#include "ReShade.fxh"
#ifndef LUNAR_FLOWER_TLSL_LINEAR_ADMISSION
#define LUNAR_FLOWER_TLSL_LINEAR_ADMISSION 1
#endif
#if LUNAR_FLOWER_TLSL_LINEAR_ADMISSION != 0 && LUNAR_FLOWER_TLSL_LINEAR_ADMISSION != 1
#error Admission curve must be 0 (cubic) or 1 (linear).
#endif

// Overbuilt package; existing shader identifiers retained for preset compatibility.
#ifndef LUNAR_FLOWER_TLSL_CONTINUOUS_SAMPLING
#define LUNAR_FLOWER_TLSL_CONTINUOUS_SAMPLING 1
#endif
#ifndef LUNAR_FLOWER_TLSL_REGULARIZE_NORMALS
#define LUNAR_FLOWER_TLSL_REGULARIZE_NORMALS 0
#endif
#if (LUNAR_FLOWER_TLSL_CONTINUOUS_SAMPLING != 0 && LUNAR_FLOWER_TLSL_CONTINUOUS_SAMPLING != 1) || (LUNAR_FLOWER_TLSL_REGULARIZE_NORMALS != 0 && LUNAR_FLOWER_TLSL_REGULARIZE_NORMALS != 1)
#error Experiment selections must be 0 or 1.
#endif

// These preset-level definitions specialize only this performance experiment.
#ifndef LUNAR_FLOWER_TLSL_DDA_STEPS
#define LUNAR_FLOWER_TLSL_DDA_STEPS 16
#endif
#ifndef LUNAR_FLOWER_TLSL_MARCH_STEPS
#define LUNAR_FLOWER_TLSL_MARCH_STEPS 16
#endif
#ifndef LUNAR_FLOWER_TLSL_COMPILED_PROVIDER
#define LUNAR_FLOWER_TLSL_COMPILED_PROVIDER 0
#endif
#ifndef LUNAR_FLOWER_TLSL_CACHE_FIRST_LIGHT
#define LUNAR_FLOWER_TLSL_CACHE_FIRST_LIGHT 1
#endif
#if LUNAR_FLOWER_TLSL_CACHE_FIRST_LIGHT != 0 && LUNAR_FLOWER_TLSL_CACHE_FIRST_LIGHT != 1
#error First-light cache selection must be 0 or 1.
#endif
#if LUNAR_FLOWER_TLSL_DDA_STEPS < 4 || LUNAR_FLOWER_TLSL_DDA_STEPS > 32
#error DDA sample budget must be between 4 and 32.
#endif
#if LUNAR_FLOWER_TLSL_MARCH_STEPS < 4 || LUNAR_FLOWER_TLSL_MARCH_STEPS > 32
#error March sample budget must be between 4 and 32.
#endif
#if LUNAR_FLOWER_TLSL_COMPILED_PROVIDER < -1 || LUNAR_FLOWER_TLSL_COMPILED_PROVIDER > 2
#error Provider must be -1 (runtime), 0 (both), 1 (DDA) or 2 (march).
#endif
// Ray geometry/reach stays at the parent maximum regardless of sample density.
#define CAMERA_OBSCURA_DDA_MAX_STEPS 32
#define CAMERA_OBSCURA_MARCH_MAX_STEPS LUNAR_FLOWER_TLSL_MARCH_STEPS
#if LUNAR_FLOWER_TLSL_COMPILED_PROVIDER >= 0
#define LUNAR_FLOWER_TLSL_ACTIVE_PROVIDER LUNAR_FLOWER_TLSL_COMPILED_PROVIDER
#else
#define LUNAR_FLOWER_TLSL_ACTIVE_PROVIDER LUNAR_FLOWER_TwinLanternsSpokeLabProviderMode
#endif
#ifndef LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS
#define LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS 1
#endif
#if LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS != 0 && LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS != 1
#error Donor normal cache must be 0 or 1.
#endif
#if LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS
texture2D LUNAR_FLOWER_TLSLGuideTex
{
    Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F;
};
sampler2D LUNAR_FLOWER_TLSLGuideSampler
{
    Texture = LUNAR_FLOWER_TLSLGuideTex;
    MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = CLAMP; AddressV = CLAMP;
};
#endif
#include "../api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh"
#include "../api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh"

uniform int LUNAR_FLOWER_TwinLanternsSpokeLabView
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 00 Diagnostics"; ui_label = "Output View"; ui_items = "Final Image\0Source Image\0Bounded Indirect Light\0Evidence Confidence\0Applied Light\0Rejection Reason\0Remaining Channel Room\0Containment Activity\0Source Difference\0Bound Verification\0Edge Fill Target\0Edge Fill Added\0Fidelity Guard Activity\0Overdrive Pressure\0Depth Fade Mask\0DDA Support Coverage\0March Support Coverage\0DDA Admitted Weight\0March Admitted Weight\0DDA Raw Donor Color\0March Raw Donor Color\0DDA Weighted Signal\0March Weighted Signal\0Combined Raw Donor\0Combined Weighted Signal\0Receiver Validity\0Captured First Light (8x)\0Bounce Weighted Signal (8x)\0Applied Second Bounce (8x)\0Chaos Direction Retention\0Bounce Support\0"; ui_tooltip = "Final Image is the production output.\nDiagnostic views expose reconstructed screen-space light, admission evidence, containment, rendering intent, and depth fade.\nBound Verification must remain green."; > = 0;

uniform bool LUNAR_FLOWER_TwinLanternsSpokeLabEnabled
< ui_type = "checkbox"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 01 Light"; ui_label = "Enable Indirect Light"; ui_tooltip = "Applies bounded reconstructed indirect light.\nOff returns the source image exactly while diagnostics remain available."; > = true;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 01 Light"; ui_label = "Indirect Light Strength"; ui_min = 0.00; ui_max = 4.00; ui_step = 0.001; ui_tooltip = "Scales admitted indirect light after transport normalization and reconstruction evidence.\nFine adjustment: 0.001 per step (0.1 percentage point of nominal strength).\nFor 10-30% strength, use 0.100-0.300; zero returns the source image exactly."; > = 2.000000;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabMaximumContribution
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 01 Light"; ui_label = "Maximum Added Light"; ui_min = 0.00; ui_max = 0.50; ui_step = 0.005; ui_tooltip = "Hard per-channel ceiling for added normalized SDR light.\nThe result is also limited by the remaining room in each source channel."; > = 0.20;


