# Experimental Extension

`LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh` is copied byte-for-byte from Full
Resolution Dual Ray Alpha. It exposes a bounded adaptive camera-visible surface
hierarchy with `64 x 36` root tiles and two optional subdivision levels. Its
`64 x 36 x 21` `RGBA32F` atlas uses Z for tree nodes, not uniform depth bins.
XY store sampled depth bounds, Z stores coverage, and W stores signed center
depth (-1 marks a branch). Final donor color is fetched at a full-resolution,
depth-validated ray sample. No coarse donor RGB is stored.

This file is distributed for inspection and Alpha integration, but it is not
part of the shared API 0.1.0 stability promise. It expects the shared Camera
Obscura API and ReShade bindings to be loaded first, requires compute and 3D
storage support, and may change before promotion.

The proxy stores only the color and depth shell visible to the camera. It does
not provide world voxelization, hidden or off-screen geometry, temporal
persistence, multi-bounce transport, or complete global illumination.
This is a bounded screen/depth quadtree, not a world-space octree or general
dynamic sparse-volume allocator. The old depth-bin storage interpretation has
changed under the experimental boundary; consumers must use matching source,
compute dispatch (`8 x 8 x 1` threads, `8 x 5 x 1` groups) and decode functions.
The atlas resources use the `LUNAR_FLOWER_TLAdaptiveAtlasV1*` identity to avoid
aliasing older volume layouts. Donor color reads use explicit LOD zero so the
trace can be called inside varying loops without implicit-gradient unrolling.
