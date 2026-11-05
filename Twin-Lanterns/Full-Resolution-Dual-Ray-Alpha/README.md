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
- a compute pass builds a `64 x 36 x 32` current-frame view-frustum
  voxel-radiance proxy from visible color and depth;
- each ray may admit proxy radiance under an independent strength and trace
  budget before the existing surface reconstruction and hard composite bounds.

## Truth Boundary

The voxel field is a **camera-visible view-frustum proxy**. It contains one
depth-derived occupied cell per proxy column and the color visible at that
screen location in the current frame. It is not world voxelization, does not
contain hidden or off-screen geometry, and does not create multi-bounce or
physically complete global illumination.

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

1. **Voxel Build** writes the current visible depth shell and radiance into the
   `64 x 36 x 32` `RGBA16F` proxy.
2. **Transport** casts the selected opposing ray pairs at full resolution. Each
   direction evaluates DDA, parametric march, and the voxel proxy, then merges
   only admitted evidence.
3. **Horizontal Resolve** reconstructs compatible full-resolution neighbors.
4. **Vertical Resolve** repeats the evidence-gated resolve on the second axis.
5. **Composite** applies edge fill and rendering intent, then performs the
   unchanged nonnegative channel-room-bounded addition.

No temporal history is retained.

## Resource And Cost Envelope

Each full-resolution `RGBA16F` working field uses eight bytes per output pixel;
the candidate allocates three. The `64 x 36 x 32` voxel proxy adds approximately
`0.56 MiB` before runtime overhead.

| Output resolution | One working field | Three working fields |
|---:|---:|---:|
| `2560 x 1440` | `28.13 MiB` | `84.38 MiB` |
| `3840 x 2160` | `63.28 MiB` | `189.84 MiB` |

Transport cost also scales with pair count. Every direction evaluates DDA,
parametric march, and up to the configured voxel trace steps. These figures are
resource arithmetic, not measured GPU frame time.

## Controls

- `Opposing Ray Pairs`: `1-4` pairs (`2-8` rays). Two pairs use the original
  east/west and north/south cardinal schedule; pairs three and four add the
  two diagonals.
- `Voxel Proxy Lighting`: contribution authority for admitted voxel-proxy
  radiance. Zero leaves only the screen-depth DDA/march providers.
- `Voxel Trace Steps`: `4-32` proxy cells tested per scheduled direction.
  This effect sets the shared ray-builder/DDA step limit to 32 so the full
  voxel step range stays within the configured transport distance. Transport
  Distance remains `4-24` pixels; more steps increase sampling density rather
  than extending that distance. The march provider retains its 16-step limit.
- `Transport Distance`, `Ray Depth Slope`, `Front Surface Bias`, and `Back
  Surface Thickness`: shared ray controls.
- `Fidelity Guard` and `Overdrive`: post-reconstruction intent controls.
- `Maximum Added Light`: unchanged hard per-channel ceiling.

## Diagnostics

The candidate retains all Fidelity Overdrive views and adds:

15. `Voxel Surface Occupancy`
16. `Voxel Surface Radiance`

`Bound Verification` must remain green. The voxel views must show only the
current camera-visible depth shell; full-volume or off-screen-looking content
is a rejection condition.

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
