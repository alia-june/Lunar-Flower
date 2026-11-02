#include "ReShade.fxh"
#include "../api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh"

uniform int CAMERA_OBSCURA_TwinLanternView
< ui_type = "combo"; ui_category = "Camera Obscura / Twin Lantern / 00 Diagnostics"; ui_label = "Output View"; ui_items = "Final Image\0Source Image\0Bounded Indirect Light\0Evidence Confidence\0Applied Light\0Rejection Reason\0Remaining Channel Room\0Containment Activity\0Source Difference\0Bound Verification\0Edge Fill Target\0Edge Fill Added\0"; ui_tooltip = "Final Image is the production output.\nDiagnostic views expose reconstructed light, admission evidence, containment, edge-fill authority, and exact source preservation.\nBound Verification must remain green."; > = 0;

uniform bool CAMERA_OBSCURA_TwinLanternEnabled
< ui_type = "checkbox"; ui_category = "Camera Obscura / Twin Lantern / 01 Light"; ui_label = "Enable Indirect Light"; ui_tooltip = "Applies bounded reconstructed indirect light.\nOff returns the source image exactly while diagnostics remain available."; > = true;

uniform float CAMERA_OBSCURA_TwinLanternStrength
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 01 Light"; ui_label = "Indirect Light Strength"; ui_min = 0.00; ui_max = 4.00; ui_step = 0.01; ui_tooltip = "Scales admitted indirect light after transport normalization and reconstruction evidence.\nZero returns the source image exactly."; > = 1.00;

uniform float CAMERA_OBSCURA_TwinLanternMaximumContribution
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 01 Light"; ui_label = "Maximum Added Light"; ui_min = 0.00; ui_max = 0.50; ui_step = 0.005; ui_tooltip = "Hard per-channel ceiling for added normalized SDR light.\nThe result is also limited by the remaining room in each source channel."; > = 0.20;

uniform float CAMERA_OBSCURA_TwinLanternRayLengthPixels
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 90 Transport"; ui_label = "Transport Distance"; ui_min = 4.0; ui_max = 24.0; ui_step = 1.0; ui_tooltip = "Maximum screen-space travel in pixels for each cardinal transport direction.\nLonger travel reaches farther donors and costs more work."; > = 24.0;

uniform float CAMERA_OBSCURA_TwinLanternDepthSlope
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 90 Transport"; ui_label = "Ray Depth Slope"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Controls how quickly transport rays move through screen depth.\nHigher values search more aggressively across depth."; > = 0.16;

uniform float CAMERA_OBSCURA_TwinLanternFrontBias
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 90 Transport"; ui_label = "Front Surface Bias"; ui_min = 0.0000; ui_max = 0.0100; ui_step = 0.0001; ui_tooltip = "Moves the accepted hit interval slightly toward the camera.\nUse only enough bias to avoid self-intersection."; > = 0.0005;

uniform float CAMERA_OBSCURA_TwinLanternBackThickness
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 90 Transport"; ui_label = "Back Surface Thickness"; ui_min = 0.0000; ui_max = 0.0200; ui_step = 0.0001; ui_tooltip = "Extends the accepted hit interval behind the ray.\nLarger values admit thicker surfaces but can increase leakage."; > = 0.0035;

uniform float CAMERA_OBSCURA_TwinLanternDepthTolerance
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 91 Reconstruction"; ui_label = "Surface Depth Agreement"; ui_min = 0.0001; ui_max = 0.0500; ui_step = 0.0001; ui_tooltip = "Maximum depth disagreement admitted during reconstruction.\nLower values protect boundaries more strictly."; > = 0.0050;

uniform float CAMERA_OBSCURA_TwinLanternNormalMinimum
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 91 Reconstruction"; ui_label = "Surface Direction Agreement"; ui_min = 0.00; ui_max = 0.99; ui_step = 0.01; ui_tooltip = "Minimum agreement between reconstructed surface directions.\nHigher values preserve edges but may reduce support."; > = 0.80;

uniform float CAMERA_OBSCURA_TwinLanternEdgeProtection
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 91 Reconstruction"; ui_label = "Depth Edge Protection"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Rejects reconstruction support near depth discontinuities.\nOne provides maximum protection against cross-surface light carry."; > = 1.00;

