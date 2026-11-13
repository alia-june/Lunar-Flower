#!/usr/bin/env python3
"""Package the separate screen-only Twin Lanterns build with unchanged Fog Guard V2."""
from __future__ import annotations

import argparse
from decimal import Decimal
import json
from pathlib import Path
import re
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

from audit_twin_lantern_loop_sampling import audit, sources
from package_crystal_spider_bundle import (
    FOG_EFFECT, defaults, digest, load_component, shader_files,
    texture_names, validate_includes,
)

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'Twin-Lanterns/No-Voxel'
SHADERS = BUILD / 'reshade-shaders/Shaders/lunar_flower_no_voxel'
EFFECT = 'reshade-shaders/Shaders/lunar_flower_no_voxel/effects/LUNAR_FLOWER_TwinLanterns_NoVoxel.fx'
TECHNIQUES = (
    'BlackWand_FogLight_Guard@BlackWand_10_FogLight_Guard.fx',
    'LUNAR_FLOWER_TwinLanternsNoVoxel@LUNAR_FLOWER_TwinLanterns_NoVoxel.fx',
    'BlackWand_FogLight_GuardRestore@BlackWand_10_FogLight_Guard.fx',
)


def validate_source() -> dict[str, bytes]:
    payload = {p.relative_to(BUILD).as_posix(): p.read_bytes()
               for p in (BUILD / 'reshade-shaders').rglob('*') if p.is_file()}
    if sorted(n for n in payload if n.endswith('.fx')) != [EFFECT]:
        raise ValueError('No-Voxel must contain exactly its one effect')
    validate_includes(payload)
    text = '\n'.join(b.decode() for b in payload.values())
    forbidden = r'\b(?:texture3D|sampler3D|storage\w*|tex3D\w*|ComputeShader|DispatchSize\w*|\w*(?:VoxelProxy|VoxelLightingStrength|VoxelTraceSteps|AdaptiveAtlas)\w*)\b'
    if re.search(forbidden, text):
        raise ValueError('No-Voxel source still contains a voxel resource, provider or control')
    effect = payload[EFFECT].decode()
    if re.findall(r'\bpass\s+(\w+)', effect) != [
            'TwinLanternTransport', 'TwinLanternResolveHorizontal',
            'TwinLanternResolveVertical', 'TwinLanternComposite']:
        raise ValueError('Unexpected No-Voxel pass graph')
    failures = audit(sources(SHADERS), entrypoints=(
        'LUNAR_FLOWER_TLNVRaw_PS', 'LUNAR_FLOWER_TLNVTraceScreenWithReceiver'))
    if failures:
        raise ValueError('Implicit-gradient or missing loop call graph:\n' + '\n'.join(failures))
    selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
    actual = defaults(payload[EFFECT])
    if len(actual) != 22 or selected.keys() != actual.keys() or any(
            Decimal(selected[k]) != Decimal(actual[k]) for k in actual):
        raise ValueError('No-Voxel defaults record disagrees with shader controls')
    lineage = json.loads((BUILD / 'SOURCE_LINEAGE.json').read_text())
    if digest(payload[EFFECT]) != lineage['new_effect_sha256']:
        raise ValueError('No-Voxel effect disagrees with its lineage record')
    for item in lineage['shared_and_local_includes']:
        path = ROOT / item['destination']
        if digest(path.read_bytes()) != item['destination_sha256']:
            raise ValueError(f'No-Voxel include disagrees with lineage: {path.name}')
    return payload


def package(output: Path) -> dict:
    payload = validate_source()
    fog_path = ROOT / 'downloads/Lazara-Fog-Guard-V2.zip'
    fog, fog_sha = load_component(fog_path, FOG_EFFECT)
    fog_shaders = shader_files(fog)
    if texture_names(payload) & texture_names(fog_shaders):
        raise ValueError('No-Voxel/Fog Guard texture names collide')
    if payload.keys() & fog_shaders.keys():
        raise ValueError('No-Voxel/Fog Guard installation paths collide')
    payload.update(fog_shaders)
    validate_includes(payload)
    for technique in TECHNIQUES:
        name, filename = technique.split('@')
        source = next(b for n, b in payload.items() if Path(n).name == filename)
        if not re.search(r'^\s*technique\s+' + re.escape(name) + r'\b', source.decode(), re.M):
            raise ValueError(f'Missing technique: {technique}')
    selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
    fog_defaults = defaults(fog[FOG_EFFECT])
    order = ','.join(TECHNIQUES)
    preset = f'Techniques={order}\nTechniqueSorting={order}\n\n'
    for filename, values in [(Path(FOG_EFFECT).name, fog_defaults), (Path(EFFECT).name, selected)]:
        preset += f'[{filename}]\n' + ''.join(f'{k}={v}\n' for k, v in sorted(values.items())) + '\n'
    payload['Twin-Lanterns-No-Voxel.ini'] = (preset.rstrip() + '\n').encode()
    for name in ['README.md', 'DEFAULTS.json', 'SOURCE_LINEAGE.json']:
        payload[name] = (BUILD / name).read_bytes()
    payload['LICENSE'] = (ROOT / 'LICENSE').read_bytes()
    for name, data in fog.items():
        if not name.startswith(('reshade-shaders/', 'tools/')):
            payload['components/fog-guard/' + name] = data
    manifest = {
        'schema': 'twin-lanterns-no-voxel-bundle-v1',
        'effect_files': [EFFECT, FOG_EFFECT],
        'technique_order': list(TECHNIQUES),
        'twin_lantern_pass_count': 4,
        'twin_lantern_texture_2d_count': 3,
        'twin_lantern_texture_3d_count': 0,
        'twin_lantern_compute_pass_count': 0,
        'fog_guard_component_sha256': fog_sha,
        'fog_guard_shader_bytes_changed': False,
        'native_compile_performed': False,
        'visual_test_performed': False,
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
    manifest = package(path)
    print(json.dumps({'output': str(path), 'sha256': digest(path.read_bytes()),
                      'techniques': manifest['technique_order']}, indent=2))
