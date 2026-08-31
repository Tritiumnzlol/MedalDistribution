// ============================================================
// MedalDistribution - Renderer.as
// ============================================================

// ============================================================
// Constants
// ============================================================

const float LABEL_WIDTH = 74.0f;
const float LABEL_HEIGHT = 34.0f;

const float VERTICAL_LABEL_WIDTH = 82.0f;

const float LABEL_GAP = 6.0f;
const float LABEL_MIN_SPACING = 34.0f;

const int MAX_LABEL_LANES = 3;


// ============================================================
// General helpers
// ============================================================

vec4 WithOpacity(vec4 color)
{
    return vec4( color.x, color.y, color.z, color.w * S_Opacity);
}


vec4 MixColor(vec4 a, vec4 b, float amount
)
{
    if (amount < 0.0f){
        amount = 0.0f;
    }
    if (amount > 1.0f){
        amount = 1.0f;
    }

    return vec4(
        a.x + (b.x - a.x) * amount,
        a.y + (b.y - a.y) * amount,
        a.z + (b.z - a.z) * amount,
        a.w + (b.w - a.w) * amount
    );
}

//Pads an int num with the given paddingCharacter until it is padTo long.
string formatInt(int num, string paddingCharacter, int padTo)
{
    bool negative = num < 0;
    string value = "" + Math::Abs(num);

    while (int(value.Length) < padTo - (negative ? 1 : 0)){
        value = paddingCharacter + value;
    }

    return negative ? "-" + value : value;
}

string FormatTimeMs(int ms)
{
    if (ms <= 0){
        return "-";
    }
        
    int minutes = ms / 60000;
    int seconds = (ms % 60000) / 1000;
    int millis = ms % 1000;

    if (minutes > 0)
    {
        return minutes + ":" + formatInt(seconds, '0', 2) + "." + formatInt(millis,'0',3);
    }

    return seconds + "." + formatInt(millis, '0', 3);
}


string FormatPercent(float value)
{
    if (value < 0.0f){
        value = 0.0f;
    }
    int tenths = int(value * 10.0f + 0.5f);

    return (tenths / 10) + "." + (tenths % 10)+ "%";
}


string FormatMedalPercent(float value,bool approximate,bool unresolved)
{
    if (unresolved){
        return "?";
    }
        
    if (approximate)
    {
        return "~" + FormatPercent(value);
    }

    return FormatPercent(value);
}


string DifficultyText(MapDistribution@ stats)
{
    int score = int(stats.Difficulty + 0.5f);

    if (stats.HasAnyCoarseData())
    {
        return "Difficulty ~" + score + " / 100 - " + DifficultyLabel(stats.Difficulty)+ " (approx.)";
    }

    return "Difficulty " + score + " / 100 - " + DifficultyLabel(stats.Difficulty);
}


float BoundaryFraction(int boundary, int total
)
{
    if (total <= 0){
        return 0.0f;
    }
        
    return Clamp01(float(boundary) / float(total));
}


float PlayerFraction(CurrentMapState@ state)
{
    if (state is null
        || state.Distribution is null
        || state.Distribution.PlayerCount <= 0
        || !state.PBReady
    )
    {
        return 0.0f;
    }

    return Clamp01( float(state.PBBoundary) / float(state.Distribution.PlayerCount) );
}


// ============================================================
// Labels
// ============================================================

string AuthorLabel(MapDistribution@ stats)
{
    return "AT\n" + FormatMedalPercent(stats.AuthorPercent(), stats.AuthorCoarse, false);
}

string GoldLabel(MapDistribution@ stats)
{
    return "Gold\n" + FormatMedalPercent( stats.GoldPercent(), stats.AuthorCoarse || stats.GoldCoarse, stats.GoldUnresolved());
}

string SilverLabel(MapDistribution@ stats)
{
    return "Silver\n" + FormatMedalPercent(stats.SilverPercent(),stats.GoldCoarse|| stats.SilverCoarse,stats.SilverUnresolved());
}

string BronzeLabel(MapDistribution@ stats){
    return "Bronze\n" + FormatMedalPercent( stats.BronzePercent(), stats.SilverCoarse || stats.BronzeCoarse, stats.BronzeUnresolved());
}

