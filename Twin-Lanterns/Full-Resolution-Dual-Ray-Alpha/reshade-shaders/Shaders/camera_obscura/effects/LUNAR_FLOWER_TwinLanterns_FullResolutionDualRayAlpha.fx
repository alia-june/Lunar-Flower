#include "ReShade.fxh"
// Match the shared ray-builder budget to the voxel trace's 32-step maximum.
#define CAMERA_OBSCURA_DDA_MAX_STEPS 32
#include "../api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh"
#include "../api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh"
#include "../api/LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh"

uniform int LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView
< ui_type = "combo"; ui_category = "Lunar Flower / Twin Lanterns / 00 Diagnostics"; ui_label = "Output View"; ui_items = "Final Image\0Source Image\0Bounded Indirect Light\0Evidence Confidence\0Applied Light\0Rejection Reason\0Remaining Channel Room\0Containment Activity\0Source Difference\0Bound Verification\0Edge Fill Target\0Edge Fill Added\0Fidelity Guard Activity\0Overdrive Pressure\0Voxel Surface Occupancy\0Voxel Surface Radiance\0Voxel Detail Level\0Depth Fade Mask\0"; ui_tooltip = "Final Image is the production output.\nDiagnostic views expose reconstructed light, admission evidence, containment, rendering intent, and the current-frame view-frustum voxel proxy.\nBound Verification must remain green."; > = 0;

uniform bool LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEnabled
< ui_type = "checkbox"; ui_category = "Lunar Flower / Twin Lanterns / 01 Light"; ui_label = "Enable Indirect Light"; ui_tooltip = "Applies bounded reconstructed indirect light.\nOff returns the source image exactly while diagnostics remain available."; > = true;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns / 01 Light"; ui_label = "Indirect Light Strength"; ui_min = 0.00; ui_max = 4.00; ui_step = 0.001; ui_tooltip = "Scales admitted indirect light after transport normalization and reconstruction evidence.\nFine adjustment: 0.001 per step (0.1 percentage point of nominal strength).\nFor 10-30% strength, use 0.100-0.300; zero returns the source image exactly."; > = 0.272000;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaMaximumContribution
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 01 Light"; ui_label = "Maximum Added Light"; ui_min = 0.00; ui_max = 0.50; ui_step = 0.005; ui_tooltip = "Hard per-channel ceiling for added normalized SDR light.\nThe result is also limited by the remaining room in each source channel."; > = 0.20;


uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns / 02 Depth Shaping"; ui_label = "Depth Fade Amount (0 = Off)"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Optional fade of final bounded Twin Lanterns added light.\n0 = Off; 1 = full removal at/after Fade End.\nDefault 0.355 follows the user preset; set 0 to disable fading.\nDepth uses ReShade normalized linear depth, not world distance."; > = 0.355000;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStart
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns / 02 Depth Shaping"; ui_label = "Depth Fade Start"; ui_min = 0.00000; ui_max = 1.00000; ui_step = 0.00001; ui_tooltip = "Normalized linear depth where fading and distant-light softening begin.\nUse Depth Fade Mask to tune this for the game; these values are not calibrated distances."; > = 0.00500;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns / 02 Depth Shaping"; ui_label = "Depth Fade End"; ui_min = 0.00000; ui_max = 1.00000; ui_step = 0.00001; ui_tooltip = "Normalized linear depth where fade and softening reach full authority.\nEnd is treated as at least Start plus 0.000001 to avoid a zero-width transition."; > = 0.05000;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSoftening
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns / 02 Depth Shaping"; ui_label = "Distant Light Softening"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Softens only the indirect-light field, increasing between Fade Start and End.\nFour neighboring taps are gated by Surface Depth and Direction Agreement.\nZero bypasses these taps. The source image is never blurred."; > = 1.000000;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSofteningRadiusPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 02 Depth Shaping"; ui_label = "Light Softening Radius"; ui_min = 1.0; ui_max = 4.0; ui_step = 1.0; ui_tooltip = "Radius in full-resolution pixels for four surface-gated indirect-light taps.\nThe fixed radius avoids depth-driven changes in the tap footprint."; > = 2.0;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaRayLengthPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 90 Transport"; ui_label = "Transport Distance"; ui_min = 4.0; ui_max = 24.0; ui_step = 1.0; ui_tooltip = "Maximum screen-space travel in pixels for each scheduled transport direction.\nLonger travel reaches farther donors and costs more work."; > = 24.0;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthSlope
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 90 Transport"; ui_label = "Ray Depth Slope"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Controls how quickly transport rays move through screen depth.\nHigher values search more aggressively across depth."; > = 0.16;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaFrontBias
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns / 90 Transport"; ui_label = "Front Surface Bias"; ui_min = 0.0000; ui_max = 0.0100; ui_step = 0.000001; ui_tooltip = "Front-side hit tolerance in normalized linear depth; this does not offset the ray origin.\nLarger values admit surfaces farther in front of the ray and also widen confidence weighting; they may increase light carry.\nFine adjustment: 0.000001 per step. Zero is valid; pixel-distance self-hit rejection is separate."; > = 0.000052;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBackThickness
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 90 Transport"; ui_label = "Back Surface Thickness"; ui_min = 0.0000; ui_max = 0.0200; ui_step = 0.0001; ui_tooltip = "Extends the accepted hit interval behind the ray.\nLarger values admit thicker surfaces but can increase leakage."; > = 0.0035;

