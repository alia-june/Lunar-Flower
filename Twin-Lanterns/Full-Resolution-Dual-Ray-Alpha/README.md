# Twin Lanterns: Full Resolution Dual Ray Alpha

Full Resolution Dual Ray Alpha is the experimental high-cost Twin Lanterns
alpha line.
It keeps the accepted evidence, reconstruction, intent, and bounded-composite
contracts while changing the transport representation:

- the raw, horizontal, and vertical transport fields run at full output
  resolution;
- `Opposing Ray Pairs` selects one to four pairs, producing two to eight
  scheduled rays per pixel;
- every scheduled direction retains the independent DDA and parametric-march
  providers;
- a compute pass builds an adaptive current-frame camera-visible surface
  proxy, with `64 x 36` root tiles and up to two subdivision levels;
- each ray may admit proxy radiance under an independent strength and trace
  budget before the existing surface reconstruction and hard composite bounds.

## Truth Boundary

The voxel interface now uses a **bounded adaptive screen/depth surface proxy**.
Tiles split on sampled depth or color variation, up to two levels. A
`64 x 36 x 21` atlas stores a root, four children and sixteen grandchildren per
tile. Z indexes tree nodes rather than 32 uniform depth slices. This is not
world voxelization, a world-space octree or a general sparse-volume allocator.
It contains only current camera-visible evidence and does not recover hidden
or off-screen geometry or create multi-bounce/physically complete GI.

Final lighting validates depth and fetches color at the full-resolution ray
sample. Nodes store sampled depth bounds and coverage, not coarse RGB. This
targets the large square patches reported at high voxel strength.
Read the [online research and implementation rationale](ADAPTIVE_PROXY_RESEARCH.md)
for the source basis, limits and proposed GPU acceptance checks.

This candidate requires ReShade compute shaders, 3D textures, and `storage3D`.
It therefore excludes D3D9 and D3D10 paths that cannot execute the compute
pass. The required language surface is documented in the official [ReShade FX
reference](https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md).

## Status

**Public alpha; static validation only.** Stable 1.4 and
Fidelity Overdrive remain unchanged rollback points. The implementation has
not yet passed a full ReShade compile, GPU frame-time measurement, or live
visual acceptance. Do not describe it as production-ready until those gates
are recorded. The source inventory and scope boundary are preserved in the
[design record](DESIGN_RECORD.md).

## Included Effect

```text
reshade-shaders/Shaders/camera_obscura/effects/
  LUNAR_FLOWER_TwinLanterns_FullResolutionDualRayAlpha.fx
```

Technique label:

```text
Lunar Flower - Twin Lanterns: Full Resolution Dual Ray Alpha
```

## Five-Pass Graph

1. **Voxel Build** clears the bounded node atlas and subdivides detected depth,
   coverage or color changes. Uniform areas stay coarse.
2. **Transport** casts the selected opposing ray pairs at full resolution. Each
   direction evaluates DDA, parametric march, and the voxel proxy, then merges
   only admitted evidence.
3. **Horizontal Resolve** reconstructs compatible full-resolution neighbors.
4. **Vertical Resolve** repeats the evidence-gated resolve on the second axis.
5. **Composite** applies edge fill and rendering intent, then performs the
   unchanged nonnegative channel-room-bounded addition.

No temporal history is retained.

### Screen-depth contour correction candidate

Alpha uses a local surface guide for screen-depth transport, resolve and edge
fill. Each normal derivative chooses the smaller valid one-sided depth change,
so an adjacent foreground/background jump does not automatically tilt a flat
surface's normal. Donor confidence no longer includes a blanket
`1 - edge_risk` fade. Hit confidence, distance weighting and normal compatibility
still control transport; depth/normal agreement still gates reconstruction.
Edge Ink remains a deliberate styling control.

This targets contour gaps observed in Applied Light and Final Image with both
Edge Ink and Voxel Proxy Lighting set to zero. It does not fill every unsupported
pixel or establish hidden-surface lighting. Stable, Fidelity and the eight shared
API 0.1.0 files are unchanged. The new helper is Alpha-local and is not part of
the versioned API package.