string NoneLabel(MapDistribution@ stats)
{
    return "None\n" + FormatMedalPercent( stats.NoMedalPercent(), stats.BronzeCoarse || stats.PlayerCountCoarse, stats.NoMedalUnresolved());
}


// ============================================================
// Basic blocks
// ============================================================

void DrawColourBlock(string id, float width, float height, vec4 color)
{
    if ( width <= 0.0f || height <= 0.0f)
    {
        return;
    }

    vec4 c = WithOpacity(color);
    UI::PushStyleColor(UI::Col::Button, c);
    UI::PushStyleColor(UI::Col::ButtonHovered,c);
    UI::PushStyleColor(UI::Col::ButtonActive, c);
    UI::Button("##" + id,vec2(width,height));
    UI::PopStyleColor(3);
}


void DrawAbsoluteColourBlock(string id, vec2 position,vec2 size,vec4 color)
{
    if (size.x <= 0.0f || size.y <= 0.0f)
    {
        return;
    }

    vec2 restore = UI::GetCursorPos();
    UI::SetCursorPos(position);
    DrawColourBlock(id, size.x,size.y,color);
    UI::SetCursorPos(restore);
}


// ============================================================
// Transparent label
// ============================================================

void DrawLabel(string id,string text,float x,float y,float width)
{
    vec2 restore = UI::GetCursorPos();
    UI::SetCursorPos(vec2(x,y));
    vec4 transparent = vec4(0.0f,0.0f,0.0f,0.0f);
    UI::PushStyleColor(UI::Col::Button,transparent);
    UI::PushStyleColor(UI::Col::ButtonHovered,transparent);
    UI::PushStyleColor(UI::Col::ButtonActive,transparent);
    UI::Button(text+ "##"+ id,vec2(width,LABEL_HEIGHT));
    UI::PopStyleColor(3);
    UI::SetCursorPos(restore);
}


// ============================================================
// Fuzzy boundary - horizontal
// ============================================================
void DrawHorizontalFuzzyBoundary(
    string id, vec2 barPos, float boundaryX, float barLength, float barHeight, vec4 leftColor, vec4 rightColor
)
{
    const int STEPS = 10;

    float fuzzyWidth = 18.0f;
    float start = boundaryX - fuzzyWidth * 0.5f;
    float end = boundaryX + fuzzyWidth * 0.5f;

    if (start < 0.0f){
        start = 0.0f;
    }

    if (end > barLength){
        end = barLength;
    }

    float actualWidth = end - start;

    if (actualWidth <= 0.0f){
        return;
    }
        
    float stepWidth = actualWidth / float(STEPS);

    for (int i = 0;i < STEPS;i++)
    {
        float amount = float(i) / float(STEPS - 1);

        DrawAbsoluteColourBlock(
            id + "_" + i, 
        vec2(barPos.x + start+ stepWidth * float(i), barPos.y),
            vec2(stepWidth + 0.5f,barHeight),
            MixColor(leftColor,rightColor,amount)
        );
    }
}


void DrawHorizontalTripleFuzzyBoundary(string id,vec2 barPos,float boundaryX,float barLength,float barHeight,vec4 leftColor,vec4 middleColor,vec4 rightColor)
{
    const int STEPS = 14;

    float fuzzyWidth =28.0f;

    float start = boundaryX - fuzzyWidth * 0.5f;
    float end = boundaryX + fuzzyWidth * 0.5f;

    if (start < 0.0f){
        start = 0.0f;
    }
        
    if (end > barLength){
        end = barLength;
    }
        
    float actualWidth = end - start;

    if (actualWidth <= 0.0f){
        return;
    }

    float stepWidth = actualWidth / float(STEPS);

    for (int i = 0; i < STEPS; i++)
    {
        float amount = float(i) / float(STEPS - 1);
        vec4 color;

        if (amount <= 0.5f)
        {
            color = MixColor(leftColor, middleColor,amount * 2.0f);
        }
        else
        {
            color = MixColor(middleColor, rightColor, (amount - 0.5f) * 2.0f);
        }

        DrawAbsoluteColourBlock(
            id + "_" + i, 
            vec2(barPos.x + start + stepWidth * float(i), barPos.y),
            vec2(stepWidth + 0.5f,barHeight),
            color
        );
    }
}


