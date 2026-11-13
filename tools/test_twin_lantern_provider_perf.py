"""Preprocessor/CPU sampling probes; these do not measure DX11/DX12 GPU time."""
import configparser
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile

from audit_twin_lantern_loop_sampling import FUNCTION
from package_crystal_spider_bundle import texture_names
from package_twin_lantern_provider_perf import BUILD, EFFECT, PREFIX, PROFILES, ROOT, SHADERS, matrix, package, presets, validate_source
import test_twin_lantern_screen_surface as cpu
import test_twin_lantern_bounce_lab as parent


def effect_cpp():
    text = (BUILD / EFFECT).read_text()
    result = ''.join(f'{kind} {name}={value};\n' for kind, name, value in re.findall(
        r'\buniform\s+(int|float|bool)\s+(\w+)\s*<.*?>\s*=\s*([^;]+);', text, re.S))
    result += '\nint LUNAR_FLOWER_TLPPRawSampler=1,LUNAR_FLOWER_TLPPResolveHSampler=2,LUNAR_FLOWER_TLPPResolveVSampler=3;\n'
    result += 'int LUNAR_FLOWER_TLPPFirstLightSampler=4,LUNAR_FLOWER_TLPPBounceSampler=5;\n'
    result += cpu.block(text, 'struct LUNAR_FLOWER_TLPPDirectionEvidence') + ';\n'
    for match in FUNCTION.finditer(text):
        result += cpu.block(text, match.group(0)) + '\n'
    return parent.translate(result)


WRAPPER = r'''
int ddaCalls=0,marchCalls=0;
float ddaReach=0,marchReach=0,depthTravel=0;
CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceDDA(CAMERA_OBSCURA_Ray ray,CAMERA_OBSCURA_TraceControls controls){
 ++ddaCalls;ddaReach=length((ray.step_uv*ray.steps)/CAMERA_OBSCURA_PixelSize());depthTravel=ray.step_depth*ray.steps;
 return RecordedDDA(ray,controls);
}
CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceMarch(CAMERA_OBSCURA_Ray ray,CAMERA_OBSCURA_TraceControls controls){
 ++marchCalls;marchReach=length((ray.step_uv*ray.steps)/CAMERA_OBSCURA_PixelSize());depthTravel=ray.step_depth*ray.steps;
 return RecordedMarch(ray,controls);
}
'''

