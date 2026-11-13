#include "ReShade.fxh"
// Fixed budgets for cardinal/diagonal A/B: 32 DDA + 16 march samples per direction.
#define CAMERA_OBSCURA_DDA_MAX_STEPS 32
#include "../api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh"
#include "../api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh"

uniform int LUNAR_FLOWER_TwinLanternsDirectionLabView
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 00 Diagnostics"; ui_label = "Output View"; ui_items = "Final Image\0Source Image\0Bounded Indirect Light\0Evidence Confidence\0Applied Light\0Rejection Reason\0Remaining Channel Room\0Containment Activity\0Source Difference\0Bound Verification\0Edge Fill Target\0Edge Fill Added\0Fidelity Guard Activity\0Overdrive Pressure\0Depth Fade Mask\0DDA Hit Coverage\0March Hit Coverage\0DDA Admitted Weight\0March Admitted Weight\0DDA Raw Donor Color\0March Raw Donor Color\0DDA Weighted Signal\0March Weighted Signal\0Combined Raw Donor\0Combined Weighted Signal\0Receiver Validity\0"; ui_tooltip = "Final Image is the production output.\nDiagnostic views expose reconstructed screen-space light, admission evidence, containment, rendering intent, and depth fade.\nBound Verification must remain green."; > = 0;

uniform bool LUNAR_FLOWER_TwinLanternsDirectionLabEnabled
< ui_type = "checkbox"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 01 Light"; ui_label = "Enable Indirect Light"; ui_tooltip = "Applies bounded reconstructed indirect light.\nOff returns the source image exactly while diagnostics remain available."; > = true;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 01 Light"; ui_label = "Indirect Light Strength"; ui_min = 0.00; ui_max = 4.00; ui_step = 0.001; ui_tooltip = "Scales admitted indirect light after transport normalization and reconstruction evidence.\nFine adjustment: 0.001 per step (0.1 percentage point of nominal strength).\nFor 10-30% strength, use 0.100-0.300; zero returns the source image exactly."; > = 0.272000;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabMaximumContribution
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 01 Light"; ui_label = "Maximum Added Light"; ui_min = 0.00; ui_max = 0.50; ui_step = 0.005; ui_tooltip = "Hard per-channel ceiling for added normalized SDR light.\nThe result is also limited by the remaining room in each source channel."; > = 0.20;


