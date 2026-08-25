# chakshu — Roadmap

> **Status**: M0–M2.5 closed; **M3 (AI integration) nearly done** — live `--explain` + streamed `?` overlay via hoosh shipped across v0.7.2–v0.7.4 (lean/AI binary split); v0.7.5 and v0.7.6 were interim toolchain/dep refreshes (Cyrius → 6.2.24, mihi → 1.1.1, darshana → 0.7.1, niyama 1.0.5). **One cut left to close M3: v0.7.7 (`--watch` + `--with-logs`).** Then M4 (polish/perf) and M5 (v1.0 ship). | **Last Updated**: 2026-08-24
>
> The path from v0.1.0 (scaffold) to v1.0 (ships as the AGNOS default system monitor, replacing the third-party `htop`/`btop` Bazaar packages).

---

## Closed milestones

- **M0 — Scaffold (v0.1.0, 2026-05-07)** ✓ Repo structure, manifest, CLAUDE.md, design-spec, ADR-0001 (binary name `shu`), `--help`/`--version`.
- **M1 — Plain snapshot (v0.2.0, 2026-05-07)** ✓ `shu -p` produces a complete single-frame system view (host/uptime/load/mem/cpu/disk/net + sortable top-N process table). 110 ms wall, ~10 ms work — under the `< 30 ms` per-frame target with 3× margin. See CHANGELOG `[0.2.0]`.
- **M2 — Full TUI (v0.5.0, 2026-05-19)** ✓ Full interactive monitor: alt-screen, signal-safe cleanup (signalfd), 1Hz refresh, SIGWINCH-driven re-layout, ↑↓ select, `s` sort cycle, `f` filter (comm+cmdline), `k` kill with confirm, `--pid N` focus mode, 16-color theme, PTY integration smoke. G.4 close audit clean: privacy invariants intact, no FFI/libc, exhaustive signal cleanup, largest single-fn stack 29 922 B (47% under 64 KiB threshold), `-p` work portion meets <30 ms target with 3× margin. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code. M2-deferred items for the record: threads/FDs in focus, per-focused-pid CPU%, true `--color auto`, fractional `--rate`, username resolution, USER column, swap reporting. See CHANGELOG `[0.5.0]`.
- **M2.5 — mihi integration (v0.6.0, 2026-05-20)** ✓ Identity / static-fact reads (hostname / kernel / distro / cpu_model / cpu_count / mem_total / mem_free / uptime / gpu_*) now flow through `lib/mihi.cyr`; per-frame deltas stay chakshu-local. New `-p` identity block (kern / proc / gpu lines) + GPU panel slot in TUI table mode — **basic GPU monitoring is live** (deepening it is tracked under M4). mihi was pinned v0.8.0 at the cut; **mihi has since shipped v1.0 and chakshu pins `1.0.0` as of v0.7.1**. Binary size grew 293 → 772 KB at the cut (ai-hwaccel backend stack linked-but-DCE-NOPed; carried to M4). See CHANGELOG `[0.6.0]`.

## Interim cuts (toolchain / dep refreshes — no new feature surface)

