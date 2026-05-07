# chakshu — State

> **Status**: Active | **Last Updated**: 2026-05-07 (M1 closed; v0.2.0 cut)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.2.0** |
| Cyrius toolchain pin | `5.9.32` (cyrius.cyml `[package].cyrius`) |
| Genesis cycle | v5.9.x — niyama-fold opener / catchup arc |
| Active milestone | **M1 — Plain snapshot** ✓ closed |
| Next milestone | **M2 — Full TUI** |
| Binary | `shu` (build/shu) — System Health Utility, per ADR 0001 |
| Binary size (DCE) | 141 488 bytes (~138 KB) — was 85 KB at M0; +53 KB for proc/snapshot/processes + chrono/hashmap/vec |
| Lines of Cyrius | src/{main,snapshot,proc,processes}.cyr (~800 LoC) |
| Test count | 57 assertions across 13 groups |
| `shu -p` wall time | ~110 ms (100 ms sample window + ~10 ms work). Roadmap gate `< 30 ms` work-budget met with 3× margin. |

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
| M1 | Plain snapshot | **Closed (v0.2.0)** — all four slices landed. `shu -p` produces a header + memory + cpu/disk/net rates + sortable top-N process table with cmdline. Perf gate met. |
| M2 | Full TUI | Not started |
| M3 | AI integration | Not started |
| M4 | Polish + perf | Not started |
| M5 | v1.0 ship | Not started |

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — build, lint, test, smoke, DCE parity, security scan, docs + version consistency |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml, version-verify against tag, build matrix (x86_64-linux), source tarball, GH release with body from CHANGELOG section |
| Smoke test | `scripts/smoke.sh` — 17 gates over M0+M1 surface, run by both CI and locally pre-commit |
| Cutting a release | Bump VERSION + CHANGELOG section + `CHAKSHU_VERSION` literal in `src/main.cyr`, push tag `vX.Y.Z` (or `X.Y.Z`); release.yml takes over. Pre-1.0 tags publish as GH prerelease automatically. |

Patterned on owl's CI/release flow. Differences: no fuzz/bench/PTY
harnesses (chakshu has none), aarch64 target deferred until a real
consumer asks (AGNOS targets both arches, but no current user runs
chakshu on aarch64).

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
