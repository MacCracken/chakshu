# `chakshu` — Design Specification

**The eye — AI-augmented system monitor for AGNOS / Cyrius**

Version: 0.1
Status: Scaffold (2026-05-07)
Audience: Implementation agent / contributors
Name: Sanskrit **चक्षु** (*chakṣu*) — *the eye, the faculty of sight*. Same observational family as planned `drishti-*` video codecs (दृष्टि — *vision*).
Binary name: `shu` — **S**ystem **H**ealth **U**tility, a contraction of *chak**shu***. See [ADR 0001](adr/0001-binary-name-shu.md).

---

## 1. Purpose & Scope

`chakshu` is a terminal system monitor for AGNOS. It reads `/proc` and `/sys` directly and renders a live view of processes and resources, with optional AI-assisted explanations of what the user is looking at.

**In scope:**

- Process list with sort/filter (CPU, memory, name, user)
- CPU usage (per-core + aggregate)
- Memory usage (RAM, swap, cached, buffers)
- Disk I/O rates (per-device + aggregate)
- Network I/O rates (per-interface + aggregate)
- Kill selected process (with confirm)
- Plain-snapshot mode (`-p`) — single-frame text dump, pipeable
- AI explanation of selected row / system state (M3+) via `daimon` + `hoosh`
- Anomaly flagging (M3+) via `aegis` / `phylax` hooks

**Out of scope (for v1):**

- Process editing (renice, taskset) — kybernet's domain
- Service management (start/stop/restart units) — kybernet's domain
- Log viewing — sakshi's domain (chakshu may *quote* recent log lines into AI prompts; it does not render a log panel)
- Container-specific UI (Docker/podman) — different scope from full system; see §11 namespace note
- File system browsing — yazi (Bazaar) or future AI file manager
- Network packet inspection — phylax's domain

---

## 2. Design Principles

1. **Observation is read-only by default.** Everything the TUI shows comes from `/proc` and `/sys`. The only mutating action is the explicit kill key, gated by a confirm dialog.
2. **Plain mode is sacred.** `-p` produces a deterministic single-frame text dump suitable for piping into other tools. No animations, no terminfo escapes (unless `--color=always`).
3. **AI is opt-in and visible.** `--explain` and the `?` key are the only paths that invoke the LLM. The user always sees an indicator when an AI call is in flight; nothing happens silently.
4. **Privacy by construction.** When assembling an AI prompt, send only data the user can already see on screen. Never include `/home` contents, untrimmed command-line args, or environment variables.
5. **The Cyrius stdlib is the dependency envelope.** No ncurses, no libc, no procps, no FFI. `/proc` is plain text; termios is a syscall.

---

## 3. Data Sources

All data comes from the Linux `/proc` and `/sys` interfaces, read via `lib/fs` + `lib/syscalls`.

| Datum | Source | Refresh |
|-------|--------|---------|
| Process list | `/proc/[pid]/stat` + `/proc/[pid]/status` + `/proc/[pid]/cmdline` | 1 Hz default |
| CPU per-core | `/proc/stat` deltas | 1 Hz |
| Memory | `/proc/meminfo` | 1 Hz |
| Swap | `/proc/swaps` | 1 Hz |
| Disk I/O | `/proc/diskstats` deltas | 1 Hz |
| Network I/O | `/proc/net/dev` deltas | 1 Hz |
| Load avg | `/proc/loadavg` | 1 Hz |
| Uptime | `/proc/uptime` | 1 Hz |
| Hostname | `/proc/sys/kernel/hostname` | once at start |

Refresh rate configurable via `--rate <hz>` (range 0.2–10).

---

## 4. TUI Layout

```
┌─ chakshu ─ host: cyriusbox ─ up: 14d 03:21 ─ load: 0.42 0.38 0.35 ────────┐
│ CPU  [████░░░░░░░░░░░░░░░░] 23%   Mem  [██████░░░░░░] 5.2/16G            │
│ DISK rd  124K/s  wr  3.1M/s       NET  ↓ 2.4M/s  ↑ 412K/s                │
├──────────────────────────────────────────────────────────────────────────┤
│  PID  USER     CPU%  MEM%  CMD                                           │
│  1234 macro    18.4   3.1  firefox.bin                                   │
│   892 macro     6.0   1.8  Web Content                                   │
│   341 macro     2.1   0.4  cyrius build src/main.cyr                     │
│   ...                                                                    │
├──────────────────────────────────────────────────────────────────────────┤
│ [↑↓] move  [k] kill  [?] explain  [f] filter  [s] sort  [q] quit         │
└──────────────────────────────────────────────────────────────────────────┘
```

Header, panels, and status bar use box-drawing chars (U+2500..U+257F). Color via `lib/io` ANSI helpers. Single-buffer redraw; full-screen alt-buffer entered/exited via standard CSI sequences (`\e[?1049h` / `\e[?1049l`).

