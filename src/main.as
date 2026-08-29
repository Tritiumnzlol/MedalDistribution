void DebugLog(string text)
{
    if (!S_Debug)
        return;

    trace(
        "[MedalDistribution] "
        + text
    );
}


bool IsValidTimedMap(
    int authorTime,
    int goldTime,
    int silverTime,
    int bronzeTime
)
{
    if (
        authorTime <= 0 ||
        goldTime <= 0 ||
        silverTime <= 0 ||
        bronzeTime <= 0
    )
    {
        return false;
    }


    // Normal timed medal ordering:
    //
    // Author <= Gold <= Silver <= Bronze

    if (authorTime > goldTime)
        return false;

    if (goldTime > silverTime)
        return false;

    if (silverTime > bronzeTime)
        return false;


    return true;
}


CurrentMapState@ CreateMapState(
    CGameCtnChallenge@ map
)
{
    CurrentMapState@ state =
        CurrentMapState();


    state.MapUid =
        map.MapInfo.MapUid;

    state.MapName =
        map.MapName;


    state.AuthorTime =
        map.TMObjective_AuthorTime;

    state.GoldTime =
        map.TMObjective_GoldTime;

    state.SilverTime =
        map.TMObjective_SilverTime;

    state.BronzeTime =
        map.TMObjective_BronzeTime;


    state.Supported =
        IsValidTimedMap(
            state.AuthorTime,
            state.GoldTime,
            state.SilverTime,
            state.BronzeTime
        );


    if (!state.Supported)
    {
        state.Status =
            "Medal Distribution: "
            "this map does not expose normal timed medals.";
    }
    else
    {
        state.Status =
            "Medal Distribution: loading...";
    }


    return state;
}


bool SameMedalTimes(
    MapDistribution@ stats,
    CurrentMapState@ state
)
{
    if (
        stats is null ||
        state is null
    )
    {
        return false;
    }


    return
        stats.AuthorTime
            == state.AuthorTime
        &&
        stats.GoldTime
            == state.GoldTime
        &&
        stats.SilverTime
            == state.SilverTime
        &&
        stats.BronzeTime
            == state.BronzeTime;
}


bool CacheIsFresh(
    MapDistribution@ stats,
    CurrentMapState@ state
)
{
    if (
        stats is null ||
        !stats.Valid ||
        !SameMedalTimes(
            stats,
            state
        )
    )
    {
        return false;
    }


    uint64 cacheDuration =
        uint64(S_CacheMinutes)
        * 60
        * 1000;


    return
        Time::Now
        <
        stats.LoadedAt
        + cacheDuration;
}


MapDistribution@ GetCachedDistribution(
    CurrentMapState@ state
)
{
    MapDistribution@ cached;


    if (
        !g_DistributionCache.Get(
            state.MapUid,
            @cached
        )
    )
    {
        return null;
    }


    if (
        !CacheIsFresh(
            cached,
            state
        )
    )
    {
        return null;
    }


    return cached;
}


void LoadDistribution(
    CurrentMapState@ state,
    bool forceRefresh = false
)
{
    if (
        state is null ||
        !state.Supported
    )
    {
        return;
    }


    // The state object itself lets us determine whether
    // the map changed while an HTTP request was running.

    if (!forceRefresh)
    {
        MapDistribution@ cached =
            GetCachedDistribution(
                state
            );


        if (cached !is null)
        {
            DebugLog(
                "Using cached distribution for "
                + state.MapUid
            );


            @state.Distribution =
                cached;

            state.Loading =
                false;

            state.Status =
                "";

            return;
        }
    }


    state.Loading =
        true;

    state.Status =
        "Medal Distribution: loading leaderboard...";


    DebugLog(
        "Loading distribution for "
        + state.MapUid
    );


    MapDistribution@ distribution =
        TmIo::FetchDistribution(
            state.MapUid,
            state.AuthorTime,
            state.GoldTime,
            state.SilverTime,
            state.BronzeTime
        );


    // Did we change maps while waiting?
    if (state !is g_State)
    {
        DebugLog(
            "Discarding stale response for "
            + state.MapUid
        );

        return;
    }


    state.Loading =
        false;


    if (
        distribution is null ||
        !distribution.Valid
    )
    {
        string message =
            "Unable to load leaderboard distribution.";


        if (
            distribution !is null &&
            distribution.Error.Length > 0
        )
        {
            message =
                distribution.Error;
        }


        state.Status =
            "Medal Distribution: "
            + message;


        state.NextDistributionRetryAt =
            Time::Now
            +
            uint64(S_RetryMinutes)
            * 60
            * 1000;


        warn(
            "[MedalDistribution] "
            + message
        );


        return;
    }


    @state.Distribution =
        distribution;


    state.Status =
        "";


    g_DistributionCache.Set(
        state.MapUid,
        @distribution
    );


    DebugLog(
        "Distribution loaded successfully."
    );
}

