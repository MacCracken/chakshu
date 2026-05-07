# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
