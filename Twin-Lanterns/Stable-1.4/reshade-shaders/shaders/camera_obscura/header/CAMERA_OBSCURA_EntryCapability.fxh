#ifndef CAMERA_OBSCURA_ENTRY_CAPABILITY_FXH
#define CAMERA_OBSCURA_ENTRY_CAPABILITY_FXH

#include "CAMERA_OBSCURA_AtomicCommon.fxh"

float CAMERA_OBSCURA_LoadDepth(float2 uv)
{
    return saturate(ReShade::GetLinearizedDepth(CAMERA_OBSCURA_SaturateUV(uv)));
}

float3 CAMERA_OBSCURA_LoadColor(float2 uv)
{
    return tex2D(ReShade::BackBuffer, CAMERA_OBSCURA_SaturateUV(uv)).rgb;
}

float3 CAMERA_OBSCURA_BuildProxyNormal(float2 uv)
{
    float2 px = CAMERA_OBSCURA_PixelSize();
    float depthCenter = CAMERA_OBSCURA_LoadDepth(uv);
    float depthRight = CAMERA_OBSCURA_LoadDepth(uv + float2(px.x, 0.0));
    float depthUp = CAMERA_OBSCURA_LoadDepth(uv + float2(0.0, px.y));
    float3 normal = float3(
        depthCenter - depthRight,
        depthCenter - depthUp,
        max(px.x + px.y, 0.0001));
    return normalize(normal);
}

CAMERA_OBSCURA_Capabilities CAMERA_OBSCURA_QueryCapabilities()
{
    CAMERA_OBSCURA_Capabilities capabilities;
    capabilities.tier = CAMERA_OBSCURA_CAP_TIER_C0;
    capabilities.has_color = 1.0;
    capabilities.has_depth = 1.0;
    capabilities.has_linear_view_z = 1.0;
    capabilities.has_projection = 0.0;
    capabilities.has_inverse_projection = 0.0;
    capabilities.has_history = 0.0;
    capabilities.has_motion_vectors = 0.0;
    capabilities.depth_metric = CAMERA_OBSCURA_DEPTH_METRIC_LINEAR01;
    return capabilities;
}

CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_BuildSurfaceGuide(float2 uv)
{
    CAMERA_OBSCURA_SurfaceGuide guide;
    float2 uvSafe = CAMERA_OBSCURA_SaturateUV(uv);
    float2 px = CAMERA_OBSCURA_PixelSize();
    float depthCenter = CAMERA_OBSCURA_LoadDepth(uvSafe);
    float depthLeft = CAMERA_OBSCURA_LoadDepth(uvSafe - float2(px.x, 0.0));
    float depthRight = CAMERA_OBSCURA_LoadDepth(uvSafe + float2(px.x, 0.0));
    float depthDown = CAMERA_OBSCURA_LoadDepth(uvSafe - float2(0.0, px.y));
    float depthUp = CAMERA_OBSCURA_LoadDepth(uvSafe + float2(0.0, px.y));
    float depthSpread =
        abs(depthLeft - depthCenter) +
        abs(depthRight - depthCenter) +
        abs(depthDown - depthCenter) +
        abs(depthUp - depthCenter);
    float edgeRisk = saturate(depthSpread * 40.0);

    guide.valid = CAMERA_OBSCURA_DepthConfidence(depthCenter);
    guide.depth = depthCenter;
    guide.normal =
        guide.valid > 0.5 ?
        CAMERA_OBSCURA_BuildProxyNormal(uvSafe) :
        float3(0.0, 0.0, 1.0);
    guide.depth_confidence = guide.valid * (1.0 - edgeRisk);
    guide.edge_risk = edgeRisk;
    guide.luma = CAMERA_OBSCURA_Luma(CAMERA_OBSCURA_LoadColor(uvSafe));
    return guide;
}

