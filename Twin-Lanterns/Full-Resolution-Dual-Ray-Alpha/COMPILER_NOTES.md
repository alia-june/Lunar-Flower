# Native compiler correction

2026-11-06: a user-supplied Elden Ring/ReShade log reports X3570 (gradient
instruction in a varying loop) followed by X3511 (forced unroll too large).
It also reports an existing texture with the old atlas name and incompatible
dimensions. The failed native compile overrides earlier CPU/static readiness
claims for that installed candidate.

## Sampling correction

The shared `CAMERA_OBSCURA_LoadColor` uses `tex2D`, which requires implicit
derivatives. Alpha screen donors and the adaptive voxel tracer called it from
varying loops. Those Alpha reads now use `tex2Dlod(..., 0)` explicitly. The
back-buffer donor is sampled at its base level, without forcing the ray loops
to unroll. The fixed Stable/Fidelity sources and eight shared API includes are
unchanged.

The official [ReShade include](https://github.com/crosire/reshade-shaders/blob/slim/Shaders/ReShade.fxh)
was inspected online; its `GetLinearizedDepth` already uses `tex2Dlod`. The
installed known-good ReShade.fxh remains an external dependency. A custom include
that introduces implicit derivatives in depth helpers needs separate inspection.

`tools/audit_twin_lantern_loop_sampling.py` follows the project-source call graph
from Alpha transport and compute/trace entrypoints and rejects reachable implicit
sampling/derivative intrinsics. Negative controls reintroduce the indirect shared
loader into each donor path and verify detection. The package tool invokes this
audit before creating a ZIP, with a test proving unsafe code is refused.

This audit does not implement the HLSL/ReShade parser, validate every external
include, or replace FXC. CPU texture shims previously hid this compiler-only
constraint; their numerical checks remain separate evidence.

## Resource identity

The 64×36×21 RGBA32F adaptive atlas now uses texture/storage/sampler names with
the `LUNAR_FLOWER_TLAdaptiveAtlasV1` prefix, separating its layout from the former
64×36×32 volume. Future incompatible atlas layouts must change this identity.
This prevents cross-version resource aliasing; it does not remove duplicate
effect files from a game installation.

## Acceptance still needed

Install the matching effect and includes together, reload, and preserve the new
native compile result. If the same-filename resource warning persists, inspect
the full log's effect paths for a remaining older copy. The supplied repair tool
can back up duplicate/obsolete files in the standard shader tree.

The corrected candidate has source and CPU checks. FXC/ReShade native compilation
and GPU performance were not executed in this Linux environment; no fresh native
pass is claimed until a corresponding result is available.

## Supplied historical compiler evidence

The November 7 upload includes a hash-matched offline compiler report for the
older `a07c3ee` Alpha and historical Stable/Fidelity sources. It reports DXBC
entry compilation with warnings. Source comparisons and evidence limits are
recorded in the [uploaded-build review](reviews/2026-11-07-uploaded-build/REVIEW.md).
That report is preserved separately and does not certify compilation of this
later adaptive/explicit-LOD candidate.
