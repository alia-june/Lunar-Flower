# Depth Input Audit

A separate diagnostic for depth effects that do nothing or appear reversed.
It compares the actual installed ReShade helper with two candidate conventions.
One pixel pass, no working textures, no GI, and no global-setting changes.

## Install and report

1. Extract the ZIP outside ReShade shader search paths. Merge `reshade-shaders`
   into the game and keep the installed `ReShade.fxh`.
2. Load `Depth-Input-Audit.ini`. This enables only **Lunar Flower - Depth Input
   Audit**. Disable other effects while inspecting its output.
3. Set Probe Position over terrain or a solid building, away from sky and UI.
4. Start with **Compare validity**, then try **Compare linear depth**. The
   three columns repeat the full scene, compressed horizontally:

| Left | Center | Right |
|---|---|---|
| Actual installed framework depth | Candidate normal Z | Candidate reversed Z |

The orange crosses refer to the same scene point. Report the column colors
and the five numbered values at the top left, or provide a screenshot.

| Numeric row | Value |
|---|---|
| 1 | Raw buffer value at the globally adjusted probe UV, before multiplier/reversal/linearization |
| 2 | Actual `ReShade::GetLinearizedDepth` result at the probe |
| 3 | Normal-Z candidate at the probe |
| 4 | Reversed-Z candidate at the probe |
| 5 | ReShade depth-resource readiness: 1 or 0 |

Numbers use scientific notation: `9.8098E-07` means `0.00000098098`.
Nonfinite values display E glyphs. Readiness 1 does not prove scene geometry is
present or that its convention is correct. The views always use actual sampled
values; display exposure/power affect only the grayscale presentation.

## Validity colors

| Color | Range | Meaning for the Twin Lanterns receiver gate |
|---|---|---|
| Green | 0.000001 through 0.999999 | Within the admitted numerical range |
| Red | Below 0.000001, within [0,1] | Rejected near zero |
| Blue | Above 0.999999, within [0,1] | Rejected near one |
| Orange | Outside [0,1] | Decode/range problem; Twin Lanterns clamps before rejecting |
| Magenta | NaN or infinity | Invalid arithmetic/input |

Green is not proof of correct depth: an incorrect interpretation can still be
in range. A flat cleared buffer is not useful scene depth under either
interpretation. Do not weaken the receiver gate just to make a view green.

## Candidate controls

Candidates preserve the global UV transforms, depth multiplier and logarithmic
setting, while explicitly testing normal versus reversed Z. Candidate Far / Near
Ratio starts from the framework's current value; Candidate Projection defaults
to perspective. These controls change only the two candidate columns. They do
not update DisplayDepth, Twin Lanterns, third-party effects or global definitions.

Raw-at-screen-UV versus raw-at-global-adjusted-UV views help inspect alignment.
The actual framework column and numeric row 2 always call the installed helper,
independent of candidate projection or ratio.

DisplayDepth's live preview can use settings different from global definitions.
Third-party shaders may also use their own depth loader/reversal controls. A
helper mismatch between shader include paths or effect-local definitions must
be checked if this diagnostic and GI disagree on the same point.

## Phantom Brigade investigation

The owner reports visible depth but black Combined Weighted Signal, red
Rejection Reason, and no change with Depth Fade Amount 0. That identifies an
invalid receiver before transport, rather than proving an engine-wide GI bug.
The observation that other effects fail or appear reversed refers to
**third-party shaders**, not just Lunar Flower effects.

The [developer's SDK](https://github.com/BraceYourselfGames/PB_ModSDK) specifies
Unity 2020.3.49f1 and built-in deferred rendering. Its
[CameraCore scene](https://github.com/BraceYourselfGames/PB_ModSDK/blob/main/Assets/Content/Scenes/game_main_sdk.unity)
uses perspective projection, near 0.1 and far 5000. These SDK settings do not
prove the current retail camera's parameters. If they apply, its perspective
far/near ratio is 50000; this is a candidate calibration, not an automatic fix.

With those assumed clip planes, a surface at 100 units and an incorrect
normal-Z interpretation of a reversed-Z buffer becomes about 9.81e-7 under
framework ratio 1000: rejected by our 1e-6 gate. The correct reversal gives
about 0.505. This derived example reproduces the mechanism; it is not a measured
value from the owner's game. The numeric probe is intended to test it.

## Validation scope and parser tool

The official ReShade **6.7.3 FX frontend** accepts this effect and generates
SM5 HLSL using an official framework header. This is actual shader-language
parsing/type checking, distinct from the C++ math fixtures. It does not invoke
FXC/DXC, produce DXBC/DXIL, or validate driver behavior, capture timing or GPU cost.
The installed framework may differ from the header checked here.

`tools/reshade_fx_frontend.cpp` is a reusable wrapper. Build it against the
unmodified official [v6.7.3 sources](https://github.com/crosire/reshade/tree/v6.7.3/source),
retaining their BSD license separately. With those source files in `$LF_FX_SRC`:

```bash
c++ -std=c++17 -O2 -I"$LF_FX_SRC" tools/reshade_fx_frontend.cpp \
  "$LF_FX_SRC/effect_lexer.cpp" "$LF_FX_SRC/effect_preprocessor.cpp" \
  "$LF_FX_SRC/effect_expression.cpp" "$LF_FX_SRC/effect_symbol_table.cpp" \
  "$LF_FX_SRC/effect_parser_exp.cpp" "$LF_FX_SRC/effect_parser_stmt.cpp" \
  "$LF_FX_SRC/effect_codegen_hlsl.cpp" -o /tmp/reshade-fx-frontend
/tmp/reshade-fx-frontend path/to/effect.fx path/to/framework/includes NAME=VALUE
```

The wrapper also needs the effect `.hpp` files and intrinsic `.inl` from the
same version. No downloaded ReShade compiler sources or binary are included in
this diagnostic ZIP. The wrapper is repository tooling under its MIT license.
