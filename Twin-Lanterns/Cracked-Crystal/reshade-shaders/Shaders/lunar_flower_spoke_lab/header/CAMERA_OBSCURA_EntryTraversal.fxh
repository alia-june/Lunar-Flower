#ifndef CAMERA_OBSCURA_ENTRY_TRAVERSAL_FXH
#define CAMERA_OBSCURA_ENTRY_TRAVERSAL_FXH

#include "CAMERA_OBSCURA_EntryCapability.fxh"

#ifndef CAMERA_OBSCURA_TRAVERSAL_DDA_ONLY
CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceMarch(
    CAMERA_OBSCURA_Ray ray,
    CAMERA_OBSCURA_TraceControls controls)
{
    CAMERA_OBSCURA_Hit result = CAMERA_OBSCURA_MakeMiss(
        CAMERA_OBSCURA_BACKEND_MARCH,
        CAMERA_OBSCURA_REASON_MAX_STEPS);
    int steps = CAMERA_OBSCURA_ClampSteps(ray.steps, CAMERA_OBSCURA_MARCH_MAX_STEPS);
    float providerStepScale =
        ray.steps * CAMERA_OBSCURA_SafeRcp((float)steps, 0.0);
    float2 providerStepUv = ray.step_uv * providerStepScale;
    float providerStepDepth = ray.step_depth * providerStepScale;
    float2 pixelSize = max(CAMERA_OBSCURA_PixelSize(), float2(0.000001, 0.000001));
    float effectiveThickness = CAMERA_OBSCURA_EffectiveThickness(ray);
    float2 pixelCoord = floor(ray.origin_uv / pixelSize);
    float marchStepJitter = CAMERA_OBSCURA_StableNoise01(
        pixelCoord + float2(controls.spatial_phase, controls.spatial_phase * 1.37)) *
        saturate(CAMERA_OBSCURA_MARCH_STEP_JITTER_STRENGTH);
    float2 previousUv = ray.origin_uv;
    float previousRayZ = ray.origin_depth;
    float sawInvalidDepth = 0.0;
    float sawSelfHit = 0.0;

    result.capability_tier = ray.capability_tier;

    if (ray.valid < 0.5)
    {
        result.reason = CAMERA_OBSCURA_REASON_INVALID_RAY;
    }
    else
    {
        [loop]
        for (int i = 0; i < CAMERA_OBSCURA_MARCH_MAX_STEPS; ++i)
        {
            if (i >= steps)
            {
                break;
            }

            float stepIndex = (float)(i + 1) + marchStepJitter;
            float2 unclampedUv = ray.origin_uv + providerStepUv * stepIndex;
            float2 uv = CAMERA_OBSCURA_SaturateUV(unclampedUv);
            float outside = step(0.000001, length(unclampedUv - uv));

            if (outside > 0.5)
            {
                result.reason = CAMERA_OBSCURA_REASON_SCREEN_EXIT;
                result.step_index = stepIndex;
                result.uv = uv;
                result.previous_uv = previousUv;
                break;
            }

            float rayZ = ray.origin_depth + providerStepDepth * stepIndex;
            float sceneZ = CAMERA_OBSCURA_LoadDepth(uv);
            float depthValid = CAMERA_OBSCURA_DepthConfidence(sceneZ);
            float intervalMin = min(previousRayZ, rayZ) - ray.front_bias;
            float intervalMax = max(previousRayZ, rayZ) + effectiveThickness;
            float overlap = step(intervalMin, sceneZ) * step(sceneZ, intervalMax);
            float originDistancePixels = length((uv - ray.origin_uv) / pixelSize);

            result.uv = uv;
            result.previous_uv = previousUv;
            result.step_index = stepIndex;
            result.previous_ray_z = previousRayZ;
            result.ray_z = rayZ;
            result.scene_z = sceneZ;

            if (depthValid < 0.5)
            {
                sawInvalidDepth = 1.0;
                overlap = 0.0;
            }
            else if (originDistancePixels <= controls.self_hit_pixels)
            {
                sawSelfHit = max(sawSelfHit, overlap);
                overlap = 0.0;
            }

            if (overlap > 0.5)
            {
                float confidence = CAMERA_OBSCURA_HitConfidence(
                    sceneZ - rayZ,
                    ray.front_bias,
                    effectiveThickness);

                result = CAMERA_OBSCURA_MakeMiss(
                    CAMERA_OBSCURA_BACKEND_MARCH,
                    CAMERA_OBSCURA_REASON_HIT);
                result.hit = 1.0;
                result.uv = uv;
                result.previous_uv = previousUv;
                result.ray_t = stepIndex;
                result.previous_ray_z = previousRayZ;
                result.ray_z = rayZ;
                result.scene_z = sceneZ;
                result.delta = sceneZ - rayZ;
                result.interval_min = intervalMin;
                result.interval_max = intervalMax;
                result.thickness_used = effectiveThickness;
                result.confidence = confidence;
                result.step_index = stepIndex;
                result.capability_tier = ray.capability_tier;
                break;
            }

            previousUv = uv;
            previousRayZ = rayZ;
        }

        if ((result.hit < 0.5) &&
            (result.reason == CAMERA_OBSCURA_REASON_MAX_STEPS))
        {
            if (sawInvalidDepth > 0.5)
            {
                result.reason = CAMERA_OBSCURA_REASON_INVALID_DEPTH;
            }
            else if (sawSelfHit > 0.5)
            {
                result.reason = CAMERA_OBSCURA_REASON_SELF_HIT;
            }
        }
    }

    return result;
}
#endif