uniform float CAMERA_OBSCURA_TwinLanternEdgeInkStrength
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 92 Style"; ui_label = "Edge Ink Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Adds the contour-heavy look created when rejected edge taps reduce visible light confidence.\nZero keeps surface rejection active without the AO-like edge emphasis.\nOne restores the original Twin Lantern edge treatment."; > = 0.00;

uniform float CAMERA_OBSCURA_TwinLanternEdgeFillStrength
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 92 Style"; ui_label = "Edge Fill Strength"; ui_min = 0.00; ui_max = 1.00; ui_step = 0.01; ui_tooltip = "Fills only positive deficits in the reconstructed indirect-light field near depth edges.\nThe source image is never blurred and depth/normal agreement prevents cross-surface carry.\nZero bypasses all edge-fill sampling."; > = 0.20;

uniform float CAMERA_OBSCURA_TwinLanternEdgeFillRadiusPixels
< ui_type = "slider"; ui_category = "Camera Obscura / Twin Lantern / 92 Style"; ui_label = "Edge Fill Radius"; ui_min = 1.00; ui_max = 4.00; ui_step = 0.25; ui_tooltip = "Distance in full-resolution pixels used to find same-surface indirect light around an edge.\nLarger values close wider dark troughs and cost the same four additional reads when fill is active."; > = 2.00;

texture2D CAMERA_OBSCURA_TL09RawTex
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RGBA16F;
};

texture2D CAMERA_OBSCURA_TL09ResolveHTex
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RGBA16F;
};

texture2D CAMERA_OBSCURA_TL09ResolveVTex
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RGBA16F;
};

sampler2D CAMERA_OBSCURA_TL09RawSampler
{
    Texture = CAMERA_OBSCURA_TL09RawTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D CAMERA_OBSCURA_TL09ResolveHSampler
{
    Texture = CAMERA_OBSCURA_TL09ResolveHTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler2D CAMERA_OBSCURA_TL09ResolveVSampler
{
    Texture = CAMERA_OBSCURA_TL09ResolveVTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

float2 CAMERA_OBSCURA_TL09HalfTexel()
{
    return float2(BUFFER_RCP_WIDTH * 2.0, BUFFER_RCP_HEIGHT * 2.0);
}

float CAMERA_OBSCURA_TL09RequestedCoverage(float2 requestedUv)
{
    return
        step(0.0, requestedUv.x) *
        step(requestedUv.x, 1.0) *
        step(0.0, requestedUv.y) *
        step(requestedUv.y, 1.0);
}

float CAMERA_OBSCURA_TwinLanternStyledEdgeProtection()
{
    return saturate(CAMERA_OBSCURA_TwinLanternEdgeProtection) *
        saturate(CAMERA_OBSCURA_TwinLanternEdgeInkStrength);
}

CAMERA_OBSCURA_API_TL08ResolveEvidence CAMERA_OBSCURA_TL09EvaluateHorizontal(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        CAMERA_OBSCURA_API_BuildTL08Guide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(CAMERA_OBSCURA_TL09HalfTexel().x, 0.0);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = CAMERA_OBSCURA_TL09RequestedCoverage(negativeRequested);
    float positiveAvailable = CAMERA_OBSCURA_TL09RequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(CAMERA_OBSCURA_TL09RawSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            CAMERA_OBSCURA_TL09RawSampler, negativeRequested);
        negativeGuide = CAMERA_OBSCURA_API_BuildTL08Guide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            CAMERA_OBSCURA_TL09RawSampler, positiveRequested);
        positiveGuide = CAMERA_OBSCURA_API_BuildTL08Guide(positiveRequested);
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
        CAMERA_OBSCURA_TwinLanternDepthTolerance,
        CAMERA_OBSCURA_TwinLanternNormalMinimum,
        CAMERA_OBSCURA_TwinLanternStyledEdgeProtection());
}

CAMERA_OBSCURA_API_TL08ResolveEvidence CAMERA_OBSCURA_TL09EvaluateVertical(
    float2 uv)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence denied =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        CAMERA_OBSCURA_API_BuildTL08Guide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return denied;
    }

    float2 offset = float2(0.0, CAMERA_OBSCURA_TL09HalfTexel().y);
    float2 negativeRequested = uv - offset;
    float2 positiveRequested = uv + offset;
    float negativeAvailable = CAMERA_OBSCURA_TL09RequestedCoverage(negativeRequested);
    float positiveAvailable = CAMERA_OBSCURA_TL09RequestedCoverage(positiveRequested);
    float4 negativeValue = float4(0.0, 0.0, 0.0, 0.0);
    float4 positiveValue = float4(0.0, 0.0, 0.0, 0.0);
    CAMERA_OBSCURA_SurfaceGuide negativeGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    CAMERA_OBSCURA_SurfaceGuide positiveGuide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float4 centerValue = tex2D(CAMERA_OBSCURA_TL09ResolveHSampler, uv);

    [branch]
    if (negativeAvailable > 0.5)
    {
        negativeValue = tex2D(
            CAMERA_OBSCURA_TL09ResolveHSampler, negativeRequested);
        negativeGuide = CAMERA_OBSCURA_API_BuildTL08Guide(negativeRequested);
    }
    [branch]
    if (positiveAvailable > 0.5)
    {
        positiveValue = tex2D(
            CAMERA_OBSCURA_TL09ResolveHSampler, positiveRequested);
        positiveGuide = CAMERA_OBSCURA_API_BuildTL08Guide(positiveRequested);
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
        CAMERA_OBSCURA_TwinLanternDepthTolerance,
        CAMERA_OBSCURA_TwinLanternNormalMinimum,
        CAMERA_OBSCURA_TwinLanternStyledEdgeProtection());
}

