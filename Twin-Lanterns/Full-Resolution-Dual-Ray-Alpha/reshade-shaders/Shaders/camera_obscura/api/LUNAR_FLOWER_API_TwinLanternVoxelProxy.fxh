#ifndef LUNAR_FLOWER_API_TWIN_LANTERN_VOXEL_PROXY_FXH
#define LUNAR_FLOWER_API_TWIN_LANTERN_VOXEL_PROXY_FXH

// Adaptive camera-visible depth shell, not world voxelization or an octree.
// A bounded quadtree per screen tile: root + 4 children + 16 grandchildren.
#define LUNAR_FLOWER_TL_VOXEL_WIDTH 64
#define LUNAR_FLOWER_TL_VOXEL_HEIGHT 36
#define LUNAR_FLOWER_TL_VOXEL_DEPTH 21
#define LUNAR_FLOWER_TL_VOXEL_MAX_LEVEL 2
#define LUNAR_FLOWER_TL_VOXEL_DEPTH_SPLIT 0.001
#define LUNAR_FLOWER_TL_VOXEL_COLOR_SPLIT 0.08
#define LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS 32

texture3D LUNAR_FLOWER_TLAdaptiveAtlasV1Tex
{
    Width = LUNAR_FLOWER_TL_VOXEL_WIDTH;
    Height = LUNAR_FLOWER_TL_VOXEL_HEIGHT;
    Depth = LUNAR_FLOWER_TL_VOXEL_DEPTH;
    Format = RGBA32F;
};

storage3D LUNAR_FLOWER_TLAdaptiveAtlasV1Storage
{
    Texture = LUNAR_FLOWER_TLAdaptiveAtlasV1Tex;
};

