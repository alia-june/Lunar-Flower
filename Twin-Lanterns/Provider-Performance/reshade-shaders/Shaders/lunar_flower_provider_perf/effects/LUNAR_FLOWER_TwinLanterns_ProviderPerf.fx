#include "ReShade.fxh"
// These preset-level definitions specialize only this performance experiment.
#ifndef LUNAR_FLOWER_TLPP_DDA_STEPS
#define LUNAR_FLOWER_TLPP_DDA_STEPS 16
#endif
#ifndef LUNAR_FLOWER_TLPP_MARCH_STEPS
#define LUNAR_FLOWER_TLPP_MARCH_STEPS 16
#endif
#ifndef LUNAR_FLOWER_TLPP_COMPILED_PROVIDER
#define LUNAR_FLOWER_TLPP_COMPILED_PROVIDER 0
#endif
#if LUNAR_FLOWER_TLPP_DDA_STEPS < 4 || LUNAR_FLOWER_TLPP_DDA_STEPS > 32
#error DDA sample budget must be between 4 and 32.
#endif
#if LUNAR_FLOWER_TLPP_MARCH_STEPS < 4 || LUNAR_FLOWER_TLPP_MARCH_STEPS > 32
#error March sample budget must be between 4 and 32.
#endif
#if LUNAR_FLOWER_TLPP_COMPILED_PROVIDER < -1 || LUNAR_FLOWER_TLPP_COMPILED_PROVIDER > 2
#error Provider must be -1 (runtime), 0 (both), 1 (DDA) or 2 (march).
#endif
// Ray geometry/reach stays at the parent maximum regardless of sample density.
#define CAMERA_OBSCURA_DDA_MAX_STEPS 32
#define CAMERA_OBSCURA_MARCH_MAX_STEPS LUNAR_FLOWER_TLPP_MARCH_STEPS
#if LUNAR_FLOWER_TLPP_COMPILED_PROVIDER >= 0
#define LUNAR_FLOWER_TLPP_ACTIVE_PROVIDER LUNAR_FLOWER_TLPP_COMPILED_PROVIDER
#else
#define LUNAR_FLOWER_TLPP_ACTIVE_PROVIDER LUNAR_FLOWER_TwinLanternsProviderPerfProviderMode
#endif
#include "../api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh"
#include "../api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh"

uniform int LUNAR_FLOWER_TwinLanternsProviderPerfView
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 00 Diagnostics"; ui_label = "Output View"; ui_items = "Final Image\0Source Image\0Bounded Indirect Light\0Evidence Confidence\0Applied Light\0Rejection Reason\0Remaining Channel Room\0Containment Activity\0Source Difference\0Bound Verification\0Edge Fill Target\0Edge Fill Added\0Fidelity Guard Activity\0Overdrive Pressure\0Depth Fade Mask\0DDA Hit Coverage\0March Hit Coverage\0DDA Admitted Weight\0March Admitted Weight\0DDA Raw Donor Color\0March Raw Donor Color\0DDA Weighted Signal\0March Weighted Signal\0Combined Raw Donor\0Combined Weighted Signal\0Receiver Validity\0Captured First Light (8x)\0Bounce Weighted Signal (8x)\0Applied Second Bounce (8x)\0Chaos Direction Retention\0Bounce Support\0"; ui_tooltip = "Final Image is the production output.\nDiagnostic views expose reconstructed screen-space light, admission evidence, containment, rendering intent, and depth fade.\nBound Verification must remain green."; > = 0;

uniform bool LUNAR_FLOWER_TwinLanternsProviderPerfEnabled
< ui_type = "checkbox"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 01 Light"; ui_label = "Enable Indirect Light"; ui_tooltip = "Applies bounded reconstructed indirect light.\nOff returns the source image exactly while diagnostics remain available."; > = true;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 01 Light"; ui_label = "Indirect Light Strength"; ui_min = 0.00; ui_max = 4.00; ui_step = 0.001; ui_tooltip = "Scales admitted indirect light after transport normalization and reconstruction evidence.\nFine adjustment: 0.001 per step (0.1 percentage point of nominal strength).\nFor 10-30% strength, use 0.100-0.300; zero returns the source image exactly."; > = 0.272000;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfMaximumContribution
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 01 Light"; ui_label = "Maximum Added Light"; ui_min = 0.00; ui_max = 0.50; ui_step = 0.005; ui_tooltip = "Hard per-channel ceiling for added normalized SDR light.\nThe result is also limited by the remaining room in each source channel."; > = 0.20;


