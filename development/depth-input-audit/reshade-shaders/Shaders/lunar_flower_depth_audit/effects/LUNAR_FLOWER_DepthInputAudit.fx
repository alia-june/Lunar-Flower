#include "ReShade.fxh"

// Display-only depth audit. It never changes global definitions or GI inputs.
uniform int LF_DPA_View
< ui_type = "combo"; ui_label = "Audit View";
  ui_items = "Compare linear depth: Framework / Normal Z / Reversed Z\0Compare validity: Framework / Normal Z / Reversed Z\0Raw depth at screen UV\0Raw depth at global-adjusted UV\0Framework linear depth\0Framework receiver validity\0Source image\0";
  ui_text = "Three columns repeat the whole scene. Left: installed ReShade helper. Center: candidate normal Z. Right: candidate reversed Z.\nNumeric rows at top left all sample the SAME Probe Position: 1 raw adjusted, 2 framework, 3 normal Z, 4 reversed Z, 5 depth resource ready.\nChanging this diagnostic does not configure other effects.";
> = 1;

uniform float LF_DPA_FarRatio
< ui_type = "drag"; ui_label = "Candidate Far / Near Ratio";
  ui_min = 1.0; ui_max = 1000000.0; ui_step = 1.0;
  ui_tooltip = "Candidate perspective linearization ratio only. Starts from the installed framework value. Does not change the framework column or global definitions. Phantom Brigade SDK example: 5000 / 0.1 = 50000; actual game camera may differ.";
> = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;

uniform int LF_DPA_Projection
< ui_type = "combo"; ui_label = "Candidate Projection";
  ui_items = "Perspective\0Orthographic / already linear\0";
  ui_tooltip = "Affects only the candidate columns. The published Phantom Brigade SDK camera is perspective despite its isometric presentation.";
> = 0;

uniform float LF_DPA_Exposure
< ui_type = "drag"; ui_label = "Depth Display Exposure";
  ui_min = -8.0; ui_max = 24.0; ui_step = 0.25;
  ui_tooltip = "Display gain in powers of two. Never affects numbers, validity or another shader.";
> = 0.0;

uniform float LF_DPA_DisplayPower
< ui_type = "drag"; ui_label = "Depth Display Power";
  ui_min = 0.05; ui_max = 1.0; ui_step = 0.05;
  ui_tooltip = "Makes small depths visible; 1 is uncurved. Never changes sampled depth or validity.";
> = 0.25;

uniform float2 LF_DPA_ProbeUV
< ui_type = "drag"; ui_label = "Probe Position (screen UV)";
  ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
  ui_tooltip = "Select a point on scene geometry. The orange cross marks this same sampled point in each column. Numbers use scientific notation: 9.81E-07 means 0.000000981.";
> = float2(0.5, 0.5);

uniform bool LF_DPA_ShowNumbers
< ui_type = "checkbox"; ui_label = "Show Five Numeric Probe Rows";
  ui_tooltip = "1 raw adjusted; 2 actual framework linear depth; 3 normal-Z candidate; 4 reversed-Z candidate; 5 ReShade depth resource ready (1/0). Readiness alone does not prove valid scene depth.";
> = true;

uniform bool LF_DPA_DepthReady < source = "bufready_depth"; > = false;

float2 LF_DPA_AdjustedUV(float2 uv)
{
#if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
    uv.y = 1.0 - uv.y;
#endif
#if RESHADE_DEPTH_INPUT_IS_MIRRORED
    uv.x = 1.0 - uv.x;
#endif
    uv.x /= RESHADE_DEPTH_INPUT_X_SCALE;
    uv.y /= RESHADE_DEPTH_INPUT_Y_SCALE;
#if RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET
    uv.x -= RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET * BUFFER_RCP_WIDTH;
#else
    uv.x -= RESHADE_DEPTH_INPUT_X_OFFSET / 2.000000001;
#endif
#if RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET
    uv.y += RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET * BUFFER_RCP_HEIGHT;
#else
    uv.y += RESHADE_DEPTH_INPUT_Y_OFFSET / 2.000000001;
#endif
    return uv;
}

