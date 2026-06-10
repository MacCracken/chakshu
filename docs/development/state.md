# chakshu — State

> **Status**: Active | **Last Updated**: 2026-06-10 (v0.7.1 cut — toolchain + mihi v1.0 dep refresh; manifest pin realigned to the host wrapper at 6.1.27, mihi pin advanced to its v1.0 ship)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.7.1** — toolchain + dep refresh on the open AGNOS cycle. mihi pin advanced `0.8.0` → `1.0.0` (mihi's v1.0 ship — unblocked once chakshu, its gating consumer, integrated at 0.6.0); identity surface read through `lib/mihi.cyr` is unchanged. No behavior change at the chakshu surface. |
| Cyrius toolchain pin | `6.1.27` (cyrius.cyml `[package].cyrius`) — realigned to the host wrapper, which had drifted ahead of the stale `6.0.1` manifest pin. No source changes required by the rev. |
| Genesis cycle | v6.1.x — toolchain rev adopted; manifest pin now matches wrapper |
| Active milestone | **AGNOS build target** (cycle-opened at v0.7.0 — `shu` on AGNOS via mihi `uname`/`sysinfo` + the `klog` syscall kernel-log view; filtering delegated to agnsh `grep`) → then **M3 — AI integration** (daimon/hoosh; not started) |
| Next milestone | **M4 — Polish + perf** (binary size pressure is the priority — see Carry-Forward) |
| Binary | `shu` (build/shu) — System Health Utility, per ADR 0001 |
| Binary size | 798 040 bytes (~779 KB) — text 595 983 + bss 201 584 + data 0. DCE and non-DCE are byte-identical: DCE NOPs unreachable code but keeps `.bss`. ~+8 KB since 0.6.0 (AGNOS klog view + mihi 1.0.0 bytes). Design-spec §8 `<256 KB` target remains ~3× over — M4 carry-forward (pressure Cyrius codegen for `--strip-dead`, or pursue the `alloc()`-restructure the build hint flags for the 201 KB `.bss`). |
| Lines of Cyrius | src/{main,proc,processes,snapshot,tui}.cyr — 2 503 LoC (main 274 / proc 475 / processes 292 / snapshot 268 / tui 1 194). Growth since 0.6.0 from the AGNOS surface (klog kernel-log view) on top of the M2 TUI. Does **not** include lib/{darshana,mihi,ai-hwaccel}.cyr (resolved via cyrius deps). |
| Test count | 57 assertions across 13 groups (TUI render path needs PTY-based testing — lands at Slice G) |
| `shu -p` wall time | ~113 ms (100 ms sample window + ~13 ms work). Roadmap gate `< 30 ms` work-budget met with margin. |

## Dependency Envelope

Pinned in `cyrius.cyml [deps].stdlib` (22 modules — the parser needs the
full chain present for the concatenated dist bundles; DCE drops what the
linked binary doesn't reach):

```
syscalls alloc fmt io fs str string slice vec
args chrono hashmap process tagged assert
agnosys fnptr thread freelist ct json bench
```

**Git deps (pulled, in `lib/` via `cyrius deps`)**:

- **darshana** `0.7.0` — Linux TTY/raw-mode primitives (termios, ANSI, cursor). Powers the M2 TUI; chakshu has zero termios/ANSI code of its own. Already ecosystem-current at the 0.7.1 cut.
- **mihi** `1.0.0` — system-info probe library. Identity reads in chakshu's `-p` and TUI paths go through `lib/mihi.cyr` (hostname/kernel/distro/cpu_model/cpu_count/mem_total/mem_free/uptime/gpu_*). Per-frame deltas stay chakshu-local. Advanced `0.8.0` → `1.0.0` at v0.7.1 (mihi's v1.0 ship; same bundled surface).
- **ai-hwaccel** `2.2.6` (transitive via mihi) — accelerator-detection backends called via mihi's no-exec API for the GPU panel. **Pin tracks mihi's own `[deps.ai-hwaccel]` tag, not ai-hwaccel's latest** (2.3.x exists; mihi 1.0.0 still pins 2.2.6) — keeps the concatenated bundle ABI-consistent.

**Not yet pulled**:

- `net` (M2, stdlib) — `/proc/net` parsing for the network panel.
- `sandhi` (M3) — daimon/hoosh JSON-RPC transport.
- `niyama` (M3) — redaction patterns for AI-prompt assembly.

## Milestone Status

| M | Title | Status |
|---|-------|--------|
| M0 | Scaffold | **Gate cleared** — `cyrius deps`/`build`/`test` all green; `shu --version` / `--help` / `--watch` (placeholder) / unknown-flag paths exercised |
| M1 | Plain snapshot | **Closed (v0.2.0)** — all four slices landed. `shu -p` produces a header + memory + cpu/disk/net rates + sortable top-N process table with cmdline. Perf gate met. |
| M2 | Full TUI | **Closed (v0.5.0)** — Slices A–G.3 shipped across v0.2.1–v0.4.0; G.4 close audit (privacy/FFI/signals/buffers/perf) green. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code of its own. See CHANGELOG `[0.5.0]` for the M2 arc summary + audit findings. |
| M2.5 | mihi integration | **Closed (v0.6.0)** — identity probes routed through mihi 0.8.0; toolchain bumped 5.10.20 → 6.0.1; GPU panel in `-p` and TUI table mode. Unblocked mihi v1.0 (shipped; chakshu pin advanced to 1.0.0 at v0.7.1). See CHANGELOG `[0.6.0]`. |
| — | AGNOS build target | **Cycle open (v0.7.0)** — `shu` runs on AGNOS: stats via mihi `uname`/`sysinfo`, kernel-log view via the `klog` syscall (unified klug ring), filtering delegated to the agnsh `grep` builtin. Inline; no platform-abstraction layer yet. See CHANGELOG `[0.7.0]`. |
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
