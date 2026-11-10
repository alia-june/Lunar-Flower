# Twin Lanterns downloads

## Crystal Spider - Beta

**[Download Crystal Spider - Beta — ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Crystal-Spider-Beta.zip)** · [Lazara](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package)

Camera-dependent tile correction: full-resolution depth now controls donor
admission; sparse voxel probes cannot mask valid light. The atlas builds only
for diagnostics. Defaults are unchanged. [Fix details and retest steps](../Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/TILE_ARTIFACT_FIX_NOTES.md).

### Lazara + Twin Lanterns

[![Elden Ring with Lazara + Twin Lanterns](../Twin-Lanterns/assets/twin-lanterns-gallery-04.png)](../Twin-Lanterns/assets/twin-lanterns-gallery-04.png)

*Elden Ring — Lazara + Twin Lanterns.* User-supplied capture, preserved at its
original 2560×1440 resolution. Click the image to view the full frame.

The Alpha defaults now match all 24 Twin Lanterns values in the corrected
user-supplied `Lazara.ini` section. Seven defaults changed: Strength `0.272`,
Front Bias `0.000052`, Ray Pairs `1`, Voxel Lighting `1`, Voxel Steps `24`,
Fade Amount `0.355`, and Softening `1`. Those defaults are preserved in the tile
correction; other effects are unchanged. The ZIP includes `DEFAULTS_FROM_PRESET.json` with the exact
values and source hash; no other preset sections are copied into it.

These are defaults for new/reset Alpha controls; saved preset values remain
as saved. Start `0.005`, End `0.05`, and softening Radius `2 px` also match the
provided preset. Zero still disables fade or softening. The fade scales final
bounded contribution, and the source image is not blurred. Native compile/live
acceptance remain separate from source, CPU and package checks.

Crystal Spider - Beta is the download name for the Twin Lanterns Alpha build.
The rebrand retains its shader identity and saved preset compatibility.

This package contains the corrected performance candidate, with explicit-LOD
ray sampling and versioned adaptive atlas resources. It replaces the earlier
archive that failed with X3570/X3511 in ReShade. It contains exactly one Alpha
`.fx` file, its required includes, installation repair tool and compiler notes.
Native compilation, visual acceptance and GPU performance
are still pending for this candidate. The package is available on `main`.

Fine tuning update: Indirect Light Strength and Voxel Proxy Lighting use drag
controls with `0.001` steps; Surface Depth Agreement uses `0.00001` steps.
For 10-30% nominal strength, use `0.100-0.300`. Existing preset values, ranges,
lighting math is preserved. Current defaults are recorded in the profile above.
The included README records the
depth-agreement brightness investigation and its CPU-only limits.

Alpha Front Surface Bias now has `0.000001` drag steps (100× finer). Exact zero
and stored preset values remain unchanged. The tooltip and included
`FRONT_BIAS_NOTES.md` explain normalized-depth admission and confidence weighting;
this control does not move the ray origin or replace pixel self-hit rejection.

1. Close the game and extract the ZIP outside ReShade's shader search folders.
2. Merge only its `reshade-shaders` directory into the existing game installation.
   The extracted folder also contains the backup-preserving repair tool; see its
   README if duplicate copies need cleanup.
3. Reload ReShade and select the Alpha technique. Compare the entire technique
   off, Output View = Source Image, and Final Image with voxel strength zero.

Do not copy the entire repository or a second extracted build tree into the
shader search path. The ZIP already includes the complete selected build.

SHA-256:

```text
b146fafde599a46bccb91e0cebb49a5eb3e0a4161e316b3102c1df1419a531c8
```

The adjacent `.zip.sha256` file records the same archive checksum. It verifies
download identity, not native shader correctness or GPU performance.

## Stable and Fidelity fine controls

| Build | Single-effect package |
| --- | --- |
| Stable 1.4 | [Download ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/fix/alpha-inactive-work-and-guides/downloads/Twin-Lanterns-Stable-1.4-fine-controls.zip) |
| Fidelity Overdrive | [Download ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/fix/alpha-inactive-work-and-guides/downloads/Twin-Lanterns-Fidelity-Overdrive-fine-controls.zip) |

Each ZIP contains exactly one effect, its matching includes, README, license
and lineage records. Merge the selected package's `reshade-shaders` folder
into the game installation; retain its known-good `ReShade.fxh`. Install one
selected build. The backport changes only Strength and Depth Agreement UI
annotations, with `0.001` and `0.00001` fine drag steps respectively. Names,
defaults, ranges, preset scales and rendering math are preserved.

The adjacent `.zip.sha256` files identify the archives. These packages are
on the review branch. CPU/source validation does not establish a fresh native
ReShade compile or visual acceptance of either backport.

## Fog Guard V2 test build for Lazara

[Download Fog Guard V2](https://raw.githubusercontent.com/alia-june/Lunar-Flower/fix/fog-guard-v2-delivery/downloads/Lazara-Fog-Guard-V2.zip).

Use **Fog Guard (Capture) → Crystal Spider/other effects → Fog Guard (Restore)**,
and set **Outside Shade to 0** in existing presets. This is a separate
single-effect Lazara test package; the Crystal Spider package is unchanged.
[Installation, patch provenance and validation](../development/fog-guard-v2/README.md).
Native compilation and target-game acceptance remain pending.