uniform float LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 02 Depth Shaping"; ui_label = "Depth Fade Amount (0 = Off)"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Optional fade of final bounded Twin Lanterns added light.\n0 = Off; 1 = full removal at/after Fade End.\nDefault 0.355 follows the user preset; set 0 to disable fading.\nDepth uses ReShade normalized linear depth, not world distance."; > = 0.355000;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStart
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 02 Depth Shaping"; ui_label = "Depth Fade Start"; ui_min = 0.00000; ui_max = 1.00000; ui_step = 0.00001; ui_tooltip = "Normalized linear depth where fading and distant-light softening begin.\nUse Depth Fade Mask to tune this for the game; these values are not calibrated distances."; > = 0.00500;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeEnd
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 02 Depth Shaping"; ui_label = "Depth Fade End"; ui_min = 0.00000; ui_max = 1.00000; ui_step = 0.00001; ui_tooltip = "Normalized linear depth where fade and softening reach full authority.\nEnd is treated as at least Start plus 0.000001 to avoid a zero-width transition."; > = 0.05000;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfLightSoftening
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 02 Depth Shaping"; ui_label = "Distant Light Softening"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Softens only the indirect-light field, increasing between Fade Start and End.\nFour neighboring taps are gated by Surface Depth and Direction Agreement.\nZero bypasses these taps. The source image is never blurred."; > = 1.000000;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfLightSofteningRadiusPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 02 Depth Shaping"; ui_label = "Light Softening Radius"; ui_min = 1.0; ui_max = 4.0; ui_step = 1.0; ui_tooltip = "Radius in full-resolution pixels for four surface-gated indirect-light taps.\nThe fixed radius avoids depth-driven changes in the tap footprint."; > = 2.0;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfRayLengthPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 90 Transport"; ui_label = "Transport Distance"; ui_min = 4.0; ui_max = 24.0; ui_step = 1.0; ui_tooltip = "Screen-space travel in pixels for each scheduled direction.\nChanges reach and sample spacing while maximum provider sample counts remain fixed. Actual work can vary with early hits or screen exits."; > = 24.0;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfDepthSlope
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 90 Transport"; ui_label = "Ray Depth Slope"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Controls normalized depth travel per pixel using the mean horizontal/vertical pixel pitch.\nDepth travel is independent of direction so cardinal/diagonal testing uses the same depth interval."; > = 0.16;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfFrontBias
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 90 Transport"; ui_label = "Front Surface Bias"; ui_min = 0.0000; ui_max = 0.0100; ui_step = 0.000001; ui_tooltip = "Front-side hit tolerance in normalized linear depth; this does not offset the ray origin.\nLarger values admit surfaces farther in front of the ray and also widen confidence weighting; they may increase light carry.\nFine adjustment: 0.000001 per step. Zero is valid; pixel-distance self-hit rejection is separate."; > = 0.000052;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfBackThickness
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 90 Transport"; ui_label = "Back Surface Thickness"; ui_min = 0.0000; ui_max = 0.0200; ui_step = 0.0001; ui_tooltip = "Extends the accepted hit interval behind the ray.\nLarger values admit thicker surfaces but can increase leakage."; > = 0.0035;

uniform int LUNAR_FLOWER_TwinLanternsProviderPerfDirectionSet
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 01 Experiment"; ui_label = "Direction Set"; ui_items = "Cardinal (4 directions)\0Diagonal (4 directions)\0Mixed (8 directions)\0"; ui_tooltip = "Cardinal and Diagonal use equal direction counts, distance, provider budgets and normalization.\nMixed doubles the directions and maximum work; it is a separate coverage experiment."; > = 0;

#if LUNAR_FLOWER_TLPP_COMPILED_PROVIDER < 0
uniform int LUNAR_FLOWER_TwinLanternsProviderPerfProviderMode
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 01 Experiment"; ui_label = "Provider"; ui_items = "DDA + March\0DDA Only\0March Only\0"; ui_tooltip = "Selects the traversal providers in both production and diagnostics.\nEach selected provider is normalized by its own direction count. Budgets are set by the benchmark preset; matched tests use 16 samples per provider.\nDisabled providers are not traced."; > = 0;
#endif

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfDepthTolerance
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 91 Reconstruction"; ui_label = "Surface Depth Agreement"; ui_min = 0.0001; ui_max = 0.0500; ui_step = 0.00001; ui_tooltip = "Maximum depth disagreement admitted during reconstruction and edge fill.\nLower values reject differing-depth neighbors more strictly; higher values admit more neighboring light and may brighten or soften boundaries.\nFine adjustment: 0.00001 per step; this is a depth tolerance, not a light strength."; > = 0.0050;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfNormalMinimum
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 91 Reconstruction"; ui_label = "Surface Direction Agreement"; ui_min = 0.00; ui_max = 0.99; ui_step = 0.01; ui_tooltip = "Minimum agreement between reconstructed surface directions.\nHigher values preserve edges but may reduce support."; > = 0.80;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfEdgeProtection
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 91 Reconstruction"; ui_label = "Depth Edge Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Rejects reconstruction support near depth discontinuities.\nOne provides maximum protection against cross-surface light carry."; > = 1.00;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfEdgeInkStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 92 Style"; ui_label = "Edge Ink Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Adds the contour-heavy look created when rejected edge taps reduce visible light confidence.\nZero keeps surface rejection active without the AO-like edge emphasis.\nOne restores the original Twin Lantern edge treatment."; > = 0.00;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfEdgeFillStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 92 Style"; ui_label = "Edge Fill Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Fills only positive deficits in the reconstructed indirect-light field near depth edges.\nThe source image is never blurred and depth/normal agreement prevents cross-surface carry.\nZero bypasses all edge-fill sampling."; > = 0.20;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfEdgeFillRadiusPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 92 Style"; ui_label = "Edge Fill Radius"; ui_min = 1.00; ui_max = 4.00; ui_step = 0.25; ui_tooltip = "Distance in full-resolution pixels used to find same-surface indirect light around an edge.\nLarger values close wider dark troughs and cost the same four additional reads when fill is active."; > = 2.00;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfFidelityGuard
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 93 Intent"; ui_label = "Fidelity Guard"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Aligns transported light toward the receiver's existing color and reduces pressure near occupied highlight channels.\nIt protects the full-stack image without weakening dark-surface transport as strongly."; > = 0.65;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfOverdrive
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 93 Intent"; ui_label = "Overdrive"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Raises admitted Twin Lantern energy up to three times before hard contribution and channel-room bounds.\nOverdrive and Fidelity Guard can run together."; > = 0.00;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfBounceStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 03 Second Bounce"; ui_label = "Second Bounce Strength"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.001; ui_tooltip = "Adds a separate same-frame gather of the first pass's bounded light.\nZero preserves the first-pass lighting exactly and skips secondary sampling.\nThe final image is never fed back into the gather."; > = 0.500;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfBounceRetention
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 03 Second Bounce"; ui_label = "Energy Retained Per Bounce"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.001; ui_tooltip = "Fraction of gathered first-pass light retained by the extra bounce.\n0.5 retains half before Second Bounce Strength. Zero removes the secondary contribution.\nThis is a bounded screen-space approximation, not a measured material reflectance."; > = 0.500;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfBounceDistanceDecay
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 03 Second Bounce"; ui_label = "Extra Bounce Distance Decay"; ui_min = 0.0; ui_max = 4.0; ui_step = 0.01; ui_tooltip = "Additional power of (1 - hit distance / transport distance) on the second leg.\nBoth legs already have the established linear distance weight; 1 makes the second-leg falloff quadratic.\nDistance is measured in screen pixels, not world units."; > = 1.0;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfColorAnchor
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 04 Perception"; ui_label = "Current-Frame Color Anchor"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.001; ui_tooltip = "Aligns only the extra light toward the receiver's current first-pass light color.\nNeither luminance nor peak intensity can increase, so anchoring cannot restore lost light.\nThis is a current-frame color-continuity approximation, not temporal memory or a model of human vision."; > = 0.500;

