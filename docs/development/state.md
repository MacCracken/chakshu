# chakshu — State

> **Status**: Active | **Last Updated**: 2026-07-17 (v0.7.11 cut — **interim toolchain/dep refresh**: Cyrius `6.2.37` → `6.4.66` (both manifests, resolving the wrapper pin drift), mihi `1.1.3` → `1.2.1` (both), `ai/` darshana `0.8.0` → `0.9.0` + niyama `1.0.5` → `1.0.6`. ai-hwaccel held at `2.2.6` (tracks mihi's transitive pin; latest is 2.3.14). Both builds + smoke green; lean `shu` shrank to ~0.48 MB. **New caveat:** `shu-ai` balloons ~2.27 → ~15.49 MB under the 6.4.66 codegen — a 13.48 MB static `.bss` from two oversized array locals promoted to shared globals in the sandhi/TLS chain (compiler, not deps); fixable only upstream, flagged for M4. Live hoosh path is still CI/real-box-only — sandhi dlopens libc.)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.7.11** — **interim toolchain/dep refresh** (no new feature surface). Cyrius pin `6.2.37` → `6.4.66` (both manifests, resolving the drift between the pin and the installed 6.4.66 wrapper); mihi `1.1.3` → `1.2.1` (both builds); `ai/` darshana `0.8.0` → `0.9.0` (lockstep with root, which advanced at 0.7.10) and niyama `1.0.5` → `1.0.6`. ai-hwaccel held at `2.2.6` (tracks mihi's transitive pin). Both builds compile clean and pass (lean 57, AI 13); smoke PASS. No chakshu source changes needed for the 6.2.37 → 6.4.66 jump. See the Binary-size row for the `shu-ai` size regression this cut surfaced. |
| Cyrius toolchain pin | `6.4.66` (both manifests) — bumped 6.2.37 → 6.4.66 at v0.7.11 to resolve the wrapper drift (pin was 6.2.37, installed cycc 6.4.66); no source changes needed. (History: 6.1.27→28 directory-style `lib/unicode/*.cyr`; 6.1.29→6.2.2 at v0.7.5; 6.2.24 at v0.7.6; 6.2.36 at v0.7.8; 6.2.37 at v0.7.9 — agnosys retired, rewired onto `sys`. `json`→`bayan` rename from 6.1.x still applies; `json`/`base64`/`bigint` folded into `bayan`.) |
| Genesis cycle | v6.4.x — toolchain rev adopted; both manifests pin 6.4.66 |
| Active milestone | **M3 — AI integration** (near done). 0.7.2 foundation; 0.7.3 live `--explain` + `?` overlay + lean/AI split; 0.7.4 hoosh 2.3.5 auth + SSE streaming + smoke gate; 0.7.5 interim 6.2.2/niyama-1.0.5 refresh; 0.7.6 interim 6.2.24/mihi-1.1.1/darshana-0.7.1 refresh. **Remaining: `--watch` + `--with-logs` (v0.7.7)**, then M3 closes. **Caveat:** the live hoosh path (sandhi HTTP) needs runtime libc (sandhi dlopens `getaddrinfo`/libssl) — so `shu-ai` is **not** a pure no-libc binary, and the transport can only be exercised on a libc host (CI/AGNOS), not the dev sandbox. Lean `shu` stays pure no-libc. |
| Next milestone | **M4 — Polish + perf** |
| Binary | **Two builds** (0.7.3 split): lean **`shu`** (build/shu, monitor only) and **`shu-ai`** (ai/build/shu-ai, +AI). System Health Utility, per ADR 0001. |
| Binary size | **Lean `shu`: ~0.48 MB** (495 512 B — bss 71 664), no AI deps — *shrank* from ~0.85 MB under the 6.4.66 codegen; well under btop's 1.7 MB install, beats htop once its ncurses/libc are counted. **`shu-ai`: ~15.49 MB** (15 489 136 B — up sharply from 0.7.6's ~2.85 MB). **Root cause is the 6.4.66 compiler, not the deps:** the same dep set built under a `6.2.37` pin is ~2.27 MB; under `6.4.66` it is ~15.49 MB. The 6.4.66 codegen promotes two *oversized array locals* in the sandhi/TLS chain into shared `.bss` globals (build note: *"oversized array local kept in shared global … exceeds per-fn stack budget; use alloc()"* ×2), yielding a **13.48 MB static `.bss`** (vs ~360 KB on 6.2.37); `.rodata` is laid out after it, so the file physically extends to ~15 MB (not sparse). DCE can't strip it (NOPs code, keeps `.bss`). Fix is upstream — sandhi/TLS stdlib buffers to `alloc()`, or a cycc codegen change. Filed for **M4**. Design-spec §8 `<256 KB` applies to the lean monitor (now ~1.9× over → M4: DCE/`--strip-dead`); `shu-ai` is explicitly the heavy opt-in. |
| Lines of Cyrius | Shared core src/{proc,processes,snapshot,tui,cli}.cyr + entries (main.cyr lean / ai/main.cyr) + ai.cyr (AI, ~370 LoC w/ live transport) / ai_stub.cyr (lean). Deps via cyrius deps (per-build lib/). |
| Test count | **Two suites**: monitor `tests/chakshu.tcyr` (57) + AI `ai/tests/chakshu-ai.tcyr` (13 — redaction / prompt / JSON marshalling). TUI render path still needs PTY-based testing. |
| `shu -p` wall time | ~113 ms (100 ms sample window + ~13 ms work). Roadmap gate `< 30 ms` work-budget met with margin. |