// ============================================================
// Fuzzy boundary - vertical
// ============================================================

void DrawVerticalFuzzyBoundary(string id, vec2 barPos, float boundaryY, float barWidth, float barLength, vec4 topColor, vec4 bottomColor)
{
    const int STEPS = 10;
    float fuzzyHeight = 18.0f;
    float start =boundaryY - fuzzyHeight * 0.5f;
    float end = boundaryY + fuzzyHeight * 0.5f;

    if (start < 0.0f){
        start = 0.0f;
    }
        
    if (end > barLength){
        end = barLength;
    }
        
    float actualHeight = end - start;

    if (actualHeight <= 0.0f){
        return;
    }

    float stepHeight = actualHeight / float(STEPS);

    for (int i = 0; i < STEPS; i++)
    {
        float amount = float(i) / float(STEPS - 1);

        DrawAbsoluteColourBlock(
            id + "_" + i,
            vec2(barPos.x, barPos.y + start + stepHeight * float(i)),
            vec2(barWidth,stepHeight + 0.5f),
            MixColor(topColor,bottomColor,amount)
        );
    }
}


void DrawVerticalTripleFuzzyBoundary(string id,vec2 barPos,float boundaryY,float barWidth,float barLength,vec4 topColor,vec4 middleColor,vec4 bottomColor)
{
    const int STEPS = 14;
    float fuzzyHeight = 28.0f;
    float start = boundaryY - fuzzyHeight * 0.5f;
    float end = boundaryY + fuzzyHeight * 0.5f;

    if (start < 0.0f){
        start = 0.0f;
    }
        
    if (end > barLength){
        end = barLength;
    }
        
    float actualHeight = end - start;

    if (actualHeight <= 0.0f) {
        return;
    }

    float stepHeight = actualHeight / float(STEPS);

    for (int i = 0; i < STEPS; i++)
    {
        float amount = float(i) / float(STEPS - 1);
        vec4 color;

        if (amount <= 0.5f)
        {
            color = MixColor(topColor, middleColor,amount * 2.0f);
        }
        else
        {
            color = MixColor(middleColor,bottomColor,(amount - 0.5f) * 2.0f);
        }

        DrawAbsoluteColourBlock(
            id + "_" + i,
            vec2(barPos.x,barPos.y+ start+ stepHeight * float(i)),
            vec2(barWidth,stepHeight + 0.5f),
            color
        );
    }
}


// ============================================================
// PB markers
// ============================================================

void DrawHorizontalPBMarker(CurrentMapState@ state,vec2 barPos,float barLength,float barHeight)
{
    if (!S_ShowPB || !state.PBReady ||state.PB <= 0)
    {
        return;
    }

    float x = PlayerFraction(state) * barLength;

    // Dark outline
    DrawAbsoluteColourBlock("PBMarkerShadow",
        vec2(barPos.x + x - 3.0f,barPos.y - 3.0f),
        vec2(6.0f,barHeight + 6.0f),
        vec4(0.0f,0.0f,0.0f,0.9f)
    );

    // Main marker
    DrawAbsoluteColourBlock(
        "PBMarker",
        vec2(barPos.x + x - 1.5f,barPos.y - 5.0f),
        vec2(3.0f,barHeight + 10.0f),
        S_PBColor
    );
}


void DrawVerticalPBMarker(CurrentMapState@ state,vec2 barPos,float barWidth,float barLength)
{
    if (!S_ShowPB || !state.PBReady || state.PB <= 0)
    {
        return;
    }

    float y = PlayerFraction(state) * barLength;

    // Dark outline
    DrawAbsoluteColourBlock(
        "VerticalPBShadow",
        vec2(barPos.x - 3.0f,barPos.y + y - 3.0f),
        vec2(barWidth + 6.0f,6.0f),
        vec4(0.0f,0.0f,0.0f,0.9f)
    );

    // Main marker
    DrawAbsoluteColourBlock(
        "VerticalPBMarker",
        vec2(barPos.x - 5.0f, barPos.y + y - 1.5f),
        vec2(barWidth + 10.0f,3.0f),
        S_PBColor
    );
}