uniform float LUNAR_FLOWER_TwinLanternsDirectionLabDepthFadeStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 02 Depth Shaping"; ui_label = "Depth Fade Amount (0 = Off)"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Optional fade of final bounded Twin Lanterns added light.\n0 = Off; 1 = full removal at/after Fade End.\nDefault 0.355 follows the user preset; set 0 to disable fading.\nDepth uses ReShade normalized linear depth, not world distance."; > = 0.355000;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabDepthFadeStart
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 02 Depth Shaping"; ui_label = "Depth Fade Start"; ui_min = 0.00000; ui_max = 1.00000; ui_step = 0.00001; ui_tooltip = "Normalized linear depth where fading and distant-light softening begin.\nUse Depth Fade Mask to tune this for the game; these values are not calibrated distances."; > = 0.00500;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabDepthFadeEnd
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 02 Depth Shaping"; ui_label = "Depth Fade End"; ui_min = 0.00000; ui_max = 1.00000; ui_step = 0.00001; ui_tooltip = "Normalized linear depth where fade and softening reach full authority.\nEnd is treated as at least Start plus 0.000001 to avoid a zero-width transition."; > = 0.05000;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabLightSoftening
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 02 Depth Shaping"; ui_label = "Distant Light Softening"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Softens only the indirect-light field, increasing between Fade Start and End.\nFour neighboring taps are gated by Surface Depth and Direction Agreement.\nZero bypasses these taps. The source image is never blurred."; > = 1.000000;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabLightSofteningRadiusPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 02 Depth Shaping"; ui_label = "Light Softening Radius"; ui_min = 1.0; ui_max = 4.0; ui_step = 1.0; ui_tooltip = "Radius in full-resolution pixels for four surface-gated indirect-light taps.\nThe fixed radius avoids depth-driven changes in the tap footprint."; > = 2.0;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabRayLengthPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 90 Transport"; ui_label = "Transport Distance"; ui_min = 4.0; ui_max = 24.0; ui_step = 1.0; ui_tooltip = "Screen-space travel in pixels for each scheduled direction.\nChanges reach and sample spacing while maximum provider sample counts remain fixed. Actual work can vary with early hits or screen exits."; > = 24.0;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabDepthSlope
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 90 Transport"; ui_label = "Ray Depth Slope"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Controls normalized depth travel per pixel using the mean horizontal/vertical pixel pitch.\nDepth travel is independent of direction so cardinal/diagonal testing uses the same depth interval."; > = 0.16;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabFrontBias
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 90 Transport"; ui_label = "Front Surface Bias"; ui_min = 0.0000; ui_max = 0.0100; ui_step = 0.000001; ui_tooltip = "Front-side hit tolerance in normalized linear depth; this does not offset the ray origin.\nLarger values admit surfaces farther in front of the ray and also widen confidence weighting; they may increase light carry.\nFine adjustment: 0.000001 per step. Zero is valid; pixel-distance self-hit rejection is separate."; > = 0.000052;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabBackThickness
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 90 Transport"; ui_label = "Back Surface Thickness"; ui_min = 0.0000; ui_max = 0.0200; ui_step = 0.0001; ui_tooltip = "Extends the accepted hit interval behind the ray.\nLarger values admit thicker surfaces but can increase leakage."; > = 0.0035;

uniform int LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 01 Experiment"; ui_label = "Direction Set"; ui_items = "Cardinal (4 directions)\0Diagonal (4 directions)\0Mixed (8 directions)\0"; ui_tooltip = "Cardinal and Diagonal use equal direction counts, distance, provider budgets and normalization.\nMixed doubles the directions and maximum work; it is a separate coverage experiment."; > = 0;

uniform int LUNAR_FLOWER_TwinLanternsDirectionLabProviderMode
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 01 Experiment"; ui_label = "Provider"; ui_items = "DDA + March\0DDA Only\0March Only\0"; ui_tooltip = "Selects the traversal providers in both production and diagnostics.\nEach selected provider is normalized by its own direction count. DDA has 32 samples per direction; march has 16.\nDisabled providers are not traced."; > = 0;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabDepthTolerance
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 91 Reconstruction"; ui_label = "Surface Depth Agreement"; ui_min = 0.0001; ui_max = 0.0500; ui_step = 0.00001; ui_tooltip = "Maximum depth disagreement admitted during reconstruction and edge fill.\nLower values reject differing-depth neighbors more strictly; higher values admit more neighboring light and may brighten or soften boundaries.\nFine adjustment: 0.00001 per step; this is a depth tolerance, not a light strength."; > = 0.0050;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabNormalMinimum
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 91 Reconstruction"; ui_label = "Surface Direction Agreement"; ui_min = 0.00; ui_max = 0.99; ui_step = 0.01; ui_tooltip = "Minimum agreement between reconstructed surface directions.\nHigher values preserve edges but may reduce support."; > = 0.80;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabEdgeProtection
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 91 Reconstruction"; ui_label = "Depth Edge Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Rejects reconstruction support near depth discontinuities.\nOne provides maximum protection against cross-surface light carry."; > = 1.00;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabEdgeInkStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 92 Style"; ui_label = "Edge Ink Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Adds the contour-heavy look created when rejected edge taps reduce visible light confidence.\nZero keeps surface rejection active without the AO-like edge emphasis.\nOne restores the original Twin Lantern edge treatment."; > = 0.00;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabEdgeFillStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 92 Style"; ui_label = "Edge Fill Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Fills only positive deficits in the reconstructed indirect-light field near depth edges.\nThe source image is never blurred and depth/normal agreement prevents cross-surface carry.\nZero bypasses all edge-fill sampling."; > = 0.20;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabEdgeFillRadiusPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 92 Style"; ui_label = "Edge Fill Radius"; ui_min = 1.00; ui_max = 4.00; ui_step = 0.25; ui_tooltip = "Distance in full-resolution pixels used to find same-surface indirect light around an edge.\nLarger values close wider dark troughs and cost the same four additional reads when fill is active."; > = 2.00;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabFidelityGuard
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 93 Intent"; ui_label = "Fidelity Guard"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Aligns transported light toward the receiver's existing color and reduces pressure near occupied highlight channels.\nIt protects the full-stack image without weakening dark-surface transport as strongly."; > = 0.65;

