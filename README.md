# Lunar Flower

Lunar Flower is the public home of **Twin Lanterns**, a ReShade screen-space
indirect-light project built around explicit surface evidence, bounded energy,
and inspectable diagnostics.

Twin Lanterns gathers donor light along explicit screen-depth rays,
reconstructs it across compatible surfaces, and adds only the contribution
allowed by the configured ceiling and the remaining room in each output
channel. Stable and Fidelity Overdrive use four half-resolution cardinal
directions. The Full Resolution Dual Ray Alpha build adds variable
opposing ray pairs and a camera-visible voxel-radiance proxy. Twin Lanterns is
not an ambient-occlusion shader, and it does not contain a denoiser or temporal
history.

## Visual Comparison

![No Effects, Twin Lanterns Full, and Twin Lanterns Full plus Lazara](Twin-Lanterns/assets/twin-lanterns-full-lazara-comparison.png)

Left: **No Effects** · Center: **Twin Lanterns Full** · Right: **Twin Lanterns Full + Lazara**

This is a deterministic vertical-third stitch of three aligned, user-supplied
2560×1440 captures. All three complete source frames are also preserved in the
repository. No comparison region was resized, filtered, labeled, or generated.
The [comparison evidence](Twin-Lanterns/assets/twin-lanterns-full-lazara-comparison.json)
records source and repository hashes, split coordinates, and exact
decoded-region checks. Effect-state labels are the user's assignments; the
image is presentation evidence, not a runtime-isolation or performance claim.

The comparison is documentation evidence containing third-party game imagery;
that imagery is not included in the repository's MIT software grant.

## Choose A Build

| Build | Status | Best for |
|---|---|---|
| [Stable 1.4](Twin-Lanterns/Stable-1.4/) | Fixed baseline | A conservative, preset-compatible Twin Lanterns installation |
| [Fidelity Overdrive](Twin-Lanterns/Fidelity-Overdrive/) | Public candidate; live acceptance pending | Independent color/highlight protection and stronger bounded transport |
| [Full Resolution Dual Ray Alpha](Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/) | Public alpha; structural checks passed, compile and live gates pending | Full-resolution transport, 2-8 rays, and compute-built view-frustum voxel-proxy research |

`Stable-1.4` is preserved as the user-designated fixed line. Fidelity
Overdrive and Full Resolution Dual Ray Alpha are staged beside it rather than
replacing it.

## Public API

Twin Lanterns now publishes its ReShade FX include contract as
[API 0.1.0](Twin-Lanterns/API/0.1.0/), with a machine-readable
[surface registry](Twin-Lanterns/API/0.1.0/PUBLIC_API.json) and
[complete declaration reference](Twin-Lanterns/API/0.1.0/REFERENCE.md). The
versioned package carries the source includes, integrity hashes, architecture
guide, and machine-readable symbol inventory.
Its umbrella include exposes
provider evidence, dual-provider transport, evidence-gated reconstruction, and
the bounded composite. The shared API sources are identical across all three
builds; the Alpha voxel-proxy extension remains separately marked
experimental.

## Quick Install

1. Install ReShade for the target game.
2. Open the selected build directory.
3. Merge its `reshade-shaders` directory into the ReShade installation.
4. Keep the installation's known-good `ReShade.fxh`.
5. Reload ReShade and enable the named Twin Lanterns technique.

Do not install multiple builds at once unless you intentionally want separate
techniques and understand their independent resources and control surfaces.

## Design Boundaries

- Stable and Fidelity Overdrive evaluate four cardinal transport directions at
  half resolution.
- Full Resolution Dual Ray Alpha evaluates one to four opposing direction pairs at
  full resolution and requires compute plus 3D storage support.
- Its voxel lighting is a current-frame camera-visible depth shell, not world
  voxelization, hidden geometry, off-screen geometry, or complete GI.
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
  API/
    0.1.0/            versioned API sources, registry, hashes, and guide
  Stable-1.4/          fixed baseline
  Fidelity-Overdrive/ independent fidelity and overdrive candidate
  Full-Resolution-Dual-Ray-Alpha/ public full-resolution voxel-proxy alpha
tools/
  validate_publication.py
  validate_full_resolution_dual_ray_alpha.py
```

Run the reproducible publication checks with:

```powershell
python -B tools/validate_publication.py
python -B tools/validate_full_resolution_dual_ray_alpha.py
python -B tools/validate_showcase_and_public_api.py
```

The Stable/Fidelity publication result is **13/13 passed**. The separate Full
Resolution Dual Ray structural result is also **13/13 passed**. The showcase
provenance and versioned public API result is **17/17 passed**.

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
