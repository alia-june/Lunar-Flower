#!/usr/bin/env python3
"""Validate the full-stack showcase and the published Twin Lanterns API."""

from __future__ import annotations

import hashlib
import json
import re
import struct
import sys
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TWIN = ROOT / "Twin-Lanterns"
ASSETS = TWIN / "assets"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def sha256_public_text(path: Path) -> str:
    """Hash the LF-normalized bytes stored in public Git text blobs."""

    return sha256_bytes(path.read_bytes().replace(b"\r\n", b"\n"))


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def decode_png_bgra(path: Path) -> tuple[int, int, bytes]:
    """Decode the bounded 8-bit, non-interlaced RGB/RGBA PNG surface used here."""

    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")

    offset = 8
    width = height = bit_depth = color_type = interlace = None
    compressed = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
        elif chunk_type == b"IDAT":
            compressed.extend(payload)
        elif chunk_type == b"IEND":
            break

    if None in (width, height, bit_depth, color_type, interlace):
        raise ValueError(f"missing IHDR: {path}")
    if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
        raise ValueError(
            f"unsupported PNG surface in {path}: "
            f"depth={bit_depth}, color={color_type}, interlace={interlace}"
        )

    channels = 3 if color_type == 2 else 4
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    expected = height * (stride + 1)
    if len(raw) != expected:
        raise ValueError(f"unexpected decoded size in {path}: {len(raw)} != {expected}")

    rows: list[bytearray] = []
    cursor = 0
    prior = bytearray(stride)
    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        encoded = raw[cursor : cursor + stride]
        cursor += stride
        row = bytearray(stride)
        for index, value in enumerate(encoded):
            left = row[index - channels] if index >= channels else 0
            above = prior[index]
            upper_left = prior[index - channels] if index >= channels else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                predictor = paeth(left, above, upper_left)
            else:
                raise ValueError(f"unsupported PNG filter {filter_type} in {path}")
            row[index] = (value + predictor) & 0xFF
        rows.append(row)
        prior = row

    bgra = bytearray(width * height * 4)
    target = 0
    for row in rows:
        for pixel in range(width):
            source = pixel * channels
            red = row[source]
            green = row[source + 1]
            blue = row[source + 2]
            alpha = row[source + 3] if channels == 4 else 255
            bgra[target : target + 4] = bytes((blue, green, red, alpha))
            target += 4
    return width, height, bytes(bgra)


def region_hash(pixels: bytes, width: int, height: int, x0: int, x1: int) -> str:
    row_width = width * 4
    start = x0 * 4
    end = x1 * 4
    region = bytearray((x1 - x0) * height * 4)
    target = 0
    for y in range(height):
        row = pixels[y * row_width + start : y * row_width + end]
        region[target : target + len(row)] = row
        target += len(row)
    return sha256_bytes(bytes(region))


def local_include_closure(entry: Path, boundary: Path) -> set[Path]:
    include_pattern = re.compile(r'^\s*#include\s+"([^"]+)"', re.MULTILINE)
    boundary = boundary.resolve()
    pending = [entry.resolve()]
    visited: set[Path] = set()
    while pending:
        current = pending.pop()
        if current in visited:
            continue
        if not current.is_file():
            raise ValueError(f"missing include: {current}")
        if boundary not in current.parents and current != boundary:
            raise ValueError(f"include escaped boundary: {current}")
        visited.add(current)
        for include in include_pattern.findall(current.read_text(encoding="utf-8")):
            candidate = (current.parent / include).resolve()
            pending.append(candidate)
    return visited


