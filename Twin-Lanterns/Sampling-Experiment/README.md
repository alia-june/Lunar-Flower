# Twin Lanterns — Sampling Experiment 1

[Download Sampling Experiment 1](https://raw.githubusercontent.com/alia-june/Lunar-Flower/refs/heads/experiment/twin-lantern-sampling-1/downloads/Twin-Lanterns-Sampling-Experiment-1.zip)

A diagnostic comparison of first-hit sampling, continuous weighted sampling,
softer depth-derived normals, and both changes together. Four presets are
included. Bounce is disabled throughout; start with **01 Baseline versus
02 Smooth Sampling**, keeping the game's working depth configuration.

The effect is **Lunar Flower - Twin Lanterns: Local Sampling Experiment**.
Extract outside shader search paths and copy only `reshade-shaders` into the
game. Keep the installed `ReShade.fxh`. The archive README covers installation,
depth definitions, the comparisons and limitations.

ReShade 6.7.3 FX parsing and SM5 HLSL generation passed for all four variants;
39,403 CPU assertions passed. These checks do not establish native driver
compilation, game visuals or GPU timing. Smooth sampling substantially increases
texture work on supported surfaces. This is not a confirmed Phantom Brigade
seam fix or a replacement for Kriegsspinne Reference Build Candidate 1.

The shaders derive from Lunar Flower's own source and independently implemented
changes. GoldenWeave Redux informed the behavioral comparison; its source and
assets are not bundled. The original Lunar Flower license is included.

The archive includes a source manifest, change patch and validation records.
It excludes chat logs, screenshots, personal presets, credentials, repository
metadata, external framework headers and compiled test binaries.

[SHA-256 checksum](../../downloads/Twin-Lanterns-Sampling-Experiment-1.zip.sha256)
