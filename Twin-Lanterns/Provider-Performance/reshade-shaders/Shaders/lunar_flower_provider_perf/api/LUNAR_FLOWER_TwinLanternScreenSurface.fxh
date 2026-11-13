#ifndef LUNAR_FLOWER_TWIN_LANTERN_PROVIDER_PERF_SCREEN_SURFACE_FXH
#define LUNAR_FLOWER_TWIN_LANTERN_PROVIDER_PERF_SCREEN_SURFACE_FXH

// Direction Lab surface guide; fixed-budget provider comparison.
float LUNAR_FLOWER_TLPPSurfaceDerivative(float negative, float center, float positive)
{
    float derivative = 0.0;
    float backward = center - negative;
    float forward = positive - center;
    bool negativeValid = CAMERA_OBSCURA_DepthConfidence(negative) > 0.5;
    bool positiveValid = CAMERA_OBSCURA_DepthConfidence(positive) > 0.5;
    if (negativeValid && positiveValid)
        derivative = abs(backward) < abs(forward) ? backward : forward;
    else if (negativeValid)
        derivative = backward;
    else if (positiveValid)
        derivative = forward;
    return derivative;
}

CAMERA_OBSCURA_SurfaceGuide LUNAR_FLOWER_TLPPBuildSurfaceGuide(float2 uv)
{
    CAMERA_OBSCURA_SurfaceGuide guide = CAMERA_OBSCURA_API_DefaultTL08Guide();
    float2 pixel = CAMERA_OBSCURA_PixelSize();
    float center = CAMERA_OBSCURA_LoadDepth(uv);
    float left = CAMERA_OBSCURA_LoadDepth(uv - float2(pixel.x, 0.0));
    float right = CAMERA_OBSCURA_LoadDepth(uv + float2(pixel.x, 0.0));
    float down = CAMERA_OBSCURA_LoadDepth(uv - float2(0.0, pixel.y));
    float up = CAMERA_OBSCURA_LoadDepth(uv + float2(0.0, pixel.y));
    float dx = LUNAR_FLOWER_TLPPSurfaceDerivative(left, center, right);
    float dy = LUNAR_FLOWER_TLPPSurfaceDerivative(down, center, up);
    guide.valid = CAMERA_OBSCURA_DepthConfidence(center);
    guide.depth = center;
    guide.normal = guide.valid > 0.5 ?
        normalize(float3(-dx, -dy, max(pixel.x + pixel.y, 0.0001))) :
        float3(0.0, 0.0, 1.0);
    // A neighboring discontinuity is not itself invalid donor depth. Retain
    // edge risk for deliberate styling/fill, without dimming every edge donor.
    guide.depth_confidence = guide.valid;
    guide.edge_risk = saturate((abs(left - center) + abs(right - center) +
        abs(down - center) + abs(up - center)) * 40.0);
    return guide;
}

bool LUNAR_FLOWER_TLPPScreenPointValid(
    float2 uv, float sceneDepth, CAMERA_OBSCURA_Ray ray,
    CAMERA_OBSCURA_TraceControls controls)
{
    float2 pixel = max(CAMERA_OBSCURA_PixelSize(), float2(0.000001, 0.000001));
    float distancePixels = length((uv - ray.origin_uv) / pixel);
    return ray.valid > 0.5 &&
        uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0 &&
        CAMERA_OBSCURA_DepthConfidence(sceneDepth) > 0.5 &&
        distancePixels > max(controls.self_hit_pixels, 0.0);
}

