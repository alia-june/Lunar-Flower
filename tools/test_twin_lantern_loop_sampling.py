from pathlib import Path
import re
import shutil
import tempfile
import unittest
from unittest.mock import patch

from audit_twin_lantern_loop_sampling import SHADERS, audit, audit_directory, sources
import package_twin_lantern_alpha as package


class LoopSamplingTests(unittest.TestCase):
    def test_active_loop_call_graphs_are_derivative_free(self):
        self.assertEqual([], audit_directory())

    def test_indirect_screen_gradient_regression_is_detected(self):
        texts = sources()
        name = next(n for n in texts if n.endswith('LUNAR_FLOWER_TwinLanternScreenSurface.fxh'))
        safe = 'tex2Dlod(ReShade::BackBuffer, float4(hit.uv, 0.0, 0.0)).rgb'
        self.assertIn(safe, texts[name])
        texts[name] = texts[name].replace(safe, 'CAMERA_OBSCURA_LoadColor(hit.uv)')
        failures = audit(texts)
        self.assertTrue(any('SampleScreenDonor -> CAMERA_OBSCURA_LoadColor -> tex2D' in x for x in failures), failures)

    def test_indirect_voxel_gradient_regression_is_detected(self):
        texts = sources()
        name = next(n for n in texts if n.endswith('LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh'))
        texts[name], count = re.subn(
            r'tex2Dlod\(\s*ReShade::BackBuffer,\s*float4\(requestedUv, 0\.0, 0\.0\)\)\.rgb',
            'CAMERA_OBSCURA_LoadColor(requestedUv)', texts[name],
        )
        self.assertEqual(1, count)
        failures = audit(texts)
        self.assertTrue(any('TraceTwinLanternVoxelProxyWithReceiver -> CAMERA_OBSCURA_LoadColor -> tex2D' in x for x in failures), failures)

    def test_package_refuses_an_unsafe_loop_call_graph(self):
        with tempfile.TemporaryDirectory() as temp:
            build = Path(temp) / 'build'
            shaders = build / 'reshade-shaders/Shaders/camera_obscura'
            shutil.copytree(SHADERS, shaders)
            helper = shaders / 'api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh'
            helper.write_text(helper.read_text().replace(
                'tex2Dlod(ReShade::BackBuffer, float4(hit.uv, 0.0, 0.0)).rgb',
                'CAMERA_OBSCURA_LoadColor(hit.uv)',
            ))
            output = Path(temp) / 'unsafe.zip'
            with patch.object(package, 'BUILD', build), self.assertRaisesRegex(ValueError, 'Implicit-gradient'):
                package.package(output)
            self.assertFalse(output.exists())

    def test_adaptive_resources_have_a_distinct_layout_identity(self):
        text = (SHADERS / 'api/LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh').read_text()
        names = re.findall(r'^(?:texture3D|storage3D|sampler3D)\s+(\w+)', text, re.M)
        self.assertEqual(['LUNAR_FLOWER_TLAdaptiveAtlasV1Tex', 'LUNAR_FLOWER_TLAdaptiveAtlasV1Storage',
                          'LUNAR_FLOWER_TLAdaptiveAtlasV1Sampler'], names)
        self.assertNotIn('FullResolutionDualRayAlphaVoxelRadianceTex', text)


if __name__ == '__main__':
    unittest.main()
