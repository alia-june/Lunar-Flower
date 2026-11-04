#!/usr/bin/env python3
"""Build the exhaustive human-readable Twin Lanterns API reference."""

from __future__ import annotations

import argparse
from pathlib import Path

from build_api_symbol_index import DEFAULT_API_ROOT, build_index


FILE_ROLES = {
    "CAMERA_OBSCURA_API_TwinLanternComposite.fxh": "Stable contract: final admission, containment, and bounded additive composite.",
    "CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh": "API-visible provider construction, trace evidence, and provider diagnostic signals.",
    "CAMERA_OBSCURA_API_TwinLanternReconstruction.fxh": "Stable contract plus visible helpers for same-surface separable reconstruction.",
    "CAMERA_OBSCURA_API_TwinLanternTransport.fxh": "Stable dual-provider transport contract and provider-sample helpers.",
    "CAMERA_OBSCURA_AtomicCommon.fxh": "Shared atomic types, enumerations, limits, and scalar helpers. Support surface; not independently version-promised unless named in PUBLIC_API.json.",
    "CAMERA_OBSCURA_AtomicDebug.fxh": "Shared diagnostic palettes and view composition. Support surface.",
    "CAMERA_OBSCURA_EntryCapability.fxh": "ReShade back-buffer/depth binding, surface construction, and ray setup. Support surface.",
    "CAMERA_OBSCURA_EntryTraversal.fxh": "DDA, parametric march, and hit refinement implementations. Support surface.",
    "LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh": "Experimental Alpha extension: compute-built current-frame view-frustum voxel proxy.",
}


STRUCT_ROLES = {
    "CAMERA_OBSCURA_API_TwinLanternProviderEvidence": "Complete observation record for one provider trace and refinement result.",
    "CAMERA_OBSCURA_API_TwinLanternTransportEvidence": "Complete DDA/march donor-admission and combination record.",
    "CAMERA_OBSCURA_API_TL07ProviderSample": "Internal transport-stage donor sample derived from one accepted hit.",
    "CAMERA_OBSCURA_API_TL08ResolveEvidence": "One-axis reconstruction result and every support/weight gate used to produce it.",
    "CAMERA_OBSCURA_API_TL09CompositeEvidence": "Final additive-composite request, containment, rejection, and output record.",
    "CAMERA_OBSCURA_Capabilities": "Available color, depth, projection, history, and motion-vector capabilities.",
    "CAMERA_OBSCURA_SurfaceGuide": "Per-pixel receiver/donor surface evidence reconstructed from depth and color.",
    "CAMERA_OBSCURA_RayRequest": "Unnormalized consumer request used to derive safe trace controls and a ray.",
    "CAMERA_OBSCURA_TraceControls": "Clamped trace controls consumed by DDA, march, and refinement.",
    "CAMERA_OBSCURA_Ray": "Validated screen-space ray in UV/depth parameter space.",
    "CAMERA_OBSCURA_Hit": "Terminal state for one trace or refinement attempt, including misses and reason codes.",
    "CAMERA_OBSCURA_DualHit": "Pairwise DDA/march agreement and conflict record used by diagnostics.",
    "CAMERA_OBSCURA_Contribution": "One provider's donor and indirect-light contribution evidence.",
    "CAMERA_OBSCURA_Fallback": "Fallback color, confidence, and class identifier.",
    "LUNAR_FLOWER_API_TwinLanternVoxelEvidence": "Experimental voxel-proxy trace result.",
}