The CPU regression compiles extracted shader functions using C++ vector/math
and texture shims. It reproduces the old edge hole, checks the candidate's
same-surface support, rejects cross-depth resolve taps, and checks source and
contribution bounds. Run it with Python and a C++17 compiler:

```powershell
python -B -m unittest discover -s tools -p test_twin_lantern_screen_surface.py -v
```

This is numerical fixture evidence, not native ReShade compilation or GPU visual
acceptance. The changed Alpha still needs a fresh native compile and the same
Applied Light / Source Image / Final Image comparison. In particular, inspect
thin geometry and silhouettes for increased donor contamination or leakage.
Reconstruction guides now sample five depth points instead of three; GPU cost
has not been measured for this candidate.

### Screen-hit refinement correction

The Alpha-local refiner repeats the coarse traversal's self-hit exclusion and
depth-validity checks at every midpoint. A rejected midpoint advances the left
bracket while retaining the known valid right endpoint, so a valid nearby coarse
hit survives. Invalid coarse fallbacks are rejected. Final donor admission also
checks coverage and the self-hit distance. Confidence is recomputed at the
selected point instead of retaining a potentially higher coarse confidence.

CPU fixtures at 1280×720, 2560×1440 and 3840×2160 reproduce the legacy violation,
check both providers in all eight directions, preserve valid nearby donors,
reject invalid-depth midpoints and verify fallback/confidence behavior. The
shared refiner and fixed Stable/Fidelity builds are unchanged. This does not
reject all donors on the receiver's local plane, change the voxel provider, or
establish physically correct GI. Fresh native compilation and in-game comparison
remain pending for this revision.

## Resource And Cost Envelope

Each full-resolution `RGBA16F` working field uses eight bytes per output pixel;
the candidate allocates three. The adaptive `64 x 36 x 21` `RGBA32F` proxy adds
approximately `0.74 MiB` before runtime overhead, compared with `0.56 MiB` for
the previous uniform volume. Leaf depth is stored directly, without 32-bin
quantization.

| Output resolution | One working field | Three working fields |
|---:|---:|---:|
| `2560 x 1440` | `28.13 MiB` | `84.38 MiB` |
| `3840 x 2160` | `63.28 MiB` | `189.84 MiB` |

Transport cost also scales with pair count. Every direction evaluates DDA,
parametric march, and up to the configured voxel trace steps. These figures are
resource arithmetic, not measured GPU frame time. The compute pass assigns one
thread per root tile. Each root samples five points; additional nodes are sampled
only when a parent splits. At most 21 nodes are built per root. All child records
are cleared every frame, so collapsing a tree does not leave stale occupancy.
The worst case performs more build sampling than a uniform scene; adaptive does
not guarantee a frame-time improvement. At voxel strength zero, per-ray voxel
tracing and building are skipped in Final Image view. The build still runs when
voxel diagnostics require it. Source Image, or disabled/zero-strength Final
Image, bypasses lighting calculations while retaining the technique's declared
passes and full-resolution targets. Receiver guides are reused across directions
and final reconstruction. See [performance investigation](PERFORMANCE_NOTES.md)
for verified source-level savings and the in-game timing comparison still needed.

### Native compiler follow-up

A reported native compile failed with X3570/X3511 because the varying ray loops
could reach the shared implicit-gradient color loader. Alpha donor reads now use
explicit base-LOD sampling, and the adaptive atlas has the distinct
`LUNAR_FLOWER_TLAdaptiveAtlasV1*` resource identity. Packaging audits the active
loop call graphs and refuses this known implicit-gradient pattern. See
[compiler investigation](COMPILER_NOTES.md) for the evidence and remaining native
validation. CPU success is not a native compiler pass.

