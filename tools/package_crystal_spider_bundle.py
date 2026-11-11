#!/usr/bin/env python3
"""Bundle the published Crystal Spider and Fog Guard components without changing shaders."""
from __future__ import annotations

import argparse
from decimal import Decimal
import hashlib
import json
from pathlib import Path, PurePosixPath
import posixpath
import re
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha'
CRYSTAL_EFFECT = 'reshade-shaders/Shaders/camera_obscura/effects/LUNAR_FLOWER_TwinLanterns_FullResolutionDualRayAlpha.fx'
FOG_EFFECT = 'reshade-shaders/Shaders/vendor/occult_box/black_wand/effects/BlackWand_10_FogLight_Guard.fx'
TECHNIQUES = (
    'BlackWand_FogLight_Guard@BlackWand_10_FogLight_Guard.fx',
    'LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlpha@LUNAR_FLOWER_TwinLanterns_FullResolutionDualRayAlpha.fx',
    'BlackWand_FogLight_GuardRestore@BlackWand_10_FogLight_Guard.fx',
)
UNIFORM = re.compile(r'\buniform\s+(int|float|bool)\s+(\w+)\s*<.*?>\s*=\s*([^;]+);', re.S)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_component(path: Path, expected_effect: str) -> tuple[dict[str, bytes], str]:
    checksum = Path(str(path) + '.sha256').read_text().split()
    data = path.read_bytes()
    if len(checksum) != 2 or checksum[1] != path.name or checksum[0].lower() != digest(data):
        raise ValueError(f'Component checksum mismatch: {path.name}')
    payload = {}
    names = set()
    with ZipFile(path) as archive:
        if sum(i.file_size for i in archive.infolist()) > 32 * 1024 * 1024:
            raise ValueError('Component exceeds the bounded input size')
        if archive.testzip() is not None:
            raise ValueError('Component archive integrity failure')
        for item in archive.infolist():
            if item.is_dir():
                continue
            name = item.filename
            parts = PurePosixPath(name)
            if parts.is_absolute() or '..' in parts.parts or '\\' in name or ':' in name or parts.as_posix() != name:
                raise ValueError(f'Unsafe component path: {name}')
            if name.casefold() in names:
                raise ValueError(f'Duplicate component path: {name}')
            names.add(name.casefold())
            payload[name] = archive.read(item)
    if sorted(n for n in payload if n.lower().endswith('.fx')) != [expected_effect]:
        raise ValueError(f'Expected exactly one component effect: {expected_effect}')
    return payload, digest(data)


def defaults(source: bytes) -> dict[str, str]:
    values = {}
    for kind, name, value in UNIFORM.findall(source.decode('utf-8')):
        if name in values:
            raise ValueError(f'Duplicate uniform: {name}')
        values[name] = {'true': '1', 'false': '0'}.get(value.strip(), value.strip())
    return values


def shader_files(payload: dict[str, bytes]) -> dict[str, bytes]:
    return {n: b for n, b in payload.items()
            if n.startswith('reshade-shaders/') and n.lower().endswith(('.fx', '.fxh'))}


def validate_includes(payload: dict[str, bytes]) -> None:
    for name, data in payload.items():
        for include in re.findall(r'^\s*#include\s+"([^"]+)"', data.decode('utf-8'), re.M):
            if include == 'ReShade.fxh':
                continue
            target = posixpath.normpath(str(PurePosixPath(name).parent / include.replace('\\', '/')))
            if target not in payload:
                raise ValueError(f'Missing bundled include {include} from {name}')


def texture_names(payload: dict[str, bytes]) -> set[str]:
    return {name for data in payload.values()
            for name in re.findall(r'^\s*texture(?:1D|2D|3D)?\s+(\w+)\s*\{', data.decode('utf-8'), re.M)}