FUNCTION_DESCRIPTIONS = {
    "CAMERA_OBSCURA_SafeRcp": "Returns `1 / denominator` when the magnitude is safe; otherwise returns the supplied fallback.",
    "CAMERA_OBSCURA_PixelSize": "Returns the inverse ReShade back-buffer dimensions as one-pixel UV extents.",
    "CAMERA_OBSCURA_SaturateUV": "Clamps normalized UV coordinates to the addressable screen range.",
    "CAMERA_OBSCURA_StableNoise01": "Produces deterministic screen-space scalar noise in `0..1` from a 2D value.",
    "CAMERA_OBSCURA_Luma": "Computes the implementation's scalar luminance estimate for an RGB value.",
    "CAMERA_OBSCURA_DepthConfidence": "Returns valid-depth confidence, rejecting the normalized far-plane sentinel.",
    "CAMERA_OBSCURA_ClampSteps": "Rounds a requested float step count and clamps it to `1..maxSteps`.",
    "CAMERA_OBSCURA_MakeMiss": "Constructs a fully initialized miss record for a backend and terminal reason.",
    "CAMERA_OBSCURA_EffectiveThickness": "Returns the nonnegative hit thickness carried by a validated ray.",
    "CAMERA_OBSCURA_HitConfidence": "Maps depth residual, front bias, and thickness to bounded hit confidence.",
    "CAMERA_OBSCURA_DebugHeat": "Maps a scalar to the standard diagnostic heat palette.",
    "CAMERA_OBSCURA_DebugBackendColor": "Returns the canonical diagnostic color for DDA, march, or no backend.",
    "CAMERA_OBSCURA_DebugSourceAnchor": "Darkens the source into a stable diagnostic background anchor.",
    "CAMERA_OBSCURA_DebugOverlay": "Composites a diagnostic signal over the source anchor.",
    "CAMERA_OBSCURA_DebugReasonColor": "Maps a terminal reason code to its diagnostic color.",
    "CAMERA_OBSCURA_DebugHit": "Visualizes one hit's success, reason, and confidence.",
    "CAMERA_OBSCURA_DebugContribution": "Visualizes one contribution's color and confidence-weighted support.",
    "CAMERA_OBSCURA_DebugContributionView": "Overlays one contribution visualization on source context.",
    "CAMERA_OBSCURA_DebugCompositeDelta": "Visualizes the nonnegative difference between source and composite.",
    "CAMERA_OBSCURA_DebugProviderBalance": "Visualizes DDA versus march provider weight and contribution balance.",
    "CAMERA_OBSCURA_DebugAgreement": "Visualizes DDA/march spatial, depth, distance, and conflict agreement.",
    "CAMERA_OBSCURA_DebugAgreementView": "Overlays agreement diagnostics on source context.",
    "CAMERA_OBSCURA_DebugView": "Dispatches the requested shared debug-view enumeration to a visualization.",
    "CAMERA_OBSCURA_LoadDepth": "Loads and saturates ReShade linearized depth at a safe UV.",
    "CAMERA_OBSCURA_LoadColor": "Loads back-buffer RGB at a safe UV.",
    "CAMERA_OBSCURA_BuildProxyNormal": "Approximates a view-facing surface normal from center/right/up depth differences.",
    "CAMERA_OBSCURA_QueryCapabilities": "Returns the fixed C0 capability record implemented by this ReShade binding.",
    "CAMERA_OBSCURA_BuildSurfaceGuide": "Builds validity, depth, proxy normal, confidence, edge risk, and luma for one UV.",
    "CAMERA_OBSCURA_SelectDirectionC0": "Selects one of eight compass directions from pixel position and spatial phase.",
    "CAMERA_OBSCURA_DefaultRayRequest": "Constructs the default ray request for a supplied UV direction.",
    "CAMERA_OBSCURA_BuildTraceControls": "Clamps and normalizes a ray request into traversal controls.",
    "CAMERA_OBSCURA_BuildRayC0": "Builds a validated C0 screen-space ray from UV, surface, request, and controls.",
    "CAMERA_OBSCURA_TraceMarch": "Runs bounded parametric depth marching and returns a hit or explicit miss.",
    "CAMERA_OBSCURA_TraceDDA": "Runs bounded pixel-grid DDA traversal and returns a hit or explicit miss.",
    "CAMERA_OBSCURA_RefineHit": "Refines a coarse hit for the configured iteration count without hiding failure state.",
    "CAMERA_OBSCURA_API_DefaultTwinLanternProviderEvidence": "Returns a zeroed provider-evidence record initialized to an invalid-ray miss.",
    "CAMERA_OBSCURA_API_TL45Direction": "Clamps/rounds an index and returns one of eight unit compass directions.",
    "CAMERA_OBSCURA_API_BuildTL45Receiver": "Builds live or injected receiver evidence for provider proof and diagnostics.",
    "CAMERA_OBSCURA_API_BuildTL45Ray": "Builds receiver, request, controls, and ray for a TL45 direction index.",
    "CAMERA_OBSCURA_API_BuildTL45Evidence": "Converts coarse/refined provider results into the published provider-evidence record.",
    "CAMERA_OBSCURA_API_TL45Status": "Maps a boolean-like value to fail/pass diagnostic colors.",
    "CAMERA_OBSCURA_API_TL45Signal": "Selects a provider-evidence diagnostic signal by view index.",
    "CAMERA_OBSCURA_API_DefaultTwinLanternTransportEvidence": "Returns a fully initialized empty dual-provider transport record.",
    "CAMERA_OBSCURA_API_DefaultTL07ProviderSample": "Returns a fully initialized empty donor sample.",
    "CAMERA_OBSCURA_API_BuildTL07DonorGuide": "Builds the surface guide used to validate a hit's donor location.",
    "CAMERA_OBSCURA_API_BuildTL07ProviderSample": "Converts an accepted hit into donor color, geometry support, confidence, and raw weight.",
    "CAMERA_OBSCURA_API_BuildTwinLanternTransportEvidence": "Runs DDA and march independently, validates donors, normalizes weights, and returns combined transport evidence.",
    "CAMERA_OBSCURA_API_DefaultTL08ResolveEvidence": "Returns a fully initialized empty reconstruction record.",
    "CAMERA_OBSCURA_API_DefaultTL08Guide": "Returns an invalid default surface guide for unavailable taps.",
    "CAMERA_OBSCURA_API_BuildTL08Guide": "Builds the reconstruction guide for a UV.",
    "CAMERA_OBSCURA_API_TL08DepthSupport": "Computes bounded center/tap depth compatibility under a tolerance.",
    "CAMERA_OBSCURA_API_TL08NormalSupport": "Computes bounded center/tap proxy-normal agreement above a minimum.",
    "CAMERA_OBSCURA_API_TL08EdgeSupport": "Reduces tap support according to center/tap edge risk and protection strength.",
    "CAMERA_OBSCURA_API_ResolveTL08Axis": "Resolves three RGBA evidence samples across one axis and returns all admission weights and supports.",
    "CAMERA_OBSCURA_API_DefaultTL09CompositeEvidence": "Returns an empty composite record configured as rejected but bounds-valid.",
    "CAMERA_OBSCURA_API_BuildTL09Composite": "Applies enabled/receiver/evidence/strength admission, then nonnegative maximum and channel-room bounds.",
    "LUNAR_FLOWER_API_DefaultTwinLanternVoxelEvidence": "Returns an empty experimental voxel trace record.",
    "LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS": "Compute entrypoint that clears/populates the camera-visible 3D proxy from current color and depth.",
    "LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface": "Loads the proxy cell corresponding to a UV's visible depth shell.",
    "LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy": "Marches the proxy along one screen-space ray direction and returns the first admitted occupied cell.",
}


