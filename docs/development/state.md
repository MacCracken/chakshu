# chakshu — State

> **Status**: Active | **Last Updated**: 2026-08-24 (v0.7.13 cut — **P-1 sweep**: audit, refactor, hardening, optimization, security, with repairs. Seven audit dimensions, every finding adversarially re-verified (10 of 58 refuted and dropped). Fixed 3 security defects (untrusted `/proc` bytes reaching the terminal and the LLM prompt; a redactor that missed `PASSWORD=` and every space-separated/JWT/AWS/URL credential; a kill confirm bypassable by typeahead) and 8 correctness defects, including a ~44 KB/frame leak that breached the §8 RSS budget in ~90 s and a `PROC_MAX` ceiling that hid the busiest process on >1024-proc hosts. Tests lean 64→77, AI 13→21, PTY 7→9. **Open:** the lean binary is ~3.4× over the §8 size target and its biggest size lever is upstream-blocked.)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.7.13** — **P-1 sweep** (audit / refactor / hardening / optimization / security + repairs). No new feature surface. 11 defects repaired across `proc.cyr`, `processes.cyr`, `snapshot.cyr`, `tui.cyr`, `ai.cyr`, `cli.cyr`; 3 of them security (terminal/prompt injection via attacker-controlled `/proc` bytes, secret-redaction misses, kill-confirm typeahead bypass). Toolchain and all dep pins unchanged from 0.7.12. Both builds green: lean **77**, AI **21**, smoke PASS, PTY **9/9**, DCE parity PASS, lint 0 non-cosmetic. See CHANGELOG `[0.7.13]` for the full list and for what was deliberately deferred. |
| Cyrius toolchain pin | `6.5.35` (both manifests) — bumped 6.4.66 → 6.5.35 at v0.7.12 to resolve the wrapper drift (pin was 6.4.66, installed cycc 6.5.35); no source changes needed. The full 6.4.66 → 6.5.35 stdlib file-list diff is **two additions, zero removals** (`async_macos.cyr`, `thread_macos.cyr`); every module both manifests declare still resolves by name, `unicode` is still directory-style, and `sandhi` is still folded in as `lib/sandhi.cyr` (1.9.0 → 1.9.10, public fn surface 836 → 836). (History: 6.1.27→28 directory-style `lib/unicode/*.cyr`; 6.1.29→6.2.2 at v0.7.5; 6.2.24 at v0.7.6; 6.2.36 at v0.7.8; 6.2.37 at v0.7.9 — agnosys retired, rewired onto `sys`; 6.4.66 at v0.7.11. `json`→`bayan` rename from 6.1.x still applies; `json`/`base64`/`bigint` folded into `bayan`.) **6.5.28 changed `cyrius fmt` to rewrite files in place** (`--check` is the safe form) — nothing in CI invokes it; don't add a bare `cyrius fmt`. |
| Genesis cycle | v6.5.x — toolchain rev adopted; both manifests pin 6.5.35 |
| Active milestone | **M3 — AI integration** (near done). 0.7.2 foundation; 0.7.3 live `--explain` + `?` overlay + lean/AI split; 0.7.4 hoosh 2.3.5 auth + SSE streaming + smoke gate; 0.7.5 interim 6.2.2/niyama-1.0.5 refresh; 0.7.6 interim 6.2.24/mihi-1.1.1/darshana-0.7.1 refresh. **Remaining: `--watch` + `--with-logs` (v0.7.7)**, then M3 closes. **Caveat:** the live hoosh path (sandhi HTTP) needs runtime libc (sandhi dlopens `getaddrinfo`/libssl) — so `shu-ai` is **not** a pure no-libc binary, and the transport can only be exercised on a libc host (CI/AGNOS), not the dev sandbox. Lean `shu` stays pure no-libc. |
| Next milestone | **M4 — Polish + perf** |
| Binary | **Two builds** (0.7.3 split): lean **`shu`** (build/shu, monitor only) and **`shu-ai`** (ai/build/shu-ai, +AI). System Health Utility, per ADR 0001. |
| Binary size | **Lean `shu`: ~0.86 MB** (861 448 B, `.bss` 145 080) — up ~4 KB from 0.7.12 for the sweep's repairs. Against design-spec §8's `< 256 KB` that is **~3.4× over**. A measured size plan exists (424 784 B, −50.4%) but its largest single item — dropping `bayan`, −353 624 B — is **upstream-blocked**: `cyrius deps` re-vendors it from ai-hwaccel's `dist/*.deps` sidecar no matter what this manifest says, and ai-hwaccel must first move `profile_from_json*` behind a profile. Even the full sweep leaves the lean monitor ~1.66× over, so §8 needs revising or taking upstream. Note `CYRIUS_DCE=1` is a **parity check, not an optimizer** since cycc 6.5.16 — it NOPs dead code in place and emits a byte-identical binary. The 0.7.13 sweep also deliberately **forfeited a −57 344 B saving** (shrinking `_tui_filtered_idx` to `[1024]`) to raise `PROC_MAX` to 8192 instead; correctness on server hosts beat binary size. **`shu-ai`: ~3.17 MB** (3 174 912 B), up ~4 KB for the widened redactor. |
| Lines of Cyrius | Shared core src/{proc,processes,snapshot,tui,cli}.cyr + entries (main.cyr lean / ai/main.cyr) + ai.cyr (AI, ~370 LoC w/ live transport) / ai_stub.cyr (lean). Deps via cyrius deps (per-build lib/). |
| Test count | **Two suites**: monitor `tests/chakshu.tcyr` (**77**) + AI `ai/tests/chakshu-ai.tcyr` (**21**), plus the PTY suite at **9** scenarios. Grew 64→77 / 13→21 / 7→9 in the 0.7.13 sweep; every added assertion was checked non-vacuous by mutation (reverting its fix must fail it). TUI render path is still the least-covered surface. |
| `shu -p` wall time | ~112 ms (100 ms sample window + ~12 ms work), unchanged at v0.7.13 — the sweep's sort rewrite and leak fix did not move it at this box's 281 processes; both matter at scale. Roadmap gate `< 30 ms` work-budget met with margin. |

