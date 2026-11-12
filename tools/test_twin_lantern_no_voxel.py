"""Execute shader-extracted CPU comparisons and verify No-Voxel delivery.

CPU shims do not establish native ReShade compilation, GPU parity or FPS.
"""
import configparser
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from zipfile import ZipFile

from audit_twin_lantern_loop_sampling import audit, sources, FUNCTION
from package_crystal_spider_bundle import shader_files, texture_names
from package_twin_lantern_no_voxel import BUILD, EFFECT, ROOT, SHADERS, TECHNIQUES, package, validate_source
from test_twin_lantern_screen_surface import block
from test_twin_lantern_adaptive_voxel import voxel_cpp
from test_twin_lantern_inactive_work import effect_cpp


def no_voxel_cpp():
    effect = (BUILD / EFFECT).read_text()
    text = ''.join(f'{kind} {name}={value};\n' for kind, name, value in re.findall(
        r'\buniform\s+(int|float|bool)\s+(\w+)\s*<.*?>\s*=\s*([^;]+);', effect, re.S))
    text += '\nint LUNAR_FLOWER_TLNVRawSampler=1,LUNAR_FLOWER_TLNVResolveHSampler=2,LUNAR_FLOWER_TLNVResolveVSampler=3;\n'
    text += (SHADERS / 'api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh').read_text()
    for match in FUNCTION.finditer(effect):
        text += block(effect, match.group(0)) + '\n'
    text = re.sub(r'\[(?:branch|loop)\]', '', text)
    text = re.sub(r'\s*:\s*(?:SV_Position|TEXCOORD|SV_Target)\b', '', text)
    text = re.sub(r'\b(?:out|inout) (float3|float|CAMERA_OBSCURA_\w+) (\w+)', r'\1& \2', text)
    text = text.replace('.rgb', '.rgb()')
    text = re.sub(r'\b(\d+\.\d+)\.xxx', r'float3(\1)', text)
    text = re.sub(r'\b(\w+)\.xxx', r'float3(\1)', text)
    return re.sub(r'\b(\d+\.\d+)(?![\w.])', r'\1f', text)


