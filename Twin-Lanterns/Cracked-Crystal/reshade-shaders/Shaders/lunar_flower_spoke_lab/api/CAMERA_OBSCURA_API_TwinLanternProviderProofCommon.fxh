#ifndef CAMERA_OBSCURA_API_TWIN_LANTERN_PROVIDER_PROOF_COMMON_FXH
#define CAMERA_OBSCURA_API_TWIN_LANTERN_PROVIDER_PROOF_COMMON_FXH

#include "../header/CAMERA_OBSCURA_EntryCapability.fxh"
#include "../header/CAMERA_OBSCURA_AtomicDebug.fxh"

#define CAMERA_OBSCURA_API_TL45_INPUT_LIVE 0.0
#define CAMERA_OBSCURA_API_TL45_INPUT_INVALID_RECEIVER 1.0
#define CAMERA_OBSCURA_API_TL45_INPUT_ZERO_DIRECTION 2.0

struct CAMERA_OBSCURA_API_TwinLanternProviderEvidence
{
    float provider_backend;
    float requested_steps;
    float receiver_valid;
    float receiver_edge_risk;
    float ray_valid;
    float2 direction_uv;
    float hit;
    float reason;
    float2 hit_uv;
    float step_index;
    float terminal_depth;
    float interval_min;
    float interval_max;
    float interval_support;
    float thickness_used;
    float coarse_residual;
    float refined_residual;
    float refinement_not_worse;
    float refinement_steps;
    float confidence;
};

CAMERA_OBSCURA_API_TwinLanternProviderEvidence
CAMERA_OBSCURA_API_DefaultTwinLanternProviderEvidence(float backend)
{
    CAMERA_OBSCURA_API_TwinLanternProviderEvidence evidence;
    evidence.provider_backend = backend;
    evidence.requested_steps = 0.0;
    evidence.receiver_valid = 0.0;
    evidence.receiver_edge_risk = 0.0;
    evidence.ray_valid = 0.0;
    evidence.direction_uv = float2(0.0, 0.0);
    evidence.hit = 0.0;
    evidence.reason = CAMERA_OBSCURA_REASON_INVALID_RAY;
    evidence.hit_uv = float2(0.0, 0.0);
    evidence.step_index = 0.0;
    evidence.terminal_depth = 0.0;
    evidence.interval_min = 0.0;
    evidence.interval_max = 0.0;
    evidence.interval_support = 0.0;
    evidence.thickness_used = 0.0;
    evidence.coarse_residual = 0.0;
    evidence.refined_residual = 0.0;
    evidence.refinement_not_worse = 0.0;
    evidence.refinement_steps = 0.0;
    evidence.confidence = 0.0;
    return evidence;
}

float2 CAMERA_OBSCURA_API_TL45Direction(float requestedIndex)
{
    int index = min(max((int)floor(requestedIndex + 0.5), 0), 7);
    if (index == 0) return float2(1.0, 0.0);
    if (index == 1) return float2(0.70710678, 0.70710678);
    if (index == 2) return float2(0.0, 1.0);
    if (index == 3) return float2(-0.70710678, 0.70710678);
    if (index == 4) return float2(-1.0, 0.0);
    if (index == 5) return float2(-0.70710678, -0.70710678);
    if (index == 6) return float2(0.0, -1.0);
    return float2(0.70710678, -0.70710678);
}

CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_BuildTL45Receiver(
    float2 uv,
    float inputMode)
{
    CAMERA_OBSCURA_SurfaceGuide guide;
    guide.valid = 0.0;
    guide.depth = 0.0;
    guide.normal = float3(0.0, 0.0, 1.0);
    guide.depth_confidence = 0.0;
    guide.edge_risk = 0.0;
    guide.luma = 0.0;

    if (inputMode < 0.5 || inputMode > 1.5)
    {
        float2 uvSafe = CAMERA_OBSCURA_SaturateUV(uv);
        float2 pixel = CAMERA_OBSCURA_PixelSize();
        float center = CAMERA_OBSCURA_LoadDepth(uvSafe);
        float left = CAMERA_OBSCURA_LoadDepth(
            CAMERA_OBSCURA_SaturateUV(uvSafe - float2(pixel.x, 0.0)));
        float right = CAMERA_OBSCURA_LoadDepth(
            CAMERA_OBSCURA_SaturateUV(uvSafe + float2(pixel.x, 0.0)));
        float down = CAMERA_OBSCURA_LoadDepth(
            CAMERA_OBSCURA_SaturateUV(uvSafe - float2(0.0, pixel.y)));
        float up = CAMERA_OBSCURA_LoadDepth(
            CAMERA_OBSCURA_SaturateUV(uvSafe + float2(0.0, pixel.y)));
        float spread =
            abs(left - center) +
            abs(right - center) +
            abs(down - center) +
            abs(up - center);

        guide.valid = CAMERA_OBSCURA_DepthConfidence(center);
        guide.depth = center;
        guide.normal =
            guide.valid > 0.5 ?
            normalize(float3(
                center - right,
                center - up,
                max(pixel.x + pixel.y, 0.0001))) :
            float3(0.0, 0.0, 1.0);
        guide.edge_risk = saturate(spread * 40.0);
        guide.depth_confidence = guide.valid * (1.0 - guide.edge_risk);
    }

    return guide;
}