## Dependency Envelope

Two manifests since the 0.7.3 lean/AI split. The toolchain force-links every
declared stdlib module (DCE NOPs the unreached, keeps the bytes), so AI deps
are kept out of the lean manifest entirely.

**Lean `shu` — root `cyrius.cyml`** (monitor only, no libc):

- stdlib (22): `syscalls alloc fmt io fs str string slice vec args chrono hashmap process tagged assert sys fnptr thread freelist ct bayan bench`
- git deps: **darshana** `0.9.0` (TTY/raw-mode — chakshu has zero termios/ANSI of its own), **mihi** `1.2.1` (identity probes: hostname/kernel/distro/cpu/mem/uptime/gpu_* via `lib/mihi.cyr`), **ai-hwaccel** `2.2.6` (transitive via mihi; GPU panel; pin tracks mihi's own, not ai-hwaccel latest — mihi 1.2.1 still pins 2.2.6, though ai-hwaccel latest is 2.3.14).

**AI `shu-ai` — `ai/cyrius.cyml`** (= the lean deps **plus**):

- stdlib: `+ unicode` (directory-style module, `lib/unicode/*.cyr`; needs the 6.1.28+ resolver) `+` the sandhi chain (`async atomic regression mmap dynlib fdlopen net http tls ws sakshi sigil keccak thread_local`) `+ sandhi` itself.
- **sandhi** is consumed as a **stdlib module, not a git dep** — the folded-in toolchain copy compiles alongside `net.cyr`/`tls.cyr` so its bare socket/TLS constants resolve (the 6.1.21-built git dist could not). It's the hoosh HTTP transport and, under the 6.4.66 codegen, the source of the AI build's 13.48 MB static `.bss` (two oversized array locals promoted to shared globals — see the Binary-size row).
- git deps: `+` **niyama** `1.0.6` — re2 secret-redaction (`src/ai.cyr`); the bre/pcre/fuzzy/vim engines DCE-NOP. Pulls the `unicode` stdlib module.

**Not yet pulled / pending**:

- `--watch` (phylax/aegis event bus) + `--with-logs` (sakshi log context) transport — v0.7.7, in the AI build.
- The lean monitor's network panel still uses chakshu-local `/proc/net` parsing (no `net` stdlib dep needed there).

## Milestone Status

| M | Title | Status |
|---|-------|--------|
| M0 | Scaffold | **Gate cleared** — `cyrius deps`/`build`/`test` all green; `shu --version` / `--help` / `--watch` (placeholder) / unknown-flag paths exercised |
| M1 | Plain snapshot | **Closed (v0.2.0)** — all four slices landed. `shu -p` produces a header + memory + cpu/disk/net rates + sortable top-N process table with cmdline. Perf gate met. |
| M2 | Full TUI | **Closed (v0.5.0)** — Slices A–G.3 shipped across v0.2.1–v0.4.0; G.4 close audit (privacy/FFI/signals/buffers/perf) green. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code of its own. See CHANGELOG `[0.5.0]` for the M2 arc summary + audit findings. |
| M2.5 | mihi integration | **Closed (v0.6.0)** — identity probes routed through mihi 0.8.0; toolchain bumped 5.10.20 → 6.0.1; GPU panel in `-p` and TUI table mode. Unblocked mihi v1.0 (shipped; chakshu pin advanced to 1.0.0 at v0.7.1). See CHANGELOG `[0.6.0]`. |
| — | AGNOS build target | **Cycle open (v0.7.0)** — `shu` runs on AGNOS: stats via mihi `uname`/`sysinfo`, kernel-log view via the `klog` syscall (unified klug ring), filtering delegated to the agnsh `grep` builtin. Inline; no platform-abstraction layer yet. See CHANGELOG `[0.7.0]`. |
| M3 | AI integration | **Near done** — redaction + prompt assembly (v0.7.2); live `--explain` + `?` overlay via hoosh + lean/AI binary split (v0.7.3); SSE streaming + hoosh 2.3.5 bearer auth + `--explain` stub smoke (v0.7.4); interim 6.2.2/niyama-1.0.5 refresh (v0.7.5); interim 6.2.24/mihi-1.1.1/darshana-0.7.1 refresh (v0.7.6). **Remaining: `--watch` + `--with-logs` (v0.7.7) → then M3 closes.** Live path is CI/real-box-only (sandhi dlopens libc). |
| M4 | Polish + perf | Not started — size work now targets the **lean** monitor (design-spec §8 `<256 KB`, ~3.3× over); `shu-ai`'s ~2.6 MB is the accepted opt-in cost. |
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