CAMERA_OBSCURA_Hit LUNAR_FLOWER_TLPPRefineScreenHit(
    CAMERA_OBSCURA_Ray ray, CAMERA_OBSCURA_Hit coarse,
    CAMERA_OBSCURA_TraceControls controls)
{
    CAMERA_OBSCURA_Hit refined = coarse;
    if (coarse.hit > 0.5)
    {
        if (!LUNAR_FLOWER_TLPPScreenPointValid(coarse.uv, coarse.scene_z, ray, controls))
        {
            // Do not fabricate support when even the coarse fallback is invalid.
            float reason = CAMERA_OBSCURA_REASON_INVALID_RAY;
            if (ray.valid > 0.5)
            {
                reason = CAMERA_OBSCURA_DepthConfidence(coarse.scene_z) > 0.5 ?
                    CAMERA_OBSCURA_REASON_SELF_HIT : CAMERA_OBSCURA_REASON_INVALID_DEPTH;
                if (coarse.uv.x < 0.0 || coarse.uv.x > 1.0 || coarse.uv.y < 0.0 || coarse.uv.y > 1.0)
                    reason = CAMERA_OBSCURA_REASON_SCREEN_EXIT;
            }
            refined = CAMERA_OBSCURA_MakeMiss(coarse.backend, reason);
        }
        else
        {
            float2 leftUv = coarse.previous_uv;
            float2 rightUv = coarse.uv;
            float leftRayZ = coarse.previous_ray_z;
            float rightRayZ = coarse.ray_z;
            float thickness = CAMERA_OBSCURA_EffectiveThickness(ray);
            int steps = CAMERA_OBSCURA_ClampSteps(controls.refinement_steps, CAMERA_OBSCURA_REFINE_STEPS);
            for (int i = 0; i < CAMERA_OBSCURA_REFINE_STEPS; ++i)
            {
                if (i >= steps) break;
                float2 midUv = (leftUv + rightUv) * 0.5;
                float midRayZ = (leftRayZ + rightRayZ) * 0.5;
                float sceneZ = CAMERA_OBSCURA_LoadDepth(midUv);
                float overlap = step(midRayZ - ray.front_bias, sceneZ) *
                    step(sceneZ, midRayZ + thickness);
                bool admissible = LUNAR_FLOWER_TLPPScreenPointValid(midUv, sceneZ, ray, controls);
                if (admissible && overlap > 0.5)
                {
                    refined.uv = midUv;
                    refined.ray_z = midRayZ;
                    refined.scene_z = sceneZ;
                    refined.delta = sceneZ - midRayZ;
                    refined.interval_min = midRayZ - ray.front_bias;
                    refined.interval_max = midRayZ + thickness;
                    rightUv = midUv;
                    rightRayZ = midRayZ;
                }
                else
                {
                    // Keep the known valid right endpoint. Advancing the left
                    // bracket preserves nearby donors without accepting self hits.
                    refined.previous_uv = midUv;
                    refined.previous_ray_z = midRayZ;
                    leftUv = midUv;
                    leftRayZ = midRayZ;
                }
            }
            refined.thickness_used = thickness;
            refined.confidence = CAMERA_OBSCURA_HitConfidence(
                refined.delta, ray.front_bias, thickness);
        }
    }
    return refined;
}

float4 LUNAR_FLOWER_TLPPSampleScreenDonor(
    CAMERA_OBSCURA_Ray ray,
    CAMERA_OBSCURA_SurfaceGuide receiver,
    CAMERA_OBSCURA_Hit hit,
    float maximumDistancePixels,
    float selfHitPixels, bool loadSourceColor)
{
    float4 sampleValue = float4(0.0, 0.0, 0.0, 0.0);
    if (ray.valid > 0.5 && receiver.valid > 0.5 && hit.hit > 0.5)
    {
        float2 pixel = max(CAMERA_OBSCURA_PixelSize(), float2(0.000001, 0.000001));
        float distancePixels = length((hit.uv - ray.origin_uv) / pixel);
        CAMERA_OBSCURA_SurfaceGuide donor = LUNAR_FLOWER_TLPPBuildSurfaceGuide(hit.uv);
        bool covered = hit.uv.x >= 0.0 && hit.uv.x <= 1.0 && hit.uv.y >= 0.0 && hit.uv.y <= 1.0;
        if (donor.valid > 0.5 && covered && distancePixels > max(selfHitPixels, 0.0))
        {
            float distanceWeight = saturate(1.0 - distancePixels / max(maximumDistancePixels, 0.000001));
            float compatibility = saturate(dot(receiver.normal, donor.normal));
            float weight = saturate(hit.confidence) * donor.depth_confidence *
                compatibility * distanceWeight;
            // Explicit base LOD: this call is reachable from varying ray loops.
            float3 color = float3(0.0, 0.0, 0.0);
            if (loadSourceColor)
                color = tex2Dlod(ReShade::BackBuffer, float4(hit.uv, 0.0, 0.0)).rgb;
            sampleValue = float4(saturate(color), weight);
        }
    }
    return sampleValue;
}

struct LUNAR_FLOWER_TLPPScreenEvidence
{
    float4 combined;
    float4 dda_sample;
    float4 march_sample;
    float dda_hit;
    float march_hit;
    float2 dda_uv;
    float2 march_uv;
    float dda_distance;
    float march_distance;
};

