#!/usr/bin/env python3
"""Compare the identified historical upload with current voxel shader functions.

Requires the user's original ZIP and a C++17 compiler. Texture/vector shims
come from the existing CPU fixtures. This is not FXC, GPU parity, or timing.
Only the exact reviewed legacy voxel include is accepted for compilation.
"""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import tempfile
from zipfile import ZipFile

from test_twin_lantern_adaptive_voxel import voxel_cpp

MEMBER = 'reshade-shaders/Shaders/camera_obscura/api/LUNAR_FLOWER_API_TwinLanternVoxelProxy.fxh'
LEGACY_SHA256 = '582949851df9c49736981be7cb0dfe2c9a512b3327118881b04957402c0b6612'


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise ValueError('CPU fixture changed; inspect this comparison adapter before reuse')
    return text.replace(before, after)


def comparison_source(legacy):
    source = voxel_cpp(2560, 1440, cases='')
    # Add separate storage for the old 32-depth-bin volume. Current nodes keep
    # their existing bounds-checked storage; resource 1 names the legacy volume.
    source = replace_once(source, 'std::vector<float4> nodes(',
        'std::vector<float4> oldVoxels(64*36*32,float4(0,0,0,0));\nstd::vector<float4> nodes(')
    source = replace_once(source,
        'void tex3Dstore(int,int3 cell,float4 value){++nodeWrites;nodes[indexOf(cell)]=value;}',
        'void tex3Dstore(int resource,int3 cell,float4 value){++nodeWrites;'
        'if(resource==1){oldVoxels.at((cell.z*36+cell.y)*64+cell.x)=value;return;}'
        'nodes[indexOf(cell)]=value;}')
    source = replace_once(source,
        'float4 tex3Dfetch(int,int3 cell){++nodeReads;return nodes[indexOf(cell)];}',
        'float4 tex3Dfetch(int resource,int3 cell){++nodeReads;'
        'if(resource==1)return oldVoxels.at((cell.z*36+cell.y)*64+cell.x);'
        'return nodes[indexOf(cell)];}')
    # In the mismatch fixture the receiver alone has depth .4; the first
    # .75-pixel sample already has incompatible depth .8.
    source = replace_once(source, 'return d<1.4f?.4f:.8f;', 'return d<.5f?.4f:.8f;')
    legacy = re.sub(r'^(?:texture3D|storage3D|sampler3D)\s+\w+\s*\{.*?^\};',
                    '', legacy, flags=re.M | re.S)
    legacy = legacy.replace('LUNAR_FLOWER_', 'OLD_LUNAR_FLOWER_')
    legacy = legacy.replace('[shader("compute")]', '').replace('[loop]', '')
    legacy = legacy.replace(' : SV_DispatchThreadID', '').replace('.rgb', '.rgb()')
    legacy = legacy.replace('id.xy', 'id.xy()')
    legacy = re.sub(r'\b(\d+\.\d+)(?![\w.])', r'\1f', legacy)
    source += r'''
float2 operator+(float2 a,float b){return float2(a.x+b,a.y+b);}
float4 operator*(float4 a,float b){return float4(a.x*b,a.y*b,a.z*b,a.a*b);}
namespace ReShade {float GetLinearizedDepth(float2 uv){return CAMERA_OBSCURA_LoadDepth(uv);}}
int OLD_LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceStorage=1;
int OLD_LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaVoxelRadianceSampler=1;
'''
    return source + legacy + CASES


CASES = r'''
void buildBoth(){
 for(int y=0;y<36;++y)for(int x=0;x<64;++x){
  LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(x,y,0));
  for(int z=0;z<32;++z)
   OLD_LUNAR_FLOWER_TwinLanternsFullResolutionDualRayAlphaBuildVoxelProxyCS(uint3(x,y,z));
 }
}
int main(){
 voxelFixture=2;buildBoth();
 float2 a(32.1f/64,18.2f/36),b(32.4f/64,18.2f/36);
 auto oldA=OLD_LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(a);
 auto oldB=OLD_LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(b);
 auto newA=LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(a);
 auto newB=LUNAR_FLOWER_API_LoadTwinLanternVoxelSurface(b);
 std::cout<<"Same tile / different colors, red: uploaded="<<oldA.x<<","<<oldB.x
          <<" current="<<newA.x<<","<<newB.x<<"\n";
 if(abs(oldA.x-oldB.x)>.00001f||abs(newA.x-.1f)>.00001f||abs(newB.x-.8f)>.00001f)return 1;
 voxelFixture=0;buildBoth();
 auto oldSelf=OLD_LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2(.5f,.5f),0,24,0,.0005f,.0035f,32);
 auto newSelf=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2(.5f,.5f),0,24,0,.0005f,.0035f,32);
 std::cout<<"First accepted flat sample, pixels: uploaded="<<oldSelf.normalized_distance*24
          <<" current="<<newSelf.normalized_distance*24<<"\n";
 if(oldSelf.hit!=1||newSelf.hit!=1||oldSelf.normalized_distance*24>1.5f||newSelf.normalized_distance*24<=1.5f)return 2;
 voxelFixture=4;
 auto oldMismatch=OLD_LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2(.5f,.5f),0,24,0,.0005f,.0035f,32);
 auto newMismatch=LUNAR_FLOWER_API_TraceTwinLanternVoxelProxy(float2(.5f,.5f),0,24,0,.0005f,.0035f,32);
 std::cout<<"Occupied cell / incompatible fine depth, hit: uploaded="<<oldMismatch.hit
          <<" current="<<newMismatch.hit<<"\n";
 if(oldMismatch.hit!=1||newMismatch.hit!=0)return 3;
 std::cout<<"PASS: three historical/current CPU comparisons; not native/GPU validation\n";
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', required=True, type=Path)
    args = parser.parse_args()
    with ZipFile(args.archive) as archive:
        legacy = archive.read(MEMBER)
    if hashlib.sha256(legacy).hexdigest() != LEGACY_SHA256:
        raise ValueError('Archive voxel include differs from the reviewed upload')
    with tempfile.TemporaryDirectory(prefix='tl-upload-comparison-') as folder:
        path = Path(folder) / 'comparison.cpp'
        path.write_text(comparison_source(legacy.decode('utf-8')))
        executable = Path(folder) / 'comparison'
        subprocess.run(['c++', '-std=c++17', '-O2', str(path), '-o', str(executable)], check=True)
        subprocess.run([str(executable)], check=True)


if __name__ == '__main__':
    main()
