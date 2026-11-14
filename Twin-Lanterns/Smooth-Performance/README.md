# Kriespinne — Smooth Performance Candidate 1

[Download performance candidate](https://raw.githubusercontent.com/alia-june/Lunar-Flower/refs/heads/perf/phantom-smooth-normals/downloads/Kriespinne-Smooth-Performance-Candidate-1.zip)
· [SHA-256](../../downloads/Kriespinne-Smooth-Performance-Candidate-1.zip.sha256)

A separate Phantom Brigade performance experiment for the reported 20–40 FPS
loss with Twin Lanterns alone. The approved Phantom Brigade Special download
is unchanged. This candidate preserves smooth weighted sampling and all eight
directions, and caches donor normals once per frame.

## Install and compare

1. Extract outside shader search paths, then copy only `reshade-shaders` into
   the game. Keep the installed `ReShade.fxh`. This uses a separate
   `lunar_flower_smooth_perf` folder and effect identity.
2. Use the supplied presets. They enable only **Lunar Flower - Twin Lanterns:
   Smooth Performance Candidate 1**. Keep the other Twin Lanterns techniques
   and the other effects off for the first comparison.
3. Keep the same resolution, camera, depth selection, persistence/capture,
   inversion and scaling. Preserve any preset-local `RESHADE_DEPTH_*`
   definitions from your working preset in each comparison preset.
4. Start with **02 Cached Dual16**. Compare its Final Image and Applied Light
   against **01 Uncached Dual16**. Use Final Image for ReShade timing/FPS.
   If the cached dual option is still expensive, try **03 Cached March16**.

| Preset | Directions | Samples per direction | Donor normal calculation |
|---|---:|---|---|
| 01 Uncached Dual16 | 8 mixed | DDA 16 + March 16 | Rebuilt per admitted sample; control |
| 02 Cached Dual16 | 8 mixed | DDA 16 + March 16 | Current-frame full-resolution cache |
| 03 Cached March16 | 8 mixed | March 16 | Current-frame full-resolution cache |

All retain 24-pixel reach, smooth admission, original normal regularization,
the selected light/reconstruction settings and disabled bounce. Preset 03 halves
the scheduled traversal samples from 256 to 128 per pixel. It removes one
provider's sampling locations and may change coverage; it is not identical
quality at half cost. There is no temporal history or voxel lighting.

## Why the original was costly

The smooth build stopped terminating at the first hit. At eight directions and
two 16-step providers, it schedules 256 depth samples per output pixel. Every
admitted donor rebuilt its normal using four additional neighboring depth reads,
then could read source color. This work still occurs with bounce disabled.

The candidate adds a full-resolution RGBA16F normal/validity field and one
prepass. Valid pixels require five depth reads in that prepass; invalid-depth
pixels require one. Donor loops read this field rather than rebuilding normals.
The actual donor depth, invalid-depth rejection, self-hit rejection, smooth
admission, distance loss, source color and final contribution caps are retained.
Receiver/reconstruction guides still use the original calculation.

Cached mode has six working fields and seven passes versus five fields and six
passes for the uncached control. Its added target uses 28.125 MiB at 2560×1440
or 63.28125 MiB at 3840×2160, plus runtime overhead. Texture access and repeated
normal math fall; this is not a promise that total GPU time falls proportionally.

## Checks and limits

Actual-function CPU fixtures use a full-resolution point depth grid, evaluate
the real prepass at requested pixel centers, and store its RGBA16F values once
per modeled frame. They do not render or time a complete game frame.

For one dense, supported eight-direction fixture at zero depth slope:

| Configuration | Transport depth reads | Normal-field reads | Source-color reads |
|---|---:|---:|---:|
| Original / uncached dual | 1269 | 0 | 240 |
| Cached dual | 261 | 252 | 240 |
| Cached March only | 133 | 128 | 120 |

These exclude the separate normal prepass (up to five depth reads per pixel),
field writes and later reconstruction/composition. The ordinary-default fixture
is also recorded in `VALIDATION.json`; admission and actual work depend on the
scene. These are sampling counts, not measured GPU time or predicted FPS.

The largest cached-versus-matched-uncached weighted-light error across the tested
scenes was about 0.0000221. The tests cover half-storage error, continuity, depth
endpoints, point-grid orientation, source preservation and output bounds.
RGBA16F rounding and snapping normals to output-pixel centers can change edge
behavior, especially with different depth-buffer dimensions or non-unit depth
coordinate transforms. Compare against the uncached control in your game.

All three configurations pass ReShade 6.7.3 FX parsing and SM5 HLSL generation.
FXC/DXC/driver compilation, Phantom Brigade visuals and actual FPS recovery
have not been verified here. `VALIDATION.json` records the checks and limits.

Bundled source is derived from Lunar Flower's own approved build. No external
shader code, screenshots, personal presets, chat logs or credentials are
included. The Lunar Flower license is retained.
