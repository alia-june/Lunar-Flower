#ifndef LUNAR_FLOWER_API_TWIN_LANTERN_VOXEL_PROXY_FXH
#define LUNAR_FLOWER_API_TWIN_LANTERN_VOXEL_PROXY_FXH

// Current-frame, camera-visible proxy only. This is not world voxelization.
#define LUNAR_FLOWER_TL_VOXEL_WIDTH 64
#define LUNAR_FLOWER_TL_VOXEL_HEIGHT 36
#define LUNAR_FLOWER_TL_VOXEL_DEPTH 32
#define LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS 32

texture3D LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceTex
{
    Width = LUNAR_FLOWER_TL_VOXEL_WIDTH;
    Height = LUNAR_FLOWER_TL_VOXEL_HEIGHT;
    Depth = LUNAR_FLOWER_TL_VOXEL_DEPTH;
    Format = RGBA16F;
};

storage3D LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceStorage
{
    Texture = LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceTex;
};

sampler3D LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceSampler
{
    Texture = LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

struct LUNAR_FLOWER_API_TwinLanternVoxelEvidence
{
    float3 radiance_rgb;
    float evidence;
    float hit;
    float normalized_distance;
};

LUNAR_FLOWER_API_TwinLanternVoxelEvidence
LUNAR_FLOWER_API_DefaultTwinLanternVoxelEvidence()
{
    LUNAR_FLOWER_API_TwinLanternVoxelEvidence evidence;
    evidence.radiance_rgb = float3(0.0, 0.0, 0.0);
    evidence.evidence = 0.0;
    evidence.hit = 0.0;
    evidence.normalized_distance = 0.0;
    return evidence;
}

[shader("compute")]
void LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(
    uint3 id : SV_DispatchThreadID)
{
    if (
        id.x >= LUNAR_FLOWER_TL_VOXEL_WIDTH ||
        id.y >= LUNAR_FLOWER_TL_VOXEL_HEIGHT ||
        id.z >= LUNAR_FLOWER_TL_VOXEL_DEPTH)
    {
        return;
    }

    float2 uv = (float2(id.xy) + 0.5) /
        float2(
            LUNAR_FLOWER_TL_VOXEL_WIDTH,
            LUNAR_FLOWER_TL_VOXEL_HEIGHT);
    float depth = saturate(ReShade::GetLinearizedDepth(uv));
    float valid = CAMERA_OBSCURA_DepthConfidence(depth);
    int depthCell = min(
        (int)floor(depth * (float)LUNAR_FLOWER_TL_VOXEL_DEPTH),
        LUNAR_FLOWER_TL_VOXEL_DEPTH - 1);
    float occupied = valid * ((int)id.z == depthCell ? 1.0 : 0.0);
    float3 source = tex2Dlod(
        ReShade::BackBuffer,
        float4(CAMERA_OBSCURA_SaturateUV(uv), 0.0, 0.0)).rgb;

    tex3Dstore(
        LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceStorage,
        int3(id),
        float4(saturate(source) * occupied, occupied));
}

float4 LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(float2 uv)
{
    float2 uvSafe = CAMERA_OBSCURA_SaturateUV(uv);
    float depth = CAMERA_OBSCURA_LoadDepth(uvSafe);
    float valid = CAMERA_OBSCURA_DepthConfidence(depth);
    int3 dimensions = int3(
        LUNAR_FLOWER_TL_VOXEL_WIDTH,
        LUNAR_FLOWER_TL_VOXEL_HEIGHT,
        LUNAR_FLOWER_TL_VOXEL_DEPTH);
    int3 cell = int3(
        min((int)floor(uvSafe.x * dimensions.x), dimensions.x - 1),
        min((int)floor(uvSafe.y * dimensions.y), dimensions.y - 1),
        min((int)floor(depth * dimensions.z), dimensions.z - 1));
    return tex3Dfetch(LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceSampler, cell) * valid;
}

LUNAR_FLOWER_API_TwinLanternVoxelEvidence
LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(
    float2 uv,
    float directionIndex,
    float rayLengthPixels,
    float depthSlope,
    float frontBias,
    float backThickness,
    float requestedSteps)
{
    LUNAR_FLOWER_API_TwinLanternVoxelEvidence evidence =
        LUNAR_FLOWER_API_DefaultTwinLanternVoxelEvidence();
    CAMERA_OBSCURA_TraceControls controls;
    CAMERA_OBSCURA_SurfaceGuide receiver;
    float safeSteps = min(
        max(requestedSteps, 1.0),
        (float)LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS);
    CAMERA_OBSCURA_Ray ray = CAMERA_OBSCURA_API_BuildTL45Ray(
        uv,
        directionIndex,
        CAMERA_OBSCURA_API_TL45_INPUT_LIVE,
        safeSteps,
        rayLengthPixels,
        depthSlope,
        frontBias,
        backThickness,
        controls,
        receiver);
    int stepCount = min(
        max((int)floor(safeSteps + 0.5), 1),
        LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS);
    int3 dimensions = int3(
        LUNAR_FLOWER_TL_VOXEL_WIDTH,
        LUNAR_FLOWER_TL_VOXEL_HEIGHT,
        LUNAR_FLOWER_TL_VOXEL_DEPTH);

    [loop]
    for (int stepIndex = 1;
         stepIndex <= LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS;
         ++stepIndex)
    {
        if (stepIndex > stepCount)
        {
            break;
        }

        float2 requestedUv = ray.origin_uv + ray.step_uv * (float)stepIndex;
        float coverage =
            step(0.0, requestedUv.x) * step(requestedUv.x, 1.0) *
            step(0.0, requestedUv.y) * step(requestedUv.y, 1.0);
        if (coverage < 0.5)
        {
            break;
        }

        float rayDepth = saturate(
            ray.origin_depth + ray.step_depth * (float)stepIndex);
        int3 cell = int3(
            min((int)floor(requestedUv.x * dimensions.x), dimensions.x - 1),
            min((int)floor(requestedUv.y * dimensions.y), dimensions.y - 1),
            min((int)floor(rayDepth * dimensions.z), dimensions.z - 1));
        float4 voxel = tex3Dfetch(
            LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceSampler,
            cell);
        float normalizedDistance =
            (float)stepIndex / max((float)stepCount, 1.0);
        float distanceWeight = saturate(1.0 - normalizedDistance);
        float accepted = ray.valid * receiver.valid *
            saturate(voxel.a) * distanceWeight;

        if (accepted > 0.000001)
        {
            evidence.radiance_rgb = saturate(voxel.rgb);
            evidence.evidence = saturate(accepted);
            evidence.hit = 1.0;
            evidence.normalized_distance = normalizedDistance;
            break;
        }
    }

    return evidence;
}

#endif // LUNAR_FLOWER_API_TWIN_LANTERN_VOXEL_PROXY_FXH