RESOURCE_DESCRIPTIONS = {
    "LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceTex": "`64 x 36 x 32` RGBA16F proxy texture; RGB stores visible radiance and alpha stores occupancy.",
    "LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceStorage": "Writable `storage3D` view used by the compute build pass.",
    "LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceSampler": "Point-filtered, clamped sampler used for cell-exact proxy reads.",
}


BASE_FIELDS = {
    "tier": "Capability tier enumeration.",
    "valid": "Boolean-like validity mask for this record.",
    "hit": "Boolean-like accepted-hit mask.",
    "reason": "Terminal `CAMERA_OBSCURA_REASON_*` code.",
    "confidence": "Bounded confidence assigned to this result.",
    "backend": "`CAMERA_OBSCURA_BACKEND_*` identifier.",
    "provider_backend": "Provider backend identifier.",
    "requested_steps": "Requested trace-step count before/for bounded execution.",
    "receiver_valid": "Receiver-surface validity mask.",
    "receiver_edge_risk": "Receiver depth-discontinuity risk.",
    "ray_valid": "Ray validity mask.",
    "direction_uv": "Normalized screen-space ray direction.",
    "hit_uv": "Accepted hit location in normalized screen coordinates.",
    "step_index": "Traversal/refinement step at which the terminal state occurred.",
    "terminal_depth": "Scene depth observed at the terminal sample.",
    "interval_min": "Lower supported depth interval bound.",
    "interval_max": "Upper supported depth interval bound.",
    "interval_support": "Boolean-like mask showing whether the hit interval is supported.",
    "thickness_used": "Effective nonnegative thickness used by the hit test.",
    "coarse_residual": "Absolute depth residual before refinement.",
    "refined_residual": "Absolute depth residual after refinement.",
    "refinement_not_worse": "Mask indicating refinement did not increase residual.",
    "refinement_steps": "Configured or completed refinement count.",
    "transport_mode": "Selected `CAMERA_OBSCURA_API_TL07_MODE_*` value.",
    "transport_enabled": "Mask enabling complementary donor transport.",
    "provider_count": "Number of providers with positive admitted weight.",
    "total_raw_weight": "Sum of admitted provider raw weights.",
    "normalized_weight_sum": "Sum of normalized provider weights.",
    "evidence_strength": "Bounded combined transport evidence.",
    "combined_donor_rgb": "Normalized-weight blend of admitted donor colors.",
    "raw_radiance_rgb": "Combined donor radiance multiplied by evidence strength.",
    "zero_contribution": "Mask indicating no provider contribution survived.",
    "donor_rgb": "Sampled donor color.",
    "distance_pixels": "Receiver-to-donor distance in pixels.",
    "distance_weight": "Distance falloff weight.",
    "receiver_facing": "Receiver-facing compatibility term.",
    "donor_facing": "Donor-facing compatibility term.",
    "normal_compatibility": "Combined receiver/donor proxy-normal compatibility.",
    "hit_confidence": "Confidence inherited from the accepted hit.",
    "raw_weight": "Pre-normalization provider weight.",
    "resolved_rgb": "Reconstructed indirect RGB for the axis.",
    "trusted_weight": "Kernel-normalized evidence retained by reconstruction.",
    "weight_sum": "Sum of admitted negative, center, and positive weights.",
    "kernel_capacity": "Maximum represented kernel weight for available taps.",
    "center_valid": "Center surface-guide validity.",
    "center_evidence": "Input alpha evidence at the center sample.",
    "minimum_depth_support": "Minimum depth support across available neighbors.",
    "minimum_normal_support": "Minimum normal support across available neighbors.",
    "minimum_edge_support": "Minimum edge support across available neighbors.",
    "zero_weight": "Mask indicating reconstruction admitted no weight.",
    "source_rgb": "Original source RGB after safety saturation.",
    "indirect_rgb": "Resolved indirect RGB supplied to the composite.",
    "weighted_indirect_rgb": "Indirect RGB after evidence, strength, and admission.",
    "bounded_indirect_rgb": "Weighted indirect RGB after nonnegative maximum-contribution bounds.",
    "remaining_room_rgb": "Per-channel normalized room remaining above source RGB.",
    "bounded_contribution_rgb": "Final per-channel contribution allowed by all ceilings.",
    "final_rgb": "Source plus bounded contribution.",
    "evidence": "Bounded evidence supporting the result.",
    "enabled": "Effect-enabled mask.",
    "strength": "Nonnegative requested effect strength.",
    "maximum_contribution": "Configured per-channel addition ceiling.",
    "admission": "Product of enabled, receiver, evidence, and strength gates.",
    "application": "Mask indicating a nonzero contribution was applied.",
    "rejection": "Complement of application/admission state used by diagnostics.",
    "rejection_code": "Composite-stage reason code for the first failed gate.",
    "containment_activity": "Magnitude/activity mask showing requested light was clipped.",
    "source_preserve_delta": "Measured deviation from source preservation when no application is authorized.",
    "bounds_valid": "Mask confirming lower, ceiling, and final-output bounds hold.",
    "has_color": "Color-input capability flag.",
    "has_depth": "Depth-input capability flag.",
    "has_linear_view_z": "Linearized view-depth capability flag.",
    "has_projection": "Projection-matrix capability flag.",
    "has_inverse_projection": "Inverse-projection capability flag.",
    "has_history": "Temporal-history capability flag.",
    "has_motion_vectors": "Motion-vector capability flag.",
    "depth_metric": "`CAMERA_OBSCURA_DEPTH_METRIC_*` identifier.",
    "depth": "Linearized depth at the guided surface.",
    "normal": "Depth-derived proxy surface normal.",
    "depth_confidence": "Depth validity reduced by local discontinuity risk.",
    "edge_risk": "Local depth-discontinuity risk.",
    "luma": "Source luminance at the guided surface.",
    "ray_length_uv": "Requested or clamped ray length in UV space.",
    "ray_depth_slope": "Depth change per unit of ray travel.",
    "front_bias": "Front-side depth bias used by intersection tests.",
    "back_thickness": "Back-side hit thickness.",
    "confidence_min": "Minimum confidence requested for acceptance.",
    "self_hit_pixels": "Minimum pixel travel before self-hit rejection clears.",
    "distance_fade": "Distance falloff control.",
    "pixel_stride": "Pixel-grid traversal stride.",
    "spatial_phase": "Deterministic phase/jitter selector.",
    "steps": "Clamped executable traversal-step count.",
    "capability_tier": "Capability tier carried by the ray/hit.",
    "origin_uv": "Ray origin in normalized screen coordinates.",
    "step_uv": "Per-step UV displacement.",
    "origin_depth": "Linearized depth at the ray origin.",
    "step_depth": "Per-step depth displacement.",
    "t_min": "Minimum permitted ray parameter.",
    "t_max": "Maximum permitted ray parameter.",
    "uv": "Terminal or accepted UV.",
    "previous_uv": "UV from the prior traversal sample.",
    "ray_t": "Ray parameter at the terminal sample.",
    "previous_ray_z": "Ray depth at the prior sample.",
    "ray_z": "Ray depth at the terminal sample.",
    "scene_z": "Scene depth at the terminal sample.",
    "delta": "Signed ray-versus-scene depth residual.",
    "dda_hit": "DDA accepted-hit mask or DDA hit record, according to type.",
    "dda_confidence": "DDA hit confidence.",
    "dda_reason": "DDA terminal reason code.",
    "march_hit": "March accepted-hit mask or march hit record, according to type.",
    "march_confidence": "March hit confidence.",
    "march_reason": "March terminal reason code.",
    "uv_agreement": "DDA/march hit-position agreement.",
    "depth_agreement": "DDA/march scene-depth agreement.",
    "distance_agreement": "DDA/march travel-distance agreement.",
    "conflict": "Mask indicating material provider disagreement.",
    "combined_confidence": "Agreement-aware combined provider confidence.",
    "one_provider_bound_ok": "Mask confirming the resolved transport does not exceed the strongest single-provider bound.",
    "indirect_rgb": "Indirect-light RGB carried by a contribution.",
    "weight": "Contribution weight.",
    "coverage": "Screen/sample coverage supporting the contribution.",
    "rgb": "Fallback RGB.",
    "class_id": "Fallback classification identifier.",
    "radiance_rgb": "Voxel-proxy radiance returned by the trace.",
    "normalized_distance": "Accepted voxel distance normalized by the trace budget.",
}