def package(output: Path) -> dict:
    crystal_path = ROOT / 'downloads/Crystal-Spider-Beta-standalone.zip'
    fog_path = ROOT / 'downloads/Lazara-Fog-Guard-V2.zip'
    crystal, crystal_sha = load_component(crystal_path, CRYSTAL_EFFECT)
    fog, fog_sha = load_component(fog_path, FOG_EFFECT)
    crystal_shaders, fog_shaders = shader_files(crystal), shader_files(fog)
    expected_crystal = {p.relative_to(BUILD).as_posix(): p.read_bytes()
                        for p in (BUILD / 'reshade-shaders').rglob('*') if p.is_file()}
    if crystal_shaders != expected_crystal:
        raise ValueError('Crystal-only archive is stale relative to the current shader source')
    fog_manifest = json.loads(fog['PACKAGE_MANIFEST.json'])
    if {n: digest(b) for n, b in fog_shaders.items()} != fog_manifest['files']:
        raise ValueError('Fog Guard shader/include bytes disagree with its component manifest')
    collision = texture_names(crystal_shaders) & texture_names(fog_shaders)
    if collision:
        raise ValueError(f'Cross-effect texture names collide: {sorted(collision)}')
    payload = {}
    seen = set()
    for name, data in list(crystal_shaders.items()) + list(fog_shaders.items()):
        if name.casefold() in seen:
            raise ValueError(f'Conflicting bundled shader path: {name}')
        seen.add(name.casefold())
        payload[name] = data
    validate_includes(payload)
    for technique in TECHNIQUES:
        name, filename = technique.split('@')
        source = next(b for n, b in payload.items() if PurePosixPath(n).name == filename)
        if not re.search(r'^\s*technique\s+' + re.escape(name) + r'\b', source.decode(), re.M):
            raise ValueError(f'Technique not declared: {technique}')
    profile = json.loads(crystal['DEFAULTS_FROM_PRESET.json'])
    crystal_defaults = defaults(crystal[CRYSTAL_EFFECT])
    selected = profile['defaults']
    if len(selected) != 24 or selected.keys() != crystal_defaults.keys() or any(
            Decimal(v) != Decimal(crystal_defaults[k]) for k, v in selected.items()):
        raise ValueError('Crystal controls disagree with its selected defaults record')
    fog_defaults = defaults(fog[FOG_EFFECT])
    if len(fog_defaults) != 13 or Decimal(fog_defaults['BWBlackWandX_Guard_ShadeOutside']) != 0:
        raise ValueError('Fog Guard defaults do not match the expected neutral V2 profile')
    order = ','.join(TECHNIQUES)
    preset = f'Techniques={order}\nTechniqueSorting={order}\n\n'
    for name, values in [(PurePosixPath(FOG_EFFECT).name, fog_defaults),
                         (PurePosixPath(CRYSTAL_EFFECT).name, selected)]:
        preset += f'[{name}]\n' + ''.join(f'{key}={value}\n' for key, value in sorted(values.items())) + '\n'
    payload['Crystal-Spider-Beta.ini'] = preset.encode()
    payload['README.md'] = (ROOT / 'docs/CRYSTAL_SPIDER_BUNDLE.md').read_bytes()
    payload['LICENSE'] = crystal['LICENSE']
    payload['DEFAULTS_FROM_PRESET.json'] = crystal['DEFAULTS_FROM_PRESET.json']
    for label, component in [('crystal-spider', crystal), ('fog-guard', fog)]:
        for name, data in component.items():
            if not name.startswith('reshade-shaders/') and not name.startswith('tools/'):
                payload[f'components/{label}/{name}'] = data
    manifest = {
        'schema': 'crystal-spider-fog-guard-bundle-v1',
        'component_archives': {
            'crystal_spider': {'filename': crystal_path.name, 'sha256': crystal_sha},
            'fog_guard': {'filename': fog_path.name, 'sha256': fog_sha},
        },
        'effect_files': [CRYSTAL_EFFECT, FOG_EFFECT],
        'shader_include_file_count': len(crystal_shaders) + len(fog_shaders),
        'technique_order': list(TECHNIQUES),
        'preset': 'Crystal-Spider-Beta.ini',
        'preset_default_counts': {'crystal_spider': len(selected), 'fog_guard': len(fog_defaults)},
        'outside_shade': 0,
        'component_shader_bytes_changed': False,
        'cross_effect_texture_collisions': [],
        'external_framework_dependency': 'ReShade.fxh (use installed framework)',
        'new_native_compile_performed': False,
        'new_visual_test_performed': False,
        'files': {n: digest(b) for n, b in sorted(payload.items())},
    }
    payload['BUNDLE_MANIFEST.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
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
    manifest = package(output)
    print(json.dumps({'output': str(output), 'sha256': digest(output.read_bytes()),
                      'effect_count': 2, 'techniques': 3,
                      'shader_include_files': manifest['shader_include_file_count']}, indent=2))
