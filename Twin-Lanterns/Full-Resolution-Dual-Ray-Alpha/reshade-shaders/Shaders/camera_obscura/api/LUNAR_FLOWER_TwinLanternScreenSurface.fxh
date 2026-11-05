#ifndef LUNAR_FLOWER_TWIN_LANTERN_SCREEN_SURFACE_FXH
#define LUNAR_FLOWER_TWIN_LANTERN_SCREEN_SURFACE_FXH

// Alpha-local experiment. Shared API 0.1.0 and the fixed builds are unchanged.
float LUNAR_FLOWER_TLFRSurfaceDerivative(float negative, float center, float positive)
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

CAMERA_OBSCURA_SurfaceGuide LUNAR_FLOWER_TLFRBuildSurfaceGuide(float2 uv)
{
    CAMERA_OBSCURA_SurfaceGuide guide = CAMERA_OBSCURA_API_DefaultTL08Guide();
    float2 pixel = CAMERA_OBSCURA_PixelSize();
    float center = CAMERA_OBSCURA_LoadDepth(uv);
    float left = CAMERA_OBSCURA_LoadDepth(uv - float2(pixel.x, 0.0));
    float right = CAMERA_OBSCURA_LoadDepth(uv + float2(pixel.x, 0.0));
    float down = CAMERA_OBSCURA_LoadDepth(uv - float2(0.0, pixel.y));
    float up = CAMERA_OBSCURA_LoadDepth(uv + float2(0.0, pixel.y));
    float dx = LUNAR_FLOWER_TLFRSurfaceDerivative(left, center, right);
    float dy = LUNAR_FLOWER_TLFRSurfaceDerivative(down, center, up);
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

float4 LUNAR_FLOWER_TLFRSampleScreenDonor(
    CAMERA_OBSCURA_Ray ray,
    CAMERA_OBSCURA_SurfaceGuide receiver,
    CAMERA_OBSCURA_Hit hit,
    float maximumDistancePixels)
{
    float4 sampleValue = float4(0.0, 0.0, 0.0, 0.0);
    if (ray.valid > 0.5 && receiver.valid > 0.5 && hit.hit > 0.5)
    {
        CAMERA_OBSCURA_SurfaceGuide donor = LUNAR_FLOWER_TLFRBuildSurfaceGuide(hit.uv);
        if (donor.valid > 0.5)
        {
            float2 pixel = max(CAMERA_OBSCURA_PixelSize(), float2(0.000001, 0.000001));
            float distancePixels = length((hit.uv - ray.origin_uv) / pixel);
            float distanceWeight = saturate(1.0 - distancePixels / max(maximumDistancePixels, 0.000001));
            float compatibility = saturate(dot(receiver.normal, donor.normal));
            float weight = saturate(hit.confidence) * donor.depth_confidence *
                compatibility * distanceWeight;
            sampleValue = float4(saturate(CAMERA_OBSCURA_LoadColor(hit.uv)), weight);
        }
    }
    return sampleValue;
}

float4 LUNAR_FLOWER_TLFRTraceScreen(
    float2 uv, float directionIndex, float rayLengthPixels,
    float depthSlope, float frontBias, float backThickness)
{
    float safeLength = clamp(rayLengthPixels, 1.0, (float)CAMERA_OBSCURA_DDA_MAX_STEPS);
    float2 travel = CAMERA_OBSCURA_API_TL45Direction(directionIndex) *
        safeLength * CAMERA_OBSCURA_PixelSize();
    CAMERA_OBSCURA_SurfaceGuide receiver = LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
    CAMERA_OBSCURA_RayRequest request = CAMERA_OBSCURA_DefaultRayRequest(travel);
    request.ray_length_uv = length(travel);
    request.ray_depth_slope = max(depthSlope, 0.0);
    request.front_bias = max(frontBias, 0.0);
    request.back_thickness = max(backThickness, 0.0);
    request.requested_steps = CAMERA_OBSCURA_DDA_MAX_STEPS;
    CAMERA_OBSCURA_TraceControls controls = CAMERA_OBSCURA_BuildTraceControls(request);
    CAMERA_OBSCURA_Ray ray = CAMERA_OBSCURA_BuildRayC0(uv, receiver, request, controls);
    CAMERA_OBSCURA_TraceControls marchControls = controls;
    marchControls.spatial_phase = 1.0;
    CAMERA_OBSCURA_Hit ddaCoarse = CAMERA_OBSCURA_TraceDDA(ray, controls);
    CAMERA_OBSCURA_Hit dda = CAMERA_OBSCURA_RefineHit(ray, ddaCoarse, controls);
    CAMERA_OBSCURA_Hit marchCoarse = CAMERA_OBSCURA_TraceMarch(ray, marchControls);
    CAMERA_OBSCURA_Hit march = CAMERA_OBSCURA_RefineHit(ray, marchCoarse, marchControls);
    float4 ddaSample = LUNAR_FLOWER_TLFRSampleScreenDonor(ray, receiver, dda, safeLength);
    float4 marchSample = LUNAR_FLOWER_TLFRSampleScreenDonor(ray, receiver, march, safeLength);
    float totalWeight = ddaSample.a + marchSample.a;
    float hasWeight = step(0.000001, totalWeight);
    float3 donor = (ddaSample.rgb * ddaSample.a + marchSample.rgb * marchSample.a) *
        CAMERA_OBSCURA_SafeRcp(totalWeight, 0.0) * hasWeight;
    return float4(saturate(donor), saturate(totalWeight * 0.5));
}

#endif