def field_description(struct_name: str, name: str) -> str:
    if name == "indirect_rgb":
        if struct_name == "CAMERA_OBSCURA_API_TL09CompositeEvidence":
            return "Resolved indirect RGB supplied to the bounded composite."
        if struct_name == "CAMERA_OBSCURA_Contribution":
            return "Indirect-light RGB carried by a contribution."
    for prefix, label in (
        ("dda_", "DDA provider: "),
        ("march_", "March provider: "),
        ("negative_", "Negative-axis tap: "),
        ("positive_", "Positive-axis tap: "),
        ("center_", "Center tap: "),
    ):
        if name.startswith(prefix) and name[len(prefix) :] in BASE_FIELDS:
            return label + BASE_FIELDS[name[len(prefix) :]].lower()
    if name.endswith("_available"):
        return "Availability/coverage mask for the named reconstruction tap."
    if name.endswith("_depth_support"):
        return "Depth-compatibility support for the named reconstruction tap."
    if name.endswith("_normal_support"):
        return "Proxy-normal compatibility for the named reconstruction tap."
    if name.endswith("_edge_support"):
        return "Edge-risk support for the named reconstruction tap."
    if name.endswith("_admitted_weight"):
        return "Final admitted reconstruction weight for the named tap."
    if name.endswith("_donor_valid"):
        return "Donor-surface validity for the named provider."
    if name.endswith("_donor_rgb"):
        return "Donor RGB sampled by the named provider."
    if name.endswith("_normalized_weight"):
        return "Normalized blend weight for the named provider."
    if name.endswith("_weight_active"):
        return "Mask describing whether the named provider combination has positive weight."
    return BASE_FIELDS.get(name, f"Stored `{name}` value for this record.")


