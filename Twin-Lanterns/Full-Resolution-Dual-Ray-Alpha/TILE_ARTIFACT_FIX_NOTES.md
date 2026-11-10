# Camera-dependent square artifacts

The reported configuration is Crystal Spider at defaults plus Lazara's Fog /
Light Guard at defaults. The square pattern disappears after a small camera
movement. This correction addresses a reproduced Crystal Spider admission
defect; the exact game scene and combined effects have not been reproduced here.

## Reproduced cause

Each adaptive node measures a center and four inset corners. Its stored minimum
and maximum are bounds on those probes, not conservative bounds on every pixel
inside the tile. A narrow surface between probes can be absent from the stored
interval even though its full-resolution depth is valid. The old trace rejected
that entire candidate before reading fine depth. A small movement that put the
surface under a probe changed the admission decision, producing tile-shaped
differences in lighting.

The CPU-extracted published shader fails a narrow-surface regression at the
shipped ray length, slope, front bias, thickness and step budget. The corrected
shader passes 21 sub-tile placements at 1280×720, 2560×1440 and 3840×2160.
The fixture exercises both coarse and subdivided nodes. It also compares full
raw transport at a fixed UV with built and empty diagnostic atlas contents.
It does not require equality between different screen UVs, where the independent
screen provider's jitter can legitimately differ.

## Correction and cost

- The bounded proxy trace validates full-resolution depth at each eligible ray
  sample. Sparse atlas coverage/bounds cannot veto a donor.
- Fine depth validity, ray interval, self-hit distance, distance weighting,
  explicit-LOD color sampling and final contribution limits remain in force.
- The surface diagnostic also uses fine depth validity. The adaptive atlas and
  detail view remain available, but the atlas is diagnostic data rather than a
  light-admission mask. Its compute build runs only for voxel diagnostic views.
- All 24 selected defaults, public identifiers, textures, pass count, preset
  scales and Stable/Fidelity shaders are unchanged.

This deliberately removes sparse hierarchy rejection from lighting. The atlas
is no longer an accelerator for transport. Fine depth reads can increase on
rays previously rejected by sparse bounds; atlas lookups and normal-view atlas
construction are removed. GPU frame time must be measured in the target game.
The loop remains capped at 32 steps, with the default request still 24; no new
implicit-gradient reads or varying loops are introduced.

## Fog Guard inspection

The Lazara package's `BlackWand_10_FogLight_Guard.fx` is a single-pass guard
using source luminance, saturation, local contrast and a depth window. Its
inspected effect and local helper file contain no voxel grid. It can make
existing light/contrast variation more visible; this source inspection does
not rule out game depth behavior or other interactions.

Shader defaults and saved preset values are different: the inspected shader's
Strength default is `1.0`, while the package's saved `Lazara.ini` uses `0.672`.
No Fog Guard defaults or Lazara files are changed by this correction.

## Retest

Install the complete updated Crystal Spider package so the effect and include
match. At the problem angle, compare the whole Crystal Spider technique off
and on, first alone and then with Fog Guard enabled. Check the same angle and
the small camera shift that previously removed the squares. Native ReShade
compilation and live visual/performance acceptance remain to be recorded.
