# miXSR_hexer — Defunct

**Status: Defunct.** Effective November 10, 2026, by project-owner direction.
**Disposition: failed research candidate.** It is retained as historical
research and audit material, with no recommendation for new installations or
ongoing development in that line.

## Continue in the current repositories

| Repository | Direction |
|---|---|
| [Lunar Flower / Twin Lanterns](https://github.com/alia-june/Lunar-Flower) | Crystal Spider, bounded indirect light, current Fog Guard V2 delivery and implementation evidence. |
| [Lazara ReShade Revival Package](https://github.com/dastardlyrat/Lazara-Reshade-Revival-Package) | Curated preset integration and ordered color/luma/detail processing. The Fog Guard V2 update is currently delivered through Lunar Flower. |
| [Occult Box](https://github.com/dastardlyrat/Occult-Box) | Individual effects and primitive/helper work, with effect-specific status and validation. |
| [OpenSurface Camera Obscura Guided Detail](https://github.com/dastardlyrat/OpenSurface-CameraObscura-GuidedDetail) | Surface-aware detail reclamation and ink-line work. |

These projects have their own scopes, implementation states and licenses.
This redirect does not certify every effect or carry legacy claims forward.

## Approximations and research bleed

Many effects in this lineage use approximations of the techniques suggested by
their names. An approximation can be useful research; it must be identified as
such. A capability label, repeated explanation, shared helper or successful
compile does not establish equivalence to the named algorithm.

The owner reports that concepts, partial implementations and capability wording
bled across AI workspaces and shader generations. That report is logged
explicitly. A complete file-by-file workspace history has not been reconstructed;
we do not invent transfers, sessions, authors or causal chains.

The [research and approximation log](../development/lineage/miXSR_hexer/RESEARCH_PROVENANCE_LOG.md)
records six scoped findings from revision `c757632`: image-space fog estimation,
bright-light estimation, custom FXAA/SMAA-style blending, finite direction
construction described as recursive, sampled screen-space gloss, and
shared-cache validity concerns. Each entry names its file/functions and links
to the inspected source. The machine-readable record includes source hashes.

The old roughly-one-hundred suspected-claims estimate is historical, not an
independently verified defect count. Project retirement does not establish that
every individual calculation fails. No fresh native compile or runtime
equivalence test is claimed by this documentation update.

## Record and upstream publication

- [Lifecycle record](../development/lineage/miXSR_hexer/STATUS.json)
- [Structured research log](../development/lineage/miXSR_hexer/RESEARCH_PROVENANCE_LOG.json)
- [Apply-ready retirement patch](../development/lineage/miXSR_hexer/mark-defunct.patch)

Lunar Flower publishes this owner-directed status and log. Updating the original
`dastardlyrat/miXSR_hexer` repository was blocked by GitHub: the current
`alia-june` login lacks write access. Its upstream README is therefore unchanged
until the patch is applied with an account that has access.

The patch adds the Defunct banner, current-repository redirects, lifecycle JSON
and research log. Apply it in a clean miXSR_hexer checkout based on
`c7576321950b0a4609d2f9d0e2500528fdad3e80` with
`git am /path/to/mark-defunct.patch`. It changes documentation only; historical
shader files and the existing restricted-use notice are preserved.