// ============================================================
// Build medal segment centres
// ============================================================

void GetHorizontalCenters(MapDistribution@ stats,float length,array<float>@ centers)
{
    float authorX = BoundaryFraction(stats.AuthorBoundary, stats.PlayerCount) * length;
    float goldX = BoundaryFraction(stats.GoldBoundary,stats.PlayerCount)      * length;
    float silverX = BoundaryFraction(stats.SilverBoundary, stats.PlayerCount) * length;
    float bronzeX = BoundaryFraction(stats.BronzeBoundary,stats.PlayerCount)  * length;

    centers.InsertLast(authorX * 0.5f);
    centers.InsertLast((authorX + goldX) * 0.5f);
    centers.InsertLast((goldX + silverX) * 0.5f);
    centers.InsertLast((silverX + bronzeX) * 0.5f);
    centers.InsertLast((bronzeX + length) * 0.5f);
}


// ============================================================
// Lane assignment
//
// Horizontal: lanes become additional rows.
//
// Vertical: lanes become additional columns.
//
// This is particularly important when coarse Gold/Silver
// boundaries collapse to the same coordinate.
// ============================================================

int AssignLabelLanes(array<float>@ centers,array<int>@ lanes)
{
    array<float> lastCenter = {-100000.0f, -100000.0f, -100000.0f};

    int maxLane = 0;

    for (uint i = 0; i < centers.Length; i++)
    {
        int lane = -1;

        for (int test = 0; test < MAX_LABEL_LANES; test++)
        {
            if (centers[i] - lastCenter[test] >= LABEL_MIN_SPACING)
            {
                lane = test;
                break;
            }
        }

        if (lane < 0){
            lane = MAX_LABEL_LANES - 1;
        }
            
        lanes.InsertLast(lane);
        lastCenter[lane] = centers[i];

        if (lane > maxLane){
            maxLane = lane;
        }
    }
    return maxLane;
}


// ============================================================
// Horizontal labels
// ============================================================

void DrawHorizontalLabels(MapDistribution@ stats,vec2 barPos,float barLength)
{
    if (!S_ShowPercentages){
        return;
    }
        
    array<float> centers;
    GetHorizontalCenters(stats,barLength,centers);

    array<int> lanes;
    AssignLabelLanes(centers,lanes);

    array<string> labels =
    {
        AuthorLabel(stats),
        GoldLabel(stats),
        SilverLabel(stats),
        BronzeLabel(stats),
        NoneLabel(stats)
    };

    array<string> ids =
    {
        "AuthorLabel",
        "GoldLabel",
        "SilverLabel",
        "BronzeLabel",
        "NoneLabel"
    };


    for (uint i = 0;i < centers.Length;i++)
    {
        float x = barPos.x + centers[i] - LABEL_WIDTH * 0.5f;

        // Keep labels reasonably inside the bar width.
        if (x < barPos.x){
            x = barPos.x;
        }
            
        if (x + LABEL_WIDTH > barPos.x + barLength)
        {
            x = barPos.x + barLength - LABEL_WIDTH;
        }

        float y;

        if (S_HorizontalLabelSide == HorizontalLabelSide::Below)
        {
            y = barPos.y + S_BarThickness + LABEL_GAP + float(lanes[i]) * LABEL_HEIGHT;
        }
        else
        {
            y = barPos.y - LABEL_GAP - LABEL_HEIGHT - float(lanes[i]) * LABEL_HEIGHT;
        }

        DrawLabel(ids[i], labels[i], x, y, LABEL_WIDTH);
    }
}


// ============================================================
// Vertical labels
// ============================================================