uniform int LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaRayPairs
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 90 Transport"; ui_label = "Opposing Ray Pairs"; ui_min = 1; ui_max = 4; ui_step = 1; ui_tooltip = "Casts one to four opposing direction pairs per full-resolution pixel.\nTwo pairs reproduce the cardinal direction schedule; four pairs add both diagonals for eight rays total."; > = 1;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns / 90 Transport"; ui_label = "Voxel Proxy Lighting"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.001; ui_tooltip = "Blends admitted radiance from the current-frame view-frustum voxel proxy into each ray direction.\nFine adjustment: 0.001 per step; 0.100-0.300 is 10-30% voxel authority.\nThis proxy contains camera-visible depth evidence only and is not world voxel lighting."; > = 1.000000;

uniform int LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelTraceSteps
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 90 Transport"; ui_label = "Voxel Trace Steps"; ui_min = 4; ui_max = 32; ui_step = 1; ui_tooltip = "Maximum depth samples tested along each scheduled ray.\nHigher values increase sampling density within the configured transport distance and increase cost."; > = 24;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthTolerance
< ui_type = "drag"; ui_category = "Lunar Flower / Twin Lanterns / 91 Reconstruction"; ui_label = "Surface Depth Agreement"; ui_min = 0.0001; ui_max = 0.0500; ui_step = 0.00001; ui_tooltip = "Maximum depth disagreement admitted during reconstruction and edge fill.\nLower values reject differing-depth neighbors more strictly; higher values admit more neighboring light and may brighten or soften boundaries.\nFine adjustment: 0.00001 per step; this is a depth tolerance, not a light strength."; > = 0.0050;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaNormalMinimum
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 91 Reconstruction"; ui_label = "Surface Direction Agreement"; ui_min = 0.00; ui_max = 0.99; ui_step = 0.01; ui_tooltip = "Minimum agreement between reconstructed surface directions.\nHigher values preserve edges but may reduce support."; > = 0.80;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeProtection
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 91 Reconstruction"; ui_label = "Depth Edge Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Rejects reconstruction support near depth discontinuities.\nOne provides maximum protection against cross-surface light carry."; > = 1.00;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeInkStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 92 Style"; ui_label = "Edge Ink Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Adds the contour-heavy look created when rejected edge taps reduce visible light confidence.\nZero keeps surface rejection active without the AO-like edge emphasis.\nOne restores the original Twin Lantern edge treatment."; > = 0.00;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeFillStrength
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 92 Style"; ui_label = "Edge Fill Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Fills only positive deficits in the reconstructed indirect-light field near depth edges.\nThe source image is never blurred and depth/normal agreement prevents cross-surface carry.\nZero bypasses all edge-fill sampling."; > = 0.20;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeFillRadiusPixels
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 92 Style"; ui_label = "Edge Fill Radius"; ui_min = 1.00; ui_max = 4.00; ui_step = 0.25; ui_tooltip = "Distance in full-resolution pixels used to find same-surface indirect light around an edge.\nLarger values close wider dark troughs and cost the same four additional reads when fill is active."; > = 2.00;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaFidelityGuard
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 93 Intent"; ui_label = "Fidelity Guard"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Aligns transported light toward the receiver's existing color and reduces pressure near occupied highlight channels.\nIt protects the full-stack image without weakening dark-surface transport as strongly."; > = 0.65;

