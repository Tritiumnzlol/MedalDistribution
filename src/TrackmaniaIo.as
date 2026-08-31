namespace TmIo
{
    const string CONFIG_URL = "https://openplanet.dev/plugin/extraleaderboardpositions/config/urls";

    // Once ranks become large exact multiples of 100,000,
    // treat them as coarse.
    const int COARSE_RANK_STEP = 100000;
    string API_URL = "";
    bool ApiConfigLoaded = false;
    bool ApiAvailable = false;

    // =========================================================
    // Models
    // =========================================================
    class BoundaryResult
    {
        bool Ok = false;
        int Count = 0;
        int PlayerCount = 0;
        bool Exact = true;        // False means Count should be displayed as approximate.
        string Error = "";
    }

    // =========================================================
    // Coarse detection
    // =========================================================

    bool IsCoarseRank(int rank)
    {
        if (rank < COARSE_RANK_STEP){
            return false;
        }
            
        return rank % COARSE_RANK_STEP == 0;
    }


    bool IsCoarsePlayerCount(int count)
    {
        // 500,000 is the value we've specifically observed
        // acting as the effective deep-leaderboard cap.
        //
        // Don't mark ordinary 100k/200k maps coarse solely
        // because their count happens to be round.
        return count >= 500000 && count % COARSE_RANK_STEP == 0;
    }

    // =========================================================
    // API configuration
    // =========================================================

    bool EnsureApiConfig()
    {
        if (ApiConfigLoaded){
            return ApiAvailable;
        }
            
        ApiConfigLoaded = true;


        if (S_Debug)
        {
            trace("[MedalDistribution] Loading ExtraLeaderboard API config...");
        }

        auto req = Net::HttpRequest();

        req.Method = Net::HttpMethod::Get;
        req.Url = CONFIG_URL;
        req.Start();


        uint64 timeoutAt = Time::Now + uint64(S_HttpTimeoutMs);
        while (!req.Finished())
        {
            if (Time::Now >= timeoutAt)
            {
                warn("[MedalDistribution] ExtraLeaderboard config request timed out.");
                return false;
            }

            yield();
        }

        if (req.ResponseCode() != 200)
        {
            warn("[MedalDistribution] ExtraLeaderboard config returned HTTP "+ req.ResponseCode());
            return false;
        }

        try
        {
            string body = req.String();

            if (S_Debug)
            {
                trace("[MedalDistribution] Config response:");
                trace(body);
            }


            auto response = Json::Parse(body);
            auto api = response["api"];
            string active = string(api["active"]);
            if (active != "true")
            {
                warn("[MedalDistribution] ExtraLeaderboard API is disabled.");
                return false;
            }

            API_URL =string(api["url"]);
            if (API_URL.Length == 0)
            {
                warn("[MedalDistribution] ExtraLeaderboard API URL was empty.");
                return false;
            }

            while (API_URL.EndsWith("/"))
            {
                API_URL = API_URL.SubStr(0,API_URL.Length - 1);
            }

            ApiAvailable = true;

            if (S_Debug)
            {
                trace("[MedalDistribution] ExtraLeaderboard API URL: "+ API_URL);
            }

            return true;
        }
        catch
        {
            warn("[MedalDistribution] Could not parse ExtraLeaderboard API config.");
            return false;
        }
    }



    // =========================================================
    // Medal distribution
    // =========================================================

    MapDistribution@ FetchDistribution(string mapUid,int authorTime,int goldTime,int silverTime,int bronzeTime)
    {
        MapDistribution@ stats = MapDistribution();
        stats.MapUid = mapUid;
        stats.AuthorTime = authorTime;
        stats.GoldTime = goldTime;
        stats.SilverTime = silverTime;
        stats.BronzeTime = bronzeTime;

        if (!EnsureApiConfig())
        {
            stats.Error = "Leaderboard statistics service is unavailable.";
            return stats;
        }

        // Dedicated standard-medal lookup.
        string url = API_URL + "/leaderboard/map/" + Net::UrlEncode(mapUid) + "/records" + "?medal=1,2,3,4" + "&getplayercount=true";

        if (S_Debug)
        {
            trace("[MedalDistribution] Medal API GET "+ url);
        }

        auto req = Net::HttpRequest();
        req.Method = Net::HttpMethod::Get;
        req.Url = url;
        req.Start();

        uint64 timeoutAt = Time::Now + uint64(S_HttpTimeoutMs);

        while (!req.Finished())
        {
            if (Time::Now >= timeoutAt)
            {
                stats.Error = "Medal leaderboard request timed out.";
                return stats;
            }

            yield();
        }

        if (req.ResponseCode() != 200)
        {
            stats.Error = "Medal leaderboard service returned HTTP " + req.ResponseCode();
            return stats;
        }

        try
        {
            string body = req.String();
            if (S_Debug)
            {
                trace("[MedalDistribution] RAW MEDAL RESPONSE:");
                trace(body);
            }

            auto json = Json::Parse(body);
            // -------------------------------------------------
            // Player count
            // -------------------------------------------------

            int total = int(json["meta"]["playerCount"]);
            if (total <= 0)
            {
                stats.Error = "Leaderboard returned an invalid player count.";
                return stats;
            }

            stats.PlayerCount = total;
            stats.PlayerCountCoarse = IsCoarsePlayerCount( total );

            // -------------------------------------------------
            // Medal positions
            // -------------------------------------------------

            auto positions = json["positions"];
            if (positions.GetType() != Json::Type::Array || positions.Length == 0)
            {
                stats.Error = "Medal API returned no positions.";
                return stats;
            }

            int authorBoundary = -1;
            int goldBoundary = -1;
            int silverBoundary = -1;
            int bronzeBoundary = -1;

            for (uint i = 0; i < positions.Length; i++)
            {
                int time = int( positions[i]["time"] );
                int rank = int( positions[i]["rank"]);
                if (S_Debug)
                {
                    trace("[MedalDistribution] Medal API position "+ i + ": time=" + time + " rank=" + rank);
                }

                if (rank <= 0){
                    continue;
                }

                if (time == authorTime)
                {
                    authorBoundary = rank;
                }

                if (time == goldTime)
                {
                    goldBoundary = rank;
                }

                if (time == silverTime)
                {
                    silverBoundary = rank;
                }

                if (time == bronzeTime)
                {
                    bronzeBoundary = rank;
                }
            }


            if (authorBoundary < 0)
            {
                stats.Error = "Author medal position was not returned.";
                return stats;
            }

            if (goldBoundary < 0)
            {
                stats.Error = "Gold medal position was not returned.";
                return stats;
            }

            if (silverBoundary < 0)
            {
                stats.Error = "Silver medal position was not returned.";
                return stats;
            }

            if (bronzeBoundary < 0)
            {
                stats.Error = "Bronze medal position was not returned.";
                return stats;
            }

            // -------------------------------------------------
            // Store cumulative boundaries.
            // -------------------------------------------------
            stats.AuthorBoundary = authorBoundary;
            stats.GoldBoundary = goldBoundary;
            stats.SilverBoundary = silverBoundary;
            stats.BronzeBoundary = bronzeBoundary;

            // -------------------------------------------------
            // Data quality flags.
            // -------------------------------------------------

            stats.AuthorCoarse = IsCoarseRank( authorBoundary );
            stats.GoldCoarse = IsCoarseRank(goldBoundary);
            stats.SilverCoarse = IsCoarseRank(silverBoundary);
            stats.BronzeCoarse =IsCoarseRank(bronzeBoundary);

            // -------------------------------------------------
            // Basic ordering still has to make sense.
            //
            // Equal adjacent coarse boundaries are explicitly
            // ALLOWED.
            // -------------------------------------------------

            if (authorBoundary > goldBoundary || goldBoundary > silverBoundary || silverBoundary > bronzeBoundary)
            {
                stats.Error = "Medal boundaries were not ordered correctly. "+ "AT=" + authorBoundary + " Gold=" + goldBoundary + " Silver=" + silverBoundary + " Bronze=" + bronzeBoundary;
                return stats;
            }

            // -------------------------------------------------
            // Clamp to reported population.
            // -------------------------------------------------
            if (stats.AuthorBoundary > stats.PlayerCount)
            {
                stats.AuthorBoundary = stats.PlayerCount;
            }

            if (stats.GoldBoundary > stats.PlayerCount)
            {
                stats.GoldBoundary = stats.PlayerCount;
            }


            if (stats.SilverBoundary > stats.PlayerCount )
            {
                stats.SilverBoundary = stats.PlayerCount;
            }

            if (stats.BronzeBoundary > stats.PlayerCount)
            {
                stats.BronzeBoundary = stats.PlayerCount;
            }

            // -------------------------------------------------
            // Approximate exclusive buckets.
            //
            // These are used for the broad shape of the bar.
            //
            // Renderer.as separately recognises collapsed
            // coarse boundaries and displays those buckets as
            // unresolved rather than claiming 0%.
            // -------------------------------------------------

            stats.Author =stats.AuthorBoundary;
            stats.Gold = stats.GoldBoundary - stats.AuthorBoundary;
            stats.Silver = stats.SilverBoundary - stats.GoldBoundary;
            stats.Bronze = stats.BronzeBoundary - stats.SilverBoundary;
            stats.NoMedal = stats.PlayerCount - stats.BronzeBoundary;

            if (stats.Author < 0)
                stats.Author = 0;

            if (stats.Gold < 0)
                stats.Gold = 0;

            if (stats.Silver < 0)
                stats.Silver = 0;

            if (stats.Bronze < 0)
                stats.Bronze = 0;

            if (stats.NoMedal < 0)
                stats.NoMedal = 0;

            stats.Difficulty = CalculateDifficulty(stats);
            stats.LoadedAt = Time::Now;
            stats.Valid = true;
            if (S_Debug)
            {
                trace("[MedalDistribution] Medal boundaries:");
                trace("  AT=" + stats.AuthorBoundary + ( stats.AuthorCoarse ? " (coarse)": ""));
                trace("  Gold="+ stats.GoldBoundary+ (stats.GoldCoarse? " (coarse)": ""));
                trace("  Silver="+ stats.SilverBoundary+ (stats.SilverCoarse? " (coarse)": ""));
                trace("  Bronze="+ stats.BronzeBoundary+ (stats.BronzeCoarse? " (coarse)": ""));
                trace("  Players="+ stats.PlayerCount + (stats.PlayerCountCoarse ? " (coarse/capped)" : ""));

                if (stats.GoldUnresolved())
                {
                    trace("  Gold bucket unresolved.");
                }

                if (stats.SilverUnresolved())
                {
                    trace("  Silver bucket unresolved.");
                }

                if (stats.BronzeUnresolved())
                {
                    trace("  Bronze bucket unresolved.");
                }

                if (stats.NoMedalUnresolved())
                {
                    trace("  No-medal bucket unresolved.");
                }
            }

            return stats;
        }
        catch
        {
            stats.Error = "Could not parse medal leaderboard response.";
            return stats;
        }
    }



    // =========================================================
    // Arbitrary-time lookup
    //
    // Used for the player's PB.
    //
    // We still accept coarse results here, but return Exact=false
    // so the renderer can say "Top ~40%" rather than pretending
    // the position is precise.
    // =========================================================

    BoundaryResult@ FetchBoundary(string mapUid,int targetTime)
    {
        BoundaryResult@ result = BoundaryResult();

        if (targetTime <= 0)
        {
            result.Error = "Invalid leaderboard time.";
            return result;
        }

        if (!EnsureApiConfig())
        {
            result.Error = "Leaderboard statistics service unavailable.";
            return result;
        }

        string url = API_URL + "/leaderboard/map/" + Net::UrlEncode(mapUid) + "/records" + "?score=" + targetTime + "&getplayercount=true";

        if (S_Debug)
        {
            trace("[MedalDistribution] PB position GET "+ url);
        }

        auto req = Net::HttpRequest();
        req.Method = Net::HttpMethod::Get;
        req.Url = url;
        req.Start();

        uint64 timeoutAt = Time::Now + uint64(S_HttpTimeoutMs);
        while (!req.Finished())
        {
            if (Time::Now >= timeoutAt)
            {
                result.Error = "PB position request timed out.";
                return result;
            }

            yield();
        }

        if (req.ResponseCode() != 200)
        {
            result.Error = "PB position service returned HTTP " + req.ResponseCode();
            return result;
        }

        try
        {
            string body = req.String();

            if (S_Debug)
            {
                trace("[MedalDistribution] RAW PB RESPONSE:");
                trace(body);
            }

            auto json = Json::Parse(body);
            int playerCount =int(json["meta"]["playerCount"]);
            auto positions = json["positions"];

            if (positions.GetType() != Json::Type::Array || positions.Length == 0 )
            {
                result.Error = "PB position API returned no positions.";
                return result;
            }


            for (uint i = 0;i < positions.Length;i++)
            {
                int time = int(positions[i]["time"]);
                int rank =int(positions[i]["rank"]);
                if (time != targetTime){
                    continue;
                }
                if (rank <= 0){
                    continue;
                }

                result.Count = rank;
                result.PlayerCount = playerCount;
                result.Exact = !IsCoarseRank(rank);
                result.Ok = true;
                if (S_Debug)
                {
                    trace("[MedalDistribution] PB rank=" + result.Count + (result.Exact ? " exact" : " coarse"));
                }

                return result;
            }

            result.Error = "Requested PB time was not returned.";
            return result;
        }
        catch
        {
            result.Error = "Could not parse PB leaderboard response.";
            return result;
        }
    }
}