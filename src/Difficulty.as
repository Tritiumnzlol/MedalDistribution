float Clamp01(float value)
{
    if (value < 0.0f)
        return 0.0f;

    if (value > 1.0f)
        return 1.0f;

    return value;
}


float CalculateDifficulty(MapDistribution@ stats)
{
    if (
        stats is null ||
        stats.PlayerCount <= 0
    )
    {
        return 0.0f;
    }

    float total =
        float(stats.PlayerCount);


    // Cumulative medal attainment.
    //
    // Author:
    //   AT only
    //
    // Gold+:
    //   AT or Gold
    //
    // etc.

    float authorRate =
        float(stats.Author)
        / total;

    float goldPlusRate =
        float(
            stats.Author +
            stats.Gold
        ) / total;

    float silverPlusRate =
        float(
            stats.Author +
            stats.Gold +
            stats.Silver
        ) / total;

    float bronzePlusRate =
        float(
            stats.Author +
            stats.Gold +
            stats.Silver +
            stats.Bronze
        ) / total;


    // Rarer = more difficult.
    //
    // AT rarity is the strongest signal,
    // but the lower medal distribution still matters.

    float score =
          (1.0f - authorRate)     * 0.45f
        + (1.0f - goldPlusRate)   * 0.30f
        + (1.0f - silverPlusRate) * 0.15f
        + (1.0f - bronzePlusRate) * 0.10f;


    score *= 100.0f;

    if (score < 0.0f)
        score = 0.0f;

    if (score > 100.0f)
        score = 100.0f;

    return score;
}


string DifficultyLabel(float score)
{
    if (score < 30.0f)
        return "Easy";

    if (score < 45.0f)
        return "Moderate";

    if (score < 60.0f)
        return "Challenging";

    if (score < 75.0f)
        return "Hard";

    if (score < 88.0f)
        return "Very Hard";

    return "Brutal";
}