uniform float LUNAR_FLOWER_TwinLanternsSpokeLabDepthFadeStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 02 Depth Shaping"; ui_label = "Depth Fade Amount (0 = Off)"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Optional fade of final bounded Twin Lanterns added light.\n0 = Off; 1 = full removal at/after Fade End.\nDefault 0.355 follows the user preset; set 0 to disable fading.\nDepth uses ReShade normalized linear depth, not world distance."; > = 0.355000;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabDepthFadeStart
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 02 Depth Shaping"; ui_label = "Depth Fade Start"; ui_min = 0.00000; ui_max = 1.00000; ui_step = 0.00001; ui_tooltip = "Normalized linear depth where fading and distant-light softening begin.\nUse Depth Fade Mask to tune this for the game; these values are not calibrated distances."; > = 0.00500;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabDepthFadeEnd
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 02 Depth Shaping"; ui_label = "Depth Fade End"; ui_min = 0.00000; ui_max = 1.00000; ui_step = 0.00001; ui_tooltip = "Normalized linear depth where fade and softening reach full authority.\nEnd is treated as at least Start plus 0.000001 to avoid a zero-width transition."; > = 0.05000;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabLightSoftening
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 02 Depth Shaping"; ui_label = "Distant Light Softening"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Softens only the indirect-light field, increasing between Fade Start and End.\nFour neighboring taps are gated by Surface Depth and Direction Agreement.\nZero bypasses these taps. The source image is never blurred."; > = 1.000000;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabLightSofteningRadiusPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 02 Depth Shaping"; ui_label = "Light Softening Radius"; ui_min = 1.0; ui_max = 4.0; ui_step = 1.0; ui_tooltip = "Radius in full-resolution pixels for four surface-gated indirect-light taps.\nThe fixed radius avoids depth-driven changes in the tap footprint."; > = 2.0;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabRayLengthPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 90 Transport"; ui_label = "Transport Distance"; ui_min = 4.0; ui_max = 24.0; ui_step = 1.0; ui_tooltip = "Screen-space travel in pixels for each scheduled direction.\nChanges reach and sample spacing while maximum provider sample counts remain fixed. Actual work can vary with early hits or screen exits."; > = 24.0;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabDepthSlope
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 90 Transport"; ui_label = "Ray Depth Slope"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Controls normalized depth travel per pixel using the mean horizontal/vertical pixel pitch.\nDepth travel is independent of direction so cardinal/diagonal testing uses the same depth interval."; > = 0.16;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabFrontBias
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 90 Transport"; ui_label = "Front Surface Bias"; ui_min = 0.0000; ui_max = 0.0100; ui_step = 0.000001; ui_tooltip = "Front-side hit tolerance in normalized linear depth; this does not offset the ray origin.\nLarger values admit surfaces farther in front of the ray and also widen confidence weighting; they may increase light carry.\nFine adjustment: 0.000001 per step. Zero is valid; pixel-distance self-hit rejection is separate."; > = 0.000052;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabBackThickness
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 90 Transport"; ui_label = "Back Surface Thickness"; ui_min = 0.0000; ui_max = 0.0200; ui_step = 0.0001; ui_tooltip = "Extends the accepted hit interval behind the ray.\nLarger values admit thicker surfaces but can increase leakage."; > = 0.0035;

uniform int LUNAR_FLOWER_TwinLanternsSpokeLabSpokeMode
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 01 Spokes";
ui_label = "Primary Spokes"; ui_items = "Eight (reference)\0Three\0";
ui_tooltip = "Three uses a fixed, spread-out selection from the eight directions. It changes angular coverage. No frame cycling or temporal history is enabled."; > = 1;
uniform int LUNAR_FLOWER_TwinLanternsSpokeLabSpokeRotation
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 01 Spokes";
ui_label = "Spoke Rotation"; ui_min = 0; ui_max = 7; ui_step = 1;
ui_tooltip = "Rotates the fixed pattern in 45-degree steps. This control does not animate between frames."; > = 0;
uniform float LUNAR_FLOWER_TwinLanternsSpokeLabCheapBounceStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 04 Cached Bounce";
ui_label = "Two-Tap Bounce Strength"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
ui_tooltip = "Scales two opposing cached-first-light taps. Zero bypasses the gather. No secondary ray marches are performed."; > = 0.250;
uniform float LUNAR_FLOWER_TwinLanternsSpokeLabCheapBounceRetention
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 04 Cached Bounce";
ui_label = "Bounce Retention"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
ui_tooltip = "Energy retained from the preceding light field before distance loss."; > = 0.500;
uniform float LUNAR_FLOWER_TwinLanternsSpokeLabCheapBounceRadius
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 04 Cached Bounce";
ui_label = "Bounce Reach"; ui_min = 2.0; ui_max = 12.0; ui_step = 0.25;
ui_tooltip = "Pixel distance for the two cached-light taps. Depth and normal agreement reject incompatible surfaces."; > = 3.0;

#if LUNAR_FLOWER_TLSL_COMPILED_PROVIDER < 0
uniform int LUNAR_FLOWER_TwinLanternsSpokeLabProviderMode
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 01 Experiment"; ui_label = "Provider"; ui_items = "DDA + March\0DDA Only\0March Only\0"; ui_tooltip = "Selects the traversal providers in both production and diagnostics.\nEach selected provider is normalized by its own direction count. Budgets are set by the benchmark preset; matched tests use 16 samples per provider.\nDisabled providers are not traced."; > = 0;
#endif

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabDepthTolerance
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 91 Reconstruction"; ui_label = "Surface Depth Agreement"; ui_min = 0.0001; ui_max = 0.0500; ui_step = 0.00001; ui_tooltip = "Maximum depth disagreement admitted during reconstruction and edge fill.\nLower values reject differing-depth neighbors more strictly; higher values admit more neighboring light and may brighten or soften boundaries.\nFine adjustment: 0.00001 per step; this is a depth tolerance, not a light strength."; > = 0.0050;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabNormalMinimum
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 91 Reconstruction"; ui_label = "Surface Direction Agreement"; ui_min = 0.00; ui_max = 0.99; ui_step = 0.01; ui_tooltip = "Minimum agreement between reconstructed surface directions.\nHigher values preserve edges but may reduce support."; > = 0.80;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabEdgeProtection
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 91 Reconstruction"; ui_label = "Depth Edge Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Rejects reconstruction support near depth discontinuities.\nOne provides maximum protection against cross-surface light carry."; > = 1.00;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabEdgeInkStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 92 Style"; ui_label = "Edge Ink Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Adds the contour-heavy look created when rejected edge taps reduce visible light confidence.\nZero keeps surface rejection active without the AO-like edge emphasis.\nOne restores the original Twin Lantern edge treatment."; > = 0.00;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabEdgeFillStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 92 Style"; ui_label = "Edge Fill Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Fills only positive deficits in the reconstructed indirect-light field near depth edges.\nThe source image is never blurred and depth/normal agreement prevents cross-surface carry.\nZero bypasses all edge-fill sampling."; > = 0.20;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabEdgeFillRadiusPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 92 Style"; ui_label = "Edge Fill Radius"; ui_min = 1.00; ui_max = 4.00; ui_step = 0.25; ui_tooltip = "Distance in full-resolution pixels used to find same-surface indirect light around an edge.\nLarger values close wider dark troughs and cost the same four additional reads when fill is active."; > = 2.00;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabFidelityGuard
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 93 Intent"; ui_label = "Fidelity Guard"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Aligns transported light toward the receiver's existing color and reduces pressure near occupied highlight channels.\nIt protects the full-stack image without weakening dark-surface transport as strongly."; > = 0.65;

uniform float LUNAR_FLOWER_TwinLanternsSpokeLabOverdrive
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Spoke Lab / 93 Intent"; ui_label = "Overdrive"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Raises admitted Twin Lantern energy up to three times before hard contribution and channel-room bounds.\nOverdrive and Fidelity Guard can run together."; > = 0.00;

static const float LUNAR_FLOWER_TwinLanternsSpokeLabBounceStrength = 0.0;

static const float LUNAR_FLOWER_TwinLanternsSpokeLabBounceRetention = 0.500;

static const float LUNAR_FLOWER_TwinLanternsSpokeLabBounceDistanceDecay = 1.0;

static const float LUNAR_FLOWER_TwinLanternsSpokeLabColorAnchor = 0.500;

static const float LUNAR_FLOWER_TwinLanternsSpokeLabChaosAmount = 0.0;

static const int LUNAR_FLOWER_TwinLanternsSpokeLabChaosMode = 2;

static const int LUNAR_FLOWER_TwinLanternsSpokeLabChaosSeed = 17;

bool LUNAR_FLOWER_TLSLSourceOnly()
{
    return LUNAR_FLOWER_TwinLanternsSpokeLabView == 1 ||
        (LUNAR_FLOWER_TwinLanternsSpokeLabView == 0 &&
         (!LUNAR_FLOWER_TwinLanternsSpokeLabEnabled ||
          LUNAR_FLOWER_TwinLanternsSpokeLabStrength <= 0.0));
}

#if LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS
float4 LUNAR_FLOWER_TLSLGuide_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLSLSourceOnly()) return float4(0.0, 0.0, 1.0, 0.0);
    float center = CAMERA_OBSCURA_LoadDepth(uv);
    if (CAMERA_OBSCURA_DepthConfidence(center) < 0.5) return float4(0.0, 0.0, 1.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide guide = LUNAR_FLOWER_TLSLBuildSurfaceGuideFromDepth(uv, center);
    return float4(guide.normal, guide.valid);
}
#endif