## Dependency Envelope

Two manifests since the 0.7.3 lean/AI split. The toolchain force-links every
declared stdlib module (DCE NOPs the unreached, keeps the bytes), so AI deps
are kept out of the lean manifest entirely.

**Lean `shu` — root `cyrius.cyml`** (monitor only, no libc):

- stdlib (23): `syscalls alloc fmt io fs str string slice vec args chrono hashmap process tagged assert sys fnptr sakshi thread freelist ct bayan bench`
- `sakshi` added at v0.7.12. It is **genuinely reachable** in the lean build — `src/snapshot.cyr` and `src/tui.cyr` call `mihi_gpu_count()` unconditionally, which routes through mihi 1.2.4's `SK_WARN` clamp — so DCE cannot drop it. It also arrives transitively via the `dist/*.deps` sidecars mihi 1.2.4 / ai-hwaccel 2.3.18 newly ship, making the entry redundant under cyrius ≥ 6.5.30 and **measured byte-neutral (857 136 B either way)**; it is declared as intent-documentation and as insurance against a toolchain below 6.5.30. Pure-syscall — the no-libc rule holds (`readelf -d build/shu`: no dynamic section).
- `bayan` is a **parse-time leaf** declared by the dist sidecars — *not*, as the manifest comment claimed until v0.7.12, because "the bundle calls `bayan_json_get`". ai-hwaccel calls no bayan function at all.
- git deps: **darshana** `1.0.0` (TTY/raw-mode — chakshu has zero termios/ANSI of its own; v1.0 **API freeze**, so the 15 symbols chakshu uses are contractually stable and 1.x minors need no diff read), **mihi** `1.2.4` (identity probes: hostname/kernel/distro/cpu/mem/uptime/gpu_* via `lib/mihi.cyr`), **ai-hwaccel** `2.3.18` (transitive via mihi; GPU panel; pin tracks **mihi's own** tag, not ai-hwaccel latest — mihi 1.2.4 pins 2.3.18, so the four-cut hold at 2.2.6 ended here. **The two must move in lockstep**: 2.3.18 against mihi 1.2.1 compiles but leaks `detect: profiles=N` to stderr mid-frame).

**AI `shu-ai` — `ai/cyrius.cyml`** (= the lean deps **plus**):

- stdlib: `+ unicode` (directory-style module, `lib/unicode/*.cyr`; needs the 6.1.28+ resolver) `+` the sandhi chain (`async atomic regression mmap dynlib fdlopen net http tls ws sigil keccak thread_local`) `+ sandhi` itself. (`sakshi` is now in the lean list too, so it is no longer an AI-only entry.)
- **sandhi** is consumed as a **stdlib module, not a git dep** — the folded-in toolchain copy compiles alongside `net.cyr`/`tls.cyr` so its bare socket/TLS constants resolve (the 6.1.21-built git dist could not). It's the hoosh HTTP transport; folded version 1.9.0 → 1.9.10 at v0.7.12, public fn surface 836 → 836, and all 8 entry points `src/ai.cyr` calls are unchanged in name and arity. **It was never the source of the 13.48 MB `.bss`** — that was sigil's banked crypto globals; see the Binary-size row.
- git deps: `+` **niyama** `1.0.7` — re2 secret-redaction (`src/ai.cyr`); the bre/pcre/fuzzy/vim engines DCE-NOP. Pulls the `unicode` stdlib module. **Hazard for a future cut:** cyrius 6.5.30 folded niyama 1.0.7 into the stdlib, so a `lib/niyama.cyr` toolchain module now exists at the very version this git dep pins. No conflict today (`niyama` is deliberately absent from `[deps].stdlib`), but it must never be consumed both ways at once — that would put two definitions of every `niyama_*` symbol in the closure.

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
| M4 | Polish + perf | Not started. **Size work targets the lean monitor** (design-spec §8 `< 256 KB`, now ~3.3× over at 857 136 B). The 0.7.11 `shu-ai` bloat item is **closed** — cyrius 6.5.22 reclaimed sigil's banked crypto `.bss` and the AI build fell to ~3.02 MB, an accepted opt-in cost. The lean regression is now upstream-shaped too: cycc 6.5.16 emits every declared stdlib module and `CYRIUS_DCE=1` no longer removes anything, so a chakshu-side fix means trimming declared modules, not more DCE. (The signalfd-teardown leak formerly carried here was **fixed post-0.7.12** — see CHANGELOG `[Unreleased]` / the v0.7.13 sweep.) |
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
