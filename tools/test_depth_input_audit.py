"""Depth math/display probes plus an optional actual ReShade FX frontend check."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from zipfile import ZipFile

from package_depth_input_audit import BUILD, EFFECT, package
import test_twin_lantern_screen_surface as cpu

FRONTEND = os.environ.get('LF_FX_FRONTEND', '')
FRAMEWORK = os.environ.get('LF_FX_INCLUDE', '')

MATH = r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <stdexcept>
using std::abs;using std::floor;using std::pow;using std::log10;using std::isnan;using std::isinf;
using std::max;using std::min;
struct float2{float x,y;float2(float a,float b):x(a),y(b){}};
struct float3{float x,y,z;float3(float a,float b,float c):x(a),y(b),z(c){}};
float2 frac(float2 p){return {p.x-floor(p.x),p.y-floor(p.y)};}
float LF_DPA_FarRatio=1000;
int LF_DPA_Projection=0;
#define RESHADE_DEPTH_MULTIPLIER 1
#define RESHADE_DEPTH_INPUT_IS_LOGARITHMIC 0
FUNCTIONS
int assertions=0;
void check(bool b,const char* why){if(!b)throw std::runtime_error(why);++assertions;}
bool close(float a,float b,float tolerance=.00001f){return abs(a-b)<tolerance;}
bool close(float3 a,float3 b){return close(a.x,b.x)&&close(a.y,b.y)&&close(a.z,b.z);}
int main(){try{
 for(float value: {0.f,.0000005f,.000001f,.25f,.999999f,1.f}){
  bool accepted=value>=.000001f&&value<=.999999f;
  auto color=LF_DPA_ValidityColor(value);
  check((color.y>.9f)==accepted,"diagnostic differs from Twin Lanterns validity gate");
 }
 check(close(LF_DPA_ValidityColor(0),float3(1,.05f,.03f)),"near-zero color wrong");
 check(close(LF_DPA_ValidityColor(1),float3(.1f,.25f,1)),"near-one color wrong");
 check(close(LF_DPA_ValidityColor(-1),float3(1,.5f,0)),"negative decode not exposed");
 check(close(LF_DPA_ValidityColor(2),float3(1,.5f,0)),"overshoot decode not exposed");
 check(close(LF_DPA_ValidityColor(NAN),float3(1,0,1)),"NaN not exposed");
 check(close(LF_DPA_ValidityColor(INFINITY),float3(1,0,1)),"infinity not exposed");
 for(float eye: {2.f,5.f,10.f,50.f,100.f}){
  float raw=(float)(1000.0/999.0-1000.0/(999.0*eye));
  float expected=(eye-1)/999;
  check(close(LF_DPA_Candidate(raw,false),expected),"perspective normal-Z conversion wrong");
  check(close(LF_DPA_Candidate(1-raw,true),expected),"perspective reversed-Z conversion wrong");
 }
 float sdkRaw=(float)(1-(5000.0/4999.9-500.0/(4999.9*100.0)));
 auto wrong=LF_DPA_Candidate(sdkRaw,false),right=LF_DPA_Candidate(sdkRaw,true);
 check(wrong<.000001f&&right>.5f&&right<.51f,"SDK reversal example does not reproduce receiver rejection");
 LF_DPA_FarRatio=50000;
 check(close(LF_DPA_Candidate(sdkRaw,true),99.9f/4999.9f,.00005f),"candidate far/near ratio calibration wrong");
 LF_DPA_Projection=1;
 for(int i=0;i<=100;++i){float raw=(float)i/100;
  check(close(LF_DPA_Candidate(raw,false),raw),"orthographic depth linearized twice");
  check(close(LF_DPA_Candidate(raw,true),1-raw),"orthographic reversed depth wrong");
 }
 // Rasterize actual numeric functions into counts and ASCII. Values must be
 // legible even below the rejected-depth cutoff, not silently shown as zero.
 for(float value: {0.f,1.f,.0009800196f,.00000098098f,.5048004f,-.25f}){
  int lit=0;
  for(int y=0;y<18;++y)for(int x=0;x<156;++x){
   float ink=LF_DPA_Number(float2((x+.5f)/12,(y+.5f)/18),value,2);
   check(ink==0||ink==1,"numeric glyph mask not binary");lit+=(int)ink;
  }
  check(lit>150,"numeric probe output is blank");
 }
 std::cout<<"PASS: "<<assertions<<" extracted C++ depth/math/glyph assertions (not FX parsing)\n";
}catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}}
'''


class DepthInputAuditTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('c++'), 'requires C++ for separate math fixture')
    def test_extracted_math_and_numeric_glyphs(self):
        source = (BUILD / EFFECT).read_text()
        functions = '\n'.join(cpu.block(source, name) for name in (
            'float LF_DPA_Candidate(', 'float3 LF_DPA_ValidityColor(',
            'float LF_DPA_Glyph(', 'float LF_DPA_Number('))
        functions = re.sub(r'\b(\d+\.\d+)(?![\w.])', r'\1f', functions)
        with tempfile.TemporaryDirectory(prefix='depth-audit-math-') as tmp:
            path = Path(tmp) / 'fixture.cpp'
            path.write_text(MATH.replace('FUNCTIONS', functions))
            exe = Path(tmp) / 'fixture'
            compiled = subprocess.run(['c++', '-std=c++17', '-O2', str(path), '-o', str(exe)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(exe)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            print(result.stdout, end='')

    @unittest.skipUnless(Path(FRONTEND).is_file() and Path(FRAMEWORK, 'ReShade.fxh').is_file(),
                         'set LF_FX_FRONTEND and LF_FX_INCLUDE for actual FX frontend checks')
    def test_actual_fx_frontend_with_global_depth_variants(self):
        variants = ((), ('RESHADE_DEPTH_INPUT_IS_REVERSED=0',),
                    ('RESHADE_DEPTH_INPUT_IS_REVERSED=1', 'RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=1',
                     'RESHADE_DEPTH_INPUT_IS_MIRRORED=1', 'RESHADE_DEPTH_INPUT_X_SCALE=0.75',
                     'RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET=16'),
                    ('RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=1', 'RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=50000'),
                    ('__RENDERER__=0xc000', 'BUFFER_WIDTH=1920', 'BUFFER_HEIGHT=1080'))
        for definitions in variants:
            result = subprocess.run([FRONTEND, str(BUILD / EFFECT), FRAMEWORK, *definitions], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('SM5 HLSL generation', result.stdout)

    @unittest.skipUnless(Path(FRONTEND).is_file(), 'set LF_FX_FRONTEND for actual FX parser regression')
    def test_actual_fx_parser_rejects_cpp_legal_reserved_identifier(self):
        with tempfile.TemporaryDirectory(prefix='fx-reserved-regression-') as tmp:
            path = Path(tmp) / 'bad.fx'
            path.write_text('float Probe() { float precise = 1.0; return precise; }')
            result = subprocess.run([FRONTEND, str(path), tmp], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('X3000', result.stderr)
            self.assertIn('precise', result.stderr)

    def test_reproducible_isolated_package(self):
        with tempfile.TemporaryDirectory(prefix='depth-audit-package-') as tmp:
            a,b = Path(tmp) / 'a.zip', Path(tmp) / 'b.zip'
            manifest = package(a)
            package(b)
            self.assertEqual(a.read_bytes(), b.read_bytes())
            self.assertTrue(manifest['display_only'])
            self.assertFalse(manifest['changes_global_definitions'])
            with ZipFile(a) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual([n for n in archive.namelist() if n.endswith('.fx')], [EFFECT])
                self.assertNotIn('ReShade.fxh', archive.namelist())
                for name, sha in manifest['files'].items():
                    self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), sha)


if __name__ == '__main__':
    unittest.main()
