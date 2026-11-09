"""CPU fixtures execute the adaptive voxel shader with bounded texture shims.

They exercise hierarchy construction and actual trace functions. They are not
native ReShade compilation, GPU parity, or timing measurements.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from test_twin_lantern_screen_surface import BASE, shader_cpp


TEXTURES = r'''
int voxelFixture=0;
float voxelCut=32.28f/64;
float thinSurfaceOffset=.1f;
int depthSamples=0,colorSamples=0;
float2 lastColorUv(0,0);
float2 lastDepthUv(0,0);
float CAMERA_OBSCURA_LoadDepth(float2 uv){
 ++depthSamples;uv=saturate(uv);lastDepthUv=uv;
 if(voxelFixture==9){
  float left=(18+thinSurfaceOffset)/36;
  return uv.y>left&&uv.y<left+.2f/36?.401f+.16f*(uv.x-32.2f/64):.4f;
 }
 if(voxelFixture==1)return uv.x<voxelCut?.4f:.8f;
 if(voxelFixture==6)return uv.x<voxelCut?.002f:.00204f;
 if(voxelFixture==7)return uv.x<voxelCut?1.f:.4f;
 if(voxelFixture==8)return .4f+.2f*uv.x+.1f*uv.y;
 if(voxelFixture==3)return 1;
 if(voxelFixture==4){
   float d=length((uv-float2(.5f,.5f))/CAMERA_OBSCURA_PixelSize());
   return d<1.4f?.4f:.8f;
 }
 return .4f;
}
float3 CAMERA_OBSCURA_LoadColor(float2 uv){
 ++colorSamples;lastColorUv=uv;
 if(voxelFixture==2)return uv.x<voxelCut?float3(.1f,.2f,.3f):float3(.8f,.2f,.3f);
 if(voxelFixture==5)return float3(.2f+uv.x*.2f,.4f,.6f);
 return float3(.6f,.4f,.2f);
}
'''

SHIMS = r'''
#include <vector>
struct int2 {
 int x,y;
 int2(int a,int b):x(a),y(b){}
 template<typename V> int2(V v):x((int)v.x),y((int)v.y){}
};
struct int3 {
 int x,y,z;
 int3(int a,int b,int c):x(a),y(b),z(c){}
 int3(int2 a,int b):x(a.x),y(a.y),z(b){}
 int2 xy()const{return int2(x,y);}
};
using uint3=int3;
float2 min(float2 a,float2 b){return {min(a.x,b.x),min(a.y,b.y)};}
int LUNAR_FLOWER_TLAdaptiveAtlasV1Storage=0;
int LUNAR_FLOWER_TLAdaptiveAtlasV1Sampler=0;
std::vector<float4> nodes(64*36*21,float4(0,0,0,0));
int nodeWrites=0,nodeReads=0;
int indexOf(int3 cell){
 if(cell.x<0||cell.x>=64||cell.y<0||cell.y>=36||cell.z<0||cell.z>=21)
     throw std::runtime_error("out-of-bounds hierarchy access");
 return (cell.z*36+cell.y)*64+cell.x;
}
void tex3Dstore(int,int3 cell,float4 value){++nodeWrites;nodes[indexOf(cell)]=value;}
float4 tex3Dfetch(int,int3 cell){++nodeReads;return nodes[indexOf(cell)];}
'''

CASES = r'''
int assertions=0;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);++assertions;}
bool close(float a,float b){return abs(a-b)<.00001f;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
void buildAll(){
 depthSamples=0;colorSamples=0;nodeWrites=0;
 for(int y=0;y<36;++y)for(int x=0;x<64;++x)
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(x,y,0));
 check(nodeWrites<=64*36*42,"hierarchy exceeded bounded node budget");
}
int main(){
 try{
  voxelFixture=0;buildAll();
  check(nodeWrites==64*36*22,"uniform scene built unnecessary child nodes");
  check(depthSamples==64*36*5,"uniform node depth sample budget changed");
  check(colorSamples==64*36*5,"uniform node color sample budget changed");
  float level=-1;
  auto uniform=LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(.5f,.5f),level);
  check(level==0&&close(uniform.a,.4f),"uniform scene failed to remain coarse");
  int before=nodeWrites;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(64,0,0));
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(0,36,0));
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(0,0,1));
  check(before==nodeWrites,"out-of-dispatch thread wrote hierarchy");
  voxelFixture=1;buildAll();
  auto foreground=LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(32.2f/64,18.2f/36),level);
  check(level==2&&close(foreground.a,.4f),"depth edge failed to refine foreground");
  auto background=LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(32.4f/64,18.2f/36),level);
  check(level==2&&close(background.a,.8f),"depth edge failed to retain background");
  LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(32.8f/64,18.2f/36),level);
  check(level==1,"uniform sibling was unnecessarily refined");
  LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(30.2f/64,18.2f/36),level);
  check(level==0,"unrelated uniform root was unnecessarily refined");
  voxelFixture=2;buildAll();
  LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(32.2f/64,18.2f/36),level);
  check(level==2,"color edge failed to trigger subdivision");
  voxelFixture=6;buildAll();
  LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(32.2f/64,18.2f/36),level);
  check(level==2,"near-depth detail was lost under an absolute subdivision threshold");
  voxelFixture=7;buildAll();
  auto skyEdge=LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(32.2f/64,18.2f/36),level);
  check(level==2&&skyEdge.a==0,"mixed sky boundary failed to refine or acquired occupancy");
  auto geometryEdge=LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(32.4f/64,18.2f/36),level);
  check(level==2&&geometryEdge.a>0,"mixed sky boundary lost geometry");
  voxelFixture=8;buildAll();
  check(nodeWrites==64*36*42,"worst-case hierarchy failed to use all bounded records");
  for(int y=0;y<4;++y)for(int x=0;x<4;++x){
   float2 p((32+(x+.5f)*.25f)/64,(18+(y+.5f)*.25f)/36);
   auto node=LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(p,level);
   float actual=CAMERA_OBSCURA_LoadDepth(p);
   check(level==2&&node.x<=actual&&actual<=node.y,"leaf indexing or sloped depth bounds failed");
  }
  voxelFixture=0;buildAll();
  for(int y=0;y<36;++y)for(int x=0;x<64;++x)for(int z=1;z<21;++z){
   auto node=nodes[indexOf(int3(x,y,z))];
   check(node.a==0&&close(node.rgb(),float3(0)),"collapsed tile retained stale child record");
  }
  LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(1,1),level);
  LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(float2(-1,-1),level);
  // Change metadata to a color-like value. It must never be used as donor RGB.
  for(auto& node:nodes)if(node.a>0)node.z=.99f;
  voxelFixture=5;colorSamples=0;
  auto fine=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2(.5f,.5f),0,24,.16f,.0005f,.0035f,32);
  check(fine.hit==1&&fine.evidence>0&&fine.evidence<=1,"fine trace lost valid donor");
  check(fine.normalized_distance*24>1.5f,"voxel trace accepted self sample");
  check(fine.normalized_distance<=1,"voxel trace exceeded requested travel");
  check(colorSamples==1,"trace did not fetch one fine-resolution donor color");
  check(close(fine.radiance_rgb,float3(.2f+lastColorUv.x*.2f,.4f,.6f)),"trace copied coarse cell color");
  check(!close(fine.radiance_rgb,float3(.4f,.4f,.99f)),"node metadata reached final lighting as RGB");
  // Coarse support alone must not authorize light through a different fine depth.
  voxelFixture=4;colorSamples=0;
  auto mismatch=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2(.5f,.5f),0,24,.16f,.0005f,.0035f,32);
  check(mismatch.hit==0&&mismatch.evidence==0,"coarse node overrode incompatible full-resolution depth");
  check(colorSamples==0,"rejected depth fetched a donor color");
  auto range=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2(.5f,.5f),0,24,0,.0005f,.0035f,32);
  float rangePixels=length((lastDepthUv-float2(.5f,.5f))/CAMERA_OBSCURA_PixelSize());
  check(range.hit==0&&abs(rangePixels-24)<.002f,"32 requested steps overshot actual ray budget");
  voxelFixture=3;buildAll();
  auto sky=LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(float2(.5f,.5f));
  check(sky.a==0,"sky acquired proxy occupancy");
  auto skyTrace=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2(.5f,.5f),0,24,.16f,.0005f,.0035f,32);
  check(skyTrace.hit==0&&skyTrace.evidence==0,"sky emitted voxel light");
  std::cout<<"PASS: "<<assertions<<" adaptive hierarchy assertions; refinement, stale-node clearing, fine shading, depth rejection and bounds.\n";
 }catch(const std::exception& error){std::cerr<<"FAIL: "<<error.what()<<"\n";return 1;}
}
'''


def voxel_cpp(width, height, dda_limit=32, cases=None):
    voxel = (BASE / 'api/LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh').read_text()
    # Resource declarations become the explicit bounded CPU storage above.
    voxel = re.sub(r'^(?:texture3D|storage3D|sampler3D)\s+\w+\s*\{.*?^\};', '', voxel, flags=re.M | re.S)
    voxel = voxel.replace('[shader("compute")]', '').replace('[loop]', '')
    voxel = voxel.replace(' : SV_DispatchThreadID', '').replace('out float level', 'float& level')
    voxel = voxel.replace('.rgb', '.rgb()').replace('id.xy', 'id.xy()')
    voxel = re.sub(r'\b(\d+\.\d+)\.xxx', r'float3(\1)', voxel)
    voxel = re.sub(r'\b(\d+\.\d+)(?![\w.])', r'\1f', voxel)
    core = shader_cpp(width, height, cases='', textures=TEXTURES)
    core = core.replace('#define CAMERA_OBSCURA_DDA_MAX_STEPS 32', f'#define CAMERA_OBSCURA_DDA_MAX_STEPS {dda_limit}')
    core = core.replace('float2():x(0),y(0){}', 'float2():x(0),y(0){} template<typename V> float2(V v):x((float)v.x),y((float)v.y){}')
    core = core.replace('float3 rgb()const', 'float2 xy()const{return {x,y};} float3 rgb()const')
    proof = (BASE / 'api/CAMERA_OBSCURA_API_TwinLanternProviderProofCommon.fxh').read_text()
    # Only the shared receiver/ray builders are needed in addition to the core.
    from test_twin_lantern_screen_surface import block
    for token in ['CAMERA_OBSCURA_SurfaceGuide CAMERA_OBSCURA_API_BuildTL45Receiver(',
                  'CAMERA_OBSCURA_Ray CAMERA_OBSCURA_API_BuildTL45Ray(']:
        function = block(proof, token)
        function = re.sub(r'out (CAMERA_OBSCURA_\w+) (\w+)', r'\1& \2', function)
        core += function + '\n'
    core = core.replace('CAMERA_OBSCURA_API_TL45_INPUT_LIVE', '0.0f')
    core += '#define CAMERA_OBSCURA_API_TL45_INPUT_LIVE 0.0f\n'
    return core + SHIMS + voxel + (CASES if cases is None else cases)


TILE_ADMISSION_CASES = r'''
int main(){
 try{
  voxelFixture=9;
  float firstEvidence=-1;
  bool sawCoarse=false,sawFine=false;
  int assertions=0;
  for(int placement=0;placement<=20;++placement){
   thinSurfaceOffset=(float)placement*.025f;
   float2 uv(32.2f/64,(18+thinSurfaceOffset+.1f)/36);
   for(int y=0;y<36;++y)for(int x=0;x<64;++x)
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(x,y,0));
   float level=0;
   LUNAR_FLOWER_API_LoadTwinLanternVoxelNode(uv,level);
   sawCoarse=sawCoarse||level==0;sawFine=sawFine||level>0;
   auto receiver=LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
   nodeReads=0;
   auto hit=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxyWithReceiver(
    uv,0,LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaRayLengthPixels,
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthSlope,
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaFrontBias,
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBackThickness,
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelTraceSteps,receiver);
   if(hit.hit!=1||hit.evidence<=0)throw std::runtime_error("tile probe missed a valid fine-depth donor at default settings");
   if(nodeReads!=0)throw std::runtime_error("transport still reads sparse atlas metadata");
   if(firstEvidence<0)firstEvidence=hit.evidence;
   if(abs(firstEvidence-hit.evidence)>.00001f)throw std::runtime_error("light changed with sparse probe placement");
   auto surface=LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(uv);
   if(surface.a!=1)throw std::runtime_error("sparse atlas rejected valid fine surface diagnostic");
   auto raw=LUNAR_FLOWER_TLFRRaw_PS(float4(0,0,0,1),uv);
   if(raw.a<=0)throw std::runtime_error("default effect lost transport evidence");
   // Keep the exact UV fixed here: the independent screen provider may
   // legitimately vary with screen-space jitter at different UVs.
   for(auto& node:nodes)node=float4(0,0,0,0);
   nodeReads=0;
   auto withoutAtlas=LUNAR_FLOWER_TLFRRaw_PS(float4(0,0,0,1),uv);
   if(nodeReads!=0||abs(raw.a-withoutAtlas.a)>.00001f||length(raw.rgb()-withoutAtlas.rgb())>.00001f)
    throw std::runtime_error("diagnostic atlas changed default raw lighting");
   assertions+=6;
  }
  if(!sawCoarse||!sawFine)throw std::runtime_error("fixture did not exercise coarse/fine transitions");
  std::cout<<"PASS: "<<assertions+1<<" tile-admission assertions at defaults; 21 camera placements, coarse/fine transitions, empty atlas and full raw transport.\n";
 }catch(const std::exception& error){std::cerr<<"FAIL: "<<error.what()<<"\n";return 1;}
}
'''


class AdaptiveVoxelTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('c++'), 'CPU fixture requires a C++17 compiler')
    def test_camera_shift_does_not_gate_fine_depth_with_sparse_tiles(self):
        from test_twin_lantern_inactive_work import effect_cpp
        for width,height in [(1280,720),(2560,1440),(3840,2160)]:
            with self.subTest(resolution=(width,height)), tempfile.TemporaryDirectory(prefix='tl-tile-admission-') as folder:
                source=Path(folder)/'fixtures.cpp'
                source.write_text(voxel_cpp(width,height,cases=effect_cpp()+TILE_ADMISSION_CASES))
                exe=Path(folder)/'fixtures'
                result=subprocess.run(['c++','-std=c++17','-O2',str(source),'-o',str(exe)],text=True,capture_output=True)
                self.assertEqual(0,result.returncode,result.stderr)
                result=subprocess.run([str(exe)],text=True,capture_output=True)
                self.assertEqual(0,result.returncode,result.stdout+result.stderr)
                print(result.stdout,end='')

    @unittest.skipUnless(shutil.which('c++'), 'CPU fixture requires a C++17 compiler')
    def test_shader_extracted_adaptive_hierarchy(self):
        for width,height,dda_limit in [(1280,720,32),(2560,1440,32),(3840,2160,32),(2560,1440,24)]:
            with self.subTest(resolution=(width,height),dda_limit=dda_limit), tempfile.TemporaryDirectory(prefix='tl-adaptive-fixtures-') as folder:
                source=Path(folder)/'fixtures.cpp';source.write_text(voxel_cpp(width,height,dda_limit))
                exe=Path(folder)/'fixtures'
                result=subprocess.run(['c++','-std=c++17','-O2',str(source),'-o',str(exe)],text=True,capture_output=True)
                self.assertEqual(0,result.returncode,result.stderr)
                result=subprocess.run([str(exe)],text=True,capture_output=True)
                self.assertEqual(0,result.returncode,result.stdout+result.stderr)
                print(result.stdout,end='')


if __name__ == '__main__':
    unittest.main()
