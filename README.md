# Lunar Flower

Lunar Flower is the public home of **Twin Lanterns**, a ReShade screen-space
indirect-light project built around explicit surface evidence, bounded energy,
and inspectable diagnostics.

Twin Lanterns gathers donor light in four cardinal directions, reconstructs it
across compatible surfaces, and adds only the contribution allowed by the
configured ceiling and the remaining room in each output channel. It is not an
ambient-occlusion shader, and it does not contain a denoiser or temporal
history.

## Visual Comparison

![No Effect, Twin Lanterns Only, and Lazara plus Twin Lanterns](Twin-Lanterns/assets/twin-lanterns-three-way-comparison.png)

Left: **No Effect** · Center: **Twin Lanterns Only** · Right: **Lazara + Twin Lanterns**

This is a deterministic vertical-third stitch of three user-supplied
2560×1440 captures. No source region was resized, filtered, or generated. The
[comparison evidence](Twin-Lanterns/assets/twin-lanterns-three-way-comparison.json)
records source hashes, split coordinates, and exact decoded-pixel checks.

The comparison is documentation evidence containing third-party game imagery;
that imagery is not included in the repository's MIT software grant.

## Choose A Build

| Build | Status | Best for |
|---|---|---|
| [Stable 1.4](Twin-Lanterns/Stable-1.4/) | Fixed baseline | A conservative, preset-compatible Twin Lanterns installation |
| [Fidelity Overdrive](Twin-Lanterns/Fidelity-Overdrive/) | Public candidate; live acceptance pending | Independent color/highlight protection and stronger bounded transport |

`Stable-1.4` is preserved as the user-designated fixed line. Fidelity
Overdrive is staged beside it rather than replacing it.

## Quick Install

1. Install ReShade for the target game.
2. Open the selected build directory.
3. Merge its `reshade-shaders` directory into the ReShade installation.
4. Keep the installation's known-good `ReShade.fxh`.
5. Reload ReShade and enable the named Twin Lanterns technique.

Do not install both variants at once unless you intentionally want two
independent techniques and understand their separate control surfaces.

## Design Boundaries

- Four cardinal transport directions are evaluated at half resolution.
- Reconstruction is gated by depth, surface direction, edge, and coverage
  evidence.
- Added light is nonnegative and bounded by both a user ceiling and remaining
  normalized SDR channel room.
- Edge Ink is optional styling; it is not claimed as ambient occlusion.
- Edge Fill operates on the reconstructed indirect field, not the source
  image.
- Denoising and temporal stabilization remain external effects.

The implementation is screen-space and cannot recover information that is
absent from the current frame. Off-screen light, hidden geometry, transparency,
and game-specific depth behavior remain practical limits.

## Repository Layout

```text
Twin-Lanterns/
  Stable-1.4/          fixed baseline
  Fidelity-Overdrive/ independent fidelity and overdrive candidate
tools/
  validate_publication.py
```

Run the reproducible publication checks with:

```powershell
python -B tools/validate_publication.py
```

The current publication result is **13/13 passed**.

Structural validation is not a substitute for a clean ReShade compile, frame
time measurement, or live visual acceptance in the target game. Each build
documents its own evidence state and test gate.

## License And Authorship

Lunar Flower is published under the [MIT License](LICENSE). The copyright and
license notice must remain with copies or substantial portions of the work.

Project direction and authorship: **alia june**. Documentation and validation
tooling were prepared with AI assistance under the author's direction; that
assistance does not replace the stated license, authorship, or live human
acceptance gates.