def macro_description(name: str, value: str, include_guard: bool) -> str:
    if include_guard:
        return "Header include guard; not a behavioral control."
    exact = {
        "CAMERA_OBSCURA_API_VERSION_MAJOR": "API semantic-version major component.",
        "CAMERA_OBSCURA_API_VERSION_MINOR": "API semantic-version minor component.",
        "CAMERA_OBSCURA_API_VERSION_PATCH": "API semantic-version patch component.",
        "CAMERA_OBSCURA_DEPTH_METRIC_NONE": "No usable depth metric.",
        "CAMERA_OBSCURA_DEPTH_METRIC_LINEAR01": "ReShade linearized depth normalized to `0..1`.",
        "CAMERA_OBSCURA_BACKEND_NONE": "No traversal backend.",
        "CAMERA_OBSCURA_BACKEND_DDA": "Pixel-grid DDA traversal backend.",
        "CAMERA_OBSCURA_BACKEND_MARCH": "Parametric march traversal backend.",
        "CAMERA_OBSCURA_DDA_MAX_STEPS": "Compile-time maximum DDA steps.",
        "CAMERA_OBSCURA_MARCH_MAX_STEPS": "Compile-time maximum march steps.",
        "CAMERA_OBSCURA_REFINE_STEPS": "Default hit-refinement iteration count.",
        "CAMERA_OBSCURA_MARCH_STEP_JITTER_STRENGTH": "Deterministic march-step jitter amplitude.",
        "CAMERA_OBSCURA_MARCH_DONOR_PREFILTER_STRENGTH": "March donor prefilter blend strength.",
        "CAMERA_OBSCURA_API_TL45_INPUT_LIVE": "Use live ReShade receiver/depth input.",
        "CAMERA_OBSCURA_API_TL45_INPUT_INVALID_RECEIVER": "Inject an invalid receiver for proof diagnostics.",
        "CAMERA_OBSCURA_API_TL45_INPUT_ZERO_DIRECTION": "Inject a zero direction for proof diagnostics.",
        "CAMERA_OBSCURA_API_TL07_MODE_PARITY": "Trace providers but do not admit complementary transport.",
        "CAMERA_OBSCURA_API_TL07_MODE_COMPLEMENTARY": "Admit independently supported DDA and march donor samples.",
        "LUNAR_FLOWER_TL_VOXEL_WIDTH": "Experimental proxy width in cells.",
        "LUNAR_FLOWER_TL_VOXEL_HEIGHT": "Experimental proxy height in cells.",
        "LUNAR_FLOWER_TL_VOXEL_DEPTH": "Experimental proxy depth in cells.",
        "LUNAR_FLOWER_TL_VOXEL_MAX_TRACE_STEPS": "Compile-time maximum voxel-proxy trace steps.",
    }
    if name in exact:
        return exact[name]
    if name.startswith("CAMERA_OBSCURA_CAP_TIER_"):
        return "Capability-tier enumeration; 0.1.0's ReShade binding reports C0."
    if name.startswith("CAMERA_OBSCURA_REASON_"):
        reason = name.removeprefix("CAMERA_OBSCURA_REASON_").replace("_", " ").lower()
        return f"Terminal trace state: {reason}."
    if name.startswith("CAMERA_OBSCURA_DEBUG_VIEW_"):
        view = name.removeprefix("CAMERA_OBSCURA_DEBUG_VIEW_").replace("_", " ").lower()
        return f"Shared debug-view selector: {view}."
    if name.startswith("CAMERA_OBSCURA_DEBUG_"):
        return "Compile-time tuning constant for shared diagnostic presentation."
    return f"Compile-time constant with published value `{value}`."


