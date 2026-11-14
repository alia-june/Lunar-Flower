# Kriespinne — Spoke Lab 1

[Download Spoke Lab 1](https://raw.githubusercontent.com/alia-june/Lunar-Flower/refs/heads/lab/phantom-spokes/downloads/Kriespinne-Spoke-Lab-1.zip)
· [SHA-256](../../downloads/Kriespinne-Spoke-Lab-1.zip.sha256)

A separate Phantom Brigade experiment: three fixed primary spokes, an optional
two-tap opposing cached-light stage, and linear/cubic depth-admission controls.
The planned chain is **3 → 2 → 1**. This build implements **3 → 2** only.
Temporal history, animated spoke cycling and the final one-spoke stage are
not implemented. Existing approved downloads are unchanged.

## Install and compare

Extract outside shader search paths and copy only `reshade-shaders` into the
game. Keep the installed `ReShade.fxh`. This uses a separate
`lunar_flower_spoke_lab` folder and the effect **Lunar Flower - Twin Lanterns:
Spoke Lab 1**. Enable only one Twin Lanterns technique for the comparison;
the supplied presets select only this lab.

Keep the working depth-buffer selection, persistence/capture, inversion,
resolution and scaling. Preserve preset-local `RESHADE_DEPTH_*` definitions
from your working preset if applicable.

| Preset | Primary spokes | Admission curve | Cached bounce | Distant light softening |
|---|---:|---|---|---|
| 01 Eight Cubic Control | 8 | Cubic | Off | Existing setting |
| 02 Three Cubic NoBounce | 3 | Cubic | Off | Existing setting |
| 03 Three Linear NoBounce | 3 | Linear | Off | Existing setting |
| 04 Three Linear TwoTapBounce | 3 | Linear | Two opposing taps | Existing setting |
| 05 Three Linear SofteningOff | 3 | Linear | Off | Off |

Start with **01 versus 02** to test three spokes. Then compare **02 versus 03**
for the admission curve, **03 versus 04** for the cached bounce, and **03 versus
05** for distant light softening. Compare **Combined Weighted Signal** before
reconstruction and **Final Image** afterward. **Bounce Weighted Signal (8x)**
shows the two-tap contribution. Use Final Image for timing.

Linear admission keeps the same transition width and depth validity policy,
but removes the cubic `t*t*(3-2*t)` easing from the transport interval weight.
It remains continuous. The existing depth-fade curve still uses smoothstep;
this isolates the transport change rather than replacing every curve at once.
Horizontal/vertical reconstruction remains active even in preset 05.

## Cost and behavior

The three-spoke pattern selects indices 0, 3 and 5 from the eight directions.
Spoke Rotation moves the fixed pattern in 45-degree increments. Three-of-eight
cannot be an exactly even 120-degree arrangement, so coverage and appearance
can change. It does not silently rotate between frames.

At 16 DDA and 16 march samples per spoke, primary traversal drops from 256 to
96 scheduled samples per pixel, a 62.5% reduction in that part of the work.
Actual admitted donors, reconstruction and composition add further work.

The optional second stage samples the **current frame's bounded first-light
field**, using the opposite directions of the first two selected primary
spokes. It performs no secondary marches and reads no original source color.
Depth/normal agreement, distance loss, strength and retention limit its input.
Missing donors lose energy; they never brighten the surviving donor. An opposing
screen-space tap is an approximation, not a normal-reflected physical ray.

Two-Tap Bounce Strength defaults to 0.25 and Bounce Retention to 0.5, before
distance loss. Final light stays inside the existing faded contribution and
remaining-channel ceilings. This uses the existing first-light and bounce
targets: six RGBA16F working fields and seven passes, as in cached Smooth
Performance Candidate 1. Captured first light also supplies final composition.

The first-light field is stored at half precision. The eight/cubic control
retains the parent raw transport; final cache storage can introduce small
rounding differences. Tests bounded the cached/full composite difference at
about 0.000124. No bit-identical final-image claim is made.

## Validation and provenance

10,869 extracted-function CPU assertions passed, including spoke schedules,
96/256 traversal budgets, both admission curves, opposing tap coordinates,
two-read bounce limits, energy loss, invalid depth, source preservation and
half-storage/final-output bounds. Both compile selections pass ReShade 6.7.3
FX parsing and SM5 HLSL generation. This does not establish native driver
compilation, game visuals or FPS recovery. See `VALIDATION.json`.

Prior feedback for the separate normal-cache build was an FPS penalty reduced
from roughly 40 to 20. This means the reported FPS loss halved; it does not mean
total FPS doubled, and it is not a measurement of this new lab.

Bundled source derives from Lunar Flower's own normal-cache candidate. No
external shader code/assets, personal presets, screenshots, credentials or chat
logs are included. The original license is retained. `DESIGN.md` records the
remaining 3 → 2 → 1 and temporal-history work.
