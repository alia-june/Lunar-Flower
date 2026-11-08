# Front Surface Bias near zero

The user reported the best result at `0`, next best at `0.0001`, and supplied
two captures labeled with those values. The `0.0001` capture appears smoother
over the pillar and armor. These captures motivate finer control; they are
not an isolated GPU test or a calibrated depth measurement.

## Meaning established from source

- Depth comes from `ReShade::GetLinearizedDepth`, clamped to normalized 0–1.
  Bias is in this depth scale, not pixels or a percentage of ray distance.
- `BuildTraceControls` preserves exact zero: `max(request.front_bias, 0)`.
  `BuildRayC0` copies it to the ray and leaves the origin at the receiver depth.
- Traversal subtracts Front Bias from the front of the ray segment's accepted
  depth interval. Refinement similarly tests `sceneDepth >= rayDepth - bias`.
  Raising it admits additional camera-side surfaces; it does not move the ray
  away from the receiver or independently prevent self-intersection.
- Hit confidence uses `1 - abs(delta)/(bias + thickness + 0.0001)`, clamped to
  0–1. Increasing bias can also increase confidence for existing hits.
- Alpha enforces its separate pixel-distance self-hit exclusion. Zero Front
  Bias does not disable that check, back thickness, or lighting.

This is a compressed useful control range, with admission thresholds capable
of causing a large visual change after a small numerical change. It does not
show that the control is ignored or numerically broken. A relative-depth or
world-distance reinterpretation would be a separate algorithm/preset change;
there is insufficient scene-depth evidence here to select that mapping.

## Executed CPU probe

The Mill retains `harness/bias_probe.cpp` and
`evidence/static/front-bias-probe.log`. It executes the actual screen trace,
refinement and confidence functions with CPU texture/vector shims at 2560×1440.
Receiver depth is `0.4`, ray depth slope is zero, length is 24 pixels and back
thickness is `0.0035`. Samples beyond 1.25 pixels have depth `0.4 - 0.00005`;
the receiver's one-pixel guide samples remain on its surface. Donor red is 0.8.

| Front Bias | Screen evidence | Confidence at residual −0.00005 |
| --- | --- | --- |
| 0 | 0 | 0.986111 |
| 0.000001 | 0 | 0.986115 |
| 0.00001 | 0 | 0.986150 |
| 0.000025 | 0 | 0.986207 |
| 0.00005 | 0.909426 | 0.986301 |
| 0.0001 | 0.909597 | 0.986486 |
| 0.0005 | 0.910813 | 0.987805 |

Confidence alone changes little in this fixture. Admitting the previously
rejected donor causes the large signal change. Zero remains exactly zero and
the independent 1.5-pixel self-hit exclusion remains configured. This fixture
demonstrates a mechanism; it does not measure which donors caused the user's
specific image difference or prove native/GPU parity.

## Control correction

Alpha now uses a fine drag control with `0.000001` steps, **100× finer** than
the old `0.0001` step. This gives 100 intervals between `0` and `0.0001`.
The uniform name, `0–0.01` range, `0.0005` default, stored values and shader
functions are preserved. Zero is a valid tuning choice. Existing presets
are not rescaled. The tooltip now describes admission and confidence rather
than incorrectly suggesting that positive bias independently avoids self hits.

Suggested comparison values are `0`, `0.00001`, `0.000025`, `0.00005` and
`0.0001`, with other settings and the camera held fixed. Native compilation
and target-game visual testing of this UI update remain pending.
