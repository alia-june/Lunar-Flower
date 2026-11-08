# Twin Lanterns API 0.1.0 — Complete Reference

This document inventories every top-level declaration shipped in the eight shared
include files and the experimental voxel extension. It complements the
[architecture and integration guide](README.md) and the machine-readable
[symbol index](SYMBOLS.json).

Coverage: **9 source files · 72 macros · 15 structs · 208 fields · 66 functions · 3 resources**.

## Stability Legend

- **Stable contract** — the twelve type/constructor/entrypoint symbols listed in `PUBLIC_API.json`.
- **Support surface** — visible shared implementation symbols required by the package; callable, but not independently promised across a future version.
- **Experimental** — Alpha voxel symbols and resources; excluded from the shared 0.1.0 stability promise.
- Include guards are inventoried for completeness but have no runtime semantics.

## Global Conventions

- Float masks use `0.0` and `1.0` as boolean-like states.
- UV coordinates are normalized screen coordinates.
- Depth is ReShade linearized depth under the target installation's configuration.
- RGB values are normalized for the shared SDR bounded-composite contract.
- Working-field RGB carries radiance; alpha carries explicit evidence.
- Zero evidence means unsupported, not valid darkness.

## `LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh`

Experimental Alpha extension: bounded adaptive camera-visible surface hierarchy with full-resolution donor validation.

