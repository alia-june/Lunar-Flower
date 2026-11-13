#!/usr/bin/env python3
"""Package the isolated current-frame bounce and broken-sampler experiment."""
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
BUILD = ROOT / 'Twin-Lanterns/Bounce-Lab'
SHADERS = BUILD / 'reshade-shaders/Shaders/lunar_flower_bounce_lab'
EFFECT = 'reshade-shaders/Shaders/lunar_flower_bounce_lab/effects/LUNAR_FLOWER_TwinLanterns_BounceLab.fx'
PREFIX = 'LUNAR_FLOWER_TwinLanternsBounceLab'
TECHNIQUE = PREFIX + '@LUNAR_FLOWER_TwinLanterns_BounceLab.fx'


def validate_source() -> dict[str, bytes]:
    payload = {p.relative_to(BUILD).as_posix(): p.read_bytes()
               for p in (BUILD / 'reshade-shaders').rglob('*') if p.is_file()}
    if sorted(n for n in payload if n.endswith('.fx')) != [EFFECT]:
        raise ValueError('Bounce Lab requires one isolated effect')
    validate_includes(payload)
    effect = payload[EFFECT].decode()
    if re.findall(r'^\s*pass\s+(\w+)', effect, re.M) != [
            'TwinLanternTransport', 'TwinLanternResolveHorizontal',
            'TwinLanternResolveVertical', 'TwinLanternCaptureFirstLight',
            'TwinLanternSecondBounce', 'TwinLanternComposite']:
        raise ValueError('Unexpected Bounce Lab pass order')
    text = '\n'.join(b.decode() for b in payload.values())
    if re.search(r'\b(?:texture3D|sampler3D|storage\w*|tex3D\w*|ComputeShader|DispatchSize\w*|framecount|frametime)\b', text, re.I):
        raise ValueError('Unexpected voxel/compute/time dependency')
    if len(re.findall(r'^texture2D\s', effect, re.M)) != 5:
        raise ValueError('Unexpected current-frame field count')
    if len(re.search(r'ui_items = "([^"]+)"', effect)[1].split('\\0')) - 1 != 31:
        raise ValueError('Unexpected diagnostic mapping')
    failures = audit(sources(SHADERS), entrypoints=(
        'LUNAR_FLOWER_TLBLRaw_PS', 'LUNAR_FLOWER_TLBLEvaluateDirections',
        'LUNAR_FLOWER_TLBLTraceScreenDetailed', 'LUNAR_FLOWER_TLBLBounce_PS'))
    if failures:
        raise ValueError('Unsafe loop sampling:\n' + '\n'.join(failures))
    selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
    actual = defaults(payload[EFFECT])
    if len(actual) != 30 or selected.keys() != actual.keys() or any(
            Decimal(selected[k]) != Decimal(actual[k]) for k in actual):
        raise ValueError('Bounce Lab defaults disagree with source')
    for item in json.loads((BUILD / 'SOURCE_LINEAGE.json').read_text())['files']:
        if digest((ROOT / item['destination']).read_bytes()) != item['destination_sha256']:
            raise ValueError(f'Stale lineage: {item["destination"]}')
    return payload


def presets() -> dict[str, bytes]:
    selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
    profiles = {
        'Reference': {'BounceStrength': '0'},
        'Bounce': {},
        'BrokenSampler': {'ChaosAmount': '0.350', 'ChaosMode': '2'},
    }
    result = {}
    for label, overrides in profiles.items():
        values = dict(selected)
        values.update({PREFIX + k: v for k, v in overrides.items()})
        text = f'Techniques={TECHNIQUE}\nTechniqueSorting={TECHNIQUE}\n\n[{Path(EFFECT).name}]\n'
        text += ''.join(f'{k}={v}\n' for k, v in sorted(values.items()))
        result[f'Twin-Lanterns-BounceLab-{label}.ini'] = text.encode()
    return result


def package(output: Path) -> dict:
    payload = validate_source()
    payload.update(presets())
    for name in ('README.md', 'DEFAULTS.json', 'SOURCE_LINEAGE.json', 'OWNER_FEEDBACK.md'):
        payload[name] = (BUILD / name).read_bytes()
    payload['LICENSE'] = (ROOT / 'LICENSE').read_bytes()
    manifest = {
        'schema': 'twin-lanterns-bounce-lab-v1', 'effect_files': [EFFECT],
        'technique': TECHNIQUE, 'pass_count': 6, 'working_texture_2d_count': 5,
        'bounce_input': 'bounded and faded first-pass added-light field',
        'extra_bounce_count': 1, 'final_image_feedback': False,
        'dropout_renormalization': False, 'frame_randomization': False,
        'temporal_history': False, 'world_visibility_available': False,
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
    path = parser.parse_args().output
    package(path)
    print(json.dumps({'output': str(path), 'sha256': digest(path.read_bytes())}, indent=2))
