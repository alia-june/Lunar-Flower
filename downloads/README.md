# Alpha performance candidate download

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
57a2ee5ed83494564eebcbd204ac32619d19a3c94e2b8faf9ab849c2d64369fa
```

The adjacent `.zip.sha256` file records the same archive checksum. It verifies
download identity, not native shader correctness or GPU performance.