void DrawVerticalLabels(MapDistribution@ stats,vec2 barPos,float barWidth,float barLength)
{
    if (!S_ShowPercentages){
        return;
    }
        
    float authorY = BoundaryFraction(stats.AuthorBoundary,stats.PlayerCount)  * barLength;
    float goldY = BoundaryFraction(stats.GoldBoundary, stats.PlayerCount)     * barLength;
    float silverY = BoundaryFraction(stats.SilverBoundary, stats.PlayerCount) * barLength;
    float bronzeY = BoundaryFraction(stats.BronzeBoundary, stats.PlayerCount) * barLength;

    array<float> centers =
    {
        authorY * 0.5f,
        (authorY + goldY) * 0.5f,
        (goldY + silverY) * 0.5f,
        (silverY + bronzeY) * 0.5f,
        (bronzeY + barLength) * 0.5f
    };

    array<int> lanes;
    AssignLabelLanes(centers,lanes);

    array<string> labels =
    {
        AuthorLabel(stats),
        GoldLabel(stats),
        SilverLabel(stats),
        BronzeLabel(stats),
        NoneLabel(stats)
    };

    array<string> ids =
    {
        "AuthorVerticalLabel",
        "GoldVerticalLabel",
        "SilverVerticalLabel",
        "BronzeVerticalLabel",
        "NoneVerticalLabel"
    };


    for (uint i = 0;i < centers.Length;i++)
    {
        float y = barPos.y + centers[i] - LABEL_HEIGHT * 0.5f;

        if (y < barPos.y){
            y = barPos.y;
        }
            
        if (y + LABEL_HEIGHT > barPos.y + barLength)
        {
            y = barPos.y + barLength - LABEL_HEIGHT;
        }

        float x;
        if (S_VerticalLabelSide == VerticalLabelSide::Right)
        {
            x = barPos.x + barWidth + LABEL_GAP + float(lanes[i]) * VERTICAL_LABEL_WIDTH;
        }
        else
        {
            x = barPos.x - LABEL_GAP - VERTICAL_LABEL_WIDTH - float(lanes[i]) * VERTICAL_LABEL_WIDTH;
        }

        DrawLabel(ids[i],labels[i],x,y,VERTICAL_LABEL_WIDTH);
    }
}


// ============================================================
// Horizontal bar
// ============================================================

