# Beginning fog- and light-aware shading

Fog carries distance and atmosphere. Light carries color, brightness and
material cues. Our shading should preserve those signals as it adds indirect
light, detail, contrast or stylization.

This is the beginning of a shared direction for our shaders, informed by lessons
from [miXSR_hexer, now defunct](MIXSR_HEXER_RETIREMENT.md). Fog Guard V2 is
our first user-confirmed step. Twin Lanterns supplies bounded light transport
and fine-depth surface checks. Broader per-effect integration is still ahead.

## Lessons from miXSR_hexer

**Lifecycle: Defunct. Disposition: failed research candidate.** It is a
historical audit source. Many named paths are approximations, and the owner
reports research and capability wording carried across AI workspaces. See the
[retirement and provenance record](MIXSR_HEXER_RETIREMENT.md) for current
destinations and the source-inspection log. Related lineage does not transfer
algorithmic claims into the current projects.

The reference review used revision
[`c757632`](https://github.com/dastardlyrat/miXSR_hexer/tree/c7576321950b0a4609d2f9d0e2500528fdad3e80).
Its fog gates, light-respect helpers, shared-mask controls and orchestrator show
the architectural ideas behind this direction. Its own documentation asks
readers to distinguish capability labels, implemented behavior and runtime
evidence. We carry that discipline forward with the protection ideas.

| Reference | Lesson for our shaders |
|---|---|
| [Fog gate](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/Includes/miXSR_FC_FogGate.fxh) | Combine brightness, desaturation, local contrast and depth evidence. Make the estimated coverage visible and tunable. |
| [Light respect](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/Includes/miXSR_FC_LightRespect.fxh) | Inspect light color and chroma changes as well as luminance. Keep protection strength separate from the shading effect's strength. |
| [Shared-mask controls](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/Includes/miXSR_FC_ShaderSharedMaskControls.fxh) | Give effects a consistent protection vocabulary. Treat a valid zero mask and unavailable data as different states. |
| [Orchestrator](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/Orchestrator/miXSR_FC_shared_mask_orchestrator.fx) | Make reference capture, mask generation, processing order and reuse decisions inspectable. A downstream guard needs an actual downstream consumer. |
| [Review workflow](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/README.md#backport-audit-protocol) | Trace a claim through its calculation, pass and composite, then test its visible behavior. A control or technique name alone establishes no capability. |

These are architectural lessons and original guidance for the current work.
No miXSR_hexer shader files are bundled or ported by this publication. Its
[restricted-use notice](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/LICENSE.md)
remains separate from Lunar Flower's license.

## How those lessons shape the work

**Protect the change being applied.** Measure a shader's contribution against
an explicit source reference and reduce that contribution where protection
evidence calls for it. Blanket outside shading is an optional artistic choice;
it should not become the default cost of preserving fog or light.

**Keep fog and light evidence inspectable.** A fog estimate and a bright-light
estimate answer different questions. Keep their diagnostic views and tuning
distinct, even when a final protection stage combines their coverage. Bright
pixels are an image-space light cue, not proof of an engine emissive material.

**Respect surfaces and gradual transitions.** Use the configured ReShade linear
depth interpretation, a documented fallback for missing depth, and soft mask
transitions. Soften protection coverage across compatible depth and luminance;
preserve source texture and silhouettes. The Crystal Spider tile correction
also establishes that sparse probe bounds cannot veto valid fine-depth light.

**Make reference ownership explicit.** A reference needs a capture stage, frame
identity and an intended consumer. A valid black mask means no protection at
that pixel. Missing, stale or wrongly ordered capture needs a safe bypass.
Temporal reuse will need separate motion, disocclusion and validity tests.

**Keep contribution bounds and diagnostics together.** Protection should remain
inside each effect's stated energy, color and surface constraints. Source,
fog estimate, light estimate, protection coverage, applied change and final
image should be available for inspection as the integrations develop.

**Measure the cost.** Shared data can reduce repeated classification work, but
capture textures, passes and mask taps still cost memory and time. Report
native compile results, GPU frame time and visual behavior separately from CPU
tests and source checks.

## What is available today

| Component | Current behavior | Evidence boundary |
|---|---|---|
| [Fog Guard V2](../development/fog-guard-v2/README.md) | Full-resolution current-frame reference, corrected linear-depth support, surface-aware mask softening, late restoration and neutral default outside shading. | User reported the fix works. Shader-extracted CPU tests and package checks pass; native compile logs and GPU timings have not been archived. |
| [Crystal Spider / Twin Lanterns](../Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/TILE_ARTIFACT_FIX_NOTES.md) | Bounded added light; full-resolution depth controls proxy donor admission; the sparse atlas is diagnostic data. | The correction has CPU regression evidence. Combined-stack feedback does not establish isolated shader behavior or GPU timing; this is not a built-in fog or emissive-material classifier. |
| Shared fog/light guidance across the family | The principles on this page and a common review direction. | A shared protection API and native integration in every shader have not been shipped. |

Fog Guard V2 currently combines its fog/light estimates into protection
coverage and blends filtered RGB toward the captured reference. More selective
integration inside each shader could constrain its own contribution before
compositing; that is a next step, not a current capability claim.

## Try the first step

[Download Fog Guard V2](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Lazara-Fog-Guard-V2.zip)
· [Download Crystal Spider - Beta](https://raw.githubusercontent.com/alia-june/Lunar-Flower/main/downloads/Crystal-Spider-Beta.zip)
· [Lazara](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package)

Use **Fog Guard Capture → Crystal Spider / other effects → Fog Guard Restore**.
For existing presets, set **Outside Shade to 0**. Follow the
[installation and migration notes](../development/fog-guard-v2/README.md) when
replacing the effect; the source and saved preset values can differ.

The next integrations should be reviewed against fog gradients, colored lights,
bright armor, desaturated walls, thin geometry, UI, absent depth and small camera
movements. Include source/processed comparisons and mask views, and record the
effect order. These cases will guide adoption one shader at a time.