float4 CAMERA_OBSCURA_TL09Raw_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    float3 weightedDonor = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;

    CAMERA_OBSCURA_API_TwinLanternTransportEvidence east =
        CAMERA_OBSCURA_API_BuildTwinLanternTransportEvidence(
            uv, 0.0, CAMERA_OBSCURA_API_TL45_INPUT_LIVE,
            CAMERA_OBSCURA_API_TL07_MODE_COMPLEMENTARY,
            CAMERA_OBSCURA_TwinLanternRayLengthPixels,
            CAMERA_OBSCURA_TwinLanternDepthSlope,
            CAMERA_OBSCURA_TwinLanternFrontBias,
            CAMERA_OBSCURA_TwinLanternBackThickness);
    CAMERA_OBSCURA_API_TwinLanternTransportEvidence north =
        CAMERA_OBSCURA_API_BuildTwinLanternTransportEvidence(
            uv, 2.0, CAMERA_OBSCURA_API_TL45_INPUT_LIVE,
            CAMERA_OBSCURA_API_TL07_MODE_COMPLEMENTARY,
            CAMERA_OBSCURA_TwinLanternRayLengthPixels,
            CAMERA_OBSCURA_TwinLanternDepthSlope,
            CAMERA_OBSCURA_TwinLanternFrontBias,
            CAMERA_OBSCURA_TwinLanternBackThickness);
    CAMERA_OBSCURA_API_TwinLanternTransportEvidence west =
        CAMERA_OBSCURA_API_BuildTwinLanternTransportEvidence(
            uv, 4.0, CAMERA_OBSCURA_API_TL45_INPUT_LIVE,
            CAMERA_OBSCURA_API_TL07_MODE_COMPLEMENTARY,
            CAMERA_OBSCURA_TwinLanternRayLengthPixels,
            CAMERA_OBSCURA_TwinLanternDepthSlope,
            CAMERA_OBSCURA_TwinLanternFrontBias,
            CAMERA_OBSCURA_TwinLanternBackThickness);
    CAMERA_OBSCURA_API_TwinLanternTransportEvidence south =
        CAMERA_OBSCURA_API_BuildTwinLanternTransportEvidence(
            uv, 6.0, CAMERA_OBSCURA_API_TL45_INPUT_LIVE,
            CAMERA_OBSCURA_API_TL07_MODE_COMPLEMENTARY,
            CAMERA_OBSCURA_TwinLanternRayLengthPixels,
            CAMERA_OBSCURA_TwinLanternDepthSlope,
            CAMERA_OBSCURA_TwinLanternFrontBias,
            CAMERA_OBSCURA_TwinLanternBackThickness);

    weightedDonor += east.combined_donor_rgb * east.evidence_strength;
    weightedDonor += north.combined_donor_rgb * north.evidence_strength;
    weightedDonor += west.combined_donor_rgb * west.evidence_strength;
    weightedDonor += south.combined_donor_rgb * south.evidence_strength;
    evidenceSum =
        east.evidence_strength +
        north.evidence_strength +
        west.evidence_strength +
        south.evidence_strength;

    float hasEvidence = step(0.000001, evidenceSum);
    float3 donor = weightedDonor *
        CAMERA_OBSCURA_SafeRcp(evidenceSum, 0.0) * hasEvidence;
    float averagedEvidence = saturate(evidenceSum * 0.25);
    return float4(donor, averagedEvidence);
}

