# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] — slated for 0.7.13 (P-1 audit / hardening sweep)

v0.7.13 is scoped as a **P-1 audit, refactor, hardening, optimization and security
sweep** with repairs. Items land here as they're fixed.

### Fixed

- **Signal-mask leak in the TUI teardown (`src/tui.cyr`).** `tui_run` opens two
  signalfds through darshana's `tty_open_signalfd`, which does a **`SIG_BLOCK`
  before creating the fd**. The teardown closed them with a bare `file_close()`,
  which releases the descriptor but **not** the mask — leaving `SIGHUP`/`SIGINT`/
  `SIGTERM` and `SIGWINCH` blocked for the rest of the process. Now torn down with
  `tty_close_signalfd(fd, sigmask)`, darshana's teardown counterpart, which closes
  **and** `SIG_UNBLOCK`s, passed the same mask the matching open was given. It
  unblocks-what-was-blocked rather than save/restore, which is what this site needs:
  chakshu holds two signalfds at once, and a `SIG_SETMASK` restore would have the
  first close stomp the second one's block.

  Measured, reading `SigBlk` from `/proc/self/status`:

  | Stage | `SigBlk` |
  |---|---|
  | before any open | `0x0000000000000000` |
  | both signalfds held | `0x0000000008004003` (HUP\|INT\|TERM\|WINCH) |
  | **after bare `file_close`** (the pre-fix path) | `0x0000000008004003` — **leaked** |
  | after `tty_close_signalfd` ×2 (the fix) | `0x0000000000000000` |

  The leak was **latent, not live**: `tui_run` returns straight to `main`, which
  exits, and the kernel discards the mask with the process. It becomes a real defect
  the moment `tui_run` returns to anything that keeps running — `--watch` is the
  obvious candidate — and a blocked mask also survives `execve`. Audited for other
  exit paths: the two early `return EXIT_ERR`s both precede the signalfd opens, and
  there is no direct `syscall(60)` anywhere in `src/`, so the single teardown site is
  exhaustive. darshana 1.0.0's `tty_close_signalfd` docstring names chakshu's
  two-signalfd pattern as the case it was written for.

### Added

- **Regression coverage for the above, at both levels.** `tests/chakshu.tcyr` gains a
  `signalfd teardown — SIG_BLOCK must not leak` group (**57 → 64 assertions**) that
  pins darshana's block/unblock contract against the live kernel: `SigBlk` clear
  before the open, non-clear while an fd is held, clear again after
  `tty_close_signalfd`, for both the EXIT and WINCH masks. Because that guards the
  *mechanism* rather than the call site, `ci.yml`'s pattern scan also now fails on
  `file_close(sfd…)` anywhere in `src/` — verified to fire on the pre-fix line and
  to pass on the fixed source.

## [0.7.12] — 2026-08-24 — Interim refresh: Cyrius 6.5.35 + darshana 1.0.0 + mihi 1.2.4 + ai-hwaccel 2.3.18

Toolchain/dependency refresh — no new feature surface at the chakshu CLI. Resolves
the manifest pin drift again (both manifests pinned `6.4.66`; the installed wrapper
is `6.5.35`) and pulls every dependency to its current tag. **The `shu-ai` size
regression filed at 0.7.11 is fixed by this toolchain jump** — the AI build falls
from ~15.49 MB to ~3.02 MB. Both builds compile clean and pass; version reports
`chakshu 0.7.12`. No chakshu source changes were required by any of the five bumps.

### Changed

- **Cyrius toolchain pin `6.4.66` → `6.5.35`** — in **both** manifests (`cyrius.cyml`
  lean `shu`, `ai/cyrius.cyml` `shu-ai`). Every stdlib module both manifests declare
  still resolves under 6.5.35 by the same name: the whole 6.4.66 → 6.5.35 stdlib
  file-list diff is **two additions and zero removals** (`async_macos.cyr`,
  `thread_macos.cyr`). `unicode` is still the directory-style module, and `sandhi`
  is still shipped folded-in as `lib/sandhi.cyr` (1.9.0 → 1.9.10, public fn surface
  836 → 836) — so no repeat of the `json`→`bayan` / `agnosys`→`sys` class of break.
  The two genuinely breaking upstream changes in the window both miss chakshu:
  `bayan_json_v_parse_str` → `_buf` (chakshu and all four vendored bundles reference
  zero `bayan_*` symbols) and the 6.5.1 promotion of wrong-arity calls from warning
  to hard error (zero mismatches — the clean build is the proof).
