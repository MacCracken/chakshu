# chakshu — State

> **Status**: Active | **Last Updated**: 2026-05-10 (v0.2.3 cut — Slice E.5 filter mode ships)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.2.3** — M2 in-progress checkpoint (Slices A+B+C+D+E+E.5 + filter cmdline fix); next minor (0.5.0) cuts at M2 close |
| Cyrius toolchain pin | `5.10.20` (cyrius.cyml `[package].cyrius`) — bumped from 5.9.32 alongside the darshana v0.1.0 scaffold |
| Genesis cycle | v5.9.x — niyama-fold opener / catchup arc |
| Active milestone | **M2 — Full TUI** (Slice A landed; B–G pending) |
| Next milestone | **M3 — AI integration** |
| Binary | `shu` (build/shu) — System Health Utility, per ADR 0001 |
| Binary size (DCE) | 187 168 bytes (~183 KB) — was 148 KB at Slice A; +39 KB for the tui_render_frame data-gather/render path |
| Lines of Cyrius | src/{main,snapshot,proc,processes,tui}.cyr (~1050 LoC) — does **not** include lib/darshana.cyr (resolved via cyrius deps from darshana 0.2.0). tui.cyr ~325 LoC includes ~150 LoC of M1-snapshot duplication marked as future-refactor candidate. |
| Test count | 57 assertions across 13 groups (TUI render path needs PTY-based testing — lands at Slice G) |
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
| M2 | Full TUI | **In progress** — Slices A (alt-screen + raw mode + q/Ctrl-C) + B (exit-signalfd cleanup) + C (1Hz render loop + `--rate`) + D (SIGWINCH + dynamic window size) + E (↑/↓ select + `s` sort cycle + reverse-video highlight + viewport scrolling) + E.5 (filter mode `f` + bottom status line) ✓; Slices F (kill+confirm), G (--pid + color + PTY smoke + close) pending. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code of its own. |
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