CASES = r'''
int assertions=0;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);++assertions;}
bool close(float a,float b){return abs(a-b)<.00001f;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
bool close(float4 a,float4 b){return close(a.rgb(),b.rgb())&&close(a.a,b.a);}
void resetReads(){depthSamples=0;colorSamples=0;nodeWrites=0;nodeReads=0;imageReads=0;}
int main(){try{
 float4 position(0,0,0,1);
 LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength=0;
 // Match the selected Crystal Spider profile, excluding voxel-only controls.
 MATCH_DEFAULTS
 for(int fixture: {0,1,2,3,4,5,6,7,8,9}){
  voxelFixture=fixture;
  for(int pairCount=1;pairCount<=4;++pairCount){
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaRayPairs=pairCount;
   LUNAR_FLOWER_TwinLanternsNoVoxelRayPairs=pairCount;
   for(int p=0;p<9;++p){
    float2 uv(p==0?0.f:p==8?1.f:.48f+p*.005f,p==0?0.f:p==8?1.f:.5f);
    resetReads();auto oldRaw=LUNAR_FLOWER_TLFRRaw_PS(position,uv);int oldReads=depthSamples;
    resetReads();auto raw=LUNAR_FLOWER_TLNVRaw_PS(position,uv);
    check(close(oldRaw,raw),"No-Voxel transport differs from Alpha voxel-zero");
    check(oldReads==depthSamples&&nodeReads==0&&nodeWrites==0,"unexpected transport sampling/storage work");
    auto oldH=LUNAR_FLOWER_TLFRResolveH_PS(position,uv);
    auto newH=LUNAR_FLOWER_TLNVResolveH_PS(position,uv);
    auto oldV=LUNAR_FLOWER_TLFRResolveV_PS(position,uv);
    auto newV=LUNAR_FLOWER_TLNVResolveV_PS(position,uv);
    check(close(oldH,newH)&&close(oldV,newV),"surface reconstruction changed");
    auto oldFinal=LUNAR_FLOWER_TLFRDisplay_PS(position,uv);
    auto final=LUNAR_FLOWER_TLNVDisplay_PS(position,uv);
    check(close(oldFinal,final),"final image differs from Alpha voxel-zero");
    float3 source=CAMERA_OBSCURA_LoadColor(uv);
    check(final.x>=source.x&&final.y>=source.y&&final.z>=source.z&&
      final.x<=1&&final.y<=1&&final.z<=1,"final light violates source/channel bounds");
   }
  }
 }
 voxelFixture=0;float2 uv(.5f,.5f);
 // Production bypasses must avoid transport/depth work and preserve source.
 for(int mode=0;mode<3;++mode){
  LUNAR_FLOWER_TwinLanternsNoVoxelView=mode==0?1:0;
  LUNAR_FLOWER_TwinLanternsNoVoxelEnabled=mode!=1;
  LUNAR_FLOWER_TwinLanternsNoVoxelStrength=mode==2?0:1;
  resetReads();
  check(LUNAR_FLOWER_TLNVRaw_PS(position,uv).a==0,"inactive transport produced evidence");
  check(LUNAR_FLOWER_TLNVResolveH_PS(position,uv).a==0&&
    LUNAR_FLOWER_TLNVResolveV_PS(position,uv).a==0,"inactive resolve produced evidence");
  check(depthSamples==0&&imageReads==0,"inactive working passes sampled inputs");
  auto final=LUNAR_FLOWER_TLNVDisplay_PS(position,uv);
  check(close(final.rgb(),float3(.6f,.4f,.2f))&&imageReads==1&&depthSamples==0,"inactive output not source-only");
 }
 LUNAR_FLOWER_TwinLanternsNoVoxelEnabled=true;
 LUNAR_FLOWER_TwinLanternsNoVoxelStrength=.272f;
 // Updated diagnostic index must skip every lighting/resolve pass.
 LUNAR_FLOWER_TwinLanternsNoVoxelView=14;
 LUNAR_FLOWER_TwinLanternsNoVoxelDepthFadeStart=.2f;
 LUNAR_FLOWER_TwinLanternsNoVoxelDepthFadeEnd=.6f;
 LUNAR_FLOWER_TwinLanternsNoVoxelDepthFadeStrength=1;
 resetReads();LUNAR_FLOWER_TLNVRaw_PS(position,uv);
 LUNAR_FLOWER_TLNVResolveH_PS(position,uv);LUNAR_FLOWER_TLNVResolveV_PS(position,uv);
 check(depthSamples==0&&imageReads==0,"fade-mask working passes did lighting work");
 auto mask=LUNAR_FLOWER_TLNVDisplay_PS(position,uv);
 check(close(mask.rgb(),float3(.5f))&&depthSamples==1&&imageReads==0,"depth mask index/value incorrect");
 // Diagnose and stress bounded composite across low/high strength and fade.
 LUNAR_FLOWER_TwinLanternsNoVoxelView=0;
 LUNAR_FLOWER_TwinLanternsNoVoxelDepthFadeStart=0;
 LUNAR_FLOWER_TwinLanternsNoVoxelDepthFadeEnd=.2f;
 for(float strength: {0.f,.001f,.1f,.272f,1.f,4.f})
 for(float fade: {0.f,.355f,1.f})
 for(float overdrive: {0.f,1.f}){
  LUNAR_FLOWER_TwinLanternsNoVoxelStrength=strength;
  LUNAR_FLOWER_TwinLanternsNoVoxelDepthFadeStrength=fade;
  LUNAR_FLOWER_TwinLanternsNoVoxelOverdrive=overdrive;
  float target=0,fidelity=0,pressure=0;float3 fill(0);
  auto result=LUNAR_FLOWER_TLNVEvaluateComposite(uv,target,fill,fidelity,pressure);
  check(result.bounds_valid>0.5,"composite reported invalid bounds");
  auto c=result.bounded_contribution_rgb;
  check(c.x>=0&&c.y>=0&&c.z>=0&&c.x<=.20001f&&c.y<=.20001f&&c.z<=.20001f,"contribution ceiling failed");
  check(close(result.final_rgb,result.source_rgb+c),"composite changed source beyond bounded addition");
  if(strength==0||fade==1)check(close(result.final_rgb,result.source_rgb),"zero/faded light not exact bypass");
 }
 std::cout<<"PASS: "<<assertions<<" No-Voxel CPU assertions; voxel-zero equivalence, bounds, bypass and fade mask\n";
}catch(const std::exception& e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}}
'''


