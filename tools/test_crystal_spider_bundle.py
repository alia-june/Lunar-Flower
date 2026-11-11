"""Verify the combined delivery and preset against the actual published components."""
import configparser
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile, ZIP_DEFLATED

from package_crystal_spider_bundle import ROOT, CRYSTAL_EFFECT, FOG_EFFECT, load_component, package


class CrystalSpiderBundleTests(unittest.TestCase):
    def test_complete_ordered_bundle_preserves_components_and_defaults(self):
        with tempfile.TemporaryDirectory(prefix='crystal-fog-bundle-') as tmp:
            first, second = Path(tmp) / 'first.zip', Path(tmp) / 'second.zip'
            package(first)
            package(second)
            self.assertEqual(first.read_bytes(), second.read_bytes(), 'Build must be reproducible')
            self.assertEqual(first.read_bytes(), (ROOT / 'downloads/Crystal-Spider-Beta.zip').read_bytes(),
                             'Published bundle must match the current reproducible build')
            expected = {}
            for filename in ['Crystal-Spider-Beta-standalone.zip', 'Lazara-Fog-Guard-V2.zip']:
                with ZipFile(ROOT / 'downloads' / filename) as component:
                    for name in component.namelist():
                        if name.startswith('reshade-shaders/') and name.endswith(('.fx', '.fxh')):
                            self.assertNotIn(name, expected)
                            expected[name] = component.read(name)
            with ZipFile(first) as bundle:
                self.assertIsNone(bundle.testzip())
                self.assertEqual(sorted(n for n in bundle.namelist() if n.endswith('.fx')), sorted([CRYSTAL_EFFECT, FOG_EFFECT]))
                self.assertEqual(len(expected), 70)
                self.assertTrue(all(bundle.read(n) == b for n, b in expected.items()))
                self.assertFalse(any(Path(n).name == 'ReShade.fxh' for n in bundle.namelist()))
                manifest = json.loads(bundle.read('BUNDLE_MANIFEST.json'))
                for name, sha in manifest['files'].items():
                    self.assertEqual(hashlib.sha256(bundle.read(name)).hexdigest(), sha)
                preset = configparser.ConfigParser(interpolation=None, strict=True)
                preset.optionxform = str
                self.assertEqual(bundle.read('Crystal-Spider-Beta.ini'),
                                 (ROOT / 'presets/Crystal-Spider-Beta.ini').read_bytes())
                preset.read_string('[PRESET]\n' + bundle.read('Crystal-Spider-Beta.ini').decode())
                order = preset['PRESET']['Techniques'].split(',')
                self.assertEqual([t.split('@')[0] for t in order], [
                    'BlackWand_FogLight_Guard',
                    'LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlpha',
                    'BlackWand_FogLight_GuardRestore',
                ])
                self.assertEqual(preset['PRESET']['Techniques'], preset['PRESET']['TechniqueSorting'])
                self.assertEqual(len(preset.sections()), 3)
                profile = json.loads(bundle.read('DEFAULTS_FROM_PRESET.json'))
                self.assertEqual(dict(preset[Path(CRYSTAL_EFFECT).name]), profile['defaults'])
                self.assertEqual(len(profile['defaults']), 24)
                fog = preset[Path(FOG_EFFECT).name]
                self.assertEqual(len(fog), 13)
                for name, value in [('ShadeOutside', '0'), ('Strength', '1'), ('DepthStart', '.005'), ('DepthEnd', '.05'), ('DebugView', '0')]:
                    self.assertEqual(Decimal(fog['BWBlackWandX_Guard_' + name]), Decimal(value))
                self.assertIn('components/fog-guard/LICENSES/VENDORED-SOURCE-NOTICE.md', bundle.namelist())

    def _component(self, tmp, names):
        path = Path(tmp) / 'component.zip'
        with ZipFile(path, 'w', compression=ZIP_DEFLATED) as archive:
            for name in names:
                archive.writestr(name, b'fixture')
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        Path(str(path) + '.sha256').write_text(sha + '  ' + path.name + '\n')
        return path

    def test_component_checksum_is_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self._component(tmp, [CRYSTAL_EFFECT])
            Path(str(path) + '.sha256').write_text('0' * 64 + '  ' + path.name + '\n')
            with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
                load_component(path, CRYSTAL_EFFECT)

    def test_rejects_case_insensitive_duplicate_install_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self._component(tmp, [CRYSTAL_EFFECT, CRYSTAL_EFFECT.upper()])
            with self.assertRaisesRegex(ValueError, 'Duplicate component path'):
                load_component(path, CRYSTAL_EFFECT)

    def test_rejects_unsafe_archive_paths(self):
        for bad in ['../outside.fx', '/absolute.fx', 'C:/outside.fx', 'folder//effect.fx']:
            with self.subTest(path=bad), tempfile.TemporaryDirectory() as tmp:
                path = self._component(tmp, [CRYSTAL_EFFECT, bad])
                with self.assertRaisesRegex(ValueError, 'Unsafe component path'):
                    load_component(path, CRYSTAL_EFFECT)


if __name__ == '__main__':
    unittest.main()