void UpdatePlayerPB(
    CurrentMapState@ state
)
{
    if (
        state is null
        ||
        state.Distribution is null
        ||
        !state.Distribution.Valid
    )
    {
        return;
    }


    if (
        state.PBReady
        &&
        Time::Now < state.NextPBCheckAt
    )
    {
        return;
    }


    if (
        !state.PBReady
        &&
        Time::Now < state.NextPBRetryAt
    )
    {
        return;
    }


    state.NextPBCheckAt =
        Time::Now
        + 10000;


    int pb =
        PlayerRecord::GetPersistentPB(
            state.MapUid
        );


    if (pb <= 0)
    {
        state.PB =
            -1;

        state.PBReady =
            false;

        state.PBPositionCoarse =
            false;

        state.PBStatus =
            "";

        return;
    }


    bool pbChanged =
        pb != state.PB;


    state.PB =
        pb;


    TmIo::BoundaryResult@ boundary =
        TmIo::FetchBoundary(
            state.MapUid,
            pb
        );


    if (state !is g_State)
        return;


    if (
        boundary is null
        ||
        !boundary.Ok
    )
    {
        state.PBReady =
            false;


        state.PBStatus =
            "Unable to calculate PB percentile.";


        state.NextPBRetryAt =
            Time::Now
            + 60000;


        return;
    }


    state.PBBoundary =
        boundary.Count;


    state.PBPositionCoarse =
        !boundary.Exact;


    state.PBReady =
        true;


    state.PBStatus =
        "";


    state.NextPBRetryAt =
        0;


    if (
        S_Debug
        &&
        pbChanged
    )
    {
        DebugLog(
            "PB updated: "
            + state.PB
            + "ms, boundary="
            + state.PBBoundary
            + (
                state.PBPositionCoarse
                ? " (coarse)"
                : ""
            )
        );
    }
}


void HandleMap(
    CGameCtnChallenge@ map
)
{
    if (map is null)
        return;


    string uid =
        map.MapInfo.MapUid;


    if (uid.Length == 0)
        return;


    // ---------------------------------------------
    // New map
    // ---------------------------------------------

    if (
        g_State is null ||
        uid != g_State.MapUid
    )
    {
        DebugLog(
            "Map changed: "
            + uid
        );


        @g_State =
            CreateMapState(
                map
            );


        if (!g_State.Supported)
        {
            DebugLog(
                "Map does not appear to use "
                "normal timed medals."
            );

            return;
        }


        LoadDistribution(
            g_State
        );


        // If loading succeeded, pick up our PB.
        if (
            g_State.Distribution !is null &&
            g_State.Distribution.Valid
        )
        {
            UpdatePlayerPB(
                g_State
            );
        }


        return;
    }


    // ---------------------------------------------
    // Manual refresh
    // ---------------------------------------------

    if (g_ForceRefreshRequested)
    {
        g_ForceRefreshRequested =
            false;


        LoadDistribution(
            g_State,
            true
        );


        if (
            g_State.Distribution !is null &&
            g_State.Distribution.Valid
        )
        {
            // Force percentile re-check as well.
            g_State.PBReady =
                false;

            g_State.NextPBRetryAt =
                0;

            UpdatePlayerPB(
                g_State
            );
        }


        return;
    }


    // ---------------------------------------------
    // Retry failed distribution
    // ---------------------------------------------

    if (
        g_State.Distribution is null ||
        !g_State.Distribution.Valid
    )
    {
        if (
            !g_State.Loading &&
            Time::Now
                >=
                g_State.NextDistributionRetryAt
        )
        {
            LoadDistribution(
                g_State
            );
        }


        return;
    }


    // ---------------------------------------------
    // Refresh an expired cache entry while the
    // player remains on the map.
    // ---------------------------------------------

    if (
        !CacheIsFresh(
            g_State.Distribution,
            g_State
        )
    )
    {
        LoadDistribution(
            g_State,
            true
        );

        return;
    }


    // ---------------------------------------------
    // Check for a newly-set PB.
    // ---------------------------------------------

    UpdatePlayerPB(
        g_State
    );
}


void Main()
{
    trace(
        "[MedalDistribution] Plugin loaded."
    );

   

    trace(
        "[MedalDistribution] "
        "Nadeo Live authenticated."
    );



    // Drawing dimensions are unavailable during the
    // first part of Openplanet startup.


    while (true)
    {
        if (!S_Enabled)
        {
            sleep(500);

            continue;
        }


        auto app =
            cast<CTrackMania>(
                GetApp()
            );


        if (
            app is null ||
            app.RootMap is null
        )
        {
            if (
                g_State !is null &&
                g_State.MapUid.Length > 0
            )
            {
                @g_State =
                    CurrentMapState();
            }


            sleep(500);

            continue;
        }


        HandleMap(
            app.RootMap
        );


        sleep(750);
    }
}


void Render()
{
    if (!S_Enabled)
        return;


    RenderMedalDistribution();
}


void RenderMenu()
{
    if (
        UI::MenuItem(
            "Medal Distribution",
            "",
            S_Enabled
        )
    )
    {
        S_Enabled =
            !S_Enabled;
    }


    if (
        S_Enabled &&
        UI::MenuItem(
            "Refresh Medal Distribution"
        )
    )
    {
        g_ForceRefreshRequested =
            true;
    }
}