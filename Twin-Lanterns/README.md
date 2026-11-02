# Twin Lanterns

Twin Lanterns is Lunar Flower's bounded screen-space indirect-light family for
ReShade. The project favors visible evidence and controlled reconstruction over
unbounded brightness or hidden temporal state.

## Processing Model

```text
Back buffer + depth
        |
Four-direction donor transport
        |
Horizontal surface resolve
        |
Vertical surface resolve
        |
Depth-aware full-resolution reconstruction
        |
Optional same-surface edge fill
        |
Bounded additive composite
```

The composite cannot subtract from the source image. Added RGB is constrained
by `Maximum Added Light` and by the unused room in each normalized output
channel.

## Builds

### Stable 1.4

[Stable-1.4](Stable-1.4/) is the fixed baseline. It retains the original Camera
Obscura public identifiers for preset compatibility and includes optional Edge
Ink and same-surface Edge Fill.

### Fidelity Overdrive

[Fidelity-Overdrive](Fidelity-Overdrive/) is a separately named public
candidate. It adds two independent rendering-intent controls:

- **Fidelity Guard** aligns indirect light toward the receiver's existing color
  direction and reduces pressure near occupied highlights.
- **Overdrive** raises requested energy from `1x` to `3x` before the existing
  hard contribution and channel-room limits.

Both controls may run together. At zero/zero, their intent stage reproduces the
pre-overdrive path.

## Shared Architecture

Both builds use the same eight Camera Obscura API and header files. The
Fidelity Overdrive publication refactors only its public effect identity and
post-reconstruction intent stage; the shared transport, reconstruction, and
bounded composite contracts remain source-identical.

The denoiser is deliberately absent. Run external denoising or stabilization as
a separate ReShade technique so Twin Lanterns remains inspectable and can be
disabled without retaining history.

## Installation

Choose one build, then merge its `reshade-shaders` directory into the target
ReShade installation. The effect expects the installation's working
`ReShade.fxh` and a usable depth buffer.

Stable technique:

```text
Camera Obscura - Twin Lantern
```

Fidelity Overdrive technique:

```text
Lunar Flower - Twin Lanterns: Fidelity Overdrive
```

## Validation Boundary

The repository validator confirms local include closure, initialized public
controls, diagnostic coverage, pass order, source/channel bounds, edge-fill
behavior, absence of active denoiser resources, and unchanged shared APIs.

It does not establish full ReShade compilation, game-specific depth behavior,
acceptable frame time, or visual acceptance. Those remain live gates described
inside each build.

## Development Rules

- Preserve the fixed baseline unless a change is explicitly promoted.
- Add experiments beside Stable rather than silently replacing it.
- Keep source observations, generated implementation, validation, and human
  acceptance distinguishable.
- Preserve the MIT license and authorship notice in distributions.