The [November 7 uploaded-build review](reviews/2026-11-07-uploaded-build/REVIEW.md)
identifies the earlier fixed-grid source, preserves its supplied offline
compiler evidence, and compares three voxel failure cases against current code.
The uploaded shaders are not replacements for the current adaptive build.

## Controls

- `Front Surface Bias`: fine drag adjustment in `0.000001` normalized-depth
  steps (100× finer). Zero is valid; positive values widen front-side hit
  admission and confidence weighting. See [Front Bias investigation](FRONT_BIAS_NOTES.md).

- `Indirect Light Strength`: fine drag adjustment and +/- steps of `0.001`
  (0.1 percentage point of nominal strength). The reported 10-30% tuning range
  is `0.100-0.300`; `1.000` is nominal 100%, not the slider maximum. The full
  `0-4` range, default, uniform name and preset scale are preserved.
- `Opposing Ray Pairs`: `1-4` pairs (`2-8` rays). Two pairs use the original
  east/west and north/south cardinal schedule; pairs three and four add the
  two diagonals.
- `Voxel Proxy Lighting`: contribution authority for admitted voxel-proxy
  radiance, with fine drag adjustment and +/- steps of `0.001`. Zero leaves
  only the screen-depth DDA/march providers. Its range and default are preserved.
- `Surface Depth Agreement`: fine drag adjustment and +/- steps of `0.00001`,
  with the existing `0.0001-0.0500` range and default. This is a depth tolerance:
  lower means stricter neighbor rejection. It does not change ray-hit admission
  or directly multiply lighting strength. Larger tolerances admit more
  neighboring light in both reconstruction passes and edge fill, which can
  brighten dark receivers and soften boundaries.
- `Voxel Trace Steps`: `4-32` ray samples per scheduled direction.
  This effect sets the shared ray-builder/DDA step limit to 32 so the full
  voxel step range stays within the configured transport distance. Transport
  Distance remains `4-24` pixels; more steps increase sampling density rather
  than extending that distance. The march provider retains its 16-step limit.
- `Transport Distance`, `Ray Depth Slope`, `Front Surface Bias`, and `Back
  Surface Thickness`: shared ray controls.
- `Fidelity Guard` and `Overdrive`: post-reconstruction intent controls.
- `Maximum Added Light`: unchanged hard per-channel ceiling.

### Depth agreement investigation

The reported clearer image at minimum tolerance is consistent with stricter
rejection of different-depth neighbors. The resolve color is a normalized
weighted mean; the Alpha visible confidence also depends on the admitted
neighbors' evidence. Bright, high-evidence neighbors can therefore raise both
resolved color and confidence as tolerance increases. Edge fill can add a
further positive deficit from newly admitted neighbors.

A CPU experiment executed the actual resolve and Alpha confidence functions,
with Edge Ink at zero, center color `0.05` / evidence `0.2`, and two neighbor
colors `0.8` / evidence `1.0` at depth difference `0.0004`. Normals agreed and
all guides were valid. Before Strength, render intent, edge fill, or ceilings:

| Depth tolerance | Resolved color × visible confidence |
| --- | --- |
| 0.0001 | 0.010000 |
| 0.0005 | 0.141659 |
| 0.0050 | 0.388541 |

With constant color `0.4` and evidence `0.8` in all three samples, that signal
remained `0.32` across six tolerances from `0.0001` to `0.05`. This demonstrates
neighbor admission as a possible source of large brightness changes, rather
than an unconditional gain from the tolerance itself. It is a synthetic CPU
fixture, not proof of the exact cause in Elden Ring or an in-game visual test.
This update changes only the three control annotations; it preserves lighting
math, source preservation, and contribution bounds.

