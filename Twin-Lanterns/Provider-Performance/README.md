# Twin Lanterns — Direction/Provider Performance Probe

A separate Bounce Lab derivative for the reported eight-versus-four-direction
cost in Elden Ring on an RX 7700 XT. It retains the bounce, decay, uncertainty,
color and hard-bound controls. There are no new full-resolution textures or
passes: five RGBA16F working fields and six pixel passes, as in Bounce Lab.

## Install and start

Extract `Twin-Lanterns-ProviderPerf.zip` outside ReShade shader search paths and
merge only `reshade-shaders` into the game. Keep the installed `ReShade.fxh`.
Select the supplied presets and keep other effects, including previous Twin
Lanterns and Fog Guard techniques, disabled for the measurement. The effect is
**Lunar Flower - Twin Lanterns: Provider Performance**.

Start with these three presets at the same scene/camera position:

| Preset suffix | Directions | DDA / march samples per direction | Maximum traversal samples across both gathers |
|---|---:|---:|---:|
| Cardinal4-EqualTraversal | 4 cardinal | 16 / 16 | 256 |
| Diagonal4-EqualTraversal | 4 diagonal | 16 / 16 | 256 |
| Mixed8-EqualTraversal | 8 mixed | 8 / 8 | 256 |
| Mixed8-FullDensity | 8 mixed | 16 / 16 | 512 |

The equal-traversal comparison keeps full ray reach and depth travel, but uses
half the sampling density per direction for the eight-direction case. This can
miss or change hits. It is a quality/cost experiment, not a free quality upgrade.
Successful hits add refinement and donor-guide reads, so equal traversal maxima
do not guarantee equal total texture work or GPU time. Early exits can also
change actual work.

## Isolate provider and bounce cost

Additional preset suffixes:

- **DDA16-Only / March16-Only:** four cardinal directions, one compiled provider,
  16 samples per direction, both gathers. Each permits 128 traversal samples.
- **Parent32-16:** four cardinal directions, both providers, the original
  32/16 budget. It permits 384 traversal samples and preserves the parent's
  tracing math at that budget.
- **FirstPassOnly:** 16/16 and four cardinal directions, with the extra bounce
  disabled. The extra fields remain allocated, but secondary sampling is skipped.
- **Runtime32-16:** original 32/16 budget with the runtime Provider menu. Compare
  with Parent32-16 to investigate runtime branching versus compiled selection.

The presets set ReShade's `PreprocessorDefinitions`. Selecting one should
recompile the effect. The Provider menu is present only in Runtime32-16;
other presets fix the provider at compile time and remove the unused call path.
Do not change Direction Set while recording a named preset's benchmark result,
since that changes the budget described by its filename.

## Measure and interpret

Use **Final Image**, not a provider diagnostic, for timing. Allow compilation to
finish and the scene/frame time to settle. Record ReShade's technique GPU time
where available, total frame time, FPS and image quality in the supplied
`PERFORMANCE_MATRIX.csv`. Keep ReShade Performance Mode consistent across a
comparison; test it as a separate variable. There are no measured results in
the template.

If full-density eight directions costs more than the equal-traversal variant,
sampling work is implicated. If matched DDA and march remain very different,
generated code, hit patterns, refinement and GPU behavior need further profiling.
A DX12-only label does not change Elden Ring's existing DX12 path or turn these
software ray walks into hardware ray tracing.

Both DX11 and DX12 source paths remain supported by design. Actual native shader
compilation, Radeon GPU performance and visual acceptance remain unverified for
this build. C++ fixtures validate budgets, reach, specialization behavior,
normalization and parent-budget equivalence; source/package checks validate
includes, loop sampling, presets and integrity. These checks are not GPU timing.

The five full-resolution fields still use about 140.6 MiB at 1440p before
framework resources. Loop/branch hints and compile-time selection are candidate
compiler aids, not measured speedup claims. See `INVESTIGATION.md` for the owner
report, calculation and pinned ReShade compiler sources.

The existing no-history, bounded extra-gather and artificial-uncertainty limits
from Bounce Lab still apply. Software uses the repository MIT license and
retained notices.
