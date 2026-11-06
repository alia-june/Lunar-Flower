# Adaptive surface proxy: online research and candidate

Research date: 2026-11-05. This is an implementation rationale and bounded
validation record, not GPU acceptance or a claim of physically complete GI.

## Primary sources consulted online

1. [Official ReShade FX reference](https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md):
   texture/storage declarations, RGBA32F, compute dispatch and exact texture
   fetch/store operations. These are the existing runtime's relevant primitives.
2. [AMD FidelityFX SSSR](https://github.com/GPUOpen-Effects/FidelityFX-SSSR/blob/master/readme.md)
   and its [hierarchical traversal/validation source](https://github.com/GPUOpen-Effects/FidelityFX-SSSR/blob/master/ffx-sssr/ffx_sssr.h):
   hierarchy-guided screen-space traversal separates coarse search from hit
   validation; its validation also rejects trivial near-origin/background hits.
   It is a reflection implementation with inputs Twin Lanterns does not have,
   including world-space normals and view-space reconstruction. It is not a GI
   specification or a drop-in replacement for this effect.
3. [NVIDIA GVDB](https://github.com/NVIDIA/gvdb-voxels/blob/master/README.md):
   sparse volumetric storage and dynamic GPU topology are explicit library
   facilities, with CUDA and other integration requirements. Subdivision is not
   an automatic property of allocating a texture3D. That library is not being
   integrated into ReShade.

The candidate is an original bounded implementation using the general ideas
above. No upstream implementation files or runtime libraries are imported.

## Diagnosis

The former 64×36×32 uniform volume stored one color/depth sample per screen
column. At 1440p each column covered 40×40 output pixels; at 4K it covered
60×60. Integer cell reads could reuse one color over that footprint. The usual
24-pixel ray reach could also remain inside its receiver's column. Raising
voxel strength made that coarse representation more visible.

More dense resolution alone would scale allocation/build work everywhere.
Ordinary trilinear color filtering would not establish that samples on opposite
sides of a depth discontinuity belong together.

## Chosen representation

Each of the 64×36 root tiles owns a fixed 21-record budget: one root, four
children and sixteen grandchildren. The root/children split on mixed valid/sky
coverage, depth-relative variation or RGB range among a center and four inset
corner samples. Uniform regions stop early. Two subdivision levels are the
hard maximum; the candidate is not an unbounded allocator.

The atlas is 64×36×21 RGBA32F: **0.73828125 MiB**, excluding runtime overhead.
The old atlas used 0.5625 MiB. Memory allocation remains fixed; subdivision
adapts sampling and lookup depth, not GPU memory allocation.

Record layout:

| Component | Meaning |
|---|---|
| X | Minimum valid sampled depth |
| Y | Maximum valid sampled depth |
| Z | Valid sample fraction, 0..1 |
| W | Center depth for a leaf; -1 for an internal branch |

An empty record is zero. A leaf can have an invalid center but valid sampled
corners; its bounds/coverage can still nominate a candidate for fine validation.
The texture's Z coordinate is a node index, not a depth bin. The historical
`VoxelRadianceTex` resource name is retained, but **no coarse RGB is stored**.
This representation is a screen/depth quadtree, not a world-space octree.

One compute thread owns a root and its descendants, avoiding cross-thread
allocation/atomics. Every frame clears all 21 slots before rebuilding that root.
Dispatch uses 8×8×1 threads per group and 8×5×1 groups, with out-of-bounds guards.
No stale child is permitted when a formerly complex tile becomes uniform.

## Lighting lookup

Lookup descends at most two levels. The leaf's sampled depth interval nominates
ray candidates; it never authorizes the final color by itself. Each candidate
must pass full-resolution depth validity and the ray's bias/thickness interval,
and must be farther than the self-hit exclusion. Color is then fetched from
the current full-resolution back buffer at that accepted UV. This removes the
specific mechanism of applying one stored cell color across a large rectangle.

The tracer follows the actual shared ray step budget, including consumers whose
shared cap is 24 rather than Alpha's 32. Voxel strength zero skips the per-ray
proxy trace. Following the reported Elden Ring slowdown, the effect also skips
the build at zero voxel strength in Final Image view. Voxel diagnostics still
request a current build. See [performance follow-up](PERFORMANCE_NOTES.md).

`Voxel Detail Level` exposes levels 0, 1 and 2. `Voxel Surface Occupancy` and
`Voxel Surface Radiance` show depth-bounds-validated visible surfaces and their
fine-resolution color. Existing diagnostic indices are preserved; the new view
is appended.

## Evidence and limitations

CPU fixtures compile the actual shader functions with explicit vector/intrinsic
and texture shims. They exercise:

- uniform scenes remaining at level zero;
- depth, color, near-depth and sky boundaries triggering refinement;
- distinct leaf indexing and sampled depth intervals on sloped surfaces;
- worst-case bounded record counts and safe dispatch/lookup boundaries;
- clearing child records after a refined tile collapses;
- fine donor color independent of node metadata;
- rejection of coarse-supported but fine-depth-incompatible candidates;
- self-distance, sky rejection and exact travel limits under 24/32 shared caps.

These are not native ReShade compilation, GPU parity, synchronization or timing
measurements. The 5-point node classification is not conservative full-resolution
voxelization: small features missed by those samples can still lose support.
Two levels cannot represent arbitrary detail. Leaf changes can pop during motion;
there is no temporal history/hysteresis. All providers still originate from the
same current framebuffer/depth map. Coplanar donor reinforcement, color-space
assumptions and absence of hidden geometry remain separate limitations.

Build cost is scene-dependent. A uniform root samples five positions. A maximally
split root builds 21 nodes and samples up to 105 positions; all 21 slots are
cleared in either case. The previous volume sampled the same column once per
depth slice. This arithmetic does not establish that the new GPU pass is faster.

## In-game acceptance sequence

1. Replace the Alpha includes and effect together; preserve a known-good rollback.
2. Capture a fresh native compile log, including warnings.
3. With Edge Ink=0, compare voxel strength 0, 0.35 and 1 using a fixed camera.
4. Check Final Image and Applied Light for square patches. Check Detail Level
   for refinement at actual depth/color boundaries rather than uniform noise.
5. Move across tile boundaries and inspect sky silhouettes, thin objects, sloped
   surfaces and geometry behind the character for leakage or level popping.
6. Record GPU frame time in both a uniform and a detailed scene at the target
   resolution. Bound Verification must remain green.

Only the experimental extension changes its storage contract. The eight shared
API 0.1.0 files and the fixed Stable/Fidelity builds remain unchanged.