bool LUNAR_FLOWER_TLSLNeedsTransportFields()
{
    int view = LUNAR_FLOWER_TwinLanternsSpokeLabView;
    return !LUNAR_FLOWER_TLSLSourceOnly() &&
        (view < 14 || (view >= 26 && view <= 30 && view != 29));
}

bool LUNAR_FLOWER_TLSLBounceActive()
{
    // Keep the first-light capture/final cache active even when extra bounce
    // is zero. The cheap gather itself has a separate early bypass.
    return LUNAR_FLOWER_TwinLanternsSpokeLabEnabled &&
        LUNAR_FLOWER_TwinLanternsSpokeLabStrength > 0.0;
}

texture2D LUNAR_FLOWER_TLSLFirstLightTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};
texture2D LUNAR_FLOWER_TLSLBounceTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};
sampler2D LUNAR_FLOWER_TLSLFirstLightSampler
{
    Texture = LUNAR_FLOWER_TLSLFirstLightTex;
    MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D LUNAR_FLOWER_TLSLBounceSampler
{
    Texture = LUNAR_FLOWER_TLSLBounceTex;
    MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = CLAMP; AddressV = CLAMP;
};

texture2D LUNAR_FLOWER_TLSLRawTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

texture2D LUNAR_FLOWER_TLSLResolveHTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

texture2D LUNAR_FLOWER_TLSLResolveVTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler2D LUNAR_FLOWER_TLSLRawSampler
{
    Texture = LUNAR_FLOWER_TLSLRawTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D LUNAR_FLOWER_TLSLResolveHSampler
{
    Texture = LUNAR_FLOWER_TLSLResolveHTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D LUNAR_FLOWER_TLSLResolveVSampler
{
    Texture = LUNAR_FLOWER_TLSLResolveVTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

float2 LUNAR_FLOWER_TLSLFullTexel()
{
    return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
}

float LUNAR_FLOWER_TLSLRequestedCoverage(float2 requestedUv)
{
    return
        step(0.0, requestedUv.x) *
        step(requestedUv.x, 1.0) *
        step(0.0, requestedUv.y) *
        step(requestedUv.y, 1.0);
}

float LUNAR_FLOWER_TwinLanternsSpokeLabStyledEdgeProtection()
{
    return saturate(LUNAR_FLOWER_TwinLanternsSpokeLabEdgeProtection) *
        saturate(LUNAR_FLOWER_TwinLanternsSpokeLabEdgeInkStrength);
}

CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLSLEvaluateHorizontal(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        LUNAR_FLOWER_TLSLBuildSurfaceGuide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(LUNAR_FLOWER_TLSLFullTexel().x, 0.0);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = LUNAR_FLOWER_TLSLRequestedCoverage(negativeRequested);
    float positiveAvailable = LUNAR_FLOWER_TLSLRequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(LUNAR_FLOWER_TLSLRawSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            LUNAR_FLOWER_TLSLRawSampler, negativeRequested);
        negativeGuide = LUNAR_FLOWER_TLSLBuildSurfaceGuide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            LUNAR_FLOWER_TLSLRawSampler, positiveRequested);
        positiveGuide = LUNAR_FLOWER_TLSLBuildSurfaceGuide(positiveRequested);
    }

    return CAMERA_OBSCURA_API_ResolveTL08Axis(
        negativeValue,
        centerValue,
        positiveValue,
        negativeGuide,
        centerGuide,
        positiveGuide,
        negativeAvailable,
        positiveAvailable,
        LUNAR_FLOWER_TwinLanternsSpokeLabDepthTolerance,
        LUNAR_FLOWER_TwinLanternsSpokeLabNormalMinimum,
        LUNAR_FLOWER_TwinLanternsSpokeLabStyledEdgeProtection());
}

CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLSLEvaluateVertical(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        LUNAR_FLOWER_TLSLBuildSurfaceGuide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(0.0, LUNAR_FLOWER_TLSLFullTexel().y);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = LUNAR_FLOWER_TLSLRequestedCoverage(negativeRequested);
    float positiveAvailable = LUNAR_FLOWER_TLSLRequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(LUNAR_FLOWER_TLSLResolveHSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            LUNAR_FLOWER_TLSLResolveHSampler, negativeRequested);
        negativeGuide = LUNAR_FLOWER_TLSLBuildSurfaceGuide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            LUNAR_FLOWER_TLSLResolveHSampler, positiveRequested);
        positiveGuide = LUNAR_FLOWER_TLSLBuildSurfaceGuide(positiveRequested);
    }

    return CAMERA_OBSCURA_API_ResolveTL08Axis(
        negativeValue,
        centerValue,
        positiveValue,
        negativeGuide,
        centerGuide,
        positiveGuide,
        negativeAvailable,
        positiveAvailable,
        LUNAR_FLOWER_TwinLanternsSpokeLabDepthTolerance,
        LUNAR_FLOWER_TwinLanternsSpokeLabNormalMinimum,
        LUNAR_FLOWER_TwinLanternsSpokeLabStyledEdgeProtection());
}

int LUNAR_FLOWER_TLSLDirectionCount()
{
    return LUNAR_FLOWER_TwinLanternsSpokeLabSpokeMode == 1 ? 3 : 8;
}

float LUNAR_FLOWER_TLSLDirectionIndex(int slot)
{
    int direction = slot;
    if (LUNAR_FLOWER_TwinLanternsSpokeLabSpokeMode == 1)
        direction = slot == 0 ? 0 : (slot == 1 ? 3 : 5);
    return (float)((direction + LUNAR_FLOWER_TwinLanternsSpokeLabSpokeRotation) & 7);
}

struct LUNAR_FLOWER_TLSLDirectionEvidence
{
    float4 combined;
    float3 dda_donor_sum;
    float3 march_donor_sum;
    float3 dda_signal;
    float3 march_signal;
    float dda_hits;
    float march_hits;
    float dda_weight;
    float march_weight;
    float receiver_valid;
};

LUNAR_FLOWER_TLSLDirectionEvidence LUNAR_FLOWER_TLSLEvaluateDirections(float2 uv)
{
    LUNAR_FLOWER_TLSLDirectionEvidence result;
    result.combined = float4(0.0, 0.0, 0.0, 0.0);
    result.dda_donor_sum = float3(0.0, 0.0, 0.0);
    result.march_donor_sum = float3(0.0, 0.0, 0.0);
    result.dda_signal = float3(0.0, 0.0, 0.0);
    result.march_signal = float3(0.0, 0.0, 0.0);
    result.dda_hits = 0.0;
    result.march_hits = 0.0;
    result.dda_weight = 0.0;
    result.march_weight = 0.0;
    CAMERA_OBSCURA_SurfaceGuide receiver = LUNAR_FLOWER_TLSLBuildSurfaceGuide(uv);
    result.receiver_valid = receiver.valid;
    if (receiver.valid < 0.5) return result;
    int directionCount = LUNAR_FLOWER_TLSLDirectionCount();
    float3 weightedDonor = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    [loop]
    for (int slot = 0; slot < 8; ++slot)
    {
        if (slot >= directionCount) break;
        LUNAR_FLOWER_TLSLScreenEvidence screen = LUNAR_FLOWER_TLSLTraceScreenDetailed(
            uv, LUNAR_FLOWER_TLSLDirectionIndex(slot),
            LUNAR_FLOWER_TwinLanternsSpokeLabRayLengthPixels,
            LUNAR_FLOWER_TwinLanternsSpokeLabDepthSlope,
            LUNAR_FLOWER_TwinLanternsSpokeLabFrontBias,
            LUNAR_FLOWER_TwinLanternsSpokeLabBackThickness,
            LUNAR_FLOWER_TLSL_ACTIVE_PROVIDER,
            true, receiver);
        weightedDonor += screen.combined.rgb * screen.combined.a;
        evidenceSum += screen.combined.a;
        result.dda_donor_sum += screen.dda_sample.rgb * screen.dda_hit;
        result.march_donor_sum += screen.march_sample.rgb * screen.march_hit;
        result.dda_signal += screen.dda_sample.rgb * screen.dda_sample.a;
        result.march_signal += screen.march_sample.rgb * screen.march_sample.a;
        result.dda_hits += screen.dda_hit;
        result.march_hits += screen.march_hit;
        result.dda_weight += screen.dda_sample.a;
        result.march_weight += screen.march_sample.a;
    }
    result.combined = float4(
        weightedDonor * CAMERA_OBSCURA_SafeRcp(evidenceSum, 0.0) * step(0.000001, evidenceSum),
        saturate(evidenceSum / (float)directionCount));
    float inverseCount = 1.0 / (float)directionCount;
    result.dda_donor_sum *= CAMERA_OBSCURA_SafeRcp(result.dda_hits, 0.0);
    result.march_donor_sum *= CAMERA_OBSCURA_SafeRcp(result.march_hits, 0.0);
    result.dda_signal *= inverseCount;
    result.march_signal *= inverseCount;
    result.dda_hits *= inverseCount;
    result.march_hits *= inverseCount;
    result.dda_weight *= inverseCount;
    result.march_weight *= inverseCount;
    return result;
}

