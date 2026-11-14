# Kriespinne — Spoke Lab 2

The owner-preferred **preset 04** is now the default: three primary spokes,
linear depth admission, and two opposing cached-first-light taps.
**Indirect Light Strength defaults to 2.0**, changed from 0.272.

Bounce strength remains 0.25, bounce retention 0.5, bounce reach 3 pixels, and
Maximum Added Light 0.20. No other selected effect values or sampling algorithms
change. The 0.20 ceiling, remaining source-channel room and depth fade can limit
the visible increase; the result is not guaranteed to look 7.35 times brighter.

## Install

Extract outside shader search paths and copy only `reshade-shaders` into the
game. Keep the installed `ReShade.fxh`. Replace the existing
`lunar_flower_spoke_lab` folder; this retains the same effect, technique and
uniform identifiers, so do not install another copy beside it.

Select **Kriespinne-Spoke-Lab-2.ini**. Its technique is **Lunar Flower - Twin
Lanterns: Spoke Lab 2**. Existing presets keep their saved strength, so loading
the new preset is required to apply 2.0 to an existing installation. The reset
default is also 2.0.

**Spoke-Lab-04-Previous-Strength.ini** provides the identical preset-04 setup at
the previous strength 0.272. The two presets differ only in main light strength.
Keep other effects off for that comparison and preserve the game's working
depth-buffer selection, inversion, capture/persistence, resolution and scaling.
Preserve any working preset-local `RESHADE_DEPTH_*` definitions if needed.

## Behavior and validation

The three-spoke gather still schedules 96 primary depth samples per pixel.
The second stage takes two gated taps from the current frame's bounded added
light, rather than launching more ray marches. Six working fields and seven
passes are retained. There is no new sampling work from changing this default;
actual GPU timing still needs in-game measurement.

The planned **3 → 2 → 1** chain remains implemented as **3 → 2**. The third
stage, frame cycling and temporal history are future work. Linear transport
admission remains enabled; the separate existing depth-fade curve still uses
smoothstep. See `DESIGN.md` for the remaining work.

`VALIDATION.json` records source/default and preset checks plus ReShade FX
frontend results. Existing mathematical validation includes strengths across
the supported 0–4 range and final light/channel bounds. Parser/CPU checks do
not establish FXC/DXC/driver compilation or measured performance at 2.0.

Source derives from Lunar Flower's own Spoke Lab 1. The original license is
retained. No external shaders, personal presets, screenshots, chat logs or
credentials are included. Spoke Lab 1 remains available separately.
