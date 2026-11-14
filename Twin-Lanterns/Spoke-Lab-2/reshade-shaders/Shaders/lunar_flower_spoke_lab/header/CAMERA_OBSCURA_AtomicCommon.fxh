#ifndef CAMERA_OBSCURA_ATOMIC_COMMON_FXH
#define CAMERA_OBSCURA_ATOMIC_COMMON_FXH

#define CAMERA_OBSCURA_API_VERSION_MAJOR 0
#define CAMERA_OBSCURA_API_VERSION_MINOR 1
#define CAMERA_OBSCURA_API_VERSION_PATCH 0

#define CAMERA_OBSCURA_CAP_TIER_C0 0
#define CAMERA_OBSCURA_CAP_TIER_C1 1
#define CAMERA_OBSCURA_CAP_TIER_C2 2
#define CAMERA_OBSCURA_CAP_TIER_C3 3

#define CAMERA_OBSCURA_DEPTH_METRIC_NONE 0
#define CAMERA_OBSCURA_DEPTH_METRIC_LINEAR01 1

#define CAMERA_OBSCURA_BACKEND_NONE 0
#define CAMERA_OBSCURA_BACKEND_DDA 1
#define CAMERA_OBSCURA_BACKEND_MARCH 2

#define CAMERA_OBSCURA_REASON_HIT 0
#define CAMERA_OBSCURA_REASON_MAX_STEPS 1
#define CAMERA_OBSCURA_REASON_SCREEN_EXIT 2
#define CAMERA_OBSCURA_REASON_INVALID_DEPTH 3
#define CAMERA_OBSCURA_REASON_NO_INTERVAL 4
#define CAMERA_OBSCURA_REASON_NEAR_CLIP 5
#define CAMERA_OBSCURA_REASON_MAX_DISTANCE 6
#define CAMERA_OBSCURA_REASON_NUMERIC_INVALID 7
#define CAMERA_OBSCURA_REASON_SELF_HIT 8
#define CAMERA_OBSCURA_REASON_UNSUPPORTED_TIER 9
#define CAMERA_OBSCURA_REASON_INVALID_RAY 10

#ifndef CAMERA_OBSCURA_DDA_MAX_STEPS
#define CAMERA_OBSCURA_DDA_MAX_STEPS 24
#endif

#ifndef CAMERA_OBSCURA_MARCH_MAX_STEPS
#define CAMERA_OBSCURA_MARCH_MAX_STEPS 16
#endif

#ifndef CAMERA_OBSCURA_REFINE_STEPS
#define CAMERA_OBSCURA_REFINE_STEPS 2
#endif

#ifndef CAMERA_OBSCURA_MARCH_STEP_JITTER_STRENGTH
#define CAMERA_OBSCURA_MARCH_STEP_JITTER_STRENGTH 0.65
#endif

#ifndef CAMERA_OBSCURA_MARCH_DONOR_PREFILTER_STRENGTH
#define CAMERA_OBSCURA_MARCH_DONOR_PREFILTER_STRENGTH 0.45
#endif

struct CAMERA_OBSCURA_Capabilities
{
    float tier;
    float has_color;
    float has_depth;
    float has_linear_view_z;
    float has_projection;
    float has_inverse_projection;
    float has_history;
    float has_motion_vectors;
    float depth_metric;
};

struct CAMERA_OBSCURA_SurfaceGuide
{
    float valid;
    float depth;
    float3 normal;
    float depth_confidence;
    float edge_risk;
    float luma;
};

struct CAMERA_OBSCURA_RayRequest
{
    float2 direction_uv;
    float ray_length_uv;
    float ray_depth_slope;
    float front_bias;
    float back_thickness;
    float confidence_min;
    float self_hit_pixels;
    float distance_fade;
    float pixel_stride;
    float refinement_steps;
    float spatial_phase;
    float requested_steps;
};

struct CAMERA_OBSCURA_TraceControls
{
    float ray_length_uv;
    float ray_depth_slope;
    float front_bias;
    float back_thickness;
    float confidence_min;
    float self_hit_pixels;
    float distance_fade;
    float pixel_stride;
    float refinement_steps;
    float steps;
    float spatial_phase;
};

