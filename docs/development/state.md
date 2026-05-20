# chakshu — State

> **Status**: Active | **Last Updated**: 2026-05-20 (v0.6.0 cut — **M2.5 closed** (mihi integration); chakshu now shares the identity-probe layer with iam — and mihi v1.0 is unblocked)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.6.0** — **M2.5 closed.** mihi integration shipped; identity probes (hostname/kernel/distro/cpu_model/cpu_count/mem_total/mem_free/uptime/gpu_*) now flow through `lib/mihi.cyr`. Per-frame deltas stay chakshu-local. Unblocks mihi v1.0. |
| Cyrius toolchain pin | `6.0.1` (cyrius.cyml `[package].cyrius`) — bumped from 5.10.20 alongside the mihi dep wire-in. Matches host toolchain; no drift warning. |
| Genesis cycle | v6.0.x — toolchain rev fully adopted in chakshu |
| Active milestone | **M3 — AI integration** (daimon/hoosh; not started) |
| Next milestone | **M4 — Polish + perf** (binary size pressure is the priority — see Carry-Forward) |
| Binary | `shu` (build/shu) — System Health Utility, per ADR 0001 |
| Binary size (DCE) | 789 519 bytes (~772 KB) — text 588 255 + bss 201 264 + data 0. **+478 KB across M2.5** for the mihi + ai-hwaccel dep tree (ai-hwaccel ships the full GPU/NPU/TPU/AI-ASIC backend stack; chakshu uses only `registry_detect_no_exec()` but DCE NOPs without stripping). Design-spec §8 `<256 KB` target is now ~3× over — M4 carry-forward (either pressure Cyrius codegen for `--strip-dead` or pursue the `alloc()`-restructure that the build hint flags). |
| Lines of Cyrius | src/{main,snapshot,proc,processes,tui}.cyr (~1230 LoC) — minor uptick from M2.5 swap (~150 LoC of hand-rolled `/proc` reads replaced by 1-line mihi calls; +GPU panels in `-p` and TUI table mode). Does **not** include lib/{darshana,mihi,ai-hwaccel}.cyr (resolved via cyrius deps). |
| Test count | 57 assertions across 13 groups (TUI render path needs PTY-based testing — lands at Slice G) |
| `shu -p` wall time | ~110 ms (100 ms sample window + ~10 ms work). Roadmap gate `< 30 ms` work-budget met with 3× margin. |

## Dependency Envelope

Pinned in `cyrius.cyml [deps].stdlib`:

```
syscalls alloc fmt io fs str string vec
args chrono hashmap process tagged assert
```

**Not yet pulled**:

- **mihi** (consumed at v0.8.0) — system-info probe library. M2.5 integration complete; identity reads in chakshu's `-p` and TUI paths now go through `lib/mihi.cyr`. mihi v1.0 release is gated on this cut shipping; see CHANGELOG `[0.6.0]`.
- **ai-hwaccel** (consumed at v2.2.6, transitive via mihi) — accelerator detection backends called via mihi's no-exec API for the GPU panel.
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
| M2.5 | mihi integration | **Closed (v0.6.0)** — identity probes routed through mihi 0.8.0; toolchain bumped 5.10.20 → 6.0.1; GPU panel in `-p` and TUI table mode. Unblocks mihi v1.0. See CHANGELOG `[0.6.0]`. |
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
