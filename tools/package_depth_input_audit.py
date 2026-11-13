"""Package the isolated, display-only depth-input diagnostic."""
from pathlib import Path
import argparse
import hashlib
import json
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

from package_crystal_spider_bundle import validate_includes
from package_twin_lantern_provider_perf import validate_declaration_names

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'development/depth-input-audit'
EFFECT = 'reshade-shaders/Shaders/lunar_flower_depth_audit/effects/LUNAR_FLOWER_DepthInputAudit.fx'
PRESET = b'''Techniques=LUNAR_FLOWER_DepthInputAudit@LUNAR_FLOWER_DepthInputAudit.fx
TechniqueSorting=LUNAR_FLOWER_DepthInputAudit@LUNAR_FLOWER_DepthInputAudit.fx

[LUNAR_FLOWER_DepthInputAudit.fx]
LF_DPA_View=1
LF_DPA_Projection=0
LF_DPA_Exposure=0.0
LF_DPA_DisplayPower=0.25
LF_DPA_ProbeUV=0.5,0.5
LF_DPA_ShowNumbers=1
'''


def package(output: Path) -> dict:
    payload = {EFFECT: (BUILD / EFFECT).read_bytes()}
    validate_includes(payload)
    validate_declaration_names(payload)
    payload.update({'Depth-Input-Audit.ini': PRESET,
                    'README.md': (BUILD / 'README.md').read_bytes(),
                    'LICENSE': (ROOT / 'LICENSE').read_bytes()})
    manifest = {'schema': 'lunar-flower-depth-input-audit-v1',
                'effect_files': [EFFECT], 'pixel_pass_count': 1,
                'working_textures': 0, 'display_only': True,
                'changes_global_definitions': False, 'changes_gi_shaders': False,
                'automatic_depth_convention_detection': False,
                'files': {n: hashlib.sha256(b).hexdigest() for n, b in sorted(payload.items())}}
    payload['PACKAGE_MANIFEST.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    with output.open('xb') as stream, ZipFile(stream, 'w', compression=ZIP_DEFLATED) as archive:
        for name, data in sorted(payload.items()):
            entry = ZipInfo(name, date_time=(2000, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_DEFLATED
            archive.writestr(entry, data)
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    path = parser.parse_args().output
    package(path)
    print(hashlib.sha256(path.read_bytes()).hexdigest(), path)
