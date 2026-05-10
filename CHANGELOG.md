# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

_No unreleased changes._

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
