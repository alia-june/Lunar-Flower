# Direction/provider performance investigation

## Owner report

The owner reports a large DDA-associated performance loss in the latest Bounce
Lab build, in **Elden Ring on an AMD RX 7700 XT**. They subsequently clarified
that the loss depends on **eight versus four directions**, and that roughly
30 FPS may have been coincidental. The owner later isolated the bounce versions and reported **60 to 40 FPS with
VSync enabled**: displayed frame time changes from 16.67 to 25 ms (8.33 ms).
This is not an isolated GPU timing because the 60 FPS cap can hide headroom
and synchronization affects presentation. No per-technique GPU timings have
been supplied.

The earlier “light adaptation” discussion was conceptual, not a request for an
exposure feature. This probe adds no exposure or adaptation control.

## Source findings

- Elden Ring's current renderer is DX12. A DX12-only restriction would not change
  the API path already used for this report.
- Bounce Lab permits 32 DDA and 16 march traversal samples per direction. Both
  providers can run in both the first and extra gathers.
- Four directions with both providers therefore permit 384 traversal samples
  per pixel across the two gathers; eight permit 768. DDA-only is 256 versus
  512. March-only is 128 versus 256.
- Direction count averages the resulting energy, but it does not average away
  the work. Successful hits also add refinement and donor-guide reads.
- The shader is software screen-depth traversal in pixel passes. It does not
  use DXR hardware ray tracing. The DDA name alone implies no acceleration over
  march; this implementation walks uniformly spaced screen-depth intervals.

These findings support a workload explanation. They do not prove the exact
runtime bottleneck, which can also depend on early exits, cache behavior,
compiler decisions and register pressure. No measured speedup is claimed.

## ReShade API/compiler evidence

Reviewed official ReShade **v6.7.3**, commit
`4a50d1eddace85734871d91792ff214f13f66c01`:

- [Runtime shader-model selection](https://github.com/crosire/reshade/blob/4a50d1eddace85734871d91792ff214f13f66c01/source/runtime.cpp): DX11 uses shader model 5.0; DX12 uses 5.1. Both use the DXBC code-generation path.
- [DXBC compiler implementation](https://github.com/crosire/reshade/blob/4a50d1eddace85734871d91792ff214f13f66c01/source/effect_codegen_dxbc.cpp): generated HLSL is passed to `D3DCompile` in both cases. This is not an automatic DXIL/SM6/DXR performance upgrade for DX12.
- Runtime source selects optimization level 3 with ReShade Performance Mode and
  level 1 otherwise, and specializes uniform values in Performance Mode. That
  is a useful additional comparison, with the same mode held constant across
  benchmark presets.
- Runtime source loads preset `PreprocessorDefinitions`, including effect-local
  definitions. The supplied presets use this supported mechanism to select
  sample budgets and remove an unused provider call path before compilation.

The owner's current installed ReShade version was not reconfirmed; this source
review describes v6.7.3, not proof of their exact generated shader assembly.
CPU/preprocessor checks in this workspace do not establish native SM5.0/5.1
compilation or AMD driver/GPU performance.

## Targeted experiment

Keep the game, camera, resolution, scene, Direction Set, other effects and
ReShade Performance Mode fixed where the comparison requires it. First compare
four cardinal / four diagonal / eight mixed directions with the same **maximum
traversal** budget. Then compare eight directions at full density, and isolate
matched DDA-only/march-only workloads. Lower density can change hit coverage and
appearance; evaluate quality alongside GPU milliseconds.

This probe preserves ray length and normalized depth travel when the sample
count is lowered. Changing the shared ray-builder maximum would incorrectly
shorten 24-pixel rays when selecting 16 samples; the new budget is applied only
to traversal density.

No backend is dropped. No previous build/download is replaced, and the original
cardinal/diagonal and bounce/uncertainty experiments remain available.

## Cached first-light implementation

The previous capture pass evaluated the shaped first composite, stored its
bounded light in RGBA16F, and then the final pass evaluated the same first
composite again. The optimized Final Image / Applied Light paths read that
existing field and the completed bounce instead. A compile-time cache switch
and three matched preset pairs retain the recomputed reference for comparison.
Ray schedules, both gathers, strength/decay defaults and resource counts remain
unchanged. This specifically targets duplicate composition; the full second
ray gather remains an additional cost.

After reading the cache, clamp first light to the faded per-channel ceiling.
Apply the existing anchor and fade to the extra light and admit only remaining
room. Do not multiply the first light by fade again or use own admission to
suppress incoming bounce. Recover precise first light when its nonzero peak is
below 0.0001 and color anchoring plus incoming bounce are active, preventing
half-subnormal color/threshold artifacts. Other diagnostics retain full metadata
computation, and zero bounce retains the original first-pass-only path.

C++ fixtures emulate RGBA16F first-light storage, compare against full-precision
composition, sweep the near-black anchor threshold, test source/channel/fade
bounds and count actual shader-extracted sampling calls. The flat-depth final
pass uses 4 rather than 57 texture calls, a reduction of 53 in that fixture;
this is not a native compilation result or measured GPU speedup.
