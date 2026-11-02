# Camera Obscura Twin Lantern

Date: 2026-11-02

Status: production consolidation with optional edge ink and same-surface edge
fill; local validation 25/25; final ReShade compile
and live smoke test pending

## Purpose

Twin Lantern reconstructs bounded screen-space indirect light from four cardinal
transport directions. It preserves the accepted TL01-TL09 V2 pipeline while
presenting one production-facing technique:

`Transport -> Horizontal Resolve -> Vertical Resolve -> Bounded Composite`

The effect is intentionally source-preserving. If the effect is disabled, its
receiver is invalid, evidence is absent, strength is zero, or no channel room
remains, the added contribution resolves to zero.

## What Is Included

- one effect: `CAMERA_OBSCURA_TwinLantern.fx`;
- four-direction transport at every half-resolution raw sample;
- surface-guided horizontal and vertical reconstruction;
- four-tap depth-aware full-resolution upsampling;
- nonnegative indirect-light contribution bounded by both the user ceiling and
  remaining normalized SDR channel room;
- diagnostic views for evidence, rejection, containment, source difference,
  and bound verification.

The denoiser is not included. There is no temporal history, D1/T1 return path,
or reconstruction-versus-blending experiment in this package. Use any external
denoiser as a separate technique.

## Install

1. Merge `reshade-shaders` into the target ReShade installation.
2. Keep the host installation's known-good `ReShade.fxh`.
3. Disable or remove older Twin Lantern proof effects.
4. Reload ReShade and enable `Camera Obscura - Twin Lantern`.
5. Record the first relevant compiler error or warning if the effect does not
   compile cleanly.

## Controls

- `Enable Indirect Light`: exact source pass-through when disabled.
- `Indirect Light Strength`: scales admitted reconstructed light; zero is exact
  source pass-through.
- `Maximum Added Light`: hard per-channel ceiling before the final SDR bound.
- `Transport Distance`: maximum screen-space reach of each transport ray.
- `Ray Depth Slope`: depth travel rate along each ray.
- `Front Surface Bias` and `Back Surface Thickness`: accepted hit interval.
- `Surface Depth Agreement`, `Surface Direction Agreement`, and `Depth Edge
  Protection`: reconstruction support gates.
- `Edge Ink Strength`: stylistic contour emphasis. Zero keeps surface-safe tap
  rejection through depth and normal agreement without applying the continuous
  edge-risk fade or reducing light confidence around rejected edges. One
  restores the original contour-heavy Twin Lantern appearance.
- `Edge Fill Strength`: restores only missing positive indirect-light signal at
  an edge. It never blurs or subtracts from the source image. Zero bypasses the
  four edge-fill reads exactly.
- `Edge Fill Radius`: full-resolution distance used to find nearby same-surface
  indirect light. Depth and normal agreement remain mandatory.

Starting values preserve the accepted transport behavior: strength `1.00`,
maximum added light `0.20`, transport distance `24`, and the accepted
reconstruction defaults shown in the panel. Edge ink defaults to `0.00`; edge
fill starts lightly at `0.20` with a `2.00` pixel radius.

## Diagnostic Views

1. `Final Image`
2. `Source Image`
3. `Bounded Indirect Light`
4. `Evidence Confidence`
5. `Applied Light`
6. `Rejection Reason`
7. `Remaining Channel Room`
8. `Containment Activity`
9. `Source Difference`
10. `Bound Verification`
11. `Edge Fill Target`
12. `Edge Fill Added`

`Bound Verification` must remain green. Rejection colors are green for applied
light, blue for disabled, red for invalid receiver, magenta for absent evidence,
amber for zero strength, cyan for no remaining channel room, and gray for zero
indirect energy.

## Final Live Gate

1. Confirm a clean ReShade compile with no relevant warning cluster.
2. Compare `Final Image` with `Source Image` in one fixed frame. Disabling the
   effect and setting strength to zero must each return the source exactly.
3. Toggle the technique in the same detailed scene used for the failed TL09
   comparison. No coherent diagonal hatch or fixed screen lattice may appear.
4. Compare `Edge Ink Strength` at `0.00` and `1.00`. Zero should remove the
   AO-like contour emphasis; one should restore it without introducing a
   diagonal screen lattice.
5. With ink at `0.00`, compare edge fill at `0.00`, `0.20`, and `1.00`.
   `Edge Fill Target` should identify depth boundaries while `Edge Fill Added`
   should remain sparse and localized to missing positive light.
6. Confirm `Bound Verification` remains green in every style.
7. Inspect thin geometry, foliage, depth boundaries, and screen borders for
   cross-surface carry or repeated edge evidence.
8. Inspect dark open surfaces for bounded light without a full-screen wash.
9. Confirm runtime cost is acceptable for the target game and resolution.
10. Record observations in `LIVE_RESULT_TEMPLATE.csv`.

The fixed-frame hatching comparison is the primary regression discriminator.
A brightness change alone is not evidence of success.

## Local Validation

- 25/25 focused checks pass;
- local include closure is complete;
- all 14 production controls are initialized;
- edge ink is an explicit initialized style control and defaults off;
- edge fill has an exact zero-strength bypass, four same-surface taps, and no
  source-image sampling;
- one production effect and one production technique are present;
- proof selectors and forced input modes are absent;
- four accepted TL08 sampling/evaluation bodies and the reconstruction API
  match the immutable package after normalization of approved public names;
- the diagonal screen-position phase lattice is absent;
- four live cardinal transport directions aggregate at every raw sample;
- four surface-gated half-resolution taps feed the full-resolution composite;
- the flat 19-field composite record is fully initialized;
- 5,000 deterministic energy, channel-room, and failure-gate cases pass;
- 5,000 deterministic edge-fill cases remain monotonic and bounded by nearby
  indirect signal;
- compatibility and strict FXC API compiles pass without warnings;
- the frozen 79-file baseline is unchanged.

These checks do not prove the complete ReShade effect compile, live visual
quality, runtime performance, or final user acceptance.

## Performance

Twin Lantern performs four raw transport evaluations per half-resolution sample
before the separable resolve. It is intentionally heavier than the first TL09
proof that selected one direction per pixel. Measure frame time in the target
game before broad deployment. Edge fill adds four reads per output pixel when
its strength is above zero and adds none when its strength is zero.

## Lineage

Internal `TL09` API, resource, and function identifiers are retained as
implementation lineage. Renaming them would create an unproven refactor without
changing behavior. The public effect, technique, controls, labels, and passes
use production names.

## Rollback

Disable Twin Lantern and remove `CAMERA_OBSCURA_TwinLantern.fx` plus
`CAMERA_OBSCURA_API_TwinLanternComposite.fxh`. Restore the previously approved
`TWIN_LANTERN_TL09_COMPOSITE_V2_LIVE_GATE_2026-11-01.zip` packet if needed.

## Integrity

`MANIFEST.sha256` records every packaged file except itself.
