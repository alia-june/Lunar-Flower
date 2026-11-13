# Twin Lanterns — Cached Bounce Composite

A separate Bounce Lab derivative for the reported eight-versus-four-direction
cost in Elden Ring on an RX 7700 XT. It retains the bounce, decay, uncertainty,
color and hard-bound controls. There are no new full-resolution textures or
passes: five RGBA16F working fields and six pixel passes, as in Bounce Lab.

## Cached final composition

Final Image and Applied Light now reuse the first-light field already captured
for the bounce. This removes the repeated surface guide, reconstruction, edge
fill, softening and rendering-intent calculation in the usual production path.
The first capture and both ray gathers retain the same sampling and controls.
No texture, pass or temporal history is added.

The cache contains bounded, faded first light. Reading it does not apply the
first-light fade again. Its RGB is reclamped to the faded contribution and
remaining-channel ceiling, since half-precision storage can round upward.
Valid receivers can still receive bounce when their own first-light admission
is zero. Invalid depth returns the source. For a nonzero first-light peak below
0.0001, with color anchoring and incoming bounce active, the final pass recovers
the precise first color: half subnormals would otherwise destabilize anchoring
near its 0.000001 luminance threshold. Savings therefore vary with the scene. These final/reconstruction reads use
explicit LOD zero so the varying fallback does not depend on implicit gradients.

The inactive-bounce path and metadata diagnostics retain the full computation.
Metadata diagnostic views can cost more than Final Image and show small storage
precision differences. Applied Light uses the same cached path as Final Image.
Do not time the optimization using another diagnostic view.

Compare these matched preset pairs at the same position:

| Cached production | Recomputed reference | Shared directions / traversal budget |
|---|---|---|
| Cardinal4-EqualTraversal | RecomputedComposite | 4 cardinal, 16 / 16 |
| Mixed8-FullDensity | Mixed8-FullDensity-Recomputed | 8 mixed, 16 / 16 |
| Parent32-16 | Parent32-16-Recomputed | 4 cardinal, 32 / 16 |

Each pair changes only `LUNAR_FLOWER_TLPP_CACHE_FIRST_LIGHT` (1 versus 0).
Use Parent32-16 to compare against Bounce Lab's original ray budgets. Start with
Cardinal4-EqualTraversal for the default matched-provider test. To isolate this
optimization, compare a pair before changing ray budgets or direction count.

In the flat valid-depth CPU fixture, final composition falls from **57 texture
calls to 4** (source, depth, captured first light, bounce). That saves 53 calls
per pixel in this fixture, about 195 million calls per 1440p frame. This counts
shader sampling operations, not DRAM traffic, full-effect work or measured GPU
time. The second ray gather remains, so this does not remove all bounce cost.
There is no promised FPS recovery. The original ZIP remains downloadable.

## Install and start

Extract `Twin-Lanterns-CachedBounce.zip` outside ReShade shader search paths and
merge only `reshade-shaders` into the game. Keep the installed `ReShade.fxh`.
Replace the existing `lunar_flower_provider_perf` folder if installed; this uses
the same effect identity and should not be installed as a second copy.
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
normalization, parent-budget equivalence, half-storage bounds and cached/reference output; source/package checks validate
includes, loop sampling, presets and integrity. These checks are not GPU timing.

The five full-resolution fields still use about 140.6 MiB at 1440p before
framework resources. Loop/branch hints and compile-time selection are candidate
compiler aids, not measured speedup claims. See `INVESTIGATION.md` for the owner
report, calculation and pinned ReShade compiler sources.

The existing no-history, bounded extra-gather and artificial-uncertainty limits
from Bounce Lab still apply. Software uses the repository MIT license and
retained notices.
