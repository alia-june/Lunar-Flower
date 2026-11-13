# Cached Bounce error log

## C++ / ReShade FX language mismatch — reserved identifier

**Status:** source corrected and regression guard added; corrected native
ReShade compilation and in-game performance still require verification.

**Affected build:** Cached Bounce, commit
`db6f9ebba0661788f22bcc40c78e0104903b2380`.

The owner supplied an Elden Ring log from ReShade 6.7.3. The same Provider
Performance failure appears at 03:36:49 and 03:37:20:

```text
LUNAR_FLOWER_TwinLanterns_ProviderPerf.fx(951, 42):
error X3000: syntax error: unexpected 'precise', expected 'identifier'
```

The new near-black cache fallback declared a local composite-evidence variable
named `precise`. That identifier is legal C++, but `precise` is a reserved
shader qualifier. ReShade FX rejected the declaration, so the effect could not
load. This incident is a syntax failure, not the earlier X3511 loop-unrolling
failure or evidence of a GPU timing problem.

### Validation mismatch

| Check | What happened | What it establishes |
|---|---|---|
| Shader-extracted C++ fixtures | Passed all 130,561 assertions across eight configurations | Math, simulated sampling, half conversion, bounds and dispatch under C++ shims |
| Source/include/loop checks | Passed | Include integrity and absence of implicit gradients in the audited call graphs |
| ReShade FX compilation on the owner's machine | Failed with X3000 | The shipped shader was not accepted by the target language |

The C++ fixtures translate FX functions into C++ and emulate textures/vector
operations. They do **not** run the FX parser, generate DXBC, invoke FXC/DXC,
exercise driver behavior or measure GPU performance. C++ accepts some names and
constructs that the shader language rejects. Passing those fixtures must never
be described as native shader compilation or proof that a download loads.
The earlier 57-to-4 read comparison remains a synthetic operation count; no
in-game performance gain was established by this failed build.

### Correction and prevention

- Rename the local variable to `uncachedFirst`; retain the cached lighting math.
- Check shader declarations for reserved qualifier names before packaging.
  Regression cases reproduce `precise`, `sample` and `groupshared` used as
  identifiers, while permitting qualifiers in their proper position.
- Rerun the C++/source/package checks and replace the affected download.
- Keep native compilation and GPU timing marked unverified until target-system
  evidence is available. The declaration guard is deliberately limited and is
  not a replacement for a real ReShade FX parser/compiler.

The GitHub issue API returned HTTP 403 in this session. This repository record
is the published error log; no GitHub issue was created.