uniform float LUNAR_FLOWER_TwinLanternsDirectionLabOverdrive
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns Direction Lab / 93 Intent"; ui_label = "Overdrive"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Raises admitted Twin Lantern energy up to three times before hard contribution and channel-room bounds.\nOverdrive and Fidelity Guard can run together."; > = 0.00;

bool LUNAR_FLOWER_TLDLSourceOnly()
{
    return LUNAR_FLOWER_TwinLanternsDirectionLabView == 1 ||
        (LUNAR_FLOWER_TwinLanternsDirectionLabView == 0 &&
         (!LUNAR_FLOWER_TwinLanternsDirectionLabEnabled ||
          LUNAR_FLOWER_TwinLanternsDirectionLabStrength <= 0.0));
}

texture2D LUNAR_FLOWER_TLDLRawTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

texture2D LUNAR_FLOWER_TLDLResolveHTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

texture2D LUNAR_FLOWER_TLDLResolveVTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler2D LUNAR_FLOWER_TLDLRawSampler
{
    Texture = LUNAR_FLOWER_TLDLRawTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D LUNAR_FLOWER_TLDLResolveHSampler
{
    Texture = LUNAR_FLOWER_TLDLResolveHTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D LUNAR_FLOWER_TLDLResolveVSampler
{
    Texture = LUNAR_FLOWER_TLDLResolveVTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

float2 LUNAR_FLOWER_TLDLFullTexel()
{
    return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
}

float LUNAR_FLOWER_TLDLRequestedCoverage(float2 requestedUv)
{
    return
        step(0.0, requestedUv.x) *
        step(requestedUv.x, 1.0) *
        step(0.0, requestedUv.y) *
        step(requestedUv.y, 1.0);
}

float LUNAR_FLOWER_TwinLanternsDirectionLabStyledEdgeProtection()
{
    return saturate(LUNAR_FLOWER_TwinLanternsDirectionLabEdgeProtection) *
        saturate(LUNAR_FLOWER_TwinLanternsDirectionLabEdgeInkStrength);
}

CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLDLEvaluateHorizontal(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        LUNAR_FLOWER_TLDLBuildSurfaceGuide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(LUNAR_FLOWER_TLDLFullTexel().x, 0.0);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = LUNAR_FLOWER_TLDLRequestedCoverage(negativeRequested);
    float positiveAvailable = LUNAR_FLOWER_TLDLRequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(LUNAR_FLOWER_TLDLRawSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            LUNAR_FLOWER_TLDLRawSampler, negativeRequested);
        negativeGuide = LUNAR_FLOWER_TLDLBuildSurfaceGuide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            LUNAR_FLOWER_TLDLRawSampler, positiveRequested);
        positiveGuide = LUNAR_FLOWER_TLDLBuildSurfaceGuide(positiveRequested);
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
        LUNAR_FLOWER_TwinLanternsDirectionLabDepthTolerance,
        LUNAR_FLOWER_TwinLanternsDirectionLabNormalMinimum,
        LUNAR_FLOWER_TwinLanternsDirectionLabStyledEdgeProtection());
}

CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLDLEvaluateVertical(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        LUNAR_FLOWER_TLDLBuildSurfaceGuide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(0.0, LUNAR_FLOWER_TLDLFullTexel().y);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = LUNAR_FLOWER_TLDLRequestedCoverage(negativeRequested);
    float positiveAvailable = LUNAR_FLOWER_TLDLRequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(LUNAR_FLOWER_TLDLResolveHSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            LUNAR_FLOWER_TLDLResolveHSampler, negativeRequested);
        negativeGuide = LUNAR_FLOWER_TLDLBuildSurfaceGuide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            LUNAR_FLOWER_TLDLResolveHSampler, positiveRequested);
        positiveGuide = LUNAR_FLOWER_TLDLBuildSurfaceGuide(positiveRequested);
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
        LUNAR_FLOWER_TwinLanternsDirectionLabDepthTolerance,
        LUNAR_FLOWER_TwinLanternsDirectionLabNormalMinimum,
        LUNAR_FLOWER_TwinLanternsDirectionLabStyledEdgeProtection());
}

