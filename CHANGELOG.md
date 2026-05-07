# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **M1 Slice A — `-p` plain snapshot (single-read fields).** `shu -p` now
  prints a two-line snapshot to stdout: `host: <name>  up: Nd HH:MM  load:
  L1 L5 L15` and `mem: <used> MiB used / <total> MiB total`. Reads
  `/proc/sys/kernel/hostname`, `/proc/uptime`, `/proc/loadavg`,
  `/proc/meminfo`. No terminal escapes — pipeable per design-spec §2.2.
- **M1 Slice C — `-p` process table.** Appends a top-10 process table
  sorted by CPU% descending. Walks `/proc/<pid>/stat` twice (paired
  with the slice B 100ms window) and computes per-process CPU% in the
  htop convention (per-core × 100 max, so a thread pegging one core
  reads 100% regardless of how many cores are idle). Uses `chrono`'s
  sleep window already taken for slice B — no additional latency.
  Columns: `PID S CPU% MEM% CMD` where MEM% = rss_pages × page / total
  and CMD is the kernel TASK_COMM_LEN-capped name (cmdline rendering
  for long-form names lands in slice D).
- New `src/processes.cyr` — walker, sampling orchestration, insertion
  sort by cpu_pct, top-N renderer. Stores per-process records in a
  module-global 48 KB heap block (1024 × 48 bytes). Uses `map_u64` to
  lookup sample-1 ticks from sample-2 by pid.
- `proc.cyr` adds `proc_pid_stat_parse` (handles comm field with
  embedded spaces/parens via "find LAST `)`" trick), `proc_stat_ncores`
  (count cpuN lines), `proc_is_pid_name` (numeric-only validator),
  `proc_pid_path` ("/proc/<pid>/<suffix>" builder).
- **Bug fix:** `_proc_next_uint` previously stalled on `-1` (the stat
  line's `tpgid` field for processes without a controlling tty),
  silently returning 0 for every subsequent field. Now consumes a
  leading `-` so signed fields can be skipped past.

- **M1 Slice B — `-p` delta-source line.** Adds a third snapshot line
  `cpu: NN%   disk: rd <rate> wr <rate>   net: rx <rate> tx <rate>`
  computed from two samples 100ms apart (`chrono.sleep_ms`). Aggregates:
  `/proc/stat` first cpu line (idle = idle + iowait), `/proc/diskstats`
  summed sectors × 512 across non-loop/ram/zram/dm-/mdN devices,
  `/proc/net/dev` summed bytes across non-loopback interfaces. Auto-unit
  rate formatter (B/s → KiB/s → MiB/s → GiB/s).
- New `src/proc.cyr` — /proc read + parse layer (`proc_read`,
  `proc_meminfo_field`, `proc_uptime_secs`, `proc_loadavg_prefix_len`,
  `proc_trim_trailing_nl`, plus Slice B parsers
  `proc_stat_cpu_agg` / `proc_diskstats_agg` / `proc_netdev_agg` and
  shared `_proc_skip_ws` / `_proc_skip_line` / `_proc_next_uint` /
  `_proc_word_start` / `_proc_skip_word` helpers). Stack-buffer based,
  no module globals; out-pointers (`&local`) for multi-value returns.
- New `src/snapshot.cyr` — `-p` orchestration / renderer.
- Parser unit tests against captured /proc fixtures
  (35 assertions total — was 10 at scaffold close).

### Fixed

- `cyrius.cyml` declared two stdlib deps that don't exist in the toolchain:
  `time` (the lib is named `chrono`) and `termios` (no equivalent provided
  by cyrius today). `cyrius deps` now resolves cleanly.
- `src/main.cyr` was wired against an imaginary stdlib API
  (`args_count` / `args_get` / `str_eq` / 1-arg `print`). Rewrote against
  the real surface — `argc()` / `argv()` (with required `args_init()`),
  `streq` for c-string compare (matches `tests/chakshu.tcyr`), and
  `println` / `eprint` for output. Patterned on
  [`owl/src/main.cyr`](https://github.com/MacCracken/owl).

### Changed

- Errors (unknown flags, unimplemented placeholders) now go to **stderr**
  per design-spec §9; `--help` / `--version` continue to write stdout.
- Manifest comment now lists `termios` under "pulled in later cycles"
  alongside `net` / `sandhi` / `niyama` — to be vendored or contributed
  upstream when M2 (TUI raw mode) work begins.

## [0.1.0] — 2026-05-07

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