float CAMERA_OBSCURA_TL09VisibleConfidence(
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
        saturate(CAMERA_OBSCURA_TwinLanternEdgeInkStrength));
    return saturate(visibleConfidence);
}

float4 CAMERA_OBSCURA_TL09ResolveH_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        CAMERA_OBSCURA_TL09EvaluateHorizontal(uv);
    return float4(
        evidence.resolved_rgb,
        CAMERA_OBSCURA_TL09VisibleConfidence(evidence));
}

float4 CAMERA_OBSCURA_TL09ResolveV_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        CAMERA_OBSCURA_TL09EvaluateVertical(uv);
    return float4(
        evidence.resolved_rgb,
        CAMERA_OBSCURA_TL09VisibleConfidence(evidence));
}

void CAMERA_OBSCURA_TL09AccumulateUpsampleTap(
    float2 requestedUv,
    float spatialWeight,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    inout float3 weightedColor,
    inout float signalWeightSum,
    inout float evidenceSum,
    inout float supportSum)
{
    float coverage = CAMERA_OBSCURA_TL09RequestedCoverage(requestedUv);
    [branch]
    if (coverage > 0.5 && spatialWeight > 0.000001)
    {
        CAMERA_OBSCURA_SurfaceGuide tapGuide =
            CAMERA_OBSCURA_API_BuildTL08Guide(requestedUv);
        float depthSupport = CAMERA_OBSCURA_API_TL08DepthSupport(
            centerGuide, tapGuide, CAMERA_OBSCURA_TwinLanternDepthTolerance);
        float normalSupport = CAMERA_OBSCURA_API_TL08NormalSupport(
            centerGuide, tapGuide, CAMERA_OBSCURA_TwinLanternNormalMinimum);
        float edgeSupport = CAMERA_OBSCURA_API_TL08EdgeSupport(
            centerGuide, tapGuide,
            CAMERA_OBSCURA_TwinLanternStyledEdgeProtection());
        float surfaceSupport =
            coverage * depthSupport * normalSupport * edgeSupport;
        float4 sampleValue = tex2D(
            CAMERA_OBSCURA_TL09ResolveVSampler, requestedUv);
        float supportWeight = spatialWeight * surfaceSupport;
        float signalWeight = supportWeight * saturate(sampleValue.a);

        weightedColor += sampleValue.rgb * signalWeight;
        signalWeightSum += signalWeight;
        evidenceSum += supportWeight * saturate(sampleValue.a);
        supportSum += supportWeight;
    }
}

float4 CAMERA_OBSCURA_TL09DepthAwareUpsample(float2 uv)
{
    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        CAMERA_OBSCURA_API_BuildTL08Guide(uv);
    if (centerGuide.valid < 0.5)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    float2 halfTexel = CAMERA_OBSCURA_TL09HalfTexel();
    float2 halfPosition = uv / halfTexel - 0.5;
    float2 baseCell = floor(halfPosition);
    float2 cellFraction = frac(halfPosition);
    float2 uv00 = (baseCell + float2(0.5, 0.5)) * halfTexel;
    float2 uv10 = uv00 + float2(halfTexel.x, 0.0);
    float2 uv01 = uv00 + float2(0.0, halfTexel.y);
    float2 uv11 = uv00 + halfTexel;
    float weight00 = (1.0 - cellFraction.x) * (1.0 - cellFraction.y);
    float weight10 = cellFraction.x * (1.0 - cellFraction.y);
    float weight01 = (1.0 - cellFraction.x) * cellFraction.y;
    float weight11 = cellFraction.x * cellFraction.y;
    float3 weightedColor = float3(0.0, 0.0, 0.0);
    float signalWeightSum = 0.0;
    float evidenceSum = 0.0;
    float supportSum = 0.0;

    CAMERA_OBSCURA_TL09AccumulateUpsampleTap(
        uv00, weight00, centerGuide,
        weightedColor, signalWeightSum, evidenceSum, supportSum);
    CAMERA_OBSCURA_TL09AccumulateUpsampleTap(
        uv10, weight10, centerGuide,
        weightedColor, signalWeightSum, evidenceSum, supportSum);
    CAMERA_OBSCURA_TL09AccumulateUpsampleTap(
        uv01, weight01, centerGuide,
        weightedColor, signalWeightSum, evidenceSum, supportSum);
    CAMERA_OBSCURA_TL09AccumulateUpsampleTap(
        uv11, weight11, centerGuide,
        weightedColor, signalWeightSum, evidenceSum, supportSum);

    float hasSignal = step(0.000001, signalWeightSum);
    float3 resolved = weightedColor *
        CAMERA_OBSCURA_SafeRcp(signalWeightSum, 0.0) * hasSignal;
    float trustedEvidence = evidenceSum *
        CAMERA_OBSCURA_SafeRcp(supportSum, 0.0) * hasSignal;
    return float4(saturate(resolved), saturate(trustedEvidence));
}

