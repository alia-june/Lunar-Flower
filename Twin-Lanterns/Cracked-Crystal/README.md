# Twin Lantern — Cracked Crystal

The default Twin Lanterns build: the owner-preferred preset 04 configuration,
with **Indirect Light Strength 2.0**. It uses three fixed primary spokes,
linear depth admission, cached donor normals and two opposing cached-light taps.

This is the public download identity for the tested Spoke Lab 2 build. Shader
code, runtime settings, effect/technique identifiers and resource layout are
unchanged. Bounce strength remains 0.25, retention 0.5, reach 3 pixels, and
Maximum Added Light 0.20. The ceiling and available source-channel room still
limit how much light can be added.

## Install

Extract outside shader search paths and copy only `reshade-shaders` into the
game. Keep the installed `ReShade.fxh`. Replace an existing
`lunar_flower_spoke_lab` folder; do not install a second copy beside it.

Select **Twin-Lantern-Cracked-Crystal.ini**. For preset compatibility, ReShade
still lists the effect as **Lunar Flower - Twin Lanterns: Spoke Lab 2**. Reset
defaults already match preset 04 at strength 2.0. Existing presets retain their
saved values until changed or reset.

The included **Spoke-Lab-04-Previous-Strength.ini** is the same configuration at
the previous strength 0.272. Keep the game's working depth selection, inversion,
capture/persistence, resolution and scaling. Preserve preset-local
`RESHADE_DEPTH_*` definitions from a working preset when needed.

## Behavior and validation

The first stage schedules 96 primary depth samples per pixel. The second stage
uses two gated taps from this frame's bounded first-light field; it launches no
secondary ray marches. Six RGBA16F working fields and seven passes are retained.
The intended 3 → 2 → 1 design currently implements 3 → 2. There is no third
stage, animated spoke cycling or temporal history. See `DESIGN.md`.

Transport admission is linear. The separate depth-fade curve still uses its
existing smoothstep. The source image is preserved and added light stays inside
the configured faded contribution/channel ceilings.

The owner preferred preset 04 with good performance in Phantom Brigade. The
underlying algorithms have CPU continuity, sampling-budget and output-bound
checks, and ReShade 6.7.3 FX parsing/SM5 HLSL generation passed. The branding
revision verifies every shader byte and preset value against Spoke Lab 2.
These checks do not supply native driver compilation or controlled GPU timings.
See `VALIDATION.json` and `SOURCE_MANIFEST.json` for scope and exact hashes.

Source derives from Lunar Flower's own Spoke Lab 2. The original license is
retained. No external shaders/assets, personal presets, screenshots, chat logs
or credentials are included. Earlier versioned builds remain separate.