sampler3D LUNAR_FLOWER_TLAdaptiveAtlasV1Sampler
{
    Texture = LUNAR_FLOWER_TLAdaptiveAtlasV1Tex;
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

float LUNAR_FLOWER_API_TwinLanternVoxelDepthTolerance(float depth)
{
    return max(0.00001, abs(depth) * LUNAR_FLOWER_TL_VOXEL_DEPTH_SPLIT);
}

bool LUNAR_FLOWER_API_BuildTwinLanternVoxelNode(
    int2 rootCell, int nodeIndex, float2 minimumUv, float2 sizeUv, int level)
{
    float2 uv = minimumUv + sizeUv * 0.5;
    float centerDepth = CAMERA_OBSCURA_LoadDepth(uv);
    float centerValid = CAMERA_OBSCURA_DepthConfidence(centerDepth);
    float3 centerColor = saturate(tex2Dlod(ReShade::BackBuffer, float4(uv, 0.0, 0.0)).rgb);
    float minimumDepth = centerValid > 0.5 ? centerDepth : 1.0;
    float maximumDepth = centerValid > 0.5 ? centerDepth : 0.0;
    float3 minimumColor = centerValid > 0.5 ? centerColor : float3(1.0, 1.0, 1.0);
    float3 maximumColor = centerValid > 0.5 ? centerColor : float3(0.0, 0.0, 0.0);
    float validCount = centerValid;
    float2 inset = min(CAMERA_OBSCURA_PixelSize() * 0.5, sizeUv * 0.25);
    for (int y = 0; y < 2; ++y)
    {
        for (int x = 0; x < 2; ++x)
        {
            float2 cornerUv = minimumUv + inset + float2(x, y) * (sizeUv - inset * 2.0);
            float depth = CAMERA_OBSCURA_LoadDepth(cornerUv);
            float valid = CAMERA_OBSCURA_DepthConfidence(depth);
            validCount += valid;
            if (valid > 0.5)
            {
                float3 color = saturate(tex2Dlod(ReShade::BackBuffer, float4(cornerUv, 0.0, 0.0)).rgb);
                minimumDepth = min(minimumDepth, depth);
                maximumDepth = max(maximumDepth, depth);
                minimumColor = min(minimumColor, color);
                maximumColor = max(maximumColor, color);
            }
        }
    }
    float3 colorRange = max(maximumColor - minimumColor, 0.0.xxx);
    float maximumColorRange = max(max(colorRange.r, colorRange.g), colorRange.b);
    bool mixedCoverage = validCount > 0.5 && validCount < 4.5;
    bool split = level < LUNAR_FLOWER_TL_VOXEL_MAX_LEVEL && validCount > 0.5 &&
        (mixedCoverage || maximumDepth - minimumDepth > LUNAR_FLOWER_API_TwinLanternVoxelDepthTolerance(minimumDepth) ||
         maximumColorRange > LUNAR_FLOWER_TL_VOXEL_COLOR_SPLIT);
    // XY hold sampled depth bounds, Z holds sampled coverage, and W is signed
    // center depth (-1=branch). Bounds retain sloped/mixed surfaces rather than
    // treating one center sample as the whole cell. No coarse RGB is stored.
    float nodeDepth = split ? -1.0 : centerDepth * centerValid;
    float hasSamples = step(0.5, validCount);
    tex3Dstore(LUNAR_FLOWER_TLAdaptiveAtlasV1Storage,
        int3(rootCell, nodeIndex), float4(minimumDepth * hasSamples,
            maximumDepth * hasSamples, validCount * 0.2, nodeDepth));
    return split;
}

void LUNAR_FLOWER_API_BuildTwinLanternVoxelTile(uint3 id)
{
    if (id.x >= LUNAR_FLOWER_TL_VOXEL_WIDTH || id.y >= LUNAR_FLOWER_TL_VOXEL_HEIGHT || id.z > 0)
        return;
    int2 rootCell = int2(id.xy);
    // Every record is cleared each frame, including children no longer needed.
    for (int node = 0; node < LUNAR_FLOWER_TL_VOXEL_DEPTH; ++node)
        tex3Dstore(LUNAR_FLOWER_TLAdaptiveAtlasV1Storage,
            int3(rootCell, node), float4(0.0, 0.0, 0.0, 0.0));
    float2 sizeUv = float2(1.0, 1.0) /
        float2(LUNAR_FLOWER_TL_VOXEL_WIDTH, LUNAR_FLOWER_TL_VOXEL_HEIGHT);
    float2 minimumUv = float2(rootCell) * sizeUv;
    bool splitRoot = LUNAR_FLOWER_API_BuildTwinLanternVoxelNode(rootCell, 0, minimumUv, sizeUv, 0);
    if (splitRoot)
    {
        for (int y = 0; y < 2; ++y)
        {
            for (int x = 0; x < 2; ++x)
            {
                float2 childMinimum = minimumUv + float2(x, y) * sizeUv * 0.5;
                bool splitChild = LUNAR_FLOWER_API_BuildTwinLanternVoxelNode(
                    rootCell, 1 + x + y * 2, childMinimum, sizeUv * 0.5, 1);
                if (splitChild)
                {
                    for (int fy = 0; fy < 2; ++fy)
                    {
                        for (int fx = 0; fx < 2; ++fx)
                        {
                            int fineIndex = 5 + x * 2 + fx + (y * 2 + fy) * 4;
                            LUNAR_FLOWER_API_BuildTwinLanternVoxelNode(rootCell, fineIndex,
                                childMinimum + float2(fx, fy) * sizeUv * 0.25, sizeUv * 0.25, 2);
                        }
                    }
                }
            }
        }
    }
}

[shader("compute")]
void LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(
    uint3 id : SV_DispatchThreadID)
{
    LUNAR_FLOWER_API_BuildTwinLanternVoxelTile(id);
}

float4 LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2 uv, out float level)
{
    float2 dimensions = float2(LUNAR_FLOWER_TL_VOXEL_WIDTH, LUNAR_FLOWER_TL_VOXEL_HEIGHT);
    float2 position = CAMERA_OBSCURA_SaturateUV(uv) * dimensions;
    int2 rootCell = int2(
        min((int)floor(position.x), LUNAR_FLOWER_TL_VOXEL_WIDTH - 1),
        min((int)floor(position.y), LUNAR_FLOWER_TL_VOXEL_HEIGHT - 1));
    float2 local = saturate(position - float2(rootCell));
    float4 node = tex3Dfetch(LUNAR_FLOWER_TLAdaptiveAtlasV1Sampler,
        int3(rootCell, 0));
    level = 0.0;
    if (node.a < 0.0)
    {
        int x = min((int)floor(local.x * 2.0), 1);
        int y = min((int)floor(local.y * 2.0), 1);
        node = tex3Dfetch(LUNAR_FLOWER_TLAdaptiveAtlasV1Sampler,
            int3(rootCell, 1 + x + y * 2));
        level = 1.0;
        if (node.a < 0.0)
        {
            int fx = min((int)floor(local.x * 4.0), 3);
            int fy = min((int)floor(local.y * 4.0), 3);
            node = tex3Dfetch(LUNAR_FLOWER_TLAdaptiveAtlasV1Sampler,
                int3(rootCell, 5 + fx + fy * 4));
            level = 2.0;
        }
    }
    return node;
}

float LUNAR_FLOWER_API_TwinLanternVoxelDetailLevel(float2 uv)
{
    float level = 0.0;
    LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(uv, level);
    return level;
}

float4 LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(float2 uv)
{
    float level = 0.0;
    float4 node = LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(uv, level);
    float depth = CAMERA_OBSCURA_LoadDepth(uv);
    float slack = LUNAR_FLOWER_API_TwinLanternVoxelDepthTolerance(node.x);
    float valid = CAMERA_OBSCURA_DepthConfidence(depth) * step(0.000001, node.z) *
        step(node.x - slack, depth) * step(depth, node.y + slack);
    float3 color = saturate(tex2Dlod(ReShade::BackBuffer, float4(uv, 0.0, 0.0)).rgb);
    return float4(color * valid, valid);
}

