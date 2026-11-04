#!/usr/bin/env python3
"""Build the complete declaration index for Twin Lanterns API 0.1.0."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_API_ROOT = ROOT / "Twin-Lanterns" / "API" / "0.1.0"


def relative_sources(api_root: Path) -> list[Path]:
    return sorted(
        [*api_root.glob("reshade-shaders/**/*.fxh"), *api_root.glob("experimental/*.fxh")],
        key=lambda path: path.relative_to(api_root).as_posix(),
    )


def extract_macros(source: str) -> list[dict[str, object]]:
    macros: list[dict[str, object]] = []
    for line in source.splitlines():
        match = re.match(r"^#define\s+([A-Z][A-Z0-9_]+)(?:\s+(.*))?$", line)
        if not match:
            continue
        name = match.group(1)
        macros.append(
            {
                "name": name,
                "value": (match.group(2) or "").strip(),
                "include_guard": name.endswith("_FXH"),
            }
        )
    return macros


def extract_structs(source: str) -> list[dict[str, object]]:
    structs: list[dict[str, object]] = []
    for match in re.finditer(r"^struct\s+(\w+)\s*\{(.*?)^\};", source, re.MULTILINE | re.DOTALL):
        fields = [
            {"type": field.group(1), "name": field.group(2)}
            for field in re.finditer(
                r"^\s*([A-Za-z_]\w*(?:\d(?:x\d)?)?)\s+(\w+)\s*;",
                match.group(2),
                re.MULTILINE,
            )
        ]
        structs.append({"name": match.group(1), "fields": fields})
    return structs


def extract_functions(source: str) -> list[dict[str, str]]:
    pattern = re.compile(
        r"^(?:\[[^\]]+\]\s*)?([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*\((.*?)\)\s*\{",
        re.MULTILINE | re.DOTALL,
    )
    return [
        {
            "return_type": match.group(1),
            "name": match.group(2),
            "parameters": " ".join(match.group(3).split()),
        }
        for match in pattern.finditer(source)
    ]


def extract_resources(source: str) -> list[dict[str, str]]:
    return [
        {"kind": match.group(1), "name": match.group(2)}
        for match in re.finditer(
            r"^(texture3D|storage3D|sampler3D)\s+(\w+)\s*\{",
            source,
            re.MULTILINE,
        )
    ]


def build_index(api_root: Path = DEFAULT_API_ROOT) -> dict[str, object]:
    source_entries: list[dict[str, object]] = []
    for path in relative_sources(api_root):
        source = path.read_text(encoding="utf-8")
        source_entries.append(
            {
                "path": path.relative_to(api_root).as_posix(),
                "macros": extract_macros(source),
                "structs": extract_structs(source),
                "functions": extract_functions(source),
                "resources": extract_resources(source),
            }
        )

    summary = {
        "source_files": len(source_entries),
        "macros": sum(len(item["macros"]) for item in source_entries),
        "structs": sum(len(item["structs"]) for item in source_entries),
        "struct_fields": sum(
            len(struct["fields"])
            for item in source_entries
            for struct in item["structs"]
        ),
        "functions": sum(len(item["functions"]) for item in source_entries),
        "resources": sum(len(item["resources"]) for item in source_entries),
    }
    return {
        "schema": "lunar-flower-twin-lanterns-symbol-index-v1",
        "api_version": "0.1.0",
        "scope": "all top-level declarations in the eight shared files and experimental voxel extension",
        "summary": summary,
        "sources": source_entries,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-root", type=Path, default=DEFAULT_API_ROOT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    api_root = args.api_root.resolve()
    output = api_root / "SYMBOLS.json"
    generated = json.dumps(build_index(api_root), indent=2) + "\n"
    if args.check:
        current = output.read_text(encoding="utf-8") if output.is_file() else ""
        if current != generated:
            print(f"FAIL|api_symbol_index_current|regenerate {output}")
            return 1
        print(f"PASS|api_symbol_index_current|{output}")
        return 0
    output.write_text(generated, encoding="utf-8", newline="\n")
    print(f"WROTE|{output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
