# Twin Lanterns

Lunar Flower’s ReShade screen-space indirect-light project. Twin Lanterns gathers
light from visible surfaces, reconstructs it across compatible geometry, and
limits added light by the configured ceiling and remaining output-channel room.

## Current default — Kriespinne / Spoke Lab 2

**[Download Twin Lanterns — Default ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Twin-Lanterns-Default.zip)**

[Install and controls](Twin-Lanterns/Spoke-Lab-2/README.md)
· [Default preset](presets/Twin-Lanterns-Default.ini)
· [SHA-256](downloads/Twin-Lanterns-Default.zip.sha256)
· [All downloads](downloads/README.md)

The default is the owner-preferred **preset 04** configuration: three fixed
primary spokes, linear depth admission, cached donor normals, and two opposing
cached-first-light taps. **Indirect Light Strength is 2.0**. Bounce strength
remains 0.25, retention 0.5, and Maximum Added Light 0.20.

### Install

1. Extract the ZIP outside ReShade’s shader search folders.
2. Merge its `reshade-shaders` folder into your game. Replace an existing
   `lunar_flower_spoke_lab` folder rather than installing a second copy. Keep
   your installed `ReShade.fxh`.
3. Load **Kriespinne-Spoke-Lab-2.ini** from the ZIP. It selects preset 04 and
   strength 2.0 automatically; old presets retain their saved values.
4. Enable **Lunar Flower - Twin Lanterns: Spoke Lab 2**. Keep the game’s working
   depth configuration and disable other Twin Lanterns techniques.

This uses six current-frame working fields and seven passes. The second stage
reads calculated first light; it does not launch secondary ray marches. The
planned third stage and temporal spoke cycling are not implemented. The owner
prefers this configuration in Phantom Brigade; game response can differ.

The source and default values match the versioned
[Spoke Lab 2 ZIP](downloads/Kriespinne-Spoke-Lab-2.zip). FX frontend checks and
previous algorithm-level CPU checks are documented in the
[validation record](Twin-Lanterns/Spoke-Lab-2/VALIDATION.json); they do not supply
native driver compilation or controlled GPU timing.

## Other builds

| Build | Purpose | Download or details |
|---|---|---|
| **Kriegsspinne — Reference Build Candidate 1** | Earlier reference with provider/budget comparisons and a marched extra gather | [ZIP](downloads/Kriegsspinne-Reference-Build-Candidate-1.zip) · [Setup](Twin-Lanterns/Provider-Performance/README.md) |
| **Crystal Spider - Beta + Fog Guard V2** | Earlier voxel-lighting build with Fog Guard Capture → Crystal Spider → Restore and a starter preset | [ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Crystal-Spider-Beta.zip) · [Setup](docs/CRYSTAL_SPIDER_BUNDLE.md) |
| **Stable 1.4** | Original fixed baseline | [Build](Twin-Lanterns/Stable-1.4/) |
| **Fidelity Overdrive** | Independent fidelity and highlight-protection candidate | [Build](Twin-Lanterns/Fidelity-Overdrive/) |
| **No Voxel** | Dual screen tracing without voxel resources; includes Fog Guard V2 | [ZIP](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Twin-Lanterns-No-Voxel.zip) · [Setup](Twin-Lanterns/No-Voxel/) |
| **Direction Lab / Bounce Lab** | Earlier direction, provider and bounce experiments | [Direction Lab](Twin-Lanterns/Direction-Lab/) · [Bounce Lab](Twin-Lanterns/Bounce-Lab/) |
| **Full Resolution Dual Ray Alpha** | Voxel-proxy research source underlying Crystal Spider | [Build and history](Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/) |

[Lazara](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package)
· [Crystal Spider without Fog Guard](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Crystal-Spider-Beta-standalone.zip)
· [Fog Guard V2 setup](development/fog-guard-v2/README.md)

## Gallery

[![Elden Ring with Lazara + Twin Lanterns](Twin-Lanterns/assets/twin-lanterns-gallery-04.png)](Twin-Lanterns/README.md#gallery)

*Earlier Elden Ring capture with Lazara + Twin Lanterns.*

[Gallery and complete comparison frames](Twin-Lanterns/README.md#visual-comparison)
· [Three-state comparison](Twin-Lanterns/assets/twin-lanterns-full-lazara-comparison.png)
· [Comparison evidence](Twin-Lanterns/assets/twin-lanterns-full-lazara-comparison.json)

The captures contain third-party game imagery, outside the MIT software grant.
Effect-state labels are user-supplied; the images do not establish isolated
shader performance or compilation success.

## Research and development

- [Fog- and light-aware shading](docs/FOG_AND_LIGHT_AWARE_SHADING.md): preserve
  atmospheric depth, light color and detail, informed by lessons from
  [miXSR_hexer, now defunct](docs/MIXSR_HEXER_RETIREMENT.md).
- [Shader development Mill](development/mill/README.md): source snapshots,
  working candidates, test evidence and packages.
- [Public API 0.1.0](Twin-Lanterns/API/0.1.0/): versioned ReShade FX include
  contract, [surface registry](Twin-Lanterns/API/0.1.0/PUBLIC_API.json) and
  [declaration reference](Twin-Lanterns/API/0.1.0/REFERENCE.md).
- [Lunar Flower AI Seed](theory/README.md): a separate proposed AI architecture;
  [canonical theory](https://github.com/alia-june/ethical-and-intellectual-theory/blob/main/blue-prints/LUNAR_FLOWER_AI_SEED_EXPERT_SYSTEM_CONTRACT.md).
  It does not describe a capability implemented by these shaders.

Twin Lanterns works with current-frame screen evidence. It cannot recover hidden
or off-screen geometry, and its depth-based lighting is an approximation rather
than complete GI. Added light is nonnegative and bounded; denoising and temporal
stabilization remain external effects. Each build documents its own resources,
validation and practical limits.

## License and authorship

[MIT License](LICENSE). Keep the copyright and license notice with copies or
substantial portions of the software.

Project direction and authorship: **alia june**. Documentation and validation
tooling were prepared with AI assistance under the author’s direction.
