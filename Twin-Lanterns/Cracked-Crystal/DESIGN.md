# Spoke chain and temporal reuse

The intended per-pixel stage budgets are **3 → 2 → 1**. They are independent
gathers over full-screen light fields, not a recursively branching ray tree.

| Stage | Budget | Input | Status |
|---|---:|---|---|
| First gather | 3 primary spokes | Current scene color/depth and cached normals | Implemented |
| Second contribution | 2 opposing cached taps | Bounded first-light contribution only | Implemented |
| Third contribution | 1 cached tap | Second contribution only | Future experiment |

Each later field must contain only that stage's new contribution. Sampling a
combined first-plus-second image for the third stage would count earlier light
again. Apply retention and distance loss at each stage, then cap the sum against
the receiver's contribution ceiling and remaining source-channel room.

For the next stage, compare a single gated cached tap before considering a new
march. Preserve a zero-strength bypass, rejected-donor energy loss, explicit
base-LOD reads and current-frame source preservation. No unimplemented third
stage control is exposed in this build.

The current three-of-eight selection is fixed. A future rotating schedule can
cover eight directions over roughly three frames. Per-direction counts/weights
must account for the repeat because eight is not divisible by three.

Temporal reuse needs a separate experiment. Accumulate added light, validate
history using geometry and appearance, constrain its age/confidence, and test
camera movement/disocclusion. Reliable reprojection requires motion information
or a justified reconstruction; same-screen-position blending alone does not
track surfaces. Reject bad history per pixel, never by a global light cutoff.
Do not add exposure adaptation to conceal missing or rejected lighting.

Performance feedback so far concerns the previous normal-cache build: the
reported FPS penalty changed from about 40 to 20. Baseline FPS and per-effect
GPU milliseconds were not supplied, so this does not establish a 2x total-FPS
gain or a measured millisecond saving. Measure the next comparisons at the
same resolution, scene/camera and output view, preferably with effect GPU time.
