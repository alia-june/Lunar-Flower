# Twin Lanterns downloads

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

## Alpha performance candidate

[Download the single-effect ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/fix/alpha-inactive-work-and-guides/downloads/Twin-Lanterns-Alpha-performance-candidate.zip).

This package contains the corrected performance candidate, with explicit-LOD
ray sampling and versioned adaptive atlas resources. It replaces the earlier
archive that failed with X3570/X3511 in ReShade. It contains exactly one Alpha
`.fx` file, its required includes, installation repair tool and compiler notes.
Native compilation, visual acceptance and GPU performance
are still pending for this candidate. It is on the review branch, not main.

Fine tuning update: Indirect Light Strength and Voxel Proxy Lighting use drag
controls with `0.001` steps; Surface Depth Agreement uses `0.00001` steps.
For 10-30% nominal strength, use `0.100-0.300`. Existing preset values, ranges,
defaults and lighting math are preserved. The included README records the
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
8c0dd96ed38d6c990667de7f32dc6beb76737670223869499d5aac7b41d84a76
```

The adjacent `.zip.sha256` file records the same archive checksum. It verifies
download identity, not native shader correctness or GPU performance.
