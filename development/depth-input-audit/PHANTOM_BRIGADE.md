# Phantom Brigade — depth capture restored, horizon banding under investigation

## Confirmed owner outcome

The owner initially reported that GI produced no light while Lazara worked.
Combined Weighted Signal was black, Rejection Reason was red, and Depth Fade
Amount 0 did not restore light. The owner also reported unrelated third-party
depth effects failing or appearing reversed.

After the recommended Generic Depth capture checks—copy before clear and
selecting a scene depth buffer—the owner reported: **“boom that did it”**.
Record this as an owner-confirmed capture-configuration resolution of the
zero-light symptom. The report does not isolate which individual capture option
or buffer selection was decisive. It does not establish a universal Unity fix.
The probe's earlier numeric transcription was ambiguous; do not treat a
reported 1.9 as a confirmed raw/framework buffer measurement.

## Remaining observation

The owner reports slight banding in this geometrically sparse game. Eight
directions reduce it compared with four, and the remaining artifact appears
like a **center/horizon split**. No screenshot or frame capture has yet been
provided to establish its exact shape, location or movement.

Four cardinal and four diagonal modes each have 90-degree angular gaps; mixed
eight uses 45-degree gaps. At the same provider sample budgets, mixed eight
doubles scheduled traversal work in both gathers. Normalization divides by the
selected direction count; it does not multiply brightness by two. Added or
missing directional support can still change the mean admitted light, so a
less-visible band alone does not prove the sampling error was eliminated.

## Source review

- No intentional horizontal half-screen split was found in the production
  Provider Performance / Kriegsspinne display path. Source and final output
  operate over the full screen.
- Directions are globally aligned. DDA samples evenly spaced intervals;
  march already has stable per-pixel distance jitter. Both providers retain
  hard overlap, self-hit and depth-validity gates.
- Depth fade and distant softening depend on normalized depth. Their transition
  can follow the projected terrain/horizon rather than a fixed screen row.
- A sky/geometry boundary naturally changes receiver validity. It is not a
  capture error unless it disagrees with actual visible geometry or represents
  a misplaced screen/viewport boundary.
- A center/horizon description is insufficient to distinguish capture edges,
  depth/projection transitions, ray admission bands, reconstruction or the
  secondary gather. Do not introduce temporal/angular noise as a confirmed fix.

## Next discriminating views

1. With other effects disabled, inspect Source Image and the audit's full-screen
   Framework Linear Depth view. Look for a discontinuity unrelated to scene
   geometry, rather than treating the normal sky boundary as an error.
2. In Kriegsspinne inspect Combined Weighted Signal and Captured First Light
   (8x). Their first appearance of the split locates it before or after shaping.
3. Temporarily set Second Bounce Strength to 0 and compare. If the split clears,
   inspect Applied Second Bounce (8x); otherwise continue on the first pass.
4. Compare four/eight at matched provider budgets and record camera position,
   fade settings, actual added-light strength and GPU time. The equal-traversal
   eight-direction preset is a separate test because it reduces ray density.

Reference Build Candidate 1 shader code, defaults and download remain unchanged
by these investigation notes. The resolved input issue and unresolved banding
are separate outcomes.
