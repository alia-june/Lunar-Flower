#!/usr/bin/env python3
"""Package only Alpha and the repair tool, with one discoverable .fx file."""

import argparse
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha"


def package(output: Path) -> None:
    payload = {
        str(p.relative_to(BUILD)).replace("\\", "/"): p
        for p in (BUILD / "reshade-shaders").rglob("*") if p.is_file()
    }
    payload.update({
        "LICENSE": ROOT / "LICENSE",
        "README.md": BUILD / "README.md",
        "tools/install_twin_lantern_alpha.py": ROOT / "tools/install_twin_lantern_alpha.py",
    })
    effects = [name for name in payload if name.endswith(".fx")]
    if effects != ["reshade-shaders/Shaders/camera_obscura/effects/LUNAR_FLOWER_TwinLanterns_FullResolutionDualRayAlpha.fx"]:
        raise ValueError("Alpha package must contain exactly its one public effect")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as stream:
        with ZipFile(stream, "w", compression=ZIP_DEFLATED) as archive:
            for name, path in sorted(payload.items()):
                archive.writestr(name, path.read_bytes())
    print(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    package(parser.parse_args().output)
