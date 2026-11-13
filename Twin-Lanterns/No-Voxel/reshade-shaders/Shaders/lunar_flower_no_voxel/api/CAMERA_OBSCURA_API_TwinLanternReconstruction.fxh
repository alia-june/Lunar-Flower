#ifndef CAMERA_OBSCURA_API_TWIN_LANTERN_RECONSTRUCTION_FXH
#define CAMERA_OBSCURA_API_TWIN_LANTERN_RECONSTRUCTION_FXH

#include "CAMERA_OBSCURA_API_TwinLanternTransport.fxh"

struct CAMERA_OBSCURA_API_TL08ResolveEvidence
{
    float3 resolved_rgb;
    float trusted_weight;
    float weight_sum;
    float kernel_capacity;
    float center_valid;
    float center_evidence;
    float negative_available;
    float positive_available;
    float negative_depth_support;
    float positive_depth_support;
    float negative_normal_support;
    float positive_normal_support;
    float negative_edge_support;
    float positive_edge_support;
    float negative_admitted_weight;
    float center_admitted_weight;
    float positive_admitted_weight;
    float minimum_depth_support;
    float minimum_normal_support;
    float minimum_edge_support;
    float zero_weight;
};

CAMERA_OBSCURA_API_TL08ResolveEvidence
CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence()
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence;
    evidence.resolved_rgb = float3(0.0, 0.0, 0.0);
    evidence.trusted_weight = 0.0;
    evidence.weight_sum = 0.0;
    evidence.kernel_capacity = 0.0;
    evidence.center_valid = 0.0;
    evidence.center_evidence = 0.0;
    evidence.negative_available = 0.0;
    evidence.positive_available = 0.0;
    evidence.negative_depth_support = 0.0;
    evidence.positive_depth_support = 0.0;
    evidence.negative_normal_support = 0.0;
    evidence.positive_normal_support = 0.0;
    evidence.negative_edge_support = 0.0;
    evidence.positive_edge_support = 0.0;
    evidence.negative_admitted_weight = 0.0;
    evidence.center_admitted_weight = 0.0;
    evidence.positive_admitted_weight = 0.0;
    evidence.minimum_depth_support = 0.0;
    evidence.minimum_normal_support = 0.0;
    evidence.minimum_edge_support = 0.0;
    evidence.zero_weight = 1.0;
    return evidence;
}

CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_DefaultTL08Guide()
{
    CAMERA_OBSCURA_SurfaceGuide guide;
    guide.valid = 0.0;
    guide.depth = 0.0;
    guide.normal = float3(0.0, 0.0, 1.0);
    guide.depth_confidence = 0.0;
    guide.edge_risk = 0.0;
    guide.luma = 0.0;
    return guide;
}

CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_BuildTL08Guide(float2 uv)
{
    CAMERA_OBSCURA_SurfaceGuide guide =
        CAMERA_OBSCURA_API_DefaultTL08Guide();
    float2 uvSafe = CAMERA_OBSCURA_SaturateUV(uv);
    float2 pixel = CAMERA_OBSCURA_PixelSize();
    float center = CAMERA_OBSCURA_LoadDepth(uvSafe);
    float right = CAMERA_OBSCURA_LoadDepth(
        CAMERA_OBSCURA_SaturateUV(uvSafe + float2(pixel.x, 0.0)));
    float up = CAMERA_OBSCURA_LoadDepth(
        CAMERA_OBSCURA_SaturateUV(uvSafe + float2(0.0, pixel.y)));
    float spread = abs(right - center) + abs(up - center);

    guide.valid = CAMERA_OBSCURA_DepthConfidence(center);
    guide.depth = center;
    guide.normal = guide.valid > 0.5 ?
        normalize(float3(
            center - right,
            center - up,
            max(pixel.x + pixel.y, 0.0001))) :
        float3(0.0, 0.0, 1.0);
    guide.depth_confidence = guide.valid;
    guide.edge_risk = saturate(spread * 40.0);
    return guide;
}

float CAMERA_OBSCURA_API_TL08DepthSupport(
    CAMERA_OBSCURA_SurfaceGuide center,
    CAMERA_OBSCURA_SurfaceGuide tapGuide,
    float depthTolerance)
{
    float safeTolerance = max(depthTolerance, 0.000001);
    return center.valid * tapGuide.valid * saturate(
        1.0 - abs(tapGuide.depth - center.depth) / safeTolerance);
}

float CAMERA_OBSCURA_API_TL08NormalSupport(
    CAMERA_OBSCURA_SurfaceGuide center,
    CAMERA_OBSCURA_SurfaceGuide tapGuide,
    float normalMinimum)
{
    float safeMinimum = min(max(normalMinimum, 0.0), 0.9999);
    float agreement = saturate(dot(center.normal, tapGuide.normal));
    return center.valid * tapGuide.valid * saturate(
        (agreement - safeMinimum) / max(1.0 - safeMinimum, 0.0001));
}

