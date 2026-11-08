# Review of the November 7 uploaded Alpha

The upload helps identify the voxel failure and adds historical compiler
evidence. It contains no new shader fixes to transplant: **all 11 shader/include
files are byte-identical to commit
[`a07c3ee`](https://github.com/alia-june/Lunar-Flower/tree/a07c3eed657ead4f4ce3860010bfb8d293193e3e)**.
The user confirmed the visually broken voxel build was this uploaded ZIP.
It predates the adaptive atlas, inactive-work guards, explicit-LOD correction,
resource versioning, and fine controls in the current candidate.

The archive hash, source comparisons, and limits are recorded in
[MANIFEST.json](MANIFEST.json). No uploaded instructions were executed and no
uploaded shader replaced the current implementation.

## Why the uploaded voxel path can look wrong

It stores tile-center color and occupancy in a fixed 64×36×32 volume. At
2560×1440 each XY tile spans **40×40 pixels**; more Z samples do not make XY
tiles smaller. Point fetching repeats that center color across the tile.
The tracer accepts occupied cells without rechecking full-resolution donor
depth, donor surface direction, or self-hit distance. A shared normalized-depth
bin is weak surface evidence: its width, 1/32, is much larger than typical fine
ray-hit tolerances.

These mechanisms explain why successful compilation can coexist with blocks,
broad added light, and boundary contamination. Their individual contributions
to a particular game capture are not measured here.

## Executed comparison

The reproducible tool executes the historical and current voxel functions with
the existing C++ vector/texture shims at 2560×1440:

```sh
python -B tools/compare_uploaded_alpha_voxels.py --archive <original-upload.zip>
```

It requires the uploaded voxel include's exact hash and a C++17 compiler.
Separate texture storage preserves each representation. These are actual
shader functions with synthetic CPU reads, not native compiler, GPU,
performance, or visual validation.

| Fixture | Uploaded | Current |
| --- | --- | --- |
| Two colors within one root tile, red channels | 0.8 / 0.8 | 0.1 / 0.8 |
| First accepted flat sample, 24 px ray / 32 steps | 0.75 px away | About 2.25 px, outside 1.5 px exclusion |
| Occupied coarse cell but incompatible fine depth | Hit accepted | Hit rejected |

The first reproduces coarse-color repetition; the second demonstrates voxel
self-sampling despite the already-fixed screen provider. The third isolates
missing fine-depth admission. Current code addresses these three cases;
this is not a universal visual pass.

## Review of the change sequence

| Change | Assessment and remaining limit |
| --- | --- |
| Full-resolution fields and 1–4 opposing ray pairs | Coherent quality experiments, with cost scaling with pixels and directions. Not a performance fix. |
| 24→32 shared ray budget | Consistent with 32 advertised samples. Increases density within the same distance and can increase cost. March retains its separate 16-step limit. |
| Old 64×36×32 color/occupancy volume | Unsuitable as direct fine-surface radiance. Do not restore it from this upload; more depth steps cannot repair XY color blocks. |
| Robust screen normals and removal of blanket edge-confidence loss | Addresses demonstrated contour holes. More light near valid edges is an intended consequence; reconstruction rejection still matters. |
| Guarded refinement and selected-hit confidence recomputation | Retain. Self-distance, UV and valid-depth checks address demonstrated invalid refinement cases; general ray intersection correctness remains unproven. |
| Adaptive atlas and fine donor fetch | Supported by the comparisons above and hierarchy fixtures. It is a bounded screen/depth quadtree, not world GI or guaranteed subdivision of every visible feature. |
| Child clearing and versioned resource names | Necessary for topology/layout changes; prevents stale children and incompatible resource reuse. Does not clean duplicate effect files. |
| Explicit base-LOD sampling | Retain to avoid implicit gradients in varying loops. Older-build compile success does not certify the later loop graph. |
| Inactive-work guards and receiver-guide reuse | Numerically checked optimizations that reduce known unnecessary work. Passes/targets remain; Elden Ring FPS improvement is not established. |
| Fine Strength / Depth Agreement controls | UI-only, preserving names, scales, ranges, defaults and shader math. Wider depth tolerance admits more neighboring light and can brighten/soften the result. |
| Fine controls backported to Stable/Fidelity | Appropriate UI-only backport; historical-source restoration checks confirm their implementations were preserved. |

Adaptive work is scene-dependent: five probes per node mean 11,520 depth and
11,520 color reads for uniform roots, up to 241,920 of each when all 21 records
per root are built. The older volume repeats its tile-center reads across
73,728 voxel invocations. Thus adaptation reduces uniform-scene build reads
but can increase them in a fully subdivided scene. These are source-level
counts, not GPU timings; adaptation should not be presented as an unconditional
performance improvement.

## What can be reused

The supplied [compiler report](RESHADEFX_COMPILE_RESULTS.json) is preserved
byte-for-byte. It records HLSL generation for three modules and 16 successful
DXBC entry compilations, including six Alpha entries. Nine entries carry
X4000 warnings across the variants. Alpha and Fidelity effect hashes match
historical files; Stable's hash matches the historical source with CRLF line
endings. This is user-supplied historical evidence, not independently
reproduced compilation here.

The external ReShade include, compiler binaries, generated HLSL and DXBC files
are absent. The report identifies its ReShadeFX compiler as `6.8.0 UNOFFICIAL`;
the earlier game log identified ReShade 6.7.3. It does not certify a current
candidate, game backend, or voxel correctness. The potentially-uninitialized
warnings remain open: without generated HLSL they cannot be dismissed as
harmless or established as the visual cause.

The uploaded shaders serve as negative controls. Their useful screen/refinement
fixes are already retained; copying the whole upload back would discard later
corrections.

## Remaining design questions

- Five probes and two subdivision levels can miss thin geometry and cause
  changing support under motion. Fine color fetch does not guarantee complete
  or temporally stable occupancy.
- Screen and voxel providers derive from the same camera buffers. Their
  confidence union can raise evidence for correlated observations. Its effect
  on brightness and boundary masking needs an isolated current-build comparison;
  bounded output does not validate that confidence model.
- Nearby coplanar donors can resemble a local brightness lift. Self-distance
  rejection alone cannot establish physical GI, visibility or conservation.
- Native compilation, GPU scheduling, Elden Ring frame time and current-build
  visual acceptance remain separate gates.

Use the current candidate for the next comparison. Capture Source, Applied
Light and Final with one fixed camera/settings, first screen-only, then varying
voxel authority. Do not mix old includes with the current effect. This review
changes evidence and review tooling only; it makes no shader-algorithm or
preset changes.
