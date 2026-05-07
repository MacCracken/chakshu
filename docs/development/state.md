# chakshu — State

> **Status**: Active | **Last Updated**: 2026-05-07 (M0 gate cleared)
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
| Active milestone | **M0 — Scaffold (gate cleared)** |
| Next milestone | **M1 — Plain snapshot (`-p`)** |
| Binary | `shu` (build/shu) — System Health Utility, per ADR 0001 |
| Binary size (DCE) | 85 208 bytes (~83 KB) — well under M4's 256 KB target |
| Lines of Cyrius | ~minimal skeleton (src/main.cyr only) |
| Test count | 10 assertions (1 group × smoke + string + version-shape) |

## Dependency Envelope

Pinned in `cyrius.cyml [deps].stdlib`:

```
syscalls alloc fmt io fs str string vec
args chrono hashmap process tagged assert
```

**Not yet pulled**:

- **TTY / raw mode** (M2) — termios is **not** stdlib and won't be added
  to the cyrius toolchain. Plan: on entering M2, extract `cyim/src/tty.cyr`
  (TCGETS/TCSETS, alt-screen, cursor, ANSI helpers; `cyrius-doom/src/input.cyr`
  is adjacent) into a new shared first-party repo rather than vendoring
  into `chakshu/lib/`. See roadmap M2 "Pre-M2 — TTY/termios lib extraction"
  for the rationale (second-consumer-drives-API). The original scaffold
  manifest's `termios` entry was a hallucination and broke `cyrius deps`
  until removed.
- `net` (M2, stdlib) — `/proc/net` parsing for the network panel.
- `sandhi` (M3) — daimon/hoosh JSON-RPC transport.
- `niyama` (M3) — redaction patterns for AI-prompt assembly.

## Milestone Status

| M | Title | Status |
|---|-------|--------|
| M0 | Scaffold | **Gate cleared** — `cyrius deps`/`build`/`test` all green; `shu --version` / `--help` / `--watch` (placeholder) / unknown-flag paths exercised |
| M1 | Plain snapshot | Not started |
| M2 | Full TUI | Not started |
| M3 | AI integration | Not started |
| M4 | Polish + perf | Not started |
| M5 | v1.0 ship | Not started |

## Carry-Forward

- ADR 0001 records the `shu` binary-name decision (with `ctop` considered and rejected) — closed; no re-litigation needed barring new namespace pressure on `shu`.
- Bazaar `htop` / `btop` recipes remain the user-facing default until M2 closes.
- The original scaffold's `cyrius.cyml` declared `time` (real name: `chrono`)
  and `termios` (does not exist in the toolchain). Both fixed; recorded
  here so the same hallucinated deps don't get re-introduced by a future
  refactor or scaffold pass.

## Cross-References

- Genesis: [agnosticos `state.md`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/state.md) (Cyrius cycle, ecosystem pin-lag)
- Registry: [agnosticos `shared-crates.md`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/shared-crates.md) — chakshu listed under Pre-1.0 Binaries & Tools
