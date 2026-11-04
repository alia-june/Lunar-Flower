# Twin Lanterns Public API

Twin Lanterns exposes its evidence, transport, reconstruction, and bounded
composite stages as a ReShade FX include API. The shared public surface is
version **0.1.0** and is recorded in the machine-readable
[API registry](PUBLIC_API.json).

This is a shader include contract, not a binary ABI or web service. The API is
public and source-available under MIT, but remains pre-1.0. Structural checks
cover the published paths, symbols, version, include closure, and identical
shared sources. A clean compile inside every downstream effect remains the
consumer's integration gate.

## Entry Include

From an effect in the packaged `camera_obscura/effects` directory:

```hlsl
#include "ReShade.fxh"
#include "../api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh"
```

The composite include is the umbrella entrypoint. Its transitive include graph
is:

```text
TwinLanternComposite
  -> TwinLanternReconstruction
     -> TwinLanternTransport
        -> TwinLanternProviderProofCommon
           -> EntryCapability + AtomicDebug
              -> AtomicCommon
        -> EntryTraversal
           -> EntryCapability
```

The entry capability binds the implementation to `ReShade::BackBuffer` and
`ReShade::GetLinearizedDepth`. Consumers therefore need a working depth buffer
and must include their installation's compatible `ReShade.fxh` first.

## Published Contracts

| Stage | Evidence type | Constructor | Main entrypoint | Contract |
|---|---|---|---|---|
| Provider | `CAMERA_OBSCURA_API_TwinLanternProviderEvidence` | `CAMERA_OBSCURA_API_DefaultTwinLanternProviderEvidence` | `CAMERA_OBSCURA_API_BuildTL45Evidence` | Builds an inspectable single-provider trace result, including receiver, ray, hit, interval, confidence, and rejection evidence. |
| Transport | `CAMERA_OBSCURA_API_TwinLanternTransportEvidence` | `CAMERA_OBSCURA_API_DefaultTwinLanternTransportEvidence` | `CAMERA_OBSCURA_API_BuildTwinLanternTransportEvidence` | Evaluates DDA and parametric-march providers independently, admits supported donor samples, and returns RGB plus explicit evidence. |
| Reconstruction | `CAMERA_OBSCURA_API_TL08ResolveEvidence` | `CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence` | `CAMERA_OBSCURA_API_ResolveTL08Axis` | Resolves one axis while gating neighbors by availability, depth, normal, edge risk, and prior evidence. |
| Composite | `CAMERA_OBSCURA_API_TL09CompositeEvidence` | `CAMERA_OBSCURA_API_DefaultTL09CompositeEvidence` | `CAMERA_OBSCURA_API_BuildTL09Composite` | Applies only nonnegative, admitted indirect light and clamps it to the configured ceiling and remaining normalized channel room. |

`TL45`, `TL07`, `TL08`, and `TL09` are retained stage identifiers. They are
part of the published symbol spelling; they are not API version numbers.

## Minimal Bounded-Composite Use

```hlsl
CAMERA_OBSCURA_API_TL09CompositeEvidence composite =
    CAMERA_OBSCURA_API_BuildTL09Composite(
        sourceRgb,
        reconstructedIndirectRgb,
        reconstructedEvidence,
        receiverValid,
        effectEnabled,
        effectStrength,
        maximumAddedLight);

return float4(composite.final_rgb, 1.0);
```

The returned struct deliberately retains admission, rejection, containment,
and bounds evidence. Consumers can route those fields to diagnostics rather
than treating the API as an opaque color transform.

## Build Matrix

The four API files and four support headers listed in the registry are
source-identical in Stable 1.4, Fidelity Overdrive, and Full Resolution Dual
Ray Alpha. Stable 1.4 is the canonical documentation source and rollback line.
The candidate builds reuse the contract without silently changing it.

Full Resolution Dual Ray Alpha additionally exposes
`LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh`. That extension builds and traces a
current-frame, camera-visible view-frustum proxy. It is explicitly
**experimental**, excluded from the shared 0.1.0 stability promise, and does
not claim world voxelization, hidden geometry, off-screen radiance, or complete
global illumination.

## Stability And Changes

- The paths and contract symbols recorded in `PUBLIC_API.json` are the
  published 0.1.0 surface.
- A breaking shared-contract change requires a version change and migration
  note.
- Other visible helpers are implementation-accessible but are not yet promised
  as stable entrypoints.
- Alpha-only Lunar Flower APIs may change before promotion.
- Static validation does not establish downstream compilation, backend
  compatibility, target-game depth behavior, frame time, or visual acceptance.

Run the API and showcase checks with:

```powershell
python -B tools/validate_showcase_and_public_api.py
```

The API sources are covered by the repository's [MIT license](../LICENSE).