uniform float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaOverdrive
< ui_type = "slider"; ui_category = "Lunar Flower / Twin Lanterns / 93 Intent"; ui_label = "Overdrive"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Raises admitted Twin Lantern energy up to three times before hard contribution and channel-room bounds.\nOverdrive and Fidelity Guard can run together."; > = 0.00;

bool LUNAR_FLOWER_TLFRSourceOnly()
{
    return LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView == 1 ||
        (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView == 0 &&
         (!LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEnabled ||
          LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStrength <= 0.0));
}

[shader("compute")]
void LUNAR_FLOWER_TLFRBuildVoxelProxyCS(uint3 id : SV_DispatchThreadID)
{
    if (!LUNAR_FLOWER_TLFRSourceOnly() &&
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView != 17 &&
        (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength > 0.000001 ||
         (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView >= 14 &&
          LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView <= 16)))
        LUNAR_FLOWER_API_BuildTwinLanternVoxelTile(id);
}

texture2D LUNAR_FLOWER_TLFRRawTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

texture2D LUNAR_FLOWER_TLFRResolveHTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

texture2D LUNAR_FLOWER_TLFRResolveVTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler2D LUNAR_FLOWER_TLFRRawSampler
{
    Texture = LUNAR_FLOWER_TLFRRawTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D LUNAR_FLOWER_TLFRResolveHSampler
{
    Texture = LUNAR_FLOWER_TLFRResolveHTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D LUNAR_FLOWER_TLFRResolveVSampler
{
    Texture = LUNAR_FLOWER_TLFRResolveVTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

float2 LUNAR_FLOWER_TLFRFullTexel()
{
    return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
}

float LUNAR_FLOWER_TLFRRequestedCoverage(float2 requestedUv)
{
    return
        step(0.0, requestedUv.x) *
        step(requestedUv.x, 1.0) *
        step(0.0, requestedUv.y) *
        step(requestedUv.y, 1.0);
}

float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStyledEdgeProtection()
{
    return saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeProtection) *
        saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeInkStrength);
}

CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLFREvaluateHorizontal(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(LUNAR_FLOWER_TLFRFullTexel().x, 0.0);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = LUNAR_FLOWER_TLFRRequestedCoverage(negativeRequested);
    float positiveAvailable = LUNAR_FLOWER_TLFRRequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(LUNAR_FLOWER_TLFRRawSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            LUNAR_FLOWER_TLFRRawSampler, negativeRequested);
        negativeGuide = LUNAR_FLOWER_TLFRBuildSurfaceGuide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            LUNAR_FLOWER_TLFRRawSampler, positiveRequested);
        positiveGuide = LUNAR_FLOWER_TLFRBuildSurfaceGuide(positiveRequested);
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
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthTolerance,
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaNormalMinimum,
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStyledEdgeProtection());
}

CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLFREvaluateVertical(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(0.0, LUNAR_FLOWER_TLFRFullTexel().y);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = LUNAR_FLOWER_TLFRRequestedCoverage(negativeRequested);
    float positiveAvailable = LUNAR_FLOWER_TLFRRequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(LUNAR_FLOWER_TLFRResolveHSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            LUNAR_FLOWER_TLFRResolveHSampler, negativeRequested);
        negativeGuide = LUNAR_FLOWER_TLFRBuildSurfaceGuide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            LUNAR_FLOWER_TLFRResolveHSampler, positiveRequested);
        positiveGuide = LUNAR_FLOWER_TLFRBuildSurfaceGuide(positiveRequested);
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
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthTolerance,
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaNormalMinimum,
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStyledEdgeProtection());
}

float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaPairDirection(int pairIndex)
{
    if (pairIndex == 0) return 0.0;
    if (pairIndex == 1) return 2.0;
    if (pairIndex == 2) return 1.0;
    return 3.0;
}

void LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaAccumulateDirection(
    float2 uv,
    float directionIndex,
    CAMERA_OBSCURA_SurfaceGuide receiver,
    inout float3 weightedDonor,
    inout float evidenceSum)
{
    float4 screenEvidence =
        LUNAR_FLOWER_TLFRTraceScreenWithReceiver(
            uv, directionIndex,
            LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaRayLengthPixels,
            LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthSlope,
            LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaFrontBias,
            LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBackThickness,
            receiver);
    LUNAR_FLOWER_API_TwinLanternVoxelEvidence voxelEvidence =
        LUNAR_FLOWER_API_DefaultTwinLanternVoxelEvidence();
    if (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength > 0.000001)
    {
        voxelEvidence =
            LUNAR_FLOWER_API_TraceTwinLanternVoxelProxyWithReceiver(
                uv,
                directionIndex,
                LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaRayLengthPixels,
                LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthSlope,
                LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaFrontBias,
                LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBackThickness,
                (float)LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelTraceSteps,
                receiver);
    }
    float screenWeight = saturate(screenEvidence.a);
    float voxelWeight = saturate(voxelEvidence.evidence) *
        saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength);
    float donorWeight = screenWeight + voxelWeight;
    float hasDonor = step(0.000001, donorWeight);
    float3 donor = (
        screenEvidence.rgb * screenWeight +
        voxelEvidence.radiance_rgb * voxelWeight) *
        CAMERA_OBSCURA_SafeRcp(donorWeight, 0.0) * hasDonor;
    float directionEvidence = saturate(
        screenWeight + voxelWeight * (1.0 - screenWeight));

    weightedDonor += donor * directionEvidence;
    evidenceSum += directionEvidence;
}

float4 LUNAR_FLOWER_TLFRRaw_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLFRSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView == 17) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide receiver = LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
    if (receiver.valid < 0.5) return float4(0.0, 0.0, 0.0, 0.0);
    float3 weightedDonor = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    int pairCount = min(max(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaRayPairs, 1), 4);

    [loop]
    for (int pairIndex = 0; pairIndex < 4; ++pairIndex)
    {
        if (pairIndex >= pairCount)
        {
            break;
        }

        float directionIndex =
            LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaPairDirection(pairIndex);
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaAccumulateDirection(
            uv,
            directionIndex,
            receiver,
            weightedDonor,
            evidenceSum);
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaAccumulateDirection(
            uv,
            directionIndex + 4.0,
            receiver,
            weightedDonor,
            evidenceSum);
    }

    float hasEvidence = step(0.000001, evidenceSum);
    float3 donor = weightedDonor *
        CAMERA_OBSCURA_SafeRcp(evidenceSum, 0.0) * hasEvidence;
    float activeRayCount = max((float)(pairCount * 2), 1.0);
    float averagedEvidence = saturate(evidenceSum / activeRayCount);
    return float4(donor, averagedEvidence);
}

float LUNAR_FLOWER_TLFRVisibleConfidence(
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
        saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeInkStrength));
    return saturate(visibleConfidence);
}

float4 LUNAR_FLOWER_TLFRResolveH_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLFRSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView == 17) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        LUNAR_FLOWER_TLFREvaluateHorizontal(uv);
    return float4(
        evidence.resolved_rgb,
        LUNAR_FLOWER_TLFRVisibleConfidence(evidence));
}

float4 LUNAR_FLOWER_TLFRResolveV_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLFRSourceOnly()) return float4(0.0, 0.0, 0.0, 0.0);
    if (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView == 17) return float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        LUNAR_FLOWER_TLFREvaluateVertical(uv);
    return float4(
        evidence.resolved_rgb,
        LUNAR_FLOWER_TLFRVisibleConfidence(evidence));
}

float4 LUNAR_FLOWER_TLFRFullResolutionReconstruct(float2 uv, CAMERA_OBSCURA_SurfaceGuide centerGuide)
{
    if (centerGuide.valid < 0.5)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    float4 resolved = tex2D(LUNAR_FLOWER_TLFRResolveVSampler, uv);
    float trustedEvidence = saturate(resolved.a) *
        saturate(centerGuide.depth_confidence);
    return float4(saturate(resolved.rgb), trustedEvidence);
}

void LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(
    float2 requestedUv,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    inout float3 signalSum,
    inout float evidenceSum,
    inout float supportSum)
{
    float coverage = LUNAR_FLOWER_TLFRRequestedCoverage(requestedUv);
    [branch]
    if (coverage > 0.5)
    {
        CAMERA_OBSCURA_SurfaceGuide tapGuide =
            LUNAR_FLOWER_TLFRBuildSurfaceGuide(requestedUv);
        float depthSupport = CAMERA_OBSCURA_API_TL08DepthSupport(
            centerGuide, tapGuide, LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthTolerance);
        float normalSupport = CAMERA_OBSCURA_API_TL08NormalSupport(
            centerGuide, tapGuide, LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaNormalMinimum);
        float surfaceSupport = coverage * depthSupport * normalSupport;
        float4 sampleValue = tex2D(
            LUNAR_FLOWER_TLFRResolveVSampler, requestedUv);
        float sampleEvidence = saturate(sampleValue.a);

        signalSum += saturate(sampleValue.rgb) *
            sampleEvidence * surfaceSupport;
        evidenceSum += sampleEvidence * surfaceSupport;
        supportSum += surfaceSupport;
    }
}