class NoVoxelTests(unittest.TestCase):
    def test_source_resources_defaults_and_independent_identity(self):
        payload = validate_source()
        self.assertEqual(len(payload), 10)
        text = payload[EFFECT].decode()
        self.assertEqual(len(re.findall(r'^texture2D\s', text, re.M)), 3)
        self.assertEqual(len(re.search(r'ui_items = "([^"]+)"', text)[1].split('\\0')) - 1, 15)
        original = ROOT / 'Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/reshade-shaders/Shaders/camera_obscura'
        old = {str(p): p.read_bytes() for p in original.rglob('*') if p.is_file()}
        self.assertFalse(texture_names(payload) & texture_names(old))
        for p in SHADERS.rglob('*.fxh'):
            if p.name != 'LUNAR_FLOWER_TwinLanternScreenSurface.fxh':
                self.assertEqual(p.read_bytes(), (original / p.relative_to(SHADERS)).read_bytes())

    def test_detects_implicit_gradient_reintroduced_in_screen_loop(self):
        texts = sources(SHADERS)
        helper = next(n for n in texts if n.endswith('LUNAR_FLOWER_TwinLanternScreenSurface.fxh'))
        texts[helper] = texts[helper].replace(
            'tex2Dlod(ReShade::BackBuffer, float4(hit.uv, 0.0, 0.0)).rgb',
            'CAMERA_OBSCURA_LoadColor(hit.uv)')
        failures = audit(texts, entrypoints=('LUNAR_FLOWER_TLNVRaw_PS',))
        self.assertTrue(any('CAMERA_OBSCURA_LoadColor -> tex2D' in f for f in failures), failures)

    @unittest.skipUnless(shutil.which('c++'), 'requires C++17 CPU fixture compiler')
    def test_actual_shader_against_alpha_with_voxel_disabled(self):
        selected = json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults']
        assignments = '\n'.join(k.replace('TwinLanternsNoVoxel', 'TwinLanternsFullResolutionDualRayAlpha')
                                + '=' + k + ';' for k in selected)
        source = voxel_cpp(2560, 1440, cases='') + effect_cpp() + no_voxel_cpp()
        source += CASES.replace('MATCH_DEFAULTS', assignments)
        with tempfile.TemporaryDirectory(prefix='tl-no-voxel-cpu-') as tmp:
            path = Path(tmp) / 'fixture.cpp'
            path.write_text(source)
            exe = Path(tmp) / 'fixture'
            result = subprocess.run(['c++', '-std=c++17', '-O2', str(path), '-o', str(exe)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(exe)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout, end='')

    def test_reproducible_bundle_and_unchanged_fog_guard(self):
        with tempfile.TemporaryDirectory(prefix='tl-no-voxel-package-') as tmp:
            a, b = Path(tmp) / 'a.zip', Path(tmp) / 'b.zip'
            manifest = package(a)
            package(b)
            self.assertEqual(a.read_bytes(), b.read_bytes())
            with ZipFile(a) as archive, ZipFile(ROOT / 'downloads/Lazara-Fog-Guard-V2.zip') as fog:
                self.assertIsNone(archive.testzip())
                for name, data in shader_files({n: fog.read(n) for n in fog.namelist()}).items():
                    self.assertEqual(archive.read(name), data)
                for name, sha in manifest['files'].items():
                    self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), sha)
                self.assertFalse(any(Path(n).name == 'ReShade.fxh' for n in archive.namelist()))
                self.assertFalse(any('VoxelProxy' in n for n in archive.namelist()))
                preset = configparser.ConfigParser(interpolation=None)
                preset.optionxform = str
                preset.read_string('[PRESET]\n' + archive.read('Twin-Lanterns-No-Voxel.ini').decode())
                self.assertEqual(preset['PRESET']['Techniques'], ','.join(TECHNIQUES))
                self.assertEqual(dict(preset[Path(EFFECT).name]),
                                 json.loads((BUILD / 'DEFAULTS.json').read_text())['defaults'])


if __name__ == '__main__':
    unittest.main()
