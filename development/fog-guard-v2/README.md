# Fog / Light Guard V2 — test build

This test build is hosted in Lunar Flower because GitHub denied the current
`alia-june` login write access to the `dastardlyrat` Lazara repository. Lazara's
upstream `main` is unchanged.

[Download the single-effect test ZIP](../../downloads/Lazara-Fog-Guard-V2.zip)
· [Apply-ready Lazara patch series](Lazara-Fog-Guard-V2.patch)
· [Validation results](VALIDATION.json)

Apply the patch in a clean **Lazara-Reshade-Revival-Package** checkout based on
`49e64006431e5e86e8a447bef517cbd926968e18`, using
`git am --keep-cr /path/to/Lazara-Fog-Guard-V2.patch`. The flag preserves the
preset's existing CRLF lines. This patch is for Lazara, not the Lunar Flower
shader tree. The test ZIP is the simpler option for an in-game retest.

The original guard was a single early pass. With default Outside Shade `0.18`,
it could darken unprotected RGB by 18% even when no later effect needed
correction. It also used uncorrected raw hardware depth, and could not restore
fog/light after the following filters. V2 changes that behavior explicitly.

## Install and order

The single-effect test ZIP contains the updated `BlackWand_10_FogLight_Guard.fx`
and its unchanged include closure. Extract outside the shader search tree and
merge only `reshade-shaders` into the existing installation, replacing that
same effect path. Keep the installed `ReShade.fxh`; do not install another copy
of the effect beside it.

Use this order in ReShade:

1. **@BlackWand - Fog / Light Guard (Capture)**
2. Crystal Spider and/or the other effects you want the guard to contain
3. **@BlackWand - Fog / Light Guard (Restore)**

The old Capture technique identifier is retained. Restore is a new second
technique in the same effect file. Enabling Capture alone records a reference;
it does not protect against later filters until Restore is enabled after them.
The source repository's `Lazara.ini` appends Restore after its original 18 stages.
Other effects' settings and the existing relative technique order are preserved.

**Existing presets retain their saved values. Set Outside Shade to `0`.**
If adopting the new depth mask, set Depth Window Start `0.005`, End `0.05`,
Depth Influence `0.5`, Mask Softening `0.5`, and Mask Radius `1 px`, or reset
only Fog Guard's controls. The packaged Lazara preset keeps its saved Strength
`0.672`; the shader's reset/default Strength remains `1`. Do not replace your
whole custom preset merely to change these Fog Guard settings.

## What changed

- Capture stores current-frame reference RGB and full-resolution coverage.
  Default capture output is unchanged: Outside Shade is now an optional style
  control, off by default.
- Fog distance uses `ReShade::GetLinearizedDepth`, honoring the installed
  framework's depth orientation/linearization definitions. It no longer reads
  raw depth with an assumed direction. Depth endpoints/invalid samples fall
  back to color/contrast classification; far fog stays supported beyond End.
  The normalized depth controls are fractions of the configured linearized
  depth range, not meters or calibrated game distances.
- Four neighboring coverage samples soften the mask. Relative-depth and
  luminance gates prevent carrying that coverage across dissimilar surfaces.
  Only coverage is softened; captured RGB is not blurred. There is no coarse
  tile grid, stochastic threshold or temporal accumulation.
- Restore blends filtered RGB toward the captured reference under Mask ×
  Strength × Protection Amount. Each channel stays between its two inputs;
  no global outside darkening is added. Outside regions remain filtered.
- A separate 1×1 RGBA32F stamp stores both exact 16-bit halves of the uint frame
  counter plus frame dimensions. Missing, stale, first-use/uninitialized,
  dimension-mismatched or wrongly ordered capture leaves current RGB unchanged.
  No previous frame is intentionally reused. Counter rollover after 2^32 frames
  has the same identity as any uint frame counter.

## Cost and validation boundary

This is a functional capture/restore pair, not a free single-pass darkening
adjustment. It adds one full-resolution RGBA16F reference/coverage texture and a
1×1 RGBA32F stamp. The extra allocation is 28.125 MiB at 2560×1440, or
63.28125 MiB at 3840×2160, plus 16 bytes and runtime overhead. Capture has
reference, stamp and preview passes; Restore adds one output pass. Default
softening measures a center and four full-resolution mask taps; disabling
softening removes the four neighbor measurements. GPU cost is unmeasured.

`python -B -m unittest discover -s tools -p 'test_fog_guard.py'` compiles actual
shader function bodies with C++ vector/texture shims. It covers default neutral
capture, bounded fog/depth classification, depth/luma boundaries, mask continuity,
late restoration, zero bypass and stale/misordered frame rejection around
16-bit and float integer precision boundaries. This does not establish native
ReShade/FXC compilation or reproduce the reported game capture.

Retest the same angle with the whole guard pair off, then on around Crystal
Spider. Compare a small camera move, Outside Shade zero, and mask diagnostic
views. Keep the original effect as a rollback outside shader discovery.

## Source provenance

Only the curated Fog Guard effect is locally patched from the locked Occult
Box baseline. `patches/fog-guard-v2.patch` and `dependencies.lock.json` record the
base and result hashes. The manual test ZIP carries the Fog Guard subset in
`SOURCE_PROVENANCE.json`. Other vendor bytes and author/license notices remain
intact. Updating the vendored manifest records this deliberate patch; it does
not imply byte identity to the unpatched upstream revision.