uniform float LUNAR_FLOWER_TwinLanternsProviderPerfChaosAmount
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 05 Broken Sampler"; ui_label = "Unknown-Support Loss"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.001; ui_tooltip = "Artificially diminishes or drops second-bounce directions.\nZero bypasses this experiment. The pattern is fixed per screen pixel, direction and seed; no frame counter is used.\nLost support is not redistributed and does not darken the source/first pass. This is simulated uncertainty, not detected occlusion."; > = 0.0;

uniform int LUNAR_FLOWER_TwinLanternsProviderPerfChaosMode
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 05 Broken Sampler"; ui_label = "Broken Sampler Mode"; ui_items = "Diminish\0Drop Directions\0Mixed\0"; > = 2;

uniform int LUNAR_FLOWER_TwinLanternsProviderPerfChaosSeed
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Provider Performance / 05 Broken Sampler"; ui_label = "Stable Pattern Seed"; ui_min = 0; ui_max = 9999; ui_step = 1; ui_tooltip = "Changes the deterministic screen-space uncertainty pattern.\nIt is screen-anchored, not attached to world geometry."; > = 17;

bool LUNAR_FLOWER_TLPPSourceOnly()
{
    return LUNAR_FLOWER_TwinLanternsProviderPerfView == 1 ||
        (LUNAR_FLOWER_TwinLanternsProviderPerfView == 0 &&
         (!LUNAR_FLOWER_TwinLanternsProviderPerfEnabled ||
          LUNAR_FLOWER_TwinLanternsProviderPerfStrength <= 0.0));
}

bool LUNAR_FLOWER_TLPPNeedsTransportFields()
{
    int view = LUNAR_FLOWER_TwinLanternsProviderPerfView;
    return !LUNAR_FLOWER_TLPPSourceOnly() &&
        (view < 14 || (view >= 26 && view <= 30 && view != 29));
}

bool LUNAR_FLOWER_TLPPBounceActive()
{
    return LUNAR_FLOWER_TwinLanternsProviderPerfBounceStrength > 0.0 &&
        LUNAR_FLOWER_TwinLanternsProviderPerfBounceRetention > 0.0 &&
        LUNAR_FLOWER_TwinLanternsProviderPerfEnabled &&
        LUNAR_FLOWER_TwinLanternsProviderPerfStrength > 0.0;
}

