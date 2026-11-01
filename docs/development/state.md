# chakshu — State

> **Status**: Active | **Last Updated**: 2026-10-31 (v0.12.1 — **what the 1.0 freeze would have locked in**: a 7-wide PID column in `-p` and the TUI, no trailing whitespace in `-p`, no clip that ends inside a UTF-8 character, and the AGNOS TUI refusing a non-terminal stdin as Linux does. Per-cut detail: CHANGELOG `[0.12.1]`. Before it, v0.12.0 — **the CLI on cmdit 1.5.0, and every contract question decided**: `--plain`, `--rows` (alias `--top`), `--watch-path`, `--`, `--flag=value`; a flag the chosen mode does not use is an error; `--explain` exits 1 when hoosh does not answer. The parser is pure and unit-tested. Per-cut detail: CHANGELOG `[0.12.0]`.)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.12.1** — 7-wide PID column, no trailing whitespace in `-p`, UTF-8-safe clipping, the AGNOS stdin gate. On **0.12.0**: the CLI on **cmdit `1.5.0`**, every contract question decided. cyrius `6.7.18`, darshana `1.7.0`, mihi `1.3.2`, ai-hwaccel `2.5.5`, bayan `1.11.1`, niyama `1.1.0` (all from v0.11.1). A dependency patch on 0.11.0 (C1-safe output on every untrusted-text path, SIGPIPE through the exit signalfd, darshana's teardown order, per-arch epoll tag, AGNOS `?` overlay). `check.sh` 23 gates, PTY 16 scenarios, `agnos_qemu.py` 35. |
| Cyrius toolchain pin | `6.7.18` (both manifests). It moved 6.7.9 → 6.7.18 at v0.11.1: patch releases in the 6.7 minor, no source change. The folds moved with it: sandhi 1.10.9 → 1.13.7 (the nine entry points `src/ai.cyr` calls keep their signatures), sakshi 2.5.8 → 2.5.10, bayan 1.5.13 → 1.11.1. niyama stays 1.1.0. Both folds are byte-identical to the pinned tags (`cmp`). Before that, 6.6.2 → 6.7.9 at v0.11.0, across the 6.7 language minor. No source change was needed for the language (no lone `!`, `~`, typed pointer, array `OP=` or reserved-word identifier anywhere — searched, not assumed). Three repairs it forced: `ai/cyrius.cyml` dropped its `version = "${file:../VERSION}"` (refused since 6.6.20 — a `${file:}` path must stay inside the project); `src/nolibc.cyr`'s four libssl refusals are now REDEFINITIONS of lib/fdlopen.cyr's (which lib/tls.cyr includes itself since 6.6.9) and bind because 6.6.20 binds every call to the last definition — four expected `duplicate fn` warnings, proven at run time by the AI suite; and niyama/bayan tags moved to the 6.7.9 folds (1.1.0 / 1.5.13). (History: 6.7.9 at v0.11.0; 6.5.35 at v0.7.12; 6.5.41 at v0.9.6; 6.5.45 at v0.9.9; 6.6.0 at v0.10.0; 6.6.1 at v0.10.2; 6.6.2 at v0.10.3.) ⚠ `~/.cyrius/bin` may point at an unreleased dev toolchain on a dev box; the `cyrius` wrapper re-execs to the manifest pin, but `cyrlint` called bare (as `check.sh` does) is whatever is on PATH — run `check.sh` with `~/.cyrius/versions/<pin>/bin` first on PATH to match CI. |
| Genesis cycle | v6.7.x — toolchain rev adopted; both manifests pin 6.7.18 |
| Active milestone | **M5 — v1.0 ship** (distribution, not features). M3 closed at **v0.8.2** (`--watch` v0.8.0, `--with-logs` v0.8.1, AI hardening + hoosh gate promotion v0.8.2). M4 closed across **v0.9.0-0.9.3** (perf/size close-out, GPU depth, theming, AGNOS parity). What remains for 1.0.0 is registry promotion, an agnosticos docs page, a zugot recipe and the announcement — **plus the v1.0 criteria published in [roadmap.md](roadmap.md)**. Criterion 1: the CLI contract is settled (every question decided at v0.12.0) and freezes at 1.0.0. Criteria 3 (benchmarks) and 6 (security audit) are met but stale, and are refreshed in 0.13.0. The AGNOS premise was re-read on 2026-10-31 (roadmap D3): the table, CPU% / MEM% and rates all work on AGNOS now, load average is the one `n/a`, and the recommendation is the lean `shu` as the T1 default, with `shu-ai` following hoosh into the AI profile. |
| Next milestone | ~~0.12.0~~ (CLI on cmdit 1.5.0 — shipped) → **0.12.1** (`-p` / render fixes the freeze would lock in) → **0.13.0** (§8 defined and re-measured, delta audit, root files, AGNOS release artifacts) → **1.0.0** (freeze + distribution). Proposed in roadmap.md; each bump is the owner's call |
| Binary | **Two builds** (0.7.3 split): lean **`shu`** (build/shu, monitor only) and **`shu-ai`** (ai/build/shu-ai, +AI). System Health Utility, per ADR 0001. |
| Binary size | **v0.12.1: lean `shu` 487,912 B DCE'd (shipped)**, 791,016 B plain; AGNOS 801,776 B. v0.12.0: lean `shu` 483,816 B DCE'd, 791,016 B plain — cmdit added 25,296 B to the shipped binary; the plain build is now over 768 KB, carrying cmdit's unreachable code, which DCE removes (roadmap 0.13.0 makes §8 name the shipped binary). `shu-ai` DCE'd 1,764,736 B; AGNOS 801,720 B. At v0.11.1: **Lean `shu`: 728,856 B** plain, **458,520 B DCE'd**. `release.yml` ships the DCE'd one: ~459 KB against design-spec §8's revised < 768 KB. Up from 688,520 / 434,568 B at v0.11.0. The 6.7.18 toolchain alone took **−60,160 B** off both (v0.11.0's tree under 6.7.18: 628,360 / 374,408 B). darshana 1.7.0 adds 0 B: 2,336 B of unreachable code, absorbed by page padding. mihi 1.3.2 + ai-hwaccel 2.5.5 add **+100,496 / +84,112 B**. AGNOS: **739,560 B**. `shu-ai`: **3,316,448 B** plain, **1,735,392 B DCE'd** (was 3,222,184 / 1,907,368; toolchain alone 3,216,016 / 1,651,344). The DCE'd binary passes smoke, the with-logs privacy smoke and the hoosh-stub smoke. `shu-ai` AGNOS: 3,280,688 B. |
| Lines of Cyrius | Shared core src/{proc,processes,snapshot,tui,cli}.cyr + entries (main.cyr lean / ai/main.cyr) + ai.cyr (AI, ~370 LoC w/ live transport) / ai_stub.cyr (lean). Deps via cyrius deps (per-build lib/). |
| Test count | **Two suites**: monitor `tests/chakshu.tcyr` (**370**: v0.12.0 added 149 for the argument parser, mutation-checked 11/11; v0.12.1 13 for `utf8_cut_len`) + AI `ai/tests/chakshu-ai.tcyr` (**53**), plus the PTY suite at **19** scenarios (16 at v0.12.0; scenario 19 skips where unprivileged pid namespaces are refused) and, for the AGNOS target, `tests/agnos_qemu.py` at **37** checks (35 at v0.12.0) (`-smp 4`; boots the `--agnos` build on a real AGNOS kernel under QEMU; host-dependent, so it skips rather than gating CI). v0.11.0 added 29 monitor + 14 AI assertions, PTY [15]/[16], with-logs [6] and AGNOS [6]; each new gate was checked to fail against the defect it covers. The monitor suite also passes on aarch64 (qemu-aarch64 and a real Pi 4: 208/208). TUI render path is still the least-covered surface. |
| Perf (§8) | **Authority is [`docs/benchmarks.md`](../benchmarks.md)**, captured with a stated method and a committed harness (`tests/bench_tui.py`). Last capture **v0.9.6, cyrius 6.5.41**: TUI 1 Hz **0.600 %** of one core, a recorded **miss** against `< 0.5 %` (linear in process count; ~290 procs); peak RSS **4,712 kB** vs `< 8 MB`; cold start **0.343 ms** vs `< 5 ms`. ⚠ Three toolchain minors stale; re-captured in 0.13.0 after the budget names its workload (roadmap D1). |
| `shu -p` wall time | **111.0 ms** (three trials of 20, all within 0.1 ms) = the deliberate 100 ms two-sample delta window + **~11 ms of work**, against the `< 30 ms of work` gate — met on that definition. ⚠ The §8 "first TUI frame < 50 ms" row is NOT settled: first bytes measure 1.0 ms, the first *complete* frame ~109 ms, and the row carries no work-vs-wall qualifier. See benchmarks.md. |

