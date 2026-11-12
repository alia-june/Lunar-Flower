#!/usr/bin/env python3
"""Reject implicit-gradient operations reachable from Alpha's loop entrypoints.

This is a conservative source call-graph check, not FXC or a ReShade compiler.
ReShade::GetLinearizedDepth is external; the official include uses tex2Dlod.
The installed ReShade.fxh must retain that derivative-free depth implementation.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / 'Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/reshade-shaders/Shaders/camera_obscura'
ENTRYPOINTS = (
    'LUNAR_FLOWER_TLFRRaw_PS',
    'LUNAR_FLOWER_TLFRBuildVoxelProxyCS',
    'LUNAR_FLOWER_TLFRTraceScreenWithReceiver',
    'LUNAR_FLOWER_API_TraceTwinLanternVoxelProxyWithReceiver',
)
GRADIENT_OPS = {'tex1D', 'tex2D', 'tex3D', 'tex1Dbias', 'tex2Dbias', 'tex3Dbias', 'ddx', 'ddy', 'fwidth'}
FUNCTION = re.compile(r'^\s*(?:\[[^\]]+\]\s*)?\w+\s+(\w+)\s*\([^;{}]*\)\s*(?::\s*\w+)?\s*\{', re.M)
CALL = re.compile(r'(?<![\w:])((?:[A-Za-z_]\w*::)*[A-Za-z_]\w*)\s*\(')


def sources(directory: Path = SHADERS) -> dict[str, str]:
    return {str(p): p.read_text(encoding='utf-8') for p in directory.rglob('*') if p.suffix in {'.fx', '.fxh'}}


def audit(texts: dict[str, str], entrypoints: tuple[str, ...] = ENTRYPOINTS) -> list[str]:
    functions = {}
    for filename, text in texts.items():
        text = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/', '', text)
        for match in FUNCTION.finditer(text):
            start = match.end()
            end, depth = start, 1
            while depth and end < len(text):
                depth += (text[end] == '{') - (text[end] == '}')
                end += 1
            functions[match[1]] = (filename, text[start:end - 1])
    failures = []
    for root in entrypoints:
        if root not in functions:
            failures.append(f'Missing loop entrypoint: {root}')
            continue
        visited = set()
        pending = [(root, [root])]
        while pending:
            name, path = pending.pop()
            if name in visited:
                continue
            visited.add(name)
            filename, body = functions[name]
            for call in CALL.findall(body):
                if call in GRADIENT_OPS:
                    failures.append(f'{filename}: ' + ' -> '.join(path + [call]))
                elif call in functions:
                    pending.append((call, path + [call]))
    return failures


def audit_directory(directory: Path = SHADERS) -> list[str]:
    return audit(sources(directory))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shader-root', type=Path, default=SHADERS)
    failures = audit_directory(parser.parse_args().shader_root)
    for failure in failures:
        print('FAIL|' + failure)
    if not failures:
        print('PASS|Alpha loop call graphs contain no implicit-gradient operations')
    raise SystemExit(bool(failures))
