"""Compile shader-extracted functions as C++ for bounded CPU regression fixtures.

Vector types/intrinsics and texture reads are CPU shims. This is not ReShade
compilation, GPU parity, or visual acceptance. Requires a C++17 compiler.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/reshade-shaders/Shaders/camera_obscura'


def block(source, token):
    start = source.index(token)
    brace = source.index('{', start)
    end, depth = brace + 1, 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


def shader_cpp(width=64, height=64, cases=None):
    source = CPP_SHIMS.replace(
        '#define BUFFER_RCP_WIDTH (1.f/64.f)', f'#define BUFFER_RCP_WIDTH (1.f/{width}.f)'
    ).replace(
        '#define BUFFER_RCP_HEIGHT (1.f/64.f)', f'#define BUFFER_RCP_HEIGHT (1.f/{height}.f)'
    )
    common = (BASE / 'header/CAMERA_OBSCURA_AtomicCommon.fxh').read_text()
    source += common
    source += CPP_TEXTURES
    cap = (BASE / 'header/CAMERA_OBSCURA_EntryCapability.fxh').read_text()
    for token in ['CAMERA_OBSCURA_RayRequest CAMERA_OBSCURA_DefaultRayRequest(',
                  'CAMERA_OBSCURA_TraceControls CAMERA_OBSCURA_BuildTraceControls(',
                  'CAMERA_OBSCURA_Ray CAMERA_OBSCURA_BuildRayC0(']:
        source += block(cap, token) + '\n'
    proof = (BASE / 'api/CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh').read_text()
    source += block(proof, 'float2 CAMERA_OBSCURA_API_TL45Direction(') + '\n'
    for path in ['header/CAMERA_OBSCURA_EntryTraversal.fxh',
                 'api/CAMERA_OBSCURA_API_TwinLanternReconstruction.fxh',
                 'api/CAMERA_OBSCURA_API_TwinLanternComposite.fxh']:
        source += re.sub(r'^#include.*$', '', (BASE / path).read_text(), flags=re.M)
    old = (BASE / 'api/CAMERA_OBSCURA_API_TwinLanternTransport.fxh').read_text()
    source += block(old, 'struct CAMERA_OBSCURA_API_TL07ProviderSample') + ';\n'
    for token in ['CAMERA_OBSCURA_API_TL07ProviderSample\nCAMERA_OBSCURA_API_DefaultTL07ProviderSample(',
                  'CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_BuildTL07DonorGuide(',
                  'CAMERA_OBSCURA_API_TL07ProviderSample\nCAMERA_OBSCURA_API_BuildTL07ProviderSample(']:
        source += block(old, token) + '\n'
    source += (BASE / 'api/LUNAR_FLOWER_TwinLanternScreenSurface.fxh').read_text()
    source = re.sub(r'\[(?:branch|loop)\]', '', source)
    source = source.replace('.rgb', '.rgb()')
    source = re.sub(r'\b(\d+\.\d+)\.xxx', r'float3(\1)', source)
    source = re.sub(r'\b(\w+)\.xxx', r'float3(\1)', source)
    source = re.sub(r'\b(\d+\.\d+)(?![\w.])', r'\1f', source)
    return source + (CPP_CASES if cases is None else cases)


CPP_SHIMS = r'''
#include <cmath>
#include <algorithm>
#include <iostream>
#include <stdexcept>
using std::abs; using std::floor;
float min(float a,float b){return a<b?a:b;} int min(int a,int b){return a<b?a:b;}
float max(float a,float b){return a>b?a:b;} int max(int a,int b){return a>b?a:b;}
float clamp(float x,float a,float b){return min(max(x,a),b);}
float saturate(float x){return clamp(x,0,1);}
float step(float e,float x){return x>=e?1:0;}
float frac(float x){return x-floor(x);}
float lerp(float a,float b,float t){return a+(b-a)*t;}
struct float2 {
 float x,y;
 float2():x(0),y(0){} float2(float a,float b):x(a),y(b){}
 float2& operator/=(float d){x/=d;y/=d;return *this;}
};
float2 operator+(float2 a,float2 b){return {a.x+b.x,a.y+b.y};}
float2 operator-(float2 a,float2 b){return {a.x-b.x,a.y-b.y};}
float2 operator*(float2 a,float b){return {a.x*b,a.y*b};}
float2 operator/(float2 a,float b){return {a.x/b,a.y/b};}
float2 operator*(float2 a,float2 b){return {a.x*b.x,a.y*b.y};}
float2 operator/(float2 a,float2 b){return {a.x/b.x,a.y/b.y};}
float2 max(float2 a,float2 b){return {max(a.x,b.x),max(a.y,b.y)};}
float dot(float2 a,float2 b){return a.x*b.x+a.y*b.y;}
float length(float2 a){return std::sqrt(dot(a,a));}
float2 floor(float2 a){return {std::floor(a.x),std::floor(a.y)};}
float2 saturate(float2 a){return {saturate(a.x),saturate(a.y)};}
struct float3 {
 union {struct {float x,y,z;};struct {float r,g,b;};};
 float3():x(0),y(0),z(0){} float3(float a):x(a),y(a),z(a){}
 float3(float a,float b,float c):x(a),y(b),z(c){}
};
float3 operator+(float3 a,float3 b){return {a.x+b.x,a.y+b.y,a.z+b.z};}
float3 operator-(float3 a,float3 b){return {a.x-b.x,a.y-b.y,a.z-b.z};}
float3 operator*(float3 a,float b){return {a.x*b,a.y*b,a.z*b};}
float3 saturate(float3 a){return {saturate(a.x),saturate(a.y),saturate(a.z)};}
float3 min(float3 a,float3 b){return {min(a.x,b.x),min(a.y,b.y),min(a.z,b.z)};}
float3 max(float3 a,float3 b){return {max(a.x,b.x),max(a.y,b.y),max(a.z,b.z)};}
float3 abs(float3 a){return {abs(a.x),abs(a.y),abs(a.z)};}
float dot(float3 a,float3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
float3 normalize(float3 a){return a*(1/std::sqrt(dot(a,a)));}
struct float4 {
 float x,y,z,a;
 float4(float r,float g,float b,float w):x(r),y(g),z(b),a(w){}
 float4(float3 c,float w):x(c.x),y(c.y),z(c.z),a(w){}
 float3 rgb()const{return {x,y,z};}
};
#define BUFFER_RCP_WIDTH (1.f/64.f)
#define BUFFER_RCP_HEIGHT (1.f/64.f)
#define CAMERA_OBSCURA_DDA_MAX_STEPS 32
'''

CPP_TEXTURES = r'''
int fixture=0;
float specialCut=.5f;
float fixtureDepth=.4f;
float3 color(.8f,.4f,.2f);
float CAMERA_OBSCURA_LoadDepth(float2 uv){
 uv=saturate(uv);
 int x=min((int)floor(uv.x*64),63);
 if(fixture==1) return x<32?.4f:.8f;
 if(fixture==2) return .3f+.001f*x;
 if(fixture==3) return 0;
 if(fixture==4) return uv.x<specialCut?0.f:fixtureDepth;
 if(fixture==5) return uv.x<specialCut?.403f:.401f;
 return .4f;
}
float3 CAMERA_OBSCURA_LoadColor(float2){return color;}
'''

CPP_CASES = r'''
int count=0;
void check(bool ok,const char* why){if(!ok) throw std::runtime_error(why);++count;}
bool close(float a,float b){return abs(a-b)<.00001f;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
int main(){
 try{
  float2 donorUV(31.5f/64,32.5f/64), receiverUV(28.5f/64,32.5f/64);
  auto ray=CAMERA_OBSCURA_Ray{};ray.valid=1;ray.origin_uv=receiverUV;
  auto hit=CAMERA_OBSCURA_MakeMiss(1,0);hit.hit=1;hit.confidence=1;hit.uv=donorUV;
  fixture=0;
  auto flat=LUNAR_FLOWER_TLFRBuildSurfaceGuide(donorUV);
  check(close(flat.normal,float3(0,0,1)),"flat normal");
  auto oldFlat=CAMERA_OBSCURA_API_BuildTL07ProviderSample(ray,flat,hit,24);
  auto newFlat=LUNAR_FLOWER_TLFRSampleScreenDonor(ray,flat,hit,24,1.5f);
  check(close(oldFlat.raw_weight,newFlat.a),"flat donor weight changed");
  check(close(oldFlat.donor_rgb,newFlat.rgb()),"flat donor color changed");
  fixture=1;
  auto edge=LUNAR_FLOWER_TLFRBuildSurfaceGuide(donorUV);
  auto receiver=LUNAR_FLOWER_TLFRBuildSurfaceGuide(receiverUV);
  auto oldGuide=CAMERA_OBSCURA_API_BuildTL07DonorGuide(donorUV);
  auto oldSample=CAMERA_OBSCURA_API_BuildTL07ProviderSample(ray,receiver,hit,24);
  auto newSample=LUNAR_FLOWER_TLFRSampleScreenDonor(ray,receiver,hit,24,1.5f);
  check(oldGuide.depth_confidence==0&&oldSample.raw_weight==0,"old edge hole not reproduced");
  check(close(edge.normal,float3(0,0,1)),"foreground edge acquired cross-object normal");
  check(close(newSample.a,.875f),"foreground edge failed to retain valid donor weight");
  check(close(newSample.rgb(),color),"foreground color changed");
  auto same=LUNAR_FLOWER_TLFRBuildSurfaceGuide(float2(30.5f/64,32.5f/64));
  auto other=LUNAR_FLOWER_TLFRBuildSurfaceGuide(float2(32.5f/64,32.5f/64));
  check(close(CAMERA_OBSCURA_API_TL08DepthSupport(edge,same,.005f),1),"same surface rejected");
  check(close(CAMERA_OBSCURA_API_TL08NormalSupport(edge,same,.8f),1),"same surface normal rejected");
  check(CAMERA_OBSCURA_API_TL08DepthSupport(edge,other,.005f)==0,"cross-depth resolve leak");
  check(close(other.normal,float3(0,0,1)),"background edge acquired cross-object normal");
  auto filtered=CAMERA_OBSCURA_API_ResolveTL08Axis(float4(color,.8f),float4(color,.8f),
      float4(float3(1,0,0),1),same,edge,other,1,1,.005f,.8f,0);
  check(close(filtered.resolved_rgb,color),"rejected red background contaminated resolve");
  fixture=2;
  auto ramp=LUNAR_FLOWER_TLFRBuildSurfaceGuide(donorUV);
  check(close(ramp.normal,normalize(float3(-.001f,0,2.f/64))),"continuous ramp normal changed");
  fixture=3;
  auto invalid=LUNAR_FLOWER_TLFRBuildSurfaceGuide(donorUV);
  check(invalid.valid==0,"invalid depth accepted");
  check(LUNAR_FLOWER_TLFRSampleScreenDonor(ray,receiver,hit,24,1.5f).a==0,"invalid donor accepted");
  fixture=0;
  hit.hit=0;
  check(LUNAR_FLOWER_TLFRSampleScreenDonor(ray,flat,hit,24,1.5f).a==0,"miss invented light");
  hit.hit=1;ray.valid=0;
  check(LUNAR_FLOWER_TLFRSampleScreenDonor(ray,flat,hit,24,1.5f).a==0,"invalid ray invented light");
  ray.valid=1;color=float3(0);
  auto black=LUNAR_FLOWER_TLFRSampleScreenDonor(ray,flat,hit,24,1.5f);
  check(black.a>0&&close(black.rgb(),float3(0)),"valid black donor misclassified");
  color=float3(.8f,.4f,.2f);
  for(int d=0;d<8;++d){
   auto screen=LUNAR_FLOWER_TLFRTraceScreen(float2(.5f,.5f),(float)d,24,0,.0005f,.0035f);
   check(screen.a>0&&screen.a<=1,"screen trace evidence invalid");
   check(close(screen.rgb(),color),"screen trace normalized color changed");
  }
  for(int i=0;i<=10;++i)for(int j=0;j<=10;++j)for(int k=0;k<=10;++k){
   float3 original((float)i/10,(float)j/10,(float)k/10);
   auto result=CAMERA_OBSCURA_API_BuildTL09Composite(original,color,.9f,1,1,12,.2f);
   auto delta=result.final_rgb-original;
   check(delta.x>=0&&delta.y>=0&&delta.z>=0,"composite darkens source");
   check(result.final_rgb.x<=1&&result.final_rgb.y<=1&&result.final_rgb.z<=1,"composite exceeds room");
   check(delta.x<=.20001f&&delta.y<=.20001f&&delta.z<=.20001f,"composite exceeds ceiling");
   auto off=CAMERA_OBSCURA_API_BuildTL09Composite(original,color,.9f,1,0,12,.2f);
   check(close(off.final_rgb,original),"disabled composite changed source");
  }
  std::cout<<"PASS: "<<count<<" CPU assertions; old contour reproduced, same-surface support restored, depth step rejected, composite bounded.\n";
 }catch(const std::exception& error){std::cerr<<"FAIL: "<<error.what()<<"\n";return 1;}
}
'''


CPP_REFINEMENT_CASES = r'''
int count=0;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);++count;}
float distancePx(float2 a,float2 b){return length((a-b)/CAMERA_OBSCURA_PixelSize());}
int main(){
 try{
  int oldViolations=0;
  float2 uv(.5f,.5f);
  CAMERA_OBSCURA_Ray savedRay{};
  CAMERA_OBSCURA_TraceControls savedControls{};
  for(int d=0;d<8;++d){
   fixture=0;
   auto receiver=LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
   auto travel=CAMERA_OBSCURA_API_TL45Direction((float)d)*24*CAMERA_OBSCURA_PixelSize();
   auto request=CAMERA_OBSCURA_DefaultRayRequest(travel);
   request.ray_length_uv=length(travel);request.ray_depth_slope=.16f;request.requested_steps=32;
   auto controls=CAMERA_OBSCURA_BuildTraceControls(request);
   auto ray=CAMERA_OBSCURA_BuildRayC0(uv,receiver,request,controls);
   savedRay=ray;savedControls=controls;
   for(int backend=0;backend<2;++backend){
    auto activeControls=controls;
    if(backend)activeControls.spatial_phase=1;
    auto coarse=backend?CAMERA_OBSCURA_TraceMarch(ray,activeControls):CAMERA_OBSCURA_TraceDDA(ray,activeControls);
    check(coarse.hit>0.5f,"fixture needs a valid coarse donor");
    auto legacy=CAMERA_OBSCURA_RefineHit(ray,coarse,activeControls);
    if(distancePx(legacy.uv,uv)<=controls.self_hit_pixels)++oldViolations;
    auto corrected=LUNAR_FLOWER_TLFRRefineScreenHit(ray,coarse,activeControls);
    check(corrected.hit>0.5f,"valid coarse fallback lost");
    check(distancePx(corrected.uv,uv)>controls.self_hit_pixels,"refinement crossed self exclusion");
    check(distancePx(corrected.uv,uv)<=distancePx(coarse.uv,uv)+.002f,"refinement extended beyond coarse hit");
    auto donor=LUNAR_FLOWER_TLFRSampleScreenDonor(ray,receiver,corrected,24,controls.self_hit_pixels);
    check(donor.a>0,"valid nearby donor lost contribution");
    auto unsafe=corrected;unsafe.uv=uv+CAMERA_OBSCURA_API_TL45Direction((float)d)*CAMERA_OBSCURA_PixelSize();
    check(LUNAR_FLOWER_TLFRSampleScreenDonor(ray,receiver,unsafe,24,controls.self_hit_pixels).a==0,
       "final donor admission accepted self sample");
    check(LUNAR_FLOWER_TLFRRefineScreenHit(ray,unsafe,activeControls).hit==0,"invalid coarse self fallback accepted");
   }
  }
  check(oldViolations>0,"legacy self-hit defect not reproduced");
  auto ray=savedRay;auto controls=savedControls;
  ray.origin_depth=.0002f;ray.step_depth=0;
  auto coarse=CAMERA_OBSCURA_MakeMiss(CAMERA_OBSCURA_BACKEND_DDA,CAMERA_OBSCURA_REASON_HIT);
  coarse.hit=1;coarse.uv=uv+float2(4*BUFFER_RCP_WIDTH,0);
  coarse.previous_uv=uv+float2(2*BUFFER_RCP_WIDTH,0);
  coarse.scene_z=.0002f;coarse.ray_z=.0002f;coarse.previous_ray_z=.0002f;
  coarse.delta=0;coarse.confidence=1;
  fixture=4;fixtureDepth=.0002f;specialCut=uv.x+3.75f*BUFFER_RCP_WIDTH;
  auto oldInvalid=CAMERA_OBSCURA_RefineHit(ray,coarse,controls);
  check(oldInvalid.hit>0.5f&&oldInvalid.scene_z==0,"legacy invalid-depth midpoint not reproduced");
  auto fallback=LUNAR_FLOWER_TLFRRefineScreenHit(ray,coarse,controls);
  check(fallback.hit>0.5f&&fallback.scene_z==.0002f,"valid fallback lost after invalid midpoint");
  check(distancePx(fallback.uv,coarse.uv)<.001f,"invalid-depth midpoint replaced valid hit");
  auto invalidCoarse=coarse;invalidCoarse.scene_z=0;
  check(LUNAR_FLOWER_TLFRRefineScreenHit(ray,invalidCoarse,controls).hit==0,"invalid coarse depth accepted");
  invalidCoarse=coarse;invalidCoarse.uv=float2(1.1f,.5f);
  check(LUNAR_FLOWER_TLFRRefineScreenHit(ray,invalidCoarse,controls).hit==0,"off-screen coarse hit accepted");
  auto invalidRay=ray;invalidRay.valid=0;
  check(LUNAR_FLOWER_TLFRRefineScreenHit(invalidRay,coarse,controls).hit==0,"invalid ray accepted");
  auto miss=CAMERA_OBSCURA_MakeMiss(CAMERA_OBSCURA_BACKEND_DDA,CAMERA_OBSCURA_REASON_MAX_STEPS);
  check(LUNAR_FLOWER_TLFRRefineScreenHit(ray,miss,controls).hit==0,"refinement fabricated a hit");
  fixture=5;specialCut=uv.x+3.75f*BUFFER_RCP_WIDTH;
  coarse.scene_z=.401f;coarse.ray_z=.401f;coarse.previous_ray_z=.4f;coarse.delta=0;coarse.confidence=1;
  auto stale=CAMERA_OBSCURA_RefineHit(ray,coarse,controls);
  auto accurate=LUNAR_FLOWER_TLFRRefineScreenHit(ray,coarse,controls);
  check(stale.confidence==1,"legacy confidence floor not reproduced");
  check(accurate.hit>0.5f&&accurate.confidence<.5f,"selected hit retained stale confidence");
  std::cout<<"PASS: "<<count<<" refinement assertions; legacy violations="<<oldViolations
     <<"; corrected hits outside exclusion, invalid midpoints rejected, valid fallback retained.\n";
 }catch(const std::exception& error){std::cerr<<"FAIL: "<<error.what()<<"\n";return 1;}
}
'''


class ScreenSurfaceTests(unittest.TestCase):
    def run_cpp(self, source_text):
        with tempfile.TemporaryDirectory(prefix='tl-surface-fixtures-') as folder:
            source = Path(folder) / 'fixtures.cpp'
            source.write_text(source_text)
            executable = Path(folder) / 'fixtures'
            result = subprocess.run(['c++', '-std=c++17', '-O2', str(source), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            print(result.stdout, end='')

    @unittest.skipUnless(shutil.which('c++'), 'CPU fixture requires a C++17 compiler')
    def test_shader_extracted_surface_and_composite(self):
        self.run_cpp(shader_cpp())

    @unittest.skipUnless(shutil.which('c++'), 'CPU fixture requires a C++17 compiler')
    def test_refinement_exclusion_depth_and_fallback(self):
        for width, height in [(1280, 720), (2560, 1440), (3840, 2160)]:
            with self.subTest(resolution=(width, height)):
                self.run_cpp(shader_cpp(width, height, CPP_REFINEMENT_CASES))


if __name__ == '__main__':
    unittest.main()
