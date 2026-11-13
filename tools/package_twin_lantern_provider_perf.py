#!/usr/bin/env python3
"""Package controlled direction/provider sampling comparisons based on Bounce Lab."""
from __future__ import annotations

import argparse
import csv
from decimal import Decimal
import io
import json
from pathlib import Path
import re
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

from audit_twin_lantern_loop_sampling import audit, sources
from package_crystal_spider_bundle import defaults, digest, validate_includes

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'Twin-Lanterns/Provider-Performance'
SHADERS = BUILD / 'reshade-shaders/Shaders/lunar_flower_provider_perf'
EFFECT = 'reshade-shaders/Shaders/lunar_flower_provider_perf/effects/LUNAR_FLOWER_TwinLanterns_ProviderPerf.fx'
PREFIX = 'LUNAR_FLOWER_TwinLanternsProviderPerf'
TECHNIQUE = PREFIX + '@LUNAR_FLOWER_TwinLanterns_ProviderPerf.fx'
# label, DDA samples, march samples, compiled provider, direction set, bounce strength, cached composite
PROFILES = (
    ('Cardinal4-EqualTraversal', 16, 16, 0, 0, '.5', 1),
    ('Diagonal4-EqualTraversal', 16, 16, 0, 1, '.5', 1),
    ('Mixed8-EqualTraversal', 8, 8, 0, 2, '.5', 1),
    ('Mixed8-FullDensity', 16, 16, 0, 2, '.5', 1),
    ('DDA16-Only', 16, 16, 1, 0, '.5', 1),
    ('March16-Only', 16, 16, 2, 0, '.5', 1),
    ('Parent32-16', 32, 16, 0, 0, '.5', 1),
    ('FirstPassOnly', 16, 16, 0, 0, '0', 1),
    ('Runtime32-16', 32, 16, -1, 0, '.5', 1),
    ('RecomputedComposite', 16, 16, 0, 0, '.5', 0),
    ('Mixed8-FullDensity-Recomputed', 16, 16, 0, 2, '.5', 0),
    ('Parent32-16-Recomputed', 32, 16, 0, 0, '.5', 0),
)


def validate_source() -> dict[str, bytes]:
    payload = {p.relative_to(BUILD).as_posix(): p.read_bytes()
               for p in (BUILD / 'reshade-shaders').rglob('*') if p.is_file()}
    if sorted(n for n in payload if n.endswith('.fx')) != [EFFECT]:
        raise ValueError('Performance probe requires one isolated effect')
    validate_includes(payload)
    effect = payload[EFFECT].decode()
    passes = re.findall(r'^\s*pass\s+(\w+)', effect, re.M)
    if passes != ['TwinLanternTransport', 'TwinLanternResolveHorizontal', 'TwinLanternResolveVertical',
                  'TwinLanternCaptureFirstLight', 'TwinLanternSecondBounce', 'TwinLanternComposite']:
        raise ValueError('Unexpected performance-probe pass order')
    failures = audit(sources(SHADERS), entrypoints=(
        'LUNAR_FLOWER_TLPPRaw_PS', 'LUNAR_FLOWER_TLPPEvaluateDirections',
        'LUNAR_FLOWER_TLPPTraceScreenDetailed', 'LUNAR_FLOWER_TLPPBounce_PS',
        'LUNAR_FLOWER_TLPPDisplay_PS'))
    if failures:
        raise ValueError('Unsafe loop sampling:\n' + '\n'.join(failures))
    selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
    actual = defaults(payload[EFFECT])
    if len(actual) != 30 or selected.keys() != actual.keys() or any(
            Decimal(selected[k]) != Decimal(actual[k]) for k in actual):
        raise ValueError('Source-level defaults record is stale')
    for item in json.loads((BUILD / 'SOURCE_LINEAGE.json').read_text())['files']:
        if digest((ROOT / item['destination']).read_bytes()) != item['destination_sha256']:
            raise ValueError(f'Stale lineage: {item["destination"]}')
    return payload


def presets() -> dict[str, bytes]:
    selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
    result = {}
    for label, dda, march, provider, direction, bounce, cache in PROFILES:
        values = dict(selected)
        values[PREFIX + 'DirectionSet'] = str(direction)
        values[PREFIX + 'BounceStrength'] = bounce
        if provider >= 0:
            values.pop(PREFIX + 'ProviderMode')
        else:
            values[PREFIX + 'ProviderMode'] = '0'
        definitions = f'LUNAR_FLOWER_TLPP_DDA_STEPS={dda},LUNAR_FLOWER_TLPP_MARCH_STEPS={march},LUNAR_FLOWER_TLPP_COMPILED_PROVIDER={provider},LUNAR_FLOWER_TLPP_CACHE_FIRST_LIGHT={cache}'
        text = f'Techniques={TECHNIQUE}\nTechniqueSorting={TECHNIQUE}\nPreprocessorDefinitions={definitions}\n\n[{Path(EFFECT).name}]\n'
        text += ''.join(f'{k}={v}\n' for k, v in sorted(values.items()))
        result[f'Twin-Lanterns-ProviderPerf-{label}.ini'] = text.encode()
    return result


def matrix() -> str:
    stream = io.StringIO(newline='')
    writer = csv.writer(stream, lineterminator='\n')
    writer.writerow(['preset', 'directions', 'dda_per_direction', 'march_per_direction',
                     'compiled_provider', 'gathers', 'maximum_traversal_samples_per_pixel', 'cached_final_composite',
                     'measured_effect_gpu_ms', 'measured_total_frame_ms', 'measured_fps', 'notes'])
    for label, dda, march, provider, direction, bounce, cache in PROFILES:
        directions = 8 if direction == 2 else 4
        per_direction = (dda if provider != 2 else 0) + (march if provider != 1 else 0)
        gathers = 1 if Decimal(bounce) == 0 else 2
        writer.writerow([label, directions, dda, march, provider, gathers,
                         directions * per_direction * gathers, int(cache and gathers == 2), '', '', '', 'not measured'])
    return stream.getvalue()


def package(output: Path) -> dict:
    payload = validate_source()
    payload.update(presets())
    payload['PERFORMANCE_MATRIX.csv'] = matrix().encode()
    for name in ('README.md', 'DEFAULTS.json', 'SOURCE_LINEAGE.json', 'INVESTIGATION.md'):
        payload[name] = (BUILD / name).read_bytes()
    payload['LICENSE'] = (ROOT / 'LICENSE').read_bytes()
    manifest = {
        'schema': 'twin-lanterns-provider-performance-v2', 'effect_files': [EFFECT],
        'technique': TECHNIQUE, 'compile_time_provider_selection': True,
        'independent_traversal_budgets': True, 'ray_reach_preserved': True,
        'pass_count': 6, 'working_texture_2d_count': 5,
        'cached_first_light_final_composite': True,
        'recomputed_composite_comparison_preset': True,
        'gpu_timing_measured': False, 'native_compile_performed': False,
        'dx11_excluded': False, 'dx12_excluded': False,
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
