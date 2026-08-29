namespace PlayerRecord
{
    int GetPersistentPB(string mapUid)
    {
        auto app =
            cast<CTrackMania>(GetApp());

        if (app is null)
            return -1;


        auto network =
            cast<CTrackManiaNetwork>(
                app.Network
            );

        if (network is null)
            return -1;


        auto playground =
            network.ClientManiaAppPlayground;

        if (playground is null)
            return -1;


        auto userMgr =
            playground.UserMgr;

        if (userMgr.Users.Length == 0)
            return -1;


        MwId userId =
            userMgr.Users[0].Id;


        auto scoreMgr =
            playground.ScoreMgr;

        if (scoreMgr is null)
            return -1;


        return scoreMgr.Map_GetRecord_v2(
            userId,
            mapUid,
            "PersonalBest",
            "",
            "TimeAttack",
            ""
        );
    }
}