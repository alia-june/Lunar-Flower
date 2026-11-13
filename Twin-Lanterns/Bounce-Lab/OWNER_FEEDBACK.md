# Owner feedback and experiment scope

Feedback following Direction Lab, parent revision `70d45e0`:

> DDA is much darker is acting like nice occlusion March is brighter and as
> acting well as illumination it is a good mix, and the cardinal is really good
> both direction probes are distinct

This is qualitative owner-reported visual feedback. It supports preserving
Cardinal + DDA/March as the comparison baseline. It does not establish a physical
occlusion solver or certify another game/settings combination. The existing
composite remains additive; the darker appearance can arise from reduced added
light.

The next requested experiment adds distance/bounce energy loss and a broken or
chaotic sampler that drops/diminishes directions under unknown support. The
owner also raises color persistence and whether this work combines rendering
with perceptual simulation.

Bounce Lab implements one bounded current-frame extra gather and an explicit
artistic uncertainty experiment. Color anchoring uses the current first-light
field. It does not claim to implement temporal color memory, human vision,
measured hidden occlusion or full physically based global illumination.