texture2D LUNAR_FLOWER_TLPPFirstLightTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};
texture2D LUNAR_FLOWER_TLPPBounceTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};
sampler2D LUNAR_FLOWER_TLPPFirstLightSampler
{
    Texture = LUNAR_FLOWER_TLPPFirstLightTex;
    MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D LUNAR_FLOWER_TLPPBounceSampler
{
    Texture = LUNAR_FLOWER_TLPPBounceTex;
    MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = CLAMP; AddressV = CLAMP;
};

texture2D LUNAR_FLOWER_TLPPRawTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

texture2D LUNAR_FLOWER_TLPPResolveHTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

texture2D LUNAR_FLOWER_TLPPResolveVTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler2D LUNAR_FLOWER_TLPPRawSampler
{
    Texture = LUNAR_FLOWER_TLPPRawTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D LUNAR_FLOWER_TLPPResolveHSampler
{
    Texture = LUNAR_FLOWER_TLPPResolveHTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D LUNAR_FLOWER_TLPPResolveVSampler
{
    Texture = LUNAR_FLOWER_TLPPResolveVTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

float2 LUNAR_FLOWER_TLPPFullTexel()
{
    return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
}

float LUNAR_FLOWER_TLPPRequestedCoverage(float2 requestedUv)
{
    return
        step(0.0, requestedUv.x) *
        step(requestedUv.x, 1.0) *
        step(0.0, requestedUv.y) *
        step(requestedUv.y, 1.0);
}

float LUNAR_FLOWER_TwinLanternsProviderPerfStyledEdgeProtection()
{
    return saturate(LUNAR_FLOWER_TwinLanternsProviderPerfEdgeProtection) *
        saturate(LUNAR_FLOWER_TwinLanternsProviderPerfEdgeInkStrength);
}

CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLPPEvaluateHorizontal(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        LUNAR_FLOWER_TLPPBuildSurfaceGuide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(LUNAR_FLOWER_TLPPFullTexel().x, 0.0);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = LUNAR_FLOWER_TLPPRequestedCoverage(negativeRequested);
    float positiveAvailable = LUNAR_FLOWER_TLPPRequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(LUNAR_FLOWER_TLPPRawSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            LUNAR_FLOWER_TLPPRawSampler, negativeRequested);
        negativeGuide = LUNAR_FLOWER_TLPPBuildSurfaceGuide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            LUNAR_FLOWER_TLPPRawSampler, positiveRequested);
        positiveGuide = LUNAR_FLOWER_TLPPBuildSurfaceGuide(positiveRequested);
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
        LUNAR_FLOWER_TwinLanternsProviderPerfDepthTolerance,
        LUNAR_FLOWER_TwinLanternsProviderPerfNormalMinimum,
        LUNAR_FLOWER_TwinLanternsProviderPerfStyledEdgeProtection());
}

CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLPPEvaluateVertical(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        LUNAR_FLOWER_TLPPBuildSurfaceGuide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(0.0, LUNAR_FLOWER_TLPPFullTexel().y);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = LUNAR_FLOWER_TLPPRequestedCoverage(negativeRequested);
    float positiveAvailable = LUNAR_FLOWER_TLPPRequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(LUNAR_FLOWER_TLPPResolveHSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            LUNAR_FLOWER_TLPPResolveHSampler, negativeRequested);
        negativeGuide = LUNAR_FLOWER_TLPPBuildSurfaceGuide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            LUNAR_FLOWER_TLPPResolveHSampler, positiveRequested);
        positiveGuide = LUNAR_FLOWER_TLPPBuildSurfaceGuide(positiveRequested);
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
        LUNAR_FLOWER_TwinLanternsProviderPerfDepthTolerance,
        LUNAR_FLOWER_TwinLanternsProviderPerfNormalMinimum,
        LUNAR_FLOWER_TwinLanternsProviderPerfStyledEdgeProtection());
}

int LUNAR_FLOWER_TLPPDirectionCount()
{
    return LUNAR_FLOWER_TwinLanternsProviderPerfDirectionSet >= 2 ? 8 : 4;
}

float LUNAR_FLOWER_TLPPDirectionIndex(int slot)
{
    if (LUNAR_FLOWER_TwinLanternsProviderPerfDirectionSet >= 2) return (float)slot;
    return (float)(slot * 2 + (LUNAR_FLOWER_TwinLanternsProviderPerfDirectionSet == 1 ? 1 : 0));
}

struct LUNAR_FLOWER_TLPPDirectionEvidence
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

LUNAR_FLOWER_TLPPDirectionEvidence LUNAR_FLOWER_TLPPEvaluateDirections(float2 uv)
{
    LUNAR_FLOWER_TLPPDirectionEvidence result;
    result.combined = float4(0.0, 0.0, 0.0, 0.0);
    result.dda_donor_sum = float3(0.0, 0.0, 0.0);
    result.march_donor_sum = float3(0.0, 0.0, 0.0);
    result.dda_signal = float3(0.0, 0.0, 0.0);
    result.march_signal = float3(0.0, 0.0, 0.0);
    result.dda_hits = 0.0;
    result.march_hits = 0.0;
    result.dda_weight = 0.0;
    result.march_weight = 0.0;
    CAMERA_OBSCURA_SurfaceGuide receiver = LUNAR_FLOWER_TLPPBuildSurfaceGuide(uv);
    result.receiver_valid = receiver.valid;
    if (receiver.valid < 0.5) return result;
    int directionCount = LUNAR_FLOWER_TLPPDirectionCount();
    float3 weightedDonor = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    [loop]
    for (int slot = 0; slot < 8; ++slot)
    {
        if (slot >= directionCount) break;
        LUNAR_FLOWER_TLPPScreenEvidence screen = LUNAR_FLOWER_TLPPTraceScreenDetailed(
            uv, LUNAR_FLOWER_TLPPDirectionIndex(slot),
            LUNAR_FLOWER_TwinLanternsProviderPerfRayLengthPixels,
            LUNAR_FLOWER_TwinLanternsProviderPerfDepthSlope,
            LUNAR_FLOWER_TwinLanternsProviderPerfFrontBias,
            LUNAR_FLOWER_TwinLanternsProviderPerfBackThickness,
            LUNAR_FLOWER_TLPP_ACTIVE_PROVIDER,
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

float4 LUNAR_FLOWER_TLPPRaw_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLPPSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (!LUNAR_FLOWER_TLPPNeedsTransportFields()) return float4(0.0, 0.0, 0.0, 0.0);
    return LUNAR_FLOWER_TLPPEvaluateDirections(uv).combined;
}

float LUNAR_FLOWER_TLPPVisibleConfidence(
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
        saturate(LUNAR_FLOWER_TwinLanternsProviderPerfEdgeInkStrength));
    return saturate(visibleConfidence);
}

float4 LUNAR_FLOWER_TLPPResolveH_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLPPSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (!LUNAR_FLOWER_TLPPNeedsTransportFields()) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        LUNAR_FLOWER_TLPPEvaluateHorizontal(uv);
    return float4(
        evidence.resolved_rgb,
        LUNAR_FLOWER_TLPPVisibleConfidence(evidence));
}

