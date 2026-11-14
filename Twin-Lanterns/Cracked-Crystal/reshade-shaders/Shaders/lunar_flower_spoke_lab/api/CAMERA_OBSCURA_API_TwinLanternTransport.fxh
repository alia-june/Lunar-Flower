#ifndef CAMERA_OBSCURA_API_TWIN_LANTERN_TRANSPORT_FXH
#define CAMERA_OBSCURA_API_TWIN_LANTERN_TRANSPORT_FXH

#include "CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh"
#include "../header/CAMERA_OBSCURA_EntryTraversal.fxh"

#define CAMERA_OBSCURA_API_TL07_MODE_PARITY 0.0
#define CAMERA_OBSCURA_API_TL07_MODE_COMPLEMENTARY 1.0

struct CAMERA_OBSCURA_API_TwinLanternTransportEvidence
{
    float transport_mode;
    float transport_enabled;
    float ray_valid;
    float receiver_valid;
    float dda_hit;
    float dda_reason;
    float dda_donor_valid;
    float3 dda_donor_rgb;
    float dda_distance_pixels;
    float dda_distance_weight;
    float dda_receiver_facing;
    float dda_donor_facing;
    float dda_normal_compatibility;
    float dda_hit_confidence;
    float dda_raw_weight;
    float dda_normalized_weight;
    float march_hit;
    float march_reason;
    float march_donor_valid;
    float3 march_donor_rgb;
    float march_distance_pixels;
    float march_distance_weight;
    float march_receiver_facing;
    float march_donor_facing;
    float march_normal_compatibility;
    float march_hit_confidence;
    float march_raw_weight;
    float march_normalized_weight;
    float dda_weight_active;
    float march_weight_active;
    float both_weight_active;
    float dda_only_weight_active;
    float march_only_weight_active;
    float neither_weight_active;
    float one_provider_bound_ok;
    float provider_count;
    float total_raw_weight;
    float normalized_weight_sum;
    float evidence_strength;
    float3 combined_donor_rgb;
    float3 raw_radiance_rgb;
    float zero_contribution;
};

struct CAMERA_OBSCURA_API_TL07ProviderSample
{
    float valid;
    float3 donor_rgb;
    float distance_pixels;
    float distance_weight;
    float receiver_facing;
    float donor_facing;
    float normal_compatibility;
    float hit_confidence;
    float raw_weight;
};

CAMERA_OBSCURA_API_TwinLanternTransportEvidence
CAMERA_OBSCURA_API_DefaultTwinLanternTransportEvidence()
{
    CAMERA_OBSCURA_API_TwinLanternTransportEvidence evidence;
    evidence.transport_mode = CAMERA_OBSCURA_API_TL07_MODE_PARITY;
    evidence.transport_enabled = 0.0;
    evidence.ray_valid = 0.0;
    evidence.receiver_valid = 0.0;
    evidence.dda_hit = 0.0;
    evidence.dda_reason = CAMERA_OBSCURA_REASON_INVALID_RAY;
    evidence.dda_donor_valid = 0.0;
    evidence.dda_donor_rgb = float3(0.0, 0.0, 0.0);
    evidence.dda_distance_pixels = 0.0;
    evidence.dda_distance_weight = 0.0;
    evidence.dda_receiver_facing = 0.0;
    evidence.dda_donor_facing = 0.0;
    evidence.dda_normal_compatibility = 0.0;
    evidence.dda_hit_confidence = 0.0;
    evidence.dda_raw_weight = 0.0;
    evidence.dda_normalized_weight = 0.0;
    evidence.march_hit = 0.0;
    evidence.march_reason = CAMERA_OBSCURA_REASON_INVALID_RAY;
    evidence.march_donor_valid = 0.0;
    evidence.march_donor_rgb = float3(0.0, 0.0, 0.0);
    evidence.march_distance_pixels = 0.0;
    evidence.march_distance_weight = 0.0;
    evidence.march_receiver_facing = 0.0;
    evidence.march_donor_facing = 0.0;
    evidence.march_normal_compatibility = 0.0;
    evidence.march_hit_confidence = 0.0;
    evidence.march_raw_weight = 0.0;
    evidence.march_normalized_weight = 0.0;
    evidence.dda_weight_active = 0.0;
    evidence.march_weight_active = 0.0;
    evidence.both_weight_active = 0.0;
    evidence.dda_only_weight_active = 0.0;
    evidence.march_only_weight_active = 0.0;
    evidence.neither_weight_active = 1.0;
    evidence.one_provider_bound_ok = 1.0;
    evidence.provider_count = 0.0;
    evidence.total_raw_weight = 0.0;
    evidence.normalized_weight_sum = 0.0;
    evidence.evidence_strength = 0.0;
    evidence.combined_donor_rgb = float3(0.0, 0.0, 0.0);
    evidence.raw_radiance_rgb = float3(0.0, 0.0, 0.0);
    evidence.zero_contribution = 1.0;
    return evidence;
}

