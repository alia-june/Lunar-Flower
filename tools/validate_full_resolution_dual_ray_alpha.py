from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from audit_twin_lantern_loop_sampling import audit_directory


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "Twin-Lanterns" / "Full-Resolution-Dual-Ray-Alpha"
SHADERS = BUILD / "reshade-shaders" / "Shaders" / "camera_obscura"
EFFECT = SHADERS / "effects" / "LUNAR_FLOWER_TwinLanterns_FullResolutionDualRayAlpha.fx"
VOXEL = SHADERS / "api" / "LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh"
SURFACE = SHADERS / "api" / "LUNAR_FLOWER_TwinLanternScreenSurface.fxh"
FIDELITY = ROOT / "Twin-Lanterns" / "Fidelity-Overdrive" / "reshade-shaders" / "Shaders" / "camera_obscura"
RESULT = BUILD / "STATIC_VALIDATION_RESULTS.json"

SHARED = [
    "api/CAMERA_OBSCURA_API_TwinLanternTransport.fxh",
    "api/CAMERA_OBSCURA_API_TwinLanternReconstruction.fxh",
    "api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh",
    "api/CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh",
    "header/CAMERA_OBSCURA_AtomicCommon.fxh",
    "header/CAMERA_OBSCURA_AtomicDebug.fxh",
    "header/CAMERA_OBSCURA_EntryCapability.fxh",
    "header/CAMERA_OBSCURA_EntryTraversal.fxh",
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


checks: list[dict[str, object]] = []


def record(name: str, passed: bool, detail: str) -> None:
    checks.append({"name": name, "passed": passed, "detail": detail})
    print(f"{'PASS' if passed else 'FAIL'}|{name}|{detail}")


required = [
    EFFECT,
    VOXEL,
    SURFACE,
    BUILD / "README.md",
    BUILD / "LINEAGE.json",
    BUILD / "DESIGN_RECORD.md",
    BUILD / "LIVE_RESULT_TEMPLATE.csv",
] + [SHADERS / item for item in SHARED]
missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
record(
    "candidate_surface_complete",
    not missing,
    f"required files present={len(required) - len(missing)}/{len(required)}"
    if not missing
    else "missing=" + ", ".join(missing),
)

effect = EFFECT.read_text(encoding="utf-8") if EFFECT.is_file() else ""
voxel = VOXEL.read_text(encoding="utf-8") if VOXEL.is_file() else ""
surface = SURFACE.read_text(encoding="utf-8") if SURFACE.is_file() else ""
readme = (BUILD / "README.md").read_text(encoding="utf-8") if (BUILD / "README.md").is_file() else ""

include_pattern = re.compile(r'^\s*#include\s+"([^"]+)"', re.MULTILINE)
include_failures: list[str] = []
for source in list(SHADERS.rglob("*.fx")) + list(SHADERS.rglob("*.fxh")):
    for include in include_pattern.findall(source.read_text(encoding="utf-8")):
        if include == "ReShade.fxh":
            continue
        target = (source.parent / include).resolve()
        if not target.is_file() or SHADERS.resolve() not in target.parents:
            include_failures.append(f"{source.name}:{include}")
record(
    "local_include_closure",
    not include_failures,
    "zero missing or escaping local includes"
    if not include_failures
    else "failures=" + ", ".join(include_failures),
)

identity_ok = all(
    token in effect
    for token in [
        "LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlpha",
        "Lunar Flower - Twin Lanterns: Full Resolution Dual Ray Alpha",
        "LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaRayPairs",
        "LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength",
        "LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelTraceSteps",
    ]
)
record("distinct_public_identity", identity_ok, "candidate technique and controls are distinct")

textures = re.findall(
    r"texture2D\s+LUNAR_FLOWER_TLFR(?:Raw|ResolveH|ResolveV)Tex\s*\{(.*?)\};",
    effect,
    re.DOTALL,
)
full_resolution = len(textures) == 3 and all(
    "Width = BUFFER_WIDTH;" in body
    and "Height = BUFFER_HEIGHT;" in body
    and "/ 2" not in body
    for body in textures
)
record("full_resolution_transport_fields", full_resolution, f"full-resolution RGBA fields={len(textures)}/3")

ray_schedule_ok = all(
    token in effect
    for token in [
        "ui_min = 1; ui_max = 4",
        "pairIndex < 4",
        "directionIndex + 4.0",
        "pairCount * 2",
    ]
)
record("variable_opposing_ray_pairs", ray_schedule_ok, "one to four pairs schedule two to eight rays")

dual_provider_ok = "LUNAR_FLOWER_TLFRTraceScreenWithReceiver(" in effect and all(
    token in surface
    for token in ["CAMERA_OBSCURA_TraceDDA", "CAMERA_OBSCURA_TraceMarch", "totalWeight * 0.5"]
)
record("dual_provider_per_direction", dual_provider_ok, "DDA and parametric march remain independently evaluated")
record(
    "alpha_surface_guide_wiring",
    "CAMERA_OBSCURA_API_BuildTL08Guide(" not in effect
    and "LUNAR_FLOWER_TLFRBuildSurfaceGuide(" in effect
    and "guide.depth_confidence = guide.valid;" in surface,
    "Alpha transport/resolve/fill use the local surface guide; CPU fixtures check behavior separately",
)
record(
    "alpha_refinement_wiring",
    surface.count("LUNAR_FLOWER_TLFRRefineScreenHit(ray,") == 2
    and "CAMERA_OBSCURA_RefineHit(ray," not in surface
    and "distancePixels > max(controls.self_hit_pixels, 0.0)" in surface
    and "distancePixels > max(selfHitPixels, 0.0)" in surface,
    "both Alpha screen providers use guarded refinement and final self-hit admission; CPU fixtures check behavior separately",
)

voxel_ok = all(
    token in voxel
    for token in [
        "texture3D LUNAR_FLOWER_TLAdaptiveAtlasV1Tex",
        "storage3D LUNAR_FLOWER_TLAdaptiveAtlasV1Storage",
        "Width = LUNAR_FLOWER_TL_VOXEL_WIDTH",
        "Depth = LUNAR_FLOWER_TL_VOXEL_DEPTH",
        "#define LUNAR_FLOWER_TL_VOXEL_DEPTH 21",
        "Format = RGBA32F",
        "tex3Dstore",
        "tex3Dfetch",
        "SV_DispatchThreadID",
    ]
)
record("view_frustum_voxel_proxy", voxel_ok, "bounded 64x36x21 RGBA32F hierarchy atlas and trace surface present")
record(
    "adaptive_hierarchy_wiring",
    all(token in voxel for token in ["splitRoot", "splitChild", "node < LUNAR_FLOWER_TL_VOXEL_DEPTH", "LUNAR_FLOWER_API_LoadTwinLanternVoxelNode"])
    and "BuildVoxelProxyCS<8, 8, 1>" in effect and "DispatchSizeZ = 1;" in effect,
    "two-level adaptive node construction, per-frame child clearing and one-thread-per-root dispatch; CPU fixtures check behavior separately",
)
record(
    "voxel_fine_validation",
    all(token in voxel for token in [
        "float sceneDepth = CAMERA_OBSCURA_LoadDepth(requestedUv)",
        "float4(requestedUv, 0.0, 0.0)).rgb",
        "distancePixels <= controls.self_hit_pixels",
        "int stepCount = min((int)ray.steps",
    ]),
    "proxy candidates require fine depth and full-resolution donor color, self-distance rejection and the actual ray budget",
)
record(
    "inactive_work_guards",
    "LUNAR_FLOWER_TLFRBuildVoxelProxyCS<8, 8, 1>" in effect
    and "!LUNAR_FLOWER_TLFRSourceOnly()" in effect
    and effect.count("if (LUNAR_FLOWER_TLFRSourceOnly())") == 4,
    "inactive/source-only builds and working passes are guarded; CPU fixtures execute the actual guards",
)
record(
    "receiver_guide_reuse",
    "LUNAR_FLOWER_API_TraceTwinLanternVoxelProxyWithReceiver(" in effect
    and "LUNAR_FLOWER_TLFRFullResolutionReconstruct(uv, centerGuide)" in effect
    and "float receiverValid = centerGuide.valid;" in effect,
    "transport and final reconstruction reuse current-pixel receiver data; CPU fixtures check output equivalence/read counts",
)
gradient_failures = audit_directory(SHADERS)
record(
    "loop_sampling_derivative_free",
    not gradient_failures,
    "no implicit-gradient operations reachable from active Alpha loop entrypoints"
    if not gradient_failures else " | ".join(gradient_failures),
)
record(
    "adaptive_resource_layout_identity",
    "LUNAR_FLOWER_TLAdaptiveAtlasV1Tex" in voxel
    and "FullResolutionDualRayAlphaVoxelRadianceTex" not in voxel,
    "adaptive atlas has a distinct resource identity from the former uniform volume",
)

record(
    "depth_shaping_wiring",
    "LUNAR_FLOWER_TLFRApplyDepthShaping(uv, reconstructed, centerGuide)" in effect
    and "saturate(shaped.a) * fade" in effect
    and "LUNAR_FLOWER_TLFRDepthFadeFactor" in effect,
    "receiver-depth fade follows edge fill/softening and precedes render intent/composite; CPU fixtures verify behavior",
)
record(
    "light_only_softening_wiring",
    effect.count("LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(uv ") == 4
    and "float3 baseSignal = saturate(baseIndirect.rgb) * baseEvidence" in effect
    and "mixedSignal" in effect and "mixedEvidence" in effect,
    "four existing depth/normal/coverage-gated ResolveV taps soften premultiplied light without a new texture/pass",
)

passes = re.findall(r"\bpass\s+(\w+)", effect)
expected_passes = [
    "TwinLanternVoxelBuild",
    "TwinLanternTransport",
    "TwinLanternResolveHorizontal",
    "TwinLanternResolveVertical",
    "TwinLanternComposite",
]
record("ordered_five_pass_graph", passes == expected_passes, f"pass order={passes}")

truth_text = (voxel + "\n" + readme).lower()
truth_ok = all(
    token in truth_text
    for token in ["current-frame", "camera-visible", "not world voxelization"]
)
record("voxel_truth_boundary", truth_ok, "proxy is explicitly bounded away from world-voxel claims")

ui_items_match = re.search(r'ui_items\s*=\s*"([^"]+)"', effect)
diagnostic_count = ui_items_match.group(1).count("\\0") if ui_items_match else 0
record("candidate_diagnostics", diagnostic_count == 18, f"diagnostic views={diagnostic_count}/18")

shared_matches = sum(
    1
    for item in SHARED
    if (SHADERS / item).is_file()
    and (FIDELITY / item).is_file()
    and digest(SHADERS / item) == digest(FIDELITY / item)
)
record("shared_api_lineage_unchanged", shared_matches == len(SHARED), f"source-identical shared files={shared_matches}/{len(SHARED)}")

composite = (SHADERS / "api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh").read_text(encoding="utf-8")
bounds_ok = all(
    token in composite
    for token in [
        "max(weightedIndirect, 0.0.xxx)",
        "safeMaximum.xxx",
        "float3 channelCeiling = min(safeMaximum.xxx, remainingRoom)",
        "float3 boundedContribution = min(boundedIndirect, channelCeiling)",
        "float3 finalRgb = safeSource + boundedContribution",
    ]
)
record("bounded_composite_unchanged", bounds_ok, "nonnegative contribution and channel-room ceiling retained")

active_source = effect + "\n" + voxel
history_ok = not re.search(
    r"\b(?:texture[123]D|sampler[123]D|storage[123]D)\s+\w*(?:history|temporal|previous|motion)\w*",
    active_source,
    re.IGNORECASE,
)
record("no_temporal_history", history_ok, "candidate adds no history or motion-vector resource")

passed = sum(1 for check in checks if check["passed"])
payload = {
    "status": "public alpha; static structural validation only; full ReShade compile and live acceptance pending",
    "passed": passed,
    "failed": len(checks) - passed,
    "effect_sha256": digest(EFFECT) if EFFECT.is_file() else None,
    "voxel_api_sha256": digest(VOXEL) if VOXEL.is_file() else None,
    "screen_surface_sha256": digest(SURFACE) if SURFACE.is_file() else None,
    "checks": checks,
}
RESULT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
print(f"SUMMARY|passed={passed}|failed={len(checks) - passed}")
raise SystemExit(0 if passed == len(checks) else 1)
