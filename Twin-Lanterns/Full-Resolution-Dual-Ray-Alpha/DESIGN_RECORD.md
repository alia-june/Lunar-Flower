# Full Resolution Dual Ray Alpha Design Record

## Request And Scope

User-approved target: full-resolution transport, variable rays, dual ray
casting, and a view-frustum voxel-radiance proxy. The interpretation recorded
for this generated candidate is:

- variable rays means `1-4` opposing direction pairs (`2-8` rays);
- dual-provider casting retains DDA and parametric march for every direction;
- voxel lighting means a current-frame camera-visible depth shell, not an
  externally supplied or world-complete voxel field;
- Stable 1.4 and Fidelity Overdrive remain unchanged.

## Source Inventory

| Identifier | Location | Type | Authority/status | Relevance |
|---|---|---|---|---|
| Fidelity Overdrive effect | `../Fidelity-Overdrive/reshade-shaders/Shaders/camera_obscura/effects/LUNAR_FLOWER_TwinLanterns_FidelityOverdrive.fx` | ReShade FX | Current public candidate; parent source | Starting effect and intent path |
| Eight Camera Obscura files | `reshade-shaders/Shaders/camera_obscura/api/` and `header/` | ReShade FX includes | Source-identical inherited contracts | Transport, reconstruction, bounds, capability, and traversal |
| Voxel proxy API | `reshade-shaders/Shaders/camera_obscura/api/LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh` | Generated ReShade FX | New, statically validated, live-uncompiled | 3D proxy build, lookup, and trace |
| ReShade FX reference | `https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md` | External technical reference | Current official language documentation | Compute, texture3D, storage3D, dispatch, fetch/store syntax |
| Twin Lantern Moonshot | Workbench source research outside this public tree | Research document | Historical/deferred design evidence | Separates screen-space core from frustum/external voxel extensions |

## Change Boundary

The candidate adds one new API and one distinct public effect. The inherited
eight Camera Obscura files are byte-identical to Fidelity Overdrive. No existing
public build is edited by the implementation.

## Alpha-local Screen Surface Candidate

The contour correction adds `LUNAR_FLOWER_TwinLanternScreenSurface.fxh` outside
the shared API contract. It selects depth-consistent one-sided derivatives for
proxy normals, removes the donor-wide edge-risk attenuation, and uses that guide
through screen transport, resolve and edge fill. Existing DDA/march traversal
and the bounded composite remain shared. This is a tested CPU candidate requiring
fresh native compile and visual validation, not a recovered historical design.

The following Alpha-local refinement correction reapplies self-hit distance,
coverage and valid-depth conditions, preserves a valid coarse fallback when
midpoints are rejected, and recomputes confidence at the selected hit. Final
screen donor admission repeats the distance guard. Shared API source identity is
preserved. CPU fixtures cover both providers/eight directions at three output
resolutions; native behavior and the remaining coplanar-donor question are not
certified by those fixtures.

## Adaptive Proxy Candidate

The uniform 32-bin volume is superseded by a bounded adaptive screen/depth
hierarchy. Its fixed 64×36×21 RGBA32F atlas holds depth bounds, coverage and
branch/center-depth metadata. Two optional subdivision levels are built on
detected depth, coverage or color variation. Final donor color comes from a
full-resolution, depth-validated sample. This is not a world-space octree or
dynamic sparse-volume allocator. See [online research and candidate validation](ADAPTIVE_PROXY_RESEARCH.md).
The experimental API copy, hash inventory and declaration reference track the
new storage interpretation; the eight shared API sources are unchanged.

## Validation State

- Static candidate checks: see `STATIC_VALIDATION_RESULTS.json`.
- Existing Stable/Fidelity publication checks remain separate.
- Full ReShade compile: pending.
- Live voxel occupancy/trace correctness: pending.
- GPU frame time: pending.
- Human visual acceptance: pending.

Static checks establish structure and declared invariants only. They do not
establish runtime correctness or performance.