Source: [`experimental/LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh`](experimental/LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `LUNAR_FLOWER_API_TWIN_LANTERN_VOXEL_PROXY_FXH` | `—` | Header include guard; not a behavioral control. |
| `LUNAR_FLOWER_TL_VOXEL_WIDTH` | `64` | Experimental proxy width in cells. |
| `LUNAR_FLOWER_TL_VOXEL_HEIGHT` | `36` | Experimental proxy height in cells. |
| `LUNAR_FLOWER_TL_VOXEL_DEPTH` | `21` | Experimental proxy depth in cells. |
| `LUNAR_FLOWER_TL_VOXEL_MAX_LEVEL` | `2` | Compile-time constant with published value `2`. |
| `LUNAR_FLOWER_TL_VOXEL_DEPTH_SPLIT` | `0.001` | Compile-time constant with published value `0.001`. |
| `LUNAR_FLOWER_TL_VOXEL_COLOR_SPLIT` | `0.08` | Compile-time constant with published value `0.08`. |
| `LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS` | `32` | Compile-time maximum voxel-proxy trace steps. |

### Resources

| Declaration | Meaning |
|---|---|
| `texture3D LUNAR_FLOWER_TLAdaptiveAtlasV1Tex` | Versioned identity for the `64 x 36 x 21` RGBA32F hierarchy atlas, distinct from the old uniform volume. XY store depth bounds, Z stores sampled coverage, W stores signed center depth (-1 marks a branch). Texture Z indexes tree nodes, not world/depth slices; no coarse donor RGB is stored. |
| `storage3D LUNAR_FLOWER_TLAdaptiveAtlasV1Storage` | Writable `storage3D` view used by the compute build pass. |
| `sampler3D LUNAR_FLOWER_TLAdaptiveAtlasV1Sampler` | Point-filtered, clamped sampler used for cell-exact proxy reads. |

### `LUNAR_FLOWER_API_TwinLanternVoxelEvidence`

Experimental voxel-proxy trace result.

| Scoped field | Type | Meaning |
|---|---|---|
| `LUNAR_FLOWER_API_TwinLanternVoxelEvidence.radiance_rgb` | `float3` | Voxel-proxy radiance returned by the trace. |
| `LUNAR_FLOWER_API_TwinLanternVoxelEvidence.evidence` | `float` | Bounded evidence supporting the result. |
| `LUNAR_FLOWER_API_TwinLanternVoxelEvidence.hit` | `float` | Boolean-like accepted-hit mask. |
| `LUNAR_FLOWER_API_TwinLanternVoxelEvidence.normalized_distance` | `float` | Accepted voxel distance normalized by the trace budget. |

### Functions

| Signature | Semantics |
|---|---|
| `LUNAR_FLOWER_API_TwinLanternVoxelEvidence LUNAR_FLOWER_API_DefaultTwinLanternVoxelEvidence()` | Returns an empty experimental voxel trace record. |
| `float LUNAR_FLOWER_API_TwinLanternVoxelDepthTolerance(float depth)` | Returns a depth-relative subdivision/lookup tolerance with a small absolute floor. |
| `bool LUNAR_FLOWER_API_BuildTwinLanternVoxelNode(int2 rootCell, int nodeIndex, float2 minimumUv, float2 sizeUv, int level)` | Measures a node's center and four inset corners, conditionally marks it as a branch, and writes depth bounds, sampled coverage and signed center depth. |
| `void LUNAR_FLOWER_API_BuildTwinLanternVoxelTile(uint3 id)` | Clears all 21 records per root tile and constructs up to two adaptive subdivision levels from current color/depth samples. |
| `void LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3 id : SV_DispatchThreadID)` | Standalone compute entrypoint that calls the root-tile builder; the Alpha effect uses a guarded entrypoint to skip inactive builds. |
| `float4 LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2 uv, out float level)` | Descends root/child/grandchild records for a UV and returns depth bounds/coverage/signed center depth plus the selected detail level. |
| `float LUNAR_FLOWER_API_TwinLanternVoxelDetailLevel(float2 uv)` | Returns the selected hierarchy level (0, 1 or 2) for the detail diagnostic. |
| `float4 LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(float2 uv)` | Returns full-resolution visible color and depth-bounds-validated occupancy for diagnostics. |
| `LUNAR_FLOWER_API_TwinLanternVoxelEvidence LUNAR_FLOWER_API_TraceTwinLanternVoxelProxyWithReceiver(float2 uv, float directionIndex, float rayLengthPixels, float depthSlope, float frontBias, float backThickness, float requestedSteps, CAMERA_OBSCURA_SurfaceGuide receiver)` | Performs the same adaptive trace with a supplied current-pixel receiver guide, avoiding repeated receiver depth reads across directions. |
| `LUNAR_FLOWER_API_TwinLanternVoxelEvidence LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2 uv, float directionIndex, float rayLengthPixels, float depthSlope, float frontBias, float backThickness, float requestedSteps)` | Gates ray candidates using the adaptive hierarchy, rejects self samples, validates full-resolution depth, and fetches current-frame donor color at the accepted UV. |

## `CAMERA_OBSCURA_API_TwinLanternComposite.fxh`

Stable contract: final admission, containment, and bounded additive composite.

Source: [`reshade-shaders/Shaders/camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh`](reshade-shaders/Shaders/camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `CAMERA_OBSCURA_API_TWIN_LANTERN_COMPOSITE_FXH` | `—` | Header include guard; not a behavioral control. |

### `CAMERA_OBSCURA_API_TL09CompositeEvidence`

Final additive-composite request, containment, rejection, and output record.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.source_rgb` | `float3` | Original source RGB after safety saturation. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.indirect_rgb` | `float3` | Resolved indirect RGB supplied to the bounded composite. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.weighted_indirect_rgb` | `float3` | Indirect RGB after evidence, strength, and admission. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.bounded_indirect_rgb` | `float3` | Weighted indirect RGB after nonnegative maximum-contribution bounds. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.remaining_room_rgb` | `float3` | Per-channel normalized room remaining above source RGB. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.bounded_contribution_rgb` | `float3` | Final per-channel contribution allowed by all ceilings. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.final_rgb` | `float3` | Source plus bounded contribution. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.evidence` | `float` | Bounded evidence supporting the result. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.receiver_valid` | `float` | Receiver-surface validity mask. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.enabled` | `float` | Effect-enabled mask. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.strength` | `float` | Nonnegative requested effect strength. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.maximum_contribution` | `float` | Configured per-channel addition ceiling. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.admission` | `float` | Product of enabled, receiver, evidence, and strength gates. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.application` | `float` | Mask indicating a nonzero contribution was applied. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.rejection` | `float` | Complement of application/admission state used by diagnostics. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.rejection_code` | `float` | Composite-stage reason code for the first failed gate. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.containment_activity` | `float` | Magnitude/activity mask showing requested light was clipped. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.source_preserve_delta` | `float` | Measured deviation from source preservation when no application is authorized. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence.bounds_valid` | `float` | Mask confirming lower, ceiling, and final-output bounds hold. |

### Functions

| Signature | Semantics |
|---|---|
| `CAMERA_OBSCURA_API_TL09CompositeEvidence CAMERA_OBSCURA_API_DefaultTL09CompositeEvidence()` | Returns an empty composite record configured as rejected but bounds-valid. |
| `CAMERA_OBSCURA_API_TL09CompositeEvidence CAMERA_OBSCURA_API_BuildTL09Composite(float3 sourceRgb, float3 resolvedIndirectRgb, float trustedWeight, float receiverValid, float enabled, float strength, float maximumContribution)` | Applies enabled/receiver/evidence/strength admission, then nonnegative maximum and channel-room bounds. |

## `CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh`

API-visible provider construction, trace evidence, and provider diagnostic signals.

Source: [`reshade-shaders/Shaders/camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh`](reshade-shaders/Shaders/camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `CAMERA_OBSCURA_API_TWIN_LANTERN_PROVIDER_PROOF_COMMON_FXH` | `—` | Header include guard; not a behavioral control. |
| `CAMERA_OBSCURA_API_TL45_INPUT_LIVE` | `0.0` | Use live ReShade receiver/depth input. |
| `CAMERA_OBSCURA_API_TL45_INPUT_INVALID_RECEIVER` | `1.0` | Inject an invalid receiver for proof diagnostics. |
| `CAMERA_OBSCURA_API_TL45_INPUT_ZERO_DIRECTION` | `2.0` | Inject a zero direction for proof diagnostics. |

### `CAMERA_OBSCURA_API_TwinLanternProviderEvidence`

Complete observation record for one provider trace and refinement result.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.provider_backend` | `float` | Provider backend identifier. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.requested_steps` | `float` | Requested trace-step count before/for bounded execution. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.receiver_valid` | `float` | Receiver-surface validity mask. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.receiver_edge_risk` | `float` | Receiver depth-discontinuity risk. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.ray_valid` | `float` | Ray validity mask. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.direction_uv` | `float2` | Normalized screen-space ray direction. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.hit` | `float` | Boolean-like accepted-hit mask. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.reason` | `float` | Terminal `CAMERA_OBSCURA_REASON_*` code. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.hit_uv` | `float2` | Accepted hit location in normalized screen coordinates. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.step_index` | `float` | Traversal/refinement step at which the terminal state occurred. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.terminal_depth` | `float` | Scene depth observed at the terminal sample. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.interval_min` | `float` | Lower supported depth interval bound. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.interval_max` | `float` | Upper supported depth interval bound. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.interval_support` | `float` | Boolean-like mask showing whether the hit interval is supported. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.thickness_used` | `float` | Effective nonnegative thickness used by the hit test. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.coarse_residual` | `float` | Absolute depth residual before refinement. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.refined_residual` | `float` | Absolute depth residual after refinement. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.refinement_not_worse` | `float` | Mask indicating refinement did not increase residual. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.refinement_steps` | `float` | Configured or completed refinement count. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence.confidence` | `float` | Bounded confidence assigned to this result. |

### Functions

| Signature | Semantics |
|---|---|
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence CAMERA_OBSCURA_API_DefaultTwinLanternProviderEvidence(float backend)` | Returns a zeroed provider-evidence record initialized to an invalid-ray miss. |
| `float2 CAMERA_OBSCURA_API_TL45Direction(float requestedIndex)` | Clamps/rounds an index and returns one of eight unit compass directions. |
| `CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_BuildTL45Receiver(float2 uv, float inputMode)` | Builds live or injected receiver evidence for provider proof and diagnostics. |
| `CAMERA_OBSCURA_Ray CAMERA_OBSCURA_API_BuildTL45Ray(float2 uv, float directionIndex, float inputMode, float requestedSteps, float rayLengthPixels, float depthSlope, float frontBias, float backThickness, out CAMERA_OBSCURA_TraceControls controls, out CAMERA_OBSCURA_SurfaceGuide receiver)` | Builds receiver, request, controls, and ray for a TL45 direction index. |
| `CAMERA_OBSCURA_API_TwinLanternProviderEvidence CAMERA_OBSCURA_API_BuildTL45Evidence(CAMERA_OBSCURA_Ray ray, CAMERA_OBSCURA_TraceControls controls, CAMERA_OBSCURA_SurfaceGuide receiver, CAMERA_OBSCURA_Hit coarse, CAMERA_OBSCURA_Hit refined, float backend)` | Converts coarse/refined provider results into the published provider-evidence record. |
| `float3 CAMERA_OBSCURA_API_TL45Status(float value)` | Maps a boolean-like value to fail/pass diagnostic colors. |
| `float3 CAMERA_OBSCURA_API_TL45Signal(CAMERA_OBSCURA_API_TwinLanternProviderEvidence evidence, float view)` | Selects a provider-evidence diagnostic signal by view index. |

## `CAMERA_OBSCURA_API_TwinLanternReconstruction.fxh`

Stable contract plus visible helpers for same-surface separable reconstruction.

Source: [`reshade-shaders/Shaders/camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternReconstruction.fxh`](reshade-shaders/Shaders/camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternReconstruction.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `CAMERA_OBSCURA_API_TWIN_LANTERN_RECONSTRUCTION_FXH` | `—` | Header include guard; not a behavioral control. |

### `CAMERA_OBSCURA_API_TL08ResolveEvidence`

One-axis reconstruction result and every support/weight gate used to produce it.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.resolved_rgb` | `float3` | Reconstructed indirect RGB for the axis. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.trusted_weight` | `float` | Kernel-normalized evidence retained by reconstruction. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.weight_sum` | `float` | Sum of admitted negative, center, and positive weights. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.kernel_capacity` | `float` | Maximum represented kernel weight for available taps. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.center_valid` | `float` | Center tap: boolean-like validity mask for this record. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.center_evidence` | `float` | Center tap: bounded evidence supporting the result. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.negative_available` | `float` | Availability/coverage mask for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.positive_available` | `float` | Availability/coverage mask for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.negative_depth_support` | `float` | Depth-compatibility support for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.positive_depth_support` | `float` | Depth-compatibility support for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.negative_normal_support` | `float` | Proxy-normal compatibility for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.positive_normal_support` | `float` | Proxy-normal compatibility for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.negative_edge_support` | `float` | Edge-risk support for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.positive_edge_support` | `float` | Edge-risk support for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.negative_admitted_weight` | `float` | Final admitted reconstruction weight for the named tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.center_admitted_weight` | `float` | Final admitted reconstruction weight for the named tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.positive_admitted_weight` | `float` | Final admitted reconstruction weight for the named tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.minimum_depth_support` | `float` | Depth-compatibility support for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.minimum_normal_support` | `float` | Proxy-normal compatibility for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.minimum_edge_support` | `float` | Edge-risk support for the named reconstruction tap. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence.zero_weight` | `float` | Mask indicating reconstruction admitted no weight. |

### Functions

| Signature | Semantics |
|---|---|
| `CAMERA_OBSCURA_API_TL08ResolveEvidence CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence()` | Returns a fully initialized empty reconstruction record. |
| `CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_DefaultTL08Guide()` | Returns an invalid default surface guide for unavailable taps. |
| `CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_BuildTL08Guide(float2 uv)` | Builds the reconstruction guide for a UV. |
| `float CAMERA_OBSCURA_API_TL08DepthSupport(CAMERA_OBSCURA_SurfaceGuide center, CAMERA_OBSCURA_SurfaceGuide tapGuide, float depthTolerance)` | Computes bounded center/tap depth compatibility under a tolerance. |
| `float CAMERA_OBSCURA_API_TL08NormalSupport(CAMERA_OBSCURA_SurfaceGuide center, CAMERA_OBSCURA_SurfaceGuide tapGuide, float normalMinimum)` | Computes bounded center/tap proxy-normal agreement above a minimum. |
| `float CAMERA_OBSCURA_API_TL08EdgeSupport(CAMERA_OBSCURA_SurfaceGuide center, CAMERA_OBSCURA_SurfaceGuide tapGuide, float edgeProtection)` | Reduces tap support according to center/tap edge risk and protection strength. |
| `CAMERA_OBSCURA_API_TL08ResolveEvidence CAMERA_OBSCURA_API_ResolveTL08Axis(float4 negativeValue, float4 centerValue, float4 positiveValue, CAMERA_OBSCURA_SurfaceGuide negativeGuide, CAMERA_OBSCURA_SurfaceGuide centerGuide, CAMERA_OBSCURA_SurfaceGuide positiveGuide, float negativeAvailable, float positiveAvailable, float depthTolerance, float normalMinimum, float edgeProtection)` | Resolves three RGBA evidence samples across one axis and returns all admission weights and supports. |

## `CAMERA_OBSCURA_API_TwinLanternTransport.fxh`

Stable dual-provider transport contract and provider-sample helpers.

Source: [`reshade-shaders/Shaders/camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternTransport.fxh`](reshade-shaders/Shaders/camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternTransport.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `CAMERA_OBSCURA_API_TWIN_LANTERN_TRANSPORT_FXH` | `—` | Header include guard; not a behavioral control. |
| `CAMERA_OBSCURA_API_TL07_MODE_PARITY` | `0.0` | Trace providers but do not admit complementary transport. |
| `CAMERA_OBSCURA_API_TL07_MODE_COMPLEMENTARY` | `1.0` | Admit independently supported DDA and march donor samples. |

### `CAMERA_OBSCURA_API_TwinLanternTransportEvidence`

Complete DDA/march donor-admission and combination record.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.transport_mode` | `float` | Selected `CAMERA_OBSCURA_API_TL07_MODE_*` value. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.transport_enabled` | `float` | Mask enabling complementary donor transport. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.ray_valid` | `float` | Ray validity mask. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.receiver_valid` | `float` | Receiver-surface validity mask. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_hit` | `float` | DDA provider: boolean-like accepted-hit mask. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_reason` | `float` | DDA provider: terminal `camera_obscura_reason_*` code. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_donor_valid` | `float` | Donor-surface validity for the named provider. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_donor_rgb` | `float3` | DDA provider: sampled donor color. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_distance_pixels` | `float` | DDA provider: receiver-to-donor distance in pixels. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_distance_weight` | `float` | DDA provider: distance falloff weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_receiver_facing` | `float` | DDA provider: receiver-facing compatibility term. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_donor_facing` | `float` | DDA provider: donor-facing compatibility term. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_normal_compatibility` | `float` | DDA provider: combined receiver/donor proxy-normal compatibility. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_hit_confidence` | `float` | DDA provider: confidence inherited from the accepted hit. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_raw_weight` | `float` | DDA provider: pre-normalization provider weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_normalized_weight` | `float` | Normalized blend weight for the named provider. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_hit` | `float` | March provider: boolean-like accepted-hit mask. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_reason` | `float` | March provider: terminal `camera_obscura_reason_*` code. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_donor_valid` | `float` | Donor-surface validity for the named provider. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_donor_rgb` | `float3` | March provider: sampled donor color. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_distance_pixels` | `float` | March provider: receiver-to-donor distance in pixels. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_distance_weight` | `float` | March provider: distance falloff weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_receiver_facing` | `float` | March provider: receiver-facing compatibility term. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_donor_facing` | `float` | March provider: donor-facing compatibility term. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_normal_compatibility` | `float` | March provider: combined receiver/donor proxy-normal compatibility. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_hit_confidence` | `float` | March provider: confidence inherited from the accepted hit. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_raw_weight` | `float` | March provider: pre-normalization provider weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_normalized_weight` | `float` | Normalized blend weight for the named provider. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_weight_active` | `float` | Mask describing whether the named provider combination has positive weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_weight_active` | `float` | Mask describing whether the named provider combination has positive weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.both_weight_active` | `float` | Mask describing whether the named provider combination has positive weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.dda_only_weight_active` | `float` | Mask describing whether the named provider combination has positive weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.march_only_weight_active` | `float` | Mask describing whether the named provider combination has positive weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.neither_weight_active` | `float` | Mask describing whether the named provider combination has positive weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.one_provider_bound_ok` | `float` | Mask confirming the resolved transport does not exceed the strongest single-provider bound. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.provider_count` | `float` | Number of providers with positive admitted weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.total_raw_weight` | `float` | Sum of admitted provider raw weights. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.normalized_weight_sum` | `float` | Sum of normalized provider weights. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.evidence_strength` | `float` | Bounded combined transport evidence. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.combined_donor_rgb` | `float3` | Donor RGB sampled by the named provider. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.raw_radiance_rgb` | `float3` | Combined donor radiance multiplied by evidence strength. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence.zero_contribution` | `float` | Mask indicating no provider contribution survived. |

### `CAMERA_OBSCURA_API_TL07ProviderSample`

Internal transport-stage donor sample derived from one accepted hit.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_API_TL07ProviderSample.valid` | `float` | Boolean-like validity mask for this record. |
| `CAMERA_OBSCURA_API_TL07ProviderSample.donor_rgb` | `float3` | Sampled donor color. |
| `CAMERA_OBSCURA_API_TL07ProviderSample.distance_pixels` | `float` | Receiver-to-donor distance in pixels. |
| `CAMERA_OBSCURA_API_TL07ProviderSample.distance_weight` | `float` | Distance falloff weight. |
| `CAMERA_OBSCURA_API_TL07ProviderSample.receiver_facing` | `float` | Receiver-facing compatibility term. |
| `CAMERA_OBSCURA_API_TL07ProviderSample.donor_facing` | `float` | Donor-facing compatibility term. |
| `CAMERA_OBSCURA_API_TL07ProviderSample.normal_compatibility` | `float` | Combined receiver/donor proxy-normal compatibility. |
| `CAMERA_OBSCURA_API_TL07ProviderSample.hit_confidence` | `float` | Confidence inherited from the accepted hit. |
| `CAMERA_OBSCURA_API_TL07ProviderSample.raw_weight` | `float` | Pre-normalization provider weight. |

### Functions

| Signature | Semantics |
|---|---|
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence CAMERA_OBSCURA_API_DefaultTwinLanternTransportEvidence()` | Returns a fully initialized empty dual-provider transport record. |
| `CAMERA_OBSCURA_API_TL07ProviderSample CAMERA_OBSCURA_API_DefaultTL07ProviderSample()` | Returns a fully initialized empty donor sample. |
| `CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_BuildTL07DonorGuide(float2 uv)` | Builds the surface guide used to validate a hit's donor location. |
| `CAMERA_OBSCURA_API_TL07ProviderSample CAMERA_OBSCURA_API_BuildTL07ProviderSample(CAMERA_OBSCURA_Ray ray, CAMERA_OBSCURA_SurfaceGuide receiver, CAMERA_OBSCURA_Hit hit, float maximumDistancePixels)` | Converts an accepted hit into donor color, geometry support, confidence, and raw weight. |
| `CAMERA_OBSCURA_API_TwinLanternTransportEvidence CAMERA_OBSCURA_API_BuildTwinLanternTransportEvidence(float2 uv, float directionIndex, float inputMode, float transportMode, float rayLengthPixels, float depthSlope, float frontBias, float backThickness)` | Runs DDA and march independently, validates donors, normalizes weights, and returns combined transport evidence. |

## `CAMERA_OBSCURA_AtomicCommon.fxh`

Shared atomic types, enumerations, limits, and scalar helpers. Support surface; not independently version-promised unless named in PUBLIC_API.json.

Source: [`reshade-shaders/Shaders/camera_obscura/header/CAMERA_OBSCURA_AtomicCommon.fxh`](reshade-shaders/Shaders/camera_obscura/header/CAMERA_OBSCURA_AtomicCommon.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `CAMERA_OBSCURA_ATOMIC_COMMON_FXH` | `—` | Header include guard; not a behavioral control. |
| `CAMERA_OBSCURA_API_VERSION_MAJOR` | `0` | API semantic-version major component. |
| `CAMERA_OBSCURA_API_VERSION_MINOR` | `1` | API semantic-version minor component. |
| `CAMERA_OBSCURA_API_VERSION_PATCH` | `0` | API semantic-version patch component. |
| `CAMERA_OBSCURA_CAP_TIER_C0` | `0` | Capability-tier enumeration; 0.1.0's ReShade binding reports C0. |
| `CAMERA_OBSCURA_CAP_TIER_C1` | `1` | Capability-tier enumeration; 0.1.0's ReShade binding reports C0. |
| `CAMERA_OBSCURA_CAP_TIER_C2` | `2` | Capability-tier enumeration; 0.1.0's ReShade binding reports C0. |
| `CAMERA_OBSCURA_CAP_TIER_C3` | `3` | Capability-tier enumeration; 0.1.0's ReShade binding reports C0. |
| `CAMERA_OBSCURA_DEPTH_METRIC_NONE` | `0` | No usable depth metric. |
| `CAMERA_OBSCURA_DEPTH_METRIC_LINEAR01` | `1` | ReShade linearized depth normalized to `0..1`. |
| `CAMERA_OBSCURA_BACKEND_NONE` | `0` | No traversal backend. |
| `CAMERA_OBSCURA_BACKEND_DDA` | `1` | Pixel-grid DDA traversal backend. |
| `CAMERA_OBSCURA_BACKEND_MARCH` | `2` | Parametric march traversal backend. |
| `CAMERA_OBSCURA_REASON_HIT` | `0` | Terminal trace state: hit. |
| `CAMERA_OBSCURA_REASON_MAX_STEPS` | `1` | Terminal trace state: max steps. |
| `CAMERA_OBSCURA_REASON_SCREEN_EXIT` | `2` | Terminal trace state: screen exit. |
| `CAMERA_OBSCURA_REASON_INVALID_DEPTH` | `3` | Terminal trace state: invalid depth. |
| `CAMERA_OBSCURA_REASON_NO_INTERVAL` | `4` | Terminal trace state: no interval. |
| `CAMERA_OBSCURA_REASON_NEAR_CLIP` | `5` | Terminal trace state: near clip. |
| `CAMERA_OBSCURA_REASON_MAX_DISTANCE` | `6` | Terminal trace state: max distance. |
| `CAMERA_OBSCURA_REASON_NUMERIC_INVALID` | `7` | Terminal trace state: numeric invalid. |
| `CAMERA_OBSCURA_REASON_SELF_HIT` | `8` | Terminal trace state: self hit. |
| `CAMERA_OBSCURA_REASON_UNSUPPORTED_TIER` | `9` | Terminal trace state: unsupported tier. |
| `CAMERA_OBSCURA_REASON_INVALID_RAY` | `10` | Terminal trace state: invalid ray. |
| `CAMERA_OBSCURA_DDA_MAX_STEPS` | `24` | Compile-time maximum DDA steps. |
| `CAMERA_OBSCURA_MARCH_MAX_STEPS` | `16` | Compile-time maximum march steps. |
| `CAMERA_OBSCURA_REFINE_STEPS` | `2` | Default hit-refinement iteration count. |
| `CAMERA_OBSCURA_MARCH_STEP_JITTER_STRENGTH` | `0.65` | Deterministic march-step jitter amplitude. |
| `CAMERA_OBSCURA_MARCH_DONOR_PREFILTER_STRENGTH` | `0.45` | March donor prefilter blend strength. |

### `CAMERA_OBSCURA_Capabilities`

Available color, depth, projection, history, and motion-vector capabilities.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_Capabilities.tier` | `float` | Capability tier enumeration. |
| `CAMERA_OBSCURA_Capabilities.has_color` | `float` | Color-input capability flag. |
| `CAMERA_OBSCURA_Capabilities.has_depth` | `float` | Depth-input capability flag. |
| `CAMERA_OBSCURA_Capabilities.has_linear_view_z` | `float` | Linearized view-depth capability flag. |
| `CAMERA_OBSCURA_Capabilities.has_projection` | `float` | Projection-matrix capability flag. |
| `CAMERA_OBSCURA_Capabilities.has_inverse_projection` | `float` | Inverse-projection capability flag. |
| `CAMERA_OBSCURA_Capabilities.has_history` | `float` | Temporal-history capability flag. |
| `CAMERA_OBSCURA_Capabilities.has_motion_vectors` | `float` | Motion-vector capability flag. |
| `CAMERA_OBSCURA_Capabilities.depth_metric` | `float` | `CAMERA_OBSCURA_DEPTH_METRIC_*` identifier. |

### `CAMERA_OBSCURA_SurfaceGuide`

Per-pixel receiver/donor surface evidence reconstructed from depth and color.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_SurfaceGuide.valid` | `float` | Boolean-like validity mask for this record. |
| `CAMERA_OBSCURA_SurfaceGuide.depth` | `float` | Linearized depth at the guided surface. |
| `CAMERA_OBSCURA_SurfaceGuide.normal` | `float3` | Depth-derived proxy surface normal. |
| `CAMERA_OBSCURA_SurfaceGuide.depth_confidence` | `float` | Depth validity reduced by local discontinuity risk. |
| `CAMERA_OBSCURA_SurfaceGuide.edge_risk` | `float` | Local depth-discontinuity risk. |
| `CAMERA_OBSCURA_SurfaceGuide.luma` | `float` | Source luminance at the guided surface. |

### `CAMERA_OBSCURA_RayRequest`

Unnormalized consumer request used to derive safe trace controls and a ray.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_RayRequest.direction_uv` | `float2` | Normalized screen-space ray direction. |
| `CAMERA_OBSCURA_RayRequest.ray_length_uv` | `float` | Requested or clamped ray length in UV space. |
| `CAMERA_OBSCURA_RayRequest.ray_depth_slope` | `float` | Depth change per unit of ray travel. |
| `CAMERA_OBSCURA_RayRequest.front_bias` | `float` | Front-side depth bias used by intersection tests. |
| `CAMERA_OBSCURA_RayRequest.back_thickness` | `float` | Back-side hit thickness. |
| `CAMERA_OBSCURA_RayRequest.confidence_min` | `float` | Minimum confidence requested for acceptance. |
| `CAMERA_OBSCURA_RayRequest.self_hit_pixels` | `float` | Minimum pixel travel before self-hit rejection clears. |
| `CAMERA_OBSCURA_RayRequest.distance_fade` | `float` | Distance falloff control. |
| `CAMERA_OBSCURA_RayRequest.pixel_stride` | `float` | Pixel-grid traversal stride. |
| `CAMERA_OBSCURA_RayRequest.refinement_steps` | `float` | Configured or completed refinement count. |
| `CAMERA_OBSCURA_RayRequest.spatial_phase` | `float` | Deterministic phase/jitter selector. |
| `CAMERA_OBSCURA_RayRequest.requested_steps` | `float` | Requested trace-step count before/for bounded execution. |

### `CAMERA_OBSCURA_TraceControls`

Clamped trace controls consumed by DDA, march, and refinement.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_TraceControls.ray_length_uv` | `float` | Requested or clamped ray length in UV space. |
| `CAMERA_OBSCURA_TraceControls.ray_depth_slope` | `float` | Depth change per unit of ray travel. |
| `CAMERA_OBSCURA_TraceControls.front_bias` | `float` | Front-side depth bias used by intersection tests. |
| `CAMERA_OBSCURA_TraceControls.back_thickness` | `float` | Back-side hit thickness. |
| `CAMERA_OBSCURA_TraceControls.confidence_min` | `float` | Minimum confidence requested for acceptance. |
| `CAMERA_OBSCURA_TraceControls.self_hit_pixels` | `float` | Minimum pixel travel before self-hit rejection clears. |
| `CAMERA_OBSCURA_TraceControls.distance_fade` | `float` | Distance falloff control. |
| `CAMERA_OBSCURA_TraceControls.pixel_stride` | `float` | Pixel-grid traversal stride. |
| `CAMERA_OBSCURA_TraceControls.refinement_steps` | `float` | Configured or completed refinement count. |
| `CAMERA_OBSCURA_TraceControls.steps` | `float` | Clamped executable traversal-step count. |
| `CAMERA_OBSCURA_TraceControls.spatial_phase` | `float` | Deterministic phase/jitter selector. |

### `CAMERA_OBSCURA_Ray`

Validated screen-space ray in UV/depth parameter space.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_Ray.valid` | `float` | Boolean-like validity mask for this record. |
| `CAMERA_OBSCURA_Ray.capability_tier` | `float` | Capability tier carried by the ray/hit. |
| `CAMERA_OBSCURA_Ray.origin_uv` | `float2` | Ray origin in normalized screen coordinates. |
| `CAMERA_OBSCURA_Ray.step_uv` | `float2` | Per-step UV displacement. |
| `CAMERA_OBSCURA_Ray.origin_depth` | `float` | Linearized depth at the ray origin. |
| `CAMERA_OBSCURA_Ray.step_depth` | `float` | Per-step depth displacement. |
| `CAMERA_OBSCURA_Ray.t_min` | `float` | Minimum permitted ray parameter. |
| `CAMERA_OBSCURA_Ray.t_max` | `float` | Maximum permitted ray parameter. |
| `CAMERA_OBSCURA_Ray.front_bias` | `float` | Front-side depth bias used by intersection tests. |
| `CAMERA_OBSCURA_Ray.back_thickness` | `float` | Back-side hit thickness. |
| `CAMERA_OBSCURA_Ray.confidence_min` | `float` | Minimum confidence requested for acceptance. |
| `CAMERA_OBSCURA_Ray.steps` | `float` | Clamped executable traversal-step count. |
| `CAMERA_OBSCURA_Ray.distance_fade` | `float` | Distance falloff control. |

### `CAMERA_OBSCURA_Hit`

Terminal state for one trace or refinement attempt, including misses and reason codes.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_Hit.valid` | `float` | Boolean-like validity mask for this record. |
| `CAMERA_OBSCURA_Hit.hit` | `float` | Boolean-like accepted-hit mask. |
| `CAMERA_OBSCURA_Hit.uv` | `float2` | Terminal or accepted UV. |
| `CAMERA_OBSCURA_Hit.previous_uv` | `float2` | UV from the prior traversal sample. |
| `CAMERA_OBSCURA_Hit.ray_t` | `float` | Ray parameter at the terminal sample. |
| `CAMERA_OBSCURA_Hit.previous_ray_z` | `float` | Ray depth at the prior sample. |
| `CAMERA_OBSCURA_Hit.ray_z` | `float` | Ray depth at the terminal sample. |
| `CAMERA_OBSCURA_Hit.scene_z` | `float` | Scene depth at the terminal sample. |
| `CAMERA_OBSCURA_Hit.delta` | `float` | Signed ray-versus-scene depth residual. |
| `CAMERA_OBSCURA_Hit.interval_min` | `float` | Lower supported depth interval bound. |
| `CAMERA_OBSCURA_Hit.interval_max` | `float` | Upper supported depth interval bound. |
| `CAMERA_OBSCURA_Hit.thickness_used` | `float` | Effective nonnegative thickness used by the hit test. |
| `CAMERA_OBSCURA_Hit.confidence` | `float` | Bounded confidence assigned to this result. |
| `CAMERA_OBSCURA_Hit.step_index` | `float` | Traversal/refinement step at which the terminal state occurred. |
| `CAMERA_OBSCURA_Hit.backend` | `float` | `CAMERA_OBSCURA_BACKEND_*` identifier. |
| `CAMERA_OBSCURA_Hit.reason` | `float` | Terminal `CAMERA_OBSCURA_REASON_*` code. |
| `CAMERA_OBSCURA_Hit.capability_tier` | `float` | Capability tier carried by the ray/hit. |

### `CAMERA_OBSCURA_DualHit`

Pairwise DDA/march agreement and conflict record used by diagnostics.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_DualHit.dda_hit` | `float` | DDA provider: boolean-like accepted-hit mask. |
| `CAMERA_OBSCURA_DualHit.dda_confidence` | `float` | DDA provider: bounded confidence assigned to this result. |
| `CAMERA_OBSCURA_DualHit.dda_reason` | `float` | DDA provider: terminal `camera_obscura_reason_*` code. |
| `CAMERA_OBSCURA_DualHit.march_hit` | `float` | March provider: boolean-like accepted-hit mask. |
| `CAMERA_OBSCURA_DualHit.march_confidence` | `float` | March provider: bounded confidence assigned to this result. |
| `CAMERA_OBSCURA_DualHit.march_reason` | `float` | March provider: terminal `camera_obscura_reason_*` code. |
| `CAMERA_OBSCURA_DualHit.uv_agreement` | `float` | DDA/march hit-position agreement. |
| `CAMERA_OBSCURA_DualHit.depth_agreement` | `float` | DDA/march scene-depth agreement. |
| `CAMERA_OBSCURA_DualHit.distance_agreement` | `float` | DDA/march travel-distance agreement. |
| `CAMERA_OBSCURA_DualHit.conflict` | `float` | Mask indicating material provider disagreement. |
| `CAMERA_OBSCURA_DualHit.combined_confidence` | `float` | Agreement-aware combined provider confidence. |

### `CAMERA_OBSCURA_Contribution`

One provider's donor and indirect-light contribution evidence.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_Contribution.valid` | `float` | Boolean-like validity mask for this record. |
| `CAMERA_OBSCURA_Contribution.donor_rgb` | `float3` | Sampled donor color. |
| `CAMERA_OBSCURA_Contribution.indirect_rgb` | `float3` | Indirect-light RGB carried by a contribution. |
| `CAMERA_OBSCURA_Contribution.weight` | `float` | Contribution weight. |
| `CAMERA_OBSCURA_Contribution.coverage` | `float` | Screen/sample coverage supporting the contribution. |
| `CAMERA_OBSCURA_Contribution.distance_weight` | `float` | Distance falloff weight. |
| `CAMERA_OBSCURA_Contribution.receiver_facing` | `float` | Receiver-facing compatibility term. |
| `CAMERA_OBSCURA_Contribution.donor_facing` | `float` | Donor-facing compatibility term. |
| `CAMERA_OBSCURA_Contribution.normal_compatibility` | `float` | Combined receiver/donor proxy-normal compatibility. |
| `CAMERA_OBSCURA_Contribution.confidence` | `float` | Bounded confidence assigned to this result. |
| `CAMERA_OBSCURA_Contribution.backend` | `float` | `CAMERA_OBSCURA_BACKEND_*` identifier. |

### `CAMERA_OBSCURA_Fallback`

Fallback color, confidence, and class identifier.

| Scoped field | Type | Meaning |
|---|---|---|
| `CAMERA_OBSCURA_Fallback.rgb` | `float3` | Fallback RGB. |
| `CAMERA_OBSCURA_Fallback.confidence` | `float` | Bounded confidence assigned to this result. |
| `CAMERA_OBSCURA_Fallback.class_id` | `float` | Fallback classification identifier. |

### Functions

| Signature | Semantics |
|---|---|
| `float CAMERA_OBSCURA_SafeRcp(float denominator, float fallback)` | Returns `1 / denominator` when the magnitude is safe; otherwise returns the supplied fallback. |
| `float2 CAMERA_OBSCURA_PixelSize()` | Returns the inverse ReShade back-buffer dimensions as one-pixel UV extents. |
| `float2 CAMERA_OBSCURA_SaturateUV(float2 uv)` | Clamps normalized UV coordinates to the addressable screen range. |
| `float CAMERA_OBSCURA_StableNoise01(float2 value)` | Produces deterministic screen-space scalar noise in `0..1` from a 2D value. |
| `float CAMERA_OBSCURA_Luma(float3 color)` | Computes the implementation's scalar luminance estimate for an RGB value. |
| `float CAMERA_OBSCURA_DepthConfidence(float depth)` | Returns valid-depth confidence, rejecting the normalized far-plane sentinel. |
| `int CAMERA_OBSCURA_ClampSteps(float requested, int maxSteps)` | Rounds a requested float step count and clamps it to `1..maxSteps`. |
| `CAMERA_OBSCURA_Hit CAMERA_OBSCURA_MakeMiss(float backend, float reason)` | Constructs a fully initialized miss record for a backend and terminal reason. |
| `float CAMERA_OBSCURA_EffectiveThickness(CAMERA_OBSCURA_Ray ray)` | Returns the nonnegative hit thickness carried by a validated ray. |
| `float CAMERA_OBSCURA_HitConfidence(float delta, float frontBias, float thicknessUsed)` | Maps depth residual, front bias, and thickness to bounded hit confidence. |

## `CAMERA_OBSCURA_AtomicDebug.fxh`

Shared diagnostic palettes and view composition. Support surface.

Source: [`reshade-shaders/Shaders/camera_obscura/header/CAMERA_OBSCURA_AtomicDebug.fxh`](reshade-shaders/Shaders/camera_obscura/header/CAMERA_OBSCURA_AtomicDebug.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `CAMERA_OBSCURA_ATOMIC_DEBUG_FXH` | `—` | Header include guard; not a behavioral control. |
| `CAMERA_OBSCURA_DEBUG_VIEW_COMPOSITE` | `0` | Shared debug-view selector: composite. |
| `CAMERA_OBSCURA_DEBUG_VIEW_DDA_HIT` | `1` | Shared debug-view selector: dda hit. |
| `CAMERA_OBSCURA_DEBUG_VIEW_MARCH_HIT` | `2` | Shared debug-view selector: march hit. |
| `CAMERA_OBSCURA_DEBUG_VIEW_AGREEMENT` | `3` | Shared debug-view selector: agreement. |
| `CAMERA_OBSCURA_DEBUG_VIEW_DDA_CONTRIBUTION` | `4` | Shared debug-view selector: dda contribution. |
| `CAMERA_OBSCURA_DEBUG_VIEW_MARCH_CONTRIBUTION` | `5` | Shared debug-view selector: march contribution. |
| `CAMERA_OBSCURA_DEBUG_VIEW_REASON` | `6` | Shared debug-view selector: reason. |
| `CAMERA_OBSCURA_DEBUG_VIEW_COMPOSITE_DELTA` | `7` | Shared debug-view selector: composite delta. |
| `CAMERA_OBSCURA_DEBUG_VIEW_PROVIDER_BALANCE` | `8` | Shared debug-view selector: provider balance. |
| `CAMERA_OBSCURA_DEBUG_VIEW_SOURCE` | `9` | Shared debug-view selector: source. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_WEIGHT` | `0.65` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MIN` | `0.20` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MAX` | `1.00` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_GREEN_G` | `0.035` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_GREEN_B` | `0.010` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_R` | `0.035` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_G` | `0.025` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_ISSUE_BLEND` | `0.78` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_AGREEMENT_NO_EVIDENCE_BLEND` | `0.35` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_CONTRIBUTION_LUMA_MIN` | `0.020` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_CONTRIBUTION_LUMA_MAX` | `0.180` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_CONTRIBUTION_WEIGHT_GAIN` | `1.00` | Compile-time tuning constant for shared diagnostic presentation. |
| `CAMERA_OBSCURA_DEBUG_CONTRIBUTION_CONTEXT` | `0.25` | Compile-time tuning constant for shared diagnostic presentation. |

### Functions

| Signature | Semantics |
|---|---|
| `float3 CAMERA_OBSCURA_DebugHeat(float value)` | Maps a scalar to the standard diagnostic heat palette. |
| `float3 CAMERA_OBSCURA_DebugBackendColor(float backend)` | Returns the canonical diagnostic color for DDA, march, or no backend. |
| `float3 CAMERA_OBSCURA_DebugSourceAnchor(float3 source)` | Darkens the source into a stable diagnostic background anchor. |
| `float3 CAMERA_OBSCURA_DebugOverlay(float3 source, float3 signal)` | Composites a diagnostic signal over the source anchor. |
| `float3 CAMERA_OBSCURA_DebugReasonColor(float reason)` | Maps a terminal reason code to its diagnostic color. |
| `float3 CAMERA_OBSCURA_DebugHit(CAMERA_OBSCURA_Hit hit)` | Visualizes one hit's success, reason, and confidence. |
| `float3 CAMERA_OBSCURA_DebugContribution(CAMERA_OBSCURA_Contribution contribution)` | Visualizes one contribution's color and confidence-weighted support. |
| `float3 CAMERA_OBSCURA_DebugContributionView(float3 source, CAMERA_OBSCURA_Contribution contribution)` | Overlays one contribution visualization on source context. |
| `float3 CAMERA_OBSCURA_DebugCompositeDelta(float3 source, float3 composite)` | Visualizes the nonnegative difference between source and composite. |
| `float3 CAMERA_OBSCURA_DebugProviderBalance(float3 source, CAMERA_OBSCURA_Contribution ddaContribution, CAMERA_OBSCURA_Contribution marchContribution)` | Visualizes DDA versus march provider weight and contribution balance. |
| `float3 CAMERA_OBSCURA_DebugAgreement(CAMERA_OBSCURA_DualHit dual)` | Visualizes DDA/march spatial, depth, distance, and conflict agreement. |
| `float3 CAMERA_OBSCURA_DebugAgreementView(float3 source, CAMERA_OBSCURA_DualHit dual)` | Overlays agreement diagnostics on source context. |
| `float3 CAMERA_OBSCURA_DebugView(float view, float3 source, float3 composite, CAMERA_OBSCURA_Hit dda, CAMERA_OBSCURA_Hit march, CAMERA_OBSCURA_DualHit dual, CAMERA_OBSCURA_Contribution ddaContribution, CAMERA_OBSCURA_Contribution marchContribution)` | Dispatches the requested shared debug-view enumeration to a visualization. |

## `CAMERA_OBSCURA_EntryCapability.fxh`

ReShade back-buffer/depth binding, surface construction, and ray setup. Support surface.

Source: [`reshade-shaders/Shaders/camera_obscura/header/CAMERA_OBSCURA_EntryCapability.fxh`](reshade-shaders/Shaders/camera_obscura/header/CAMERA_OBSCURA_EntryCapability.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `CAMERA_OBSCURA_ENTRY_CAPABILITY_FXH` | `—` | Header include guard; not a behavioral control. |

### Functions

| Signature | Semantics |
|---|---|
| `float CAMERA_OBSCURA_LoadDepth(float2 uv)` | Loads and saturates ReShade linearized depth at a safe UV. |
| `float3 CAMERA_OBSCURA_LoadColor(float2 uv)` | Loads back-buffer RGB at a safe UV. |
| `float3 CAMERA_OBSCURA_BuildProxyNormal(float2 uv)` | Approximates a view-facing surface normal from center/right/up depth differences. |
| `CAMERA_OBSCURA_Capabilities CAMERA_OBSCURA_QueryCapabilities()` | Returns the fixed C0 capability record implemented by this ReShade binding. |
| `CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_BuildSurfaceGuide(float2 uv)` | Builds validity, depth, proxy normal, confidence, edge risk, and luma for one UV. |
| `float2 CAMERA_OBSCURA_SelectDirectionC0(float2 pixel, float spatialPhase)` | Selects one of eight compass directions from pixel position and spatial phase. |
| `CAMERA_OBSCURA_RayRequest CAMERA_OBSCURA_DefaultRayRequest(float2 directionUv)` | Constructs the default ray request for a supplied UV direction. |
| `CAMERA_OBSCURA_TraceControls CAMERA_OBSCURA_BuildTraceControls(CAMERA_OBSCURA_RayRequest request)` | Clamps and normalizes a ray request into traversal controls. |
| `CAMERA_OBSCURA_Ray CAMERA_OBSCURA_BuildRayC0(float2 uv, CAMERA_OBSCURA_SurfaceGuide surface, CAMERA_OBSCURA_RayRequest request, CAMERA_OBSCURA_TraceControls controls)` | Builds a validated C0 screen-space ray from UV, surface, request, and controls. |

## `CAMERA_OBSCURA_EntryTraversal.fxh`

DDA, parametric march, and hit refinement implementations. Support surface.

Source: [`reshade-shaders/Shaders/camera_obscura/header/CAMERA_OBSCURA_EntryTraversal.fxh`](reshade-shaders/Shaders/camera_obscura/header/CAMERA_OBSCURA_EntryTraversal.fxh)

### Macros

| Name | Value | Meaning |
|---|---:|---|
| `CAMERA_OBSCURA_ENTRY_TRAVERSAL_FXH` | `—` | Header include guard; not a behavioral control. |

### Functions

| Signature | Semantics |
|---|---|
| `CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceMarch(CAMERA_OBSCURA_Ray ray, CAMERA_OBSCURA_TraceControls controls)` | Runs bounded parametric depth marching and returns a hit or explicit miss. |
| `CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceDDA(CAMERA_OBSCURA_Ray ray, CAMERA_OBSCURA_TraceControls controls)` | Runs bounded pixel-grid DDA traversal and returns a hit or explicit miss. |
| `CAMERA_OBSCURA_Hit CAMERA_OBSCURA_RefineHit(CAMERA_OBSCURA_Ray ray, CAMERA_OBSCURA_Hit coarse, CAMERA_OBSCURA_TraceControls controls)` | Refines a coarse hit for the configured iteration count without hiding failure state. |

## Completeness And Validation

`tools/build_api_symbol_index.py --check` proves that `SYMBOLS.json` matches
the packaged declarations. `tools/build_api_reference.py --check` proves this
reference is the deterministic rendering of that index and its semantic
description tables. The publication validator additionally checks that every
macro, struct, scoped field, function, and resource token appears here.

These checks prove documentation coverage and source/package consistency. They
do not prove downstream compilation, target-game depth correctness, runtime
performance, or visual acceptance.