int LUNAR_FLOWER_TLDLDirectionCount()
{
    return LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet >= 2 ? 8 : 4;
}

float LUNAR_FLOWER_TLDLDirectionIndex(int slot)
{
    if (LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet >= 2) return (float)slot;
    return (float)(slot * 2 + (LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet == 1 ? 1 : 0));
}

struct LUNAR_FLOWER_TLDLDirectionEvidence
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

LUNAR_FLOWER_TLDLDirectionEvidence LUNAR_FLOWER_TLDLEvaluateDirections(float2 uv)
{
    LUNAR_FLOWER_TLDLDirectionEvidence result;
    result.combined = float4(0.0, 0.0, 0.0, 0.0);
    result.dda_donor_sum = float3(0.0, 0.0, 0.0);
    result.march_donor_sum = float3(0.0, 0.0, 0.0);
    result.dda_signal = float3(0.0, 0.0, 0.0);
    result.march_signal = float3(0.0, 0.0, 0.0);
    result.dda_hits = 0.0;
    result.march_hits = 0.0;
    result.dda_weight = 0.0;
    result.march_weight = 0.0;
    CAMERA_OBSCURA_SurfaceGuide receiver = LUNAR_FLOWER_TLDLBuildSurfaceGuide(uv);
    result.receiver_valid = receiver.valid;
    if (receiver.valid < 0.5) return result;
    int directionCount = LUNAR_FLOWER_TLDLDirectionCount();
    float3 weightedDonor = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    [loop]
    for (int slot = 0; slot < 8; ++slot)
    {
        if (slot >= directionCount) break;
        LUNAR_FLOWER_TLDLScreenEvidence screen = LUNAR_FLOWER_TLDLTraceScreenDetailed(
            uv, LUNAR_FLOWER_TLDLDirectionIndex(slot),
            LUNAR_FLOWER_TwinLanternsDirectionLabRayLengthPixels,
            LUNAR_FLOWER_TwinLanternsDirectionLabDepthSlope,
            LUNAR_FLOWER_TwinLanternsDirectionLabFrontBias,
            LUNAR_FLOWER_TwinLanternsDirectionLabBackThickness,
            LUNAR_FLOWER_TwinLanternsDirectionLabProviderMode,
            receiver);
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

float4 LUNAR_FLOWER_TLDLRaw_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLDLSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (LUNAR_FLOWER_TwinLanternsDirectionLabView >= 14) return float4(0.0, 0.0, 0.0, 0.0);
    return LUNAR_FLOWER_TLDLEvaluateDirections(uv).combined;
}

float LUNAR_FLOWER_TLDLVisibleConfidence(
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
        saturate(LUNAR_FLOWER_TwinLanternsDirectionLabEdgeInkStrength));
    return saturate(visibleConfidence);
}