CASES = r'''
int assertions=0;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);++assertions;}
bool close(float a,float b){return abs(a-b)<.0001f;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
bool close(float4 a,float4 b){return close(a.rgb(),b.rgb())&&close(a.a,b.a);}
void reset(){depthSamples=0;colorSamples=0;firstReads=0;bounceReads=0;imageReads=0;ddaCalls=0;marchCalls=0;}
int main(){try{
 float2 uv(.5f,.5f);float4 position(0,0,0,1);
 fixture=4;auto receiver=CAMERA_OBSCURA_API_DefaultTL08Guide();
 receiver.valid=1;receiver.depth=.4f;receiver.normal=float3(0,0,1);receiver.depth_confidence=1;
 float expectedTravel=.16f*24*(1.f/2560+1.f/1440)*.5f;
 for(int runtime=0;runtime<3;++runtime)for(int direction=0;direction<8;++direction){
  int active=LUNAR_FLOWER_TLPP_COMPILED_PROVIDER>=0?LUNAR_FLOWER_TLPP_COMPILED_PROVIDER:runtime;
  reset();auto hit=LUNAR_FLOWER_TLPPTraceScreenDetailed(uv,(float)direction,24,.16f,.000052f,.0035f,runtime,false,receiver);
  int expected=(active!=2?LUNAR_FLOWER_TLPP_DDA_STEPS:0)+(active!=1?LUNAR_FLOWER_TLPP_MARCH_STEPS:0);
  check(depthSamples==expected,"wrong traversal sample budget or unused provider executed");
  check(ddaCalls==(active!=2)&&marchCalls==(active!=1),"compiled provider choice not honored");
  if(active!=2)check(close(ddaReach,24),"lower DDA density shortened ray reach");
  if(active!=1)check(close(marchReach,24),"lower march density shortened ray reach");
  check(abs(depthTravel-expectedTravel)<.00000001f,"sample budget/direction changed depth travel");
  check(hit.combined.a==0&&colorSamples==0&&firstReads==0&&bounceReads==0,"far-plane miss sampled donor light");
 }
 // A small valid receiver patch followed by far donors prevents early hits,
 // allowing an actual full-schedule traversal count for each direction set.
 fixture=5;
 for(int dirs=0;dirs<3;++dirs){
  LUNAR_FLOWER_TwinLanternsProviderPerfDirectionSet=dirs;
  LUNAR_FLOWER_TwinLanternsProviderPerfProviderMode=0;
  int count=dirs==2?8:4;
  int active=LUNAR_FLOWER_TLPP_COMPILED_PROVIDER>=0?LUNAR_FLOWER_TLPP_COMPILED_PROVIDER:0;
  int expected=count*((active!=2?LUNAR_FLOWER_TLPP_DDA_STEPS:0)+(active!=1?LUNAR_FLOWER_TLPP_MARCH_STEPS:0));
  reset();auto first=LUNAR_FLOWER_TLPPRaw_PS(position,uv);
  check(first.a==0&&depthSamples==5+expected,"first gather full-budget count differs from schedule");
  reset();auto second=LUNAR_FLOWER_TLPPBounce_PS(position,uv);
  check(second.a==0&&depthSamples==5+expected,"extra gather full-budget count differs from schedule");
  check(firstReads==0&&colorSamples==0,"missed extra gather read source/light data");
 }
 fixture=0;LUNAR_FLOWER_TwinLanternsProviderPerfDepthSlope=0;
 // Uniform-color donors retain color and independent provider averaging.
 for(int dirs=0;dirs<3;++dirs){
  LUNAR_FLOWER_TwinLanternsProviderPerfDirectionSet=dirs;
  auto hit=LUNAR_FLOWER_TLPPEvaluateDirections(uv);
  check(close(hit.combined.rgb(),float3(.6f,.4f,.2f))&&hit.combined.a>0&&hit.combined.a<=1,"constant donor normalization changed");
  int active=LUNAR_FLOWER_TLPP_COMPILED_PROVIDER>=0?LUNAR_FLOWER_TLPP_COMPILED_PROVIDER:0;
  if(active==1)check(hit.march_hits==0&&hit.march_weight==0,"compiled-out march produced evidence");
  if(active==2)check(hit.dda_hits==0&&hit.dda_weight==0,"compiled-out DDA produced evidence");
  auto expected=(hit.dda_signal+hit.march_signal)*(active==0?.5f:1.f);
  check(close(hit.combined.rgb()*hit.combined.a,expected),"provider specialization changed normalization");
  float target=0,fidelity=0,pressure=0;float3 fill(0);
  auto total=LUNAR_FLOWER_TLPPEvaluateComposite(uv,target,fill,fidelity,pressure);
  check(total.bounds_valid>.5f&&close(total.final_rgb,total.source_rgb+total.bounded_contribution_rgb),"specialized composite violated bounds/source preservation");
 }
 // At the original 32/16 budget, compare actual first-pass and composite
 // behavior with Bounce Lab. Other budgets intentionally change hit density.
#if LUNAR_FLOWER_TLPP_DDA_STEPS == 32 && LUNAR_FLOWER_TLPP_MARCH_STEPS == 16 && LUNAR_FLOWER_TLPP_COMPILED_PROVIDER <= 0
 MATCH_PARENT
 for(int scene: {0,1,2,3,4})for(int dirs=0;dirs<3;++dirs){
  fixture=scene;
  LUNAR_FLOWER_TwinLanternsProviderPerfDirectionSet=dirs;LUNAR_FLOWER_TwinLanternsBounceLabDirectionSet=dirs;
  auto a=LUNAR_FLOWER_TLBLRaw_PS(position,uv),b=LUNAR_FLOWER_TLPPRaw_PS(position,uv);
  check(close(a,b),"parent-budget primary transport changed");
  auto oldBounce=LUNAR_FLOWER_TLBLBounce_PS(position,uv),newBounce=LUNAR_FLOWER_TLPPBounce_PS(position,uv);
  check(close(oldBounce,newBounce),"parent-budget secondary gather changed");
  firstField=LUNAR_FLOWER_TLPPFirstLight_PS(position,uv);
  auto old=LUNAR_FLOWER_TLBLDisplay_PS(position,uv),now=LUNAR_FLOWER_TLPPDisplay_PS(position,uv);
  check(close(old,now),"parent-budget composition changed");
 }
#endif

 // Exercise the actual display dispatch after storing first light at RGBA16F
 // precision. Keep the reference composite in full precision to bound the
 // cache rounding difference, rather than pretending it is bit-identical.
 fixture=0;LUNAR_FLOWER_TwinLanternsProviderPerfView=0;
 LUNAR_FLOWER_TwinLanternsProviderPerfBounceStrength=.5f;
 LUNAR_FLOWER_TwinLanternsProviderPerfBounceRetention=.5f;
 for(int scene: {0,1,2,3,4})for(int dirs=0;dirs<3;++dirs){
  fixture=scene;LUNAR_FLOWER_TwinLanternsProviderPerfDirectionSet=dirs;
  auto capture=LUNAR_FLOWER_TLPPFirstLight_PS(position,uv);
  firstField=float4((float)(_Float16)capture.x,(float)(_Float16)capture.y,
                   (float)(_Float16)capture.z,(float)(_Float16)capture.a);
  bounceField=LUNAR_FLOWER_TLPPBounce_PS(position,uv);
  float target=0,fidelity=0,pressure=0;float3 fill(0);
  reset();auto reference=LUNAR_FLOWER_TLPPEvaluateComposite(uv,target,fill,fidelity,pressure);
  int referenceReads=depthSamples+imageReads+firstReads+bounceReads;
  reset();auto actual=LUNAR_FLOWER_TLPPDisplay_PS(position,uv);
  check(abs(actual.x-reference.final_rgb.x)<.0002f&&abs(actual.y-reference.final_rgb.y)<.0002f&&
        abs(actual.z-reference.final_rgb.z)<.0002f,"cached display exceeds half-storage error tolerance");
#if LUNAR_FLOWER_TLPP_CACHE_FIRST_LIGHT
  check(depthSamples==1&&imageReads==1,"cached display repeated reconstruction/depth-guide work");
  if(scene==0&&dirs==0)std::cout<<"final texture calls: recomputed="<<referenceReads<<" cached="
       <<depthSamples+imageReads+firstReads+bounceReads<<"\n";
  check(firstReads==(scene==3?0:1)&&bounceReads==(scene==3?0:1),"cached display read fields more than once");
#endif
 }
 // Random bounds and source colors, including highlights and no own-pixel
 // admission. Compare against the existing full-precision AddBounce math.
 fixture=6;unsigned int state=17;
 auto random=[&](){state=state*1664525u+1013904223u;return (float)(state>>8)/16777215.f;};
 float maxDifference=0;
 for(int i=0;i<4000;++i){
  testSource=float3(random(),random(),random());testDepth=.00001f+random()*.9999f;
  LUNAR_FLOWER_TwinLanternsProviderPerfMaximumContribution=random()*.5f;
  LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStrength=random();
  LUNAR_FLOWER_TwinLanternsProviderPerfColorAnchor=random();
  LUNAR_FLOWER_TwinLanternsProviderPerfStrength=i%7==0?.00001f:random()*4;
  float target=0,fidelity=0,pressure=0;float3 fill(0);
  auto first=LUNAR_FLOWER_TLPPEvaluateFirstComposite(uv,target,fill,fidelity,pressure);
  firstField=float4((float)(_Float16)first.bounded_contribution_rgb.x,
                   (float)(_Float16)first.bounded_contribution_rgb.y,
                   (float)(_Float16)first.bounded_contribution_rgb.z,first.admission);
  bounceField=float4(random()*.2f,random()*.2f,random()*.2f,1);
  auto reference=LUNAR_FLOWER_TLPPAddBounce(first,bounceField.rgb(),testDepth);
  float3 source(0);auto contribution=LUNAR_FLOWER_TLPPCachedContribution(uv,source);
  auto ceiling=min(float3(LUNAR_FLOWER_TwinLanternsProviderPerfMaximumContribution),float3(1)-testSource)*
       LUNAR_FLOWER_TLPPDepthFadeFactor(testDepth);
  check(close(source,testSource),"cache changed source color");
  check(contribution.x>=0&&contribution.y>=0&&contribution.z>=0,"cache darkened source");
  check(contribution.x<=ceiling.x+.0000001f&&contribution.y<=ceiling.y+.0000001f&&
        contribution.z<=ceiling.z+.0000001f,"half rounding escaped faded/channel ceiling");
  auto difference=abs(contribution-reference.bounded_contribution_rgb);
  maxDifference=max(maxDifference,max(max(difference.x,difference.y),difference.z));
  check(max(max(difference.x,difference.y),difference.z)<.0003f,"cached bounce diverged beyond storage tolerance");
 }

 // Near-black cache quantization must not flip the color-anchor threshold or
 // amplify half subnormal hue errors. This path intentionally reconstructs.
 testDepth=.4f;testSource=float3(.1f,.3f,.7f);
 LUNAR_FLOWER_TwinLanternsProviderPerfMaximumContribution=.2f;
 LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStrength=0;
 LUNAR_FLOWER_TwinLanternsProviderPerfColorAnchor=1;
 for(int i=1;i<=100;++i){
  LUNAR_FLOWER_TwinLanternsProviderPerfStrength=(float)i*.0000005f;
  float target=0,fidelity=0,pressure=0;float3 fill(0);
  auto first=LUNAR_FLOWER_TLPPEvaluateFirstComposite(uv,target,fill,fidelity,pressure);
  firstField=float4((float)(_Float16)first.bounded_contribution_rgb.x,
                   (float)(_Float16)first.bounded_contribution_rgb.y,
                   (float)(_Float16)first.bounded_contribution_rgb.z,first.admission);
  bounceField=float4(.08f,.03f,.01f,1);
  auto reference=LUNAR_FLOWER_TLPPAddBounce(first,bounceField.rgb(),testDepth);
  float3 source(0);auto actual=LUNAR_FLOWER_TLPPCachedContribution(uv,source);
  check(close(actual,reference.bounded_contribution_rgb),"near-black half cache changed color anchor");
 }
 // An upward-rounded cache value must be clipped, without applying fade twice.
 LUNAR_FLOWER_TwinLanternsProviderPerfStrength=.272f;
 testSource=float3(.1f);testDepth=.4f;
 LUNAR_FLOWER_TwinLanternsProviderPerfMaximumContribution=.2f;
 LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStrength=.355f;
 firstField=float4((float)(_Float16).129f,(float)(_Float16).129f,(float)(_Float16).129f,1);
 bounceField=float4(0,0,0,0);float3 cachedSource(0);
 auto capped=LUNAR_FLOWER_TLPPCachedContribution(uv,cachedSource);
 check(abs(capped.x-.129f)<.0000001f,"cache rounded above ceiling or faded first light twice");
 firstField=float4(0,0,0,0);bounceField=float4(.05f,.05f,.05f,1);
 check(LUNAR_FLOWER_TLPPCachedContribution(uv,cachedSource).x>0,"own admission suppressed valid incoming bounce");
 for(float depth: {0.f,.0000005f,1.f}){
  testDepth=depth;reset();
  auto noLight=LUNAR_FLOWER_TLPPCachedContribution(uv,cachedSource);
  check(close(noLight,float3(0))&&firstReads==0&&bounceReads==0,"invalid depth emitted cached light");
 }
 testDepth=.4f;LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStrength=1;
 check(close(LUNAR_FLOWER_TLPPCachedContribution(uv,cachedSource),float3(0)),"full depth fade leaked light");
 LUNAR_FLOWER_TwinLanternsProviderPerfDepthFadeStrength=0;
 LUNAR_FLOWER_TwinLanternsProviderPerfView=0;reset();
 auto final=LUNAR_FLOWER_TLPPDisplay_PS(position,uv);
 LUNAR_FLOWER_TwinLanternsProviderPerfView=4;
 auto applied=LUNAR_FLOWER_TLPPDisplay_PS(position,uv);
 check(close(final.rgb(),testSource+applied.rgb()),"Applied Light differs from production contribution");
 LUNAR_FLOWER_TwinLanternsProviderPerfView=0;
 for(int mode=0;mode<4;++mode){
  LUNAR_FLOWER_TwinLanternsProviderPerfEnabled=mode!=0;
  LUNAR_FLOWER_TwinLanternsProviderPerfStrength=mode==1?0.f:.272f;
  LUNAR_FLOWER_TwinLanternsProviderPerfBounceStrength=mode==2?0.f:.5f;
  LUNAR_FLOWER_TwinLanternsProviderPerfBounceRetention=mode==3?0.f:.5f;
  reset();LUNAR_FLOWER_TLPPDisplay_PS(position,uv);
  check(firstReads==0&&bounceReads==0,"disabled lighting/bounce read cached fields");
 }
 std::cout<<"maximum half-storage final contribution error="<<maxDifference<<"\n";
 std::cout<<"PASS: "<<assertions<<" performance CPU assertions; DDA="<<LUNAR_FLOWER_TLPP_DDA_STEPS
  <<" March="<<LUNAR_FLOWER_TLPP_MARCH_STEPS<<" compiled="<<LUNAR_FLOWER_TLPP_COMPILED_PROVIDER
  <<" cache="<<LUNAR_FLOWER_TLPP_CACHE_FIRST_LIGHT<<"\n";
}catch(const std::exception& e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}}
'''


class ProviderPerformanceTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('c++'), 'requires C++17 CPU fixture compiler')
    def test_all_compiled_budget_variants(self):
        variants = sorted({(p[1], p[2], p[3], p[6]) for p in PROFILES})
        for dda, march, compiled, cache in variants:
            with self.subTest(dda=dda, march=march, compiled=compiled, cache=cache):
                defines = f'#define LUNAR_FLOWER_TLPP_DDA_STEPS {dda}\n#define LUNAR_FLOWER_TLPP_MARCH_STEPS {march}\n#define LUNAR_FLOWER_TLPP_COMPILED_PROVIDER {compiled}\n'
                defines += f'#define LUNAR_FLOWER_TLPP_CACHE_FIRST_LIGHT {cache}\n'
                defines += '#define CAMERA_OBSCURA_MARCH_MAX_STEPS LUNAR_FLOWER_TLPP_MARCH_STEPS\n'
                defines += '#if LUNAR_FLOWER_TLPP_COMPILED_PROVIDER>=0\n#define LUNAR_FLOWER_TLPP_ACTIVE_PROVIDER LUNAR_FLOWER_TLPP_COMPILED_PROVIDER\n#else\n#define LUNAR_FLOWER_TLPP_ACTIVE_PROVIDER LUNAR_FLOWER_TwinLanternsProviderPerfProviderMode\n#endif\n'
                textures = parent.parent.TEXTURES.replace(' if(fixture==4)return .9f;', ''' if(fixture==4)return .9f;
 if(fixture==6)return testDepth;
 if(fixture==5){auto d=length((uv-float2(.5f,.5f))/CAMERA_OBSCURA_PixelSize());return d<=1.5f?.4f:.9f;}''')
                textures = textures.replace('float2 lastDepthUv', 'float testDepth=.4f;float3 testSource(.6f,.4f,.2f);\nfloat2 lastDepthUv')
                textures = textures.replace(' ++colorSamples;', ' ++colorSamples;if(fixture==6)return testSource;')
                with patch.object(cpu, 'BASE', SHADERS):
                    source = defines + cpu.shader_cpp(2560, 1440, cases='', textures=textures)
                source = source.replace('struct float4 {', 'struct float4 {\n float4()=default;')
                fields = 'float4 tex2D(int sampler,float2 uv);\n' + parent.FIELDS.replace(
                    'return float4(CAMERA_OBSCURA_LoadColor(float2(coords.x,coords.y)),1);',
                    'return tex2D(sampler,float2(coords.x,coords.y));')
                source, n = re.subn(r'float4 tex2Dlod\(int, float4 coords\)\s*\{[^{}]+\}', fields, source)
                self.assertEqual(n, 1)
                source = source.replace('CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceDDA(', 'CAMERA_OBSCURA_Hit RecordedDDA(')
                source = source.replace('CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceMarch(', 'CAMERA_OBSCURA_Hit RecordedMarch(')
                source = source.replace('struct LUNAR_FLOWER_TLPPScreenEvidence', WRAPPER + '\nstruct LUNAR_FLOWER_TLPPScreenEvidence', 1)
                source += parent.translate((parent.parent.SHADERS / 'api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh').read_text())
                source += parent.parent.effect_cpp()
                source += '\nfloat3 operator-(float3 a){return float3(0)-a;}\n'
                source += parent.translate((parent.SHADERS / 'api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh').read_text())
                source += parent.effect_cpp() + effect_cpp()
                values = json.loads((parent.BUILD / 'DEFAULTS.json').read_text())['defaults']
                assignments = '\n'.join(k + '=' + k.replace('TwinLanternsBounceLab', 'TwinLanternsProviderPerf') + ';' for k in values)
                source += CASES.replace('MATCH_PARENT', assignments)
                with tempfile.TemporaryDirectory(prefix='tl-provider-perf-') as tmp:
                    path = Path(tmp) / 'fixture.cpp'
                    path.write_text(source)
                    exe = Path(tmp) / 'fixture'
                    result = subprocess.run(['c++', '-std=c++17', '-O2', str(path), '-o', str(exe)], text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    result = subprocess.run([str(exe)], text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    print(result.stdout, end='')

    @unittest.skipUnless(shutil.which('c++'), 'requires a preprocessor')
    def test_unused_provider_call_path_is_removed_before_compilation(self):
        helper = (SHADERS / 'api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh').read_text()
        for provider in (-1, 0, 1, 2):
            result = subprocess.run(['c++', '-E', '-P', '-x', 'c', f'-DLUNAR_FLOWER_TLPP_COMPILED_PROVIDER={provider}', '-'],
                                    input=helper, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            body = cpu.block(result.stdout, 'LUNAR_FLOWER_TLPPScreenEvidence LUNAR_FLOWER_TLPPTraceScreenDetailed(')
            self.assertEqual('CAMERA_OBSCURA_TraceDDA(ray,' in body, provider != 2)
            self.assertEqual('CAMERA_OBSCURA_TraceMarch(ray,' in body, provider != 1)

    def test_source_resource_independence_and_budget_matrix(self):
        payload = validate_source()
        self.assertEqual(len(payload), 10)
        old = {str(p): p.read_bytes() for p in parent.SHADERS.rglob('*') if p.is_file()}
        self.assertFalse(texture_names(payload) & texture_names(old))
        rows = list(csv.DictReader(io.StringIO(matrix())))
        counts = {r['preset']: int(r['maximum_traversal_samples_per_pixel']) for r in rows}
        self.assertEqual([counts[n] for n in ('Cardinal4-EqualTraversal', 'Diagonal4-EqualTraversal', 'Mixed8-EqualTraversal')], [256, 256, 256])
        self.assertEqual(counts['Mixed8-FullDensity'], 512)
        self.assertEqual(counts['DDA16-Only'], counts['March16-Only'])
        self.assertTrue(all(r['measured_effect_gpu_ms'] == '' for r in rows))

    def test_package_presets_define_compiled_modes_and_preserve_controls(self):
        with tempfile.TemporaryDirectory(prefix='tl-provider-perf-package-') as tmp:
            a, b = Path(tmp) / 'a.zip', Path(tmp) / 'b.zip'
            manifest = package(a)
            package(b)
            self.assertEqual(a.read_bytes(), b.read_bytes())
            with ZipFile(a) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual([n for n in archive.namelist() if n.endswith('.fx')], [EFFECT])
                for name, sha in manifest['files'].items():
                    self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), sha)
                for profile, (name, data) in zip(PROFILES, presets().items()):
                    self.assertEqual(archive.read(name), data)
                    cfg = configparser.ConfigParser(interpolation=None)
                    cfg.optionxform = str
                    cfg.read_string('[PRESET]\n' + data.decode())
                    defs = cfg['PRESET']['PreprocessorDefinitions']
                    self.assertIn(f'LUNAR_FLOWER_TLPP_DDA_STEPS={profile[1]}', defs)
                    self.assertIn(f'LUNAR_FLOWER_TLPP_MARCH_STEPS={profile[2]}', defs)
                    self.assertIn(f'LUNAR_FLOWER_TLPP_COMPILED_PROVIDER={profile[3]}', defs)
                    self.assertIn(f'LUNAR_FLOWER_TLPP_CACHE_FIRST_LIGHT={profile[6]}', defs)
                    section = cfg[Path(EFFECT).name]
                    self.assertEqual(PREFIX + 'ProviderMode' in section, profile[3] < 0)
                    self.assertEqual(section[PREFIX + 'DirectionSet'], str(profile[4]))
                    self.assertEqual(section[PREFIX + 'RayLengthPixels'], '24.0')
                    self.assertEqual(len(cfg['PRESET']['Techniques'].split(',')), 1)
                for cached, reference in (
                        ('Cardinal4-EqualTraversal', 'RecomputedComposite'),
                        ('Mixed8-FullDensity', 'Mixed8-FullDensity-Recomputed'),
                        ('Parent32-16', 'Parent32-16-Recomputed')):
                    a = archive.read(f'Twin-Lanterns-ProviderPerf-{cached}.ini')
                    b = archive.read(f'Twin-Lanterns-ProviderPerf-{reference}.ini')
                    self.assertEqual(a.replace(b'LUNAR_FLOWER_TLPP_CACHE_FIRST_LIGHT=1',
                                               b'LUNAR_FLOWER_TLPP_CACHE_FIRST_LIGHT=0'), b)


if __name__ == '__main__':
    unittest.main()
