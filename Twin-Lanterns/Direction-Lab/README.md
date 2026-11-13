# Twin Lanterns — Direction Lab

A voxel-free first-pass lighting experiment for comparing directional coverage
and understanding why transport contributes little or changes abruptly.

## Install and compare

1. Extract `Twin-Lanterns-DirectionLab.zip` outside ReShade shader search folders.
2. Merge only `reshade-shaders` into the game installation. Keep its installed
   `ReShade.fxh`.
3. Select `Twin-Lanterns-DirectionLab-Cardinal.ini`. It enables only **Lunar
   Flower - Twin Lanterns: Direction Lab**, without Fog Guard or other effects.
4. At a fixed scene/camera position, switch **Direction Set** between
   **Cardinal (4 directions)** and **Diagonal (4 directions)**. Leave Provider,
   strength, distance, shaping and all other settings identical. Separate
   Cardinal and Diagonal presets are also supplied with these identical values.
5. Test **Mixed (8 directions)** separately. It averages evidence by eight and
   can improve coverage, but doubles the maximum traversal work.

The effect, uniforms, render targets and include directory have independent
identities. Existing No-Voxel and Crystal Spider downloads are preserved. For
an isolated comparison, keep those techniques and both Fog Guard techniques
disabled. Re-enable the original preset afterward to restore your full stack.

## What is controlled

Cardinal and Diagonal each use four directions, the same Euclidean distance in
full-resolution pixels, the same normalized depth travel, the same provider
budgets and the same averaging. **Provider** selects DDA + March, DDA Only or
March Only; a disabled provider is not traced. Each selected provider is
normalized independently of whether the other provider is enabled.

The parent DDA uses a major-axis cell count, which gives diagonals fewer samples
at the same pixel distance. Its depth travel also depends on direction through
UV length on rectangular render targets. This lab changes its local traversal
copy to **32 uniformly spaced DDA samples** per direction, while march keeps its
**16-sample maximum** and established spatial jitter. Depth travel uses the
mean X/Y pixel pitch for every direction. This controls sampling and depth-range
bias; it changes the parent tracing schedule, so this is an experimental build,
not a byte-equivalent replacement for No Voxel.

Early hits, screen exits and invalid receivers can reduce actual work. Equal
maximum budgets do not guarantee equal GPU time or sample counts in different
scene directions. Reconstruction, bounds, hit tolerances, receiver validity,
surface guidance and the selected non-direction defaults remain in place.

## Read the diagnostics

Keep Provider at **DDA + March** when comparing the two providers side by side.
Selecting a single provider intentionally leaves the disabled provider's views
black.

| Output View | Meaning |
|---|---|
| DDA / March Hit Coverage | Fraction of scheduled directions with a refined hit; white = all, black = none |
| DDA / March Admitted Weight | Average weight after confidence, donor validity, normal compatibility and distance |
| DDA / March Raw Donor Color | Average source color at hit donors, without light-strength or final-shaping attenuation |
| DDA / March Weighted Signal | Donor color multiplied by its admitted weight, averaged over that provider's directions |
| Combined Raw Donor | Normalized color from selected providers before reconstruction |
| Combined Weighted Signal | Raw donor × combined evidence before reconstruction, strength, fade, fidelity and caps |
| Receiver Validity | Validity of the current pixel's depth guide |
| Applied Light | Actual final addition after reconstruction, intent, fade and bounds |

These new views use grayscale for coverage/weight and unamplified RGB for donor
and signal. A dark signal can be small valid light; black donor color is not
automatically a missing hit. Bright hit coverage with weak admitted weight
points to later donor rejection/attenuation. Strong raw signal with weak Applied
Light points to reconstruction or subsequent shaping. Capture the same scene
and camera state before assigning a cause to a difference.

Output views 0–14 retain the No-Voxel mapping. New views occupy 15–25. In the
provider diagnostic views, working passes skip lighting/resolve work and the
display pass evaluates the scheduled rays once. This adds no diagnostic texture,
compute pass, temporal state or additional ray schedule in Final Image.

## Scope and evidence

This experiment measures first-pass screen-space transport. It does not add
another bounce, read previous-frame lighting, capture off-screen geometry or
claim physically complete GI. A controlled second pass can be evaluated after
the first-pass direction/provider comparison.

C++ fixtures execute shader-extracted functions against synthetic textures to
test direction schedules, sample budgets, angular light coverage, provider
normalization, diagnostics and exact bypass/bounds. Source audits check the
loop call graphs for implicit-gradient operations. These checks do not replace
native ReShade compilation, game captures or GPU performance measurements;
those remain pending. There is no claim that this fixes the reported Elden
Ring cutoff.

Three full-resolution RGBA16F working textures and four pixel passes remain.
No voxel resources or temporal history are included. `SOURCE_LINEAGE.json`
identifies every parent and changed file; shared includes other than the local
traversal file retain their source bytes. Software uses the repository MIT
license and retained notices.