#ifndef CAMERA_OBSCURA_TRAVERSAL_MARCH_ONLY
CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceDDA(
    CAMERA_OBSCURA_Ray ray,
    CAMERA_OBSCURA_TraceControls controls)
{
    CAMERA_OBSCURA_Hit result = CAMERA_OBSCURA_MakeMiss(
        CAMERA_OBSCURA_BACKEND_DDA,
        CAMERA_OBSCURA_REASON_MAX_STEPS);
    float2 pixelSize = max(CAMERA_OBSCURA_PixelSize(), float2(0.000001, 0.000001));
    float2 requestedTravelUv = ray.step_uv * ray.steps;
    float2 requestedTravelPixels = requestedTravelUv / pixelSize;
    // Performance probe: equal angular sampling with an independently selectable
    // DDA budget. Lower sample density does not shorten the requested ray.
    int requestedCells = CAMERA_OBSCURA_ClampSteps(controls.steps, LUNAR_FLOWER_TLSL_DDA_STEPS);
    int steps = requestedCells;
    float directionLength = length(requestedTravelUv);
    float effectiveThickness = CAMERA_OBSCURA_EffectiveThickness(ray);
    float2 previousUv = ray.origin_uv;
    float previousRayZ = ray.origin_depth;
    float sawInvalidDepth = 0.0;
    float sawSelfHit = 0.0;

    result.capability_tier = ray.capability_tier;

    if (ray.valid < 0.5 || directionLength <= 0.000001)
    {
        result.reason = CAMERA_OBSCURA_REASON_INVALID_RAY;
    }
    else
    {
        float2 ddaStep = requestedTravelUv *
            CAMERA_OBSCURA_SafeRcp((float)requestedCells, 0.0);
        float requestedDepthTravel = ray.step_depth * ray.steps;
        float depthStep = requestedDepthTravel *
            CAMERA_OBSCURA_SafeRcp((float)requestedCells, 0.0);

        [loop]
        for (int i = 0; i < LUNAR_FLOWER_TLSL_DDA_STEPS; ++i)
        {
            if (i >= steps)
            {
                break;
            }

            float stepIndex = (float)(i + 1);
            float2 unclampedUv = ray.origin_uv + ddaStep * stepIndex;
            float2 uv = CAMERA_OBSCURA_SaturateUV(unclampedUv);
            float outside = step(0.000001, length(unclampedUv - uv));

            if (outside > 0.5)
            {
                result.reason = CAMERA_OBSCURA_REASON_SCREEN_EXIT;
                result.step_index = stepIndex;
                result.uv = uv;
                result.previous_uv = previousUv;
                break;
            }

            float rayZ = ray.origin_depth + depthStep * stepIndex;
            float sceneZ = CAMERA_OBSCURA_LoadDepth(uv);
            float depthValid = CAMERA_OBSCURA_DepthConfidence(sceneZ);
            float intervalMin = min(previousRayZ, rayZ) - ray.front_bias;
            float intervalMax = max(previousRayZ, rayZ) + effectiveThickness;
            float overlap = step(intervalMin, sceneZ) * step(sceneZ, intervalMax);
            float originDistancePixels = length((uv - ray.origin_uv) / pixelSize);

            result.uv = uv;
            result.previous_uv = previousUv;
            result.step_index = stepIndex;
            result.previous_ray_z = previousRayZ;
            result.ray_z = rayZ;
            result.scene_z = sceneZ;

            if (depthValid < 0.5)
            {
                sawInvalidDepth = 1.0;
                overlap = 0.0;
            }
            else if (originDistancePixels <= controls.self_hit_pixels)
            {
                sawSelfHit = max(sawSelfHit, overlap);
                overlap = 0.0;
            }

            if (overlap > 0.5)
            {
                float confidence = CAMERA_OBSCURA_HitConfidence(
                    sceneZ - rayZ,
                    ray.front_bias,
                    effectiveThickness);

                result = CAMERA_OBSCURA_MakeMiss(
                    CAMERA_OBSCURA_BACKEND_DDA,
                    CAMERA_OBSCURA_REASON_HIT);
                result.hit = 1.0;
                result.uv = uv;
                result.previous_uv = previousUv;
                result.ray_t = stepIndex;
                result.previous_ray_z = previousRayZ;
                result.ray_z = rayZ;
                result.scene_z = sceneZ;
                result.delta = sceneZ - rayZ;
                result.interval_min = intervalMin;
                result.interval_max = intervalMax;
                result.thickness_used = effectiveThickness;
                result.confidence = confidence;
                result.step_index = stepIndex;
                result.capability_tier = ray.capability_tier;
                break;
            }

            previousUv = uv;
            previousRayZ = rayZ;
        }

        if ((result.hit < 0.5) &&
            (result.reason == CAMERA_OBSCURA_REASON_MAX_STEPS))
        {
            if (sawInvalidDepth > 0.5)
            {
                result.reason = CAMERA_OBSCURA_REASON_INVALID_DEPTH;
            }
            else if (sawSelfHit > 0.5)
            {
                result.reason = CAMERA_OBSCURA_REASON_SELF_HIT;
            }
        }
    }

    return result;
}
#endif