---

## 5. Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| TUI | default | Full-screen interactive monitor |
| Plain | `-p` / pipe-to-tty-detected | Single frame to stdout, no termios changes, no alt-buffer |
| Single-process | `--pid N` | TUI focused on one process (full process tree, fds, threads) |
| Explain | `--explain N` | AI explanation of process N — prompt assembly, hoosh call, response printed, exit |
| Watch | `--watch` (M3+) | Tail-mode: show events flagged by aegis/phylax as they occur |

---

## 6. AI Integration (M3+)

**Not in scope until parity (M2) is closed.** Documented here so design decisions in M0–M2 don't paint M3 into a corner.

### 6.1 Trigger surface

- `?` key — explain the selected process row
- `--explain <pid>` — non-interactive one-shot
- `--watch` — anomaly stream

No other code path makes AI calls.

### 6.2 Prompt assembly

For "explain process N", the prompt includes:

- Basic process metadata: name, pid, ppid, uid (resolved to username), state, start time, cpu%, mem%
- The first 256 bytes of `/proc/[pid]/cmdline` with a redaction pass (drop anything matching common secret patterns: `--password=`, `--token=`, `*KEY*`, etc. — niyama-driven once M3 lands)
- The last N lines from sakshi for that pid (if sakshi is running and the user has opted in via `--with-logs`)
- The current system snapshot: load avg, mem pressure, top 5 processes by cpu/mem

Excluded: env vars, /home paths, file contents, network packets.

### 6.3 Transport

- `daimon` over `sandhi` JSON-RPC (Unix socket — `XDG_RUNTIME_DIR/daimon.sock`)
- Streamed response rendered into a modal overlay
- Cancellable via `Esc`

### 6.4 Anomaly stream (M3+)

`aegis` and `phylax` already publish events. `chakshu --watch` subscribes to that bus (sandhi pub/sub via `majra`?  TBD at M3 design) and renders flagged events in a dedicated panel.

---

## 7. CLI Surface

```
shu [OPTIONS]
shu --pid <PID>
shu --explain <PID>
shu --watch
shu -p
shu -h | --help | -V | --version

OPTIONS:
  -p                 Plain snapshot mode (single frame, no TUI)
  --rate <HZ>        Refresh rate (0.2–10, default 1)
  --color <when>     auto | always | never (default auto)
  --pid <PID>        Focus a single process
  --explain <PID>    Print AI explanation and exit (M3+)
  --watch            Anomaly stream mode (M3+)
  --with-logs        Allow AI prompts to include sakshi log context (M3+)
  -h, --help         Show help
  -V, --version      Show version
```

---

## 8. Performance Targets

| Target | Goal | Measured at |
|--------|------|-------------|
| Cold start (`shu --version`) | < 5 ms | M0 |
| First TUI frame | < 50 ms | M1 |
| Steady-state CPU at 1 Hz | < 0.5% on a 4-core machine | M2 |
| Memory resident | < 8 MB | M2 |
| `-p` snapshot | < 30 ms | M1 |

---

## 9. Error Handling

Errors go to stderr as `chakshu: <reason>`. The TUI always restores termios state on exit, including SIGTERM / SIGINT / panic paths. A double-fault path resets termios via direct syscall before re-raising.

---

## 10. Testing

- `tests/chakshu.tcyr` — unit tests for parsers (one fixture per `/proc` source)
- Smoke gates (M1+): `shu --version`, `shu --help`, `shu -p` produces non-empty output, exits 0 on a process that exists, exits non-zero on `--pid 0`
- Manual TUI walkthrough at every milestone close — type checks can't catch ANSI regressions

---

## 11. Naming notes

The binary is **`shu`** — **S**ystem **H**ealth **U**tility, a contraction of *chak**shu***.

`ctop` was considered during scaffolding (would have slotted into the `top` / `htop` / `btop` lineage) and rejected to avoid namespace overlap with [`bcicen/ctop`](https://github.com/bcicen/ctop), a popular Go-based Docker container monitor. The full reasoning is in [ADR 0001](adr/0001-binary-name-shu.md). On AGNOS the tool is therefore unambiguous: `chakshu` is the registry/repo/package name; `shu` is the command. Bazaar users who install `bcicen/ctop` retain their muscle memory.

---

## 12. Future Work (post-v1, deferred)

- GPU monitoring (NVIDIA/AMD/Intel) once `ai-hwaccel` exposes a stable surface
- Per-cgroup view (containers/services without becoming `bcicen/ctop`)
- Historical replay (chakshu reading from a sakshi-backed time-series store)
- Mobile/dashboard frontends — pure backend protocol over sandhi

These do not gate v1.0.