float4 LUNAR_FLOWER_TLDLResolveH_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLDLSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (LUNAR_FLOWER_TwinLanternsDirectionLabView >= 14) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        LUNAR_FLOWER_TLDLEvaluateHorizontal(uv);
    return float4(
        evidence.resolved_rgb,
        LUNAR_FLOWER_TLDLVisibleConfidence(evidence));
}

float4 LUNAR_FLOWER_TLDLResolveV_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLDLSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (LUNAR_FLOWER_TwinLanternsDirectionLabView >= 14) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        LUNAR_FLOWER_TLDLEvaluateVertical(uv);
    return float4(
        evidence.resolved_rgb,
        LUNAR_FLOWER_TLDLVisibleConfidence(evidence));
}

float4 LUNAR_FLOWER_TLDLFullResolutionReconstruct(float2 uv, CAMERA_OBSCURA_SurfaceGuide centerGuide)
{
    if (centerGuide.valid < 0.5)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    float4 resolved = tex2D(LUNAR_FLOWER_TLDLResolveVSampler, uv);
    float trustedEvidence = saturate(resolved.a) *
        saturate(centerGuide.depth_confidence);
    return float4(saturate(resolved.rgb), trustedEvidence);
}

void LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(
    float2 requestedUv,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    inout float3 signalSum,
    inout float evidenceSum,
    inout float supportSum)
{
    float coverage = LUNAR_FLOWER_TLDLRequestedCoverage(requestedUv);
    [branch]
    if (coverage > 0.5)
    {
        CAMERA_OBSCURA_SurfaceGuide tapGuide =
            LUNAR_FLOWER_TLDLBuildSurfaceGuide(requestedUv);
        float depthSupport = CAMERA_OBSCURA_API_TL08DepthSupport(
            centerGuide, tapGuide, LUNAR_FLOWER_TwinLanternsDirectionLabDepthTolerance);
        float normalSupport = CAMERA_OBSCURA_API_TL08NormalSupport(
            centerGuide, tapGuide, LUNAR_FLOWER_TwinLanternsDirectionLabNormalMinimum);
        float surfaceSupport = coverage * depthSupport * normalSupport;
        float4 sampleValue = tex2D(
            LUNAR_FLOWER_TLDLResolveVSampler, requestedUv);
        float sampleEvidence = saturate(sampleValue.a);

        signalSum += saturate(sampleValue.rgb) *
            sampleEvidence * surfaceSupport;
        evidenceSum += sampleEvidence * surfaceSupport;
        supportSum += surfaceSupport;
    }
}

