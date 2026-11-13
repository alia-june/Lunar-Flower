"""Shader-extracted direction/budget/diagnostic CPU probes; not a GPU compiler."""
import configparser
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile

from audit_twin_lantern_loop_sampling import FUNCTION, audit, sources
from package_crystal_spider_bundle import texture_names
from package_twin_lantern_direction_lab import BUILD, EFFECT, PREFIX, ROOT, SHADERS, package, presets, validate_source
import test_twin_lantern_screen_surface as cpu


TEXTURES = r'''
int fixture=0,depthSamples=0,colorSamples=0,imageReads=0;
float2 lastDepthUv(0,0);
float CAMERA_OBSCURA_LoadDepth(float2 uv){
 ++depthSamples;lastDepthUv=uv;
 if(fixture==3)return 1;
 if(fixture==4)return .9f;
 return .4f;
}
float3 CAMERA_OBSCURA_LoadColor(float2 uv){
 ++colorSamples;
 auto d=(uv-float2(.5f,.5f))/CAMERA_OBSCURA_PixelSize();
 if(fixture==1)return abs(d.x)>1&&abs(d.y)>1?float3(.8f,.4f,.2f):float3(0);
 if(fixture==2)return abs(d.x)<.5f||abs(d.y)<.5f?float3(.8f,.4f,.2f):float3(0);
 return float3(.6f,.4f,.2f);
}
'''


def effect_cpp():
    effect = (BUILD / EFFECT).read_text()
    text = ''.join(f'{kind} {name}={value};\n' for kind, name, value in re.findall(
        r'\buniform\s+(int|float|bool)\s+(\w+)\s*<.*?>\s*=\s*([^;]+);', effect, re.S))
    text += r'''
int LUNAR_FLOWER_TLDLRawSampler=1,LUNAR_FLOWER_TLDLResolveHSampler=2,LUNAR_FLOWER_TLDLResolveVSampler=3;
float4 tex2D(int sampler,float2 uv){++imageReads;
 if(sampler==ReShade::BackBuffer)return float4(CAMERA_OBSCURA_LoadColor(uv),1);
 return float4(.4f,.3f,.2f,.8f);}
float smoothstep(float a,float b,float x){float t=saturate((x-a)/(b-a));return t*t*(3-2*t);}
float3 lerp(float3 a,float3 b,float t){return a+(b-a)*t;}
float3& operator+=(float3& a,float3 b){a=a+b;return a;}
float3& operator*=(float3& a,float b){a=a*b;return a;}
float3 CAMERA_OBSCURA_DebugHeat(float x){return float3(x);}
'''
    text += cpu.block(effect, 'struct LUNAR_FLOWER_TLDLDirectionEvidence') + ';\n'
    for match in FUNCTION.finditer(effect):
        text += cpu.block(effect, match.group(0)) + '\n'
    text = re.sub(r'\[(?:branch|loop)\]', '', text)
    text = re.sub(r'\s*:\s*(?:SV_Position|TEXCOORD|SV_Target)\b', '', text)
    text = re.sub(r'\b(?:out|inout) (float3|float|CAMERA_OBSCURA_\w+) (\w+)', r'\1& \2', text)
    text = text.replace('.rgb', '.rgb()')
    text = re.sub(r'\b(\d+\.\d+)\.xxx', r'float3(\1)', text)
    text = re.sub(r'\b([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\.xxx', r'float3(\1)', text)
    return re.sub(r'\b(\d+\.\d+)(?![\w.])', r'\1f', text)