CAMERA_OBSCURA_API_TL07ProviderSample
CAMERA_OBSCURA_API_DefaultTL07ProviderSample()
{
    CAMERA_OBSCURA_API_TL07ProviderSample providerSample;
    providerSample.valid = 0.0;
    providerSample.donor_rgb = float3(0.0, 0.0, 0.0);
    providerSample.distance_pixels = 0.0;
    providerSample.distance_weight = 0.0;
    providerSample.receiver_facing = 0.0;
    providerSample.donor_facing = 0.0;
    providerSample.normal_compatibility = 0.0;
    providerSample.hit_confidence = 0.0;
    providerSample.raw_weight = 0.0;
    return providerSample;
}

CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_BuildTL07DonorGuide(float2 uv)
{
    CAMERA_OBSCURA_SurfaceGuide guide;
    guide.valid = 0.0;
    guide.depth = 0.0;
    guide.normal = float3(0.0, 0.0, 1.0);
    guide.depth_confidence = 0.0;
    guide.edge_risk = 0.0;
    guide.luma = 0.0;

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
    guide.normal = guide.valid > 0.5 ?
        normalize(float3(
            center - right,
            center - up,
            max(pixel.x + pixel.y, 0.0001))) :
        float3(0.0, 0.0, 1.0);
    guide.edge_risk = saturate(spread * 40.0);
    guide.depth_confidence = guide.valid * (1.0 - guide.edge_risk);
    return guide;
}

CAMERA_OBSCURA_API_TL07ProviderSample
CAMERA_OBSCURA_API_BuildTL07ProviderSample(
    CAMERA_OBSCURA_Ray ray,
    CAMERA_OBSCURA_SurfaceGuide receiver,
    CAMERA_OBSCURA_Hit hit,
    float maximumDistancePixels)
{
    CAMERA_OBSCURA_API_TL07ProviderSample providerSample =
        CAMERA_OBSCURA_API_DefaultTL07ProviderSample();

    [branch]
    if (ray.valid > 0.5 && receiver.valid > 0.5 && hit.hit > 0.5)
    {
        CAMERA_OBSCURA_SurfaceGuide donor =
            CAMERA_OBSCURA_API_BuildTL07DonorGuide(hit.uv);
        [branch]
        if (donor.valid > 0.5)
        {
            float2 pixel = max(
                CAMERA_OBSCURA_PixelSize(),
                float2(0.000001, 0.000001));
            float distancePixels = length((hit.uv - ray.origin_uv) / pixel);
            float distanceWeight = saturate(
                1.0 - distancePixels / max(maximumDistancePixels, 0.000001));
            float compatibility = saturate(dot(receiver.normal, donor.normal));
            float confidence = saturate(hit.confidence);
            float rawWeight =
                confidence *
                donor.depth_confidence *
                compatibility *
                distanceWeight;
            float3 directDonor = CAMERA_OBSCURA_LoadColor(hit.uv);

            providerSample.valid = 1.0;
            providerSample.donor_rgb = saturate(directDonor);
            providerSample.distance_pixels = distancePixels;
            providerSample.distance_weight = distanceWeight;
            providerSample.receiver_facing = 1.0;
            providerSample.donor_facing = 1.0;
            providerSample.normal_compatibility = compatibility;
            providerSample.hit_confidence = confidence;
            providerSample.raw_weight = rawWeight;
        }
    }
    return providerSample;
}

