# Twin Lanterns: Fidelity Overdrive

Fidelity Overdrive is the high-headroom Twin Lanterns candidate for Lunar
Flower. It keeps the fixed transport, reconstruction, edge-isolation, and
bounded composite architecture, then adds two independent controls after
reconstruction:

- **Fidelity Guard** protects receiver color direction and occupied highlight
  room.
- **Overdrive** raises requested Twin Lanterns energy up to `3x` before the
  existing hard bounds.

These controls can operate concurrently. Overdrive does not bypass `Maximum
Added Light` or the remaining room in any normalized output channel.

## Status

**Public candidate.** The source package passed 27/27 focused static and API
compiler checks before the public identifier refactor. The repository-native
validator separately checks the renamed public surface and writes
`PUBLICATION_VALIDATION_RESULTS.json`; the current result is 13/13 passed.

Complete ReShade compilation, target-game frame time, and live visual
acceptance of this public candidate remain pending. The source result is kept
as `SOURCE_VALIDATION_RESULTS.json` so these evidence states are not conflated.
The exact source package and public rename mapping are recorded in
`LINEAGE.json`.

## Included Effect

```text
reshade-shaders/Shaders/camera_obscura/effects/
  LUNAR_FLOWER_TwinLanterns_FidelityOverdrive.fx
```

Technique label:

```text
Lunar Flower - Twin Lanterns: Fidelity Overdrive
```

The internal `CAMERA_OBSCURA_TL09` names and APIs are retained as implementation
lineage. The public filename, technique, categories, and controls use the Lunar
Flower Twin Lanterns identity.

## Public API

This build carries the shared [Twin Lanterns Public API 0.1.0](../API/0.1.0/).
Its four API files and four support headers are source-identical to the Stable
1.4 contract; Fidelity Guard and Overdrive remain effect-level rendering-intent
controls rather than silent API changes.

## Install

1. Merge this directory's `reshade-shaders` folder into the target ReShade
   installation.
2. Keep the installation's known-good `ReShade.fxh`.
3. Do not overwrite or enable Stable 1.4 unless you intentionally want both
   techniques available.
4. Reload ReShade and enable `Lunar Flower - Twin Lanterns: Fidelity
   Overdrive`.
5. Select `Bound Verification`; it must remain green.

## Intent Controls

### Fidelity Guard

`0.00` leaves reconstructed indirect color unchanged. Increasing the control
aligns indirect light toward the receiver's current RGB direction and reduces
requested energy near occupied highlights. The default is `0.65`.

This is a normalized screen-space guard. It is not a claim of scene-linear,
spectral, or colorimetric fidelity.

### Overdrive

`0.00` applies no extra gain. `1.00` requests up to `3x` the admitted energy
before the hard contribution and channel-room limits. The default is `0.00`.

Overdrive adds arithmetic only. It adds no texture reads, history buffers, or
resources.

## Other Controls

- `Indirect Light Strength` scales admitted reconstructed light, with a fine
  drag control and `0.001` steps (0.1 percentage point of nominal strength).
  For 10-30% nominal strength, use `0.100-0.300`.
- `Maximum Added Light` is the hard per-channel addition ceiling.
- transport controls set ray reach, depth slope, front bias, and back
  thickness.
- reconstruction controls set depth, surface-direction, and edge agreement.
  `Surface Depth Agreement` uses a fine drag control with `0.00001` steps.
  Lower values reject differing-depth neighbors more strictly; higher values
  can admit more neighboring light and soften boundaries.
- `Edge Ink Strength` restores optional contour-heavy styling.
- `Edge Fill Strength` and `Edge Fill Radius` repair positive indirect-light
  deficits using four same-surface taps. Edge Fill never samples or blurs the
  source image.

These two UI annotations were backported from the accepted Alpha controls.
Ctrl-click permits direct numeric entry. Existing uniform names, ranges,
defaults, preset scales, shader functions and shared includes are preserved.
`LINEAGE.json` retains the original source hash and records the exact annotation
edits; publication validation reverses those edits before the historical rename
check. Native UI and visual acceptance for this backport still require ReShade.

## Diagnostics

1. Final Image
2. Source Image
3. Bounded Indirect Light
4. Evidence Confidence
5. Applied Light
6. Rejection Reason
7. Remaining Channel Room
8. Containment Activity
9. Source Difference
10. Bound Verification
11. Edge Fill Target
12. Edge Fill Added
13. Fidelity Guard Activity
14. Overdrive Pressure

`Bound Verification` must remain green. The two intent diagnostics should be
localized responses, not fixed full-screen masks.

## Acceptance Matrix

| Fidelity Guard | Overdrive | Purpose |
|---:|---:|---|
| `0.00` | `0.00` | Reproduce the pre-overdrive intent path |
| `1.00` | `0.00` | Isolate receiver-color and highlight protection |
| `0.00` | `1.00` | Stress raw bounded overdrive |
| `0.65` | `1.00` | Exercise both controls concurrently |

For every row:

- keep the camera and scene fixed;
- confirm `Bound Verification` remains green;
- inspect highlights for clipping or hue break;
- inspect dark surfaces for useful transport rather than a full-screen wash;
- inspect thin silhouettes for cross-surface carry;
- record the result in `LIVE_RESULT_TEMPLATE.csv`.

## Performance

Twin Lanterns performs four transport evaluations per half-resolution raw
sample before separable reconstruction. Edge Fill adds four reads per output
pixel when enabled and none at zero strength. Fidelity Guard and Overdrive add
arithmetic only. Measure frame time at the intended game and resolution.

## Rollback

Disable the Fidelity Overdrive technique and remove its effect file. Return to
[Stable 1.4](../Stable-1.4/) without changing that baseline's shader files.

## License

This build is distributed under the repository's
[MIT License](../../LICENSE). Preserve the copyright and license notice with
copies or substantial portions.
