"""Execute bounded bounce/color/dropout CPU fixtures; not native ReShade validation."""
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
from package_twin_lantern_bounce_lab import BUILD, EFFECT, PREFIX, ROOT, SHADERS, package, presets, validate_source
import test_twin_lantern_screen_surface as cpu
import test_twin_lantern_direction_lab as parent


def translate(text):
    text = re.sub(r'\[(?:branch|loop)\]', '', text)
    text = re.sub(r'\s*:\s*(?:SV_Position|TEXCOORD|SV_Target)\b', '', text)
    text = re.sub(r'\b(?:out|inout) (float3|float|CAMERA_OBSCURA_\w+) (\w+)', r'\1& \2', text)
    text = text.replace('.rgb', '.rgb()')
    text = re.sub(r'\b(\d+\.\d+)\.xxx', r'float3(\1)', text)
    text = re.sub(r'\b([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\.xxx', r'float3(\1)', text)
    return re.sub(r'\b(\d+\.\d+)(?![\w.])', r'\1f', text)


def effect_cpp():
    effect = (BUILD / EFFECT).read_text()
    text = ''.join(f'{kind} {name}={value};\n' for kind, name, value in re.findall(
        r'\buniform\s+(int|float|bool)\s+(\w+)\s*<.*?>\s*=\s*([^;]+);', effect, re.S))
    text += '\nint LUNAR_FLOWER_TLBLRawSampler=1,LUNAR_FLOWER_TLBLResolveHSampler=2,LUNAR_FLOWER_TLBLResolveVSampler=3;\n'
    text += 'int LUNAR_FLOWER_TLBLFirstLightSampler=4,LUNAR_FLOWER_TLBLBounceSampler=5;\n'
    text += cpu.block(effect, 'struct LUNAR_FLOWER_TLBLDirectionEvidence') + ';\n'
    for match in FUNCTION.finditer(effect):
        text += cpu.block(effect, match.group(0)) + '\n'
    return translate(text)


FIELDS = r'''
float4 firstField(.08f,.04f,.02f,1),bounceField(0,0,0,0);
int firstReads=0,bounceReads=0;
float4 tex2Dlod(int sampler,float4 coords){
 if(sampler==4){++firstReads;return firstField;}
 if(sampler==5){++bounceReads;return bounceField;}
 return float4(CAMERA_OBSCURA_LoadColor(float2(coords.x,coords.y)),1);
}
'''