void RenderHorizontalBar(CurrentMapState@ state)
{
    MapDistribution@ stats = state.Distribution;

    if (stats is null || stats.PlayerCount <= 0)
    {
        return;
    }

    float length = S_BarLength;
    float height = S_BarThickness;

    // ---------------------------------------------------------
    // PB text
    // ---------------------------------------------------------

    if (S_ShowPB && state.PBReady && state.PB > 0)
    {
        string approximate = state.PBPositionCoarse ? "~" : "";
        UI::Text("PB " + FormatTimeMs(state.PB) + "  |  Top " + approximate + FormatPercent( PlayerFraction(state) * 100.0f )
        );
    }

    float authorX = BoundaryFraction( stats.AuthorBoundary, stats.PlayerCount ) * length;
    float goldX = BoundaryFraction(stats.GoldBoundary, stats.PlayerCount) * length;
    float silverX = BoundaryFraction(stats.SilverBoundary,stats.PlayerCount) * length;
    float bronzeX = BoundaryFraction(stats.BronzeBoundary,stats.PlayerCount) * length;

    // ---------------------------------------------------------
    // Work out how much label space needs reserving.
    // ---------------------------------------------------------
    float labelSpace = 0.0f;
    int maxLane = 0;

    if (S_ShowPercentages)
    {
        array<float> centers;
        GetHorizontalCenters(stats,length,centers);
        array<int> lanes;
        maxLane = AssignLabelLanes(centers,lanes);
        labelSpace = float(maxLane + 1) * LABEL_HEIGHT+ LABEL_GAP;
    }

    vec2 canvasStart = UI::GetCursorPos();
    vec2 barPos = canvasStart;

    if (S_ShowPercentages && S_HorizontalLabelSide == HorizontalLabelSide::Above)
    {
        barPos.y += labelSpace;
    }

    float canvasHeight = height + labelSpace;
    UI::Dummy(vec2(length,canvasHeight));

    // ---------------------------------------------------------
    // Main segments
    // ---------------------------------------------------------

    DrawAbsoluteColourBlock("AuthorSegment", barPos, vec2(authorX,height),S_AuthorColor);
    DrawAbsoluteColourBlock("GoldSegment",vec2(barPos.x + authorX,barPos.y),vec2(goldX - authorX,height), S_GoldColor);
    DrawAbsoluteColourBlock("SilverSegment",vec2(barPos.x + goldX,barPos.y),vec2(silverX - goldX,height),S_SilverColor);
    DrawAbsoluteColourBlock("BronzeSegment",vec2(barPos.x + silverX,barPos.y),vec2(bronzeX - silverX,height),S_BronzeColor);
    DrawAbsoluteColourBlock("NoMedalSegment",vec2(barPos.x + bronzeX,barPos.y),vec2(length - bronzeX,height),S_NoMedalColor);

    // ---------------------------------------------------------
    // Fuzzy boundaries
    // ---------------------------------------------------------

    bool goldUnresolved = stats.GoldUnresolved();
    bool silverUnresolved = stats.SilverUnresolved();
    bool bronzeUnresolved = stats.BronzeUnresolved();

    if (stats.AuthorCoarse && !goldUnresolved)
    {
        DrawHorizontalFuzzyBoundary("AuthorGoldFuzzy",barPos,authorX,length,height,S_AuthorColor,S_GoldColor);
    }

    if (stats.GoldCoarse && !goldUnresolved && !silverUnresolved )
    {
        DrawHorizontalFuzzyBoundary("GoldSilverFuzzy",barPos,goldX,length,height,S_GoldColor,S_SilverColor);
    }

    if (stats.SilverCoarse && !silverUnresolved && !bronzeUnresolved)
    {
        DrawHorizontalFuzzyBoundary("SilverBronzeFuzzy",barPos,silverX,length,height,S_SilverColor,S_BronzeColor);
    }


    if (stats.BronzeCoarse && !bronzeUnresolved)
    {
        DrawHorizontalFuzzyBoundary("BronzeNoneFuzzy", barPos, bronzeX, length, height, S_BronzeColor, S_NoMedalColor);
    }

    if (goldUnresolved)
    {
        DrawHorizontalTripleFuzzyBoundary("GoldUnresolvedFuzzy", barPos,authorX,length,height,S_AuthorColor,S_GoldColor,S_SilverColor);
    }


    if (silverUnresolved)
    {
        DrawHorizontalTripleFuzzyBoundary("SilverUnresolvedFuzzy",barPos,goldX,length,height,S_GoldColor,S_SilverColor,S_BronzeColor);
    }

    if (bronzeUnresolved)
    {
        DrawHorizontalTripleFuzzyBoundary("BronzeUnresolvedFuzzy",barPos,silverX,length,height,S_SilverColor,S_BronzeColor,S_NoMedalColor);
    }

    DrawHorizontalPBMarker(state,barPos,length,height);
    DrawHorizontalLabels(stats,barPos,length);

    // Footer
    if (stats.HasAnyCoarseData())
    {
        UI::Text("~ approximate   ? unresolved at leaderboard resolution");
    }


    if (S_ShowPlayerCount)
{
    if (stats.PlayerCountCoarse)
    {
        UI::Text("Finished players: "+ stats.PlayerCount+ "+");
    }
    else
    {
        UI::Text("Finished players: "+ stats.PlayerCount);
    }
}

// IMPORTANT:
//
// Our renderer uses SetCursorPos() for labels, fuzzy
// boundaries and the PB marker.
//
// ImGui requires a submitted item after absolute cursor
// positioning before the window ends. Player-count text
// previously happened to do this for us.
//
// Keep this unconditional.
    UI::Dummy(vec2(1.0f,1.0f));
}


// ============================================================
// Vertical bar
// ============================================================

