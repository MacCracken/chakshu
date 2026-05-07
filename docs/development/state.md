# chakshu — State

> **Status**: Active | **Last Updated**: 2026-05-07
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.1.0** |
| Cyrius toolchain pin | `5.9.32` (cyrius.cyml `[package].cyrius`) |
| Genesis cycle | v5.9.x — niyama-fold opener / catchup arc |
| Active milestone | **M0 — Scaffold** |
| Next milestone | **M1 — Plain snapshot (`-p`)** |
| Binary | `shu` (build/shu) — System Health Utility, per ADR 0001 |
| Binary size (DCE) | n/a — no real code yet |
| Lines of Cyrius | ~minimal skeleton |
| Test count | 1 smoke test |

## Dependency Envelope

Pinned in `cyrius.cyml [deps].stdlib`:

```
syscalls alloc fmt io fs str string vec
args time termios hashmap process tagged assert
```

**Not yet pulled** (planned for M3): `net` (stdlib), `sandhi` (daimon transport), `niyama` (redaction patterns).

## Milestone Status

| M | Title | Status |
|---|-------|--------|
| M0 | Scaffold | **In progress** (this file is part of M0) |
| M1 | Plain snapshot | Not started |
| M2 | Full TUI | Not started |
| M3 | AI integration | Not started |
| M4 | Polish + perf | Not started |
| M5 | v1.0 ship | Not started |

## Carry-Forward

- ADR 0001 records the `shu` binary-name decision (with `ctop` considered and rejected) — closed; no re-litigation needed barring new namespace pressure on `shu`.
- Bazaar `htop` / `btop` recipes remain the user-facing default until M2 closes.

## Cross-References

- Genesis: [agnosticos `state.md`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/state.md) (Cyrius cycle, ecosystem pin-lag)
- Registry: [agnosticos `shared-crates.md`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/shared-crates.md) — chakshu listed under Pre-1.0 Binaries & Tools
