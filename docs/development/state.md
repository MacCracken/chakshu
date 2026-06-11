# chakshu — State

> **Status**: Active | **Last Updated**: 2026-06-10 (v0.7.2 cut — **M3 foundation**: `--explain` redacted-context preview + niyama-driven secret redaction; toolchain → 6.1.28, niyama 1.0.4 + `unicode` wired)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.7.2** — **M3 foundation.** `--explain <PID>` and the TUI `?` key are wired; both assemble a **privacy-redacted context** (process facts the user can already see + niyama-driven secret-value redaction of the cmdline) and print/point at it. The live daimon JSON-RPC call + streamed answer land at 0.7.3; `--watch` / `--with-logs` at 0.7.4. New module `src/ai.cyr`. |
| Cyrius toolchain pin | `6.1.28` (cyrius.cyml `[package].cyrius`) — bumped from 6.1.27 because 6.1.28's dep resolver handles **directory-style stdlib modules** (`lib/unicode/*.cyr`); 6.1.27 errored `cannot read ./lib/unicode.cyr` when pulling `unicode` for niyama. No source change from the rev itself. (`json`→`bayan` rename from 6.1.x still applies.) |
| Genesis cycle | v6.1.x — toolchain rev adopted; manifest pin matches wrapper (6.1.28) |
| Active milestone | **M3 — AI integration** (foundation landed v0.7.2: redaction + prompt assembly + `--explain`/`?` plumbing). Remaining: live daimon/hoosh transport + streamed overlay (0.7.3); `--watch` anomaly stream + `--with-logs` sakshi context (0.7.4). |
| Next milestone | **M4 — Polish + perf** (binary size pressure is now acute — see Binary size + Carry-Forward) |
| Binary | `shu` (build/shu) — System Health Utility, per ADR 0001 |
| Binary size | **1 447 150 bytes (~1.38 MB)** — text 1 182 614 + bss 264 536 + data 0. **Over the relaxed `< 1 MB` M4 budget.** The +~565 KB jump from 0.7.1 (861 KB) is niyama's bundle (~248 KB, 5 regex engines — chakshu uses only re2) plus the `unicode` data tables (~350 KB) its re2 engine hard-references (`unicode_category` / `unicode_to_lower` / `NFD`/`NFC`). DCE NOPs the unused engines but keeps their bytes. **M4 decision pending**: pursue real `--strip-dead` of the unused niyama engines + unicode tables, or revert redaction to a chakshu-local matcher (no niyama dep). Design-spec §8 `<256 KB` is now ~5.5× over. |
| Lines of Cyrius | src/{main,proc,processes,snapshot,tui,ai}.cyr — 2 884 LoC (ai.cyr +331 for the M3 foundation). Does **not** include lib/{darshana,mihi,ai-hwaccel,niyama}.cyr (resolved via cyrius deps). |
| Test count | 65 assertions across 15 groups (+8 at 0.7.2: exact-output redaction cases + prompt-assembly shape). TUI render path still needs PTY-based testing. |
| `shu -p` wall time | ~113 ms (100 ms sample window + ~13 ms work). Roadmap gate `< 30 ms` work-budget met with margin. |

## Dependency Envelope

Pinned in `cyrius.cyml [deps].stdlib` (23 modules — the parser needs the
full chain present for the concatenated dist bundles; DCE drops what the
linked binary doesn't reach):

```
syscalls alloc fmt io fs str string slice vec
args chrono hashmap process tagged assert
agnosys fnptr thread freelist ct bayan bench
unicode
```

`unicode` (added v0.7.2) is a **directory-style** stdlib module
(`lib/unicode/*.cyr`) — required by niyama's re2/fuzzy engines and only
resolvable by the 6.1.28+ dep resolver.

**Git deps (pulled, in `lib/` via `cyrius deps`)**:

- **darshana** `0.7.0` — Linux TTY/raw-mode primitives (termios, ANSI, cursor). Powers the M2 TUI; chakshu has zero termios/ANSI code of its own. Already ecosystem-current at the 0.7.1 cut.
- **mihi** `1.0.0` — system-info probe library. Identity reads in chakshu's `-p` and TUI paths go through `lib/mihi.cyr` (hostname/kernel/distro/cpu_model/cpu_count/mem_total/mem_free/uptime/gpu_*). Per-frame deltas stay chakshu-local. Advanced `0.8.0` → `1.0.0` at v0.7.1 (mihi's v1.0 ship; same bundled surface).
- **ai-hwaccel** `2.2.6` (transitive via mihi) — accelerator-detection backends called via mihi's no-exec API for the GPU panel. **Pin tracks mihi's own `[deps.ai-hwaccel]` tag, not ai-hwaccel's latest** (2.3.x exists; mihi 1.0.0 still pins 2.2.6) — keeps the concatenated bundle ABI-consistent.
- **niyama** `1.0.4` (added v0.7.2) — regex engines. chakshu uses only the **re2** surface (`niyama_re2_compile`/`_search`/`_group_*`) in `src/ai.cyr` for §6.2 secret redaction; the bre/pcre/fuzzy/vim engines DCE-NOP. First niyama tag built on 6.1.27+; pulls the `unicode` stdlib module. **Carries the bulk of the 0.7.2 size jump** — see Binary size.

**Not yet pulled**:

- `net` (M2, stdlib) — `/proc/net` parsing for the network panel.
- `sandhi` (M3, 0.7.3) — daimon/hoosh JSON-RPC transport for the live `--explain` call.
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