void RenderVerticalBar(CurrentMapState@ state)
{
    MapDistribution@ stats = state.Distribution;


    if (stats is null || stats.PlayerCount <= 0)
    {
        return;
    }

    float width = S_BarThickness;
    float length = S_BarLength;
    // ---------------------------------------------------------
    // PB text
    // ---------------------------------------------------------

    if (S_ShowPB && state.PBReady && state.PB > 0)
    {
        string approximate = state.PBPositionCoarse ? "~" : "";
        UI::Text("PB " + FormatTimeMs(state.PB) + "  |  Top " + approximate + FormatPercent( PlayerFraction(state) * 100.0f ));
    }

    float authorY = BoundaryFraction(stats.AuthorBoundary,stats.PlayerCount) * length;
    float goldY = BoundaryFraction( stats.GoldBoundary, stats.PlayerCount) * length;
    float silverY = BoundaryFraction(stats.SilverBoundary,stats.PlayerCount) * length;
    float bronzeY = BoundaryFraction(stats.BronzeBoundary,stats.PlayerCount) * length;

    // ---------------------------------------------------------
    // Determine label columns needed.
    // ---------------------------------------------------------

    float labelSpace = 0.0f;
    int maxLane = 0;


    if (S_ShowPercentages)
    {
        array<float> centers =
        {
            authorY * 0.5f,
            (authorY + goldY) * 0.5f,
            (goldY + silverY) * 0.5f,
            (silverY + bronzeY) * 0.5f,
            (bronzeY + length) * 0.5f
        };
        array<int> lanes;
        maxLane = AssignLabelLanes(centers,lanes);
        labelSpace = float(maxLane + 1) * VERTICAL_LABEL_WIDTH + LABEL_GAP;
    }

    vec2 canvasStart = UI::GetCursorPos();
    vec2 barPos = canvasStart;

    if (S_ShowPercentages && S_VerticalLabelSide == VerticalLabelSide::Left)
    {
        barPos.x += labelSpace;
    }

    float canvasWidth = width + labelSpace;
    UI::Dummy(vec2(canvasWidth,length));

    // ---------------------------------------------------------
    // Base segments
    // ---------------------------------------------------------

    DrawAbsoluteColourBlock("AuthorVertical",barPos,vec2(width,authorY),S_AuthorColor);
    DrawAbsoluteColourBlock("GoldVertical",vec2(barPos.x,barPos.y + authorY),vec2(width,goldY - authorY),S_GoldColor);
    DrawAbsoluteColourBlock("SilverVertical",vec2(barPos.x,barPos.y + goldY),vec2(width,silverY - goldY),S_SilverColor);
    DrawAbsoluteColourBlock("BronzeVertical",vec2(barPos.x,barPos.y + silverY),vec2(width,bronzeY - silverY),S_BronzeColor);
    DrawAbsoluteColourBlock("NoneVertical",vec2(barPos.x,barPos.y + bronzeY),vec2(width,length - bronzeY),S_NoMedalColor);

    // ---------------------------------------------------------
    // Fuzzy overlays
    // ---------------------------------------------------------

    bool goldUnresolved =stats.GoldUnresolved();
    bool silverUnresolved = stats.SilverUnresolved();
    bool bronzeUnresolved = stats.BronzeUnresolved();

    if (stats.AuthorCoarse && !goldUnresolved)
    {
        DrawVerticalFuzzyBoundary("AuthorGoldVerticalFuzzy",barPos,authorY,width,length,S_AuthorColor,S_GoldColor);
    }

    if (stats.GoldCoarse && !goldUnresolved && !silverUnresolved)
    {
        DrawVerticalFuzzyBoundary("GoldSilverVerticalFuzzy",barPos,goldY,width,length,S_GoldColor,S_SilverColor);
    }

    if (stats.SilverCoarse && !silverUnresolved && !bronzeUnresolved)
    {
        DrawVerticalFuzzyBoundary( "SilverBronzeVerticalFuzzy",barPos,silverY, width, length, S_SilverColor, S_BronzeColor);
    }

    if (stats.BronzeCoarse && !bronzeUnresolved)
    {
        DrawVerticalFuzzyBoundary("BronzeNoneVerticalFuzzy",barPos,bronzeY,width,length,S_BronzeColor,S_NoMedalColor);
    }

    if (goldUnresolved)
    {
        DrawVerticalTripleFuzzyBoundary("GoldUnresolvedVerticalFuzzy",barPos,authorY,width,length,S_AuthorColor,S_GoldColor,S_SilverColor);
    }

    if (silverUnresolved)
    {
        DrawVerticalTripleFuzzyBoundary("SilverUnresolvedVerticalFuzzy",barPos,goldY,width,length,S_GoldColor,S_SilverColor,S_BronzeColor);
    }

    if (bronzeUnresolved)
    {
        DrawVerticalTripleFuzzyBoundary("BronzeUnresolvedVerticalFuzzy",barPos,silverY,width,length,S_SilverColor,S_BronzeColor,S_NoMedalColor);
    }

    DrawVerticalPBMarker(state,barPos,width,length);
    DrawVerticalLabels(stats,barPos,width,length);

    if (stats.HasAnyCoarseData())
    {
        UI::Text("~ approximate   ? unresolved at leaderboard resolution");
    }

if (S_ShowPlayerCount)
{
    if (stats.PlayerCountCoarse)
    {
        UI::Text("Finished players: "+ stats.PlayerCount+ "+");
    }
    else
    {
        UI::Text("Finished players: "+ stats.PlayerCount);
    }
}

// Finalise layout after any SetCursorPos() calls.
UI::Dummy(vec2(1.0f,1.0f));
}