CASES = r'''
int assertions=0;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);++assertions;}
bool close(float a,float b){return abs(a-b)<.0001f;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
void reset(){depthSamples=0;colorSamples=0;imageReads=0;}
int main(){try{
 float2 uv(.5f,.5f);float4 position(0,0,0,1);
 // Schedule checks are separate from an actual ray sample/count probe below.
 for(int mode=0;mode<3;++mode){
  LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet=mode;
  int count=LUNAR_FLOWER_TLDLDirectionCount(),seen=0;
  check(count==(mode==2?8:4),"wrong direction count");
  float2 sum(0,0);
  for(int i=0;i<count;++i){
   int index=(int)LUNAR_FLOWER_TLDLDirectionIndex(i);
   check(index>=0&&index<8&&!(seen&(1<<index)),"duplicate/out-of-range direction");seen|=1<<index;
   if(mode<2)check(index%2==mode,"cardinal/diagonal directions mixed");
   auto d=CAMERA_OBSCURA_API_TL45Direction((float)index);sum=sum+d;
   check(close(length(d),1),"pixel direction length is not unit");
  }
  check(close(length(sum),0),"schedule not opposing/symmetric");
 }
 // Use a valid fixed receiver and a far donor plane: no early hit/refinement.
 fixture=4;auto receiver=CAMERA_OBSCURA_API_DefaultTL08Guide();
 receiver.valid=1;receiver.depth=.4f;receiver.normal=float3(0,0,1);receiver.depth_confidence=1;
 float referenceDepthTravel=-1,referenceMarchDistance=-1;
 for(int direction=0;direction<8;++direction){
  reset();auto dda=LUNAR_FLOWER_TLDLTraceScreenDetailed(uv,(float)direction,24,.16f,.000052f,.0035f,1,receiver);
  check(depthSamples==32&&colorSamples==0,"DDA budget differs with direction or unused provider ran");
  check(dda.dda_hit==0&&dda.march_hit==0&&dda.combined.a==0,"miss invented provider evidence");
  check(close(length((lastDepthUv-uv)/CAMERA_OBSCURA_PixelSize()),24),"DDA travel not 24 pixels");
  if(direction==0)referenceDepthTravel=recordedDepthTravel;
  check(abs(recordedDepthTravel-referenceDepthTravel)<.00000001f,"normalized depth travel differs by direction");
  reset();auto march=LUNAR_FLOWER_TLDLTraceScreenDetailed(uv,(float)direction,24,.16f,.000052f,.0035f,2,receiver);
  check(depthSamples==16&&colorSamples==0,"march budget differs with direction or unused provider ran");
  float distance=length((lastDepthUv-uv)/CAMERA_OBSCURA_PixelSize());
  if(direction==0)referenceMarchDistance=distance;
  check(close(distance,referenceMarchDistance),"march jitter/distance differs by direction");
  reset();LUNAR_FLOWER_TLDLTraceScreenDetailed(uv,(float)direction,24,.16f,.000052f,.0035f,0,receiver);
  check(depthSamples==48,"dual provider budget not additive");
 }
 // Flat geometry, zero slope: angular color targets isolate coverage and keep
 // valid black donors distinct from missing hits. Mixed averages both sets.
 LUNAR_FLOWER_TwinLanternsDirectionLabDepthSlope=0;
 LUNAR_FLOWER_TwinLanternsDirectionLabProviderMode=0;
 for(int scene=1;scene<=2;++scene){
  fixture=scene;
  LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet=0;
  auto card=LUNAR_FLOWER_TLDLEvaluateDirections(uv);
  LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet=1;
  auto diag=LUNAR_FLOWER_TLDLEvaluateDirections(uv);
  LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet=2;
  auto mixed=LUNAR_FLOWER_TLDLEvaluateDirections(uv);
  check(card.dda_hits>0&&diag.dda_hits>0&&card.march_hits>0&&diag.march_hits>0,"angular fixture lost valid geometry");
  if(scene==1)check(close(card.combined.rgb(),float3(0))&&diag.combined.x>.7f,"diagonal donor not isolated");
  if(scene==2)check(close(diag.combined.rgb(),float3(0))&&card.combined.x>.7f,"cardinal donor not isolated");
  auto mean=(card.combined.rgb()*card.combined.a+diag.combined.rgb()*diag.combined.a)*.5f;
  check(close(mixed.combined.rgb()*mixed.combined.a,mean),"mixed schedule doubled or misnormalized energy");
 }
 fixture=0;
 for(int mode=0;mode<3;++mode){
  LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet=mode;
  for(int provider=0;provider<3;++provider){
   LUNAR_FLOWER_TwinLanternsDirectionLabProviderMode=provider;
   auto e=LUNAR_FLOWER_TLDLEvaluateDirections(uv);
   check(close(e.combined.rgb(),float3(.6f,.4f,.2f))&&e.combined.a>0&&e.combined.a<=1,"constant donor color/evidence changed");
   if(provider==1)check(e.march_hits==0&&e.march_weight==0&&close(e.march_signal,float3(0)),"disabled march left evidence");
   if(provider==2)check(e.dda_hits==0&&e.dda_weight==0&&close(e.dda_signal,float3(0)),"disabled DDA left evidence");
   auto expected=(e.dda_signal+e.march_signal)*(provider==0?.5f:1.f);
   check(close(e.combined.rgb()*e.combined.a,expected),"selected providers not independently normalized");
   // Every provider diagnostic skips all working-pass trace/resolve sampling.
   for(int view=15;view<=25;++view){
    LUNAR_FLOWER_TwinLanternsDirectionLabView=view;reset();
    LUNAR_FLOWER_TLDLRaw_PS(position,uv);LUNAR_FLOWER_TLDLResolveH_PS(position,uv);LUNAR_FLOWER_TLDLResolveV_PS(position,uv);
    check(depthSamples==0&&imageReads==0&&colorSamples==0,"diagnostic working passes did work");
    auto output=LUNAR_FLOWER_TLDLDisplay_PS(position,uv);
    check(imageReads==0,"provider diagnostic read reconstructed lighting");
    if(view==15)check(close(output.rgb(),float3(e.dda_hits)),"DDA hit mapping incorrect");
    if(view==16)check(close(output.rgb(),float3(e.march_hits)),"march hit mapping incorrect");
    if(view==17)check(close(output.rgb(),float3(e.dda_weight)),"DDA weight mapping incorrect");
    if(view==18)check(close(output.rgb(),float3(e.march_weight)),"march weight mapping incorrect");
    if(view==19)check(close(output.rgb(),e.dda_donor_sum),"DDA raw donor mapping incorrect");
    if(view==20)check(close(output.rgb(),e.march_donor_sum),"march raw donor mapping incorrect");
    if(view==21)check(close(output.rgb(),e.dda_signal),"DDA signal mapping incorrect");
    if(view==22)check(close(output.rgb(),e.march_signal),"march signal mapping incorrect");
    if(view==23)check(close(output.rgb(),e.combined.rgb()),"combined donor mapping incorrect");
    if(view==24)check(close(output.rgb(),e.combined.rgb()*e.combined.a),"combined signal mapping incorrect");
    if(view==25)check(close(output.rgb(),float3(1)),"receiver validity mapping incorrect");
   }
  }
 }
 LUNAR_FLOWER_TwinLanternsDirectionLabView=0;
 for(int mode=0;mode<3;++mode){
  LUNAR_FLOWER_TwinLanternsDirectionLabView=mode==0?1:0;
  LUNAR_FLOWER_TwinLanternsDirectionLabEnabled=mode!=1;
  LUNAR_FLOWER_TwinLanternsDirectionLabStrength=mode==2?0:.272f;
  reset();LUNAR_FLOWER_TLDLRaw_PS(position,uv);LUNAR_FLOWER_TLDLResolveH_PS(position,uv);LUNAR_FLOWER_TLDLResolveV_PS(position,uv);
  check(depthSamples==0&&imageReads==0&&colorSamples==0,"source bypass did lighting work");
  auto source=LUNAR_FLOWER_TLDLDisplay_PS(position,uv);
  check(close(source.rgb(),float3(.6f,.4f,.2f))&&depthSamples==0&&imageReads==1,"source bypass changed output");
 }
 LUNAR_FLOWER_TwinLanternsDirectionLabView=0;LUNAR_FLOWER_TwinLanternsDirectionLabEnabled=true;
 LUNAR_FLOWER_TwinLanternsDirectionLabStrength=.272f;fixture=3;reset();
 auto invalid=LUNAR_FLOWER_TLDLEvaluateDirections(uv);
 check(invalid.receiver_valid==0&&invalid.combined.a==0&&depthSamples==5&&colorSamples==0,"invalid receiver traced providers");
 fixture=0;
 for(float strength: {0.f,.1f,.272f,1.f,4.f}){
  LUNAR_FLOWER_TwinLanternsDirectionLabStrength=strength;
  float target=0,fidelity=0,pressure=0;float3 fill(0);
  auto result=LUNAR_FLOWER_TLDLEvaluateComposite(uv,target,fill,fidelity,pressure);
  check(result.bounds_valid>.5f,"final composite violated bounds");
  check(close(result.final_rgb,result.source_rgb+result.bounded_contribution_rgb),"final composite altered source beyond bounded addition");
 }
 std::cout<<"PASS: "<<assertions<<" Direction Lab CPU assertions; equal budgets, angular donors, normalized providers, diagnostics and bounds\n";
}catch(const std::exception& e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}}
'''


class DirectionLabTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('c++'), 'requires a C++17 CPU fixture compiler')
    def test_actual_shader_schedules_providers_and_diagnostics(self):
        with patch.object(cpu, 'BASE', SHADERS):
            source = cpu.shader_cpp(2560, 1440, cases='', textures=TEXTURES)
        # Supply the missing CPU float4 default constructor, without initializing
        # its components; the shader must still initialize every evidence field.
        source = source.replace('struct float4 {', 'struct float4 {\n float4()=default;')
        source = source.replace('CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceDDA(',
                                'CAMERA_OBSCURA_Hit RecordedTraceDDA(')
        wrapper = r'''
float recordedDepthTravel=0;
CAMERA_OBSCURA_Hit CAMERA_OBSCURA_TraceDDA(CAMERA_OBSCURA_Ray ray,CAMERA_OBSCURA_TraceControls controls){
 recordedDepthTravel=ray.step_depth*ray.steps;
 return RecordedTraceDDA(ray,controls);
}
'''
        source = source.replace('struct LUNAR_FLOWER_TLDLScreenEvidence',
                                wrapper + '\nstruct LUNAR_FLOWER_TLDLScreenEvidence', 1)
        source += effect_cpp() + CASES
        with tempfile.TemporaryDirectory(prefix='tl-direction-lab-') as tmp:
            path = Path(tmp) / 'fixture.cpp'
            path.write_text(source)
            exe = Path(tmp) / 'fixture'
            result = subprocess.run(['c++', '-std=c++17', '-O2', str(path), '-o', str(exe)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(exe)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout, end='')

    def test_source_and_resource_independence(self):
        payload = validate_source()
        self.assertEqual(len(payload), 10)
        old_root = ROOT / 'Twin-Lanterns/No-Voxel/reshade-shaders'
        old = {str(p): p.read_bytes() for p in old_root.rglob('*') if p.is_file()}
        self.assertFalse(texture_names(payload) & texture_names(old))
        records = json.loads((BUILD / 'SOURCE_LINEAGE.json').read_text())['files']
        self.assertEqual(sum(i['byte_identical'] for i in records), 7)

    def test_unsafe_sampling_is_detected(self):
        texts = sources(SHADERS)
        helper = next(n for n in texts if n.endswith('LUNAR_FLOWER_TwinLanternScreenSurface.fxh'))
        texts[helper] = texts[helper].replace(
            'tex2Dlod(ReShade::BackBuffer, float4(hit.uv, 0.0, 0.0)).rgb',
            'CAMERA_OBSCURA_LoadColor(hit.uv)')
        failures = audit(texts, entrypoints=('LUNAR_FLOWER_TLDLEvaluateDirections',))
        self.assertTrue(any('CAMERA_OBSCURA_LoadColor -> tex2D' in f for f in failures), failures)

    def test_reproducible_package_and_matched_presets(self):
        with tempfile.TemporaryDirectory(prefix='tl-direction-package-') as tmp:
            a, b = Path(tmp) / 'a.zip', Path(tmp) / 'b.zip'
            manifest = package(a)
            package(b)
            self.assertEqual(a.read_bytes(), b.read_bytes())
            with ZipFile(a) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual([n for n in archive.namelist() if n.endswith('.fx')], [EFFECT])
                self.assertFalse(any(Path(n).name == 'ReShade.fxh' for n in archive.namelist()))
                for name, sha in manifest['files'].items():
                    self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), sha)
                common = None
                for mode, (name, data) in enumerate(presets().items()):
                    self.assertEqual(archive.read(name), data)
                    cfg = configparser.ConfigParser(interpolation=None)
                    cfg.optionxform = str
                    cfg.read_string('[PRESET]\n' + data.decode())
                    section = dict(cfg['LUNAR_FLOWER_TwinLanterns_DirectionLab.fx'])
                    self.assertEqual(section.pop(PREFIX + 'DirectionSet'), str(mode))
                    if common is None:
                        common = section
                    self.assertEqual(section, common, 'A/B presets differ beyond direction selection')


if __name__ == '__main__':
    unittest.main()