float4 LUNAR_FLOWER_TLDLApplyEdgeFill(
    float2 uv,
    float4 baseIndirect,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    out float edgeFillTarget,
    out float3 edgeFillAdded)
{
    edgeFillTarget = 0.0;
    edgeFillAdded = float3(0.0, 0.0, 0.0);
    float safeStrength = saturate(LUNAR_FLOWER_TwinLanternsDirectionLabEdgeFillStrength);
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
        LUNAR_FLOWER_TwinLanternsDirectionLabEdgeFillRadiusPixels, 1.0, 4.0);
    float2 offset = float2(
        BUFFER_RCP_WIDTH * safeRadius,
        BUFFER_RCP_HEIGHT * safeRadius);
    float3 signalSum = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    float supportSum = 0.0;

    LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(
        uv - float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(
        uv + float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(
        uv - float2(0.0, offset.y), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(
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


float LUNAR_FLOWER_TLDLDepthPhase(float receiverDepth)
{
    float start = saturate(LUNAR_FLOWER_TwinLanternsDirectionLabDepthFadeStart);
    float end = max(saturate(LUNAR_FLOWER_TwinLanternsDirectionLabDepthFadeEnd), start + 0.000001);
    return smoothstep(start, end, saturate(receiverDepth));
}

float LUNAR_FLOWER_TLDLDepthFadeFactor(float receiverDepth)
{
    return 1.0 - saturate(LUNAR_FLOWER_TwinLanternsDirectionLabDepthFadeStrength) *
        LUNAR_FLOWER_TLDLDepthPhase(receiverDepth);
}

float4 LUNAR_FLOWER_TLDLApplyDepthShaping(
    float2 uv, float4 baseIndirect, CAMERA_OBSCURA_SurfaceGuide centerGuide)
{
    if (LUNAR_FLOWER_TwinLanternsDirectionLabDepthFadeStrength <= 0.0 &&
        LUNAR_FLOWER_TwinLanternsDirectionLabLightSoftening <= 0.0)
        return baseIndirect;
    if (centerGuide.valid < 0.5) return float4(0.0, 0.0, 0.0, 0.0);
    float phase = LUNAR_FLOWER_TLDLDepthPhase(centerGuide.depth);
    float fade = LUNAR_FLOWER_TLDLDepthFadeFactor(centerGuide.depth);
    if (fade <= 0.0) return baseIndirect; // Final composite removes the light; skip softening work.
    float amount = saturate(LUNAR_FLOWER_TwinLanternsDirectionLabLightSoftening) * phase;
    float4 shaped = baseIndirect;
    [branch]
    if (amount > 0.000001)
    {
        float radius = clamp(LUNAR_FLOWER_TwinLanternsDirectionLabLightSofteningRadiusPixels, 1.0, 4.0);
        float2 offset = LUNAR_FLOWER_TLDLFullTexel() * radius;
        float baseEvidence = saturate(baseIndirect.a);
        float3 baseSignal = saturate(baseIndirect.rgb) * baseEvidence;
        float3 signalSum = baseSignal;
        float evidenceSum = baseEvidence;
        float supportSum = 1.0;
        // Existing depth/normal/coverage-gated taps read only ResolveV light.
        LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(uv - float2(offset.x, 0.0), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(uv + float2(offset.x, 0.0), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(uv - float2(0.0, offset.y), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLDLAccumulateEdgeFillTap(uv + float2(0.0, offset.y), centerGuide, signalSum, evidenceSum, supportSum);
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

float4 LUNAR_FLOWER_TLDLApplyRenderIntent(
    float3 source,
    float4 reconstructed,
    out float fidelityActivity,
    out float overdrivePressure,
    out float effectiveStrength)
{
    fidelityActivity = 0.0;
    overdrivePressure = 0.0;
    effectiveStrength = max(LUNAR_FLOWER_TwinLanternsDirectionLabStrength, 0.0);
    float safeFidelity = saturate(LUNAR_FLOWER_TwinLanternsDirectionLabFidelityGuard);
    float safeOverdrive = saturate(LUNAR_FLOWER_TwinLanternsDirectionLabOverdrive);
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
    effectiveStrength = max(LUNAR_FLOWER_TwinLanternsDirectionLabStrength, 0.0) *
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
LUNAR_FLOWER_TLDLFadeComposite(
    CAMERA_OBSCURA_API_TL09CompositeEvidence result, float receiverDepth)
{
    float fade = LUNAR_FLOWER_TLDLDepthFadeFactor(receiverDepth);
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
LUNAR_FLOWER_TLDLEvaluateComposite(
    float2 uv,
    out float edgeFillTarget,
    out float3 edgeFillAdded,
    out float fidelityActivity,
    out float overdrivePressure)
{
    CAMERA_OBSCURA_SurfaceGuide centerGuide = LUNAR_FLOWER_TLDLBuildSurfaceGuide(uv);
    float4 vertical = LUNAR_FLOWER_TLDLFullResolutionReconstruct(uv, centerGuide);
    float4 reconstructed = LUNAR_FLOWER_TLDLApplyEdgeFill(
        uv, vertical, centerGuide, edgeFillTarget, edgeFillAdded);
    reconstructed = LUNAR_FLOWER_TLDLApplyDepthShaping(uv, reconstructed, centerGuide);
    float3 source = saturate(tex2D(ReShade::BackBuffer, uv).rgb);
    float effectiveStrength = 0.0;
    float4 intended = LUNAR_FLOWER_TLDLApplyRenderIntent(
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
        LUNAR_FLOWER_TwinLanternsDirectionLabEnabled ? 1.0 : 0.0,
        effectiveStrength,
        LUNAR_FLOWER_TwinLanternsDirectionLabMaximumContribution);
    return LUNAR_FLOWER_TLDLFadeComposite(result, centerGuide.depth);
}

float3 LUNAR_FLOWER_TLDLRejectionColor(float rejectionCode)
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

float4 LUNAR_FLOWER_TLDLDisplay_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLDLSourceOnly())
        return float4(saturate(tex2D(ReShade::BackBuffer, uv).rgb), 1.0);
    if (LUNAR_FLOWER_TwinLanternsDirectionLabView == 14)
    {
        float depth = CAMERA_OBSCURA_LoadDepth(uv);
        float mask = CAMERA_OBSCURA_DepthConfidence(depth) * LUNAR_FLOWER_TLDLDepthFadeFactor(depth);
        return float4(mask, mask, mask, 1.0);
    }

    if (LUNAR_FLOWER_TwinLanternsDirectionLabView >= 15)
    {
        LUNAR_FLOWER_TLDLDirectionEvidence diagnostic = LUNAR_FLOWER_TLDLEvaluateDirections(uv);
        int diagnosticView = LUNAR_FLOWER_TwinLanternsDirectionLabView;
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

    float edgeFillTarget = 0.0;
    float3 edgeFillAdded = float3(0.0, 0.0, 0.0);
    float fidelityActivity = 0.0;
    float overdrivePressure = 0.0;
    CAMERA_OBSCURA_API_TL09CompositeEvidence evidence =
        LUNAR_FLOWER_TLDLEvaluateComposite(
            uv,
            edgeFillTarget,
            edgeFillAdded,
            fidelityActivity,
            overdrivePressure);
    float view = (float)LUNAR_FLOWER_TwinLanternsDirectionLabView;
    if (view < 0.5) return float4(evidence.final_rgb, 1.0);
    if (view < 1.5) return float4(evidence.source_rgb, 1.0);
    if (view < 2.5) return float4(evidence.bounded_indirect_rgb, 1.0);
    if (view < 3.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.evidence), 1.0);
    if (view < 4.5) return float4(
        evidence.bounded_contribution_rgb, 1.0);
    if (view < 5.5) return float4(
        LUNAR_FLOWER_TLDLRejectionColor(evidence.rejection_code), 1.0);
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

technique LUNAR_FLOWER_TwinLanternsDirectionLab
< ui_label = "Lunar Flower - Twin Lanterns: Direction Lab"; ui_tooltip = "Voxel-free directional coverage experiment.\nCompare four cardinal with four diagonal directions at fixed DDA/march sample budgets and equal pixel/depth travel. Mixed uses eight directions and more work.\nProvider diagnostics expose hits, raw donors and weighted signals before reconstruction/strength/fade. Four pixel passes; current-frame screen evidence only."; >
{
    pass TwinLanternTransport
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLDLRaw_PS;
        RenderTarget = LUNAR_FLOWER_TLDLRawTex;
    }
    pass TwinLanternResolveHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLDLResolveH_PS;
        RenderTarget = LUNAR_FLOWER_TLDLResolveHTex;
    }
    pass TwinLanternResolveVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLDLResolveV_PS;
        RenderTarget = LUNAR_FLOWER_TLDLResolveVTex;
    }
    pass TwinLanternComposite
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLDLDisplay_PS;
    }
}
