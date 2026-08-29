enum BarOrientation
{
    Horizontal,
    Vertical
}

enum HorizontalLabelSide
{
    Above,
    Below
}

enum VerticalLabelSide
{
    Left,
    Right
}


[Setting category="General" name="Enabled"]
bool S_Enabled = true;


[Setting category="Display" name="Orientation"]
BarOrientation S_Orientation =
    BarOrientation::Horizontal;


[Setting category="Display" name="Horizontal label position"]
HorizontalLabelSide S_HorizontalLabelSide =
    HorizontalLabelSide::Below;


[Setting category="Display" name="Vertical label position"]
VerticalLabelSide S_VerticalLabelSide =
    VerticalLabelSide::Right;

[Setting category="Display" name="Bar length" min=150 max=1200]
float S_BarLength = 520.0f;


[Setting category="Display" name="Bar thickness" min=10 max=120]
float S_BarThickness = 32.0f;


[Setting category="Display" name="Bar opacity" min=0.1 max=1.0]
float S_Opacity = 0.92f;


[Setting category="Display" name="Background opacity" min=0.0 max=1.0]
float S_BackgroundOpacity = 0.75f;


[Setting category="Display" name="Show map name"]
bool S_ShowMapName = true;


[Setting category="Display" name="Show difficulty"]
bool S_ShowDifficulty = true;


[Setting category="Display" name="Show medal percentages"]
bool S_ShowPercentages = true;


[Setting category="Display" name="Show PB marker"]
bool S_ShowPB = true;


[Setting category="Display" name="Show player count"]
bool S_ShowPlayerCount = true;

[Setting category="Display" name="Hide while car is moving"]
bool S_HideWhileMoving = false;

[Setting category="Display" name="Hide movement threshold (km/h)" min=0.1 max=20.0]
float S_HideMovingThreshold = 1.0f;

[Setting category="Display" name="Show API errors"]
bool S_ShowErrors = true;


[Setting category="Network" name="Distribution cache (minutes)" min=1 max=1440]
int S_CacheMinutes = 60;


[Setting category="Network" name="Retry failed request after (minutes)" min=1 max=60]
int S_RetryMinutes = 5;


[Setting category="Network" name="HTTP timeout (ms)" min=3000 max=60000]
int S_HttpTimeoutMs = 15000;


[Setting category="Network" name="Delay between requests (ms)" min=0 max=5000]
int S_RequestDelayMs = 150;


[Setting category="Debug" name="Verbose logging"]
bool S_Debug = false;


[Setting category="Colours" name="Author" color]
vec4 S_AuthorColor =
    vec4(0.15f, 0.85f, 0.35f, 1.0f);


[Setting category="Colours" name="Gold" color]
vec4 S_GoldColor =
    vec4(1.00f, 0.76f, 0.10f, 1.0f);


[Setting category="Colours" name="Silver" color]
vec4 S_SilverColor =
    vec4(0.72f, 0.76f, 0.82f, 1.0f);


[Setting category="Colours" name="Bronze" color]
vec4 S_BronzeColor =
    vec4(0.72f, 0.39f, 0.18f, 1.0f);


[Setting category="Colours" name="No medal" color]
vec4 S_NoMedalColor =
    vec4(0.18f, 0.18f, 0.20f, 1.0f);


[Setting category="Colours" name="PB marker" color]
vec4 S_PBColor =
    vec4(1.0f, 1.0f, 1.0f, 1.0f);