## Dependency Envelope

Two manifests since the 0.7.3 lean/AI split. The toolchain force-links every
declared stdlib module (DCE NOPs the unreached, keeps the bytes), so AI deps
are kept out of the lean manifest entirely.

**Lean `shu` — root `cyrius.cyml`** (monitor only, no libc):

- stdlib (22): `syscalls alloc fmt io fs str string slice vec args chrono hashmap process tagged assert sys fnptr sakshi thread freelist ct bench`  ⚠ `bayan` left the list at v0.7.14 when the monolith was dropped from the closure; this line claimed 23 modules including `bayan` until v0.9.4. Verify against `cyrius.cyml` rather than trusting it here.
- `sakshi` added at v0.7.12. It is **genuinely reachable** in the lean build — `src/snapshot.cyr` and `src/tui.cyr` call `mihi_gpu_count()` unconditionally, which routes through mihi's `SK_WARN` clamp (kept in 1.3.2, now belt and braces beside ai-hwaccel 2.5.5's own log threshold) — so DCE cannot drop it. It also arrives transitively via the `dist/*.deps` sidecar ai-hwaccel 2.5.5 ships (mihi 1.3.2's names only `sys syscalls`), making the entry redundant under cyrius ≥ 6.5.30 and **measured byte-neutral at the time (857,136 B either way — that measurement dates from v0.7.13; the lean binary is 728,856 B at v0.11.1, and the byte-NEUTRALITY is the claim being preserved here, not the size)**; it is declared as intent-documentation and as insurance against a toolchain below 6.5.30. Pure-syscall — the no-libc rule holds (`readelf -d build/shu`: no dynamic section).
- `bayan` is a **parse-time leaf** declared by the dist sidecars — *not*, as the manifest comment claimed until v0.7.12, because "the bundle calls `bayan_json_get`". ai-hwaccel calls no bayan function at all.
- git deps: **cmdit** `1.5.0` (since v0.12.0; both manifests) — the argument parser under `src/cli_parse.cyr`: getopt-long syntax, `--`, `--flag=value`, typed errors that carry the offending token. Its sidecar names `args alloc string io`, all already declared. **darshana** `1.7.0` (TTY/raw-mode — chakshu has zero termios/ANSI of its own, and since v0.11.0 no hand-written SGR escape or control-byte scrubber either; v1.0 **API freeze**, so the 23 functions and 15 constants chakshu uses are contractually stable and 1.x minors need no diff read. ⚠ Since 1.3.0 a Linux build needs cyrius ≥ 6.7.2 (the bundle declares `const`s), and since 1.5.0 an AGNOS build needs ≥ 6.7.11. ⚠ 1.5.0 changed the AGNOS arm on agnos ≥ 1.57.13: `tty_isatty(fd)` answers about `fd`, and `tty_flush_input` is console_mode#110's `CM_FLUSH`), **mihi** `1.3.2` (identity probes: hostname/kernel/distro/cpu/mem/uptime/gpu_* via `lib/mihi.cyr`), **ai-hwaccel** `2.5.5` (transitive via mihi; GPU panel. The pin tracks **mihi's own** tag, not ai-hwaccel's latest. mihi 1.3.2 pins 2.5.5, which is also the latest, so v0.11.1 moves with it. It held at 2.3.22 through v0.11.0 while mihi pinned that, and at 2.3.19 for two cuts before. That is the rule working, not being suspended. **The two must move in lockstep**: 2.3.18 against mihi 1.2.1 compiles but leaks `detect: profiles=N` to stderr mid-frame).

**AI `shu-ai` — `ai/cyrius.cyml`** (= the lean deps **plus**):

- stdlib: `+ unicode` (directory-style module, `lib/unicode/*.cyr`; needs the 6.1.28+ resolver) `+` the sandhi chain (`async atomic regression mmap dynlib fdlopen net http tls ws sigil keccak thread_local`) `+ sandhi` itself. (`sakshi` is now in the lean list too, so it is no longer an AI-only entry.)
- **sandhi** is consumed as a **stdlib module, not a git dep** — the folded-in toolchain copy compiles alongside `net.cyr`/`tls.cyr` so its bare socket/TLS constants resolve (the 6.1.21-built git dist could not). It's the hoosh HTTP transport; folded version 1.9.10 → 1.9.15 at v0.9.6, public fn surface 836 → 836, and all 8 entry points `src/ai.cyr` calls are unchanged in name and arity. **It was never the source of the 13.48 MB `.bss`** — that was sigil's banked crypto globals; see the Binary-size row.
- git deps: `+` **niyama** `1.1.0` — re2 secret-redaction (`src/ai.cyr`); the bre/pcre/fuzzy/vim engines DCE-NOP. Pulls the `unicode` stdlib module. Moved 1.0.10 → 1.1.0 at v0.11.0 to match cyrius 6.7.9's fold (byte-identical dist), and still the 6.7.18 fold and the latest tag at v0.11.1; with a different tag every AI build warns that `./lib/` shadows the version-pinned lib. 1.1.0 changes pcre answers only — chakshu uses re2, whose entry points are unchanged. **Hazard for a future cut:** cyrius 6.5.30 folded niyama into the stdlib, so a `lib/niyama.cyr` toolchain module exists beside this git dep. No conflict today (`niyama` is deliberately absent from `[deps].stdlib`), but it must never be consumed both ways at once — that would put two definitions of every `niyama_*` symbol in the closure.

- **bayan** `1.11.1` (AI manifest only, declared at the full bundle). It moved 1.5.13 → 1.11.1 at v0.11.1 because 6.7.18 folds 1.11.1, and 1.5.5 → 1.5.13 at v0.11.0 for 6.7.9's fold. The tag's dist and `ai/lib/bayan.cyr` are byte-identical. 1.11.1's JSON float parsing pulls `lib/math.cyr` into the AI build. ⚠ **cyrius 6.5.39 reversed stdlib-vs-git-dep precedence**: `cyrius deps` now keeps the toolchain's folded `lib/bayan.cyr` and SKIPS the pinned dep artifact, printing `refusing to overwrite stdlib leaf 'bayan'`. The tag therefore selects no bytes — it was moved 1.5.2 → 1.5.4 at v0.9.6 so it at least names what links (all three of `ai/lib/bayan.cyr`, the 6.5.41 stdlib copy and the 1.5.4 dep dist are now byte-identical, `md5 21e1dc32…`; at 1.5.2 a genuinely different file was being skipped). ⚠ **That stated reason expired at v0.10.0**: ai-hwaccel 2.3.22 marks its own `[deps.bayan]` `optional = true`, so there is no transitive sublib left to collide with — which is exactly why the lean binary shrank 55 KB. The block is retained because the AI build genuinely uses bayan through the ws/sigil/tls chain, not to suppress a collision that no longer happens.

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
| — | AGNOS build target | **Closed (v0.9.3)** — parity reached: the **TUI** runs on AGNOS, not just `-p`. Input is a poll loop over `kbscan` #42 / `winsize` #60 (`src/tui_agnos.cyr`); `SYS_IOCTL` is gated off (AGNOS has no `ioctl`); absent `/proc` sources degrade to `n/a`; the footer uses ASCII on a console with no UTF-8 decoder. Verified under QEMU + HMP `sendkey`. **Requires the AGNOS ring-3 stack fix (cycle 1.56.46)** — chakshu found it: 2 MB was mapped but only 12 KB was usable, killing any large frame as `exit 142`. The process-table gap this row recorded closed at v0.9.8 (`proclist` #99), and CPU% / MEM% and the disk and net rates followed by v0.10.1. **Open upstream gap:** load average (agnos `sysinfo` #35 has no `loads[]`). |
| M3 | AI integration | **Closed (v0.8.2)** — redaction + prompt assembly (v0.7.2); live `--explain` + `?` overlay + lean/AI split (v0.7.3); SSE streaming + hoosh 2.3.5 bearer auth (v0.7.4); `--watch` anomaly stream (v0.8.0, **lean build** so it works on a no-libc AGNOS box); `--with-logs` (v0.8.1 — per-pid attribution proved impossible, sakshi carries no pid, so it ships system-level context + the anomaly ring); AI hardening + hoosh gate promoted to a hard CI gate (v0.8.2 — the blocker was a whitespace-intolerant JSON parse misreported as a transport error, not libc). Live path was CI/real-box-only until **v0.9.7 removed the libc bridge** — `shu-ai` is now pure-syscall and builds for AGNOS. |
| M4 | Polish + perf | **Closed (v0.9.0-0.9.3)** — v0.9.0 perf + size close-out (all design-spec §8 runtime targets met; the size target formally revised 256 KB → 768 KB with the reason recorded, the 256 KB figure having been set at M0 before chakshu took its dependencies); v0.9.1 GPU telemetry depth; v0.9.2 theming + a `--color auto` that actually decides; v0.9.3 AGNOS parity. Lean `shu` is **636,000 B** against the revised < 768 KB — met with ~130 KB headroom. `CYRIUS_DCE=1` emits a byte-identical binary since cycc 6.5.16, so it is a parity check, not an optimiser. |
| M5 | v1.0 ship | **In progress.** No features remain. The path is 0.12.0 → 0.12.1 → 0.13.0 → 1.0.0 (roadmap.md): settle and freeze the CLI on cmdit, fix what the freeze would lock in, refresh the benchmarks and the audit, then the distribution acts. |

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — build, lint, test, smoke, DCE parity, security scan, docs + version consistency |
| Local pre-flight | `bash scripts/check.sh` — **23** gates, CI's commands in CI's order, including the separate security and docs jobs. ⛔ The only local check that counts; it has drifted from `ci.yml` three times (v0.9.4, v0.9.5, and again by v0.9.6, which found DCE parity, three security assertions, the `ai/*.cyr` glob and three required files missing). Add a gate to `ci.yml` and add it here in the SAME edit |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml, version-verify against tag, build matrix (x86_64-linux), source tarball, GH release with body from CHANGELOG section |
| Smoke test | `scripts/smoke.sh` — **29** gates (v0.9.4 added a `--version` == VERSION check and an argument-rejection block covering `--pid 0`, `--rate 0/99`, `--color`/`--theme` invalid values and unknown flags), run by both CI and locally pre-commit |
| Cutting a release | Bump VERSION + CHANGELOG section + `CHAKSHU_VERSION` literal in **`src/cli.cyr:10`** (NOT `src/main.cyr` — that pointer was wrong here until v0.9.4), push tag `vX.Y.Z` (or `X.Y.Z`); release.yml takes over. Pre-1.0 tags publish as GH prerelease automatically. |

Patterned on owl's CI/release flow. Differences: no fuzz or bench
harness. ⚠ The "no PTY harness" claim that stood here until v0.9.4 was
false — `tests/integration_smoke.py` has driven PTY scenarios since v0.8.0
(19 at v0.12.1), and `tests/agnos_qemu.py` adds 37 checks against a real
AGNOS kernel under QEMU (host-dependent, so it skips rather than gating CI;
on a heavily loaded host its boot can time out — re-run). aarch64 is
deferred until a real consumer asks; the lean aarch64 build measures
790,704 B at v0.11.0 (plain — aarch64 has no DCE compaction yet), over the
revised 768 KB target, and its process table does not render (roadmap,
"Found at v0.11.0"), so adopting that arch means fixing that first and
then qualifying the §8 target as x86_64-only or accepting a recorded
deviation.

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
