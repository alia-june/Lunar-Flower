"""Execute actual Alpha depth shaping with CPU texture/vector shims, not FXC."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_twin_lantern_adaptive_voxel import voxel_cpp
from test_twin_lantern_inactive_work import effect_cpp


CASES = r'''
int assertions=0;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);++assertions;}
bool close(float a,float b){return abs(a-b)<.00001f;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
bool close(float4 a,float4 b){return close(a.rgb(),b.rgb())&&close(a.a,b.a);}
float3 signal(float4 value){return value.rgb()*value.a;}
void resetReads(){depthSamples=0;colorSamples=0;imageReads=0;nodeWrites=0;nodeReads=0;}
int main(){
 try{
  float2 uv(.5f,.5f);float4 position(0,0,0,1);
  voxelFixture=0;
  auto guide=LUNAR_FLOWER_TLFRBuildSurfaceGuide(uv);
  auto base=float4(.4f,.3f,.2f,.8f);
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStart=.2f;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd=.6f;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength=1;
  check(close(LUNAR_FLOWER_TLFRDepthFadeFactor(.1f),1),"near light faded");
  check(close(LUNAR_FLOWER_TLFRDepthFadeFactor(.4f),.5f),"fade midpoint incorrect");
  check(close(LUNAR_FLOWER_TLFRDepthFadeFactor(.8f),0),"far light remained");
  float previous=1;
  for(int i=0;i<=100;++i){
   float fade=LUNAR_FLOWER_TLFRDepthFadeFactor(i*.01f);
   check(fade>=0&&fade<=1&&fade<=previous+.000001f,"fade is not bounded/monotone");previous=fade;
  }
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd=.2f;
  check(close(LUNAR_FLOWER_TLFRDepthFadeFactor(.19f),1)&&close(LUNAR_FLOWER_TLFRDepthFadeFactor(.21f),0),"equal endpoints broke fade");
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd=.1f;
  check(close(LUNAR_FLOWER_TLFRDepthFadeFactor(.19f),1)&&close(LUNAR_FLOWER_TLFRDepthFadeFactor(.21f),0),"reversed endpoints broke fade");
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd=.6f;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSoftening=0;
  resetReads();auto midpoint=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,guide);
  check(close(midpoint.rgb(),base.rgb())&&close(midpoint.a,.4f)&&imageReads==0&&depthSamples==0,"fade-only midpoint changed color or sampled taps");
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength=.5f;
  check(close(LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,guide).a,.6f),"partial fade strength incorrect");
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength=1;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSoftening=1;
  auto invalid=guide;invalid.valid=0;
  check(LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,invalid).a==0,"invalid receiver gained light");
  auto near=guide;near.depth=.1f;
  resetReads();auto nearLight=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,near);
  check(close(nearLight,base)&&imageReads==0&&depthSamples==0,"near light softened or sampled taps");
  auto far=guide;far.depth=.8f;
  resetReads();auto farLight=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,far);
  check(farLight.a==0&&imageReads==0&&depthSamples==0,"fully faded receiver sampled softening taps");
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength=0;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSoftening=0;
  resetReads();auto bypass=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,guide);
  check(bypass.x==base.x&&bypass.y==base.y&&bypass.z==base.z&&bypass.a==base.a,"zero controls not exact bypass");
  check(imageReads==0&&depthSamples==0,"zero controls sampled taps");
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStart=0;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd=.2f;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSoftening=1;
  // A constant premultiplied signal stays constant, including partial evidence.
  fieldFixture=0;resetReads();auto uniform=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,guide);
  check(close(uniform,base),"uniform light/evidence changed under softening");
  check(imageReads==4&&depthSamples==20,"softening exceeded four field/four guide taps");
  // A center impulse is reduced by four admitted black neighbors, without
  // treating their nonzero evidence as an invalid sample.
  fieldFixture=1;auto impulse=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,float4(.8f,.8f,.8f,1),guide);
  check(close(signal(impulse),float3(.16f))&&close(impulse.a,1),"light impulse failed to soften");
  fieldFixture=3;auto black=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,float4(0,0,0,.8f),guide);
  check(close(black.rgb(),float3(0))&&close(black.a,.8f),"valid black light was mishandled");
  // Bright taps beyond a different-depth silhouette cannot contaminate center.
  fieldFixture=2;voxelFixture=4;
  auto dark=float4(.1f,.1f,.1f,1);
  auto depthRejected=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,dark,guide);
  check(close(depthRejected,dark),"softening crossed rejected depth boundary");
  voxelFixture=0;auto opposite=guide;opposite.normal=float3(0,0,-1);
  check(close(LUNAR_FLOWER_TLFRApplyDepthShaping(uv,dark,opposite),dark),"softening crossed rejected normal boundary");
  voxelFixture=3;
  check(close(LUNAR_FLOWER_TLFRApplyDepthShaping(uv,dark,guide),dark),"sky taps carried light");
  voxelFixture=0;fieldFixture=1;
  resetReads();auto corner=LUNAR_FLOWER_TLFRApplyDepthShaping(float2(.5f*BUFFER_RCP_WIDTH,.5f*BUFFER_RCP_HEIGHT),float4(.8f,.8f,.8f,1),guide);
  check(close(signal(corner),float3(.8f/3.f))&&imageReads==2&&depthSamples==10,"out-of-screen softening taps were sampled/admitted");
  // Fade attenuation is monotone with fade strength; shared hard ceilings
  // and nonnegative addition remain valid for all these shaped signals.
  fieldFixture=2;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStart=.2f;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd=.6f;
  for(float amount: {0.f,.25f,.5f,.75f,1.f}){
   LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaLightSoftening=amount;
   float3 last(1);
   for(int i=0;i<=10;++i){
    LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength=i*.1f;
    auto shaped=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,guide);auto added=signal(shaped);
    check(added.x<=last.x+.00001f&&added.y<=last.y+.00001f&&added.z<=last.z+.00001f,"more fade increased light");last=added;
    check(shaped.a>=0&&shaped.a<=1&&added.x>=0&&added.x<=.90001f,"softening escaped convex signal bounds");
    for(int c=0;c<=10;++c){
     float3 source(c*.1f,.4f,.9f);
     auto composite=CAMERA_OBSCURA_API_BuildTL09Composite(source,shaped.rgb(),shaped.a,1,1,4,.2f);
     check(composite.bounds_valid==1&&composite.final_rgb.x>=source.x&&composite.final_rgb.y>=source.y&&composite.final_rgb.z>=source.z,"depth shaping broke bounded source-preserving composite");
    }
   }
  }

  // Regression: partial fades must remain visible after either hard ceiling.
  // The earlier pre-cap implementation kept 0.2 added light at both 1 and 0.5
  // strength when raw light exceeded the ceiling; near-white channel room
  // concealed the same fade at 0.05 added light.
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength=1;
  for(float receiver: {0.f,.1f,.5f,.95f,1.f})
   for(float energy: {0.f,.05f,.8f,1.f})
    for(float evidence: {0.f,.1f,1.f})
     for(float strength: {0.f,.2f,1.f,4.f})
      for(float ceiling: {0.f,.05f,.2f,.5f}){
       auto original=CAMERA_OBSCURA_API_BuildTL09Composite(float3(receiver),float3(energy),evidence,1,1,strength,ceiling);
       for(float depth: {.1f,.2f,.4f,.6f,.9f}){
        float keep=depth<.4f?1.f:(depth==.4f?.5f:0.f);
        auto faded=LUNAR_FLOWER_TLFRFadeComposite(original,depth);
        check(close(faded.bounded_contribution_rgb,original.bounded_contribution_rgb*keep),"fade concealed by contribution/channel-room cap");
        check(close(faded.final_rgb,original.source_rgb+original.bounded_contribution_rgb*keep),"final output does not match faded bounded light");
        check(faded.final_rgb.x>=receiver&&faded.final_rgb.x<=1.000001f&&faded.bounds_valid==original.bounds_valid,"post-bound fade broke source/channel bounds or hid failure");
        check(close(faded.evidence,original.evidence*keep)&&close(faded.maximum_contribution,original.maximum_contribution*keep),"post-fade diagnostics do not track effective evidence/ceiling");
       }
      }
  auto limited=CAMERA_OBSCURA_API_BuildTL09Composite(float3(.5f),float3(.8f),1,1,1,4,.2f);
  auto halfLimited=LUNAR_FLOWER_TLFRFadeComposite(limited,.4f);
  check(close(halfLimited.bounded_contribution_rgb,float3(.1f))&&close(halfLimited.source_preserve_delta,.1f)&&close(halfLimited.containment_activity,1),"half fade or diagnostics incorrect for saturated request");
  auto removed=LUNAR_FLOWER_TLFRFadeComposite(limited,.6f);
  check(removed.application==0&&removed.rejection==1&&removed.rejection_code==7,"fully faded application/rejection diagnostics incorrect");
  limited.bounds_valid=0;
  check(LUNAR_FLOWER_TLFRFadeComposite(limited,.4f).bounds_valid==0,"fade erased an existing bound failure");

  // Edge fill cannot restore faded light, since final fade follows all bounds.
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStart=0;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd=.2f;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStrength=1;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaEdgeFillStrength=1;
  float target=0,fidelity=0,pressure=0;float3 fill(0);
  auto final=LUNAR_FLOWER_TLFREvaluateComposite(uv,target,fill,fidelity,pressure);
  check(close(final.final_rgb,float3(.6f,.4f,.2f))&&close(final.bounded_contribution_rgb,float3(0)),"edge fill/render intent restored fully faded light");
  // Mask view requires one depth read and skips transport, resolve and voxels.
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaView=17;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelLightingStrength=1;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeStart=.2f;
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaDepthFadeEnd=.6f;
  resetReads();LUNAR_FLOWER_TLFRBuildVoxelProxyCS(uint3(32,18,0));
  LUNAR_FLOWER_TLFRRaw_PS(position,uv);LUNAR_FLOWER_TLFRResolveH_PS(position,uv);LUNAR_FLOWER_TLFRResolveV_PS(position,uv);
  check(nodeWrites==0&&nodeReads==0&&imageReads==0&&depthSamples==0,"mask view performed lighting work");
  auto mask=LUNAR_FLOWER_TLFRDisplay_PS(position,uv);
  check(close(mask.rgb(),float3(.5f))&&imageReads==0&&depthSamples==1,"mask did not show receiver fade directly");
  std::cout<<"PASS: "<<assertions<<" depth-shaping CPU assertions; fade, constant light, impulses, surface/sky/coverage rejection, bounds, exact bypass and mask work guards\n";
 }catch(const std::exception& error){std::cerr<<"FAIL: "<<error.what()<<"\n";return 1;}
}
'''


def source():
    effect = effect_cpp()
    anchor = 'int LUNAR_FLOWER_TLFRRawSampler=1'
    assert effect.count(anchor) == 1
    effect = effect.replace(anchor, 'int fieldFixture=0;\n' + anchor)
    anchor = ' return float4(.4f,.3f,.2f,.8f);'
    assert effect.count(anchor) == 1
    effect = effect.replace(anchor, '''
 if(fieldFixture==1)return float4(0,0,0,1);
 if(fieldFixture==2)return float4(.9f,.9f,.9f,1);
 if(fieldFixture==3)return float4(0,0,0,.8f);
 return float4(.4f,.3f,.2f,.8f);''')
    fixture = r"""
float4 FixtureShapeThenFade(float2 uv,float4 base,CAMERA_OBSCURA_SurfaceGuide guide){
 auto softened=LUNAR_FLOWER_TLFRApplyDepthShaping(uv,base,guide);
 auto result=CAMERA_OBSCURA_API_BuildTL09Composite(float3(0),softened.rgb(),softened.a,guide.valid,1,1,1);
 result=LUNAR_FLOWER_TLFRFadeComposite(result,guide.depth);
 return float4(result.indirect_rgb,result.evidence);
}
"""
    cases = CASES.replace('LUNAR_FLOWER_TLFRApplyDepthShaping(', 'FixtureShapeThenFade(')
    return voxel_cpp(2560, 1440, cases='') + effect + fixture + cases


class DepthShapingTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('c++'), 'CPU fixture requires C++17')
    def test_actual_shader_depth_shaping(self):
        with tempfile.TemporaryDirectory(prefix='tl-depth-shaping-') as temp:
            path = Path(temp) / 'fixtures.cpp'
            path.write_text(source())
            executable = Path(temp) / 'fixtures'
            result = subprocess.run(['c++', '-std=c++17', '-O2', str(path), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            print(result.stdout, end='')


if __name__ == '__main__':
    unittest.main()