CAMERA_OBSCURA_Hit CAMERA_OBSCURA_RefineHit(
    CAMERA_OBSCURA_Ray ray,
    CAMERA_OBSCURA_Hit coarse,
    CAMERA_OBSCURA_TraceControls controls)
{
    int refineSteps = CAMERA_OBSCURA_ClampSteps(
        controls.refinement_steps,
        CAMERA_OBSCURA_REFINE_STEPS);
    float effectiveThickness = CAMERA_OBSCURA_EffectiveThickness(ray);
    CAMERA_OBSCURA_Hit refined = coarse;

    if (coarse.hit >= 0.5)
    {
        float2 leftUv = coarse.previous_uv;
        float2 rightUv = coarse.uv;
        float leftRayZ = coarse.previous_ray_z;
        float rightRayZ = coarse.ray_z;

        [loop]
        for (int i = 0; i < CAMERA_OBSCURA_REFINE_STEPS; ++i)
        {
            if (i >= refineSteps)
            {
                break;
            }

            float2 midUv = CAMERA_OBSCURA_SaturateUV((leftUv + rightUv) * 0.5);
            float midRayZ = (leftRayZ + rightRayZ) * 0.5;
            float sceneZ = CAMERA_OBSCURA_LoadDepth(midUv);
            float overlap = step(midRayZ - ray.front_bias, sceneZ) *
                step(sceneZ, midRayZ + effectiveThickness);

            if (overlap > 0.5)
            {
                refined.uv = midUv;
                refined.ray_z = midRayZ;
                refined.scene_z = sceneZ;
                refined.delta = sceneZ - midRayZ;
                refined.interval_min = midRayZ - ray.front_bias;
                refined.interval_max = midRayZ + effectiveThickness;
                rightUv = midUv;
                rightRayZ = midRayZ;
            }
            else
            {
                refined.previous_uv = midUv;
                refined.previous_ray_z = midRayZ;
                leftUv = midUv;
                leftRayZ = midRayZ;
            }
        }

        refined.thickness_used = effectiveThickness;
        refined.confidence = saturate(max(
            refined.confidence,
            CAMERA_OBSCURA_HitConfidence(
                refined.delta,
                ray.front_bias,
                effectiveThickness)));
    }

    return refined;
}

#endif // CAMERA_OBSCURA_ENTRY_TRAVERSAL_FXH