// ============================================================
// Window background
// ============================================================

void PushWindowBackground()
{
    // Same dark neutral base as before, but alpha is now
    // user-configurable.

    vec4 body =vec4(0.10f,0.10f,0.10f,S_BackgroundOpacity);
    vec4 title =vec4(0.08f,0.08f,0.08f,S_BackgroundOpacity);

    UI::PushStyleColor(UI::Col::WindowBg,body);
    UI::PushStyleColor(UI::Col::TitleBg,title);
    UI::PushStyleColor(UI::Col::TitleBgActive,title);
    UI::PushStyleColor(UI::Col::TitleBgCollapsed,title);
}


void PopWindowBackground()
{
    UI::PopStyleColor(4);
}


// ============================================================
// Main overlay
// ============================================================


bool ShouldHideWhileMoving()
{
    if (!S_HideWhileMoving){
        return false;
    }
    auto visState =VehicleState::ViewingPlayerState();

    // No active vehicle -- keep the plugin visible.
    if (visState is null){
        return false;
    }

    // FrontSpeed is metres/sec.
    // Convert to km/h.
    float speedKmh = visState.FrontSpeed * 3.6f;

    // Reverse produces negative speed.
    if (speedKmh < 0.0f){
        speedKmh = -speedKmh;
    }
        
    return speedKmh >= S_HideMovingThreshold;
}

void RenderMedalDistribution()
{
    CurrentMapState@ state = g_State;

    if (state is null || state.MapUid.Length == 0)
    {
        return;
    }

    // Hide the whole overlay while driving.
    //
    // Keep this BEFORE PushWindowBackground() / UI::Begin()
    // so we don't leave anything on the ImGui stack.
    if (ShouldHideWhileMoving())
    {
        return;
    }

    PushWindowBackground();
    UI::WindowFlags flags =UI::WindowFlags(UI::WindowFlags::AlwaysAutoResize|UI::WindowFlags::NoCollapse);

    bool visible =UI::Begin("Medal Distribution###MedalDistributionOverlay",flags);

    if (!visible)
    {
        UI::End();
        PopWindowBackground();
        return;
    }

    if (state.Distribution is null || !state.Distribution.Valid)
    {
        if (state.Status.Length > 0){
            UI::Text(state.Status);
        }
        else
        {
            UI::Text("Waiting for map data...");
        }

        UI::End();
        PopWindowBackground();
        return;
    }

    if (S_ShowMapName)
    {
        UI::Text(state.MapName);
    }

    if (S_ShowDifficulty)
    {
        UI::Text(DifficultyText(state.Distribution));
    }

    UI::Separator();

    if (S_Orientation==BarOrientation::Horizontal)
    {
        RenderHorizontalBar(state);
    }
    else
    {
        RenderVerticalBar(state);
    }

    UI::End();
    PopWindowBackground();
}
