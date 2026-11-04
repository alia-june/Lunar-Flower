# Twin Lanterns API

This directory is the versioned distribution point for Twin Lanterns' ReShade
FX include API. Each release is self-contained: documentation, a
machine-readable contract registry, integrity hashes, and the published shader
sources live together under the version that governs them.

## Releases

| Version | Status | Shared contract | Notes |
|---|---|---|---|
| [0.1.0](0.1.0/) | Public, pre-1.0 | Provider evidence, dual-provider transport, surface reconstruction, bounded composite | [Complete declaration reference](0.1.0/REFERENCE.md); downstream compile integration remains consumer-validated. |

## Version Selection

Pin integrations to a concrete directory such as `API/0.1.0`. Do not consume
an unversioned moving path. A breaking contract change will receive a new API
version and a migration note; published source payloads, stable contract
declarations, and hash inventories remain immutable. Documentation metadata may
expand without changing that contract.

The Full Resolution Dual Ray voxel-proxy extension is distributed with 0.1.0
for inspection, but remains explicitly experimental and outside the shared
stability promise.

Start with the [0.1.0 integration and architecture guide](0.1.0/README.md), then
use the [complete reference](0.1.0/REFERENCE.md) for field-by-field and
signature-level coverage.
