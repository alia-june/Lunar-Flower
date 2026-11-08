# MILL-001: Windows path-case test fails on Linux

Status: **OPEN — recorded on the deployment page.**

Intended upstream tracker: `alia-june/xOSG-prototype` GitHub Issues.
GitHub GraphQL and REST issue reads, followed by the `gh issue create`
submission attempt, returned `Forbidden` in this cloud environment on
2026-11-08. No GitHub issue ticket was created, and no issue number is assigned.
This page retains the report for submission.

## Affected source

- Repository revision: `545dbf47c9ea33c09eb6e97d5536255344001cd5`.
- [Test: test_allowed_root_comparison_uses_windows_case_rules](https://github.com/alia-june/xOSG-prototype/blob/545dbf47c9ea33c09eb6e97d5536255344001cd5/Instrumentation/mill-controllers/creation/tests/test_controller.py#L161).
- [Controller: is_within](https://github.com/alia-june/xOSG-prototype/blob/545dbf47c9ea33c09eb6e97d5536255344001cd5/Instrumentation/mill-controllers/creation/controller.py#L86).
- Environment: Debian GNU/Linux 13, Python 3.12.14, PowerShell 7.5.4.

## Reproduce

With the Mill checkout and PowerShell bound in the environment:

```bash
export MILL_FACTORY_ROOT=/path/to/xOSG-prototype/mill-factory
python -B -m unittest discover \
  -s /path/to/xOSG-prototype/Instrumentation/mill-controllers/creation/tests \
  -p test_controller.py
```

In the deployed shader workspace, first source
`/workspace/shader-mill/activate.sh` to supply the runtime and tool bindings.

Observed suite result: **12 passed, 1 failed**. A separate invocation of only
the affected test reproduced the same failure on 2026-11-08.

```text
FAIL: test_allowed_root_comparison_uses_windows_case_rules
  File "Instrumentation/mill-controllers/creation/tests/test_controller.py", line 169
    self.assertEqual("permitted", receipt["admission"])
AssertionError: 'permitted' != 'not_permitted'
```

## Cause and expected behavior

The test uppercases the asserted allowed output root and unconditionally
expects admission. The controller uses `os.path.normcase`/`normpath` and
filesystem identity checks. On Linux, uppercasing a normal temporary path
names a different path; refusing that assertion is appropriate.

The test should account for filesystem/platform semantics. On a
case-sensitive filesystem it should verify that a differently cased,
non-identical root is refused. On the intended Windows case-insensitive
filesystem it should retain the equivalent-path admission check. Do not fix
this by unconditionally case-folding Linux paths in the controller.

## Impact and acceptance criteria

The unmodified creation test suite cannot report all cases passing on this
Linux deployment. Actual exact-case batch creation and structural verification
succeeded. Verification-controller checks passed 14/14, gate-controller checks
12/12, and factory controls 10/10. Those results do not erase this failure.

Suggested resolution:

1. Make the case-equivalence test conditional on the filesystem behavior being
   tested, or separate the Windows admission and case-sensitive refusal cases.
2. Retain outside-root and mismatched-authority refusal coverage.
3. Run the suite on Linux and Windows and retain the results separately.

No upstream test or runtime fix has been applied. The local workflow uses
exact-case paths. Shader native compilation and live testing remain separate
unresolved gates, unrelated to this test failure.

## Evidence

The [retained failure log](MILL-001-creation-controller-tests.log) is an exact
copy of the deployment's original 13-test output. The separate one-test
reproduction is described above. The deployment result remains in
[DEPLOYMENT_RESULT.json](../DEPLOYMENT_RESULT.json).