- **v0.6.1 (2026-05-20)** — darshana 0.3.0 → 0.4.1 forward-compat refresh. No behavior change.
- **v0.7.0 (2026-06-06) — AGNOS build-target cycle opened.** `shu` targets AGNOS: system stats via mihi `uname` / `sysinfo`. The **`klug` kernel-log view** (via the `klog` syscall) is **deferred until the AGNOS cycle picks up** — described at cut-time but not yet implemented in `src/`.
- **v0.7.1 (2026-06-10)** — Cyrius 6.0.1 → 6.1.27; mihi 0.8.0 → 1.0.0; stdlib `json` → `bayan` (6.1.x rename); ai-hwaccel held at 2.2.6 to match mihi's transitive pin. No behavior change at the chakshu surface. See CHANGELOG `[0.7.1]`.
- **v0.7.5 (2026-06-13)** — Cyrius 6.1.29 → 6.2.2 (both manifests); niyama 1.0.4 → 1.0.5 (AI build). darshana 0.7.0 / mihi 1.0.0 already latest; ai-hwaccel still held at 2.2.6 (mihi pin). Both builds + smoke green on 6.2.2; no behavior change. See CHANGELOG `[0.7.5]`.
- **v0.7.6 (2026-06-19)** — Cyrius 6.2.2 → 6.2.24 (both manifests); mihi 1.0.0 → 1.1.1 and darshana 0.7.0 → 0.7.1 (both builds). ai-hwaccel held at 2.2.6 (mihi 1.1.1 still pins it); niyama held at 1.0.5 (latest). Both builds + smoke green on 6.2.24; no behavior change. The M3-closing `--watch` / `--with-logs` feature cut moved 0.7.6 → **0.7.7**. See CHANGELOG `[0.7.6]`.
- **v0.7.8 (2026-06-22)** — Cyrius 6.2.24 → 6.2.36; darshana 0.7.1 → 0.8.0 (agnos `tty_winsize` / winsize#60). See CHANGELOG `[0.7.8]`.
- **v0.7.9 (2026-06-22) — agnosys retirement rewire.** cyrius retired the stale stdlib `agnosys` snapshot at 6.2.37; chakshu dropped `"agnosys"` from both manifests, added `"sys"`, bumped mihi 1.1.1 → 1.1.3 (the `sys_uname` / `sys_sysinfo` rewire) + cyrius → 6.2.37, brought `ai/` darshana → 0.8.0, and added a `cyrius lib sync` CI step. Host build clean. The `--watch` / `--with-logs` cut slides to **0.7.10**. See CHANGELOG `[0.7.9]`.
- **v0.7.11 (2026-07-17)** — Cyrius 6.2.37 → 6.4.66 (both manifests, resolving the wrapper pin drift); mihi 1.1.3 → 1.2.1 (both); `ai/` darshana 0.8.0 → 0.9.0 (lockstep with root) and niyama 1.0.5 → 1.0.6. ai-hwaccel held at 2.2.6 (mihi 1.2.1 still pins it). Both builds + smoke green; lean `shu` shrank to ~0.48 MB. **Caveat:** `shu-ai` balloons ~2.27 → ~15.49 MB under the 6.4.66 codegen (13.48 MB static `.bss` from two oversized array locals promoted to shared globals in the sandhi/TLS chain — compiler, not deps; fixable only upstream). Flagged for M4. See CHANGELOG `[0.7.11]`.
- **v0.7.12 (2026-08-24)** — Cyrius 6.4.66 → 6.5.35 (both manifests, resolving the wrapper pin drift again); darshana 0.9.0 → 1.0.0 (darshana's **v1.0 API freeze** — the 15 symbols chakshu uses are now contractually stable); mihi 1.2.1 → 1.2.4; **ai-hwaccel 2.2.6 → 2.3.18 — the four-cut hold ends**, because mihi 1.2.4 finally advanced its own transitive pin (the tracking rule is unchanged, not suspended; the two must move in lockstep or ai-hwaccel 2.3.x leaks `detect: profiles=N` to stderr mid-frame). `ai/` niyama 1.0.6 → 1.0.7 (pin-only). `sakshi` declared in the lean `[deps].stdlib` — byte-neutral, and it documents a genuinely reachable dep (`mihi_gpu_count()`). **No source changes needed for any of the five bumps.** Both builds + smoke + PTY + DCE parity green. **The 0.7.11 `shu-ai` size regression is FIXED** by the toolchain: ~15.49 → ~3.02 MB (`.bss` 13.48 MB → 871 KB), and the 0.7.11 root-cause note was **misattributed** — it was sigil's banked crypto globals (reclaimed by cyrius 6.5.22), not sandhi/TLS array locals. **New caveat:** the lean `shu` grew ~0.48 → ~0.86 MB, ~72% of it the cycc 6.5.16 change (emits every declared stdlib module; `CYRIUS_DCE=1` no longer shrinks anything) and ~28% the dep bumps. Flagged for M4. See CHANGELOG `[0.7.12]`.

## v0.7.13 — P-1 audit / hardening sweep (landed 2026-08-24)

A **P-1 audit, refactor, hardening, optimization and security sweep** with repairs —
whole-tree scope rather than a milestone slice. Seven audit dimensions; every finding
adversarially re-verified against a real build before being acted on, and 10 of 58
candidate findings refuted and dropped. See CHANGELOG `[0.7.13]`.

**Landed:**

- [x] **Signal-mask leak in the TUI teardown** — bare `file_close()` on the two
  signalfds left HUP/INT/TERM and WINCH blocked (`SigBlk` measured `0x08004003`).
  Now `tty_close_signalfd(fd, mask)`. Guarded by a live-kernel contract test and a
  `ci.yml` pattern scan.
- [x] **Terminal / prompt injection via untrusted `/proc` bytes** — an unprivileged
  process could forge table rows and emit ANSI into the monitor watching it, in plain
  mode. Scrubbed at the `cmdline` and `comm` choke points.
- [x] **Secret-redaction misses** — `PASSWORD=` and every space-separated, JWT, AWS
  key-id and URL-userinfo credential shipped verbatim to hoosh. Case-folded, widened
  vocabulary, cross-token lookback, shape rules.
- [x] **Kill-confirm typeahead bypass** — a `ky` burst killed with no prompt drawn.
  Kernel + userspace input flush on arming, plus a 250 ms dwell.
- [x] **~44 KB/frame TUI leak** — breached the §8 8 MB RSS budget in ~90 s. Measured
  4,556 → 12,748 kB over 400 frames before; flat at 4,900 kB after.
- [x] **`PROC_MAX` hid the busiest process** on >1024-proc hosts (the walk broke before
  the sort). Raised to 8192, forfeiting a −57 KB binary saving.
- [x] Shift-hole sort rewrite; negative rate clamp; uptime / cpu-count sentinels;
  truncated-diskstats stale totals; focus-panel stale frame; `out_rec` init; three
  newline-truncated diagnostics; `-p --pid` rejection.
- [x] **Coverage**: lean 64→77, AI 13→21, PTY 7→9 — every addition mutation-checked.
  Deleted a proven-vacuous version-string test.

**Also landed (the sweep's second pass — no P-1 finding was left deferred):**

- [x] **`R10` — line-anchored `/proc/<pid>/status` parsing.** `proc_meminfo_field` used
  an unanchored `strstr`, so a process renamed to `Uid:0` via `prctl(PR_SET_NAME)` planted
  a match at offset 6 that beat the real `Uid:` line at offset 98 — chakshu reported an
  unprivileged process as **uid 0**, in the focus panel *and* in the prompt sent to hoosh.
  Reproduced live; now line-anchored, which fixes every caller at once.
- [x] **`R7(b,c)`** — 64 KiB heap scratch + truncation detection. Measured: at the old
  8 KiB cap a 200-interface `/proc/net/dev` aggregated only 65 interfaces
  (rx 65,000,000 of 200,000,000 — a 67% undercount, silently reported as success).
  Callers consume partial data and can check `proc_truncated()`; they never fail, since
  refusing to run on a big host is strictly worse than an approximate rate.
- [x] **`R14`** — the `?` overlay parked in a blocking `read(0,…)` with HUP/INT/TERM
  SIG_BLOCKed and the signalfd undrained, so `kill` was inert until a keypress. Now polls
  stdin *and* the signalfd, and returns a sentinel so teardown runs through `tui_run`
  rather than stranding the mask. Verified: pre-fix ignored SIGTERM, post-fix exits.
- [x] **`R15`** — signalfds opened before a failed `epoll_create` were never unblocked,
  leaving the degraded launch unkillable. Reproduced at `ulimit -n 5`: pre-fix needed
  SIGKILL, post-fix honours SIGTERM.
- [x] **`R16`** — `mihi_mem_free()` −1 rendered `61192 MiB used / 61192 MiB total`.
  Guarded at all three sites; the `ai.cyr` one mattered most, where the sentinel became a
  fabricated OOM premise in the model's prompt.
- [x] **`R19`/`R20`** — CI. The AI-privacy grep was wrapped in `if [ -d src/ai ]` and had
  **never executed** — the AI shipped as the *file* `src/ai.cyr`, so the most
  privacy-critical gate in the repo was dead scaffolding for five releases. Re-pointed,
  plus a new binary-level AI-opt-in gate (the lean manifest must declare no transport
  module — and note `sandhi` is a stdlib entry, so scanning `[deps.*]` tables misses it).
  `R20`'s large-buffer gate is now scope-aware (module-scope is 8 bytes/element, locals
  1) with `FNR` instead of `NR`, plus a visible `# bigbuf-ok:` escape hatch — it
  immediately caught `_tui_filtered_idx` at exactly 65,536 B, which is now an annotated,
  reviewed exemption rather than a silently loosened threshold.
- [x] **`R21`** — `avail = _tui_cols - 21` hardcoded a 6-digit PID column; this box ships
  `pid_max = 4194304` (7 digits), making the row one column too wide, wrapping it, and
  scrolling the header off. Now derived per row.

**Binary size — upstream fixed and consumed (v0.7.14, 2026-08-24):**

- [x] **ai-hwaccel 2.3.19** — 11 `json_v_*` call sites moved to canonical
  `bayan_json_v_*`; `bayan` swapped out of `[deps].stdlib` for a focused
  `[deps.bayan] modules = ["dist/bayan-json.cyr"]`. Sidecar 19 → 18 leaves. 13/13 green.
- [x] **mihi 1.2.5** — dropped the `bayan` entry it carried as cover for ai-hwaccel's
  bundle (mihi's own source references zero bayan/json symbols). 143/143 green.
- [x] **chakshu 0.7.14** — pins both, drops `"bayan"` from the lean stdlib list.
  **861,536 B → 571,480 B, −290,056 B (−33.7%).** §8 goes ~3.4× → **~2.2× over**.

- [ ] **Remaining size gap.** 571,480 B against §8's 256 KB. The safe chakshu-side drops
  (`bench`, `freelist`, `tagged`, `slice`) total only ~25 KB, and `CYRIUS_DCE=1` has been
  a parity check rather than an optimizer since cycc 6.5.16 — it NOPs dead code in place
  and emits a byte-identical binary. So closing the rest means either revising §8's target
  or further upstream work on what the mihi/ai-hwaccel bundles pull in. Not a chakshu-side
  lever today.

---

## AGNOS-readiness backlog (the `--agnos` build is not yet green)

The `v0.7.0` AGNOS cycle was opened for the **identity/stats** surface (mihi `uname` / `sysinfo`) — that half builds `--agnos`. The **TUI render loop is not agnos-ready**, though: it's built on the Linux **signalfd + epoll** model — SIGWINCH-driven dynamic resize + signal multiplexing via darshana's `TTY_SIGMASK_*` / `tty_open_signalfd` / `epoll` (all Linux-only; ~18 signal-path refs in `src/tui.cyr`, zero agnos gating). As of **0.7.9** the `--agnos` build clears the old agnosys blocker and now stops at `TTY_SIGMASK_EXIT`.

- [ ] **Agnos-native resize/signal handling for `shu`.** Either gate the signalfd/epoll path off under `CYRIUS_TARGET_AGNOS` (poll `winsize`#60 for size + `kbscan` for input each frame — no SIGWINCH, no signalfd) or wait on an agnos signal primitive. Its own arc; the lean `shu` runs on Linux today, AGNOS support is post-this.

---

## M3 — AI integration — substantive milestone, in progress

The substantive case for first-party. `chakshu` becomes the panel where the AGNOS LLM stack meets the live system view. Landing across 0.7.2–0.7.6 (incremental cuts rather than one big v0.8.0).

**Foundation — shipped v0.7.2** (`src/ai.cyr`):

- [x] Prompt assembly per design-spec §6.2 (with privacy redaction)
- [x] niyama-driven secret-pattern redaction in cmdline args (re2; `src/ai.cyr`)
- [x] `--explain <pid>` — non-interactive one-shot (redacted-context preview)

**Live transport — shipped v0.7.3:**

- [x] hoosh HTTP client via sandhi — `--explain` POSTs `/v1/chat/completions`, prints the answer, falls back to the redacted context on failure. (design-spec §6.3 corrected: HTTP, not the stale Unix-socket framing.)
- [x] `?` key — in-TUI explain **overlay** (`ai_tui_explain`); request→render for now
- [x] **lean/AI binary split** — default `shu` (monitor) vs `shu-ai` (+AI); AI deps confined to `ai/cyrius.cyml`. Sizes at the 0.7.3 cut were ~0.84 MB / ~2.57 MB; current figures live in [`state.md`](state.md).

**SSE streaming + hoosh 2.3.5 — shipped v0.7.4:**

- [x] Incremental streamed render in the `?` overlay via `sandhi_http_stream` (fnptr `_ai_stream_cb` extracts each OpenAI `delta.content`) + Esc/q cancel (non-blocking `poll(stdin)`). Falls back to the context preview if nothing streams.
- [x] hoosh **2.3.5** bearer-token auth — `Authorization: Bearer $CHAKSHU_HOOSH_TOKEN` when set (token-less gateway still open).
- [x] Smoke gate: `tests/hoosh_stub_smoke.py` stands up an OpenAI-shaped stub and runs `shu-ai --explain` against it (POST + content extraction + Bearer header). **Soft CI gate** — sandhi's `fdlopen`→libc `getaddrinfo` can't run in a no-libc/sandbox context, so it's pending its first green on a libc CI runner (then promote to hard).

**Logs + anomaly stream — v0.7.6 (closes M3):**

- [ ] `--watch` — anomaly stream (subscribe to aegis/phylax events)
- [ ] `--with-logs` opt-in for sakshi log context in prompts

**Gate to M4**: a user can ask "why is this process spiking" and get a coherent answer that quotes real /proc data.

> **Runtime-libc caveat (0.7.4):** sandhi's HTTP client dlopens libc (`getaddrinfo`/libssl), so **`shu-ai` is not a pure no-libc binary** and its live path only runs on a libc host (CI/AGNOS). The lean `shu` (no sandhi) stays pure no-libc per CLAUDE.md. If this becomes a problem, the fallback is a chakshu-local raw-HTTP-over-TCP client (no sandhi, no dlopen).

> **Size note:** the lean/AI split keeps the default `shu` at ~0.86 MB (still under btop's ~1.7 MB install); the AI heft (~3.02 MB) is confined to the opt-in `shu-ai`. M4 size work targets the lean monitor only (design-spec §8 `<256 KB`, ~3.3× over as of v0.7.12). Note that since cycc 6.5.16 the compiler emits every *declared* stdlib module and `CYRIUS_DCE=1` no longer shrinks the output, so that work means trimming declared modules, not more DCE.

---

## M4 — Polish + perf (v0.9.0)

- [x] **Performance audit against design-spec §8 targets — run 2026-08-24 (v0.7.14).**
  Measured under a real PTY at `--rate 1` over 20 s, 281 processes on a 16-core box.
- [x] Memory: `< 8 MB` resident at steady state — **MET: 4.49 MB (4,600 kB) and flat.**
  Was unbounded before v0.7.13 fixed the ~44 KB/frame `dir_list` leak (RSS climbed
  4,556 → 12,748 kB over 400 frames and breached this budget in ~90 s).
- [x] Cold start `< 5 ms` — **MET: ~1.6 ms** (`shu --version`, median of 5: 1,523–1,747 µs).
- [ ] CPU: `< 0.5%` at 1 Hz — **OVER: 0.650%.** Diagnosed, not mysterious: every TUI frame
  runs `processes_sample1()` → `sleep_ms(100)` → `processes_sample2()`, i.e. **two full
  `/proc` walks per frame**, each reading `/proc/<pid>/stat` for every process (~562 stat
  reads/sec here). The fix is to stop taking two fresh samples per frame and instead use
  the *previous frame's* sample as the baseline: it halves the `/proc` work, removes the
  100 ms per-frame sleep entirely, and widens the CPU% delta window from 100 ms to the
  full refresh interval — which is both cheaper and more accurate (htop samples over its
  whole interval for the same reason). **It does change what CPU% means**, so it wants a
  deliberate decision rather than a drive-by optimization; `shu -p` should keep its
  100 ms window, since a one-shot snapshot has no previous frame to difference against.
- [ ] Manual TTY checks documented in `tests/`
- [x] Binary size budget — **interim target `< 1 MB`: MET at v0.7.14.** Lean `shu` is **571,480 B (0.57 MB)**, comfortably under. (History: ~1.38 MB at 0.7.2 → 861,536 B at 0.7.13 → 571,480 B once ai-hwaccel 2.3.19 / mihi 1.2.5 took the 641 KB bayan monolith out of the lean closure.) The 0.7.2 note about niyama's re2 pulling unicode tables no longer applies to the lean build — niyama is AI-only and lives in `ai/cyrius.cyml`.
- [ ] Binary size — design-spec §8's `< 256 KB` long-term target: still **~2.2× over**. Not a chakshu-side lever any more: the safe remaining stdlib drops (`bench`, `freelist`, `tagged`, `slice`) total ~25 KB, and `CYRIUS_DCE=1` has been a parity check rather than an optimizer since cycc 6.5.16 (it NOPs dead code in place and emits a byte-identical binary). Closing the rest means revising §8 or further upstream work on what the mihi/ai-hwaccel bundles pull in. See [`p1-sweep-findings.md`](p1-sweep-findings.md).
- [ ] Deepen GPU telemetry — basic GPU panel shipped at M2.5; richer per-device stats means picking up more of the `ai-hwaccel` surface. **The old blocker is gone:** the pin is no longer held at 2.2.6 — v0.7.14 moved it to **2.3.19** in lockstep with mihi 1.2.5, so the coordinated bump this item was waiting on has already happened. What remains is choosing which per-device stats to surface and where in the layout.
- [ ] Theme support (dark / light, configurable)

**Gate to v1.0**: all design-spec performance targets met; documentation complete; one external test user (non-author) runs chakshu for a week without filing showstopper bugs.

---

## M5 — v1.0 ship (v1.0.0)

- [ ] Promote in agnosticos `shared-crates.md` from Pre-1.0 → v1.0+ Stable Index
- [ ] Add `docs/applications/libs/chakshu/` page in agnosticos (per first-party-standards)
- [ ] zugot recipe → AGNOS ISO default
- [ ] Bazaar `htop` and `btop` recipes remain available (don't break user choice)
- [ ] Announce: AGNOS now ships its own AI-augmented system monitor

---

## Post-v1 Ideas (deferred — do not sneak into earlier milestones)

- Per-cgroup view (without becoming a container monitor — that's a different scope)
- Historical replay (chakshu over a sakshi-backed time-series store)
- Mobile / dashboard frontends — same backend, different render layer
- Themed glyphs / non-ASCII art mode (btop-style)
- Plugin surface for custom panels