float2 CAMERA_OBSCURA_SelectDirectionC0(float2 pixel, float spatialPhase)
{
    int px = (int)floor(pixel.x + 0.5);
    int py = (int)floor(pixel.y + 0.5);
    int phase = (px + py + (int)floor(spatialPhase + 0.5)) & 7;

    if (phase == 0) return float2(1.0, 0.0);
    if (phase == 1) return float2(0.70710678, 0.70710678);
    if (phase == 2) return float2(0.0, 1.0);
    if (phase == 3) return float2(-0.70710678, 0.70710678);
    if (phase == 4) return float2(-1.0, 0.0);
    if (phase == 5) return float2(-0.70710678, -0.70710678);
    if (phase == 6) return float2(0.0, -1.0);
    return float2(0.70710678, -0.70710678);
}

CAMERA_OBSCURA_RayRequest CAMERA_OBSCURA_DefaultRayRequest(float2 directionUv)
{
    CAMERA_OBSCURA_RayRequest request;
    float directionLength = length(directionUv);
    request.direction_uv =
        directionLength > 0.000001 ?
        (directionUv / directionLength) :
        float2(1.0, 0.0);
    request.ray_length_uv = 20.0 * max(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    request.ray_depth_slope = 0.15;
    request.front_bias = 0.0005;
    request.back_thickness = 0.0035;
    request.confidence_min = 0.05;
    request.self_hit_pixels = 1.5;
    request.distance_fade = 1.0;
    request.pixel_stride = 1.0;
    request.refinement_steps = CAMERA_OBSCURA_REFINE_STEPS;
    request.spatial_phase = 0.0;
    request.requested_steps = CAMERA_OBSCURA_MARCH_MAX_STEPS;
    return request;
}

CAMERA_OBSCURA_TraceControls CAMERA_OBSCURA_BuildTraceControls(CAMERA_OBSCURA_RayRequest request)
{
    CAMERA_OBSCURA_TraceControls controls;
    controls.ray_length_uv = max(request.ray_length_uv, 0.0);
    controls.ray_depth_slope = max(request.ray_depth_slope, 0.0);
    controls.front_bias = max(request.front_bias, 0.0);
    controls.back_thickness = max(request.back_thickness, 0.0);
    controls.confidence_min = saturate(request.confidence_min);
    controls.self_hit_pixels = max(request.self_hit_pixels, 0.0);
    controls.distance_fade = max(request.distance_fade, 0.0);
    controls.pixel_stride = max(request.pixel_stride, 1.0);
    controls.refinement_steps = max(request.refinement_steps, 1.0);
    controls.steps = max(request.requested_steps, 1.0);
    controls.spatial_phase = request.spatial_phase;
    return controls;
}

CAMERA_OBSCURA_Ray CAMERA_OBSCURA_BuildRayC0(
    float2 uv,
    CAMERA_OBSCURA_SurfaceGuide surface,
    CAMERA_OBSCURA_RayRequest request,
    CAMERA_OBSCURA_TraceControls controls)
{
    CAMERA_OBSCURA_Ray ray;
    float2 direction = request.direction_uv;
    float directionLength = length(direction);
    float directionValid = step(0.000001, directionLength);
    int steps = CAMERA_OBSCURA_ClampSteps(controls.steps, CAMERA_OBSCURA_DDA_MAX_STEPS);

    if (directionLength <= 0.000001)
    {
        direction = float2(0.0, 0.0);
    }
    else
    {
        direction /= directionLength;
    }

    ray.valid = surface.valid * step(0.5, controls.steps) * directionValid;
    ray.capability_tier = CAMERA_OBSCURA_CAP_TIER_C0;
    ray.origin_uv = CAMERA_OBSCURA_SaturateUV(uv);
    ray.step_uv =
        direction *
        max(controls.ray_length_uv, 0.0) *
        CAMERA_OBSCURA_SafeRcp((float)steps, 0.0);
    ray.origin_depth = surface.depth;
    ray.step_depth = max(controls.ray_depth_slope, 0.0) * length(ray.step_uv);
    ray.t_min = 0.0;
    ray.t_max = (float)steps;
    ray.front_bias = controls.front_bias;
    ray.back_thickness = controls.back_thickness;
    ray.confidence_min = controls.confidence_min;
    ray.steps = (float)steps;
    ray.distance_fade = controls.distance_fade;
    return ray;
}

#endif // CAMERA_OBSCURA_ENTRY_CAPABILITY_FXH
