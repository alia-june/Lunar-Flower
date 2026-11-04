# Twin Lanterns Stable 1.4

Stable 1.4 is the user-designated fixed Twin Lanterns baseline. This directory
preserves its shader implementation and Camera Obscura public identifiers so
existing ReShade presets can continue to address the same technique and
controls.

## Included Effect

```text
reshade-shaders/shaders/camera_obscura/effects/
  CAMERA_OBSCURA_TwinLantern.fx
```

Technique label: `Camera Obscura - Twin Lantern`

## Features

- four-cardinal-direction donor transport at half resolution;
- horizontal and vertical surface-guided reconstruction;
- depth-aware full-resolution upsampling;
- optional contour styling through Edge Ink;
- positive same-surface indirect deficit repair through Edge Fill;
- nonnegative additive output bounded by maximum contribution and remaining
  normalized SDR channel room;
- twelve diagnostic views, including rejection state, source difference, edge
  fill, and bound verification.

The effect includes no temporal history or denoiser.

## Public API

Stable 1.4 is the canonical source for the shared
[Twin Lanterns Public API 0.1.0](../API/0.1.0/). Its provider-evidence, transport,
reconstruction, and bounded-composite includes are the published rollback
contract. Exposing the API does not change this build's effect, technique, or
uniform identifiers.

## Install

1. Merge this directory's `reshade-shaders` folder into the target ReShade
   installation.
2. Keep the installation's known-good `ReShade.fxh`.
3. Reload ReShade.
4. Enable `Camera Obscura - Twin Lantern`.
5. Select `Bound Verification`; it should remain green during testing.

## Controls

- `Enable Indirect Light`
- `Indirect Light Strength`
- `Maximum Added Light`
- `Transport Distance`
- `Ray Depth Slope`
- `Front Surface Bias`
- `Back Surface Thickness`
- `Surface Depth Agreement`
- `Surface Direction Agreement`
- `Depth Edge Protection`
- `Edge Ink Strength`
- `Edge Fill Strength`
- `Edge Fill Radius`
- `Output View`

Edge Ink defaults to `0.00`. Edge Fill defaults to `0.20` at a `2.00` pixel
radius.

## Live Check

Use a fixed frame with fine geometry and depth boundaries:

1. Confirm a clean ReShade compile.
2. Toggle the technique and check for fixed screen-space hatching.
3. Compare Edge Ink at `0.00` and `1.00`.
4. Compare Edge Fill at `0.00`, `0.20`, and `1.00`.
5. Check thin silhouettes for cross-surface light carry.
6. Confirm `Bound Verification` stays green.

Stable naming records the accepted project position; it is not a universal
performance or compatibility guarantee for every game, API, depth buffer, or
ReShade release.

## License

This build is distributed under the repository's
[MIT License](../../LICENSE). Preserve the copyright and license notice with
copies or substantial portions.
