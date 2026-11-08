# Local shader development Mill

The existing Mill Factory is deployed in this task's cloud workspace at
`/workspace/shader-mill`. It was found through the user's GitHub frontdoor and
has completed a frozen-source Twin Lanterns baseline run. This is local
development tooling, not a hosted web service or a shader promotion.

Start with:

```bash
source /workspace/shader-mill/activate.sh
```

The detailed usage guide is `/workspace/shader-mill/README.md`. The working
copy is:

```text
/workspace/shader-mill/batches/twin-lanterns-development-2026-11-08/candidate/Lunar-Flower
```

Sources, candidates, evidence and packages are separate. Current production
shader files and upstream Mill/controller sources are unchanged. Existing
creation, verification and gate controllers retain request-bound receipts and
state outside their source checkout. The frontdoor's instrument-before-use
deployment rule was followed using these existing controllers.

## Pinned sources and runtime

| Component | Source identity |
| --- | --- |
| GitHub frontdoor | [this-repository-machine-interface, cdebc54](https://github.com/alia-june/this-repository-machine-interface/tree/cdebc54cb96a986a69c2880a2b3d98aab4296f47) |
| Mill and controllers | [xOSG-prototype, 545dbf4](https://github.com/alia-june/xOSG-prototype/tree/545dbf47c9ea33c09eb6e97d5536255344001cd5) |
| Shader baseline | [Lunar-Flower, 5b615ca](https://github.com/alia-june/Lunar-Flower/tree/5b615ca881a7d360a089f4ee81cdb5f3f8604f3d) |
| Runtime | [Official PowerShell 7.5.4](https://github.com/PowerShell/PowerShell/releases/tag/v7.5.4), Linux x64 |

The runtime archive was checked against Microsoft's release checksum:

```text
1fd7983fe56ca9e6233f126925edb24bf6b6b33e356b69996d925c4db94e2fef
```

PowerShell's XDG cache/config/data directories are bound beneath the local
Mill workspace because the cloud home directory is read-only. HOME is
preserved. The referenced m.A.R.S. template is retained as an unmodified
reference; local resource bindings and authority are recorded separately.

## Observed deployment results

| Check | Result |
| --- | --- |
| Factory controls | 10/10 pass |
| Creation controller | 12/13 pass; one Windows case-insensitive path test fails on Linux |
| Real batch creation | Admitted, created and structurally verified |
| Verification controller | 14/14 pass with an explicit batch fixture |
| Gate controller | 12/12 pass |
| Shader checks | 51 structural checks, 15 regression tests and three historical voxel comparisons pass |
| Package | One effect and all 11 shader/include files match current candidate bytes |
| Final batch verification | Structure, manifest and gate logic pass |

The Windows-specific test failure is retained, not patched or counted as
passing. Exact-case paths work in the deployed Linux workflow. An initial
verification test invocation had no fixture and skipped 14 cases; only the
later fully bound run is counted above.

The failure is tracked as [MILL-001](issues/MILL-001.md), with reproduction,
the retained log, expected platform behavior and resolution criteria. GitHub's
issue API returned `Forbidden`; this is a page-level issue record, not a
created upstream GitHub issue ticket.

The first batch has `PASS` for source freeze, candidate assembly, static
checks and packaging. Native compilation is `BLOCKED`, live game testing is
`PENDING`, and its decision remains `HOLD`. Offline compiler results from the
older uploaded Alpha are retained as historical evidence only.

## Continue shader work

Run the task-owned bounded harness with a fresh run ID:

```bash
python -B /workspace/shader-mill/batches/twin-lanterns-development-2026-11-08/harness/run_shader_checks.py --run-id next-check-001
```

The harness calls the existing repository checks and packager, retains logs
and a results record, verifies the ZIP, and refuses to overwrite an earlier
run. It does not compile with FXC/ReShade, execute a game, write gates or
promote. Later shader edits require new matching evidence and reviewed gate
updates; baseline evidence cannot validate changed bytes.

## Recreate in another workspace

1. Read the pinned frontdoor's `ai.landing.pad.low-mem.json`, `ai.ingress.json`,
   `ai.launch.pad.json`, systems deployment guide and `ai.egress.json`.
2. Check out the pinned xOSG revision. Read `mill-factory/HOW_TO.md` and the
   creation/verification/gate controller READMEs under `Instrumentation`.
3. Install PowerShell 7+ in a user-owned location. For the exact replay runtime,
   obtain the official 7.5.4 Linux x64 release archive and verify the hash above
   against the official `hashes.sha256` asset before extraction.
4. Bind the tool source, PowerShell launcher, output root and separate
   controller state roots for the receiving environment. Establish actual
   task authority; example authority JSON does not grant approval.
5. Run factory controls and controller tests with a real retained batch fixture.
   Record platform-specific failures and skipped cases separately.
6. Create a non-overwriting batch through the existing creation controller;
   import the exact shader source ZIP and historical inputs using Mill intake.
7. Copy frozen current source to the candidate area, run its checks and
   packager, and record each supported gate through the existing gate controller.
8. Verify the batch through the verification controller. Keep unavailable
   compiler/live evidence unresolved and leave promotion to its own decision.

Local runtimes, caches, state databases, source snapshots and generated
packages are intentionally not committed into the shader repository. This
setup did not publish or change the reusable cloud environment configuration.

## Subsequent shader experiment

The [Front Bias precision run](experiments/front-bias-precision.json) used a
separate non-overwriting batch at
`/workspace/shader-mill/batches/twin-lanterns-front-bias-2026-11-08`.
It retains the source freeze, working candidate, actual-function CPU probe,
check logs, package identity and controller receipts for the Alpha control
update. Native compilation remains blocked and live testing pending.

The [depth fade and light softening run](experiments/depth-shaping.json) adds
an Alpha-only light-field stage in
`/workspace/shader-mill/batches/twin-lanterns-depth-shaping-2026-11-08`.
Its 53 structural checks and 16 regression tests include 839 depth-shaping
assertions. The package is verified; native compilation and in-game acceptance
remain unresolved, and the batch stays on HOLD.

The [fade-usability correction](experiments/fade-usability.json) follows the
reported black mask and Final/Source match. It defaults the new shaping off,
clarifies the fade slider, and fixes partial fading being hidden by contribution
or channel-room caps. Its separate Mill batch retains the before-correction
diagnostic and 20,042 depth-shaping assertions; saved presets are not reset.
