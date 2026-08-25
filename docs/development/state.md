# chakshu — State

> **Status**: Active | **Last Updated**: 2026-08-24 (v0.9.2 — **theming + display polish**. New `--theme dark|light|auto`: the light palette substitutes the three ANSI attributes that genuinely fail on a white ground (yellow→magenta, cyan→blue, dim→normal) while keeping green/red identical so band semantics do not shift between themes. `--color auto` **was a synonym for `always`** — three values parsed, two behaviours — and now honours `NO_COLOR`, `TERM`, and whether **stdout** is a TTY. Both are asserted on the wire by PTY scenarios 13/14. PTY suite 12 → **14**.)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.9.4** — v1.0 readiness. Security audit PASS ([`docs/audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md)): 4 surfaces, 38 raised, **14 confirmed**, 24 refuted; two HIGH (`--watch` silently dropped 23.7% of security events; `$CHAKSHU_LOG_PATH` put the process environment into the AI prompt). `--rate` accepts fractional Hz (0.2-10) via integer millihertz — htop's 1.5 s and btop's 2 s defaults are finally expressible. Swap/cached/buffers shipped (2 of the 6 design-spec §1 features that were in scope since M0 and never implemented). New gates: literal-length (CI), `--agnos` compile (CI), `--version` vs VERSION (smoke). **AGNOS process table is blocked on a cyrius release carrying `SYS_PROCLIST`** — agnos 1.56.47 minted `#99 proclist`. |
| Cyrius toolchain pin | `6.5.35` (both manifests) — bumped 6.4.66 → 6.5.35 at v0.7.12 to resolve the wrapper drift (pin was 6.4.66, installed cycc 6.5.35); no source changes needed. The full 6.4.66 → 6.5.35 stdlib file-list diff is **two additions, zero removals** (`async_macos.cyr`, `thread_macos.cyr`); every module both manifests declare still resolves by name, `unicode` is still directory-style, and `sandhi` is still folded in as `lib/sandhi.cyr` (1.9.0 → 1.9.10, public fn surface 836 → 836). (History: 6.1.27→28 directory-style `lib/unicode/*.cyr`; 6.1.29→6.2.2 at v0.7.5; 6.2.24 at v0.7.6; 6.2.36 at v0.7.8; 6.2.37 at v0.7.9 — agnosys retired, rewired onto `sys`; 6.4.66 at v0.7.11. `json`→`bayan` rename from 6.1.x still applies; `json`/`base64`/`bigint` folded into `bayan`.) **6.5.28 changed `cyrius fmt` to rewrite files in place** (`--check` is the safe form) — nothing in CI invokes it; don't add a bare `cyrius fmt`. |
| Genesis cycle | v6.5.x — toolchain rev adopted; both manifests pin 6.5.35 |
| Active milestone | **M5 — v1.0 ship** (distribution, not features). M3 closed at **v0.8.2** (`--watch` v0.8.0, `--with-logs` v0.8.1, AI hardening + hoosh gate promotion v0.8.2). M4 closed across **v0.9.0-0.9.3** (perf/size close-out, GPU depth, theming, AGNOS parity). What remains for 1.0.0 is registry promotion, an agnosticos docs page, a zugot recipe and the announcement — **plus the v1.0 criteria now published in [roadmap.md](roadmap.md), of which two are unmet (CLI contract doc, security audit) and two partial (benchmarks artifact, downstream-consumer definition)**. ⛔ The milestone premise itself is under review: see the decision block in roadmap.md — on AGNOS the process table is necessarily empty and `shu-ai` cannot run, so "AGNOS default AI-augmented monitor" is not currently true on AGNOS. |
| Next milestone | **M4 — Polish + perf** |
| Binary | **Two builds** (0.7.3 split): lean **`shu`** (build/shu, monitor only) and **`shu-ai`** (ai/build/shu-ai, +AI). System Health Utility, per ADR 0001. |
| Binary size | **Lean `shu`: 640,216 B** (AGNOS target: 633,840 B) against design-spec §8's **revised < 768 KB** target — met, with headroom. (History: 861,536 B at 0.7.13 → 571,480 B at 0.7.14 once the bayan monolith left the closure → 622 KB after `--watch` and the 0.9.0 render work; 636 KB after the 0.9.1 GPU and 0.9.3 AGNOS-input work; 640 KB at 0.9.4 with the audit fixes and fractional --rate.) The old 256 KB figure was set at M0 before chakshu took its dependencies and is unreachable while the lean build links mihi + ai-hwaccel; ~25 KB of safe stdlib drops remain and `CYRIUS_DCE=1` emits a byte-identical binary, so the rest is upstream bundle bulk. **`shu-ai`: 3,256,448 B**, explicitly out of scope as the opt-in heavy build. |
| Lines of Cyrius | Shared core src/{proc,processes,snapshot,tui,cli}.cyr + entries (main.cyr lean / ai/main.cyr) + ai.cyr (AI, ~370 LoC w/ live transport) / ai_stub.cyr (lean). Deps via cyrius deps (per-build lib/). |
| Test count | **Two suites**: monitor `tests/chakshu.tcyr` (**130**) + AI `ai/tests/chakshu-ai.tcyr` (**39**), plus the PTY suite at **14** scenarios and, for the AGNOS target, `tests/agnos_qemu.py` at **17** checks (boots the `--agnos` build on a real AGNOS kernel under QEMU; host-dependent, so it skips rather than gates CI). Grew 81→116 / 13→21 / 11→12 at v0.8.0 in the 0.7.13 sweep; every added assertion was checked non-vacuous by mutation (reverting its fix must fail it). TUI render path is still the least-covered surface. |
| Perf (§8) | **Authority is [`docs/benchmarks.md`](../benchmarks.md)** as of v0.9.4 — captured with a stated method and a committed harness (`tests/bench_tui.py`), rather than restated here. Headline: TUI 1 Hz **0.500 %** of one core (290 procs / 16 cores, 60 s window) — *at* the `< 0.5 %` budget, not under it, and linear in process count; peak RSS **4,684 kB** vs `< 8 MB`; cold start **0.544 ms** vs `< 5 ms`. Rate scaling is 4.1x for 4x rate, so per-frame work dominates. |
| `shu -p` wall time | **111.0 ms** (three trials of 20, all within 0.1 ms) = the deliberate 100 ms two-sample delta window + **~11 ms of work**, against the `< 30 ms of work` gate — met on that definition. ⚠ The §8 "first TUI frame < 50 ms" row is NOT settled: first bytes measure 1.0 ms, the first *complete* frame ~109 ms, and the row carries no work-vs-wall qualifier. See benchmarks.md. |

## Dependency Envelope

Two manifests since the 0.7.3 lean/AI split. The toolchain force-links every
declared stdlib module (DCE NOPs the unreached, keeps the bytes), so AI deps
are kept out of the lean manifest entirely.

**Lean `shu` — root `cyrius.cyml`** (monitor only, no libc):

- stdlib (22): `syscalls alloc fmt io fs str string slice vec args chrono hashmap process tagged assert sys fnptr sakshi thread freelist ct bench`  ⚠ `bayan` left the list at v0.7.14 when the monolith was dropped from the closure; this line claimed 23 modules including `bayan` until v0.9.4. Verify against `cyrius.cyml` rather than trusting it here.
- `sakshi` added at v0.7.12. It is **genuinely reachable** in the lean build — `src/snapshot.cyr` and `src/tui.cyr` call `mihi_gpu_count()` unconditionally, which routes through mihi 1.2.4's `SK_WARN` clamp — so DCE cannot drop it. It also arrives transitively via the `dist/*.deps` sidecars mihi 1.2.4 / ai-hwaccel 2.3.18 newly ship, making the entry redundant under cyrius ≥ 6.5.30 and **measured byte-neutral at the time (857,136 B either way — that measurement dates from v0.7.13; the lean binary is 636,000 B today, and the byte-NEUTRALITY is the claim being preserved here, not the size)**; it is declared as intent-documentation and as insurance against a toolchain below 6.5.30. Pure-syscall — the no-libc rule holds (`readelf -d build/shu`: no dynamic section).
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
| — | AGNOS build target | **Closed (v0.9.3)** — parity reached: the **TUI** runs on AGNOS, not just `-p`. Input is a poll loop over `kbscan` #42 / `winsize` #60 (`src/tui_agnos.cyr`); `SYS_IOCTL` is gated off (AGNOS has no `ioctl`); absent `/proc` sources degrade to `n/a`; the footer uses ASCII on a console with no UTF-8 decoder. Verified under QEMU + HMP `sendkey`. **Requires the AGNOS ring-3 stack fix (cycle 1.56.46)** — chakshu found it: 2 MB was mapped but only 12 KB was usable, killing any large frame as `exit 142`. **Open upstream gap:** no procfs and no process-enumeration syscall, so the process table is necessarily empty on AGNOS. |
| M3 | AI integration | **Closed (v0.8.2)** — redaction + prompt assembly (v0.7.2); live `--explain` + `?` overlay + lean/AI split (v0.7.3); SSE streaming + hoosh 2.3.5 bearer auth (v0.7.4); `--watch` anomaly stream (v0.8.0, **lean build** so it works on a no-libc AGNOS box); `--with-logs` (v0.8.1 — per-pid attribution proved impossible, sakshi carries no pid, so it ships system-level context + the anomaly ring); AI hardening + hoosh gate promoted to a hard CI gate (v0.8.2 — the blocker was a whitespace-intolerant JSON parse misreported as a transport error, not libc). Live path stays CI/real-box-only: sandhi dlopens libc. |
| M4 | Polish + perf | **Closed (v0.9.0-0.9.3)** — v0.9.0 perf + size close-out (all design-spec §8 runtime targets met; the size target formally revised 256 KB → 768 KB with the reason recorded, the 256 KB figure having been set at M0 before chakshu took its dependencies); v0.9.1 GPU telemetry depth; v0.9.2 theming + a `--color auto` that actually decides; v0.9.3 AGNOS parity. Lean `shu` is **636,000 B** against the revised < 768 KB — met with ~130 KB headroom. `CYRIUS_DCE=1` emits a byte-identical binary since cycc 6.5.16, so it is a parity check, not an optimiser. |
| M5 | v1.0 ship | **In progress** — this is a DISTRIBUTION milestone (registry promotion, agnosticos docs page, zugot recipe, announcement), gated on the v1.0 criteria published in [roadmap.md](roadmap.md) and on the AGNOS-premise decision recorded there. |

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — build, lint, test, smoke, DCE parity, security scan, docs + version consistency |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml, version-verify against tag, build matrix (x86_64-linux), source tarball, GH release with body from CHANGELOG section |
| Smoke test | `scripts/smoke.sh` — **25** gates (v0.9.4 added a `--version` == VERSION check and an argument-rejection block covering `--pid 0`, `--rate 0/99`, `--color`/`--theme` invalid values and unknown flags), run by both CI and locally pre-commit |
| Cutting a release | Bump VERSION + CHANGELOG section + `CHAKSHU_VERSION` literal in **`src/cli.cyr:10`** (NOT `src/main.cyr` — that pointer was wrong here until v0.9.4), push tag `vX.Y.Z` (or `X.Y.Z`); release.yml takes over. Pre-1.0 tags publish as GH prerelease automatically. |

Patterned on owl's CI/release flow. Differences: no fuzz or bench
harness. ⚠ The "no PTY harness" claim that stood here until v0.9.4 was
false — `tests/integration_smoke.py` has driven 14 scenarios under a real
pseudo-terminal since v0.8.0, and `tests/agnos_qemu.py` adds 17 more
against a real AGNOS kernel under QEMU (host-dependent, so it skips
rather than gating CI). aarch64 is deferred until a real consumer asks;
note the lean aarch64 build measures ~975 KB, over the revised 768 KB
target, so adopting that arch means either qualifying the §8 target as
x86_64-only or accepting a recorded deviation.

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