struct CAMERA_OBSCURA_Ray
{
    float valid;
    float capability_tier;
    float2 origin_uv;
    float2 step_uv;
    float origin_depth;
    float step_depth;
    float t_min;
    float t_max;
    float front_bias;
    float back_thickness;
    float confidence_min;
    float steps;
    float distance_fade;
};

struct CAMERA_OBSCURA_Hit
{
    float valid;
    float hit;
    float2 uv;
    float2 previous_uv;
    float ray_t;
    float previous_ray_z;
    float ray_z;
    float scene_z;
    float delta;
    float interval_min;
    float interval_max;
    float thickness_used;
    float confidence;
    float step_index;
    float backend;
    float reason;
    float capability_tier;
};

struct CAMERA_OBSCURA_DualHit
{
    float dda_hit;
    float dda_confidence;
    float dda_reason;
    float march_hit;
    float march_confidence;
    float march_reason;
    float uv_agreement;
    float depth_agreement;
    float distance_agreement;
    float conflict;
    float combined_confidence;
};

struct CAMERA_OBSCURA_Contribution
{
    float valid;
    float3 donor_rgb;
    float3 indirect_rgb;
    float weight;
    float coverage;
    float distance_weight;
    float receiver_facing;
    float donor_facing;
    float normal_compatibility;
    float confidence;
    float backend;
};

struct CAMERA_OBSCURA_Fallback
{
    float3 rgb;
    float confidence;
    float class_id;
};

float CAMERA_OBSCURA_SafeRcp(float denominator, float fallback)
{
    return abs(denominator) > 0.000001 ? (1.0 / denominator) : fallback;
}

float2 CAMERA_OBSCURA_PixelSize()
{
    return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
}

float2 CAMERA_OBSCURA_SaturateUV(float2 uv)
{
    return saturate(uv);
}

float CAMERA_OBSCURA_StableNoise01(float2 value)
{
    return frac(52.9829189 * frac(dot(value, float2(0.06711056, 0.00583715))));
}

float CAMERA_OBSCURA_Luma(float3 color)
{
    return dot(saturate(color), float3(0.2126, 0.7152, 0.0722));
}

float CAMERA_OBSCURA_DepthConfidence(float depth)
{
    return step(0.000001, depth) * step(depth, 0.999999);
}

int CAMERA_OBSCURA_ClampSteps(float requested, int maxSteps)
{
    return min(max((int)floor(requested + 0.5), 1), maxSteps);
}

CAMERA_OBSCURA_Hit CAMERA_OBSCURA_MakeMiss(float backend, float reason)
{
    CAMERA_OBSCURA_Hit hit;
    hit.valid = 1.0;
    hit.hit = 0.0;
    hit.uv = float2(0.0, 0.0);
    hit.previous_uv = float2(0.0, 0.0);
    hit.ray_t = 0.0;
    hit.previous_ray_z = 0.0;
    hit.ray_z = 0.0;
    hit.scene_z = 0.0;
    hit.delta = 0.0;
    hit.interval_min = 0.0;
    hit.interval_max = 0.0;
    hit.thickness_used = 0.0;
    hit.confidence = 0.0;
    hit.step_index = 0.0;
    hit.backend = backend;
    hit.reason = reason;
    hit.capability_tier = CAMERA_OBSCURA_CAP_TIER_C0;
    return hit;
}

float CAMERA_OBSCURA_EffectiveThickness(CAMERA_OBSCURA_Ray ray)
{
    float configuredThickness = max(ray.back_thickness, 0.0);
    return configuredThickness;
}

float CAMERA_OBSCURA_HitConfidence(
    float delta,
    float frontBias,
    float thicknessUsed)
{
    return saturate(
        1.0 - abs(delta) *
        CAMERA_OBSCURA_SafeRcp(frontBias + thicknessUsed + 0.0001, 0.0));
}

#endif // CAMERA_OBSCURA_ATOMIC_COMMON_FXH
