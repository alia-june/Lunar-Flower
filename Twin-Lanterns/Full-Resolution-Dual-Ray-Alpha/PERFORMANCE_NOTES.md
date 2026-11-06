# Performance investigation

Date: 2026-11-06. The user reports that Dual Ray reduces Elden Ring to 30 FPS,
without the same problem in DS3. Reducing ray pairs and voxel strength reportedly
did not improve FPS. Render resolutions, baseline FPS, exact installed revision
and ReShade GPU timings have not yet been supplied. These observations do not
establish which pass is expensive or whether a presentation threshold is involved.

## Confirmed source-level work removed

- The preceding adaptive candidate skipped per-ray voxel tracing at zero voxel
  strength but still built the hierarchy every frame. The Alpha effect now uses
  a guarded compute entrypoint. Final Image with voxel strength zero skips node
  construction. Voxel diagnostic views still request a fresh build, even at zero
  strength, so they do not read a stale tree.
- Source Image, and disabled/zero-strength Final Image, skip lighting work in
  the compute, raw transport, resolve and display paths. Intermediate passes
  write empty fields; display reads the source once. Positive strengths are not
  rounded into this bypass. Diagnostic views retain their intended behavior.
- Raw transport builds one receiver guide and reuses it across directions and
  screen/voxel providers. Invalid receivers return before evaluating directions.
- Final reconstruction, edge fill and receiver admission reuse one center guide.

All working fields remain full resolution. Ray counts, traversal budgets,
hierarchy detail, donor admission, reconstruction and additive bounds are not
reduced. Public standalone experimental wrappers remain available; the Alpha
effect chooses the guarded/cached variants.

## CPU evidence, not a GPU benchmark

`tools/test_twin_lantern_inactive_work.py` compiles shader-extracted functions
with explicit CPU texture/vector shims. It compares cached and independently
recomputed guides for flat, stepped and color-varying fixtures, compares raw
direction accumulation, and compares final color/contribution/diagnostics. It
also executes the effect's compute/working/display guards and counts texture
operations. Existing hierarchy, refinement, boundary and installation fixtures
remain separate checks.

For receiver setup, each eliminated guide removes five depth reads in the CPU
fixture. With four active directions, source-level receiver setup changes from
20 reads (screen only) or 40 reads (screen plus voxel) to five. Final center-guide
reuse saves six reads when Edge Fill is active, or one when it is bypassed. These
counts exclude donor/traversal and neighbor reads. GPU compilers/caches may
already reuse some work; these are not measured GPU instruction or timing gains.

The fixed render targets, draw/dispatch calls, resource transitions and ReShade
frame-copy overhead remain. The new Source Image path is therefore not equivalent
to disabling the entire technique. This candidate does not establish that the
reported 30-FPS limit is resolved.

## Required in-game comparison

Use the same scene/camera and resolution, with other ReShade techniques off.
Record FPS and the technique's GPU milliseconds, if available, for:

1. Entire technique unchecked in the effect list.
2. Technique enabled, Output View = Source Image (the new lightweight path).
3. Final Image, voxel strength zero, one opposing ray pair.
4. Final Image with the intended voxel strength and pair count.

Turning off the inner Enable Indirect Light control is not the same as disabling
the entire technique. A 30-FPS display rate is about 33.3 ms per presented frame,
not necessarily 33.3 ms spent in this shader. Changes can also remain hidden by
presentation/VSync thresholds, so GPU timings are preferable to FPS alone.

Check that Voxel Detail Level exists in Output View to distinguish the adaptive
line from older copies. Install matching effect/includes together and capture a
fresh compile log. The current candidate still needs native compile, in-game
output comparison and timing; no Elden Ring or DS3 GPU measurements were made in
the cloud executor.