float4 LUNAR_FLOWER_TLSLRaw_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLSLSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (!LUNAR_FLOWER_TLSLNeedsTransportFields()) return float4(0.0, 0.0, 0.0, 0.0);
    return LUNAR_FLOWER_TLSLEvaluateDirections(uv).combined;
}

float LUNAR_FLOWER_TLSLVisibleConfidence(
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence)
{
    float negativeCapacity = 0.5 *
        evidence.negative_depth_support *
        evidence.negative_normal_support *
        evidence.negative_edge_support;
    float positiveCapacity = 0.5 *
        evidence.positive_depth_support *
        evidence.positive_normal_support *
        evidence.positive_edge_support;
    float admittedCapacity =
        evidence.center_valid + negativeCapacity + positiveCapacity;
    float hasCapacity = step(0.000001, admittedCapacity);
    float neutralConfidence = saturate(
        evidence.weight_sum *
        CAMERA_OBSCURA_SafeRcp(admittedCapacity, 0.0)) * hasCapacity;
    float visibleConfidence = lerp(
        neutralConfidence,
        evidence.trusted_weight,
        saturate(LUNAR_FLOWER_TwinLanternsSpokeLabEdgeInkStrength));
    return saturate(visibleConfidence);
}

float4 LUNAR_FLOWER_TLSLResolveH_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLSLSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (!LUNAR_FLOWER_TLSLNeedsTransportFields()) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        LUNAR_FLOWER_TLSLEvaluateHorizontal(uv);
    return float4(
        evidence.resolved_rgb,
        LUNAR_FLOWER_TLSLVisibleConfidence(evidence));
}

float4 LUNAR_FLOWER_TLSLResolveV_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLSLSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (!LUNAR_FLOWER_TLSLNeedsTransportFields()) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        LUNAR_FLOWER_TLSLEvaluateVertical(uv);
    return float4(
        evidence.resolved_rgb,
        LUNAR_FLOWER_TLSLVisibleConfidence(evidence));
}

float4 LUNAR_FLOWER_TLSLFullResolutionReconstruct(float2 uv, CAMERA_OBSCURA_SurfaceGuide centerGuide)
{
    if (centerGuide.valid < 0.5)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    float4 resolved = tex2Dlod(LUNAR_FLOWER_TLSLResolveVSampler, float4(uv, 0.0, 0.0));
    float trustedEvidence = saturate(resolved.a) *
        saturate(centerGuide.depth_confidence);
    return float4(saturate(resolved.rgb), trustedEvidence);
}

void LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(
    float2 requestedUv,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    inout float3 signalSum,
    inout float evidenceSum,
    inout float supportSum)
{
    float coverage = LUNAR_FLOWER_TLSLRequestedCoverage(requestedUv);
    [branch]
    if (coverage > 0.5)
    {
        CAMERA_OBSCURA_SurfaceGuide tapGuide =
            LUNAR_FLOWER_TLSLBuildSurfaceGuide(requestedUv);
        float depthSupport = CAMERA_OBSCURA_API_TL08DepthSupport(
            centerGuide, tapGuide, LUNAR_FLOWER_TwinLanternsSpokeLabDepthTolerance);
        float normalSupport = CAMERA_OBSCURA_API_TL08NormalSupport(
            centerGuide, tapGuide, LUNAR_FLOWER_TwinLanternsSpokeLabNormalMinimum);
        float surfaceSupport = coverage * depthSupport * normalSupport;
        float4 sampleValue = tex2Dlod(
            LUNAR_FLOWER_TLSLResolveVSampler, float4(requestedUv, 0.0, 0.0));
        float sampleEvidence = saturate(sampleValue.a);

        signalSum += saturate(sampleValue.rgb) *
            sampleEvidence * surfaceSupport;
        evidenceSum += sampleEvidence * surfaceSupport;
        supportSum += surfaceSupport;
    }
}