ReShade's [control documentation](https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md)
supports drag controls and `ui_step`. Its
[runtime UI](https://github.com/crosire/reshade/blob/main/source/runtime_gui.cpp)
derives displayed decimal precision from that step. Fine dragging avoids
compressing the useful low range into a short section of a full-range slider;
Ctrl-click allows direct numeric entry.

## Diagnostics

The candidate retains all Fidelity Overdrive views and adds:

15. `Voxel Surface Occupancy`
16. `Voxel Surface Radiance`
17. `Voxel Detail Level` (heatmap of hierarchy levels `0`, `1`, `2`)

`Bound Verification` must remain green. The voxel views must show only the
current camera-visible depth shell; full-volume or off-screen-looking content
is a rejection condition.
The radiance diagnostic shows fine-resolution color on proxy-supported surfaces.
Detail Level should vary with scene complexity. Small features missed by the center/corner
samples and refinement-level changes under camera motion remain acceptance risks.

## Public API

This Alpha carries the shared [Twin Lanterns Public API 0.1.0](../API/0.1.0/)
without changing its eight common source files. It also exposes the separate
`LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh` extension. The voxel extension is
experimental and excluded from the shared 0.1.0 stability promise until a
later promotion decision.

## Install

1. Use a target running a compute-capable ReShade backend.
2. Merge only this build's `reshade-shaders` directory into the installation.
   Keep the repository and extracted release folders outside all ReShade effect
   search paths. Installing both the repository tree and its flattened shader
   folder makes ReShade discover Alpha twice.
3. Keep the installation's known-good `ReShade.fxh`.
4. Reload effects and enable `Lunar Flower - Twin Lanterns: Full Resolution
   Dual Ray Alpha`.
5. If the effect does not compile, disable it and preserve the complete ReShade
   error log.

### Repair a duplicate installation

Close the game. With Python 3.9 or newer installed, open a terminal in the
downloaded repository or the single-build package, outside the game's shader
search paths. Preview the repair:

```powershell
py -3 tools/install_twin_lantern_alpha.py --game-dir 'Y:\SteamLibrary\steamapps\common\ELDEN RING\Game'
```

Apply it:

```powershell
py -3 tools/install_twin_lantern_alpha.py --game-dir 'Y:\SteamLibrary\steamapps\common\ELDEN RING\Game' --apply
```

The tool backs up duplicate Alpha effects, the obsolete
`LUNAR_FLOWER_TwinLanterns_FullResolutionDualRay.fx`, and any replaced includes
under `<game>/Lunar-Flower-backups/`, outside `reshade-shaders`. It then installs
one current Alpha at
`reshade-shaders/Shaders/camera_obscura/effects/`. Other effects, `ReShade.fxh`,
presets and `ReShade.ini` are preserved. Repeating the repair is a no-op when
the installation is current. Scope is the standard `reshade-shaders/Shaders`
tree; separately configured effect search directories need separate inspection.

Reload ReShade, select **Lunar Flower - Twin Lanterns: Full Resolution Dual Ray
Alpha**, and save the preset without the obsolete non-Alpha technique.
Compiler X4000 warnings are a separate issue; removing duplicate files does
not resolve those warnings.

To build a single-effect ZIP from the repository:

```powershell
py -3 tools/package_twin_lantern_alpha.py --output ../Twin-Lanterns-Alpha.zip
```

Extract it outside shader search paths, then run the repair command above.

## Acceptance Gates

1. Clean ReShade compile on the target backend.
2. `Voxel Surface Occupancy` contains only visible depth-shell cells.
3. Pair counts `1-4` change scheduled coverage without invalid reads.
4. `Voxel Proxy Lighting = 0` removes voxel influence.
5. `Bound Verification` remains green under maximum ray, voxel, fidelity, and
   overdrive settings.
6. No cross-surface carry at silhouettes or thin geometry.
7. Frame time is recorded at the target resolution for every pair count.
8. Human visual acceptance is recorded in `LIVE_RESULT_TEMPLATE.csv`.

## Rollback

Disable this technique and remove its effect/API files. Return to
[Fidelity Overdrive](../Fidelity-Overdrive/) or [Stable 1.4](../Stable-1.4/)
without modifying either baseline.

## License

This candidate is distributed under the repository's
[MIT License](../../LICENSE). Preserve the copyright and license notice with
copies or substantial portions.