float4 LUNAR_FLOWER_TLPPResolveV_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLPPSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (!LUNAR_FLOWER_TLPPNeedsTransportFields()) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        LUNAR_FLOWER_TLPPEvaluateVertical(uv);
    return float4(
        evidence.resolved_rgb,
        LUNAR_FLOWER_TLPPVisibleConfidence(evidence));
}

float4 LUNAR_FLOWER_TLPPFullResolutionReconstruct(float2 uv, CAMERA_OBSCURA_SurfaceGuide centerGuide)
{
    if (centerGuide.valid < 0.5)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    float4 resolved = tex2D(LUNAR_FLOWER_TLPPResolveVSampler, uv);
    float trustedEvidence = saturate(resolved.a) *
        saturate(centerGuide.depth_confidence);
    return float4(saturate(resolved.rgb), trustedEvidence);
}

void LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(
    float2 requestedUv,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    inout float3 signalSum,
    inout float evidenceSum,
    inout float supportSum)
{
    float coverage = LUNAR_FLOWER_TLPPRequestedCoverage(requestedUv);
    [branch]
    if (coverage > 0.5)
    {
        CAMERA_OBSCURA_SurfaceGuide tapGuide =
            LUNAR_FLOWER_TLPPBuildSurfaceGuide(requestedUv);
        float depthSupport = CAMERA_OBSCURA_API_TL08DepthSupport(
            centerGuide, tapGuide, LUNAR_FLOWER_TwinLanternsProviderPerfDepthTolerance);
        float normalSupport = CAMERA_OBSCURA_API_TL08NormalSupport(
            centerGuide, tapGuide, LUNAR_FLOWER_TwinLanternsProviderPerfNormalMinimum);
        float surfaceSupport = coverage * depthSupport * normalSupport;
        float4 sampleValue = tex2D(
            LUNAR_FLOWER_TLPPResolveVSampler, requestedUv);
        float sampleEvidence = saturate(sampleValue.a);

        signalSum += saturate(sampleValue.rgb) *
            sampleEvidence * surfaceSupport;
        evidenceSum += sampleEvidence * surfaceSupport;
        supportSum += surfaceSupport;
    }
}