def build_reference(api_root: Path = DEFAULT_API_ROOT) -> str:
    index = build_index(api_root)
    summary = index["summary"]
    lines = [
        "# Twin Lanterns API 0.1.0 — Complete Reference",
        "",
        "This document inventories every top-level declaration shipped in the eight shared",
        "include files and the experimental voxel extension. It complements the",
        "[architecture and integration guide](README.md) and the machine-readable",
        "[symbol index](SYMBOLS.json).",
        "",
        f"Coverage: **{summary['source_files']} source files · {summary['macros']} macros · "
        f"{summary['structs']} structs · {summary['struct_fields']} fields · "
        f"{summary['functions']} functions · {summary['resources']} resources**.",
        "",
        "## Stability Legend",
        "",
        "- **Stable contract** — the twelve type/constructor/entrypoint symbols listed in `PUBLIC_API.json`.",
        "- **Support surface** — visible shared implementation symbols required by the package; callable, but not independently promised across a future version.",
        "- **Experimental** — Alpha voxel symbols and resources; excluded from the shared 0.1.0 stability promise.",
        "- Include guards are inventoried for completeness but have no runtime semantics.",
        "",
        "## Global Conventions",
        "",
        "- Float masks use `0.0` and `1.0` as boolean-like states.",
        "- UV coordinates are normalized screen coordinates.",
        "- Depth is ReShade linearized depth under the target installation's configuration.",
        "- RGB values are normalized for the shared SDR bounded-composite contract.",
        "- Working-field RGB carries radiance; alpha carries explicit evidence.",
        "- Zero evidence means unsupported, not valid darkness.",
        "",
    ]

    for source in index["sources"]:
        name = Path(source["path"]).name
        lines.extend(
            [
                f"## `{name}`",
                "",
                FILE_ROLES[name],
                "",
                f"Source: [`{source['path']}`]({source['path']})",
                "",
            ]
        )
        if source["macros"]:
            lines.extend(["### Macros", "", "| Name | Value | Meaning |", "|---|---:|---|"])
            for macro in source["macros"]:
                value = macro["value"] or "—"
                lines.append(
                    f"| `{macro['name']}` | `{value}` | "
                    f"{macro_description(macro['name'], macro['value'], macro['include_guard'])} |"
                )
            lines.append("")
        if source["resources"]:
            lines.extend(["### Resources", "", "| Declaration | Meaning |", "|---|---|"])
            for resource in source["resources"]:
                lines.append(
                    f"| `{resource['kind']} {resource['name']}` | "
                    f"{RESOURCE_DESCRIPTIONS[resource['name']]} |"
                )
            lines.append("")
        for struct in source["structs"]:
            lines.extend(
                [
                    f"### `{struct['name']}`",
                    "",
                    STRUCT_ROLES[struct["name"]],
                    "",
                    "| Scoped field | Type | Meaning |",
                    "|---|---|---|",
                ]
            )
            for field in struct["fields"]:
                lines.append(
                    f"| `{struct['name']}.{field['name']}` | `{field['type']}` | "
                    f"{field_description(struct['name'], field['name'])} |"
                )
            lines.append("")
        if source["functions"]:
            lines.extend(["### Functions", "", "| Signature | Semantics |", "|---|---|"])
            for function in source["functions"]:
                signature = (
                    f"{function['return_type']} {function['name']}({function['parameters']})"
                )
                lines.append(
                    f"| `{signature}` | {FUNCTION_DESCRIPTIONS[function['name']]} |"
                )
            lines.append("")

    lines.extend(
        [
            "## Completeness And Validation",
            "",
            "`tools/build_api_symbol_index.py --check` proves that `SYMBOLS.json` matches",
            "the packaged declarations. `tools/build_api_reference.py --check` proves this",
            "reference is the deterministic rendering of that index and its semantic",
            "description tables. The publication validator additionally checks that every",
            "macro, struct, scoped field, function, and resource token appears here.",
            "",
            "These checks prove documentation coverage and source/package consistency. They",
            "do not prove downstream compilation, target-game depth correctness, runtime",
            "performance, or visual acceptance.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-root", type=Path, default=DEFAULT_API_ROOT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    api_root = args.api_root.resolve()
    output = api_root / "REFERENCE.md"
    generated = build_reference(api_root)
    if args.check:
        current = output.read_text(encoding="utf-8") if output.is_file() else ""
        if current != generated:
            print(f"FAIL|api_reference_current|regenerate {output}")
            return 1
        print(f"PASS|api_reference_current|{output}")
        return 0
    output.write_text(generated, encoding="utf-8", newline="\n")
    print(f"WROTE|{output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