float4 LUNAR_FLOWER_TLSLApplyEdgeFill(
    float2 uv,
    float4 baseIndirect,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    out float edgeFillTarget,
    out float3 edgeFillAdded)
{
    edgeFillTarget = 0.0;
    edgeFillAdded = float3(0.0, 0.0, 0.0);
    float safeStrength = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabEdgeFillStrength);
    [branch]
    if (safeStrength <= 0.000001)
    {
        return baseIndirect;
    }

    [branch]
    if (centerGuide.valid < 0.5)
    {
        return baseIndirect;
    }

    float safeRadius = clamp(
        LUNAR_FLOWER_TwinLanternsSpokeLabEdgeFillRadiusPixels, 1.0, 4.0);
    float2 offset = float2(
        BUFFER_RCP_WIDTH * safeRadius,
        BUFFER_RCP_HEIGHT * safeRadius);
    float3 signalSum = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    float supportSum = 0.0;

    LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(
        uv - float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(
        uv + float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(
        uv - float2(0.0, offset.y), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(
        uv + float2(0.0, offset.y), centerGuide,
        signalSum, evidenceSum, supportSum);

    float hasSupport = step(0.000001, supportSum);
    float inverseSupport = CAMERA_OBSCURA_SafeRcp(supportSum, 0.0);
    float3 neighborSignal = signalSum * inverseSupport * hasSupport;
    float neighborEvidence = saturate(
        evidenceSum * inverseSupport * hasSupport);
    float baseEvidence = saturate(baseIndirect.a);
    float3 baseSignal = saturate(baseIndirect.rgb) * baseEvidence;
    float3 positiveDeficit = max(neighborSignal - baseSignal, 0.0.xxx);
    float edgeMask = saturate(centerGuide.edge_risk);
    float fillAuthority = safeStrength * edgeMask;
    float3 filledSignal = baseSignal + positiveDeficit * fillAuthority;
    float filledEvidence = lerp(
        baseEvidence,
        max(baseEvidence, neighborEvidence),
        fillAuthority);
    float hasFilledEvidence = step(0.000001, filledEvidence);
    float3 filledColor = filledSignal *
        CAMERA_OBSCURA_SafeRcp(filledEvidence, 0.0) * hasFilledEvidence;

    edgeFillTarget = edgeMask * hasSupport;
    edgeFillAdded = max(filledSignal - baseSignal, 0.0.xxx);
    return float4(saturate(filledColor), saturate(filledEvidence));
}


float LUNAR_FLOWER_TLSLDepthPhase(float receiverDepth)
{
    float start = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabDepthFadeStart);
    float end = max(saturate(LUNAR_FLOWER_TwinLanternsSpokeLabDepthFadeEnd), start + 0.000001);
    return smoothstep(start, end, saturate(receiverDepth));
}

float LUNAR_FLOWER_TLSLDepthFadeFactor(float receiverDepth)
{
    return 1.0 - saturate(LUNAR_FLOWER_TwinLanternsSpokeLabDepthFadeStrength) *
        LUNAR_FLOWER_TLSLDepthPhase(receiverDepth);
}

float4 LUNAR_FLOWER_TLSLApplyDepthShaping(
    float2 uv, float4 baseIndirect, CAMERA_OBSCURA_SurfaceGuide centerGuide)
{
    if (LUNAR_FLOWER_TwinLanternsSpokeLabDepthFadeStrength <= 0.0 &&
        LUNAR_FLOWER_TwinLanternsSpokeLabLightSoftening <= 0.0)
        return baseIndirect;
    if (centerGuide.valid < 0.5) return float4(0.0, 0.0, 0.0, 0.0);
    float phase = LUNAR_FLOWER_TLSLDepthPhase(centerGuide.depth);
    float fade = LUNAR_FLOWER_TLSLDepthFadeFactor(centerGuide.depth);
    if (fade <= 0.0) return baseIndirect; // Final composite removes the light; skip softening work.
    float amount = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabLightSoftening) * phase;
    float4 shaped = baseIndirect;
    [branch]
    if (amount > 0.000001)
    {
        float radius = clamp(LUNAR_FLOWER_TwinLanternsSpokeLabLightSofteningRadiusPixels, 1.0, 4.0);
        float2 offset = LUNAR_FLOWER_TLSLFullTexel() * radius;
        float baseEvidence = saturate(baseIndirect.a);
        float3 baseSignal = saturate(baseIndirect.rgb) * baseEvidence;
        float3 signalSum = baseSignal;
        float evidenceSum = baseEvidence;
        float supportSum = 1.0;
        // Existing depth/normal/coverage-gated taps read only ResolveV light.
        LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(uv - float2(offset.x, 0.0), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(uv + float2(offset.x, 0.0), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(uv - float2(0.0, offset.y), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLSLAccumulateEdgeFillTap(uv + float2(0.0, offset.y), centerGuide, signalSum, evidenceSum, supportSum);
        float inverseSupport = CAMERA_OBSCURA_SafeRcp(supportSum, 0.0);
        float3 meanSignal = signalSum * inverseSupport;
        float meanEvidence = saturate(evidenceSum * inverseSupport);
        float3 mixedSignal = lerp(baseSignal, meanSignal, amount);
        float mixedEvidence = saturate(lerp(baseEvidence, meanEvidence, amount));
        float hasEvidence = step(0.000001, mixedEvidence);
        float3 mixedColor = mixedSignal * CAMERA_OBSCURA_SafeRcp(mixedEvidence, 0.0) * hasEvidence;
        shaped = float4(saturate(mixedColor), mixedEvidence);
    }
    // Energy fade is applied after the final hard bounds, not to this evidence.
    return shaped;
}

float4 LUNAR_FLOWER_TLSLApplyRenderIntent(
    float3 source,
    float4 reconstructed,
    out float fidelityActivity,
    out float overdrivePressure,
    out float effectiveStrength)
{
    fidelityActivity = 0.0;
    overdrivePressure = 0.0;
    effectiveStrength = max(LUNAR_FLOWER_TwinLanternsSpokeLabStrength, 0.0);
    float safeFidelity = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabFidelityGuard);
    float safeOverdrive = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabOverdrive);
    float3 safeSource = saturate(source);
    float3 safeIndirect = saturate(reconstructed.rgb);
    float sourceLuma = CAMERA_OBSCURA_Luma(safeSource);
    float indirectLuma = CAMERA_OBSCURA_Luma(safeIndirect);
    float sourcePeak = max(max(safeSource.r, safeSource.g), safeSource.b);
    float receiverAvailable = smoothstep(0.02, 0.15, sourceLuma);
    float3 receiverAligned = safeSource * indirectLuma *
        CAMERA_OBSCURA_SafeRcp(sourceLuma, 0.0);
    receiverAligned = lerp(
        indirectLuma.xxx,
        saturate(receiverAligned),
        receiverAvailable);
    float3 fidelityIndirect = lerp(
        safeIndirect,
        receiverAligned,
        safeFidelity);
    float highlightRisk = smoothstep(0.65, 0.98, sourcePeak);
    float highlightGain = 1.0 - safeFidelity * highlightRisk * 0.85;
    float overdriveGain = 1.0 + safeOverdrive * 2.0;
    effectiveStrength = max(LUNAR_FLOWER_TwinLanternsSpokeLabStrength, 0.0) *
        highlightGain * overdriveGain;
    fidelityActivity = saturate(
        safeFidelity *
        (highlightRisk + CAMERA_OBSCURA_Luma(
            abs(fidelityIndirect - safeIndirect))));
    overdrivePressure = saturate(
        safeOverdrive *
        CAMERA_OBSCURA_Luma(fidelityIndirect) *
        saturate(reconstructed.a) * 2.0);
    return float4(saturate(fidelityIndirect), saturate(reconstructed.a));
}


CAMERA_OBSCURA_API_TL09CompositeEvidence
LUNAR_FLOWER_TLSLFadeComposite(
    CAMERA_OBSCURA_API_TL09CompositeEvidence result, float receiverDepth)
{
    float fade = LUNAR_FLOWER_TLSLDepthFadeFactor(receiverDepth);
    if (fade >= 1.0) return result;
    float wasApplied = result.application;
    // Scale already bounded energy: neither contribution nor channel-room
    // clipping can conceal a partial fade. The original source stays exact.
    result.weighted_indirect_rgb *= fade;
    result.bounded_indirect_rgb *= fade;
    result.bounded_contribution_rgb *= fade;
    result.evidence *= fade;
    result.maximum_contribution *= fade;
    result.final_rgb = result.source_rgb + result.bounded_contribution_rgb;
    result.containment_activity = saturate(CAMERA_OBSCURA_Luma(
        max(result.weighted_indirect_rgb - result.bounded_contribution_rgb, 0.0.xxx)));
    result.source_preserve_delta = CAMERA_OBSCURA_Luma(
        abs(result.final_rgb - result.source_rgb));
    result.admission *= fade > 0.0 ? 1.0 : 0.0;
    float contributionMaximum = max(max(result.bounded_contribution_rgb.r,
        result.bounded_contribution_rgb.g), result.bounded_contribution_rgb.b);
    result.application = result.admission * step(0.000001, contributionMaximum);
    result.rejection = 1.0 - result.application;
    if (wasApplied > 0.5 && result.application < 0.5) result.rejection_code = 7.0;
    // Multiplying a valid nonnegative contribution by [0,1] preserves its
    // original hard bounds. Keep any pre-existing failure flag visible.
    return result;
}

CAMERA_OBSCURA_API_TL09CompositeEvidence
LUNAR_FLOWER_TLSLEvaluateFirstComposite(
    float2 uv,
    out float edgeFillTarget,
    out float3 edgeFillAdded,
    out float fidelityActivity,
    out float overdrivePressure)
{
    CAMERA_OBSCURA_SurfaceGuide centerGuide = LUNAR_FLOWER_TLSLBuildSurfaceGuide(uv);
    float4 vertical = LUNAR_FLOWER_TLSLFullResolutionReconstruct(uv, centerGuide);
    float4 reconstructed = LUNAR_FLOWER_TLSLApplyEdgeFill(
        uv, vertical, centerGuide, edgeFillTarget, edgeFillAdded);
    reconstructed = LUNAR_FLOWER_TLSLApplyDepthShaping(uv, reconstructed, centerGuide);
    float3 source = saturate(tex2Dlod(ReShade::BackBuffer, float4(uv, 0.0, 0.0)).rgb);
    float effectiveStrength = 0.0;
    float4 intended = LUNAR_FLOWER_TLSLApplyRenderIntent(
        source,
        reconstructed,
        fidelityActivity,
        overdrivePressure,
        effectiveStrength);
    float receiverValid = centerGuide.valid;
    CAMERA_OBSCURA_API_TL09CompositeEvidence result = CAMERA_OBSCURA_API_BuildTL09Composite(
        source,
        intended.rgb,
        intended.a,
        receiverValid,
        LUNAR_FLOWER_TwinLanternsSpokeLabEnabled ? 1.0 : 0.0,
        effectiveStrength,
        LUNAR_FLOWER_TwinLanternsSpokeLabMaximumContribution);
    return LUNAR_FLOWER_TLSLFadeComposite(result, centerGuide.depth);
}

float LUNAR_FLOWER_TLSLChaosRetention(float2 uv, float directionIndex)
{
    float amount = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabChaosAmount);
    if (amount <= 0.0) return 1.0;
    float seed = (float)LUNAR_FLOWER_TwinLanternsSpokeLabChaosSeed;
    float2 pixel = floor(uv / CAMERA_OBSCURA_PixelSize());
    float noise = CAMERA_OBSCURA_StableNoise01(pixel +
        float2(directionIndex * 19.17 + seed * 7.13, directionIndex * 43.71 + seed * 11.37));
    if (LUNAR_FLOWER_TwinLanternsSpokeLabChaosMode == 1)
        return noise >= amount ? 1.0 : 0.0;
    if (LUNAR_FLOWER_TwinLanternsSpokeLabChaosMode == 2 && noise < amount * 0.5)
        return 0.0;
    float variation = CAMERA_OBSCURA_StableNoise01(pixel +
        float2(directionIndex * 37.11 + seed * 3.17, directionIndex * 13.79 + seed * 23.41));
    return 1.0 - amount * variation;
}

