# Defunct research and approximation log

miXSR_hexer is **defunct**, with the owner-directed disposition **failed research candidate**, effective November 10, 2026. This record preserves the distinction between a research idea, its approximation, an implemented path and demonstrated runtime behavior.

## Research bleed across AI workspaces

The owner reports that research concepts, approximations, partial implementations and capability wording bled across AI workspaces and shader generations. That history is recorded as an owner report. A complete per-file transfer history has not been reconstructed, so this log does not invent sessions, authors, dates or causal chains.

Many effects in this lineage use approximations. Approximation is a valid research technique when described accurately; it must not silently become a claim of a complete named algorithm. An inherited label, repeated explanation or compilation success alone cannot establish algorithmic equivalence.

The older README mentions roughly one hundred suspected claims. That is a historical estimate, not an independently verified defect count. The entries below are scoped examples from revision `c7576321950b0a4609d2f9d0e2500528fdad3e80`, not an exhaustive judgment of every shader.

## Source-inspection findings

| ID | Finding | Accurate description | Source |
|---|---|---|---|
| MX-001 | Fog coverage is inferred from brightness, desaturation, local contrast and depth. This is an image-space estimate, not access to the engine fog volume or a participating-media simulation. | Heuristic image-space fog protection estimate. | [`FC_FOG_Core`, `FC_FOG_DepthMask`](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/Includes/miXSR_FC_FogGate.fxh) |
| MX-002 | Light/emission coverage is inferred from luminance, peak channel and saturation thresholds; it is not an engine material-emission classification. | Bright/color light protection estimate. | [`FC_LIGHT_EmissionMask`](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/Includes/miXSR_FC_LightRespect.fxh) |
| MX-003 | The inspected path combines custom directional smoothing with horizontal, vertical and diagonal neighborhood blends. FXAA/SMAA-style labels do not establish canonical FXAA or full SMAA algorithm equivalence. | Custom directional and edge-aware neighborhood anti-aliasing approximation. | [`FDOAA_MainPS`](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/AA/miXSR_FC_bio_fibonacci_fxaa_smaa.fx) |
| MX-004 | The inspected offset uses a finite, explicitly expanded chain of direction transforms and fixed weights. Its recursive/bio/Fibonacci naming does not establish adaptive recursive image processing or a biological model. | Finite golden-ratio-inspired direction and sampling construction. | [`FDOAA_OrganicRecursiveOffset`](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/AA/miXSR_FC_bio_fibonacci_fxaa_smaa.fx) |
| MX-005 | The inspected path samples offset screen color/depth and aggregates bright depth-compatible samples. Ray-M/gloss naming alone does not establish physically correct reflection tracing or access to hidden/off-screen geometry. | Bounded screen-space sampled gloss heuristic. | [`FDRMGLOSS_AccumulateRayStep`, `FDRMGLOSS_RayMarchDirection`](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/GlossSSR/miXSR_FC_bio_raym_gloss_material_response.fx) |
| MX-006 | The presence helper tests nonzero mask content, while the nonzero cache modes select shared-cache use without establishing freshness in these helpers. Valid zero coverage must be distinguished from missing data; capture order and lifetime need independent evidence. | Shared mask selection with a separately required availability/freshness contract. | [`MIXSR_SHARED_HasSharedGateCache`, `MIXSR_SHARED_UseSharedGateCache`](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/Includes/miXSR_FC_ShaderSharedMaskControls.fxh) |

These findings describe the inspected code. No fresh native compilation, runtime equivalence test or performance benchmark is asserted. The overall failed-candidate disposition does not mean that every individual calculation fails.

## Migration rule

Carry forward a lesson only with the source revision, exact function/pass, calculation, required inputs, approximation boundary and evidence state. Give a new implementation its own tests and claims. Keep fog/light masks, valid zero coverage, missing data, temporal history, source preservation and final-composite behavior explicit.

Each follow-up record should identify the donor and destination repositories, relevant revisions, what was reused conceptually or changed in code, which claims were rejected or narrowed, and the checks actually performed. An unknown provenance link stays unknown.

## Current destinations

- [Lunar Flower / Twin Lanterns](https://github.com/alia-june/Lunar-Flower): Twin Lanterns / Crystal Spider development, bounded indirect light, current Fog Guard V2 delivery and documented evidence.
- [Lazara ReShade Revival Package](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package): Curated preset integration and ordered color/luma/detail workflow; Fog Guard V2 is currently delivered through Lunar Flower.
- [Occult Box](https://github.com/dastardlyrat/Occult-Box): Individual effects and primitive/helper collection; consult effect-specific status and validation.
- [OpenSurface Camera Obscura Guided Detail](https://github.com/dastardlyrat/OpenSurface-CameraObscura-GuidedDetail): Surface-aware detail reclamation and ink-line work.

The existing [restricted-use notice](https://github.com/dastardlyrat/miXSR_hexer/blob/c7576321950b0a4609d2f9d0e2500528fdad3e80/LICENSE.md) is unchanged. Retirement and this log do not grant redistribution rights or relicense historical shaders. See [the structured record](RESEARCH_PROVENANCE_LOG.json) and [lifecycle status](STATUS.json).