void CAMERA_OBSCURA_TL09AccumulateEdgeFillTap(
    float2 requestedUv,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    inout float3 signalSum,
    inout float evidenceSum,
    inout float supportSum)
{
    float coverage = CAMERA_OBSCURA_TL09RequestedCoverage(requestedUv);
    [branch]
    if (coverage > 0.5)
    {
        CAMERA_OBSCURA_SurfaceGuide tapGuide =
            CAMERA_OBSCURA_API_BuildTL08Guide(requestedUv);
        float depthSupport = CAMERA_OBSCURA_API_TL08DepthSupport(
            centerGuide, tapGuide, CAMERA_OBSCURA_TwinLanternDepthTolerance);
        float normalSupport = CAMERA_OBSCURA_API_TL08NormalSupport(
            centerGuide, tapGuide, CAMERA_OBSCURA_TwinLanternNormalMinimum);
        float surfaceSupport = coverage * depthSupport * normalSupport;
        float4 sampleValue = tex2D(
            CAMERA_OBSCURA_TL09ResolveVSampler, requestedUv);
        float sampleEvidence = saturate(sampleValue.a);

        signalSum += saturate(sampleValue.rgb) *
            sampleEvidence * surfaceSupport;
        evidenceSum += sampleEvidence * surfaceSupport;
        supportSum += surfaceSupport;
    }
}

