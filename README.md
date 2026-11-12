# Twin Lanterns

### Crystal Spider - Beta · by Lunar Flower

**[Download Crystal Spider - Beta + Fog Guard — ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Crystal-Spider-Beta.zip)** · [Lazara](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package) · [Installation and package details](downloads/README.md#crystal-spider---beta) · [Gallery](Twin-Lanterns/README.md#gallery)

[![Elden Ring with Lazara + Twin Lanterns](Twin-Lanterns/assets/twin-lanterns-gallery-04.png)](Twin-Lanterns/assets/twin-lanterns-gallery-04.png)

*Elden Ring — [Lazara](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package) + Twin Lanterns.*

The download now bundles Crystal Spider with Fog Guard V2 and a starter preset.
Extract the ZIP outside ReShade's shader search folders, merge its
`reshade-shaders` folder into your game, and select the included
`Crystal-Spider-Beta.ini` in ReShade. Keep your installed `ReShade.fxh`.

The preset enables **Fog Guard Capture → Crystal Spider → Fog Guard Restore**,
with **Outside Shade = 0**. To retain an existing Lazara/custom stack, keep its
preset and use that order around the effects you want protected.
[Bundle setup and contents](docs/CRYSTAL_SPIDER_BUNDLE.md) ·
[Crystal-only ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Crystal-Spider-Beta-standalone.zip).
Crystal Spider retains its Twin Lanterns Alpha technique/control identifiers.

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

## AI theory — Lunar Flower Seed

The [Lunar Flower AI Seed](theory/README.md) is a separate proposed architecture: AI under an expert-system contract for constrained orchestration, with tools and structure built from the ground up and generative synthetic decisions as a last resort. [Read the canonical theory](https://github.com/alia-june/ethical-and-intellectual-theory/blob/main/blue-prints/LUNAR_FLOWER_AI_SEED_EXPERT_SYSTEM_CONTRACT.md). This does **not** describe a capability implemented by the shaders in this repository.

## Beginning fog- and light-aware shading

We are beginning a broader approach to our shaders: preserve atmospheric depth,
light color and surface detail while applying controlled shading. Lessons from
[miXSR_hexer, now defunct](docs/MIXSR_HEXER_RETIREMENT.md)—fog gates, light
respect, shared masks and visible diagnostics—help guide this work. It is a
retired, failed research candidate whose approximations and inherited claims
require audit. Current implementations need their own evidence.

[Fog Guard V2](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Lazara-Fog-Guard-V2.zip)
is the first user-confirmed step: capture fog/light evidence before processing,
then restore protected regions afterward. Twin Lanterns contributes bounded
light and fine-depth surface checks. Integration across the shader family is
beginning; each effect will need its own validation.

[Read the approach and lessons learned](docs/FOG_AND_LIGHT_AWARE_SHADING.md)
· [Fog Guard setup](development/fog-guard-v2/README.md)
· [Lazara](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package)

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
| [No Voxel](Twin-Lanterns/No-Voxel/) | Separate test build; native compile and live acceptance pending | Full-resolution dual screen tracing with voxel lighting, compute pass and 3D atlas removed |

`Stable-1.4` is preserved as the user-designated fixed line. Fidelity
Overdrive and Full Resolution Dual Ray Alpha are staged beside it rather than
replacing it.

All three builds now carry the accepted fine Strength (`0.001`) and Surface
Depth Agreement (`0.00001`) drag controls. Stable and Fidelity received only
those UI changes; their implementations and preset values remain intact.
Combined and standalone packages are available in [downloads](downloads/).

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
Keep the repository ZIP and its extracted tree outside ReShade effect search
paths; merge only the selected build's `reshade-shaders` folder. For duplicate
Alpha entries or the obsolete non-Alpha compile error, see the
[Alpha installation repair](Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/README.md#repair-a-duplicate-installation).

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

The [shader development Mill](development/mill/README.md) provides a local
workspace for frozen source, working candidates, test evidence and packages.
Its initial deployment is running; native compiler and live game checks remain
separate from the passing CPU/source checks.

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
Resolution Dual Ray structural result is **23/23 passed**. The showcase
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

## Machine-readable entry points

```text
IF reader = heuristic engine THEN read ai.landing.pad.json.
ELSE IF reader = AI THEN read ai.landing.pad.low-mem.json.
ELSE continue with the human README.
IF a required reference fails to resolve THEN stop the dependent step AND report the unresolved reference.
```

[Heuristic engine landing pad](ai.landing.pad.json) · [AI landing germ](ai.landing.pad.low-mem.json)
