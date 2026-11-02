#!/usr/bin/env python3
"""Reproducible structural validation for the Lunar Flower publication tree."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TWINS = ROOT / "Twin-Lanterns"
STABLE = TWINS / "Stable-1.4"
OVERDRIVE = TWINS / "Fidelity-Overdrive"
STABLE_SHADER_ROOT = STABLE / "reshade-shaders" / "shaders"
OVERDRIVE_SHADER_ROOT = OVERDRIVE / "reshade-shaders" / "Shaders"
STABLE_EFFECT = (
    STABLE_SHADER_ROOT
    / "camera_obscura"
    / "effects"
    / "CAMERA_OBSCURA_TwinLantern.fx"
)
OVERDRIVE_EFFECT = (
    OVERDRIVE_SHADER_ROOT
    / "camera_obscura"
    / "effects"
    / "LUNAR_FLOWER_TwinLanterns_FidelityOverdrive.fx"
)
RESULT_PATH = OVERDRIVE / "PUBLICATION_VALIDATION_RESULTS.json"

checks: list[dict[str, object]] = []


def record(name: str, passed: bool, detail: str) -> None:
    checks.append({"name": name, "passed": bool(passed), "detail": detail})


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def function_body(source: str, name: str) -> str:
    start = source.find(name)
    if start < 0:
        return ""
    brace = source.find("{", start)
    if brace < 0:
        return ""
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : index]
    return ""


def include_closure(shader_root: Path) -> tuple[bool, list[str]]:
    missing: list[str] = []
    include_pattern = re.compile(r'^\s*#include\s+"([^"]+)"', re.MULTILINE)
    for source_path in shader_root.rglob("*"):
        if source_path.suffix.lower() not in {".fx", ".fxh"}:
            continue
        for include in include_pattern.findall(read(source_path)):
            if include == "ReShade.fxh":
                continue
            candidate = (source_path.parent / include).resolve()
            try:
                candidate.relative_to(shader_root.resolve())
            except ValueError:
                missing.append(f"unsafe:{source_path.relative_to(shader_root)}:{include}")
                continue
            if not candidate.is_file():
                missing.append(f"missing:{source_path.relative_to(shader_root)}:{include}")
    return not missing, missing


required_files = [
    ROOT / "LICENSE",
    ROOT / "README.md",
    TWINS / "README.md",
    STABLE / "README.md",
    OVERDRIVE / "README.md",
    OVERDRIVE / "SOURCE_VALIDATION_RESULTS.json",
    OVERDRIVE / "LINEAGE.json",
    OVERDRIVE / "LIVE_RESULT_TEMPLATE.csv",
    STABLE_EFFECT,
    OVERDRIVE_EFFECT,
]
record(
    "publication_surface_complete",
    all(path.is_file() for path in required_files),
    f"required files present={sum(path.is_file() for path in required_files)}/{len(required_files)}",
)

for label, shader_root in (
    ("stable", STABLE_SHADER_ROOT),
    ("fidelity_overdrive", OVERDRIVE_SHADER_ROOT),
):
    ok, missing = include_closure(shader_root)
    record(
        f"{label}_local_include_closure",
        ok,
        "zero missing or escaping local includes" if ok else "; ".join(missing),
    )

stable_source = read(STABLE_EFFECT)
overdrive_source = read(OVERDRIVE_EFFECT)
lineage = json.loads(read(OVERDRIVE / "LINEAGE.json"))

record(
    "stable_1_4_identity_preserved",
    "technique CAMERA_OBSCURA_TwinLantern" in stable_source
    and "LUNAR_FLOWER_TwinLanterns" not in stable_source
    and "CAMERA_OBSCURA_TwinLanternFidelityGuard" not in stable_source
    and "CAMERA_OBSCURA_TwinLanternOverdrive" not in stable_source,
    "stable public identifiers retained and fidelity/overdrive controls absent",
)

public_uniforms = re.findall(
    r"\buniform\s+(?:int|bool|float)\s+(LUNAR_FLOWER_TwinLanterns\w+)\s*\n"
    r"<.*?>\s*=\s*([^;]+);",
    overdrive_source,
    re.DOTALL,
)
record(
    "fidelity_overdrive_public_identity",
    len(public_uniforms) == 16
    and all(default.strip() for _, default in public_uniforms)
    and "technique LUNAR_FLOWER_TwinLanternsFidelityOverdrive"
    in overdrive_source
    and 'ui_label = "Lunar Flower - Twin Lanterns: Fidelity Overdrive"'
    in overdrive_source
    and "Camera Obscura / Twin Lantern /" not in overdrive_source,
    f"initialized Lunar Flower controls={len(public_uniforms)}/16",
)

reversed_public_source = (
    overdrive_source
    .replace(
        "technique LUNAR_FLOWER_TwinLanternsFidelityOverdrive",
        "technique CAMERA_OBSCURA_TwinLantern",
    )
    .replace("LUNAR_FLOWER_TwinLanterns", "CAMERA_OBSCURA_TwinLantern")
    .replace("Lunar Flower / Twin Lanterns /", "Camera Obscura / Twin Lantern /")
    .replace(
        "Lunar Flower - Twin Lanterns: Fidelity Overdrive",
        "Camera Obscura - Twin Lantern",
    )
)
reversed_public_hash = hashlib.sha256(
    reversed_public_source.encode("utf-8")
).hexdigest().upper()
record(
    "public_refactor_matches_recorded_source",
    reversed_public_hash == lineage["source_effect_sha256"],
    f"reverse-mapped source sha256={reversed_public_hash}",
)

view_match = re.search(
    r'LUNAR_FLOWER_TwinLanternsView\s*\n<.*?ui_items = "([^"]+)"',
    overdrive_source,
    re.DOTALL,
)
views = view_match.group(1).split("\\0") if view_match else []
if views and views[-1] == "":
    views.pop()
record(
    "fidelity_overdrive_diagnostics",
    len(views) == 14
    and "Fidelity Guard Activity" in views
    and "Overdrive Pressure" in views
    and "Bound Verification" in views,
    f"diagnostic views={len(views)}/14",
)

intent = function_body(overdrive_source, "CAMERA_OBSCURA_TL09ApplyRenderIntent")
composite = function_body(overdrive_source, "CAMERA_OBSCURA_TL09EvaluateComposite")
edge_fill = function_body(overdrive_source, "CAMERA_OBSCURA_TL09ApplyEdgeFill")
record(
    "independent_bounded_render_intent",
    "safeSource * indirectLuma" in intent
    and "highlightGain = 1.0 - safeFidelity * highlightRisk * 0.85" in intent
    and "overdriveGain = 1.0 + safeOverdrive * 2.0" in intent
    and "highlightGain * overdriveGain" in intent
    and "effectiveStrength" in composite
    and "LUNAR_FLOWER_TwinLanternsMaximumContribution" in composite,
    "fidelity and overdrive remain independent before the hard composite ceiling",
)
record(
    "same_surface_edge_fill_retained",
    "if (safeStrength <= 0.000001)" in edge_fill
    and edge_fill.count("CAMERA_OBSCURA_TL09AccumulateEdgeFillTap") == 4
    and "positiveDeficit" in edge_fill
    and "ReShade::BackBuffer" not in edge_fill,
    "zero bypass and four-tap positive indirect deficit fill retained",
)

composite_header = read(
    OVERDRIVE_SHADER_ROOT
    / "camera_obscura"
    / "api"
    / "CAMERA_OBSCURA_API_TwinLanternComposite.fxh"
)
builder = function_body(composite_header, "CAMERA_OBSCURA_API_BuildTL09Composite")
record(
    "source_and_channel_bounds_retained",
    "finalRgb = safeSource + boundedContribution" in builder
    and "channelCeiling = min(safeMaximum.xxx, remainingRoom)" in builder
    and "boundedContribution = min(boundedIndirect, channelCeiling)" in builder,
    "final contribution remains additive, nonnegative, and channel-room bounded",
)

record(
    "denoiser_remains_external",
    not list(OVERDRIVE_SHADER_ROOT.rglob("*Denoise*"))
    and not any(
        token in overdrive_source
        for token in (
            "HistoryTex",
            "Denoise_PS",
            "TemporalMotion",
            "DetailTarget",
        )
    ),
    "no temporal history or denoiser return path in Twin Lanterns",
)

passes = re.findall(r"\bpass\s+(TwinLantern\w+)", overdrive_source)
record(
    "ordered_four_pass_graph",
    passes
    == [
        "TwinLanternTransport",
        "TwinLanternResolveHorizontal",
        "TwinLanternResolveVertical",
        "TwinLanternComposite",
    ],
    f"pass order={passes}",
)

shared_relatives = [
    Path("camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh"),
    Path("camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh"),
    Path("camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternReconstruction.fxh"),
    Path("camera_obscura/api/CAMERA_OBSCURA_API_TwinLanternTransport.fxh"),
    Path("camera_obscura/header/CAMERA_OBSCURA_AtomicCommon.fxh"),
    Path("camera_obscura/header/CAMERA_OBSCURA_AtomicDebug.fxh"),
    Path("camera_obscura/header/CAMERA_OBSCURA_EntryCapability.fxh"),
    Path("camera_obscura/header/CAMERA_OBSCURA_EntryTraversal.fxh"),
]
shared_equal = all(
    read(STABLE_SHADER_ROOT / relative)
    == read(OVERDRIVE_SHADER_ROOT / relative)
    for relative in shared_relatives
)
record(
    "shared_api_lineage_unchanged",
    shared_equal,
    f"source-identical shared API/header files={len(shared_relatives) if shared_equal else 0}/{len(shared_relatives)}",
)

result = {
    "scope": "Lunar Flower Twin Lanterns public staging",
    "truth_state": (
        "reproducible structural publication validation; full ReShade compile, "
        "runtime performance, and Fidelity Overdrive live visual acceptance pending"
    ),
    "passed": sum(check["passed"] for check in checks),
    "failed": sum(not check["passed"] for check in checks),
    "checks": checks,
}
RESULT_PATH.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

for check in checks:
    print(f"{'PASS' if check['passed'] else 'FAIL'}|{check['name']}|{check['detail']}")
print(f"SUMMARY|passed={result['passed']}|failed={result['failed']}")
sys.exit(1 if result["failed"] else 0)
