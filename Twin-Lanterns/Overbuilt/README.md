# Kriegspinne — Overbuilt

**Slow. A real laser light show.**

[Download Kriegspinne — Overbuilt](https://raw.githubusercontent.com/alia-june/Lunar-Flower/refs/heads/release/kriegspinne-overbuilt/downloads/Kriegspinne-Overbuilt.zip)
· [SHA-256](../../downloads/Kriegspinne-Overbuilt.zip.sha256)

Twin Lanterns with smooth weighted sampling, eight mixed directions, original
normals, and no voxel lighting or bounce. The supplied stack combines it with
GoldenWeave Redux, GI Color Bleed, Lazara, and Fog Guard. The owner reports
smooth sampling gives the superior result in their game.

## Install

1. If your working stack is already installed, keep it and continue at step 3.
   Otherwise, get the supporting shaders from the original
   [Lazara ReShade Revival Package](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package).
   Install that package's shaders for the full stack. Its code and assets are
   not redistributed here.
2. Install [Fog Guard V2 Capture + Restore](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Lazara-Fog-Guard-V2.zip)
   over Lazara's older single-pass Fog Guard at the same shader path. Copy only
   that ZIP's `reshade-shaders` folder; do not keep a duplicate effect file.
3. Extract this ZIP outside shader search paths. Copy its `reshade-shaders`
   folder into the game. Keep your installed `ReShade.fxh`.
   If Sampling Experiment is already installed, replace its
   `lunar_flower_sampling_experiment` folder; do not install a second copy.
4. Select **Kriegspinne-Overbuilt.ini** for the complete enabled stack, or
   **Kriegspinne-Overbuilt-Twin-Lanterns-Only.ini** for our shader alone.
5. Keep the game's working depth-buffer selection, persistence/capture,
   inversion and scaling. The presets set the Twin Lanterns experiment
   switches automatically. If your old preset stored `RESHADE_DEPTH_*`
   definitions, preserve those same definitions in the new preset as well.

The Twin Lanterns effect keeps the existing ReShade label **Lunar Flower -
Twin Lanterns: Local Sampling Experiment** and identifiers for compatibility.
The package/download identity is **Kriegspinne — Overbuilt**.

## Enabled stack

| Order | Effect | Supplied by |
|---|---|---|
| 1 | Fog Guard Capture | Fog Guard V2 |
| 2 | GoldenWeave Redux | Lazara Revival |
| 3 | Twin Lanterns: smooth sampling, eight directions | This package |
| 4 | GI Color Bleed | Lazara Revival |
| 5 | Lazara | Lazara Revival |
| 6 | Fog Guard Restore | Fog Guard V2 |

The preset preserves the selected effect settings and enabled order. Disabled
effects and unrelated sorting entries are omitted. Fog Guard Restore belongs
after the lighting/color effects. The Twin Lanterns-only preset does not
reproduce the entire stack's appearance.

## Defaults and cost

Smooth sampling is enabled by default; normal regularization stays off.
Twin Lanterns uses eight directions, 16 DDA and 16 march samples per direction,
24-pixel reach, strength 0.272, and maximum added light 0.20. Bounce is forcibly
disabled. The package retains five full-resolution RGBA16F working fields and
six passes. `DEFAULTS.json` records all selected Twin Lanterns values.

This is the expensive presentation build. A supported flat-plane CPU fixture
used 156 depth reads and 30 color reads for one smooth-sampling direction,
versus 17 and 2 for first-hit sampling. Eight directions double the directional
work of the four-direction experiment; the full stack also runs other GI and
color effects. These figures are fixture counts, not measured GPU time or FPS.
Uncheck the whole technique to stop its passes.

## Source, credit and validation

Bundled shaders derive from Lunar Flower's own sampling experiment with
independently implemented changes. GoldenWeave Redux informed the research
comparison; its source and assets remain in their original repository. The
Lunar Flower license is retained. This package contains no external shader
source, screenshots, chat logs, raw uploaded presets, credentials or private
filesystem paths. Generated INIs contain only selected numeric effect settings
and technique identifiers.

Only the smooth-sampling default and selected eight-direction default change
from the published experiment's shader behavior. `CHANGES.patch` records those
changes. `VALIDATION.json` distinguishes CPU tests and ReShade FX frontend
checks from driver compilation, GPU timing and game-level visual acceptance.
The reference Kriegsspinne release is separate and unchanged.