float4 LUNAR_FLOWER_TLPPApplyEdgeFill(
    float2 uv,
    float4 baseIndirect,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    out float edgeFillTarget,
    out float3 edgeFillAdded)
{
    edgeFillTarget = 0.0;
    edgeFillAdded = float3(0.0, 0.0, 0.0);
    float safeStrength = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfEdgeFillStrength);
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
        LUNAR_FLOWER_TwinLanternsProviderPerfEdgeFillRadiusPixels, 1.0, 4.0);
    float2 offset = float2(
        BUFFER_RCP_WIDTH * safeRadius,
        BUFFER_RCP_HEIGHT * safeRadius);
    float3 signalSum = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    float supportSum = 0.0;

    LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(
        uv - float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(
        uv + float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(
        uv - float2(0.0, offset.y), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(
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


float LUNAR_FLOWER_TLPPDepthPhase(float receiverDepth)
{
    float start = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStart);
    float end = max(saturate(LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeEnd), start + 0.000001);
    return smoothstep(start, end, saturate(receiverDepth));
}

float LUNAR_FLOWER_TLPPDepthFadeFactor(float receiverDepth)
{
    return 1.0 - saturate(LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStrength) *
        LUNAR_FLOWER_TLPPDepthPhase(receiverDepth);
}

float4 LUNAR_FLOWER_TLPPApplyDepthShaping(
    float2 uv, float4 baseIndirect, CAMERA_OBSCURA_SurfaceGuide centerGuide)
{
    if (LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStrength <= 0.0 &&
        LUNAR_FLOWER_TwinLanternsProviderPerfLightSoftening <= 0.0)
        return baseIndirect;
    if (centerGuide.valid < 0.5) return float4(0.0, 0.0, 0.0, 0.0);
    float phase = LUNAR_FLOWER_TLPPDepthPhase(centerGuide.depth);
    float fade = LUNAR_FLOWER_TLPPDepthFadeFactor(centerGuide.depth);
    if (fade <= 0.0) return baseIndirect; // Final composite removes the light; skip softening work.
    float amount = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfLightSoftening) * phase;
    float4 shaped = baseIndirect;
    [branch]
    if (amount > 0.000001)
    {
        float radius = clamp(LUNAR_FLOWER_TwinLanternsProviderPerfLightSofteningRadiusPixels, 1.0, 4.0);
        float2 offset = LUNAR_FLOWER_TLPPFullTexel() * radius;
        float baseEvidence = saturate(baseIndirect.a);
        float3 baseSignal = saturate(baseIndirect.rgb) * baseEvidence;
        float3 signalSum = baseSignal;
        float evidenceSum = baseEvidence;
        float supportSum = 1.0;
        // Existing depth/normal/coverage-gated taps read only ResolveV light.
        LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(uv - float2(offset.x, 0.0), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(uv + float2(offset.x, 0.0), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(uv - float2(0.0, offset.y), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLPPAccumulateEdgeFillTap(uv + float2(0.0, offset.y), centerGuide, signalSum, evidenceSum, supportSum);
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

float4 LUNAR_FLOWER_TLPPApplyRenderIntent(
    float3 source,
    float4 reconstructed,
    out float fidelityActivity,
    out float overdrivePressure,
    out float effectiveStrength)
{
    fidelityActivity = 0.0;
    overdrivePressure = 0.0;
    effectiveStrength = max(LUNAR_FLOWER_TwinLanternsProviderPerfStrength, 0.0);
    float safeFidelity = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfFidelityGuard);
    float safeOverdrive = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfOverdrive);
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
    effectiveStrength = max(LUNAR_FLOWER_TwinLanternsProviderPerfStrength, 0.0) *
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
LUNAR_FLOWER_TLPPFadeComposite(
    CAMERA_OBSCURA_API_TL09CompositeEvidence result, float receiverDepth)
{
    float fade = LUNAR_FLOWER_TLPPDepthFadeFactor(receiverDepth);
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
LUNAR_FLOWER_TLPPEvaluateFirstComposite(
    float2 uv,
    out float edgeFillTarget,
    out float3 edgeFillAdded,
    out float fidelityActivity,
    out float overdrivePressure)
{
    CAMERA_OBSCURA_SurfaceGuide centerGuide = LUNAR_FLOWER_TLPPBuildSurfaceGuide(uv);
    float4 vertical = LUNAR_FLOWER_TLPPFullResolutionReconstruct(uv, centerGuide);
    float4 reconstructed = LUNAR_FLOWER_TLPPApplyEdgeFill(
        uv, vertical, centerGuide, edgeFillTarget, edgeFillAdded);
    reconstructed = LUNAR_FLOWER_TLPPApplyDepthShaping(uv, reconstructed, centerGuide);
    float3 source = saturate(tex2D(ReShade::BackBuffer, uv).rgb);
    float effectiveStrength = 0.0;
    float4 intended = LUNAR_FLOWER_TLPPApplyRenderIntent(
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
        LUNAR_FLOWER_TwinLanternsProviderPerfEnabled ? 1.0 : 0.0,
        effectiveStrength,
        LUNAR_FLOWER_TwinLanternsProviderPerfMaximumContribution);
    return LUNAR_FLOWER_TLPPFadeComposite(result, centerGuide.depth);
}

float LUNAR_FLOWER_TLPPChaosRetention(float2 uv, float directionIndex)
{
    float amount = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfChaosAmount);
    if (amount <= 0.0) return 1.0;
    float seed = (float)LUNAR_FLOWER_TwinLanternsProviderPerfChaosSeed;
    float2 pixel = floor(uv / CAMERA_OBSCURA_PixelSize());
    float noise = CAMERA_OBSCURA_StableNoise01(pixel +
        float2(directionIndex * 19.17 + seed * 7.13, directionIndex * 43.71 + seed * 11.37));
    if (LUNAR_FLOWER_TwinLanternsProviderPerfChaosMode == 1)
        return noise >= amount ? 1.0 : 0.0;
    if (LUNAR_FLOWER_TwinLanternsProviderPerfChaosMode == 2 && noise < amount * 0.5)
        return 0.0;
    float variation = CAMERA_OBSCURA_StableNoise01(pixel +
        float2(directionIndex * 37.11 + seed * 3.17, directionIndex * 13.79 + seed * 23.41));
    return 1.0 - amount * variation;
}

float LUNAR_FLOWER_TLPPBounceDistanceGain(float distancePixels)
{
    float extraDecay = max(LUNAR_FLOWER_TwinLanternsProviderPerfBounceDistanceDecay, 0.0);
    if (extraDecay <= 0.0) return 1.0;
    float remaining = saturate(1.0 - max(distancePixels, 0.0) /
        max(LUNAR_FLOWER_TwinLanternsProviderPerfRayLengthPixels, 1.0));
    return pow(remaining, extraDecay);
}

float4 LUNAR_FLOWER_TLPPFirstLight_PS(
    float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    if (!LUNAR_FLOWER_TLPPNeedsTransportFields() ||
        (!LUNAR_FLOWER_TLPPBounceActive() && LUNAR_FLOWER_TwinLanternsProviderPerfView != 26))
        return float4(0.0, 0.0, 0.0, 0.0);
    float target = 0.0, fidelity = 0.0, pressure = 0.0;
    float3 fill = float3(0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL09CompositeEvidence first =
        LUNAR_FLOWER_TLPPEvaluateFirstComposite(uv, target, fill, fidelity, pressure);
    // RGB is actual bounded, faded added light, not source color or final color.
    return float4(first.bounded_contribution_rgb, first.admission);
}

void LUNAR_FLOWER_TLPPAccumulateBounceHit(
    float2 hitUv, float sampleWeight, float distancePixels, float retention,
    inout float3 signal, inout float support)
{
    float weight = saturate(sampleWeight) * saturate(retention) *
        LUNAR_FLOWER_TLPPBounceDistanceGain(distancePixels);
    if (weight <= 0.0) return;
    float4 firstLight = tex2Dlod(LUNAR_FLOWER_TLPPFirstLightSampler, float4(hitUv, 0.0, 0.0));
    float admitted = weight * saturate(firstLight.a);
    signal += max(firstLight.rgb, 0.0.xxx) * admitted;
    support += admitted;
}

float4 LUNAR_FLOWER_TLPPBounce_PS(
    float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    if (!LUNAR_FLOWER_TLPPNeedsTransportFields() || !LUNAR_FLOWER_TLPPBounceActive() ||
        LUNAR_FLOWER_TwinLanternsProviderPerfView == 26)
        return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide receiver = LUNAR_FLOWER_TLPPBuildSurfaceGuide(uv);
    if (receiver.valid < 0.5) return float4(0.0, 0.0, 0.0, 0.0);
    float3 signal = float3(0.0, 0.0, 0.0);
    float support = 0.0;
    int count = LUNAR_FLOWER_TLPPDirectionCount();
    [loop]
    for (int slot = 0; slot < 8; ++slot)
    {
        if (slot >= count) break;
        float direction = LUNAR_FLOWER_TLPPDirectionIndex(slot);
        float retained = LUNAR_FLOWER_TLPPChaosRetention(uv, direction);
        if (retained <= 0.0) continue;
        LUNAR_FLOWER_TLPPScreenEvidence hit = LUNAR_FLOWER_TLPPTraceScreenDetailed(
            uv, direction, LUNAR_FLOWER_TwinLanternsProviderPerfRayLengthPixels,
            LUNAR_FLOWER_TwinLanternsProviderPerfDepthSlope,
            LUNAR_FLOWER_TwinLanternsProviderPerfFrontBias,
            LUNAR_FLOWER_TwinLanternsProviderPerfBackThickness,
            LUNAR_FLOWER_TLPP_ACTIVE_PROVIDER, false, receiver);
        LUNAR_FLOWER_TLPPAccumulateBounceHit(hit.dda_uv, hit.dda_sample.a,
            hit.dda_distance, retained, signal, support);
        LUNAR_FLOWER_TLPPAccumulateBounceHit(hit.march_uv, hit.march_sample.a,
            hit.march_distance, retained, signal, support);
    }
    int providerMode = LUNAR_FLOWER_TLPP_ACTIVE_PROVIDER;
    float providers = (providerMode == 1 || providerMode == 2) ? 1.0 : 2.0;
    // Fixed scheduled denominator: missing directions are energy loss, never
    // a reason to brighten the remaining samples.
    float inverseBudget = 1.0 / ((float)count * providers);
    float energy = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfBounceRetention) *
        saturate(LUNAR_FLOWER_TwinLanternsProviderPerfBounceStrength);
    return float4(signal * inverseBudget * energy, saturate(support * inverseBudget));
}

float3 LUNAR_FLOWER_TLPPAnchorBounceColor(float3 signal, float3 firstLight)
{
    float amount = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfColorAnchor);
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

CAMERA_OBSCURA_API_TL09CompositeEvidence LUNAR_FLOWER_TLPPAddBounce(
    CAMERA_OBSCURA_API_TL09CompositeEvidence first, float3 bounceSignal, float receiverDepth)
{
    if (!LUNAR_FLOWER_TLPPBounceActive() || first.receiver_valid < 0.5) return first;
    float3 signal = LUNAR_FLOWER_TLPPAnchorBounceColor(max(bounceSignal, 0.0.xxx),
        first.bounded_contribution_rgb);
    float fade = LUNAR_FLOWER_TLPPDepthFadeFactor(receiverDepth);
    float maximumContribution = saturate(LUNAR_FLOWER_TwinLanternsProviderPerfMaximumContribution);
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

CAMERA_OBSCURA_API_TL09CompositeEvidence LUNAR_FLOWER_TLPPEvaluateComposite(
    float2 uv, out float edgeFillTarget, out float3 edgeFillAdded,
    out float fidelityActivity, out float overdrivePressure)
{
    CAMERA_OBSCURA_API_TL09CompositeEvidence first = LUNAR_FLOWER_TLPPEvaluateFirstComposite(
        uv, edgeFillTarget, edgeFillAdded, fidelityActivity, overdrivePressure);
    if (!LUNAR_FLOWER_TLPPBounceActive()) return first;
    float4 bounce = tex2Dlod(LUNAR_FLOWER_TLPPBounceSampler, float4(uv, 0.0, 0.0));
    return LUNAR_FLOWER_TLPPAddBounce(first, bounce.rgb, CAMERA_OBSCURA_LoadDepth(uv));
}

float3 LUNAR_FLOWER_TLPPRejectionColor(float rejectionCode)
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

float4 LUNAR_FLOWER_TLPPDisplay_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLPPSourceOnly())
        return float4(saturate(tex2D(ReShade::BackBuffer, uv).rgb), 1.0);
    if (LUNAR_FLOWER_TwinLanternsProviderPerfView == 14)
    {
        float depth = CAMERA_OBSCURA_LoadDepth(uv);
        float mask = CAMERA_OBSCURA_DepthConfidence(depth) * LUNAR_FLOWER_TLPPDepthFadeFactor(depth);
        return float4(mask, mask, mask, 1.0);
    }

    if (LUNAR_FLOWER_TwinLanternsProviderPerfView >= 15 && LUNAR_FLOWER_TwinLanternsProviderPerfView <= 25)
    {
        LUNAR_FLOWER_TLPPDirectionEvidence diagnostic = LUNAR_FLOWER_TLPPEvaluateDirections(uv);
        int diagnosticView = LUNAR_FLOWER_TwinLanternsProviderPerfView;
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

    int bounceView = LUNAR_FLOWER_TwinLanternsProviderPerfView;
    if (bounceView == 29)
    {
        float retained = 0.0;
        int count = LUNAR_FLOWER_TLPPDirectionCount();
        [loop]
        for (int slot = 0; slot < 8; ++slot)
        {
            if (slot >= count) break;
            retained += LUNAR_FLOWER_TLPPChaosRetention(uv, LUNAR_FLOWER_TLPPDirectionIndex(slot));
        }
        retained /= (float)count;
        return float4(retained, retained, retained, 1.0);
    }
    if (bounceView == 26)
        return float4(saturate(tex2Dlod(LUNAR_FLOWER_TLPPFirstLightSampler, float4(uv, 0.0, 0.0)).rgb * 8.0), 1.0);
    if (bounceView == 27 || bounceView == 30)
    {
        float4 bounce = tex2Dlod(LUNAR_FLOWER_TLPPBounceSampler, float4(uv, 0.0, 0.0));
        return bounceView == 27 ? float4(saturate(bounce.rgb * 8.0), 1.0) : float4(bounce.a, bounce.a, bounce.a, 1.0);
    }
    if (bounceView == 28)
    {
        float target = 0.0, fidelity = 0.0, pressure = 0.0;
        float3 fill = float3(0.0, 0.0, 0.0);
        CAMERA_OBSCURA_API_TL09CompositeEvidence first = LUNAR_FLOWER_TLPPEvaluateFirstComposite(
            uv, target, fill, fidelity, pressure);
        float4 bounce = tex2Dlod(LUNAR_FLOWER_TLPPBounceSampler, float4(uv, 0.0, 0.0));
        CAMERA_OBSCURA_API_TL09CompositeEvidence total = LUNAR_FLOWER_TLPPAddBounce(
            first, bounce.rgb, CAMERA_OBSCURA_LoadDepth(uv));
        return float4(saturate(max(total.bounded_contribution_rgb - first.bounded_contribution_rgb, 0.0.xxx) * 8.0), 1.0);
    }

    float edgeFillTarget = 0.0;
    float3 edgeFillAdded = float3(0.0, 0.0, 0.0);
    float fidelityActivity = 0.0;
    float overdrivePressure = 0.0;
    CAMERA_OBSCURA_API_TL09CompositeEvidence evidence =
        LUNAR_FLOWER_TLPPEvaluateComposite(
            uv,
            edgeFillTarget,
            edgeFillAdded,
            fidelityActivity,
            overdrivePressure);
    float view = (float)LUNAR_FLOWER_TwinLanternsProviderPerfView;
    if (view < 0.5) return float4(evidence.final_rgb, 1.0);
    if (view < 1.5) return float4(evidence.source_rgb, 1.0);
    if (view < 2.5) return float4(evidence.bounded_indirect_rgb, 1.0);
    if (view < 3.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.evidence), 1.0);
    if (view < 4.5) return float4(
        evidence.bounded_contribution_rgb, 1.0);
    if (view < 5.5) return float4(
        LUNAR_FLOWER_TLPPRejectionColor(evidence.rejection_code), 1.0);
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

technique LUNAR_FLOWER_TwinLanternsProviderPerf
< ui_label = "Lunar Flower - Twin Lanterns: Provider Performance"; ui_tooltip = "Provider performance comparison with matched budgets and compile-time selection.\nCompare four cardinal with four diagonal directions at fixed DDA/march sample budgets and equal pixel/depth travel. Mixed uses eight directions and more work.\nProvider diagnostics expose hits, raw donors and weighted signals before reconstruction/strength/fade. Six pixel passes; bounded first-light capture feeds one additional gather. Current-frame screen evidence only; no temporal history."; >
{
    pass TwinLanternTransport
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLPPRaw_PS;
        RenderTarget = LUNAR_FLOWER_TLPPRawTex;
    }
    pass TwinLanternResolveHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLPPResolveH_PS;
        RenderTarget = LUNAR_FLOWER_TLPPResolveHTex;
    }
    pass TwinLanternResolveVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLPPResolveV_PS;
        RenderTarget = LUNAR_FLOWER_TLPPResolveVTex;
    }
    pass TwinLanternCaptureFirstLight
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLPPFirstLight_PS;
        RenderTarget = LUNAR_FLOWER_TLPPFirstLightTex;
    }
    pass TwinLanternSecondBounce
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLPPBounce_PS;
        RenderTarget = LUNAR_FLOWER_TLPPBounceTex;
    }
    pass TwinLanternComposite
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLPPDisplay_PS;
    }
}