float4 LUNAR_FLOWER_TLFRApplyEdgeFill(
    float2 uv,
    float4 baseIndirect,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    out float edgeFillTarget,
    out float3 edgeFillAdded)
{
    edgeFillTarget = 0.0;
    edgeFillAdded = float3(0.0, 0.0, 0.0);
    float safeStrength = saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeFillStrength);
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
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeFillRadiusPixels, 1.0, 4.0);
    float2 offset = float2(
        BUFFER_RCP_WIDTH * safeRadius,
        BUFFER_RCP_HEIGHT * safeRadius);
    float3 signalSum = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    float supportSum = 0.0;

    LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(
        uv - float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(
        uv + float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(
        uv - float2(0.0, offset.y), centerGuide,
        signalSum, evidenceSum, supportSum);
    LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(
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


float LUNAR_FLOWER_TLFRDepthPhase(float receiverDepth)
{
    float start = saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStart);
    float end = max(saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd), start + 0.000001);
    return smoothstep(start, end, saturate(receiverDepth));
}

float LUNAR_FLOWER_TLFRDepthFadeFactor(float receiverDepth)
{
    return 1.0 - saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength) *
        LUNAR_FLOWER_TLFRDepthPhase(receiverDepth);
}

float4 LUNAR_FLOWER_TLFRApplyDepthShaping(
    float2 uv, float4 baseIndirect, CAMERA_OBSCURA_SurfaceGuide centerGuide)
{
    if (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength <= 0.0 &&
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSoftening <= 0.0)
        return baseIndirect;
    if (centerGuide.valid < 0.5) return float4(0.0, 0.0, 0.0, 0.0);
    float phase = LUNAR_FLOWER_TLFRDepthPhase(centerGuide.depth);
    float fade = LUNAR_FLOWER_TLFRDepthFadeFactor(centerGuide.depth);
    if (fade <= 0.0) return baseIndirect; // Final composite removes the light; skip softening work.
    float amount = saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSoftening) * phase;
    float4 shaped = baseIndirect;
    [branch]
    if (amount > 0.000001)
    {
        float radius = clamp(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSofteningRadiusPixels, 1.0, 4.0);
        float2 offset = LUNAR_FLOWER_TLFRFullTexel() * radius;
        float baseEvidence = saturate(baseIndirect.a);
        float3 baseSignal = saturate(baseIndirect.rgb) * baseEvidence;
        float3 signalSum = baseSignal;
        float evidenceSum = baseEvidence;
        float supportSum = 1.0;
        // Existing depth/normal/coverage-gated taps read only ResolveV light.
        LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(uv - float2(offset.x, 0.0), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(uv + float2(offset.x, 0.0), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(uv - float2(0.0, offset.y), centerGuide, signalSum, evidenceSum, supportSum);
        LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(uv + float2(0.0, offset.y), centerGuide, signalSum, evidenceSum, supportSum);
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

float4 LUNAR_FLOWER_TLFRApplyRenderIntent(
    float3 source,
    float4 reconstructed,
    out float fidelityActivity,
    out float overdrivePressure,
    out float effectiveStrength)
{
    fidelityActivity = 0.0;
    overdrivePressure = 0.0;
    effectiveStrength = max(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStrength, 0.0);
    float safeFidelity = saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaFidelityGuard);
    float safeOverdrive = saturate(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaOverdrive);
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
    effectiveStrength = max(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStrength, 0.0) *
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
LUNAR_FLOWER_TLFRFadeComposite(
    CAMERA_OBSCURA_API_TL09CompositeEvidence result, float receiverDepth)
{
    float fade = LUNAR_FLOWER_TLFRDepthFadeFactor(receiverDepth);
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
LUNAR_FLOWER_TLFREvaluateComposite(
    float2 uv,
    out float edgeFillTarget,
    out float3 edgeFillAdded,
    out float fidelityActivity,
    out float overdrivePressure)
{
    CAMERA_OBSCURA_SurfaceGuide centerGuide = LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
    float4 vertical = LUNAR_FLOWER_TLFRFullResolutionReconstruct(uv, centerGuide);
    float4 reconstructed = LUNAR_FLOWER_TLFRApplyEdgeFill(
        uv, vertical, centerGuide, edgeFillTarget, edgeFillAdded);
    reconstructed = LUNAR_FLOWER_TLFRApplyDepthShaping(uv, reconstructed, centerGuide);
    float3 source = saturate(tex2D(ReShade::BackBuffer, uv).rgb);
    float effectiveStrength = 0.0;
    float4 intended = LUNAR_FLOWER_TLFRApplyRenderIntent(
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
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEnabled ? 1.0 : 0.0,
        effectiveStrength,
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaMaximumContribution);
    return LUNAR_FLOWER_TLFRFadeComposite(result, centerGuide.depth);
}

float3 LUNAR_FLOWER_TLFRRejectionColor(float rejectionCode)
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

float4 LUNAR_FLOWER_TLFRDisplay_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    if (LUNAR_FLOWER_TLFRSourceOnly())
        return float4(saturate(tex2D(ReShade::BackBuffer, uv).rgb), 1.0);
    if (LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView == 17)
    {
        float depth = CAMERA_OBSCURA_LoadDepth(uv);
        float mask = CAMERA_OBSCURA_DepthConfidence(depth) * LUNAR_FLOWER_TLFRDepthFadeFactor(depth);
        return float4(mask, mask, mask, 1.0);
    }

    float edgeFillTarget = 0.0;
    float3 edgeFillAdded = float3(0.0, 0.0, 0.0);
    float fidelityActivity = 0.0;
    float overdrivePressure = 0.0;
    CAMERA_OBSCURA_API_TL09CompositeEvidence evidence =
        LUNAR_FLOWER_TLFREvaluateComposite(
            uv,
            edgeFillTarget,
            edgeFillAdded,
            fidelityActivity,
            overdrivePressure);
    float view = (float)LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView;
    if (view < 0.5) return float4(evidence.final_rgb, 1.0);
    if (view < 1.5) return float4(evidence.source_rgb, 1.0);
    if (view < 2.5) return float4(evidence.bounded_indirect_rgb, 1.0);
    if (view < 3.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.evidence), 1.0);
    if (view < 4.5) return float4(
        evidence.bounded_contribution_rgb, 1.0);
    if (view < 5.5) return float4(
        LUNAR_FLOWER_TLFRRejectionColor(evidence.rejection_code), 1.0);
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
    float4 voxelSurface =
        LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(uv);
    if (view < 14.5) return float4(
        CAMERA_OBSCURA_DebugHeat(voxelSurface.a), 1.0);
    if (view < 15.5) return float4(saturate(voxelSurface.rgb), 1.0);
    return float4(CAMERA_OBSCURA_DebugHeat(
        LUNAR_FLOWER_API_TwinLanternVoxelDetailLevel(uv) * 0.5), 1.0);
}

technique LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlpha
< ui_label = "Lunar Flower - Twin Lanterns: Full Resolution Dual Ray Alpha"; ui_tooltip = "Full-resolution indirect light from one to four opposing ray pairs plus a current-frame view-frustum voxel-radiance proxy.\nThe proxy contains camera-visible depth evidence only; fidelity and overdrive remain inside the bounded source-preserving composite.\nRequires ReShade compute and 3D storage support; no denoiser or temporal history is included."; >
{
    pass TwinLanternVoxelBuild
    {
        ComputeShader = LUNAR_FLOWER_TLFRBuildVoxelProxyCS<8, 8, 1>;
        DispatchSizeX = 8;
        DispatchSizeY = 5;
        DispatchSizeZ = 1;
    }
    pass TwinLanternTransport
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLFRRaw_PS;
        RenderTarget = LUNAR_FLOWER_TLFRRawTex;
    }
    pass TwinLanternResolveHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLFRResolveH_PS;
        RenderTarget = LUNAR_FLOWER_TLFRResolveHTex;
    }
    pass TwinLanternResolveVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLFRResolveV_PS;
        RenderTarget = LUNAR_FLOWER_TLFRResolveVTex;
    }
    pass TwinLanternComposite
    {
        VertexShader = PostProcessVS;
        PixelShader = LUNAR_FLOWER_TLFRDisplay_PS;
    }
}
