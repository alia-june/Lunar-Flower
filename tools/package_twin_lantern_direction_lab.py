#!/usr/bin/env python3
"""Validate and reproducibly package the isolated Twin Lanterns direction experiment."""
from __future__ import annotations

import argparse
from decimal import Decimal
import json
from pathlib import Path
import re
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

from audit_twin_lantern_loop_sampling import audit, sources
from package_crystal_spider_bundle import defaults, digest, validate_includes

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'Twin-Lanterns/Direction-Lab'
SHADERS = BUILD / 'reshade-shaders/Shaders/lunar_flower_direction_lab'
EFFECT = 'reshade-shaders/Shaders/lunar_flower_direction_lab/effects/LUNAR_FLOWER_TwinLanterns_DirectionLab.fx'
PREFIX = 'LUNAR_FLOWER_TwinLanternsDirectionLab'
TECHNIQUE = PREFIX + '@LUNAR_FLOWER_TwinLanterns_DirectionLab.fx'


def validate_source() -> dict[str, bytes]:
    payload = {p.relative_to(BUILD).as_posix(): p.read_bytes()
               for p in (BUILD / 'reshade-shaders').rglob('*') if p.is_file()}
    if sorted(n for n in payload if n.endswith('.fx')) != [EFFECT]:
        raise ValueError('Direction Lab requires its one isolated effect')
    validate_includes(payload)
    effect = payload[EFFECT].decode()
    if re.findall(r'\bpass\s+(\w+)', effect) != [
            'TwinLanternTransport', 'TwinLanternResolveHorizontal',
            'TwinLanternResolveVertical', 'TwinLanternComposite']:
        raise ValueError('Unexpected Direction Lab pass graph')
    text = '\n'.join(b.decode() for b in payload.values())
    if re.search(r'\b(?:texture3D|sampler3D|storage\w*|tex3D\w*|ComputeShader|DispatchSize\w*|\w*(?:VoxelProxy|VoxelLightingStrength|VoxelTraceSteps|AdaptiveAtlas)\w*)\b', text):
        raise ValueError('Direction Lab contains a voxel/compute dependency')
    if len(re.findall(r'^texture2D\s', effect, re.M)) != 3:
        raise ValueError('Unexpected working texture count')
    if len(re.search(r'ui_items = "([^"]+)"', effect)[1].split('\\0')) - 1 != 26:
        raise ValueError('Unexpected diagnostic view mapping')
    failures = audit(sources(SHADERS), entrypoints=(
        'LUNAR_FLOWER_TLDLRaw_PS', 'LUNAR_FLOWER_TLDLEvaluateDirections',
        'LUNAR_FLOWER_TLDLTraceScreenDetailed'))
    if failures:
        raise ValueError('Unsafe loop sampling:\n' + '\n'.join(failures))
    selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
    actual = defaults(payload[EFFECT])
    if len(actual) != 23 or selected.keys() != actual.keys() or any(
            Decimal(selected[k]) != Decimal(actual[k]) for k in actual):
        raise ValueError('Direction Lab defaults disagree with the effect')
    for item in json.loads((BUILD / 'SOURCE_LINEAGE.json').read_text())['files']:
        if digest((ROOT / item['destination']).read_bytes()) != item['destination_sha256']:
            raise ValueError(f'Stale lineage for {item["destination"]}')
    return payload


def presets() -> dict[str, bytes]:
    selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
    result = {}
    for mode, label in enumerate(('Cardinal', 'Diagonal', 'Mixed')):
        values = dict(selected)
        values[PREFIX + 'DirectionSet'] = str(mode)
        text = f'Techniques={TECHNIQUE}\nTechniqueSorting={TECHNIQUE}\n\n[{Path(EFFECT).name}]\n'
        text += ''.join(f'{k}={v}\n' for k, v in sorted(values.items()))
        result[f'Twin-Lanterns-DirectionLab-{label}.ini'] = text.encode()
    return result


def package(output: Path) -> dict:
    payload = validate_source()
    payload.update(presets())
    for name in ('README.md', 'DEFAULTS.json', 'SOURCE_LINEAGE.json'):
        payload[name] = (BUILD / name).read_bytes()
    payload['LICENSE'] = (ROOT / 'LICENSE').read_bytes()
    manifest = {
        'schema': 'twin-lanterns-direction-lab-v1',
        'effect_files': [EFFECT],
        'technique': TECHNIQUE,
        'direction_counts': {'cardinal': 4, 'diagonal': 4, 'mixed': 8},
        'provider_maximum_samples_per_direction': {'dda': 32, 'march': 16},
        'fixed_dda_budget': True,
        'direction_independent_depth_travel': True,
        'pass_count': 4, 'working_texture_2d_count': 3,
        'voxel_resources': False, 'temporal_history': False,
        'native_compile_performed': False, 'visual_test_performed': False,
        'files': {n: digest(b) for n, b in sorted(payload.items())},
    }
    payload['PACKAGE_MANIFEST.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('xb') as stream, ZipFile(stream, 'w', compression=ZIP_DEFLATED) as archive:
        for name, data in sorted(payload.items()):
            entry = ZipInfo(name, date_time=(2000, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_DEFLATED
            archive.writestr(entry, data)
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    output = parser.parse_args().output
    package(output)
    print(json.dumps({'output': str(output), 'sha256': digest(output.read_bytes())}, indent=2))