float4 CAMERA_OBSCURA_TL09ApplyEdgeFill(
    float2 uv,
    float4 baseIndirect,
    out float edgeFillTarget,
    out float3 edgeFillAdded)
{
    edgeFillTarget = 0.0;
    edgeFillAdded = float3(0.0, 0.0, 0.0);
    float safeStrength = saturate(CAMERA_OBSCURA_TwinLanternEdgeFillStrength);
    [branch]
    if (safeStrength <= 0.000001)
    {
        return baseIndirect;
    }

    CAMERA_OBSCURA_SurfaceGuide centerGuide =
        CAMERA_OBSCURA_API_BuildTL08Guide(uv);
    [branch]
    if (centerGuide.valid < 0.5)
    {
        return baseIndirect;
    }

    float safeRadius = clamp(
        CAMERA_OBSCURA_TwinLanternEdgeFillRadiusPixels, 1.0, 4.0);
    float2 offset = float2(
        BUFFER_RCP_WIDTH * safeRadius,
        BUFFER_RCP_HEIGHT * safeRadius);
    float3 signalSum = float3(0.0, 0.0, 0.0);
    float evidenceSum = 0.0;
    float supportSum = 0.0;

    CAMERA_OBSCURA_TL09AccumulateEdgeFillTap(
        uv - float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    CAMERA_OBSCURA_TL09AccumulateEdgeFillTap(
        uv + float2(offset.x, 0.0), centerGuide,
        signalSum, evidenceSum, supportSum);
    CAMERA_OBSCURA_TL09AccumulateEdgeFillTap(
        uv - float2(0.0, offset.y), centerGuide,
        signalSum, evidenceSum, supportSum);
    CAMERA_OBSCURA_TL09AccumulateEdgeFillTap(
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

CAMERA_OBSCURA_API_TL09CompositeEvidence
CAMERA_OBSCURA_TL09EvaluateComposite(
    float2 uv,
    out float edgeFillTarget,
    out float3 edgeFillAdded)
{
    float4 vertical = CAMERA_OBSCURA_TL09DepthAwareUpsample(uv);
    float4 reconstructed = CAMERA_OBSCURA_TL09ApplyEdgeFill(
        uv, vertical, edgeFillTarget, edgeFillAdded);
    float3 source = saturate(tex2D(ReShade::BackBuffer, uv).rgb);
    float receiverValid = CAMERA_OBSCURA_DepthConfidence(
        CAMERA_OBSCURA_LoadDepth(uv));
    return CAMERA_OBSCURA_API_BuildTL09Composite(
        source,
        reconstructed.rgb,
        reconstructed.a,
        receiverValid,
        CAMERA_OBSCURA_TwinLanternEnabled ? 1.0 : 0.0,
        CAMERA_OBSCURA_TwinLanternStrength,
        CAMERA_OBSCURA_TwinLanternMaximumContribution);
}

float3 CAMERA_OBSCURA_TL09RejectionColor(float rejectionCode)
{
    if (rejectionCode < 0.5) return float3(0.05, 0.95, 0.18);
    if (rejectionCode < 1.5) return float3(0.10, 0.25, 0.95);
    if (rejectionCode < 2.5) return float3(0.95, 0.05, 0.03);
    if (rejectionCode < 3.5) return float3(0.95, 0.05, 0.75);
    if (rejectionCode < 4.5) return float3(0.95, 0.55, 0.05);
    if (rejectionCode < 5.5) return float3(0.05, 0.90, 0.90);
    return float3(0.45, 0.45, 0.45);
}

float4 CAMERA_OBSCURA_TL09Display_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD) : SV_Target
{
    float edgeFillTarget = 0.0;
    float3 edgeFillAdded = float3(0.0, 0.0, 0.0);
    CAMERA_OBSCURA_API_TL09CompositeEvidence evidence =
        CAMERA_OBSCURA_TL09EvaluateComposite(
            uv, edgeFillTarget, edgeFillAdded);
    float view = (float)CAMERA_OBSCURA_TwinLanternView;
    if (view < 0.5) return float4(evidence.final_rgb, 1.0);
    if (view < 1.5) return float4(evidence.source_rgb, 1.0);
    if (view < 2.5) return float4(evidence.bounded_indirect_rgb, 1.0);
    if (view < 3.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.evidence), 1.0);
    if (view < 4.5) return float4(
        evidence.bounded_contribution_rgb, 1.0);
    if (view < 5.5) return float4(
        CAMERA_OBSCURA_TL09RejectionColor(evidence.rejection_code), 1.0);
    if (view < 6.5) return float4(evidence.remaining_room_rgb, 1.0);
    if (view < 7.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.containment_activity), 1.0);
    if (view < 8.5) return float4(
        CAMERA_OBSCURA_DebugHeat(evidence.source_preserve_delta), 1.0);
    if (view < 9.5) return float4(evidence.bounds_valid > 0.5 ?
        float3(0.05, 0.95, 0.18) : float3(0.95, 0.05, 0.03), 1.0);
    if (view < 10.5) return float4(
        CAMERA_OBSCURA_DebugHeat(edgeFillTarget), 1.0);
    return float4(saturate(edgeFillAdded * 8.0), 1.0);
}

technique CAMERA_OBSCURA_TwinLantern
< ui_label = "Camera Obscura - Twin Lantern"; ui_tooltip = "Screen-space indirect light reconstructed from four cardinal transport directions.\nSurface evidence controls a depth-aware full-resolution reconstruction before a bounded source-preserving composite.\nNo denoiser or temporal history is included."; >
{
    pass TwinLanternTransport
    {
        VertexShader = PostProcessVS;
        PixelShader = CAMERA_OBSCURA_TL09Raw_PS;
        RenderTarget = CAMERA_OBSCURA_TL09RawTex;
    }
    pass TwinLanternResolveHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = CAMERA_OBSCURA_TL09ResolveH_PS;
        RenderTarget = CAMERA_OBSCURA_TL09ResolveHTex;
    }
    pass TwinLanternResolveVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = CAMERA_OBSCURA_TL09ResolveV_PS;
        RenderTarget = CAMERA_OBSCURA_TL09ResolveVTex;
    }
    pass TwinLanternComposite
    {
        VertexShader = PostProcessVS;
        PixelShader = CAMERA_OBSCURA_TL09Display_PS;
    }
}
