# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

_No unreleased changes._

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
