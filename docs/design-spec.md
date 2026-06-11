# `chakshu` — Design Specification

**The eye — AI-augmented system monitor for AGNOS / Cyrius**

Version: 0.1
Status: M2.5 complete (2026-05-20) — mihi-backed identity layer landed; M3 (AI) next
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
- AI explanation of selected row / system state via the `hoosh` LLM gateway (HTTP) — shipped in the `shu-ai` build (v0.7.3+)
- Anomaly flagging via `aegis` / `phylax` hooks — pending v0.7.5

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

Data lives in two layers:

- **Identity / static facts** are surfaced through the [mihi](https://github.com/MacCracken/mihi) probe library. mihi consolidates `uname(2)`, `/proc/cpuinfo`, `/proc/meminfo`, `/etc/os-release`, and ai-hwaccel's accelerator registry behind a stable Cyrius API. Read via `lib/mihi.cyr` after `cyrius deps` resolves the dep.
- **Per-frame deltas** (CPU%, disk rate, network rate, per-pid stats) come from `/proc` directly via `lib/fs` + `lib/syscalls`. mihi explicitly does not own delta-sourced data — that's chakshu's job.

| Datum | Source | Refresh |
|-------|--------|---------|
| Hostname | `mihi_hostname` (uname) | once at start |
| Kernel name + version | `mihi_kernel_name` / `mihi_kernel_version` (uname) | once at start |
| Distro | `mihi_distro` (`/etc/os-release`) | once at start |
| CPU model + core count | `mihi_cpu_model` / `mihi_cpu_count` (`/proc/cpuinfo`, `/sys/devices/system/cpu/online`) | once at start |
| GPU / accelerators (count, name, memory, family, type) | `mihi_gpu_*` (ai-hwaccel, no-exec sysfs/PCI/registry) | once at start |
| Memory total / available | `mihi_mem_total` / `mihi_mem_free` (`/proc/meminfo` — actually returns `MemAvailable`) | 1 Hz |
| Uptime | `mihi_uptime_secs` (`/proc/uptime`) | 1 Hz |
| Process list | `/proc/[pid]/stat` + `/proc/[pid]/status` + `/proc/[pid]/cmdline` | 1 Hz default |
| CPU usage (aggregate) | `/proc/stat` deltas | 1 Hz |
| Swap | `/proc/swaps` | 1 Hz |
| Disk I/O | `/proc/diskstats` deltas | 1 Hz |
| Network I/O | `/proc/net/dev` deltas | 1 Hz |
| Load avg | `/proc/loadavg` | 1 Hz |

Refresh rate configurable via `--rate <hz>` (range 0.2–10).

---

## 4. TUI Layout

```
host: cyriusbox  up: 14d 03:21  load: 0.42 0.38 0.35
mem:  5300 MiB used / 16384 MiB total
gpu:  AMD Radeon RX 6800 (16384 MiB)               (omitted if no GPU detected)
cpu:  23%   disk: rd 124 KiB/s wr 3 MiB/s   net: rx 2 MiB/s tx 412 KiB/s
   PID S  CPU%  MEM% CMD
  1234 S   18.4   3.1 firefox.bin
   892 S    6.0   1.8 Web Content
   341 R    2.1   0.4 cyrius build src/main.cyr
   ...
 [↑↓] move  [s] sort  [f] filter  [k] kill  [q] quit
```

Layout is text-anchored rather than box-drawn — bars and graphs are M4-polish work (see roadmap). Color via ANSI helpers (16-color theme by default, `--color` flag controls; see CHANGELOG `[0.3.0]`). Single-buffer redraw; full-screen alt-buffer entered/exited via standard CSI sequences (`\e[?1049h` / `\e[?1049l`).

`-p` (plain-snapshot) mode also surfaces `kern:` and `proc:` identity lines between `host:` and `mem:`; the TUI omits those to keep the process table tall. Identity panel placement in the TUI is a polish item for M4.


---

## 5. Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| TUI | default | Full-screen interactive monitor |
| Plain | `-p` / pipe-to-tty-detected | Single frame to stdout, no termios changes, no alt-buffer |
| Single-process | `--pid N` | TUI focused on one process (full process tree, fds, threads) |
| Explain | `--explain N` | AI explanation of process N — redacted prompt → hoosh, answer printed, exit (`shu-ai`; v0.7.3) |
| Watch | `--watch` | Tail-mode: show events flagged by aegis/phylax as they occur (`shu-ai`; pending v0.7.5) |

---

## 6. AI Integration (M3)

**Implemented in the `shu-ai` build (v0.7.2–v0.7.4).** §6.1–§6.3 below describe the shipped behaviour; §6.4 (`--watch`) is still pending (v0.7.5). The lean `shu` build has no AI surface — `--explain`/`?` there point users at `shu-ai`.

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

> **Corrected v0.7.3 (was: "daimon over sandhi JSON-RPC, Unix socket — `daimon.sock`").** The real AGNOS LLM path is `hoosh`'s **OpenAI-compatible HTTP API** (`hoosh` is an HTTP server per its ADR-001), not a Unix-socket JSON-RPC to `daimon`.

- **HTTP `POST /v1/chat/completions`** to the `hoosh` gateway via `sandhi`'s HTTP client. Default `http://127.0.0.1:8088`; override with `$CHAKSHU_HOOSH_URL`. Model via `$CHAKSHU_MODEL`. Bearer auth via `$CHAKSHU_HOOSH_TOKEN` (hoosh 2.3.5+).
- OpenAI request `{model, messages:[{role:"user", content:<prompt>}]}`; answer extracted from the response `content`.
- The `?` overlay sets `"stream":true` and renders the **SSE** deltas incrementally into a modal overlay; **Esc/q cancels** (non-blocking poll). `--explain` is request→render (one-shot). On any failure it falls back to printing the redacted context.
- Caveat: `sandhi` dlopens libc (`getaddrinfo`/libssl), so this path runs only on a libc host — see [`state.md`](development/state.md) "runtime-libc caveat".

> If `hoosh` later exposes a Unix socket for internal use, a socket transport can be added behind the same `$CHAKSHU_HOOSH_URL` selection. For now it's HTTP.

### 6.4 Anomaly stream + log context (pending — v0.7.5, closes M3)

- `--watch`: `aegis` and `phylax` already publish events. `chakshu --watch` subscribes to that bus (transport TBD — sandhi pub/sub or polling the relevant hoosh/phylax HTTP endpoint) and renders flagged events in a dedicated panel.
- `--with-logs`: opt-in to fold the last N `sakshi` log lines for the focused pid into the `--explain`/`?` prompt (§6.2). Off by default; privacy rules in §6.2 still apply.

Both land in the `shu-ai` build.

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
  --explain <PID>    Ask hoosh to explain PID and exit (shu-ai build; v0.7.3)
  --watch            Anomaly stream mode (shu-ai build; pending v0.7.5)
  --with-logs        Allow AI prompts to include sakshi log context (shu-ai; pending v0.7.5)
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
