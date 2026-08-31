class MapDistribution
{
    string MapUid;

    int AuthorTime = -1;
    int GoldTime = -1;
    int SilverTime = -1;
    int BronzeTime = -1;


    // ---------------------------------------------------------
    // Total leaderboard population
    // ---------------------------------------------------------

    int PlayerCount = 0;

    // True when the reported total itself looks capped/coarse.
    bool PlayerCountCoarse = false;


    // ---------------------------------------------------------
    // Cumulative medal boundaries
    //
    // Example:
    //
    // AuthorBoundary = number of players AT or better
    // GoldBoundary   = number of players Gold or better
    // etc.
    // ---------------------------------------------------------

    int AuthorBoundary = 0;
    int GoldBoundary = 0;
    int SilverBoundary = 0;
    int BronzeBoundary = 0;


    // Whether each cumulative boundary is approximate.
    bool AuthorCoarse = false;
    bool GoldCoarse = false;
    bool SilverCoarse = false;
    bool BronzeCoarse = false;


    // ---------------------------------------------------------
    // Exclusive buckets used by the renderer.
    //
    // These are still useful as approximate values, but a zero
    // resulting from two identical coarse boundaries should be
    // displayed as "?" rather than "0%".
    // ---------------------------------------------------------

    int Author = 0;
    int Gold = 0;
    int Silver = 0;
    int Bronze = 0;
    int NoMedal = 0;

    float Difficulty = 0.0f;

    uint64 LoadedAt = 0;

    bool Valid = false;

    string Error = "";

    float Percent(int value)
    {
        if (PlayerCount <= 0)
            return 0.0f;

        return
            100.0f
            * float(value)
            / float(PlayerCount);
    }


    float AuthorPercent()
    {
        return Percent(Author);
    }


    float GoldPercent()
    {
        return Percent(Gold);
    }


    float SilverPercent()
    {
        return Percent(Silver);
    }


    float BronzePercent()
    {
        return Percent(Bronze);
    }


    float NoMedalPercent()
    {
        return Percent(NoMedal);
    }

    bool HasCoarseMedals()
    {
        return AuthorCoarse || GoldCoarse || SilverCoarse || BronzeCoarse;
    }

    bool HasAnyCoarseData()
    {
        return HasCoarseMedals() || PlayerCountCoarse;
    }


    // ---------------------------------------------------------
    // Is an exclusive medal bucket actually unknowable?
    //
    // Example:
    //
    // GoldBoundary   = 400000 coarse
    // SilverBoundary = 400000 coarse
    //
    // The Silver bucket mathematically becomes zero, but we
    // know that is just the coarse leaderboard resolution.
    // ---------------------------------------------------------

    bool GoldUnresolved()
    {
        return AuthorTime != GoldTime && AuthorBoundary == GoldBoundary && ( AuthorCoarse || GoldCoarse );
    }


    bool SilverUnresolved()
    {
        return GoldTime != SilverTime && GoldBoundary == SilverBoundary && ( GoldCoarse || SilverCoarse);
    }

    bool BronzeUnresolved()
    {
        return SilverTime != BronzeTime && SilverBoundary == BronzeBoundary && (SilverCoarse || BronzeCoarse);
    }

    bool NoMedalUnresolved()
    {
        return PlayerCountCoarse && BronzeBoundary >= PlayerCount;
    }
}


class CurrentMapState
{
    string MapUid = "";
    string MapName = "";

    int AuthorTime = -1;
    int GoldTime = -1;
    int SilverTime = -1;
    int BronzeTime = -1;

    bool Supported = true;
    bool Loading = false;

    string Status = "";
    string PBStatus = "";

    MapDistribution@ Distribution = null;
    // Persistent local PB.
    int PB = -1;

    // Position/rank returned for PB.
    int PBBoundary = 0;
    bool PBReady = false;

    // True when PB rank has also fallen into the coarse range.
    bool PBPositionCoarse = false;

    uint64 NextDistributionRetryAt = 0;
    uint64 NextPBRetryAt = 0;
    uint64 NextPBCheckAt = 0;
}


CurrentMapState@ g_State = CurrentMapState();

dictionary g_DistributionCache;

bool g_ForceRefreshRequested = false;