CASES = r'''
int assertions=0;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);++assertions;}
bool close(float a,float b){return abs(a-b)<.0001f;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
bool close(float4 a,float4 b){return close(a.rgb(),b.rgb())&&close(a.a,b.a);}
void reset(){depthSamples=0;colorSamples=0;imageReads=0;firstReads=0;bounceReads=0;}
float peak(float3 a){return max(max(a.x,a.y),a.z);}
int main(){try{
 float2 uv(.5f,.5f);float4 position(0,0,0,1);
 MATCH_PARENT
 LUNAR_FLOWER_TwinLanternsBounceLabBounceStrength=0;
 // The new first-pass path and disabled-extra output must retain the parent.
 for(int scene: {0,1,2,3,4})for(int dirs=0;dirs<3;++dirs)for(int provider=0;provider<3;++provider){
  fixture=scene;
  LUNAR_FLOWER_TwinLanternsBounceLabDirectionSet=dirs;LUNAR_FLOWER_TwinLanternsDirectionLabDirectionSet=dirs;
  LUNAR_FLOWER_TwinLanternsBounceLabProviderMode=provider;LUNAR_FLOWER_TwinLanternsDirectionLabProviderMode=provider;
  for(float slope: {0.f,.16f}){
   LUNAR_FLOWER_TwinLanternsBounceLabDepthSlope=slope;LUNAR_FLOWER_TwinLanternsDirectionLabDepthSlope=slope;
   auto a=LUNAR_FLOWER_TLDLRaw_PS(position,uv),b=LUNAR_FLOWER_TLBLRaw_PS(position,uv);
   check(close(a,b),"first transport changed from Direction Lab");
   auto old=LUNAR_FLOWER_TLDLDisplay_PS(position,uv);reset();
   auto current=LUNAR_FLOWER_TLBLDisplay_PS(position,uv);
   check(close(old,current),"disabled bounce changed final baseline");
   check(firstReads==0&&bounceReads==0,"disabled bounce read a secondary field");
   reset();auto capture=LUNAR_FLOWER_TLBLFirstLight_PS(position,uv);
   auto second=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
   check(close(capture,float4(0,0,0,0))&&close(second,float4(0,0,0,0))&&depthSamples==0&&imageReads==0&&colorSamples==0,
    "disabled bounce passes did sampling work");
  }
 }
 fixture=0;LUNAR_FLOWER_TwinLanternsBounceLabDirectionSet=0;
 LUNAR_FLOWER_TwinLanternsBounceLabProviderMode=0;LUNAR_FLOWER_TwinLanternsBounceLabDepthSlope=0;
 LUNAR_FLOWER_TwinLanternsBounceLabBounceStrength=.5f;
 LUNAR_FLOWER_TwinLanternsBounceLabBounceRetention=.5f;
 LUNAR_FLOWER_TwinLanternsBounceLabBounceDistanceDecay=0;
 LUNAR_FLOWER_TwinLanternsBounceLabChaosAmount=0;
 auto gather=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
 check(gather.x>0&&gather.a>0&&gather.x<=.08f*.25f,"secondary input gained unbounded energy");
 reset();LUNAR_FLOWER_TLBLBounce_PS(position,uv);
 check(firstReads>0&&bounceReads==0&&colorSamples==0,"secondary gather sampled source/final color instead of first light");
 for(int mode: {-1,3}){
  LUNAR_FLOWER_TwinLanternsBounceLabProviderMode=mode;
  check(close(LUNAR_FLOWER_TLBLBounce_PS(position,uv),gather),"out-of-range provider mode misnormalized the active providers");
 }
 LUNAR_FLOWER_TwinLanternsBounceLabProviderMode=0;
 // Distance and per-bounce losses must reduce energy without changing hue.
 float last=gather.x;
 for(float decay: {0.f,.5f,1.f,2.f,4.f}){
  LUNAR_FLOWER_TwinLanternsBounceLabBounceDistanceDecay=decay;
  auto value=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
  check(value.x<=last+.000001f&&value.x>=0,"distance decay increased energy");last=value.x;
  check(close(value.x,2*value.y)&&close(value.y,2*value.z),"distance decay changed donor hue");
  float previous=1;
  for(int i=0;i<=100;++i){
   float gain=LUNAR_FLOWER_TLBLBounceDistanceGain((float)i*.24f);
   check(gain>=0&&gain<=1&&gain<=previous+.000001f,"distance gain not bounded/monotone");previous=gain;
  }
 }
 LUNAR_FLOWER_TwinLanternsBounceLabBounceDistanceDecay=0;
 LUNAR_FLOWER_TwinLanternsBounceLabBounceRetention=.25f;
 auto quarter=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
 check(close(quarter.rgb(),gather.rgb()*.5f),"bounce retention not multiplicative");
 LUNAR_FLOWER_TwinLanternsBounceLabBounceRetention=.5f;
 LUNAR_FLOWER_TwinLanternsBounceLabBounceStrength=.25f;
 auto strength=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
 check(close(strength.rgb(),gather.rgb()*.5f),"bounce strength not multiplicative");
 LUNAR_FLOWER_TwinLanternsBounceLabBounceStrength=.5f;
 // Discarding a captured field with no admitted data cannot create light.
 firstField.a=0;auto unavailable=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
 check(close(unavailable,float4(0,0,0,0)),"missing first-light support emitted energy");firstField.a=1;
 // A deterministic broken pattern is artificial missing support, not a fresh
 // per-frame sample and not a reason to renormalize surviving light upward.
 for(int mode=0;mode<3;++mode){
  LUNAR_FLOWER_TwinLanternsBounceLabChaosMode=mode;
  for(float amount: {0.f,.2f,.5f,1.f}){
   LUNAR_FLOWER_TwinLanternsBounceLabChaosAmount=amount;
   for(int i=0;i<120;++i){
    auto p=float2(.2f+(i%12)*.005f,.3f+(i/12)*.005f);
    for(int dir=0;dir<8;++dir){
     float keep=LUNAR_FLOWER_TLBLChaosRetention(p,(float)dir);
     check(keep>=0&&keep<=1&&keep==LUNAR_FLOWER_TLBLChaosRetention(p,(float)dir),"chaos retention unstable or outside bounds");
     if(amount==0)check(keep==1,"chaos zero changed a direction");
    }
   }
   float retained=0;
   for(int slot=0;slot<4;++slot)retained+=LUNAR_FLOWER_TLBLChaosRetention(uv,LUNAR_FLOWER_TLBLDirectionIndex(slot));
   auto broken=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
   check(close(broken.rgb(),gather.rgb()*(retained*.25f)),"lost energy was renormalized among survivors");
   if(mode==1&&amount==1){
    reset();auto none=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
    check(close(none,float4(0,0,0,0))&&depthSamples==5&&firstReads==0&&colorSamples==0,"fully dropped directions still traced/sampled light");
   }
  }
 }
 // Seed changes the spatial pattern; identical seed/pixel/direction repeats.
 int changed=0;LUNAR_FLOWER_TwinLanternsBounceLabChaosAmount=.5f;
 for(int i=0;i<100;++i){
  auto p=float2(.2f+i*.001f,.4f);
  LUNAR_FLOWER_TwinLanternsBounceLabChaosSeed=17;float a=LUNAR_FLOWER_TLBLChaosRetention(p,0);
  LUNAR_FLOWER_TwinLanternsBounceLabChaosSeed=18;float b=LUNAR_FLOWER_TLBLChaosRetention(p,0);
  if(a!=b)++changed;
 }check(changed>10,"seed did not change uncertainty pattern");
 // Perceptual anchoring changes color without increasing luminance or peak.
 for(float anchor: {0.f,.5f,1.f}){
  LUNAR_FLOWER_TwinLanternsBounceLabColorAnchor=anchor;
  for(int i=0;i<100;++i){
   auto signal=float3(.01f+i*.001f,.04f,.02f),first=float3(.02f,.08f,.04f);
   auto anchored=LUNAR_FLOWER_TLBLAnchorBounceColor(signal,first);
   check(peak(anchored)<=peak(signal)+.000001f&&CAMERA_OBSCURA_Luma(anchored)<=CAMERA_OBSCURA_Luma(signal)+.000001f&&anchored.x>=0&&anchored.y>=0&&anchored.z>=0,"color anchor restored lost energy or went negative");
   check(close(LUNAR_FLOWER_TLBLAnchorBounceColor(float3(0),first),float3(0)),"color anchor invented energy after total dropout");
   if(anchor==0)check(close(anchored,signal),"zero color anchor not exact bypass");
   if(anchor==1)check(close(anchored.x,anchored.y*.25f)&&close(anchored.z,anchored.y*.5f),"full color anchor failed to retain reference hue");
  }
 }
 LUNAR_FLOWER_TwinLanternsBounceLabChaosAmount=0;LUNAR_FLOWER_TwinLanternsBounceLabColorAnchor=.5f;
 // Run actual composition functions across source colors, first energies,
 // receiver fades and oversized secondary candidates. Existing source/first
 // contribution must survive, and the total must respect the faded ceiling.
 for(int i=0;i<4000;++i){
  float r=(float)(i%17)/16,g=(float)((i/17)%13)/12,b=(float)((i/221)%11)/10;
  auto source=float3(r,g,b);
  float depth=(float)(i%101)/100;
  auto first=CAMERA_OBSCURA_API_BuildTL09Composite(source,float3(.8f,.4f,.2f),.8f,1,1,(float)(i%9)*.5f,.2f);
  first=LUNAR_FLOWER_TLBLFadeComposite(first,depth);
  auto total=LUNAR_FLOWER_TLBLAddBounce(first,float3((float)(i%7)*.2f,.3f,.5f),depth);
  auto c=total.bounded_contribution_rgb;
  float fade=LUNAR_FLOWER_TLBLDepthFadeFactor(depth);
  auto ceiling=min(float3(.2f),float3(1)-source)*fade;
  check(total.bounds_valid>.5f&&c.x<=ceiling.x+.000001f&&c.y<=ceiling.y+.000001f&&c.z<=ceiling.z+.000001f,"secondary violated faded/channel/user bounds");
  check(c.x>=first.bounded_contribution_rgb.x&&c.y>=first.bounded_contribution_rgb.y&&c.z>=first.bounded_contribution_rgb.z,"secondary removed first-pass light");
  check(close(total.final_rgb,source+c)&&total.final_rgb.x<=1&&total.final_rgb.y<=1&&total.final_rgb.z<=1,"secondary changed source outside bounded addition");
  auto dropped=LUNAR_FLOWER_TLBLAddBounce(first,float3(0),depth);
  check(close(dropped.final_rgb,first.final_rgb),"dropped bounce changed existing source/color/first light");
 }
 // A zero retention or strength skips sampling. Mask/provider-only views also
 // skip the extra fields; the uncertainty view evaluates no depth or lighting.
 LUNAR_FLOWER_TwinLanternsBounceLabBounceRetention=0;reset();
 check(close(LUNAR_FLOWER_TLBLBounce_PS(position,uv),float4(0,0,0,0))&&depthSamples==0&&firstReads==0,"zero retention did sampling work");
 LUNAR_FLOWER_TwinLanternsBounceLabBounceRetention=.5f;
 for(int view: {1,14,15,25,29}){
  LUNAR_FLOWER_TwinLanternsBounceLabView=view;reset();
  LUNAR_FLOWER_TLBLRaw_PS(position,uv);LUNAR_FLOWER_TLBLResolveH_PS(position,uv);LUNAR_FLOWER_TLBLResolveV_PS(position,uv);
  LUNAR_FLOWER_TLBLFirstLight_PS(position,uv);LUNAR_FLOWER_TLBLBounce_PS(position,uv);
  check(depthSamples==0&&firstReads==0&&bounceReads==0&&imageReads==0&&colorSamples==0,"non-field diagnostic performed working-pass sampling");
  if(view==29){auto mask=LUNAR_FLOWER_TLBLDisplay_PS(position,uv);check(close(mask.rgb(),float3(1))&&depthSamples==0&&firstReads==0&&bounceReads==0,"zero-loss chaos mask not white or sampled fields");}
 }
 LUNAR_FLOWER_TwinLanternsBounceLabView=0;
 float target=0,fidelity=0,pressure=0;float3 fill(0);
 auto first=LUNAR_FLOWER_TLBLEvaluateFirstComposite(uv,target,fill,fidelity,pressure);
 firstField=LUNAR_FLOWER_TLBLFirstLight_PS(position,uv);
 check(close(firstField.rgb(),first.bounded_contribution_rgb),"first capture did not contain actual bounded added light");
 bounceField=LUNAR_FLOWER_TLBLBounce_PS(position,uv);
 auto total=LUNAR_FLOWER_TLBLEvaluateComposite(uv,target,fill,fidelity,pressure);
 auto final=LUNAR_FLOWER_TLBLDisplay_PS(position,uv);
 check(close(final.rgb(),total.final_rgb)&&total.bounds_valid>.5f,"final display omitted bounded second bounce");
 check(total.final_rgb.x>=first.final_rgb.x&&total.final_rgb.y>=first.final_rgb.y&&total.final_rgb.z>=first.final_rgb.z,"captured/gathered path darkened first light");
 for(int view: {26,27,28,30}){
  LUNAR_FLOWER_TwinLanternsBounceLabView=view;
  auto diagnostic=LUNAR_FLOWER_TLBLDisplay_PS(position,uv);
  if(view==26)check(close(diagnostic.rgb(),saturate(firstField.rgb()*8)),"first-field diagnostic mapping/gain incorrect");
  if(view==27)check(close(diagnostic.rgb(),saturate(bounceField.rgb()*8)),"bounce signal diagnostic mapping/gain incorrect");
  if(view==28)check(close(diagnostic.rgb(),saturate((total.bounded_contribution_rgb-first.bounded_contribution_rgb)*8)),"applied-extra diagnostic mapping/gain incorrect");
  if(view==30)check(close(diagnostic.rgb(),float3(bounceField.a)),"support diagnostic mapping incorrect");
 }
 std::cout<<"PASS: "<<assertions<<" Bounce Lab CPU assertions; baseline, energy loss, deterministic dropout, color anchor, bounds and field views\n";
}catch(const std::exception& e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}}
'''


class BounceLabTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('c++'), 'requires C++17 CPU fixture compiler')
    def test_actual_bounce_shader(self):
        with patch.object(cpu, 'BASE', SHADERS):
            source = cpu.shader_cpp(2560, 1440, cases='', textures=parent.TEXTURES)
        source = source.replace('struct float4 {', 'struct float4 {\n float4()=default;')
        source, replaced = re.subn(
            r'float4 tex2Dlod\(int, float4 coords\)\s*\{[^{}]+\}', FIELDS, source)
        self.assertEqual(replaced, 1, 'CPU source-color shim was not replaced exactly once')
        parent_helper = (parent.SHADERS / 'api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh').read_text()
        source += translate(parent_helper) + parent.effect_cpp()
        source += '\nfloat3 operator-(float3 a){return float3(0)-a;}\n'
        source += effect_cpp()
        values = json.loads((parent.BUILD / 'DEFAULTS.json').read_text())['defaults']
        assignments = '\n'.join(k + '=' + k.replace('TwinLanternsDirectionLab', 'TwinLanternsBounceLab') + ';' for k in values)
        source += CASES.replace('MATCH_PARENT', assignments)
        with tempfile.TemporaryDirectory(prefix='tl-bounce-lab-') as tmp:
            path = Path(tmp) / 'fixture.cpp'
            path.write_text(source)
            exe = Path(tmp) / 'fixture'
            result = subprocess.run(['c++', '-std=c++17', '-O2', str(path), '-o', str(exe)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(exe)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout, end='')

    def test_source_fields_and_independent_resources(self):
        payload = validate_source()
        self.assertEqual(len(payload), 10)
        old = {str(p): p.read_bytes() for p in parent.SHADERS.rglob('*') if p.is_file()}
        self.assertFalse(texture_names(payload) & texture_names(old))
        lineage = json.loads((BUILD / 'SOURCE_LINEAGE.json').read_text())['files']
        self.assertEqual(sum(i['byte_identical'] for i in lineage), 8)

    def test_secondary_gradient_regression_is_detected(self):
        texts = sources(SHADERS)
        effect = next(n for n in texts if n.endswith('_BounceLab.fx'))
        safe = 'tex2Dlod(LUNAR_FLOWER_TLBLFirstLightSampler, float4(hitUv, 0.0, 0.0))'
        self.assertIn(safe, texts[effect])
        texts[effect] = texts[effect].replace(safe, 'tex2D(LUNAR_FLOWER_TLBLFirstLightSampler, hitUv)')
        failures = audit(texts, entrypoints=('LUNAR_FLOWER_TLBLBounce_PS',))
        self.assertTrue(any('AccumulateBounceHit -> tex2D' in f for f in failures), failures)

    def test_reproducible_package_and_isolated_presets(self):
        with tempfile.TemporaryDirectory(prefix='tl-bounce-package-') as tmp:
            a, b = Path(tmp) / 'a.zip', Path(tmp) / 'b.zip'
            manifest = package(a)
            package(b)
            self.assertEqual(a.read_bytes(), b.read_bytes())
            with ZipFile(a) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual([n for n in archive.namelist() if n.endswith('.fx')], [EFFECT])
                for name, sha in manifest['files'].items():
                    self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), sha)
                self.assertFalse(manifest['temporal_history'])
                self.assertFalse(manifest['final_image_feedback'])
                values = []
                for name, data in presets().items():
                    self.assertEqual(archive.read(name), data)
                    cfg = configparser.ConfigParser(interpolation=None)
                    cfg.optionxform = str
                    cfg.read_string('[PRESET]\n' + data.decode())
                    self.assertEqual(len(cfg['PRESET']['Techniques'].split(',')), 1)
                    values.append(dict(cfg[Path(EFFECT).name]))
                reference, bounce, broken = values
                self.assertEqual(reference[PREFIX + 'BounceStrength'], '0')
                self.assertEqual([k for k in reference if reference[k] != bounce[k]], [PREFIX + 'BounceStrength'])
                self.assertEqual([k for k in bounce if bounce[k] != broken[k]], [PREFIX + 'ChaosAmount'])


if __name__ == '__main__':
    unittest.main()