CAMERA_OBSCURA_Ray CAMERA_OBSCURA_API_BuildTL45Ray(
    float2 uv,
    float directionIndex,
    float inputMode,
    float requestedSteps,
    float rayLengthPixels,
    float depthSlope,
    float frontBias,
    float backThickness,
    out CAMERA_OBSCURA_TraceControls controls,
    out CAMERA_OBSCURA_SurfaceGuide receiver)
{
    float2 directionPixels = CAMERA_OBSCURA_API_TL45Direction(directionIndex);
    float2 requestedTravelUv =
        directionPixels *
        max(rayLengthPixels, 0.0) *
        CAMERA_OBSCURA_PixelSize();
    receiver = CAMERA_OBSCURA_API_BuildTL45Receiver(uv, inputMode);
    CAMERA_OBSCURA_RayRequest request =
        CAMERA_OBSCURA_DefaultRayRequest(requestedTravelUv);

    if (inputMode > 1.5)
    {
        request.direction_uv = float2(0.0, 0.0);
    }

    request.ray_length_uv = length(requestedTravelUv);
    request.ray_depth_slope = max(depthSlope, 0.0);
    request.front_bias = max(frontBias, 0.0);
    request.back_thickness = max(backThickness, 0.0);
    request.refinement_steps = CAMERA_OBSCURA_REFINE_STEPS;
    request.requested_steps = requestedSteps;
    controls = CAMERA_OBSCURA_BuildTraceControls(request);
    return CAMERA_OBSCURA_BuildRayC0(
        CAMERA_OBSCURA_SaturateUV(uv),
        receiver,
        request,
        controls);
}

CAMERA_OBSCURA_API_TwinLanternProviderEvidence
CAMERA_OBSCURA_API_BuildTL45Evidence(
    CAMERA_OBSCURA_Ray ray,
    CAMERA_OBSCURA_TraceControls controls,
    CAMERA_OBSCURA_SurfaceGuide receiver,
    CAMERA_OBSCURA_Hit coarse,
    CAMERA_OBSCURA_Hit refined,
    float backend)
{
    CAMERA_OBSCURA_API_TwinLanternProviderEvidence evidence =
        CAMERA_OBSCURA_API_DefaultTwinLanternProviderEvidence(backend);
    float coarseResidual = abs(coarse.delta);
    float refinedResidual = abs(refined.delta);
    float intervalSupport =
        step(refined.interval_min, refined.scene_z) *
        step(refined.scene_z, refined.interval_max) *
        refined.hit;

    evidence.requested_steps = controls.steps;
    evidence.receiver_valid = receiver.valid;
    evidence.receiver_edge_risk = receiver.edge_risk;
    evidence.ray_valid = ray.valid;
    evidence.direction_uv = normalize(
        ray.step_uv + float2(0.0000001, 0.0000001));
    evidence.hit = refined.hit;
    evidence.reason = refined.reason;
    evidence.hit_uv = refined.uv;
    evidence.step_index = refined.step_index;
    evidence.terminal_depth = refined.scene_z;
    evidence.interval_min = refined.interval_min;
    evidence.interval_max = refined.interval_max;
    evidence.interval_support = intervalSupport;
    evidence.thickness_used = refined.thickness_used;
    evidence.coarse_residual = coarseResidual;
    evidence.refined_residual = refinedResidual;
    evidence.refinement_not_worse = refined.hit * step(
        refinedResidual,
        coarseResidual + 0.000001);
    evidence.refinement_steps = refined.hit * controls.refinement_steps;
    evidence.confidence = refined.confidence;
    return evidence;
}

float3 CAMERA_OBSCURA_API_TL45Status(float value)
{
    return lerp(
        float3(0.78, 0.05, 0.58),
        float3(0.08, 0.88, 0.22),
        step(0.5, value));
}

float3 CAMERA_OBSCURA_API_TL45Signal(
    CAMERA_OBSCURA_API_TwinLanternProviderEvidence evidence,
    float view)
{
    if (view < 0.5)
        return evidence.hit > 0.5 ?
            CAMERA_OBSCURA_DebugBackendColor(evidence.provider_backend) :
            CAMERA_OBSCURA_DebugReasonColor(evidence.reason);
    if (view < 1.5)
        return CAMERA_OBSCURA_DebugReasonColor(evidence.reason);
    if (view < 2.5)
        return CAMERA_OBSCURA_DebugHeat(saturate(
            evidence.step_index /
            max(evidence.requested_steps, 1.0)));
    if (view < 3.5)
        return float3(evidence.hit_uv, evidence.hit);
    if (view < 4.5)
        return CAMERA_OBSCURA_DebugHeat(saturate(evidence.terminal_depth));
    if (view < 5.5)
        return CAMERA_OBSCURA_API_TL45Status(evidence.interval_support);
    if (view < 6.5)
        return CAMERA_OBSCURA_DebugHeat(saturate(
            (evidence.interval_max - evidence.interval_min) * 128.0));
    if (view < 7.5)
        return CAMERA_OBSCURA_DebugHeat(saturate(
            evidence.coarse_residual * 192.0));
    if (view < 8.5)
        return CAMERA_OBSCURA_DebugHeat(saturate(
            evidence.refined_residual * 192.0));
    if (view < 9.5)
        return CAMERA_OBSCURA_API_TL45Status(
            evidence.refinement_not_worse + (1.0 - evidence.hit));
    if (view < 10.5)
        return lerp(
            float3(0.88, 0.10, 0.08),
            float3(0.08, 0.88, 0.22),
            saturate(evidence.confidence));
    if (view < 11.5)
        return CAMERA_OBSCURA_DebugHeat(evidence.receiver_edge_risk);
    return CAMERA_OBSCURA_API_TL45Status(evidence.ray_valid);
}

#endif // CAMERA_OBSCURA_API_TWIN_LANTERN_PROVIDER_PROOF_COMMON_FXH
