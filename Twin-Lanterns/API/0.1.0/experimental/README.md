# Experimental Extension

`LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh` is copied byte-for-byte from Full
Resolution Dual Ray Alpha. It exposes the Alpha's compute-built `64 x 36 x 32`
current-frame view-frustum voxel-radiance proxy.

This file is distributed for inspection and Alpha integration, but it is not
part of the shared API 0.1.0 stability promise. It expects the shared Camera
Obscura API and ReShade bindings to be loaded first, requires compute and 3D
storage support, and may change before promotion.

The proxy stores only the color and depth shell visible to the camera. It does
not provide world voxelization, hidden or off-screen geometry, temporal
persistence, multi-bounce transport, or complete global illumination.