LUNAR_FLOWER_API_TwinLanternVoxelEvidence
LUNAR_FLOWER_API_TraceTwinLanternVoxelProxyWithReceiver(
    float2 uv, float directionIndex, float rayLengthPixels, float depthSlope,
    float frontBias, float backThickness, float requestedSteps,
    CAMERA_OBSCURA_SurfaceGuide receiver)
{
    LUNAR_FLOWER_API_TwinLanternVoxelEvidence evidence = LUNAR_FLOWER_API_DefaultTwinLanternVoxelEvidence();
    float safeSteps = clamp(requestedSteps, 1.0, (float)LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS);
    float2 travel = CAMERA_OBSCURA_API_TL45Direction(directionIndex) *
        max(rayLengthPixels, 0.0) * CAMERA_OBSCURA_PixelSize();
    CAMERA_OBSCURA_RayRequest request = CAMERA_OBSCURA_DefaultRayRequest(travel);
    request.ray_length_uv = length(travel);
    request.ray_depth_slope = max(depthSlope, 0.0);
    request.front_bias = max(frontBias, 0.0);
    request.back_thickness = max(backThickness, 0.0);
    request.requested_steps = safeSteps;
    CAMERA_OBSCURA_TraceControls controls = CAMERA_OBSCURA_BuildTraceControls(request);
    CAMERA_OBSCURA_Ray ray = CAMERA_OBSCURA_BuildRayC0(uv, receiver, request, controls);
    // Follow the actual ray budget even when a consumer uses a smaller shared cap.
    int stepCount = min((int)ray.steps, LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS);
    float2 pixel = max(CAMERA_OBSCURA_PixelSize(), float2(0.000001, 0.000001));
    float previousRayDepth = ray.origin_depth;
    if (ray.valid > 0.5 && receiver.valid > 0.5)
    {
        [loop]
        for (int stepIndex = 1; stepIndex <= LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS; ++stepIndex)
        {
            if (stepIndex > stepCount) break;
            float2 requestedUv = ray.origin_uv + ray.step_uv * (float)stepIndex;
            if (requestedUv.x < 0.0 || requestedUv.x > 1.0 || requestedUv.y < 0.0 || requestedUv.y > 1.0)
                break;
            float rayDepth = ray.origin_depth + ray.step_depth * (float)stepIndex;
            float intervalMin = min(previousRayDepth, rayDepth) - ray.front_bias;
            float intervalMax = max(previousRayDepth, rayDepth) + ray.back_thickness;
            previousRayDepth = rayDepth;
            float distancePixels = length((requestedUv - ray.origin_uv) / pixel);
            if (distancePixels <= controls.self_hit_pixels) continue;
            float level = 0.0;
            float4 node = LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(requestedUv, level);
            float coarseSlack = LUNAR_FLOWER_API_TwinLanternVoxelDepthTolerance(node.x);
            float coarseSupport = step(0.000001, node.z) *
                CAMERA_OBSCURA_DepthConfidence(node.x) * CAMERA_OBSCURA_DepthConfidence(node.y) *
                step(intervalMin - coarseSlack, node.y) * step(node.x, intervalMax + coarseSlack);
            if (coarseSupport > 0.5)
            {
                float sceneDepth = CAMERA_OBSCURA_LoadDepth(requestedUv);
                float fineSupport = CAMERA_OBSCURA_DepthConfidence(sceneDepth) *
                    step(intervalMin, sceneDepth) * step(sceneDepth, intervalMax);
                float distanceWeight = saturate(1.0 - distancePixels / max(rayLengthPixels, 0.000001));
                float weight = fineSupport * distanceWeight * CAMERA_OBSCURA_HitConfidence(
                    sceneDepth - rayDepth, ray.front_bias, ray.back_thickness);
                if (weight > 0.000001)
                {
                    // Avoid implicit gradients in the varying traversal loop.
                    evidence.radiance_rgb = saturate(tex2Dlod(
                        ReShade::BackBuffer, float4(requestedUv, 0.0, 0.0)).rgb);
                    evidence.evidence = saturate(weight);
                    evidence.hit = 1.0;
                    evidence.normalized_distance = saturate(distancePixels / max(rayLengthPixels, 0.000001));
                    break;
                }
            }
        }
    }
    return evidence;
}

LUNAR_FLOWER_API_TwinLanternVoxelEvidence
LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(
    float2 uv, float directionIndex, float rayLengthPixels, float depthSlope,
    float frontBias, float backThickness, float requestedSteps)
{
    CAMERA_OBSCURA_SurfaceGuide receiver = CAMERA_OBSCURA_API_BuildTL45Receiver(
        uv, CAMERA_OBSCURA_API_TL45_INPUT_LIVE);
    return LUNAR_FLOWER_API_TraceTwinLanternVoxelProxyWithReceiver(uv, directionIndex,
        rayLengthPixels, depthSlope, frontBias, backThickness, requestedSteps, receiver);
}

#endif // LUNAR_FLOWER_API_TWIN_LANTERN_VOXEL_PROXY_FXH