float LF_DPA_Raw(float2 uv)
{
    return tex2Dlod(ReShade::DepthBuffer, float4(uv, 0.0, 0.0)).r;
}

float LF_DPA_Candidate(float rawDepth, bool reversedZ)
{
    float depth = rawDepth * RESHADE_DEPTH_MULTIPLIER;
#if RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
    const float C = 0.01;
    depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
#endif
    if (reversedZ) depth = 1.0 - depth;
    if (LF_DPA_Projection == 1) return depth;
    float ratio = max(LF_DPA_FarRatio, 1.0);
    return depth / (ratio - depth * (ratio - 1.0));
}

float3 LF_DPA_ValidityColor(float depth)
{
    if (isnan(depth) || isinf(depth)) return float3(1.0, 0.0, 1.0);
    if (depth < 0.0 || depth > 1.0) return float3(1.0, 0.5, 0.0);
    if (depth < 0.000001) return float3(1.0, 0.05, 0.03);
    if (depth > 0.999999) return float3(0.1, 0.25, 1.0);
    return float3(0.05, 0.95, 0.18);
}

float3 LF_DPA_DepthColor(float depth)
{
    if (isnan(depth) || isinf(depth) || depth < 0.0 || depth > 1.0)
        return LF_DPA_ValidityColor(depth);
    float shown = pow(saturate(depth * exp2(LF_DPA_Exposure)), max(LF_DPA_DisplayPower, 0.05));
    return float3(shown, shown, shown);
}

// Small seven-segment numeric overlay. No font textures or extra render passes.
float LF_DPA_Glyph(float2 p, int glyph)
{
    if (glyph < 0) return 0.0;
    int bits = 0;
    if (glyph == 0) bits = 63;
    else if (glyph == 1) bits = 6;
    else if (glyph == 2) bits = 91;
    else if (glyph == 3) bits = 79;
    else if (glyph == 4) bits = 102;
    else if (glyph == 5) bits = 109;
    else if (glyph == 6) bits = 125;
    else if (glyph == 7) bits = 7;
    else if (glyph == 8) bits = 127;
    else if (glyph == 9) bits = 111;
    else if (glyph == 10) bits = 121; // E
    else if (glyph == 11) bits = 64; // minus
    if (glyph == 12) return p.x > 0.25 && p.x < 0.45 && p.y > 0.83 && p.y < 0.97 ? 1.0 : 0.0;
    bool horizontal = p.x > 0.2 && p.x < 0.8;
    bool left = p.x > 0.1 && p.x < 0.25;
    bool right = p.x > 0.75 && p.x < 0.9;
    bool top = p.y > 0.16 && p.y < 0.45;
    bool bottom = p.y > 0.55 && p.y < 0.84;
    bool lit = ((bits & 1) != 0 && horizontal && abs(p.y - 0.1) < 0.06) ||
        ((bits & 2) != 0 && right && top) || ((bits & 4) != 0 && right && bottom) ||
        ((bits & 8) != 0 && horizontal && abs(p.y - 0.9) < 0.06) ||
        ((bits & 16) != 0 && left && bottom) || ((bits & 32) != 0 && left && top) ||
        ((bits & 64) != 0 && horizontal && abs(p.y - 0.5) < 0.06);
    return lit ? 1.0 : 0.0;
}

float LF_DPA_Number(float2 p, float value, int rowNumber)
{
    int cell = (int)floor(p.x);
    if (cell == 0) return LF_DPA_Glyph(frac(p), rowNumber);
    if (cell == 1) return 0.0;
    if (isnan(value) || isinf(value)) return LF_DPA_Glyph(frac(p), 10);
    float magnitude = abs(value);
    float exponent = magnitude > 0.0 ? floor(log10(max(magnitude, 0.00000000000000000001))) : 0.0;
    float mantissa = magnitude * pow(10.0, -exponent);
    // Avoid a value near a decade boundary appearing with a blank leading 10.
    if (mantissa >= 10.0) { mantissa *= 0.1; exponent += 1.0; }
    if (cell == 2) return LF_DPA_Glyph(frac(p), value < 0.0 ? 11 : -1);
    if (cell == 3) return LF_DPA_Glyph(frac(p), (int)floor(mantissa));
    if (cell == 4) return LF_DPA_Glyph(frac(p), 12);
    if (cell >= 5 && cell <= 8)
    {
        float shifted = floor(mantissa * pow(10.0, (float)(cell - 4)));
        return LF_DPA_Glyph(frac(p), (int)(shifted - floor(shifted / 10.0) * 10.0));
    }
    if (cell == 9) return LF_DPA_Glyph(frac(p), 10);
    if (cell == 10) return LF_DPA_Glyph(frac(p), exponent < 0.0 ? 11 : -1);
    if (cell == 11) return LF_DPA_Glyph(frac(p), (int)floor(abs(exponent) / 10.0));
    if (cell == 12) return LF_DPA_Glyph(frac(p), (int)(abs(exponent) - floor(abs(exponent) / 10.0) * 10.0));
    return 0.0;
}