float CAMERA_OBSCURA_API_TL08EdgeSupport(
    CAMERA_OBSCURA_SurfaceGuide center,
    CAMERA_OBSCURA_SurfaceGuide tapGuide,
    float edgeProtection)
{
    float risk = max(center.edge_risk, tapGuide.edge_risk);
    return saturate(1.0 - risk * saturate(edgeProtection));
}

CAMERA_OBSCURA_API_TL08ResolveEvidence
CAMERA_OBSCURA_API_ResolveTL08Axis(
    float4 negativeValue,
    float4 centerValue,
    float4 positiveValue,
    CAMERA_OBSCURA_SurfaceGuide negativeGuide,
    CAMERA_OBSCURA_SurfaceGuide centerGuide,
    CAMERA_OBSCURA_SurfaceGuide positiveGuide,
    float negativeAvailable,
    float positiveAvailable,
    float depthTolerance,
    float normalMinimum,
    float edgeProtection)
{
    CAMERA_OBSCURA_API_TL08ResolveEvidence evidence =
        CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence();
    float negativeCoverage = saturate(negativeAvailable);
    float positiveCoverage = saturate(positiveAvailable);
    float negativeDepth = CAMERA_OBSCURA_API_TL08DepthSupport(
        centerGuide, negativeGuide, depthTolerance) * negativeCoverage;
    float positiveDepth = CAMERA_OBSCURA_API_TL08DepthSupport(
        centerGuide, positiveGuide, depthTolerance) * positiveCoverage;
    float negativeNormal = CAMERA_OBSCURA_API_TL08NormalSupport(
        centerGuide, negativeGuide, normalMinimum) * negativeCoverage;
    float positiveNormal = CAMERA_OBSCURA_API_TL08NormalSupport(
        centerGuide, positiveGuide, normalMinimum) * positiveCoverage;
    float negativeEdge = CAMERA_OBSCURA_API_TL08EdgeSupport(
        centerGuide, negativeGuide, edgeProtection) * negativeCoverage;
    float positiveEdge = CAMERA_OBSCURA_API_TL08EdgeSupport(
        centerGuide, positiveGuide, edgeProtection) * positiveCoverage;
    float negativeSurface = negativeDepth * negativeNormal * negativeEdge;
    float positiveSurface = positiveDepth * positiveNormal * positiveEdge;
    float negativeWeight =
        0.5 * saturate(negativeValue.a) * negativeSurface;
    float centerWeight =
        saturate(centerValue.a) * centerGuide.valid;
    float positiveWeight =
        0.5 * saturate(positiveValue.a) * positiveSurface;
    float weightSum = negativeWeight + centerWeight + positiveWeight;
    float kernelCapacity =
        1.0 + 0.5 * (negativeCoverage + positiveCoverage);
    float hasWeight = step(0.000001, weightSum);
    float inverseWeight = CAMERA_OBSCURA_SafeRcp(weightSum, 0.0);
    float3 resolved =
        (negativeValue.rgb * negativeWeight +
         centerValue.rgb * centerWeight +
         positiveValue.rgb * positiveWeight) *
        inverseWeight * hasWeight;
    float minimumDepth = min(
        lerp(1.0, negativeDepth, negativeCoverage),
        lerp(1.0, positiveDepth, positiveCoverage));
    float minimumNormal = min(
        lerp(1.0, negativeNormal, negativeCoverage),
        lerp(1.0, positiveNormal, positiveCoverage));
    float minimumEdge = min(
        lerp(1.0, negativeEdge, negativeCoverage),
        lerp(1.0, positiveEdge, positiveCoverage));

    evidence.resolved_rgb = saturate(resolved);
    evidence.trusted_weight = saturate(
        weightSum * CAMERA_OBSCURA_SafeRcp(kernelCapacity, 0.0));
    evidence.weight_sum = weightSum;
    evidence.kernel_capacity = kernelCapacity;
    evidence.center_valid = centerGuide.valid;
    evidence.center_evidence = saturate(centerValue.a);
    evidence.negative_available = negativeCoverage;
    evidence.positive_available = positiveCoverage;
    evidence.negative_depth_support = negativeDepth;
    evidence.positive_depth_support = positiveDepth;
    evidence.negative_normal_support = negativeNormal;
    evidence.positive_normal_support = positiveNormal;
    evidence.negative_edge_support = negativeEdge;
    evidence.positive_edge_support = positiveEdge;
    evidence.negative_admitted_weight = negativeWeight;
    evidence.center_admitted_weight = centerWeight;
    evidence.positive_admitted_weight = positiveWeight;
    evidence.minimum_depth_support = minimumDepth;
    evidence.minimum_normal_support = minimumNormal;
    evidence.minimum_edge_support = minimumEdge;
    evidence.zero_weight = 1.0 - hasWeight;
    return evidence;
}

#endif // CAMERA_OBSCURA_API_TWIN_LANTERN_RECONSTRUCTION_FXH