float LUNAR_FLOWER_TLSLBounceDistanceGain(float distancePixels)
{
    float extraDecay = max(LUNAR_FLOWER_TwinLanternsSpokeLabBounceDistanceDecay, 0.0);
    if (extraDecay <= 0.0) return 1.0;
    float remaining = saturate(1.0 - max(distancePixels, 0.0) /
        max(LUNAR_FLOWER_TwinLanternsSpokeLabRayLengthPixels, 1.0));
    return pow(remaining, extraDecay);
}

float4 LUNAR_FLOWER_TLSLFirstLight_PS(
    float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    if (!LUNAR_FLOWER_TLSLNeedsTransportFields() ||
        (!LUNAR_FLOWER_TLSLBounceActive() && LUNAR_FLOWER_TwinLanternsSpokeLabView != 26))
        return float4(0.0, 0.0, 0.0, 0.0);
    float target = 0.0, fidelity = 0.0, pressure = 0.0;
    float3 fill = float3(0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL09CompositeEvidence first =
        LUNAR_FLOWER_TLSLEvaluateFirstComposite(uv, target, fill, fidelity, pressure);
    // RGB is actual bounded, faded added light, not source color or final color.
    return float4(first.bounded_contribution_rgb, first.admission);
}

void LUNAR_FLOWER_TLSLAccumulateBounceHit(
    float2 hitUv, float sampleWeight, float distancePixels, float retention,
    inout float3 signal, inout float support)
{
    float weight = saturate(sampleWeight) * saturate(retention) *
        LUNAR_FLOWER_TLSLBounceDistanceGain(distancePixels);
    if (weight <= 0.0) return;
    float4 firstLight = tex2Dlod(LUNAR_FLOWER_TLSLFirstLightSampler, float4(hitUv, 0.0, 0.0));
    float admitted = weight * saturate(firstLight.a);
    signal += max(firstLight.rgb, 0.0.xxx) * admitted;
    support += admitted;
}

float4 LUNAR_FLOWER_TLSLBounce_PS(
    float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float gain = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabCheapBounceStrength) *
        saturate(LUNAR_FLOWER_TwinLanternsSpokeLabCheapBounceRetention);
    if (!LUNAR_FLOWER_TLSLNeedsTransportFields() || !LUNAR_FLOWER_TLSLBounceActive() ||
        gain <= 0.0 || LUNAR_FLOWER_TwinLanternsSpokeLabView == 26)
        return float4(0.0, 0.0, 0.0, 0.0);
    float depth = CAMERA_OBSCURA_LoadDepth(uv);
    if (CAMERA_OBSCURA_DepthConfidence(depth) < 0.5)
        return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide receiver = CAMERA_OBSCURA_API_DefaultTL08Guide();
    receiver.depth = depth;
    receiver.valid = 1.0;
    receiver.depth_confidence = 1.0;
#if LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS
    float4 receiverNormal = tex2Dlod(LUNAR_FLOWER_TLSLGuideSampler, float4(uv, 0.0, 0.0));
    receiver.normal = receiverNormal.rgb;
    receiver.valid *= saturate(receiverNormal.a);
#else
    receiver = LUNAR_FLOWER_TLSLBuildSurfaceGuideFromDepth(uv, depth);
#endif
    if (receiver.valid < 0.5) return float4(0.0, 0.0, 0.0, 0.0);
    float3 signal = float3(0.0, 0.0, 0.0);
    float support = 0.0;
    float radius = clamp(LUNAR_FLOWER_TwinLanternsSpokeLabCheapBounceRadius, 2.0, 12.0);
    float2 pixel = CAMERA_OBSCURA_PixelSize();
    [loop]
    for (int slot = 0; slot < 2; ++slot)
    {
        // Opposing screen directions, not a normal-reflected physical ray.
        int opposite = ((int)LUNAR_FLOWER_TLSLDirectionIndex(slot) + 4) & 7;
        float2 sampleUv = uv + CAMERA_OBSCURA_API_TL45Direction((float)opposite) * radius * pixel;
        if (sampleUv.x < 0.0 || sampleUv.x > 1.0 || sampleUv.y < 0.0 || sampleUv.y > 1.0) continue;
        float sampleDepth = CAMERA_OBSCURA_LoadDepth(sampleUv);
        if (CAMERA_OBSCURA_DepthConfidence(sampleDepth) < 0.5) continue;
        CAMERA_OBSCURA_SurfaceGuide donor = CAMERA_OBSCURA_API_DefaultTL08Guide();
        donor.depth = sampleDepth;donor.valid = 1.0;donor.depth_confidence = 1.0;
#if LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS
        float4 donorNormal = tex2Dlod(LUNAR_FLOWER_TLSLGuideSampler, float4(sampleUv, 0.0, 0.0));
        donor.normal = donorNormal.rgb;donor.valid *= saturate(donorNormal.a);
#else
        donor = LUNAR_FLOWER_TLSLBuildSurfaceGuideFromDepth(sampleUv, sampleDepth);
#endif
        float surface = CAMERA_OBSCURA_API_TL08DepthSupport(receiver, donor,
            LUNAR_FLOWER_TwinLanternsSpokeLabDepthTolerance) *
            CAMERA_OBSCURA_API_TL08NormalSupport(receiver, donor,
            LUNAR_FLOWER_TwinLanternsSpokeLabNormalMinimum);
        float distancePixels = length((sampleUv - uv) / pixel);
        if (surface <= 0.0 || distancePixels <= 1.5) continue;
        float4 first = tex2Dlod(LUNAR_FLOWER_TLSLFirstLightSampler, float4(sampleUv, 0.0, 0.0));
        float weight = surface * saturate(first.a) *
            saturate(1.0 - distancePixels / max(LUNAR_FLOWER_TwinLanternsSpokeLabRayLengthPixels, 1.0));
        float maximum = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabMaximumContribution);
        signal += min(max(first.rgb, 0.0.xxx), maximum.xxx) * weight;
        support += weight;
    }
    // Missing taps lose energy. Never renormalize by surviving donors.
    return float4(signal * (gain * 0.5), saturate(support * 0.5));
}


