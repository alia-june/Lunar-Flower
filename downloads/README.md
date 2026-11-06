# Alpha performance candidate download

[Download the single-effect ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/fix/alpha-inactive-work-and-guides/downloads/Twin-Lanterns-Alpha-performance-candidate.zip).

This package contains the shader/include bytes from performance candidate
`1d7f0dd`, with exactly one Alpha `.fx` file, its required includes, installation
repair tool and notes. Native compilation, visual acceptance and GPU performance
are still pending for this candidate. It is on the review branch, not main.

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
4eedfc6056f96aa5e7829e377c2bd91bf5a639309c012fac986392a50769f903
```

The adjacent `.zip.sha256` file records the same archive checksum. It verifies
download identity, not native shader correctness or GPU performance.