float4 LF_DPA_Display(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 sceneUv = uv;
    int column = min((int)floor(uv.x * 3.0), 2);
    if (LF_DPA_View <= 1) sceneUv.x = frac(uv.x * 3.0);
    float raw = LF_DPA_Raw(LF_DPA_AdjustedUV(sceneUv));
    float framework = ReShade::GetLinearizedDepth(sceneUv);
    float3 color = LF_DPA_DepthColor(framework);
    if (LF_DPA_View <= 1)
    {
        float depth = column == 0 ? framework : LF_DPA_Candidate(raw, column == 2);
        color = LF_DPA_View == 1 ? LF_DPA_ValidityColor(depth) : LF_DPA_DepthColor(depth);
    }
    else if (LF_DPA_View == 2) color = LF_DPA_DepthColor(LF_DPA_Raw(sceneUv));
    else if (LF_DPA_View == 3) color = LF_DPA_DepthColor(raw);
    else if (LF_DPA_View == 5) color = LF_DPA_ValidityColor(framework);
    else if (LF_DPA_View == 6) color = tex2Dlod(ReShade::BackBuffer, float4(sceneUv, 0.0, 0.0)).rgb;
    float2 crossDistance = abs(sceneUv - saturate(LF_DPA_ProbeUV)) / float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    if ((crossDistance.x < 1.5 && crossDistance.y < 12.0) ||
        (crossDistance.y < 1.5 && crossDistance.x < 12.0)) color = float3(1.0, 0.6, 0.0);
    if (LF_DPA_ShowNumbers)
    {
        float height = max(18.0, BUFFER_HEIGHT / 64.0);
        float2 textUv = (position.xy - float2(12.0, 12.0)) / float2(height * 0.6, height);
        int row = (int)floor(textUv.y);
        if (textUv.x >= 0.0 && textUv.x < 13.0 && row >= 0 && row < 5)
        {
            float2 probe = saturate(LF_DPA_ProbeUV);
            float probeRaw = LF_DPA_Raw(LF_DPA_AdjustedUV(probe));
            float probeValue = probeRaw;
            if (row == 1) probeValue = ReShade::GetLinearizedDepth(probe);
            else if (row == 2) probeValue = LF_DPA_Candidate(probeRaw, false);
            else if (row == 3) probeValue = LF_DPA_Candidate(probeRaw, true);
            else if (row == 4) probeValue = LF_DPA_DepthReady ? 1.0 : 0.0;
            float ink = LF_DPA_Number(float2(textUv.x, frac(textUv.y)), probeValue, row + 1);
            color = lerp(float3(0.015, 0.015, 0.015), float3(1.0, 1.0, 1.0), ink);
        }
    }
    return float4(color, 1.0);
}

technique LUNAR_FLOWER_DepthInputAudit
< ui_label = "Lunar Flower - Depth Input Audit";
  ui_tooltip = "Display-only framework/normal-Z/reversed-Z comparison with numeric probe values. Green means range-admissible, not proven correct geometry. Red below 1e-6; blue above 0.999999; orange outside [0,1]; magenta nonfinite. No lighting, feedback or settings changes.";
>
{
    pass DepthAudit
    {
        VertexShader = PostProcessVS;
        PixelShader = LF_DPA_Display;
    }
}