CAMERA_OBSCURA_API_TwinLanternTransportEvidence
CAMERA_OBSCURA_API_BuildTwinLanternTransportEvidence(
    float2 uv,
    float directionIndex,
    float inputMode,
    float transportMode,
    float rayLengthPixels,
    float depthSlope,
    float frontBias,
    float backThickness)
{
    CAMERA_OBSCURA_API_TwinLanternTransportEvidence evidence =
        CAMERA_OBSCURA_API_DefaultTwinLanternTransportEvidence();
    CAMERA_OBSCURA_TraceControls controls;
    CAMERA_OBSCURA_SurfaceGuide receiver;
    float safeRayLength = min(
        max(rayLengthPixels, 1.0),
        (float)CAMERA_OBSCURA_DDA_MAX_STEPS);
    CAMERA_OBSCURA_Ray ray = CAMERA_OBSCURA_API_BuildTL45Ray(
        uv,
        directionIndex,
        inputMode,
        CAMERA_OBSCURA_DDA_MAX_STEPS,
        safeRayLength,
        depthSlope,
        frontBias,
        backThickness,
        controls,
        receiver);

    CAMERA_OBSCURA_TraceControls ddaControls = controls;
    CAMERA_OBSCURA_TraceControls marchControls = controls;
    float complementary = step(0.5, transportMode);
    marchControls.spatial_phase = complementary;

    CAMERA_OBSCURA_Hit ddaCoarse = CAMERA_OBSCURA_TraceDDA(ray, ddaControls);
    CAMERA_OBSCURA_Hit dda = CAMERA_OBSCURA_RefineHit(
        ray, ddaCoarse, ddaControls);
    CAMERA_OBSCURA_Hit marchCoarse =
        CAMERA_OBSCURA_TraceMarch(ray, marchControls);
    CAMERA_OBSCURA_Hit march = CAMERA_OBSCURA_RefineHit(
        ray, marchCoarse, marchControls);

    evidence.transport_mode = complementary;
    evidence.transport_enabled = complementary;
    evidence.ray_valid = ray.valid;
    evidence.receiver_valid = receiver.valid;
    evidence.dda_hit = dda.hit;
    evidence.dda_reason = dda.reason;
    evidence.dda_hit_confidence = dda.confidence;
    evidence.march_hit = march.hit;
    evidence.march_reason = march.reason;
    evidence.march_hit_confidence = march.confidence;

    [branch]
    if (complementary < 0.5)
    {
        return evidence;
    }

    CAMERA_OBSCURA_API_TL07ProviderSample ddaSample =
        CAMERA_OBSCURA_API_BuildTL07ProviderSample(
            ray, receiver, dda, safeRayLength);
    CAMERA_OBSCURA_API_TL07ProviderSample marchSample =
        CAMERA_OBSCURA_API_BuildTL07ProviderSample(
            ray, receiver, march, safeRayLength);
    float totalRawWeight = ddaSample.raw_weight + marchSample.raw_weight;
    float hasWeight = step(0.000001, totalRawWeight);
    float inverseTotal = CAMERA_OBSCURA_SafeRcp(totalRawWeight, 0.0);
    float ddaNormalized = ddaSample.raw_weight * inverseTotal * hasWeight;
    float marchNormalized = marchSample.raw_weight * inverseTotal * hasWeight;
    float evidenceStrength = saturate(totalRawWeight * 0.5);
    float ddaWeightActive = step(0.000001, ddaSample.raw_weight);
    float marchWeightActive = step(0.000001, marchSample.raw_weight);
    float bothWeightActive = min(ddaWeightActive, marchWeightActive);
    float ddaOnlyWeightActive = ddaWeightActive * (1.0 - marchWeightActive);
    float marchOnlyWeightActive = marchWeightActive * (1.0 - ddaWeightActive);
    float neitherWeightActive =
        (1.0 - ddaWeightActive) * (1.0 - marchWeightActive);
    float oneWeightActive = ddaOnlyWeightActive + marchOnlyWeightActive;
    float oneProviderViolation =
        oneWeightActive * step(0.500001, evidenceStrength);
    float3 combinedDonor =
        ddaSample.donor_rgb * ddaNormalized +
        marchSample.donor_rgb * marchNormalized;

    evidence.dda_donor_valid = ddaSample.valid;
    evidence.dda_donor_rgb = ddaSample.donor_rgb;
    evidence.dda_distance_pixels = ddaSample.distance_pixels;
    evidence.dda_distance_weight = ddaSample.distance_weight;
    evidence.dda_receiver_facing = ddaSample.receiver_facing;
    evidence.dda_donor_facing = ddaSample.donor_facing;
    evidence.dda_normal_compatibility = ddaSample.normal_compatibility;
    evidence.dda_hit_confidence = ddaSample.hit_confidence;
    evidence.dda_raw_weight = ddaSample.raw_weight;
    evidence.dda_normalized_weight = ddaNormalized;
    evidence.march_donor_valid = marchSample.valid;
    evidence.march_donor_rgb = marchSample.donor_rgb;
    evidence.march_distance_pixels = marchSample.distance_pixels;
    evidence.march_distance_weight = marchSample.distance_weight;
    evidence.march_receiver_facing = marchSample.receiver_facing;
    evidence.march_donor_facing = marchSample.donor_facing;
    evidence.march_normal_compatibility = marchSample.normal_compatibility;
    evidence.march_hit_confidence = marchSample.hit_confidence;
    evidence.march_raw_weight = marchSample.raw_weight;
    evidence.march_normalized_weight = marchNormalized;
    evidence.dda_weight_active = ddaWeightActive;
    evidence.march_weight_active = marchWeightActive;
    evidence.both_weight_active = bothWeightActive;
    evidence.dda_only_weight_active = ddaOnlyWeightActive;
    evidence.march_only_weight_active = marchOnlyWeightActive;
    evidence.neither_weight_active = neitherWeightActive;
    evidence.one_provider_bound_ok = 1.0 - oneProviderViolation;
    evidence.provider_count = ddaSample.valid + marchSample.valid;
    evidence.total_raw_weight = totalRawWeight;
    evidence.normalized_weight_sum = ddaNormalized + marchNormalized;
    evidence.evidence_strength = evidenceStrength;
    evidence.combined_donor_rgb = combinedDonor;
    evidence.raw_radiance_rgb = combinedDonor * evidenceStrength;
    evidence.zero_contribution = 1.0 - hasWeight;
    return evidence;
}

#endif // CAMERA_OBSCURA_API_TWIN_LANTERN_TRANSPORT_FXH
