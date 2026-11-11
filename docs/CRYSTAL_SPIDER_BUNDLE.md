# Crystal Spider - Beta + Fog Guard V2

One download contains Crystal Spider, Fog Guard V2, their matching includes,
and `Crystal-Spider-Beta.ini`, a starter preset enabling this order:

**Fog Guard Capture → Crystal Spider → Fog Guard Restore**

The bundle contains two effect files and three techniques. Shader files are
unchanged from the previously published component packages. Crystal Spider's
24 selected defaults are retained; Fog Guard uses its shader defaults, including
Outside Shade `0`. The starter preset contains only these two effects' controls.

## Install

1. Close the game and extract the ZIP outside ReShade's shader search folders.
2. Merge the extracted `reshade-shaders` folder into the game's existing
   installation, replacing the matching files. Keep the installed `ReShade.fxh`.
3. Copy `Crystal-Spider-Beta.ini` beside the game executable or into your preset
   folder, then select it in ReShade.
4. Confirm the three enabled techniques appear in Capture → Crystal Spider →
   Restore order. Crystal Spider retains its existing Twin Lanterns Alpha
   technique name and control identifiers for preset compatibility.

Keep one installed copy of each effect. Update the existing canonical paths
rather than placing a second extracted repository inside the shader search
tree. The package excludes `ReShade.fxh` because the installed framework and
its game-specific depth configuration remain the dependency.

## Keep an existing Lazara or custom preset

Keep that preset selected to retain the rest of its effect stack. Place Fog
Guard Capture before the effects you want protected, and Fog Guard Restore
after them, with Crystal Spider between the two. Set Outside Shade to `0` in
the existing Fog Guard section; an older saved `0.18` value otherwise remains.

The included starter preset selects only this bundle's three techniques.
It is a fresh setup option, not a migration of the rest of a custom preset.
Fog Guard's starter Strength is its shader default `1`; Lazara's separate
curated preset has historically saved `0.672`. Existing custom values remain
under your control.

## Contents and provenance

- `reshade-shaders/`: the complete two-effect shader/include closure.
- `Crystal-Spider-Beta.ini`: explicit technique order and both components'
  current defaults.
- `DEFAULTS_FROM_PRESET.json`: the original Crystal Spider defaults record.
- `BUNDLE_MANIFEST.json`: source archive hashes, included file hashes,
  technique order, defaults and resource-name checks.
- `components/crystal-spider/`: original component notes and license.
- `components/fog-guard/`: original component notes, license notice, source
  provenance, manifest and Fog Guard patch.

Use this README for bundle installation. Component notes retain the context of
their original standalone packages. The root `LICENSE` covers Lunar Flower's
component; Fog Guard and its includes retain their accompanying source notices.
Bundling does not extend or replace those notices.

## Validation and cost

Packaging checks verify both source archive checksums, every shader/include
byte, two unique effect paths, three declared techniques, closed local includes,
separate texture names and the starter preset's defaults/order. The build fails
on conflicting paths or stale component archives. No shader math, passes or
textures are added by packaging.

The components retain their existing GPU costs. Fog Guard keeps a full-resolution
reference and needs both Capture and Restore enabled. CPU and package checks
and previous user feedback are component evidence; this bundle does not claim
a new native compile, combined GPU benchmark or fresh game test.

The standalone Crystal Spider and Fog Guard downloads remain available on
the repository's downloads page for separate installs and rollback.