float3 LUNAR_FLOWER_TLSLAnchorBounceColor(float3 signal, float3 firstLight)
{
    float amount = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabColorAnchor);
    if (amount <= 0.0) return signal;
    float peak = max(max(signal.r, signal.g), signal.b);
    float3 lumaWeights = float3(0.2126, 0.7152, 0.0722);
    float signalLuma = dot(signal, lumaWeights);
    float firstLuma = dot(firstLight, lumaWeights);
    if (peak <= 0.0 || firstLuma <= 0.000001) return signal;
    float3 anchored = firstLight * (signalLuma / firstLuma);
    float3 mixed = lerp(signal, anchored, amount);
    float mixedPeak = max(max(mixed.r, mixed.g), mixed.b);
    // Mixing equal-luminance colors preserves luminance. A uniform reduction
    // then prevents any peak increase while retaining the resulting hue.
    float reduction = min(1.0, peak / max(mixedPeak, 0.000001));
    return mixed * reduction;
}

CAMERA_OBSCURA_API_TL09CompositeEvidence LUNAR_FLOWER_TLSLAddBounce(
    CAMERA_OBSCURA_API_TL09CompositeEvidence first, float3 bounceSignal, float receiverDepth)
{
    if (!LUNAR_FLOWER_TLSLBounceActive() || first.receiver_valid < 0.5) return first;
    float3 signal = LUNAR_FLOWER_TLSLAnchorBounceColor(max(bounceSignal, 0.0.xxx),
        first.bounded_contribution_rgb);
    float fade = LUNAR_FLOWER_TLSLDepthFadeFactor(receiverDepth);
    float maximumContribution = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabMaximumContribution);
    float3 ceiling = min(maximumContribution.xxx,
        first.remaining_room_rgb) * fade;
    float3 available = max(ceiling - first.bounded_contribution_rgb, 0.0.xxx);
    float3 extra = min(signal * fade, available);
    first.weighted_indirect_rgb += signal * fade;
    first.bounded_indirect_rgb += extra;
    first.bounded_contribution_rgb += extra;
    first.final_rgb = first.source_rgb + first.bounded_contribution_rgb;
    float peak = max(max(first.bounded_contribution_rgb.r, first.bounded_contribution_rgb.g),
        first.bounded_contribution_rgb.b);
    first.application = step(0.000001, peak);
    first.admission = max(first.admission, first.application);
    first.rejection = 1.0 - first.application;
    if (first.application > 0.5) first.rejection_code = 0.0;
    first.source_preserve_delta = CAMERA_OBSCURA_Luma(abs(first.final_rgb - first.source_rgb));
    first.containment_activity = saturate(CAMERA_OBSCURA_Luma(max(
        first.weighted_indirect_rgb - first.bounded_contribution_rgb, 0.0.xxx)));
    float3 violation = max(first.bounded_contribution_rgb - ceiling, 0.0.xxx) +
        max(-first.bounded_contribution_rgb, 0.0.xxx) + max(first.final_rgb - 1.0.xxx, 0.0.xxx);
    float error = max(max(violation.r, violation.g), violation.b);
    first.bounds_valid *= 1.0 - step(0.000001, error);
    return first;
}

CAMERA_OBSCURA_API_TL09CompositeEvidence LUNAR_FLOWER_TLSLEvaluateComposite(
    float2 uv, out float edgeFillTarget, out float3 edgeFillAdded,
    out float fidelityActivity, out float overdrivePressure)
{
    CAMERA_OBSCURA_API_TL09CompositeEvidence first = LUNAR_FLOWER_TLSLEvaluateFirstComposite(
        uv, edgeFillTarget, edgeFillAdded, fidelityActivity, overdrivePressure);
    if (!LUNAR_FLOWER_TLSLBounceActive()) return first;
    float4 bounce = tex2Dlod(LUNAR_FLOWER_TLSLBounceSampler, float4(uv, 0.0, 0.0));
    return LUNAR_FLOWER_TLSLAddBounce(first, bounce.rgb, CAMERA_OBSCURA_LoadDepth(uv));
}

float3 LUNAR_FLOWER_TLSLCachedContribution(float2 uv, out float3 source)
{
    source = saturate(tex2Dlod(ReShade::BackBuffer, float4(uv, 0.0, 0.0)).rgb);
    float depth = CAMERA_OBSCURA_LoadDepth(uv);
    // BuildSurfaceGuide uses this same center-depth validity rule. Its normal
    // and four neighboring depths are unnecessary for an already shaped field.
    if (CAMERA_OBSCURA_DepthConfidence(depth) < 0.5) return float3(0.0, 0.0, 0.0);
    float fade = LUNAR_FLOWER_TLSLDepthFadeFactor(depth);
    float maximumContribution = saturate(LUNAR_FLOWER_TwinLanternsSpokeLabMaximumContribution);
    float3 ceiling = min(maximumContribution.xxx, max(1.0.xxx - source, 0.0.xxx)) * fade;
    float4 captured = tex2Dlod(LUNAR_FLOWER_TLSLFirstLightSampler, float4(uv, 0.0, 0.0));
    // Captured RGB already includes first-pass strength, shaping and fade.
    // RGBA16F storage can round upward: restore the exact receiver ceiling.
    float3 firstLight = min(max(captured.rgb, 0.0.xxx), ceiling);
    float4 bounce = tex2Dlod(LUNAR_FLOWER_TLSLBounceSampler, float4(uv, 0.0, 0.0));
    float firstPeak = max(max(firstLight.r, firstLight.g), firstLight.b);
    float bouncePeak = max(max(bounce.x, bounce.y), bounce.z);
    [branch]
    if (LUNAR_FLOWER_TwinLanternsSpokeLabColorAnchor > 0.0 &&
        firstPeak > 0.0 && firstPeak < 0.0001 && bouncePeak > 0.0)
    {
        // Half subnormals have poor relative color precision near black and
        // can cross AnchorBounceColor's 1e-6 luminance threshold. Recover the
        // exact first color only for this low-signal anchoring case.
        float target = 0.0, fidelity = 0.0, pressure = 0.0;
        float3 fill = float3(0.0, 0.0, 0.0);
        CAMERA_OBSCURA_API_TL09CompositeEvidence uncachedFirst = LUNAR_FLOWER_TLSLEvaluateFirstComposite(
            uv, target, fill, fidelity, pressure);
        firstLight = uncachedFirst.bounded_contribution_rgb;
    }
    float3 signal = LUNAR_FLOWER_TLSLAnchorBounceColor(max(bounce.rgb, 0.0.xxx), firstLight);
    float3 extra = min(signal * fade, max(ceiling - firstLight, 0.0.xxx));
    // Own-pixel admission is not a gate on incoming bounce: a valid receiver
    // with no first light may still receive light from admitted donor pixels.
    return firstLight + extra;
}

float3 LUNAR_FLOWER_TLSLRejectionColor(float rejectionCode)
{
    if (rejectionCode < 0.5) return float3(0.05, 0.95, 0.18);
    if (rejectionCode < 1.5) return float3(0.10, 0.25, 0.95);
    if (rejectionCode < 2.5) return float3(0.95, 0.05, 0.03);
    if (rejectionCode < 3.5) return float3(0.95, 0.05, 0.75);
    if (rejectionCode < 4.5) return float3(0.95, 0.55, 0.05);
    if (rejectionCode < 5.5) return float3(0.05, 0.90, 0.90);
    if (rejectionCode < 6.5) return float3(0.45, 0.45, 0.45);
    return float3(0.35, 0.55, 1.0);
}

float4 LUNAR_FLOWER_TLSLDisplay_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLSLSourceOnly())
        return float4(saturate(tex2Dlod(ReShade::BackBuffer, float4(uv, 0.0, 0.0)).rgb), 1.0);
