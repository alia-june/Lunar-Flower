# Depth fade and distant light softening

This Alpha candidate adds receiver-depth fading and surface-aware softening
of the indirect-light field. The motivating image was captured with the full
preset stack. No claim is made that Twin Lanterns alone caused its distant
white regions, outlines or stippling. These controls cannot recover details
already clipped, blurred or outlined in the source supplied by other effects.

## Controls and defaults

| Control | Default | Meaning |
| --- | --- | --- |
| Depth Light Fade | 1.000 | Fade authority; 1 removes added light at/after End, 0 disables this fade |
| Depth Fade Start | 0.00500 | Normalized linear depth where fade and softening begin |
| Depth Fade End | 0.05000 | Depth where they reach full authority |
| Distant Light Softening | 0.350 | Maximum blend toward the surface-gated neighboring light mean |
| Light Softening Radius | 2 px | Fixed full-resolution radius for four neighbors |

These are **normalized ReShade linear depth values**, not calibrated game
distances. The initial range is a tuning starting point. Start/End have
`0.00001` drag steps and allow numeric entry. End is treated as at least
Start plus `0.000001`; equal or reversed endpoints cannot divide by zero.
The shared source image, API and existing preset values are preserved. New
controls use the defaults above when absent from a preset, so they introduce
the new look until deliberately disabled or tuned.

Set **Depth Light Fade = 0 and Distant Light Softening = 0** to reproduce the
previous light-shaping path exactly and bypass all new neighboring samples.
The controls are independent: disabling fading alone can leave distant
softening active, using the same Start/End transition.

## Processing order

```text
transport → horizontal/vertical resolve → positive edge fill
          → distant light softening → receiver-depth fade
          → fidelity/overdrive intent → bounded additive composite
```

Fade uses a smooth monotone transition from Start to End and multiplies the
light's evidence, which the existing composite uses to scale added energy.
It runs after edge fill and softening so neither can refill a fully faded
receiver. Fully removed light returns the source through the existing
composite, including when Overdrive is enabled. It does not darken the source.

Softening blends the center and four ResolveV neighbors. Every neighbor must
pass the existing Surface Depth Agreement, Surface Direction Agreement, and
screen-coverage checks. It averages **light × evidence** and evidence together,
then reconstructs color. This keeps constant light/evidence constant and
allows valid black samples to soften a bright impulse without being mistaken
for missing data. The source back buffer is never part of this filter.

Softening authority grows with the depth transition. Its footprint is fixed
by Radius rather than changing discretely with depth. Loose depth/direction
tolerances can still admit unwanted neighbors; this is surface-gated sampling,
not a guarantee of geometric visibility or temporal stability.

## Tune with the mask

The appended **Depth Fade Mask** view preserves indices 0–16; its index is 17.
White means retain Twin Lanterns light, black means remove it, and gray means
partial retention. Invalid/sky depth is black. The mask shows fade only,
not the softening amount.

1. Hold the scene and camera fixed; initially isolate Twin Lanterns.
2. Select Depth Fade Mask. Adjust Start/End until the foreground remains white
   and the intended distant geometry transitions toward black. If all geometry
   stays white or turns black too early, tune the range for the game's actual
   normalized depth rather than assuming the defaults describe meters.
3. Return to Final Image and compare Depth Light Fade at 0 and 1.
4. Compare Distant Light Softening at 0 and 0.35, starting with Radius 1–2 px.
5. Inspect thin silhouettes and foreground/background edges. Tighten Surface
   Depth/Direction Agreement if unrelated surfaces are admitted.
6. Restore the full stack and compare Source Image and Applied Light. Source
   Image is the input Twin Lanterns receives, including preceding effects.

Edge Fill Target/Added remain diagnostics of the edge-fill stage before the
new depth shaping. Applied Light shows the final bounded contribution after
shaping and render intent. Bound Verification must remain green.

## Cost and validation limits

There are no new passes, working textures, history buffers or shared API
changes. Active softening adds at most four indirect-field reads and twenty
depth reads (four surface guides) at a partly retained receiver. Near receivers,
zero softening and fully faded receivers bypass those neighboring reads.
Regular transport still runs in Final Image; a fade is not a ray-work cull.
GPU cost and frame time must be measured in the target game.

Depth Fade Mask skips voxel building and lighting work in the existing
working passes, then reads depth once in display. The pass dispatches and
field writes still exist.

`tools/test_twin_lantern_depth_shaping.py` executes actual extracted shader
functions with CPU texture/vector shims. It checks endpoints, monotonicity,
fade-only signal, degenerate ranges, constant light, impulses, black samples,
depth/normal/sky/coverage rejection, bounded source preservation, exact bypass,
fade after edge fill, and mask work guards. These tests do not replace
ReShade/FXC compilation or game visual and timing acceptance. Native
compilation and live testing remain pending.