- **darshana `0.9.0` → `1.0.0`** (both manifests) — darshana's **v1.0 API freeze**
  (its ADR 0003). Bundle bodies are identical to 0.9.4; the substance of the span is
  0.9.1 (its own pin → 6.5.35), 0.9.2 (aarch64 `SYS_IOCTL` fix), 0.9.3 (two
  deliberate pre-freeze breaks) and 0.9.4 (docs/example only). Both 0.9.3 breaks hit
  **zero** chakshu call sites — chakshu calls no `_buf` composer (color stays in
  `src/tui.cyr`'s own theme path) and no `AGNOS_*` constant. All 15 symbols chakshu
  does use are in ADR 0003's frozen tables at identical arity and constant values.
- **mihi `1.2.1` → `1.2.4`** (both manifests) — **not a mechanical pin move.** mihi
  1.2.2 advanced its own transitive ai-hwaccel pin to `2.3.18` and took on a `sakshi`
  requirement: `_mihi_gpu_ensure()` clamps the sakshi log level to `SK_WARN` around
  its one `registry_detect_no_exec()` call, because ai-hwaccel 2.3.x logs
  `detect: profiles=N` at the default `SK_INFO` and would otherwise scribble on
  stderr mid-TUI-frame. 1.2.3 hardened the shared `/proc` read path (looped reads,
  bounded EINTR retry, truncation now fatal for meminfo/uptime/os-release) —
  chakshu's 8192-byte scratch buffers sit well clear of every limit. 1.2.4 added an
  aarch64 device-tree arm to `mihi_cpu_model` and an AGNOS `sysinfo` arm to
  `mihi_mem_free`, the latter fixing a permanent `-1` that `shu -p --agnos` had been
  subtracting in its used-memory line. The identity/static probe API chakshu reads
  is unchanged; all 13 symbols re-verified arity-identical.
- **ai-hwaccel `2.2.6` → `2.3.18`** (both manifests) — **the held pin finally moves.**
  The tracking rule is unchanged, not suspended: the pin follows *mihi's*
  `[deps.ai-hwaccel]` tag, and it sat at 2.2.6 for four cuts precisely because mihi
  still pinned 2.2.6. mihi 1.2.4 pins 2.3.18, so chakshu follows. **Both pins must
  move together** — 2.3.18 against mihi 1.2.1 compiles but leaks the `detect:` line
  to stderr. The span crosses four deliberate symbol de-collisions (2.3.13 `ERR_*` →
  `HWA_ERR_*`; 2.3.14 `registry_new` → `hw_registry_new`; 2.3.18 `BACKEND_COUNT` →
  `AIHW_BACKEND_COUNT`, `Backend` → `AiHwBackend`, `path_exists` → `aihw_path_exists`);
  chakshu references none of them — it reaches this surface only via `mihi_gpu_*`.
  All nine structs are byte-identical, so the concatenated bundle stays ABI-consistent.
- **niyama `1.0.6` → `1.0.7`** (`ai/cyrius.cyml`) — a **pin-only** release: niyama's
  own cyrius pin moved 6.4.64 → 6.5.29 with zero engine source changes, and
  `dist/niyama.cyr` is byte-identical to 1.0.6 apart from its version header. The two
  symbols `src/ai.cyr` calls (`niyama_re2_compile`, `niyama_re2_search`) are unchanged.

### Added

- **`sakshi` declared in the lean root `[deps].stdlib`.** It is genuinely reachable in
  the lean monitor — `src/snapshot.cyr` and `src/tui.cyr` call `mihi_gpu_count()`
  unconditionally, which routes through mihi 1.2.4's sakshi level clamp — so DCE
  cannot drop it. It already arrives transitively via the `dist/*.deps` sidecars that
  mihi 1.2.4 and ai-hwaccel 2.3.18 newly ship (cyrius 6.5.30 fixed the `distlib` bug
  that suppressed them), which makes the entry **redundant under cyrius ≥ 6.5.30 and
  measured byte-neutral — 857 136 B with or without it.** It is declared anyway as
  intent-documentation, and as insurance against a toolchain below 6.5.30 where
  sidecar auto-resolution disappears and the omission becomes a hard link failure.
  `sakshi` is pure-syscall (`clock_gettime`/`nanosleep`) — the no-libc rule holds
  (`readelf -d build/shu`: no dynamic section).

### Fixed

- **`shu-ai` is back in its pre-6.4.66 size band: ~15.49 MB → ~3.02 MB**
  (15 489 136 → 3 170 560 B), with static `.bss` falling **13 477 224 → 870 992 B
  (−93.5%)**. This closes the M4 item filed at 0.7.11, purely as a function of the
  toolchain pin — no dep or source change contributed.
- **The 0.7.11 root-cause diagnosis of that bloat was misattributed and is corrected
  here.** It was *not* "two oversized array locals in the sandhi/TLS chain." The
  driver was **sigil's banked crypto workspace held as module-level array globals**:
  6.4.66's `lib/sigil.cyr` declared ~1 587 782 top-level `var X[N]` elements
  (`_rsa_blind_prod[65536]`, the `_bn_*` bignum engine, `_pss_*` — each 512 B ×
  `SIGIL_CRYPTO_BANKS` = 64 lanes) ≈ 12.7 MB, i.e. **~94% of the measured `.bss`**.
  cyrius 6.5.22 folded sigil 3.12.9, which localised the RSA sign/blind/CRT workspace
  and the bignum engine to stack frames (upstream: *"9.53 MiB of .bss reclaimed"*).
  6.5.35's sigil declares 13 954 such elements. The two actual "oversized array
  local" notes — `sigil.cyr` `var SCR[352256]` (argon2 scratch) and `var buf[262144]`
  (hash-file I/O scratch), ~614 KB combined — were only ~4.5% of the old figure,
  which is exactly why they were the wrong suspect. **Those two notes still fire ×2
  on the `shu-ai` build and are expected, not a residual regression.**
- **Root `cyrius.cyml`'s `bayan` rationale corrected.** It claimed *"the bundle calls
  `bayan_json_get`"* — it does not. ai-hwaccel's dist contains zero `bayan_*`
  references (the only `json_*` tokens are four local variable names). `bayan` is
  still required, but as a **parse-time leaf** declared by the dist sidecars. Recorded
  so a future cut doesn't drop it for the stated-and-false reason — or keep it for one.

### Known — lean `shu` size regression under the 6.5.x codegen (backlog / M4)

- The lean monitor grew **495 512 → 857 136 B (+361 624 B, +73%)**, `.bss` **71 664 →
  145 000 B**. Isolated by building the *old* dep set under the *new* toolchain:

  | Build | Size | Delta |
  |---|---:|---|
  | 0.7.11 — 6.4.66 + old deps | 495 512 B | — |
  | 6.5.35 + **old** deps | 757 616 B | **+262 104 B — toolchain** |
  | 0.7.12 — 6.5.35 + new deps | 857 136 B | **+99 520 B — deps** |

  So ~72% of the growth is the compiler and ~28% the dep bumps (ai-hwaccel's bundle
  alone grew 179 098 → 209 216 B, plus `sakshi` newly in the lean closure). niyama's
  1.0.7 changelog bisects the compiler half to **6.5.15 → 6.5.16**: cycc now emits
  every manifest-included stdlib module rather than pruning to what `main` reaches,
  and `CYRIUS_DCE=1` NOPs dead functions in place instead of removing them, never
  dropping unreferenced data tables. Confirmed here — **`build/shu-dce` is 857 136 B,
  byte-for-byte identical to the non-DCE build** (DCE parity still passes; it just no
  longer shrinks anything). Against design-spec §8's `< 256 KB` target the lean
  monitor moves from ~1.9× to **~3.3× over**. This replaces the `shu-ai` entry as the
  M4 size item.

### Verified

- Lean `shu`: `cyrius build` clean, `tests/chakshu.tcyr` **57/57**, `scripts/smoke.sh`
  **PASS** (17 gates), `tests/integration_smoke.py` PTY suite **7/7 PASS**, DCE parity
  **PASS**. `shu -p` wall time **~112 ms**, unchanged. `shu --version` reports
  `chakshu 0.7.12`.
- `shu -p` renders the GPU line with **stderr exactly 0 bytes** — mihi 1.2.4's
  `SK_WARN` clamp confirmed working; no `detect: profiles=N` leak into the frame.
- AI `shu-ai`: `cyrius build` clean (`CYRIUS_ALLOW_PARENT_INCLUDES=1`),
  `tests/chakshu-ai.tcyr` **13/13**.
- `cyrius lint` over `src/*.cyr`: **0 non-cosmetic warnings** (the ci.yml gate).
- `tests/hoosh_stub_smoke.py` still cannot run on the dev box (sandhi resolves via
  `fdlopen`→libc `getaddrinfo`); the `--explain` fallback correctly printed the
  redacted context instead. Unchanged posture — CI marks that gate `continue-on-error`
  pending its first green on a libc runner.

### Process note

- Upstream now publishes a **`dist/*.deps` sidecar per bundle** naming the stdlib
  leaves that fold requires. On every future dep bump, union the sidecars and diff
  against `[deps].stdlib` — one command that would have caught this cut's `sakshi`
  question, and the earlier `json`→`bayan`, `unicode`, and `agnosys`→`sys` surprises.
- **`cyrius fmt` now rewrites files in place** as of 6.5.28 (`--check` is the
  non-destructive form). Nothing in `ci.yml`, `release.yml` or `scripts/` invokes it —
  do not add a bare `cyrius fmt` to CI.

## [0.7.11] — 2026-07-17 — Interim refresh: Cyrius 6.4.66 + mihi 1.2.1 + niyama 1.0.6

Toolchain/dependency refresh — no new feature surface at the chakshu CLI. Resolves
the manifest pin drift (both manifests pinned `6.2.37`; the installed wrapper is
`6.4.66`) and pulls every dependency to its current tag. Both builds compile clean
and pass; version reports `chakshu 0.7.11`.

### Changed

- **Cyrius toolchain pin `6.2.37` → `6.4.66`** — in **both** manifests (`cyrius.cyml`
  lean `shu`, `ai/cyrius.cyml` `shu-ai`). Spans the 6.3.x line and most of 6.4.x; no
  chakshu source changes were needed (all stdlib modules chakshu declares still
  resolve under 6.4.66).
- **mihi `1.1.3` → `1.2.1`** (both manifests) — latest tag. mihi 1.2.1 still pins
  ai-hwaccel `2.2.6` transitively, so chakshu's ai-hwaccel pin holds at `2.2.6`
  (ABI-consistency of the concatenated `dist/mihi.cyr` + `dist/ai-hwaccel.cyr`
  bundle). The identity/static API chakshu reads is unchanged.
- **darshana `0.8.0` → `0.9.0`** (`ai/cyrius.cyml` only) — brings the AI manifest in
  lockstep with the root manifest, which advanced to `0.9.0` at v0.7.10. No TTY
  surface change on Linux.
- **niyama `1.0.5` → `1.0.6`** (`ai/cyrius.cyml`) — latest tag (built for cyrius
  6.4.64, aligned with the 6.4.66 pin). re2 redaction API unchanged.
- **ai-hwaccel held at `2.2.6`** — deliberately *not* bumped to its latest (`2.3.14`);
  the pin tracks whatever mihi pins transitively (2.2.6), not ai-hwaccel's own latest.

### Verified

- Lean `shu`: `cyrius build` clean, `tests/chakshu.tcyr` **57/57**, `scripts/smoke.sh`
  **PASS** (17 gates, ~0.11 s wall). Binary shrank to **~0.48 MB** (495 512 B) under
  6.4.66 — down from ~0.90 MB.
- AI `shu-ai`: `cyrius build` clean (`CYRIUS_ALLOW_PARENT_INCLUDES=1`),
  `tests/chakshu-ai.tcyr` **13/13**.

### Known — `shu-ai` size regression under the 6.4.66 codegen (backlog / M4)

- The AI build grew from **~2.27 MB to ~15.49 MB** purely as a function of the
  toolchain pin. Isolated to the **compiler codegen**, not the dep bumps: the same
  dep set built under a `6.2.37` pin is 2.27 MB; under `6.4.66` it is 15.49 MB.
  The 6.4.66 compiler promotes two *oversized array locals* in the sandhi/TLS chain
  into shared `.bss` globals (build note: *"oversized array local kept in shared
  global (not per-thread) — exceeds per-fn stack budget; use alloc()"* ×2), producing
  a **13.48 MB static `.bss`** where 6.2.37 emitted ~360 KB. The linker places
  `.rodata` after that `.bss`, so the file physically extends to ~15 MB (not sparse).
  DCE cannot strip it (it NOPs unreachable *code*, keeps `.bss`); the only fix is
  upstream — the sandhi/TLS stdlib buffers moving to `alloc()`, or a cycc codegen
  change. The **lean `shu` is unaffected** (it pulls none of that chain, and actually
  shrank). Filed as an M4 / upstream-cyrius concern; the AI build remains the
  documented heavy opt-in.

## [0.7.10] — 2026-07-08

Unblocks the `--agnos` build (the `shu` entry in agnosticos' `build-dev.sh`
agnos-dev docker image). `cyrius build --agnos src/main.cyr shu` failed to link
on `undefined variable 'TTY_SIGMASK_EXIT'` — the first of several Linux-only
symbols in `tui_run`'s interactive input-mux.

### Changed

- **darshana `0.8.0` → `0.9.0`** (`cyrius.cyml`) — picks up the agnos signalfd
  branch (`tty_open_signalfd` / `tty_close_signalfd` + `TTY_SIGMASK_EXIT` /
  `TTY_SIGMASK_WINCH`), which resolves those symbols on agnos. TTY surface
  unchanged on Linux.

### Fixed

- **`--agnos` build** — gated `tui_run`'s epoll/signalfd interactive input-mux
  behind `#ifndef CYRIUS_TARGET_AGNOS` (`src/tui.cyr`). The block is Linux-only
  in shape — the cyrius stdlib epoll surface it uses (`EPOLLIN` /
  `EPOLL_CTL_ADD` / `epoll_event_new` + 4-arg `sys_epoll_ctl` / `sys_epoll_wait`)
  is absent / differently-shaped on agnos, and mirshi's epoll carries no per-fd
  `data` tag this loop dispatches on. It is also **unreachable** on agnos:
  darshana's `tty_raw` returns `-1` there, so `tui_run` bails to the
  not-a-TTY message before the block. Interactive `shu` degrades to the `-p`
  plain-snapshot path on agnos; the Linux TUI is byte-identical. Verified:
  `--agnos` build succeeds and `shu` / `shu -p` run under mirshi (Linux path
  unchanged).

## [0.7.9] — 2026-06-22

### Changed

- **Dropped `agnosys`; rewired the mihi probe chain onto the native `sys` stdlib module.**
  cyrius retired the stale stdlib `agnosys` snapshot at **6.2.37**. chakshu pulled it only
  transitively (via mihi's `agnosys_uname`), so this drops `"agnosys"` from the stdlib list in
  **both** manifests (lean `shu` + `ai/` `shu-ai`), adds `"sys"`, and bumps **mihi `1.1.1` →
  `1.1.3`** (the mihi half of the rewire → `sys_uname` / `sys_sysinfo`). Brought the `ai/`
  manifest current too (darshana `0.7.1` → `0.8.0`, cyrius `6.2.36` → `6.2.37`), and added a
  `cyrius lib sync` CI step on both build paths for the opt-in-vendored `sys` module (`lib/` is
  gitignored / CI-regenerated). **Host build verified clean; no monitor-surface change.** The
  planned `--watch` / `--with-logs` M3 cut slides to **v0.7.10**.

### Known — AGNOS build gap (backlog)

- With agnosys cleared, the `--agnos` build now reaches its **next** blocker: chakshu's TUI
  render loop is built on the Linux **signalfd + epoll** model (SIGWINCH resize + signal
  multiplexing via darshana's `TTY_SIGMASK_*` / `tty_open_signalfd`, all Linux-only — 18
  signal-path refs, no agnos gating). Agnos-native `shu` is its own arc (agnos-native
  resize/signal handling), tracked in `docs/development/roadmap.md`. The lean `shu` runs on
  Linux today; AGNOS support lands post-this-cut.

## [0.7.8] — 2026-06-22

### Changed

- **cyrius toolchain pin `6.2.24` → `6.2.36`** — in **both** manifests: top-level `cyrius.cyml`
  (lean `shu`) **and** `ai/cyrius.cyml` (`shu-ai`). Aligns with the latest cyrius. Both builds
  re-verified clean (shu-ai via the CI's `CYRIUS_ALLOW_PARENT_INCLUDES=1`); the `--agnos` build
  remains blocked **upstream** on the cyrius-stdlib
  `agnosys` Landlock gap (filed:
  `cyrius/docs/development/issues/2026-06-22-agnosys-stdlib-security-fns-not-agnos-gated.md`),
  not on this pin. (The planned `--watch` / `--with-logs` M3 cut slides to **v0.7.9**.)

## [0.7.7] — 2026-06-22 — Interim refresh: darshana 0.8.0 (agnos winsize#60)

Dependency refresh. No new feature surface at the chakshu CLI. (The M3-closing
`--watch` / `--with-logs` cut that 0.7.6 earmarked for v0.7.7 shifts to **v0.7.8** —
this slot is taken by the darshana refresh, mirroring 0.7.6's interim-refresh pattern.)

### Changed

- **`[deps.darshana]` 0.7.1 → 0.8.0** — darshana's minor cut adds the agnos
  `tty_winsize` branch backed by the kernel `winsize`#60 syscall (agnos 1.45.13). On
  Linux the TTY surface chakshu consumes is unchanged (host build clean); on agnos
  `tty_winsize` now **resolves** (it was Linux-only, so an agnos build couldn't link
  it), letting `_tui_update_winsize` read the real framebuffer console grid instead
  of the 24×80 fallback. This benefit is **latent**: chakshu's agnos build is still
  blocked upstream of winsize by the `agnosys` → `agnodrm` migration (the agnos target
  fails on `agnosys`'s Landlock syscalls — unrelated to this dep bump). Host build
  verified; agnos build deferred to the agnosys-migration arc.

## [0.7.6] — 2026-06-19 — Interim refresh: Cyrius 6.2.24 + mihi 1.1.1 + darshana 0.7.1

Toolchain/dependency refresh. No new feature surface at the chakshu CLI —
the M3-closing `--watch` / `--with-logs` cut moves to **v0.7.7**.

### Changed

- **Cyrius toolchain pin** `6.2.2` → `6.2.24` (both manifests), aligning
  with the installed wrapper (6.2.25). Both builds compile clean — lean
  `shu` (57 tests) and `shu-ai` (13 tests) green, smoke gate PASS. No
  source changes were required for the 6.2.x line.
- **mihi** `1.0.0` → `1.1.1` (both builds) — latest tag (built for cyrius
  6.2.22). The identity/static API chakshu reads (hostname / kernel /
  distro / cpu_model / cpu_count / mem_* / uptime / gpu_*) is unchanged.
- **darshana** `0.7.0` → `0.7.1` (both builds) — latest tag (built for
  cyrius 6.2.22). Patch-level refresh; the TTY/raw-mode surface chakshu
  consumes is unchanged.

### Held

- **ai-hwaccel** stays at **2.2.6** — pin tracks mihi 1.1.1's own
  transitive pin to keep the concatenated `dist/mihi.cyr` +
  `dist/ai-hwaccel.cyr` bundle ABI-consistent. 2.3.x tags exist (up to
  2.3.12); adopting them is deferred to a coordinated mihi bump.
- **niyama** stays at **1.0.5** (AI build) — already the latest tag.

## [0.7.5] — 2026-06-13 — Interim refresh: Cyrius 6.2.2 + niyama 1.0.5

Toolchain/dependency refresh. No new feature surface at the chakshu CLI —
the M3-closing `--watch` / `--with-logs` cut moves to **v0.7.6**.

### Changed

- **Cyrius toolchain pin** `6.1.29` → `6.2.2` (both manifests). The
  installed wrapper had already advanced to 6.2.2; this aligns the pins
  with it. Both builds compile clean on 6.2.2 — lean `shu` (57 tests) and
  `shu-ai` (13 tests) green, smoke gate PASS. No source changes were
  required for the 6.1.x → 6.2.x line (the `json`→`bayan` rename and
  directory-style stdlib modules from 6.1.x still apply).
- **niyama** `1.0.4` → `1.0.5` (AI build only) — re2 redaction engine,
  latest tag. Redaction tests unchanged and green.
- Help text + `src/ai.cyr` header: the planned-cut labels for `--watch` /
  `--with-logs` now read **(0.7.6)** (were 0.7.4 — those features have not
  shipped yet; this tracks the renumbered feature cut).

### Held

- **ai-hwaccel** stays at **2.2.6** — pin tracks mihi 1.0.0's own
  transitive pin to keep the concatenated `dist/mihi.cyr` +
  `dist/ai-hwaccel.cyr` bundle ABI-consistent. 2.3.x tags exist; adopting
  them is deferred to a coordinated mihi bump (roadmap M4).
- **darshana** `0.7.0` and **mihi** `1.0.0` are already at their latest
  tags — no change.

## [0.7.4] — 2026-06-10 — M3 live transport II: hoosh 2.3.5 auth + SSE streaming + `--explain` smoke

### Added

- **SSE streaming in the `?` overlay.** The TUI explain overlay now streams
  hoosh's answer incrementally (`ai_hoosh_stream` → `sandhi_http_stream`
  with `"stream":true`): sandhi parses the SSE, and `_ai_stream_cb` extracts
  each OpenAI `delta.content` (reusing `_ai_extract_content`) and renders it
  as it arrives. **Esc / q cancels mid-stream** (non-blocking `poll(stdin)`
  in the callback returns 0). Falls back to the redacted-context preview if
  nothing streams. `--explain` (CLI one-shot) stays request→render. Replaces
  the 0.7.3 blocking placeholder. Happy-path needs a live hoosh + real TTY
  to verify visually.

### Changed

- **hoosh 2.3.5 compatibility — bearer-token auth.** hoosh now enforces
  `Authorization: Bearer <token>` on `/v1/*` when tokens are configured (a
  token-less gateway still "allows all", so unauthenticated calls keep
  working against it). `--explain` and the `?` overlay now send the header
  when `$CHAKSHU_HOOSH_TOKEN` is set, and omit it otherwise — compatible
  with both modes. New `_ai_hoosh_headers` builds Content-Type + optional
  auth, reused by the (upcoming) SSE stream path. Endpoint / port / request
  / response are unchanged from 0.7.3 (`POST /v1/chat/completions`, `:8088`,
  OpenAI format, `"content"` extraction).

### Pending

- `--explain` smoke gate (needs a live or stubbed hoosh in CI).
- Live-hoosh verification pass: confirm the real served model name
  (`$CHAKSHU_MODEL`, default "default") and the streamed `?` overlay visually.

## [0.7.3] — 2026-06-10 — M3 live transport: lean/AI split + hoosh `--explain` + `?` overlay

### Added

- **Live `--explain` via hoosh** (`src/ai.cyr`): builds an OpenAI chat
  request, POSTs to the hoosh gateway (`POST /v1/chat/completions`,
  default `:8088`, overridable via `$CHAKSHU_HOOSH_URL` / `$CHAKSHU_MODEL`)
  using sandhi's HTTP client, extracts the answer, and prints it. Any
  failure (unreachable / non-200 / no content) degrades to the redacted-
  context preview. JSON escape + content extraction unit-tested. The live
  POST needs a running hoosh to verify; design-spec §6.3's "Unix socket /
  daimon.sock" framing was stale — the real path is hoosh's HTTP API.
- **TUI `?` explain overlay** (`ai_tui_explain`): in `shu-ai`, `?` takes
  over the screen, shows an "asking hoosh" line, makes the call, and renders
  the answer (or the redacted-context fallback) until a key is pressed; in
  lean `shu` it shows a "run shu-ai" notice. The prompt-building is shared
  with `--explain` via `_ai_prompt_for_pid`. Request→render for now;
  incremental SSE streaming (`sandhi_http_stream` + Esc-cancel) is a
  follow-up refinement. Needs a live hoosh + real TTY to verify visually.

### Changed — **lean / AI binary split**

- **`shu` is now monitor-only (~0.86 MB)** — no AI deps. The AI build
  `shu-ai` (~2.57 MB) lives in `ai/` as a sub-project that shares the
  monitor source (`../src/*`, via `CYRIUS_ALLOW_PARENT_INCLUDES=1`) and
  adds `src/ai.cyr` + the sandhi/niyama dep chain. Rationale: AI deps are
  force-linked by the toolchain (DCE NOPs but keeps bytes), so the only way
  to keep the default monitor small is to keep those deps out of its
  manifest. Lean `shu` is now smaller than btop's install and beats htop
  once their shared libs (ncurses/libc/libstdc++) are counted.
- **CLI extracted to `src/cli.cyr`** (shared `chakshu_main()`); `src/main.cyr`
  (lean) includes `src/ai_stub.cyr`, `ai/main.cyr` includes `src/ai.cyr`.
  `--explain` / `?` in the lean build point users at `shu-ai`.
- **Tests split**: `tests/chakshu.tcyr` (monitor parsers, 57) +
  `ai/tests/chakshu-ai.tcyr` (redaction / prompt / JSON, 13).
- **CI** builds + tests both binaries; version check now reads
  `CHAKSHU_VERSION` from `src/cli.cyr`.
- **Toolchain pin** `6.1.28` → `6.1.29`.

## [0.7.2] — 2026-06-10 — M3 foundation: `--explain` context + niyama redaction

**Minor — first AI-integration surface (M3 foundation).** `--explain
<PID>` and the TUI `?` key are wired; the live daimon transport +
streamed answer land at 0.7.3, `--watch` / `--with-logs` at 0.7.4.

### Added

- **`src/ai.cyr`** — AI-integration module:
  - **`ai_redact_cmdline`** — design-spec §6.2 secret redaction, driven
    by niyama's re2 engine. Tokenizes the printable cmdline; for any
    `key=value` whose key matches `password|token|secret|key|passwd`
    (case-insensitive on the lead letter and on KEY), the value is
    replaced with `***`. Fail-safe: if the detector regex can't compile,
    `key=value` values are redacted rather than leaked.
  - **`ai_build_prompt`** — assembles the explain prompt from facts the
    user can already see (process identity/state/rss, redacted command,
    one-line system summary). Pure formatter; privacy by construction —
    no env vars, no /home, no untrimmed args (design-spec §6.2).
  - **`ai_explain`** — `--explain <PID>` one-shot: gathers /proc facts,
    redacts, assembles, and prints the **redacted context that will be
    sent** to daimon, then reports transport status. Makes the prompt
    auditable now ("AI is opt-in and visible", design-spec §2.2/§6).
- **`--explain <PID>`** wired in `src/main.cyr` (was a placeholder).
- **TUI `?` key** — captures the selected row's pid and shows a transient
  hint pointing at `shu --explain <pid>`; `[?] explain` added to the
  status-line hints. The streamed overlay replaces the hint at 0.7.3.
- **Tests** — 8 new assertions (65 total): exact-output redaction cases
  (privacy-critical) + prompt-assembly shape.

### Changed

- **`cyrius.cyml [package].cyrius`** — `6.1.27` → `6.1.28`. 6.1.28's dep
  resolver handles **directory-style stdlib modules**, which 6.1.27 could
  not — required to pull `unicode` (see below). No source change.
- **`cyrius.cyml [deps]`** — added **niyama `1.0.4`** (re2 redaction; first
  niyama tag built on 6.1.27+) and the **`unicode`** stdlib module (niyama's
  re2/fuzzy engines reference `unicode_category` / `unicode_to_lower` / the
  `NFD`/`NFC` normalization constants). ai-hwaccel stays 2.2.6, mihi 1.0.0,
  darshana 0.7.0.
- **`cyrius.lock`** — regenerated (now includes niyama + the `unicode`
  directory module).
- **`VERSION` / `CHAKSHU_VERSION`** — `0.7.1` → `0.7.2`.

### Notes

- **Binary size jumped to ~1.38 MB** (text 1 182 614 + bss 264 536),
  **over the relaxed `< 1 MB` M4 budget**. niyama's re2 hard-references the
  `unicode` data tables (~350 KB) plus niyama's own bundle (~248 KB), even
  though chakshu uses only re2 on ASCII patterns. This is the size/justifi-
  cation tension CLAUDE.md flags ("no external deps until justified"); see
  the M4 carry-forward in `docs/development/state.md`. Options on the table:
  pursue real DCE/`--strip-dead` of the unused niyama engines + unicode
  tables, or revert to a chakshu-local redactor.
- **`unicode` is a directory-style stdlib module** (`lib/unicode/*.cyr`).
  Pulling it requires the 6.1.28 resolver; 6.1.27 errored with
  `cannot read ./lib/unicode.cyr`.

## [0.7.1] — 2026-06-10 — toolchain + mihi v1.0 dep refresh

**Patch — toolchain bump and ecosystem-current dep refresh.** No
behavior change at the chakshu surface; the mihi API chakshu reads
and the darshana TTY surface it calls are both unchanged.

### Changed

- **`cyrius.cyml [package].cyrius`** — `6.0.1` → `6.1.27`. Aligns the
  manifest pin with the host wrapper (which had drifted ahead to
  6.1.27). No source changes required by the toolchain rev.
- **`cyrius.cyml [deps.mihi].tag`** — `0.8.0` → `1.0.0`. mihi's v1.0
  ship, unblocked once chakshu (mihi's gating consumer, M6) integrated
  at v0.6.0. The bundled identity surface chakshu reads
  (hostname / kernel / distro / cpu_model / cpu_count / mem_total /
  mem_free / uptime / gpu_*) is unchanged from 0.8.0 — same bytes,
  stable tag.
- **`cyrius.cyml [deps.ai-hwaccel].tag`** — held at `2.2.6`. The
  transitive pin tracks mihi's own `[deps.ai-hwaccel]` tag (mihi 1.0.0
  still pins 2.2.6), not ai-hwaccel's latest (2.3.x), to keep the
  concatenated `dist/mihi.cyr` + `dist/ai-hwaccel.cyr` bundle
  ABI-consistent. Comment block expanded to record the invariant.
- **`cyrius.cyml [deps].stdlib`** — `json` → `bayan`. The stdlib JSON
  module was renamed in the 6.1.x toolchain line: 6.0.x shipped
  `lib/json.cyr`; 6.1.27 ships `lib/bayan.cyr` (the `bayan_json_*` /
  `bayan_csv_*` / `bayan_cyml_*` families). Required by the toolchain
  bump — see Fixed.
- **`cyrius.lock`** — regenerated by `cyrius deps` against 6.1.27
  (34 → 44 locked deps; the prior lock was resolved through a stale
  `lib/` shadow).
- **`CHAKSHU_VERSION`** — `"chakshu 0.7.0"` → `"chakshu 0.7.1"` in
  `src/main.cyr` line 20.
- **`VERSION`** — `0.7.0` → `0.7.1`.

### Fixed

- **CI `cyrius deps` failure on 6.1.27** — `cannot read
  .../versions/6.1.27/lib/json.cyr`. The toolchain bump renamed the
  stdlib JSON module `json` → `bayan`; the manifest still requested
  `json`, which resolves on a 6.0.x dev box (and was further masked
  by a stale, gitignored `lib/json.cyr` shadowing the version-pinned
  toolchain lib) but fails on CI's clean checkout. Switched the dep to
  `bayan`; this also resolves the local `undefined function
  'bayan_json_get'` build warning, since the ai-hwaccel bundle calls
  the new `bayan_json_*` API that only `bayan.cyr` provides. Verified
  by wiping `lib/` and re-resolving to reproduce the CI clean state.

### Note

- **darshana** stays at `0.7.0` — already the ecosystem-current tag at
  this cut; no bump needed.
- **Binary size** grew to ~861 KB (882 120 B) at this cut — the real
  `bayan.cyr` is a fuller module than the old `json.cyr` (+~80 KB
  `.bss`/text). Still ~3.4× over the design-spec §8 `<256 KB` target;
  **deferred to M4** per the size-pressure carry-forward (the gap is a
  known DCE/`.bss`-stripping limitation, not new debt).

## [0.7.0] — 2026-06-06 (cycle-open: AGNOS as a build target)

### Added

- **AGNOS platform support — cycle opened** (VERSION → 0.7.0). An AGNOS-target build so the `shu` monitor runs on AGNOS: system stats via mihi's `uname`#34 / `sysinfo`#35 reads, and a kernel-log view via the new `klog`#36 syscall (reads the unified klug ring). Filtering stays the **agnsh `grep` builtin** — chakshu does NOT bundle its own grep. Inline; no platform-abstraction layer yet.

## [0.6.1] — 2026-05-20 — darshana 0.4.1 dep refresh

**Patch — forward-compat dep bump closing darshana's M4 milestone.**
chakshu's M2 (Full TUI) shipped at 0.5.0 on darshana 0.3.0, which
already satisfied the literal M4 gate ("chakshu M2 closes ... using
darshana"). This cut advances chakshu's darshana pin from 0.3.0 →
0.4.1 so darshana's M4 close ceremony aligns chakshu with the
ecosystem-current dep. **No behavior change** at the chakshu surface
— the v0.3.5/0.4.x darshana additions (SGR helpers, `tty_sgr` bounds
check, ADR 0002 state-restore posture) aren't called from chakshu;
its colour rendering stays in `src/tui.cyr`'s own 16-colour theme
path, and its exit/teardown wiring already conforms to ADR 0002.

The darshana surface chakshu *does* use is unchanged from 0.3.0:
`tty_raw` / `tty_cooked`, `tty_alt_enter` / `tty_alt_leave`,
`tty_clear` / `tty_clear_to_eol` / `tty_clear_to_end`,
`tty_cursor_hide` / `tty_cursor_show` / `tty_cursor_home`,
`tty_move`, `tty_winsize`, `tty_open_signalfd` + the
`TTY_SIGMASK_EXIT` / `TTY_SIGMASK_WINCH` constants. All names + ABIs
preserved.

### Changed

- **`cyrius.cyml [deps.darshana].tag`** — `0.3.0` → `0.4.1`. Comment
  block expanded to record the bumped surface (SGR helpers, bounds
  check, ADR 0002) and the rationale (forward-compat refresh, no
  chakshu callsites yet).
- **`cyrius.lock`** — auto-refreshed by `cyrius deps`.
- **`CHAKSHU_VERSION`** — `"chakshu 0.6.0"` → `"chakshu 0.6.1"` in
  `src/main.cyr` line 20.
- **`VERSION`** — `0.6.0` → `0.6.1`.

### Fixed

- **`cyrius.cyml [build].test`** — added `test = "tests/chakshu.tcyr"`.
  The manifest previously omitted the `test` key, so bare
  `cyrius test` had no entry point. Surfaced while verifying this
  bump (`cyrius test src/test.cyr` ran against a nonexistent path
  and exited non-zero without printing assertions); the actual unit
  suite lives at `tests/chakshu.tcyr` and stays at 57/57 green.

### Unchanged (deliberately)

- All chakshu source files — no functional edits beyond the version
  literal in `src/main.cyr`.
- mihi pin (`0.8.0`) and ai-hwaccel pin (`2.2.6`) stay put — M2.5's
  dep tree is current as of yesterday's 0.6.0 cut.
- Cyrius toolchain pin (`6.0.1`) — chakshu is already on the
  ecosystem-current cycc.

### Verification

- `cyrius build src/main.cyr build/shu` — OK on the bumped manifest.
- `cyrius test` (resolves to `tests/chakshu.tcyr` via the
  newly-added manifest key) — 57/57 passed.
- `bash scripts/smoke.sh` — all M0–M2.5 smoke gates green against
  the darshana 0.4.1 dist bundle.

## [0.6.0] — 2026-05-20 — M2.5 close (mihi integration)

**Milestone close.** chakshu now consumes the
[mihi](https://github.com/MacCracken/mihi) probe library for all
identity / static-fact reads (hostname, kernel, distro, CPU model,
core count, total/available memory, uptime, GPU/accelerators).
Per-frame deltas (CPU%, disk rate, network rate, per-pid stats)
stay chakshu-local. This cut unblocks **mihi v1.0** — mihi's M6 gate
was chakshu integration, and it's now closed.

**Layered architecture established**: chakshu owns the per-frame
delta loop + TUI + process management; mihi owns the identity probes.
Future identity additions (username resolution, swap reporting,
threads/FDs in focus mode) will accrete on the mihi side rather than
re-introducing hand-rolled `/proc` reads in chakshu.

### Added

- **`[deps.mihi]` (0.8.0) + `[deps.ai-hwaccel]` (2.2.6)** in
  `cyrius.cyml`. mihi 0.8.0 is an "acknowledgment cut" — `dist/mihi.cyr`
  is byte-identical to 0.7.0 (mihi's CHANGELOG: "M5 acknowledgment cut.
  No source changes"). chakshu's surface against mihi is identical to
  what iam (mihi-0.7.0) consumes; bumping to 0.8.0 keeps chakshu's
  pin tracking mihi's latest tag.
- **Cyrius toolchain pin bumped 5.10.20 → 6.0.1** to match mihi's
  pin and the host's de-facto toolchain. Silences the M2-era
  toolchain-drift warning.
- **New stdlib modules** in the dep envelope: `slice`, `agnosys`,
  `fnptr`, `thread`, `freelist`, `ct`, `json`, `bench`. All
  transitively referenced by mihi and ai-hwaccel's distlib bundles;
  DCE eliminates the unused code from the linked binary.

- **`-p` plain-snapshot output now surfaces the full identity block:**
  ```
  host: <hostname>  up: <Nd HH:MM>  load: <L1 L5 L15>
  kern: Linux <release>  distro: <PRETTY_NAME>
  proc: <CPU model> (<N> cores)
  gpu:  <accelerator name> (<MiB>)               (omitted if none)
  mem:  <used> MiB used / <total> MiB total
  cpu:  <pct>%  disk: rd ... wr ...  net: rx ... tx ...
     PID S  CPU%  MEM% CMD
     ...
  ```
  - `proc:` (not `cpu:`) is the new label for the CPU-model line so it
    doesn't collide with the existing `cpu:` delta line — plain-mode
    output is sacred per design-spec §2.2.
  - `gpu:` line is **omitted entirely** when `mihi_gpu_count() == 0`
    (most CI runners + cloud VMs).
  - On hosts with multiple accelerators, the `gpu:` line lists them
    comma-separated.

- **GPU panel in TUI table mode** — chakshu's first GPU surface
  inside the interactive view. Sits at row 3, between `mem:` and the
  CPU/disk/net delta line. The row slot is reserved unconditionally
  so plug/unplug at runtime doesn't shift the process table — re-renders
  stay layout-stable.

- **Identity reads in TUI focus mode (`--pid N`)** also route
  through mihi (hostname, uptime, mem_total for the focused-pid mem%
  calc). No layout change; same row positions as v0.4.0.

### Changed

- **TUI table-mode layout shifted down by 1 row** to accommodate the
  GPU panel slot. Process-table viewport is now `_tui_rows - 6`
  (was `_tui_rows - 5`). Re-renders, SIGWINCH, sort/filter/kill,
  arrow-nav — all updated and PTY-smoke green.
- **`mihi_mem_free` actually reads `MemAvailable`** (per the mihi
  probe's own docstring) — preserves chakshu's pre-M2.5 "used =
  total - available" semantic, not the misleading "used = total -
  truly-free" semantic. No user-visible regression. The pre-3.14
  MemAvailable-absent → MemFree fallback that lived in
  `snapshot.cyr` is dropped; AGNOS targets current kernels and mihi
  is the layer that would re-add the fallback if needed.

- **`scripts/smoke.sh` updated for the new header shape.** Header
  assertions switched from absolute-line-number to line-anchored
  `grep` patterns (gpu line is host-variable, so line numbers no
  longer stable). Process-row counts now derived as "rows after the
  PID header" rather than total line counts. New co-field
  assertions: `distro:`, `(N cores)`.

- **`docs/design-spec.md` §3 (Data Sources)** restructured into
  identity-via-mihi and deltas-via-`/proc` layers. §4 (TUI Layout)
  mock now matches shipped text-anchored layout (the v0.1-scaffold
  box-drawn mock with CPU/Mem bar graphs is gone — bars are an M4
  polish target).

### Performance / size

- `shu -p` wall time unchanged from v0.5.0 (~110-111 ms, dominated
  by the 100 ms inherent two-sample window).
- **Binary size grew 292 KB → ~772 KB DCE'd** (text 588 KB + bss
  201 KB + data 0). The +458 KB text growth is mihi + ai-hwaccel —
  ai-hwaccel ships the full GPU/NPU/TPU/AI-ASIC detection-backend
  stack (ROCm, Intel NPU, AMD XDNA, Qualcomm, Groq, Samsung NPU,
  MediaTek APU), all linked in even though chakshu uses only the
  `registry_detect_no_exec()` entry. Cyrius DCE NOPs unreachable
  fns (~379 KB NOPed this cut) but doesn't strip them from the binary;
  M4 polish/perf needs to either pressure upstream codegen or pursue
  the `alloc()`-restructure path that the build hint flags. The
  design-spec §8 `<256 KB` target is now ~3× over — renegotiate or
  pursue stripping; flagged as M4 carry-forward.

### Known issues / carry-forward

- Identity panel placement in the TUI (kern / proc / distro lines) is
  M4 polish — the table view omits these to keep the process table
  tall; only `gpu:` made it into the table view at M2.5.
- USER column, swap reporting, username resolution still M2-deferred
  per `roadmap.md`.

## [0.5.0] — 2026-05-19 — M2 close

**Milestone close.** The full interactive TUI is shipped: alt-screen
mode, signal-safe cleanup, 1Hz refresh, SIGWINCH-driven re-layout,
arrow/sort/filter/kill keybinds, color theme, `--pid` focus mode, and
PTY-driven integration smoke. chakshu now functions as a usable
`htop` / `btop` replacement; AGNOS Bazaar default switch follows in
the M2.5 mihi-integration release.

This is a summary cut — no new code lands in 0.5.0 beyond the
M2 close audit. The substantive M2 work shipped across v0.2.1
through v0.4.0; see those entries for details.

### M2 arc summary (v0.2.1 → v0.4.0)

| Cut | Slice | Headline |
|-----|-------|----------|
| v0.2.1 | A+B+C | Alt-screen + raw mode + signalfd cleanup + 1Hz refresh loop |
| v0.2.2 | D+E   | SIGWINCH + dynamic window size + ↑↓ select + `s` sort cycle + viewport scrolling; 3 QA bugs fixed |
| v0.2.3 | E.5   | Filter mode + status line; cmdline-fall-through fix |
| v0.2.4 | F     | `k` kill + confirm dialog → SIGTERM |
| v0.2.5 | G.1   | PTY integration smoke gate; 2 latent input/winsize bugs caught + fixed |
| v0.3.0 | G.2   | 16-color theme + `--color` flag |
| v0.4.0 | G.3   | `--pid N` focus mode + render dispatcher + PTY smoke #7 |

### G.4 — close audit findings

- **Privacy invariants intact.** Zero reads of `/home`, env vars, or
  command-line args as prompt material. Surface to be exercised again
  at M3 (AI integration) when redaction lands.
- **No FFI / libc / dlopen** anywhere in `src/` — only comments
  asserting their absence. Stdlib + darshana 0.3.0 envelope holds.
- **Signal cleanup exhaustive.** Single `_tui_teardown` call site
  at `tui.cyr:1166`; all loop-exit paths (q, Ctrl-C, external
  HUP/INT/TERM via signalfd, degraded epoll-failed fallback) fall
  through to it before fd close. Signalfd-based design avoids the
  x86_64 `sa_restorer` trampoline trap entirely.
- **Stack footprint safe.** Largest single-fn stack accumulation is
  `tui_render_focus_frame` at **29 922 bytes** (~47% margin under
  the 64 KiB threshold).
- **Performance unchanged from v0.3.0 baseline.** `shu --version`
  cold start ~1 ms (design-spec §8 target <5 ms ✓). `shu -p` wall
  ~110-111 ms (≈100 ms inherent two-sample window + ~10 ms work —
  the work portion meets the <30 ms target with 3× margin). Steady-
  state CPU and memory-resident measurement deferred to M4 polish
  (host has no GNU `time`; needs proper tooling pass).
- **Binary size grew 183 KB → 293 KB across the M2 arc.** Investigation
  pinned the bulk to toolchain codegen drift (Cyrius 5.10.20 → 6.0.1,
  used de-facto despite the pin), not chakshu source. Of 165 KB bss:
  ~8.3 KB is chakshu module-globals + darshana 60 bytes; the
  remaining ~161 KB is Cyrius-runtime-emitted statics outside source
  control. Carry-forward for M4 — the design-spec §8 `<256 KB` DCE
  target is now ~37 KB over and may need either codegen pressure on
  the Cyrius project or implementing the build hint's
  `alloc()`-for-large-buffers restructure. Worth surfacing at
  agnosticos genesis level if other first-party binaries see the
  same 5.10 → 6.0 footprint jump.

### Changed

- Help text footer at `src/main.cyr:53` updated from
  `Status: v0.1.0 scaffold. Most flags are placeholders pending
  M1-M3.` to a current M2-complete / M3-ahead line.

### Known deferrals carried into M2.5+ (for the record)

These items showed up in the design-spec walk but were intentionally
not addressed at M2 close; logged here so they don't get re-discovered:

- **CPU/Mem bar graphs** (design-spec §4). Spec mocks
  `[████░░░░] 23%`; chakshu emits text-only. Decision deferred to M4
  polish — either update the spec or implement bars.
- **§9 spec language about "panic paths" and "double-fault path
  resets termios via direct syscall before re-raising"** is
  scaffold-era aspirational language that doesn't match Cyrius
  reality. Shipped behavior (signalfd-driven clean teardown) covers
  the realistic failure modes. Spec patch is a paragraph; deferred
  to a documentation sweep.
- **USER column, swap reporting, username resolution, threads/FDs in
  focus mode** — already enumerated as M2-deferred in `roadmap.md`.
- **Design-spec header still reads `Status: Scaffold (2026-05-07)`** —
  stale at M2 close; touched in this cut to read `M2 complete`.

## [0.4.0] — 2026-05-19 — `--pid` focus mode

Slice G.3 lands: `shu --pid N` launches the TUI focused on a single
process. The last code-bearing slice before the M2-close audit (G.4
cuts as v0.5.0). QA-confirmed before tag.

### Added

- **M2 Slice G.3 — `--pid N` focus mode.** New CLI flag launches
  the TUI focused on a single process. Layout (4 rows + status):
  - Row 1: `host: ...  up: ...  load: ...` (same as table mode)
  - Row 2: `── PID <N> (<comm>) <state> ──` (state colored)
  - Row 3: `ppid: X  uid: X  threads: X  rss: X KiB  mem: X%`
  - Row 4: `cmdline: <full cmdline, clipped to terminal width>`
  - Status row: `[k] kill  [q] quit  (focus mode — single process)`

  Refresh tick still applies (1Hz default). If the focused process
  exits during refresh, rows 2-4 collapse to `PID N has exited.`
  in red and the status row updates to `[q] quit (focused process
  exited)` — user can see the death and quit cleanly.

  `--pid` validates the PID exists at startup by attempting to open
  `/proc/<N>/stat`; failure exits 1 with `chakshu: --pid N: no such
  process`. `--pid 0` and missing-value get EXIT_USAGE.

- **Render dispatcher.** `tui_render_frame` is now a 5-line
  dispatcher that picks `tui_render_table_frame` (existing, renamed)
  or `tui_render_focus_frame` (new) based on `_tui_focus_pid`. All
  call sites unchanged — refresh tick / SIGWINCH / key events still
  call `tui_render_frame`.

- **Focus-mode key handling.** Sort/filter/arrow keys are no-ops
  in focus mode (no selection, no sortable list). `k` kills the
  focused pid (rather than the selected row); confirm flow shared
  with table mode. q/Ctrl-C exit; signalfd cleanup unaffected.

- **PTY smoke test #7** — exercises `shu --pid 1 → q`, asserts
  `PID 1` header + `cmdline:` label + `focus mode` status hint
  are present in output.

## [0.3.0] — 2026-05-10 — color theme

First minor bump of the M2 cycle — the TUI is now colored. Header
labels are bold; CPU%/MEM% values band on green/yellow/red
thresholds; process state letters color-code by category. Plain
mode (`-p`) stays uncolored per the deterministic-bytes rule.
QA-confirmed before tag.

### Added

- **M2 Slice G.2 — color theme + `--color` flag.** TUI mode now
  emits a 16-color theme by default. Plain mode (`-p`) is unaffected
  (deterministic bytes per design-spec §2.2).
  - **Header labels bolded:** `host:`, `up:`, `load:`, `mem:`,
    `cpu:`, `disk:`, `net:`, `wr`, `tx`, `rx`.
  - **CPU% column band:** green `< 25%`, yellow `< 70%`, red `>= 70%`.
  - **MEM% column band:** green `< 50%`, yellow `< 80%`, red `>= 80%`.
  - **State letter color:** R=green (running), D=blue (uninterruptible),
    Z=red (zombie), T=yellow (stopped), I=cyan (kernel idle —
    distinct semantic from S since these are kworker/* threads),
    others (S sleeping, etc.) dim.
  - **PID column dimmed** for visual hierarchy.
  - **Selection bar interaction:** colors are suppressed inside the
    reverse-video highlight so the bar stays visually clean (red-on-
    reversed-row would be illegible noise).
- **`--color {auto, always, never}` CLI flag.** Default `auto`; `auto`
  and `always` both enable color in TUI mode (true `auto` with `$TERM`
  detection is M3 polish — currently they're identical). `never`
  disables all color escapes. Validation rejects unknown values
  with EXIT_USAGE + helpful stderr message.
- New tui.cyr globals: `_tui_color_enabled`, `_tui_color_suppress`.
- New helpers: `_tui_color_emit/red/green/yellow/blue/cyan/dim/bold/reset`,
  `_tui_color_pct_band(pct, low, mid)`, `_tui_color_state(byte)`.
  Inline in tui.cyr; promotion to darshana deferred until cyim asks.

## [0.2.5] — 2026-05-10 — PTY smoke + input fixes

A patch release shipping Slice G.1: a PTY-based integration smoke
that drives the TUI through real keystrokes under a real terminal.
The new test caught two latent bugs immediately on its first run —
both shipping fixed in this release.

### Added

- **M2 Slice G.1 — PTY integration smoke gate.** New
  `tests/integration_smoke.py` spawns chakshu under a real PTY (so
  `tty_raw` succeeds), drives recorded keystroke sequences, and
  asserts on output substrings + exit code. Six test cases cover
  Slices A-F end-to-end:
  - Launch + `q` quit (verifies alt-screen enter/leave + headers)
  - Ctrl-C exit
  - `s` sort cycle
  - Filter mode round-trip (`f` → typed text → Enter → `q`)
  - Kill confirm cancel (`k` → `n` → `q` — never sends `y` so no
    actual signal goes anywhere)
  - Down-arrow CSI sequence (validates multi-byte read path)

  Wired into CI as a new step after `scripts/smoke.sh`. Runs against
  both the regular and DCE'd builds.

### Fixed

- **Input buffer dropping rapidly-arrived keys.** `_tui_read_key`
  was reading up to 4 bytes from stdin in one call but returning
  only the first — so when keys queued during a 100ms render tick
  (rapid typing in Filter mode, or batched keystrokes from any
  source), bytes 2-4 were silently lost. Now uses a 4-byte
  `_tui_input_buf` consumed one event at a time; the main loop
  drains it via `_tui_input_pending()` before re-entering
  `epoll_wait`. CSI arrow detection works at consume-time, not
  read-time, so an arrow embedded in a multi-byte read still
  parses correctly. _Caught by the PTY smoke test on the filter
  round-trip — the test would time out because the trailing `q`
  was being dropped._
- **`_tui_update_winsize` accepting a 0x0 winsize.** When
  `tty_winsize` succeeded but reported 0 rows / 0 cols (Python's
  `pty.fork()` default), chakshu would set `_tui_rows = 0` and
  `_tui_cols = 0`. The status row tried to render at row 0 (which
  terminals interpret as row 1) — stomping the host header — and
  the status text clipped to 0 bytes (nothing visible). Now also
  rejects 0/0, falling through to the cached 24x80 defaults. The
  PTY test sets winsize explicitly via `TIOCSWINSZ` so the layout
  paths are exercised under realistic dimensions.
- **Dispatch refactor.** Extracted the per-key handling out of
  `tui_run` into `_tui_dispatch_key(k)` so the buffer-drain loop
  can share the same dispatch path as the epoll/stdin branch. No
  behavior change beyond the input-buffer fix above.

## [0.2.4] — 2026-05-10 — kill action

A patch release shipping Slice F: the selection finally does
something. `k` on a selected process opens a `Kill PID <N>? [y/N]`
confirm; `y` sends SIGTERM; anything else cancels. q is
intentionally cancel-only inside confirm so an accidental q
during the prompt doesn't quit the whole app.

### Added

- **M2 Slice F — kill key + confirm dialog.** `k` (Normal mode)
  captures the selected row's pid and switches to a new mode
  `TUI_MODE_CONFIRM_KILL`; the status line shows
  `Kill PID <N>? [y/N]`. `y`/`Y` calls `sys_kill(pid, SIGTERM=15)`
  and returns to Normal; any other key cancels back to Normal
  without sending the signal. q intentionally cancels-only inside
  confirm — no accidental quit-while-confirming. Killed processes
  drop off the table on the next refresh tick; selection
  auto-clamps via the render's defensive recompute.
- New globals: `TUI_MODE_CONFIRM_KILL`, `_tui_kill_pid`,
  `TUI_KILL_SIGNUM` (= 15, SIGTERM). `sys_kill(pid, sig)` already
  in stdlib syscalls — no new dep needed.
- Status-line keybind hints now include `[k] kill`.
- Help text shortened to one-line keybind summary.

## [0.2.3] — 2026-05-10 — filter mode

A patch release shipping Slice E.5: a working filter (`f` keybind)
backed by a bottom status line. Filter substring-matches against
both `comm` (fast path, no syscall) and `/proc/<pid>/cmdline` (fall
through), so process-name and arg/path searches both work.
QA-confirmed before tag.

### Fixed

- **Filter now matches cmdline too.** Initial Slice E.5 only checked
  the kernel `comm` field (15-char executable name), so substrings
  containing args or paths — e.g. `claude --dangerously-skip-permissions`,
  `/usr/lib/Xorg`, `--socket /tmp/sddm` — never matched. Filter now
  tries comm first (cheap, in-memory), falls through to a
  `/proc/<pid>/cmdline` read on miss. Comm-first short-circuit means
  typical process-name filters never trigger the per-process file
  read; arg-bearing filters pay ~15ms / 300 procs at 1Hz refresh
  (acceptable). _Caught by user immediately on Slice E.5 first run._

### Added

- **M2 Slice E.5 — filter mode + status line.** New bottom row
  displays keybind hints in Normal mode (`[↑↓] move  [s] sort
  [f] filter  [q] quit`, plus `filter: <buf>` if active) and a
  prompt in Filter mode (`filter: <buf>_  (Enter: apply, Esc:
  clear)`). `f` (in Normal) enters Filter mode; printable chars
  append to the filter buffer, Backspace deletes the last byte,
  Enter exits to Normal (filter persists), Esc clears the filter
  and exits to Normal. Filter is a substring match against each
  process's `comm` field (16-byte cstring already in proc_recs —
  no extra /proc reads per frame). Filter against the full
  cmdline is a future polish item.
- New module globals: `_tui_mode`, `TUI_MODE_NORMAL`,
  `TUI_MODE_FILTER`, `_tui_filter_buf[64]`, `_tui_filter_n`,
  `_tui_filtered_idx[8192]` (1024 u64 indices),
  `_tui_filtered_n`. Selection + viewport now operate in filtered
  space — `_tui_select_down` and the render loop use
  `_tui_filtered_n` instead of `_proc_n`.
- New helpers: `_tui_proc_matches_filter`, `_tui_filter_clear`,
  `_tui_filter_append_byte`, `_tui_filter_backspace`,
  `_tui_render_status`, `_tui_status_append`,
  `_tui_status_append_bytes`. Status text composed into a 256-byte
  stack buffer with terminal-width clipping (no narrow-terminal
  wrap that could trigger the alt-screen scroll bug from Slice E).
- Mode-aware key dispatch in `tui_run` — Filter mode handles
  Esc / Enter / Backspace (0x7f and 0x08) / printable bytes
  (0x20-0x7e); Normal mode keeps q/Ctrl-C/↑/↓/s and adds `f`.

### Changed

- Bottom terminal row reserved for the status line. `max_rows`
  for the process table is now `_tui_rows - 5` (was `_tui_rows - 4`).
  `_tui_select_down` and `tui_render_frame` both updated.
- Post-render clear-to-end now uses `<` instead of `<=` (the status
  row is rewritten unconditionally — don't redundantly wipe it
  first).

## [0.2.2] — 2026-05-09 — M2 Slices D+E + QA pass

A patch release shipping two more M2 slices plus three real bugs
caught by interactive QA on small terminals — none of which would
have shown up in a unit-test-only workflow. The TUI is now fully
adaptive to terminal size: SIGWINCH triggers re-layout, the process
table viewport scrolls under a pinned highlight when there are
more processes than fit, and content never overflows the visible
area.

The big shape change since v0.2.1: chakshu now consumes
[darshana](https://github.com/MacCracken/darshana) **v0.3.0**
(was 0.2.0). darshana grew the chakshu-driven primitives —
`tty_winsize`, `tty_open_signalfd(mask)`, `TTY_SIGMASK_EXIT/WINCH`,
`tty_clear_to_eol/end` — completing Phase 3 of the original TUI
extraction plan. chakshu has zero termios/ANSI code of its own.

### Added

- **M2 Slice E — keybinds (↑/↓ + `s`).** Three new interactions:
  - `↑` / `↓` move row selection within the displayed process table;
    selection is highlighted with reverse-video (CSI 7m / 0m). Clamped
    to `[0, n_visible)` where `n_visible = min(top_n, terminal_rows - 4,
    actual_proc_count)`. Auto-clamps if the visible row count shrinks
    (terminal resized smaller, sort changed, processes exited).
  - `s` cycles the sort key in the order CPU → MEM → PID → NAME → CPU.
    Resets selection to row 0 (the previous index almost certainly
    points to a different process after re-sort).
  - All three trigger an immediate re-render — no waiting for the
    next 1Hz tick. UI feels instant.
- New `_tui_read_key` parses multi-byte CSI escape sequences. Reads
  up to 4 bytes in one syscall (xterm-family terminals send arrow
  sequences as one packet, so the additional bytes are already in
  the kernel buffer when the first byte unblocks). Returns synthetic
  key codes (`KEY_UP`/`KEY_DOWN`/`KEY_LEFT`/`KEY_RIGHT` = 1000-1003,
  above the 0..255 byte range) for arrows; raw byte for everything
  else. Bare Esc returns 0x1b — chakshu currently ignores; Slice E.5
  may repurpose for filter-cancel.
- New module globals: `_tui_sort_key`, `_tui_top_n`,
  `_tui_selected_idx`, `_tui_view_offset`. Promoted from tui_run
  params so any input handler can mutate them and trigger a
  re-render in place. Seeded from CLI flags at tui_run startup.
- **Viewport scrolling.** Selection range is bound by `--top` (and
  actual proc count); terminal height bounds the visible window
  but NOT the navigable range. Pressing ↓ at the bottom-visible
  row scrolls the viewport down so the selection stays in sight;
  ↑ at the top scrolls up. On a 6-row terminal (only 2 process
  rows visible), the user can still navigate through all of
  `--top`'s processes by scrolling. Resize / sort / process exit
  re-clamp `_tui_view_offset` defensively in `tui_render_frame`.

### Fixed

- **Off-by-one in the post-render `tty_move`** that caused the
  alt-screen to scroll up by one line when the process table
  exactly filled the visible area (e.g., `--top 4` on an 8-row
  terminal, or any small terminal at default `--top 10`). The
  trailing `tty_move(5 + n, 1) + tty_clear_to_end()` pair was
  moving to row `_tui_rows + 1` — past the bottom — and some
  terminals respond by scrolling the alt-screen, pushing the top
  header off-screen and making the bottom highlight appear to
  vanish. Now guarded with `if (5 + n <= _tui_rows)`. _Caught by
  user interactive testing on a 6-row terminal._
- **Viewport scroll wasn't actually scrolling** in small terminals
  because `tui_render_frame` had a leftover `top_n = max_rows`
  cap from before scrolling existed. That clamped the navigable
  range back to terminal-height — `_tui_select_down` would set
  `_tui_view_offset = 6`, render's defensive last-clamp would see
  `view_offset + max_rows > max_navigable` and reset offset to 0.
  Selection appeared pinned to the bottom-visible row but the
  viewport never advanced past the initial 5 processes. Removed
  the cap; `top_n` now cleanly represents the user's `--top` value
  (navigable range), and `max_rows` separately bounds the visible
  window. _Caught by user interactive testing — selection wouldn't
  reach processes 6-10 on a 9-row terminal with --top 10._
- **Cmdline auto-wrap scrolling the alt-screen.** Per-process row
  content (pid + state + cpu% + mem% + cmdline) wasn't bounded by
  terminal width. Long cmdlines (Xorg's argv is 100+ chars) would
  exceed `_tui_cols`, the terminal would auto-wrap the text to
  the next line, the cursor would advance past `_tui_rows`, and
  the alt-screen would scroll — pushing the host/uptime/load line
  off the top. Headers reappeared on the next 1Hz tick because
  `tty_cursor_home + write` wrote to row 1 again, but each ↓
  keypress that scrolled into a long-cmdline process re-triggered
  the bug. Now clips cmdline to `(_tui_cols - 21)` (the prefix is
  exactly 21 cols wide); bracketed `[comm]` fallback also clips
  for kernel threads. _Caught by user testing on a terminal too
  narrow to fit Xorg's full cmdline._
- New helpers: `_tui_invert_on/off`, `_tui_cycle_sort`,
  `_tui_select_up/down`. The invert pair will promote to darshana
  when a second consumer wants reverse-video.

### Changed

- `tui_render_frame` is now parameterless — reads `_tui_sort_key`,
  `_tui_top_n`, `_tui_selected_idx` from globals. Selection clamp
  happens inside the render so any caller (refresh tick, keypress,
  WINCH) gets correct behavior.

- **M2 Slice D — SIGWINCH + dynamic window size.** TUI layout now
  adapts to the actual terminal dimensions. A second signalfd
  (separate from the exit-signalfd for clearer dispatch — fd
  identity == intent) routes SIGWINCH to the epoll set; on resize,
  the loop drains the fd, calls `tty_winsize` to refresh cached
  rows/cols, full-clears the alt-screen, and re-renders. The process
  table is capped at `(rows - 4)` so it never overflows the visible
  area regardless of `--top`. New module globals `_tui_rows` /
  `_tui_cols` (default 24×80) populated at startup and on every
  WINCH event — render-time cost is one variable read instead of a
  per-frame ioctl.
- New `_tui_update_winsize()` helper.
- Phase 3 of the original TUI extraction plan **complete**: the
  signal/clear inline helpers from Slices B+C are gone, replaced
  by their darshana 0.3.0 equivalents. chakshu now delegates all
  TTY work — termios, ANSI, cursor positioning, signalfd, winsize,
  partial-clear — entirely to darshana.

### Changed

- **darshana dep bumped 0.2.0 → 0.3.0** (`cyrius.cyml [deps.darshana]`).
  Brings in `tty_winsize`, `tty_open_signalfd(mask)`,
  `TTY_SIGMASK_EXIT/WINCH`, `tty_clear_to_eol`, `tty_clear_to_end`.
- **Inline helpers removed in favor of darshana:**
  - `_tui_open_exit_signalfd` → `tty_open_signalfd(TTY_SIGMASK_EXIT)`
  - `_tui_clear_eol` → `tty_clear_to_eol` (5 call sites updated)
  - `_tui_clear_to_end` → `tty_clear_to_end` (1 call site)
  - `TUI_EXIT_SIGMASK` const removed (now `TTY_SIGMASK_EXIT` in darshana)
  - `_tui_print_cstr` removed (unused since Slice C's render replaced
    the placeholder paint)

## [0.2.1] — 2026-05-09 — M2 in-progress checkpoint

A patch release shipping the first three M2 slices — chakshu now has
a working interactive TUI. v0.5.0 (per the roadmap) closes M2 with
SIGWINCH, keybinds, kill-with-confirm, `--pid`, color, and the PTY
smoke gate. v0.2.x patches mark intermediate ship-able checkpoints.

The big shape change since v0.2.0: bare `shu` (no args) now launches
a full-screen TUI on the alt-screen at 1 Hz refresh, powered by the
new [darshana](https://github.com/MacCracken/darshana) library.
chakshu has no termios code of its own — `darshana` owns that layer.
`shu -p` (plain snapshot) is unchanged.

### Added

- **M2 Slice C — render loop + real layout.** The TUI now refreshes
  every 1 second (configurable via `--rate <Hz>`, integer 1-10).
  `epoll_wait` runs with a finite timeout — on timeout it re-renders
  the frame; stdin and signalfd dispatch unchanged from Slice B.
  Layout matches plain mode: row 1 host/up/load, row 2 mem,
  row 3 cpu/disk/net deltas, row 4 process-table header, rows 5-N
  process rows. Cursor positioned with `tty_move` per row + clear-
  to-eol so successive frames overwrite cleanly.
- New `tui_render_frame(sort_key, top_n)` — duplicates the M1
  snapshot data gather + format with TUI-friendly output (no
  `\n` since OPOST is cleared). Uses the same proc.cyr / processes.cyr
  parsers and the same 100ms inter-sample window. ~150 LoC of
  duplication with snapshot.cyr, marked as a future-refactor
  candidate (extract a shared "snapshot data" core that both plain
  mode and TUI render from).
- New `_tui_clear_eol` / `_tui_clear_to_end` — inline ANSI helpers
  (CSI K and CSI J). Two more darshana-extraction candidates when
  partial-clear gets a second consumer.
- New `--rate <Hz>` CLI flag with validation (1-10 integer; rejects
  `0`, `>10`, and non-numeric like `foo`). Help text updated.
- Bare `shu` now falls through to a single dispatch path at the
  bottom of `main()` instead of short-circuiting at the top —
  removes the previous bug where the args-loop accumulators weren't
  declared yet at the bare-invocation branch.

- **M2 Slice B — signal-safe cleanup.** The TUI now multiplexes stdin
  and a signalfd via epoll, so external SIGHUP / SIGINT / SIGTERM
  (`kill <pid>` from another terminal, parent shell HUP, etc.)
  trigger `_tui_teardown` instead of leaving the terminal in
  raw + alt-screen + cursor-hidden state. Setup degrades gracefully
  if signalfd or epoll fails — falls back to the Slice A direct-stdin
  loop so the binary still launches with reduced signal handling
  rather than refusing.
- New `_tui_open_exit_signalfd()` helper in tui.cyr: blocks the exit
  signals via `sys_sigprocmask` (`TUI_EXIT_SIGMASK = 0x4003` for
  HUP/INT/TERM) and creates a signalfd that delivers them. Belongs
  in darshana proper as the "guaranteed cleanup at exit" primitive
  any TUI consumer would want; lives in chakshu for slice-B velocity
  and is structured to extract mechanically when cyim asks.
- Avoided the `rt_sigaction` x86_64 sa_restorer trampoline trap by
  using signalfd instead of synchronous signal handlers — pure
  syscall, no inline assembly needed.

- **M2 Slice A — minimum viable TUI.** Bare `shu` invocation now
  enters the alt-screen + raw mode via darshana, paints a placeholder,
  and reads input one byte at a time. Exits cleanly on `q` or Ctrl-C
  (the latter arrives as byte 0x03 because `tty_apply_raw_flags`
  clears ISIG — same convention as vim). On non-TTY stdin (CI runners,
  `shu < /dev/null`), `tty_raw` fails and we exit 1 with a stderr
  message pointing the user at `-p` for plain mode.
- New `src/tui.cyr` — `tui_run()` plus `_tui_print_cstr` /
  `_tui_read_key` / `_tui_teardown` helpers. Slices B–G grow this:
  signal-safe cleanup (B), real refresh loop reusing the M1 snapshot
  (C), SIGWINCH (D), keybinds (E), kill-with-confirm (F), `--pid`
  focus + color + PTY smoke (G).
- **darshana 0.2.0 wired in.** `cyrius.cyml` now declares
  `[deps.darshana]` git+tag+modules pointing at the published v0.2.0
  release; `cyrius deps` resolves `dist/darshana.cyr` into
  `lib/darshana.cyr` and `cyrius.lock` records the SHA256. The TTY
  primitives (`tty_raw`, `tty_cooked`, `tty_alt_enter/leave`,
  `tty_clear`, `tty_cursor_*`, `tty_move`) all come from darshana —
  chakshu has no termios code of its own.

### Changed

- Bare `shu` no longer prints `--help`; it launches the TUI per the
  design-spec. `--help` still works for the help text. Smoke updated:
  the prior `bare → exit 0` assertion is now `bare in non-TTY →
  exit 1 with 'not a TTY' stderr`.

- **Cyrius toolchain pin bumped 5.9.32 → 5.10.20** (`cyrius.cyml [package].cyrius`). Coordinated with the [darshana](https://github.com/MacCracken/darshana) v0.1.0 scaffold (which chakshu picks up at M2/Phase 5 of the TUI extraction plan); both repos move together. Build/test/smoke verified green at the new pin: 57/57 tests pass, `shu -p` wall ~108 ms.

### Fixed

- CI Test step uses explicit `cyrius test tests/chakshu.tcyr` rather than bare `cyrius test`. The bare form's auto-discovery failed in darshana's CI on the 5.10.20 toolchain artifact (`No .tcyr files found in tests/tcyr/ or tests/` despite the file being checked in); chakshu would have hit the same regression on its next CI run. Documented form per `cyrius help test` is `cyrius test <test.cyr>` — using it explicitly removes the discovery surface from CI.

## [0.2.0] — 2026-05-07 — M1 close

The plain-snapshot milestone. `shu -p` is now a complete single-frame
system view — header + memory + cpu/disk/net rates + top-N process
table — pipeable, deterministic, sub-30 ms work-budget on the dev box.
Replaces `htop -d 1 -t -n 1` for the "what's the box doing right now?"
use case from a script. Interactive TUI is the M2 work.

Output shape (default `shu -p`):

```
host: archaemenid  up: 0d 01:33  load: 1.15 0.74 0.64
mem:  2994 MiB used / 61193 MiB total
cpu:  4%   disk: rd 0 B/s wr 0 B/s   net: rx 22 KiB/s tx 21 KiB/s
   PID S  CPU%  MEM% CMD
  3037 S    29     0 claude --dangerously-skip-permissions
  ...
```

### Added

- **Slice A — single-read fields.** Lines 1–2 of `-p`. Reads
  `/proc/sys/kernel/hostname`, `/proc/uptime`, `/proc/loadavg`,
  `/proc/meminfo`. Uptime formatted `Nd HH:MM`; mem in MiB used / total.
- **Slice B — delta-source line.** Line 3 of `-p`. Two samples 100 ms
  apart (`chrono.sleep_ms`); aggregates `/proc/stat` first cpu line
  (idle = idle + iowait), `/proc/diskstats` summed sectors × 512 across
  non-loop/ram/zram/dm-/mdN devices, `/proc/net/dev` summed bytes
  across non-loopback interfaces. Auto-unit rate formatter
  (B/s → KiB/s → MiB/s → GiB/s).
- **Slice C — process table.** Walks `/proc/<pid>/stat` twice (paired
  with the slice B 100 ms window — no extra latency). Per-process CPU%
  in the htop convention (per-core × 100 max, so a thread pegging one
  core reads 100 % regardless of how many cores are idle). Columns
  `PID S CPU% MEM% CMD`; MEM% = rss_pages × page-size / mem_total.
  `map_u64` for pid → ticks lookup across samples; insertion sort
  on the records array.
- **Slice D — `--sort` / `--top` / cmdline / M1 close.**
  - `--sort cpu|mem|pid|name` (default cpu). CPU/MEM descending,
    PID/NAME ascending. Pluggable comparator so M2 can grow the key
    set without touching the walker.
  - `--top N` (default 10). Negative or zero rejected with EXIT_USAGE.
  - CMD column now reads `/proc/<pid>/cmdline` (null separators →
    spaces) for the displayed top-N rows only. Kernel threads (empty
    cmdline) fall back to `[<comm>]` per htop convention. Caps reads
    at N per snapshot, not one per pid.
  - Mode-flag accumulation refactor in `main.cyr` so `--sort mem -p`
    works (CLI parsing collects flags, then dispatches).
  - `eprint_cstr` helper — strlen-based stderr writes, no manual
    byte counts.

### Module layout

- `src/main.cyr` — CLI parse + mode dispatch.
- `src/proc.cyr` — `/proc` read + parse layer (single-read fields,
  delta-source aggregates, `/proc/<pid>/stat` parser, helpers).
- `src/processes.cyr` — pid walker, sample-1/sample-2 orchestration,
  sort, top-N renderer with cmdline reads.
- `src/snapshot.cyr` — `-p` mode: assembles the three header lines
  and calls processes_render for the table.

### Fixed

- `_proc_next_uint` previously stalled on `-1` (the `tpgid` field in
  `/proc/<pid>/stat` for processes with no controlling tty), silently
  returning 0 for every subsequent field. Now consumes a leading `-`
  so signed fields can be skipped past. _Caught by parser unit test
  before integration could mask it._
- Two off-by-one byte counts in stderr literals (em dash in slice A's
  unimplemented message; leading space in `--sort: unknown key '...'`).
  Replaced manual counts with strlen-based `eprint_cstr` everywhere.
  _Second one caught by reading the user-visible error output._

### Tooling

- **CI/release workflows.** `.github/workflows/ci.yml` (three jobs:
  build-and-test → lint → tests → smoke → DCE parity; security scan;
  docs + version-consistency) and `.github/workflows/release.yml`
  (semver-tag-triggered, gates on CI via `workflow_call`, version-verify
  against tag, build matrix, source tarball, GH release with body
  extracted from the matching CHANGELOG section). Patterned on owl's
  CI; scoped to chakshu's M1 surface (no fuzz/bench/PTY harnesses yet).
- `scripts/smoke.sh` — 17-gate end-to-end exerciser of the closed
  M0+M1 surface. Locks down: version/help short-long parity, exit-code
  matrix (unknown=2, unimplemented=1, usage=2), `-p` line shape
  (host/mem/cpu/PID-header order), `--top` validation, `--sort` keys
  (incl. ASC pid ordering check), pipe sanity, wall-time budget.
  Runs under bash (uses `<(...)` and `$'\x...'` escapes — not posix sh).
- Version consistency in CI now closed-loop: VERSION = CHANGELOG
  section header = cyrius.cyml `${file:VERSION}` indirection =
  CHAKSHU_VERSION literal. CI fails closed on drift.

### Tests

- 57 assertions across 13 groups, up from 10 at scaffold close.
  Coverage: meminfo/uptime/loadavg/trim helpers; aggregate cpu line;
  diskstats + exclusion rules (incl. `mdctl` not-excluded edge case);
  netdev + lo exclusion; ncores counting; pid name validator; path
  builder; `/proc/<pid>/stat` parser including `(foo (bar) baz)`
  comm with internal parens; signed-field skip via the `-1` bug fix.

### Performance

- 110 ms wall (~100 ms sample window + ~10 ms work) on dev box.
  Roadmap M1 perf gate was `< 30 ms` per frame (work portion); met
  with 3× margin.
- Binary size: 141 KB (was 85 KB at M0; +56 KB for proc/snapshot/
  processes modules + chrono + hashmap + vec).

## [0.1.0] — 2026-05-07

Initial scaffold.

### Added

- Repo structure: `src/`, `docs/`, `tests/`, root metadata.
- `cyrius.cyml` manifest pinned to Cyrius 5.9.32; binary output `shu`.
- Stdlib footprint declared for the M0–M2 arc (`syscalls`, `fs`, `termios`, `time`, `process`, `args`, `hashmap`, etc.).
- `docs/design-spec.md` — name etymology, scope, /proc data sources, TUI layout, AI integration plan.
- `docs/development/roadmap.md` — M0 through M5 milestones to v1.0.
- `docs/development/state.md` — current toolchain pin and active milestone.
- `src/main.cyr` skeleton with `--help` and `--version`.
- `tests/chakshu.tcyr` smoke test.
- ADR 0001: binary name `shu` (System Health Utility — Sanskrit *chak**shu*** contraction; `ctop` considered and rejected to avoid `bcicen/ctop` namespace conflict).

### Notes

- No system-monitor functionality yet. Use `htop` or `btop` from the Bazaar in the meantime.
- The scaffold's `cyrius.cyml` declared `time` (real name: `chrono`) and `termios` (no toolchain equivalent — TUI lib extraction is M2 work, recorded in roadmap M2). Both fixed in v0.2.0; see that entry's _Fixed_ section.
- The scaffold's `src/main.cyr` was wired against an imaginary stdlib API (`args_count` / `args_get` / `str_eq` / 1-arg `print`); rewritten against the real surface in v0.2.0.