#if LUNAR_FLOWER_TLSL_CACHE_FIRST_LIGHT
    [branch]
    if ((LUNAR_FLOWER_TwinLanternsSpokeLabView == 0 ||
         LUNAR_FLOWER_TwinLanternsSpokeLabView == 4) && LUNAR_FLOWER_TLSLBounceActive())
    {
        float3 source = float3(0.0, 0.0, 0.0);
        float3 contribution = LUNAR_FLOWER_TLSLCachedContribution(uv, source);
        return float4(LUNAR_FLOWER_TwinLanternsSpokeLabView == 4 ? contribution :
            source + contribution, 1.0);
    }
#endif
    if (LUNAR_FLOWER_TwinLanternsSpokeLabView == 14)
    {
        float depth = CAMERA_OBSCURA_LoadDepth(uv);
        float mask = CAMERA_OBSCURA_DepthConfidence(depth) * LUNAR_FLOWER_TLSLDepthFadeFactor(depth);
        return float4(mask, mask, mask, 1.0);
    }

    if (LUNAR_FLOWER_TwinLanternsSpokeLabView >= 15 && LUNAR_FLOWER_TwinLanternsSpokeLabView <= 25)
    {
        LUNAR_FLOWER_TLSLDirectionEvidence diagnostic = LUNAR_FLOWER_TLSLEvaluateDirections(uv);
        int diagnosticView = LUNAR_FLOWER_TwinLanternsSpokeLabView;
        if (diagnosticView == 15) return float4(diagnostic.dda_hits.xxx, 1.0);
        if (diagnosticView == 16) return float4(diagnostic.march_hits.xxx, 1.0);
        if (diagnosticView == 17) return float4(diagnostic.dda_weight.xxx, 1.0);
        if (diagnosticView == 18) return float4(diagnostic.march_weight.xxx, 1.0);
        if (diagnosticView == 19) return float4(diagnostic.dda_donor_sum, 1.0);
        if (diagnosticView == 20) return float4(diagnostic.march_donor_sum, 1.0);
        if (diagnosticView == 21) return float4(diagnostic.dda_signal, 1.0);
        if (diagnosticView == 22) return float4(diagnostic.march_signal, 1.0);
        if (diagnosticView == 23) return float4(diagnostic.combined.rgb, 1.0);
        if (diagnosticView == 24) return float4(diagnostic.combined.rgb * diagnostic.combined.a, 1.0);
        return float4(diagnostic.receiver_valid.xxx, 1.0);
    }

    int bounceView = LUNAR_FLOWER_TwinLanternsSpokeLabView;
    if (bounceView == 29)
    {
        float retained = 0.0;
        int count = LUNAR_FLOWER_TLSLDirectionCount();
        [loop]
        for (int slot = 0; slot < 8; ++slot)
        {
            if (slot >= count) break;
            retained += LUNAR_FLOWER_TLSLChaosRetention(uv, LUNAR_FLOWER_TLSLDirectionIndex(slot));
        }
        retained /= (float)count;
        return float4(retained, retained, retained, 1.0);
    }
    if (bounceView == 26)
        return float4(saturate(tex2Dlod(LUNAR_FLOWER_TLSLFirstLightSampler, float4(uv, 0.0, 0.0)).rgb * 8.0), 1.0);
    if (bounceView == 27 || bounceView == 30)
    {
        float4 bounce = tex2Dlod(LUNAR_FLOWER_TLSLBounceSampler, float4(uv, 0.0, 0.0));
        return bounceView == 27 ? float4(saturate(bounce.rgb * 8.0), 1.0) : float4(bounce.a, bounce.a, bounce.a, 1.0);
    }
    if (bounceView == 28)
    {
        float target = 0.0, fidelity = 0.0, pressure = 0.0;
        float3 fill = float3(0.0, 0.0, 0.0);
        CAMERA_OBSCURA_API_TL09CompositeEvidence first = LUNAR_FLOWER_TLSLEvaluateFirstComposite(
            uv, target, fill, fidelity, pressure);
        float4 bounce = tex2Dlod(LUNAR_FLOWER_TLSLBounceSampler, float4(uv, 0.0, 0.0));
        CAMERA_OBSCURA_API_TL09CompositeEvidence total = LUNAR_FLOWER_TLSLAddBounce(
            first, bounce.rgb, CAMERA_OBSCURA_LoadDepth(uv));
        return float4(saturate(max(total.bounded_contribution_rgb - first.bounded_contribution_rgb, 0.0.xxx) * 8.0), 1.0);
    }

    float edgeFillTarget = 0.0;
    float3 edgeFillAdded = float3(0.0, 0.0, 0.0);
    float fidelityActivity = 0.0;
    float overdrivePressure = 0.0;
    CAMERA_OBSCURA_API_TL09CompositeEvidence evidence =
        LUNAR_FLOWER_TLSLEvaluateComposite(
            uv,
            edgeFillTarget,
            edgeFillAdded,
            fidelityActivity,
            overdrivePressure);
    float view = (float)LUNAR_FLOWER_TwinLanternsSpokeLabView;
    if (view < 0.5) return float4(evidence.final_rgb, 1.0);
    if (view < 1.5) return float4(evidence.source_rgb, 1.0);
    if (view < 2.5) return float4(evidence.bounded_indirect_rgb, 1.0);
    if (view < 3.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.evidence), 1.0);
    if (view < 4.5) return float4(
        evidence.bounded_contribution_rgb, 1.0);
    if (view < 5.5) return float4(
        LUNAR_FLOWER_TLSLRejectionColor(evidence.rejection_code), 1.0);
    if (view < 6.5) return float4(evidence.remaining_room_rgb, 1.0);
    if (view < 7.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.containment_activity), 1.0);
    if (view < 8.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.source_preserve_delta), 1.0);
    if (view < 9.5) return float4(evidence.bounds_valid > 0.5 ?
        float3(0.05, 0.95, 0.18) : float3(0.95, 0.05, 0.03), 1.0);
    if (view < 10.5) return float4(
        CAMERA_OBSCURA_DebugHeat(edgeFillTarget), 1.0);
    if (view < 11.5) return float4(saturate(edgeFillAdded * 8.0), 1.0);
    if (view < 12.5) return float4(
        CAMERA_OBSCURA_DebugHeat(fidelityActivity), 1.0);
    if (view < 13.5) return float4(
        CAMERA_OBSCURA_DebugHeat(overdrivePressure), 1.0);
    return float4(evidence.final_rgb, 1.0);
}

technique LUNAR_FLOWER_TwinLanternsSpokeLab
< ui_label = "Lunar Flower - Twin Lanterns: Spoke Lab 2"; ui_tooltip = "Three fixed primary spokes, linear/cubic admission comparisons, and an optional two-tap opposing cached-light gather. Uses current-frame fields only. No third stage or temporal history is implemented. Six working fields and seven passes with the normal cache."; >
{
#if LUNAR_FLOWER_TLSL_CACHE_DONOR_NORMALS
    pass TwinLanternDonorNormals
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLSLGuide_PS;
        RenderTarget = LUNAR_FLOWER_TLSLGuideTex;
    }
#endif
    pass TwinLanternTransport
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLSLRaw_PS;
        RenderTarget = LUNAR_FLOWER_TLSLRawTex;
    }
    pass TwinLanternResolveHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLSLResolveH_PS;
        RenderTarget = LUNAR_FLOWER_TLSLResolveHTex;
    }
    pass TwinLanternResolveVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLSLResolveV_PS;
        RenderTarget = LUNAR_FLOWER_TLSLResolveVTex;
    }
    pass TwinLanternCaptureFirstLight
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLSLFirstLight_PS;
        RenderTarget = LUNAR_FLOWER_TLSLFirstLightTex;
    }
    pass TwinLanternSecondBounce
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLSLBounce_PS;
        RenderTarget = LUNAR_FLOWER_TLSLBounceTex;
    }
    pass TwinLanternComposite
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLSLDisplay_PS;
    }
}
