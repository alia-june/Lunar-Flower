"""CPU equivalence/read-count fixtures; GPU timings still require ReShade."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from test_twin_lantern_screen_surface import BASE, block
from test_twin_lantern_adaptive_voxel import voxel_cpp

PREFIX='LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlpha'


def effect_cpp():
    effect=next((BASE/'effects').glob('*.fx')).read_text()
    uniforms={
        'View':('int','0'), 'Enabled':('bool','true'), 'Strength':('float','1'),
        'VoxelLightingStrength':('float','.35f'), 'VoxelTraceSteps':('int','16'),
        'RayPairs':('int','2'), 'RayLengthPixels':('float','24'),
        'DepthSlope':('float','.16f'), 'FrontBias':('float','.0005f'),
        'BackThickness':('float','.0035f'), 'DepthTolerance':('float','.005f'),
        'NormalMinimum':('float','.8f'), 'EdgeProtection':('float','1'),
        'EdgeInkStrength':('float','0'), 'EdgeFillStrength':('float','.2f'),
        'EdgeFillRadiusPixels':('float','2'), 'FidelityGuard':('float','.65f'),
        'Overdrive':('float','0'), 'MaximumContribution':('float','.2f'),
        # Explicitly disable new shaping for the existing cache-equivalence fixtures.
        'DepthFadeStrength':('float','0'), 'DepthFadeStart':('float','.005f'),
        'DepthFadeEnd':('float','.05f'), 'LightSoftening':('float','0'),
        'LightSofteningRadiusPixels':('float','2'),
    }
    source='\n'.join(f'{kind} {PREFIX}{name}={value};' for name,(kind,value) in uniforms.items())+'\n'
    source+=r'''
int LUNAR_FLOWER_TLFRRawSampler=1,LUNAR_FLOWER_TLFRResolveHSampler=2,LUNAR_FLOWER_TLFRResolveVSampler=3;
int imageReads=0;
float4 tex2D(int sampler,float2 uv){
 ++imageReads;
 if(sampler==ReShade::BackBuffer)return float4(CAMERA_OBSCURA_LoadColor(uv),1);
 return float4(.4f,.3f,.2f,.8f);
}
float smoothstep(float a,float b,float x){float t=saturate((x-a)/(b-a));return t*t*(3-2*t);}
float3 lerp(float3 a,float3 b,float t){return a+(b-a)*t;}
float3& operator+=(float3& a,float3 b){a=a+b;return a;}
float3& operator*=(float3& a,float b){a=a*b;return a;}
float3 CAMERA_OBSCURA_DebugHeat(float x){return float3(x);}
'''
    tokens=[
        'bool LUNAR_FLOWER_TLFRSourceOnly(', 'void LUNAR_FLOWER_TLFRBuildVoxelProxyCS(',
        'float2 LUNAR_FLOWER_TLFRFullTexel(', 'float LUNAR_FLOWER_TLFRRequestedCoverage(',
        'float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStyledEdgeProtection(',
        'CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLFREvaluateHorizontal(',
        'CAMERA_OBSCURA_API_TL08ResolveEvidence LUNAR_FLOWER_TLFREvaluateVertical(',
        'float LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaPairDirection(',
        'void LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaAccumulateDirection(',
        'float4 LUNAR_FLOWER_TLFRRaw_PS(', 'float LUNAR_FLOWER_TLFRVisibleConfidence(',
        'float4 LUNAR_FLOWER_TLFRResolveH_PS(', 'float4 LUNAR_FLOWER_TLFRResolveV_PS(',
        'float4 LUNAR_FLOWER_TLFRFullResolutionReconstruct(',
        'void LUNAR_FLOWER_TLFRAccumulateEdgeFillTap(', 'float4 LUNAR_FLOWER_TLFRApplyEdgeFill(',
        'float LUNAR_FLOWER_TLFRDepthPhase(', 'float LUNAR_FLOWER_TLFRDepthFadeFactor(',
        'float4 LUNAR_FLOWER_TLFRApplyDepthShaping(',
        'float4 LUNAR_FLOWER_TLFRApplyRenderIntent(',
        'CAMERA_OBSCURA_API_TL09CompositeEvidence\nLUNAR_FLOWER_TLFRFadeComposite(',
        'CAMERA_OBSCURA_API_TL09CompositeEvidence\nLUNAR_FLOWER_TLFREvaluateComposite(',
        'float3 LUNAR_FLOWER_TLFRRejectionColor(', 'float4 LUNAR_FLOWER_TLFRDisplay_PS(',
    ]
    for token in tokens:source+=block(effect,token)+'\n'
    # Reference recomputes reconstruction/fill/receiver guides, while retaining
    # a center guide for the new depth-shaping stage in both evaluations.
    reconstruct=block(effect,'float4 LUNAR_FLOWER_TLFRFullResolutionReconstruct(')
    reconstruct=reconstruct.replace('LUNAR_FLOWER_TLFRFullResolutionReconstruct','LegacyReconstruct')
    reconstruct=reconstruct.replace(', CAMERA_OBSCURA_SurfaceGuide centerGuide','')
    reconstruct=reconstruct.replace('{','{\nCAMERA_OBSCURA_SurfaceGuide centerGuide=LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);',1)
    fill=block(effect,'float4 LUNAR_FLOWER_TLFRApplyEdgeFill(').replace('LUNAR_FLOWER_TLFRApplyEdgeFill','LegacyFill')
    fill=fill.replace('    CAMERA_OBSCURA_SurfaceGuide centerGuide,\n','')
    fill=fill.replace('    [branch]\n    if (centerGuide.valid',
        '    CAMERA_OBSCURA_SurfaceGuide centerGuide=LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);\n    [branch]\n    if (centerGuide.valid',1)
    evaluate=block(effect,'CAMERA_OBSCURA_API_TL09CompositeEvidence\nLUNAR_FLOWER_TLFREvaluateComposite(')
    evaluate=evaluate.replace('LUNAR_FLOWER_TLFREvaluateComposite','LegacyEvaluate')
    evaluate=evaluate.replace('LUNAR_FLOWER_TLFRFullResolutionReconstruct(uv, centerGuide)','LegacyReconstruct(uv)')
    evaluate=evaluate.replace('LUNAR_FLOWER_TLFRApplyEdgeFill(','LegacyFill(').replace('uv, vertical, centerGuide,','uv, vertical,')
    evaluate=evaluate.replace('float receiverValid = centerGuide.valid;',
        'float receiverValid = CAMERA_OBSCURA_DepthConfidence(CAMERA_OBSCURA_LoadDepth(uv));')
    source+=reconstruct+'\n'+fill+'\n'+evaluate+'\n'
    source=re.sub(r'\[(?:branch|loop)\]','',source)
    source=re.sub(r'\s*:\s*(?:SV_Position|SV_DispatchThreadID|TEXCOORD|SV_Target)\b','',source)
    source=re.sub(r'\b(?:out|inout) (float3|float|CAMERA_OBSCURA_\w+) (\w+)',r'\1& \2',source)
    source=source.replace('.rgb','.rgb()')
    source=re.sub(r'\b(\d+\.\d+)\.xxx',r'float3(\1)',source)
    source=re.sub(r'\b(\w+)\.xxx',r'float3(\1)',source)
    source=re.sub(r'\b(\d+\.\d+)(?![\w.])',r'\1f',source)
    return source


CASES = r'''
int assertions=0;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);++assertions;}
bool close(float a,float b){return abs(a-b)<.00001f;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
bool close(float4 a,float4 b){return close(a.rgb(),b.rgb())&&close(a.a,b.a);}
void resetReads(){depthSamples=0;colorSamples=0;nodeWrites=0;nodeReads=0;imageReads=0;}
float4 referenceRaw(float2 uv){
 float3 weighted(0);float total=0;
 for(float direction: {0.f,4.f,2.f,6.f}){
  auto receiver=LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaAccumulateDirection(uv,direction,receiver,weighted,total);
 }
 return float4(weighted*CAMERA_OBSCURA_SafeRcp(total,0),saturate(total*.25f));
}
int main(){
 try{
  float2 uv(.5f,.5f);float4 position(0,0,0,1);
  for(int y=0;y<36;++y)for(int x=0;x<64;++x)
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(x,y,0));
  int screenSaved=0,voxelSaved=0,compositeSaved=0;
  for(int fixture: {0,1,5}){
   voxelFixture=fixture;
   for(int y=0;y<36;++y)for(int x=0;x<64;++x)
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(x,y,0));
   auto receiver=LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
   for(int direction=0;direction<8;++direction){
    resetReads();
    auto a=LUNAR_FLOWER_TLFRTraceScreen(uv,(float)direction,24,.16f,.0005f,.0035f);
    int baseline=depthSamples;
    resetReads();
    auto b=LUNAR_FLOWER_TLFRTraceScreenWithReceiver(uv,(float)direction,24,.16f,.0005f,.0035f,receiver);
    check(close(a,b),"screen receiver reuse changed output");
    check(baseline-depthSamples==5,"screen path did not eliminate five redundant depth reads");
    screenSaved+=baseline-depthSamples;
    resetReads();
    auto va=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(uv,(float)direction,24,.16f,.0005f,.0035f,16);
    baseline=depthSamples;
    resetReads();
    auto vb=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxyWithReceiver(uv,(float)direction,24,.16f,.0005f,.0035f,16,receiver);
    check(close(va.radiance_rgb,vb.radiance_rgb)&&close(va.evidence,vb.evidence)&&va.hit==vb.hit&&
      close(va.normalized_distance,vb.normalized_distance),"voxel receiver reuse changed output");
    check(baseline-depthSamples==5,"voxel path did not eliminate five redundant depth reads");
    voxelSaved+=baseline-depthSamples;
   }
   for(float voxel: {0.f,1.f}){
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength=voxel;
    resetReads();auto reference=referenceRaw(uv);int baseline=depthSamples;
    resetReads();auto cached=LUNAR_FLOWER_TLFRRaw_PS(position,uv);
    check(close(reference,cached),"raw pass receiver reuse changed direction accumulation");
    check(baseline-depthSamples==15,"raw pass did not share receiver across four directions");
   }
   for(float fill: {0.f,.2f,1.f}){
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeFillStrength=fill;
    float target=0,fidelity=0,pressure=0;float3 added(0);
    resetReads();auto old=LegacyEvaluate(uv,target,added,fidelity,pressure);int baseline=depthSamples;
    float oldTarget=target,oldFidelity=fidelity,oldPressure=pressure;float3 oldAdded=added;
    resetReads();auto current=LUNAR_FLOWER_TLFREvaluateComposite(uv,target,added,fidelity,pressure);
    check(close(old.final_rgb,current.final_rgb)&&close(old.evidence,current.evidence)&&
      close(old.bounded_contribution_rgb,current.bounded_contribution_rgb),"composite receiver reuse changed output");
    check(close(oldTarget,target)&&close(oldFidelity,fidelity)&&close(oldPressure,pressure)&&close(oldAdded,added),
      "composite receiver reuse changed diagnostics");
    check(baseline-depthSamples==(fill==0?6:11),"composite did not eliminate repeated center guide reads");
    compositeSaved+=baseline-depthSamples;
   }
  }
  voxelFixture=0;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength=0;
  resetReads();LUNAR_FLOWER_TLFRBuildVoxelProxyCS(uint3(32,18,0));
  check(nodeWrites==0&&depthSamples==0&&colorSamples==0,"voxel-zero still built the hierarchy in Final view");
  for(int mode=0;mode<3;++mode){
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView=mode==0?1:0;
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEnabled=mode!=1;
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStrength=mode==2?0:1;
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength=1;
   resetReads();LUNAR_FLOWER_TLFRBuildVoxelProxyCS(uint3(32,18,0));
   check(nodeWrites==0&&depthSamples==0,"source-only mode built hierarchy");
   check(LUNAR_FLOWER_TLFRRaw_PS(position,uv).a==0,"source-only transport wasn't empty");
   check(LUNAR_FLOWER_TLFRResolveH_PS(position,uv).a==0,"source-only horizontal resolve wasn't empty");
   check(LUNAR_FLOWER_TLFRResolveV_PS(position,uv).a==0,"source-only vertical resolve wasn't empty");
   check(depthSamples==0&&imageReads==0,"source-only working passes sampled depth/fields");
   auto source=LUNAR_FLOWER_TLFRDisplay_PS(position,uv);
   check(close(source.rgb(),float3(.6f,.4f,.2f))&&source.a==1,"source-only display changed source RGB");
   check(depthSamples==0&&imageReads==1,"source-only display did more than one source read");
  }
  for(int view=14;view<=16;++view){
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView=view;
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength=0;
   resetReads();LUNAR_FLOWER_TLFRBuildVoxelProxyCS(uint3(32,18,0));
   check(nodeWrites>0,"voxel diagnostic lost its required build at voxel strength zero");
  }
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView=0;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEnabled=true;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStrength=1;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength=1;
  resetReads();LUNAR_FLOWER_TLFRBuildVoxelProxyCS(uint3(32,18,0));
  check(nodeWrites>0,"active final lighting lost its voxel build");
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStrength=.0000001f;
  check(!LUNAR_FLOWER_TLFRSourceOnly(),"source-only guard discarded a positive strength");
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaStrength=1;
  voxelFixture=3;resetReads();
  auto sky=LUNAR_FLOWER_TLFRRaw_PS(position,uv);
  check(sky.a==0&&depthSamples==5&&nodeReads==0,"invalid receiver still evaluated directions/providers");
  std::cout<<"PASS: "<<assertions<<" performance/equivalence assertions; eliminated depth reads: screen="<<screenSaved
   <<" voxel="<<voxelSaved<<" composite="<<compositeSaved<<". CPU counts, not GPU timing.\n";
 }catch(const std::exception& error){std::cerr<<"FAIL: "<<error.what()<<"\n";return 1;}
}
'''


class InactiveWorkTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('c++'),'CPU fixture requires a C++17 compiler')
    def test_actual_effect_guards_and_guide_reuse(self):
        with tempfile.TemporaryDirectory(prefix='tl-inactive-fixtures-') as folder:
            source=Path(folder)/'fixtures.cpp'
            source.write_text(voxel_cpp(2560,1440,cases=effect_cpp()+CASES))
            exe=Path(folder)/'fixtures'
            result=subprocess.run(['c++','-std=c++17','-O2',str(source),'-o',str(exe)],text=True,capture_output=True)
            self.assertEqual(0,result.returncode,result.stderr)
            result=subprocess.run([str(exe)],text=True,capture_output=True)
            self.assertEqual(0,result.returncode,result.stdout+result.stderr)
            print(result.stdout,end='')


if __name__=='__main__':unittest.main()
