# Twin Lanterns — Bounce Lab

An isolated voxel-free experiment combining screen-space light transport with
a limited current-frame color-continuity approximation. The Direction Lab
Cardinal + DDA/March baseline remains available unchanged.

## Install and compare

1. Extract `Twin-Lanterns-BounceLab.zip` outside ReShade shader search folders.
2. Merge only `reshade-shaders` into the game. Keep the installed `ReShade.fxh`.
3. Load **Twin-Lanterns-BounceLab-Reference.ini**. It enables only **Lunar Flower
   - Twin Lanterns: Bounce Lab**, with Second Bounce Strength zero. Its first
   pass retains the selected Direction Lab settings.
4. At the same scene/camera position, compare **Bounce.ini**: Second Bounce
   Strength `0.5`, Energy Retained Per Bounce `0.5`, Extra Bounce Distance Decay
   `1`, and Current-Frame Color Anchor `0.5`. Unknown-Support Loss stays zero.
5. Then compare **BrokenSampler.ini**, which changes only Unknown-Support Loss
   to `0.35` with Mixed mode. Keep other effects and both Fog Guard techniques
   disabled while isolating this experiment.

The independent effect, uniform, texture and include-directory identities allow
installation beside previous builds. Disable those techniques during testing.
No existing shader/download is replaced and no full Lazara preset is changed.

## Light transport and degradation

The six ordered pixel passes are first transport, horizontal resolve, vertical
resolve, bounded first-light capture, second gather, and final composite.

The capture contains only the first pass's actual bounded, faded **added light**.
The second gather traces the selected directions/providers against current
depth, then reads that captured light at accepted donors. It does not feed the
final brightened image or previous-frame lighting back into the calculation.
Secondary tracing skips backbuffer color reads.

Both ray legs retain their established linear distance weight. Extra Bounce
Distance Decay applies an additional power of `(1 - distance / travel)` on the
second leg; `1` makes that leg's combined distance falloff quadratic. Distances
are screen pixels. This is not calibrated inverse-square world-space transport.

Energy Retained Per Bounce and Second Bounce Strength multiply the gathered
secondary signal. At `0.5` each, at most one quarter of the already bounded
donor light survives before the other support/distance losses. This is one extra
gather; no recursive bounce loop or material-reflectance measurement is claimed.

Missing/dropped directions keep their place in the scheduled denominator.
Their energy is lost rather than redistributed to brighten surviving samples.
The source and first-pass contribution have priority. Additional light fits
only into the remaining faded contribution and channel-room ceilings. Changing
secondary support cannot subtract existing source/first-pass light.

## Broken sampler and color continuity

Unknown-Support Loss is an artificial uncertainty experiment applied only to
the second gather:

- **Diminish:** reduce direction weights by deterministic variation.
- **Drop Directions:** remove a fraction of directions; amount `1` removes all.
- **Mixed:** drop some directions and diminish the others.

The hash uses screen pixel, direction and Stable Pattern Seed. There is no
frame counter or fresh per-frame randomization. The pattern is screen-anchored,
not world-anchored; camera motion can still change its relationship to surfaces.
Grain or fixed-pattern structure is possible. This control does not detect
unknown occluders, and a missing DDA hit is not treated as proof of obstruction.

Current-Frame Color Anchor aligns the extra signal toward the current receiver's
first-pass light color without increasing the extra signal's luminance or peak.
It does not restore energy lost to distance, bounce loss or dropped samples.
If secondary light vanishes, the existing source and first light remain.

That separates a rendering approximation from a perceptual control. It is not
temporal persistence, a validated human-vision model or proof that absent light
should remain visible. Motion-aware color memory would require separate history,
reprojection and disocclusion work; this build contains none.

## Diagnostics

Views 0–25 retain the first-pass/provider mappings from Direction Lab. Applied
Light and Bound Verification include the secondary contribution; Evidence
Confidence continues to describe the first pass. Use Bounce Support for the
secondary support signal.

| New Output View | Meaning |
|---|---|
| Captured First Light (8x) | Actual bounded/faded first contribution available to donors, with display-only gain |
| Bounce Weighted Signal (8x) | Secondary RGB after sampling support, distance and bounce loss, before receiver anchoring/caps, with display-only gain |
| Applied Second Bounce (8x) | Only the extra contribution that survives receiver fade and remaining ceilings, with display-only gain |
| Chaos Direction Retention | Mean retained direction weight from the artificial uncertainty pattern; no lighting field reads |
| Bounce Support | Secondary geometry/field/uncertainty/distance support averaged over the fixed scheduled budget |

The three RGB views marked **8x** amplify and clamp their display only. That
gain never enters either lighting field, the gather or Final Image. It helps
distinguish a small surviving contribution from zero. The two scalar masks
remain unamplified.

## Cost, validation and limits

Five full-resolution RGBA16F textures use approximately **140.6 MiB at 1440p**,
excluding framework resources. An enabled second gather adds ray work, and
first-light capture adds a composite evaluation. Second Bounce Strength zero
skips secondary sampling and capture outside its dedicated diagnostic view;
the two textures and passes still exist. GPU timings have not been measured.

CPU fixtures execute extracted shader functions with synthetic textures to
check first-pass equivalence, bounded energy, decay, fixed dropout accounting,
color anchoring, source preservation and same-frame field ordering assumptions.
Source/package checks cover includes, explicit-LOD loop sampling, resources,
presets, provenance and archive integrity. They do not establish native ReShade
compilation, GPU correctness, frame synchronization or in-game appearance. Those
remain pending. The existing Elden Ring cutoff is not claimed fixed.

`SOURCE_LINEAGE.json` identifies parent/source bytes. `OWNER_FEEDBACK.md` records
the visual observations motivating this experiment. Software follows the
repository MIT license and retained notices.
