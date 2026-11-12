# Twin Lanterns — No Voxel

A separate full-resolution Twin Lanterns build using screen-space light only.
Each scheduled direction combines DDA traversal and a parametric march. One to
four opposing pairs provide two to eight directions. Both providers retain the
32-step maximum, guarded hit refinement and explicit-LOD sampling.

Voxel lighting, its controls and diagnostic views, the compute pass and the
3D atlas are removed from this build. Its four passes are transport, horizontal
resolve, vertical resolve and composite. Three full-resolution RGBA16F working
textures remain: approximately 47.5 MiB at 1080p or 84.4 MiB at 1440p, excluding
ReShade/framework resources. This remains a full-resolution effect; an FPS gain
has not been measured.

Depth-aware light fade, light-only softening, edge fill, fidelity guard,
overdrive and the bounded source-preserving composite are retained. The 22
remaining controls keep the selected Crystal Spider defaults, including
Strength `0.272`, Front Bias `0.000052`, Ray Pairs `1`, Fade Amount `0.355`, and
Light Softening `1`. Depth Fade Mask is now Output View 14.

## Install

1. Extract `Twin-Lanterns-No-Voxel.zip` outside ReShade's shader search folders.
2. Merge only its `reshade-shaders` directory into the game installation. Keep
   the installed `ReShade.fxh`.
3. Select the included `Twin-Lanterns-No-Voxel.ini` for the bundled Fog Guard V2
   setup: **Fog Guard Capture → Twin Lanterns No Voxel → Fog Guard Restore**.
4. Disable the existing Crystal Spider/Alpha technique when comparing. The new
   effect appears as **Lunar Flower - Twin Lanterns: No Voxel**. Its filename,
   control names, working textures and include directory have independent
   identities, so installing it does not overwrite Crystal Spider.

For a standalone test, enable only Twin Lanterns No Voxel. Fog Guard is the
same component supplied with Crystal Spider and can be left disabled. If it is
already installed, merge the bundled identical version into its existing path;
do not create another nested copy. For an existing Lazara/custom preset, retain
that preset and add the new technique where Crystal Spider was used. The new
controls start with their shader defaults; old Alpha control names do not map
automatically.

## Verification and limits

Source/package checks and C++ CPU fixtures compare the actual new shader
functions with the existing build at voxel strength zero, exercise source-only
bypass, invalid depth, all pair counts, light bounds and depth fade, and check
that loop-reachable sampling remains derivative-free. CPU texture/vector shims
are not native ReShade compilation or GPU validation. Native compilation,
in-game appearance and performance still require testing in ReShade.

`SOURCE_LINEAGE.json` records the parent revision and include identities.
`DEFAULTS.json` records the remaining default controls. The shared API includes
are preserved. The existing Crystal Spider downloads are unchanged.

Software licensing follows the repository MIT license and retained notices.
Fog Guard's component notices and provenance are included in the package.