LUNAR_FLOWER_TLPPScreenEvidence LUNAR_FLOWER_TLPPTraceScreenDetailed(
    float2 uv, float directionIndex, float rayLengthPixels,
    float depthSlope, float frontBias, float backThickness, int providerMode,
    bool loadSourceColor, CAMERA_OBSCURA_SurfaceGuide receiver)
{
#if LUNAR_FLOWER_TLPP_COMPILED_PROVIDER >= 0
    providerMode = LUNAR_FLOWER_TLPP_COMPILED_PROVIDER;
#endif
    LUNAR_FLOWER_TLPPScreenEvidence result;
    result.combined = float4(0.0, 0.0, 0.0, 0.0);
    result.dda_sample = float4(0.0, 0.0, 0.0, 0.0);
    result.march_sample = float4(0.0, 0.0, 0.0, 0.0);
    result.dda_hit = 0.0;
    result.march_hit = 0.0;
    result.dda_uv = uv;
    result.march_uv = uv;
    result.dda_distance = 0.0;
    result.march_distance = 0.0;
    float safeLength = clamp(rayLengthPixels, 1.0, (float)CAMERA_OBSCURA_DDA_MAX_STEPS);
    float2 pixel = CAMERA_OBSCURA_PixelSize();
    float2 travel = CAMERA_OBSCURA_API_TL45Direction(directionIndex) * safeLength * pixel;
    CAMERA_OBSCURA_RayRequest request = CAMERA_OBSCURA_DefaultRayRequest(travel);
    request.ray_length_uv = length(travel);
    request.ray_depth_slope = max(depthSlope, 0.0);
    request.front_bias = max(frontBias, 0.0);
    request.back_thickness = max(backThickness, 0.0);
    request.requested_steps = CAMERA_OBSCURA_DDA_MAX_STEPS;
    CAMERA_OBSCURA_TraceControls controls = CAMERA_OBSCURA_BuildTraceControls(request);
    CAMERA_OBSCURA_Ray ray = CAMERA_OBSCURA_BuildRayC0(uv, receiver, request, controls);
    // A/B control: the same pixel distance has the same normalized depth travel
    // for every direction, including on rectangular render targets.
    ray.step_depth = max(depthSlope, 0.0) * safeLength * (pixel.x + pixel.y) * 0.5 /
        max(ray.steps, 1.0);
    float providerCount = 0.0;
#if LUNAR_FLOWER_TLPP_COMPILED_PROVIDER != 2
    [branch]
    if (providerMode != 2)
    {
        CAMERA_OBSCURA_Hit coarse = CAMERA_OBSCURA_TraceDDA(ray, controls);
        CAMERA_OBSCURA_Hit hit = LUNAR_FLOWER_TLPPRefineScreenHit(ray, coarse, controls);
        result.dda_hit = hit.hit;
        result.dda_uv = hit.uv;
        result.dda_distance = length((hit.uv - uv) / pixel);
        result.dda_sample = LUNAR_FLOWER_TLPPSampleScreenDonor(
            ray, receiver, hit, safeLength, controls.self_hit_pixels, loadSourceColor);
        providerCount += 1.0;
    }
#endif
#if LUNAR_FLOWER_TLPP_COMPILED_PROVIDER != 1
    [branch]
    if (providerMode != 1)
    {
        CAMERA_OBSCURA_TraceControls marchControls = controls;
        marchControls.spatial_phase = 1.0;
        CAMERA_OBSCURA_Hit coarse = CAMERA_OBSCURA_TraceMarch(ray, marchControls);
        CAMERA_OBSCURA_Hit hit = LUNAR_FLOWER_TLPPRefineScreenHit(ray, coarse, marchControls);
        result.march_hit = hit.hit;
        result.march_uv = hit.uv;
        result.march_distance = length((hit.uv - uv) / pixel);
        result.march_sample = LUNAR_FLOWER_TLPPSampleScreenDonor(
            ray, receiver, hit, safeLength, marchControls.self_hit_pixels, loadSourceColor);
        providerCount += 1.0;
    }
#endif
    float totalWeight = result.dda_sample.a + result.march_sample.a;
    float3 donor = (result.dda_sample.rgb * result.dda_sample.a +
        result.march_sample.rgb * result.march_sample.a) *
        CAMERA_OBSCURA_SafeRcp(totalWeight, 0.0) * step(0.000001, totalWeight);
    result.combined = float4(saturate(donor), saturate(totalWeight / max(providerCount, 1.0)));
    return result;
}

#endif