def main() -> int:
    checks: list[tuple[str, bool, str]] = []

    def record(name: str, passed: bool, detail: str) -> None:
        checks.append((name, passed, detail))

    manifest_path = ASSETS / "twin-lanterns-full-lazara-comparison.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    source_files = [ASSETS / item["repository_file"] for item in manifest["sources"]]
    comparison_path = ASSETS / manifest["comparison"]["output_file"]
    required_showcase = source_files + [comparison_path, manifest_path]
    record(
        "showcase_surface_complete",
        all(path.is_file() for path in required_showcase),
        f"required files present={sum(path.is_file() for path in required_showcase)}/{len(required_showcase)}",
    )

    exact_sources = all(
        sha256_file(ASSETS / item["repository_file"]) == item["source_sha256"]
        == item["repository_sha256"]
        and item["exact_copy"] is True
        for item in manifest["sources"]
    )
    record("source_images_exact", exact_sources, "byte-identical source copies=3/3")

    decoded: dict[str, tuple[int, int, bytes]] = {}
    for path in source_files + [comparison_path]:
        decoded[path.name] = decode_png_bgra(path)
    dimensions_match = all(
        width == manifest["width"] and height == manifest["height"]
        for width, height, _ in decoded.values()
    )
    record("showcase_dimensions", dimensions_match, "all images=2560x1440")

    output_hash_match = (
        sha256_file(comparison_path) == manifest["comparison"]["output_sha256"]
    )
    record("comparison_file_hash", output_hash_match, manifest["comparison"]["output_sha256"])

    output_width, output_height, output_pixels = decoded[comparison_path.name]
    region_results: list[bool] = []
    for region in manifest["comparison"]["regions"]:
        source_width, source_height, source_pixels = decoded[region["source_file"]]
        x0 = region["x_start"]
        x1 = region["x_end_exclusive"]
        source_hash = region_hash(source_pixels, source_width, source_height, x0, x1)
        output_hash = region_hash(output_pixels, output_width, output_height, x0, x1)
        region_results.append(
            source_hash == output_hash
            == region["decoded_source_region_sha256"]
            == region["decoded_output_region_sha256"]
            and region["exact_match"] is True
        )
    record(
        "decoded_regions_exact",
        all(region_results) and manifest["comparison"]["all_regions_exact"] is True,
        f"source/output regions exact={sum(region_results)}/{len(region_results)}",
    )

    api_root = TWIN / "API" / "0.1.0"
    registry_path = api_root / "PUBLIC_API.json"
    api_doc_path = api_root / "README.md"
    version_path = api_root / "VERSION"
    sums_path = api_root / "SHA256SUMS.txt"
    api_index_path = TWIN / "API" / "README.md"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    record(
        "public_api_surface_complete",
        all(
            path.is_file()
            for path in (
                registry_path,
                api_doc_path,
                version_path,
                sums_path,
                api_index_path,
            )
        ),
        "version index, 0.1.0 guide, registry, marker, and hash inventory present",
    )

    stable_root = TWIN / "Stable-1.4" / "reshade-shaders" / "shaders" / "camera_obscura"
    fidelity_root = TWIN / "Fidelity-Overdrive" / "reshade-shaders" / "Shaders" / "camera_obscura"
    alpha_root = TWIN / "Full-Resolution-Dual-Ray-Alpha" / "reshade-shaders" / "Shaders" / "camera_obscura"
    common = (stable_root / "header" / "CAMERA_OBSCURA_AtomicCommon.fxh").read_text(
        encoding="utf-8"
    )
    version = ".".join(
        re.search(rf"CAMERA_OBSCURA_API_VERSION_{part}\s+(\d+)", common).group(1)
        for part in ("MAJOR", "MINOR", "PATCH")
    )
    record(
        "api_version_matches_source",
        version
        == registry["api_version"]
        == version_path.read_text(encoding="utf-8").strip()
        == "0.1.0",
        f"source, registry, and marker version={version}",
    )

    package_shader_root = api_root / "reshade-shaders" / "Shaders" / "camera_obscura"
    shared_entries = registry["shared_files"]
    shared_paths = [api_root / item["path"] for item in shared_entries]
    sums = {}
    for line in sums_path.read_text(encoding="utf-8").splitlines():
        digest_value, relative = line.split("  ", 1)
        sums[relative] = digest_value
    hash_results = [
        path.is_file()
        and sha256_public_text(path) == item["sha256"]
        and sums.get(item["path"]) == item["sha256"]
        for path, item in zip(shared_paths, shared_entries)
    ]
    record(
        "versioned_api_hash_inventory",
        all(hash_results) and len(sums) == 9,
        f"shared package hashes verified={sum(hash_results)}/{len(hash_results)}; inventory entries={len(sums)}",
    )

    entry = api_root / registry["entry_include"]
    closure = local_include_closure(entry, package_shader_root)
    record(
        "public_include_closure",
        len(closure) == len(shared_entries) == 8,
        f"closed local include surface={len(closure)} files",
    )

    identical_count = 0
    prefix = "reshade-shaders/Shaders/camera_obscura/"
    for package_path, item in zip(shared_paths, shared_entries):
        relative = Path(item["path"].removeprefix(prefix))
        stable_source = (stable_root / relative).read_text(encoding="utf-8")
        if (
            package_path.read_text(encoding="utf-8") == stable_source
            and (fidelity_root / relative).read_text(encoding="utf-8") == stable_source
            and (alpha_root / relative).read_text(encoding="utf-8") == stable_source
        ):
            identical_count += 1
    record(
        "versioned_api_source_lineage",
        identical_count == len(shared_entries),
        f"package/Stable/Fidelity/Alpha source identity={identical_count}/{len(shared_entries)}",
    )

    canonical_text = "\n".join(path.read_text(encoding="utf-8") for path in closure)
    published_symbols = [
        contract[key]
        for contract in registry["public_contracts"]
        for key in ("type", "default_constructor", "entrypoint")
    ]
    symbol_results = [
        re.search(rf"\b{re.escape(symbol)}\b", canonical_text) is not None
        for symbol in published_symbols
    ]
    record(
        "published_contract_symbols",
        all(symbol_results),
        f"registered symbols present={sum(symbol_results)}/{len(symbol_results)}",
    )

    extension = registry["experimental_extensions"][0]
    extension_path = api_root / extension["path"]
    extension_text = extension_path.read_text(encoding="utf-8")
    extension_symbols = [extension["type"], *extension["entrypoints"]]
    extension_present = all(
        re.search(rf"\b{re.escape(symbol)}\b", extension_text) is not None
        for symbol in extension_symbols
    )
    boundary_text = (extension["status"] + "\n" + api_doc_path.read_text(encoding="utf-8")).lower()
    experimental_bounded = (
        extension_present
        and "experimental" in boundary_text
        and "excluded" in boundary_text
        and (
            "not claim world voxelization" in boundary_text
            or "not world voxelization" in boundary_text
        )
    )
    record(
        "experimental_voxel_api_bounded",
        experimental_bounded,
        f"experimental symbols present={sum(symbol in extension_text for symbol in extension_symbols)}/{len(extension_symbols)}",
    )

    alpha_extension = (
        alpha_root / "api" / "LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh"
    )
    extension_identity = (
        sha256_public_text(extension_path) == extension["sha256"]
        == sums.get(extension["path"])
        == sha256_public_text(alpha_extension)
    )
    record(
        "experimental_voxel_source_identity",
        extension_identity,
        f"packaged Alpha extension sha256={extension['sha256']}",
    )

    root_readme = (ROOT / "README.md").read_text(encoding="utf-8")
    twin_readme = (TWIN / "README.md").read_text(encoding="utf-8")
    variant_readmes = "\n".join(
        (TWIN / build / "README.md").read_text(encoding="utf-8")
        for build in (
            "Stable-1.4",
            "Fidelity-Overdrive",
            "Full-Resolution-Dual-Ray-Alpha",
        )
    )
    docs_linked = all(
        token in root_readme + twin_readme + variant_readmes
        for token in (
            "twin-lanterns-full-lazara-comparison.png",
            "twin-lanterns-full-lazara-comparison.json",
            "API/0.1.0/",
            "API/0.1.0/PUBLIC_API.json",
        )
    ) and "0.1.0" in api_index_path.read_text(encoding="utf-8")
    record(
        "readme_publication_links",
        docs_linked,
        "showcase and versioned API linked from public and variant READMEs",
    )

    failures = 0
    for name, passed, detail in checks:
        status = "PASS" if passed else "FAIL"
        print(f"{status}|{name}|{detail}")
        failures += 0 if passed else 1
    print(f"SUMMARY|passed={len(checks) - failures}|failed={failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
