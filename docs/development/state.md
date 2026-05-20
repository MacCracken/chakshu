# chakshu — State

> **Status**: Active | **Last Updated**: 2026-05-19 (v0.5.0 cut — **M2 closed**; mihi integration is the next milestone)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.5.0** — **M2 closed.** Full interactive TUI shipped (Slices A–G.3) with close audit (G.4) green. Next bump: M2.5 mihi integration → 0.6.0 |
| Cyrius toolchain pin | `5.10.20` (cyrius.cyml `[package].cyrius`) — **drift**: host `cycc` is `6.0.1`; builds clean with warning. Pin bump scheduled for M2.5 (coordinates with the mihi dep wire-in). |
| Genesis cycle | v6.0.x — toolchain rev landed in agnosticos; chakshu still pinned to 5.10.20 |
| Active milestone | **M2.5 — mihi integration** (open; cuts as 0.6.0; unblocks mihi v1.0) |
| Next milestone | **M3 — AI integration** (daimon/hoosh) |
| Binary | `shu` (build/shu) — System Health Utility, per ADR 0001 |
| Binary size (DCE) | 299 276 bytes (~292 KB) — text 129 844 + bss 169 432. G.4 audit pinned the 183 → 293 KB jump across M2 to **Cyrius 5.10.20 → 6.0.1 codegen drift** (de-facto toolchain), not chakshu source: of 165 KB bss only ~8.3 KB is chakshu module-globals + darshana 60 bytes. M4 polish/perf needs to either renegotiate the design-spec §8 `<256 KB` target or restructure large static buffers via `alloc()` per the build hint. |
| Lines of Cyrius | src/{main,snapshot,proc,processes,tui}.cyr (~1200 LoC) — tui.cyr ~475 LoC after G.3 added `tui_render_focus_frame` + dispatcher. Does **not** include lib/darshana.cyr (resolved via cyrius deps from darshana 0.3.0). |
| Test count | 57 assertions across 13 groups (TUI render path needs PTY-based testing — lands at Slice G) |
| `shu -p` wall time | ~110 ms (100 ms sample window + ~10 ms work). Roadmap gate `< 30 ms` work-budget met with 3× margin. |

## Dependency Envelope

Pinned in `cyrius.cyml [deps].stdlib`:

```
syscalls alloc fmt io fs str string vec
args chrono hashmap process tagged assert
```

**Not yet pulled**:

- **mihi** (M2.5, first-party) — system-info probe library (hostname, uptime, meminfo, cpu count/arch/model, kernel, distro, gpu). At v0.8.0 with chakshu integration as its only remaining v1.0 gate. Wire-in coordinates with the 5.10.20 → 6.0.1 toolchain bump.
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
| M2 | Full TUI | **Closed (v0.5.0)** — Slices A–G.3 shipped across v0.2.1–v0.4.0; G.4 close audit (privacy/FFI/signals/buffers/perf) green. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code of its own. See CHANGELOG `[0.5.0]` for the M2 arc summary + audit findings. |
| M2.5 | mihi integration | **Open.** Bumps cyrius pin 5.10.20 → 6.0.1, wires `[deps.mihi]`, swaps hand-rolled hostname/uptime/meminfo/cpu_count reads to mihi probes, adds GPU panel (chakshu's first GPU surface). Cuts as v0.6.0 and unblocks mihi v1.0 (mihi's M6 gate). See roadmap. |
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
