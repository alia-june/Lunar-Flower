#!/usr/bin/env python3
"""Install one Alpha effect; preserve replaced files outside shader discovery."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
import shutil
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/reshade-shaders/Shaders/camera_obscura"
if not SOURCE.is_dir():
    SOURCE = ROOT / "reshade-shaders/Shaders/camera_obscura"
ALPHA = "LUNAR_FLOWER_TwinLanterns_FullResolutionDualRayAlpha.fx"
OBSOLETE = "LUNAR_FLOWER_TwinLanterns_FullResolutionDualRay.fx"


def repair(game: Path, *, apply: bool = False) -> list[str]:
    game = game.resolve(strict=True)
    shaders = game / "reshade-shaders" / "Shaders"
    if not shaders.is_dir():
        raise ValueError(f"Expected existing ReShade shader directory: {shaders}")
    if SOURCE.resolve().is_relative_to(shaders.resolve()):
        raise ValueError("Extract this download outside the shader search tree before running repair")
    if any(p.is_symlink() and p.is_dir() for p in shaders.rglob("*")):
        raise ValueError("Refusing linked shader directories; duplicate discovery would be incomplete")
    destination = shaders / "camera_obscura"
    payload = sorted(p for p in SOURCE.rglob("*") if p.suffix.lower() in {".fx", ".fxh"})
    if not payload or [p.name for p in payload if p.suffix == ".fx"] != [ALPHA]:
        raise ValueError("Source must contain exactly one Alpha effect and its includes")
    desired = {destination / p.relative_to(SOURCE): p for p in payload}
    # Limit removal to the two exact full-resolution effect names. Shared headers,
    # unrelated effects, presets, ReShade.fxh and ReShade.ini are never removed.
    candidates = {
        p for p in shaders.rglob("*")
        if p.is_file() and p.name.casefold() in {ALPHA.casefold(), OBSOLETE.casefold()}
    }
    replace = {p for p in desired if p.exists() and p.read_bytes() != desired[p].read_bytes()}
    remove = {p for p in candidates if p not in desired}
    write = {p for p, source in desired.items() if not p.exists() or p in replace}
    # Check every affected parent before touching files; reject links that could
    # turn a local installation into writes outside the specified game folder.
    for path in sorted(candidates | set(desired)):
        path.resolve().relative_to(game)
        current = path
        while current != game:
            if current.is_symlink():
                raise ValueError(f"Refusing symlink in installation path: {current}")
            current = current.parent
    backup_root = game / "Lunar-Flower-backups"
    if backup_root.is_symlink():
        raise ValueError(f"Refusing symlink backup directory: {backup_root}")
    actions = [f"BACK UP AND REMOVE {p.relative_to(game)}" for p in sorted(remove)]
    actions += [f"BACK UP AND REPLACE {p.relative_to(game)}" for p in sorted(replace)]
    actions += [f"INSTALL {p.relative_to(game)}" for p in sorted(write - replace)]
    if not apply or not actions:
        return actions
    backup_root.mkdir(exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = Path(tempfile.mkdtemp(prefix=stamp + "-", dir=backup_root))
    # Preserve all originals before making the first change. Backups are outside
    # reshade-shaders so recursive discovery will not load them again.
    for path in sorted(remove | replace):
        target = backup / path.relative_to(game)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    try:
        for path in sorted(write):
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(desired[path], path)
        for path in sorted(remove):
            path.unlink()
    except Exception:
        for path in write - replace:
            path.unlink(missing_ok=True)
        for path in remove | replace:
            shutil.copy2(backup / path.relative_to(game), path)
        raise
    installed = [p for p in shaders.rglob("*") if p.is_file() and p.name.casefold() == ALPHA.casefold()]
    if installed != [destination / "effects" / ALPHA]:
        raise RuntimeError("Expected exactly one installed Alpha effect; inspect installation")
    return actions + [f"BACKUP {backup}"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-dir", required=True, type=Path, help="Folder containing reshade-shaders")
    parser.add_argument("--apply", action="store_true", help="Apply the repair; otherwise only preview")
    args = parser.parse_args()
    actions = repair(args.game_dir, apply=args.apply)
    print("APPLY" if args.apply else "PREVIEW (use --apply to repair)")
    print("\n".join(actions) if actions else "Already installed: one current Alpha copy; no changes needed.")
    if args.apply:
        print("Reload ReShade and enable 'Lunar Flower - Twin Lanterns: Full Resolution Dual Ray Alpha'.")
        print("Remove the obsolete non-Alpha technique from the preset through ReShade's UI.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
