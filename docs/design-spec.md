# `chakshu` — Design Specification

**The eye — AI-augmented system monitor for AGNOS / Cyrius**

Version: 0.2 (revised at v0.9.4)
Status: M3 closed v0.8.2, M4 closed v0.9.3. M5 (v1.0 ship) in progress — see
        [roadmap.md](development/roadmap.md) for the v1.0 criteria and the open
        AGNOS-premise decision. ⚠ This document is the CONTRACT a v1.0 publishes;
        §7 below was reconciled against `shu --help` line by line at v0.9.4.
Audience: Implementation agent / contributors
Name: Sanskrit **चक्षु** (*chakṣu*) — *the eye, the faculty of sight*. Same observational family as planned `drishti-*` video codecs (दृष्टि — *vision*).
Binary name: `shu` — **S**ystem **H**ealth **U**tility, a contraction of *chak**shu***. See [ADR 0001](adr/0001-binary-name-shu.md).

---

## 1. Purpose & Scope

`chakshu` is a terminal system monitor for AGNOS. It reads `/proc` and `/sys` directly and renders a live view of processes and resources, with optional AI-assisted explanations of what the user is looking at.

**In scope:**

- Process list with sort/filter (CPU, memory, name — **not user**, see below)
- CPU usage (**aggregate only** — per-core not implemented, see below)
- Memory usage (RAM — **swap / cached / buffers not implemented**, see below)
- Disk I/O rates (**aggregate only** — per-device not implemented, see below)
- Network I/O rates (**aggregate only** — per-interface not implemented, see below)

> ⛔ **SIX ITEMS ABOVE ARE UNIMPLEMENTED AND HAVE NEVER BEEN FORMALLY DESCOPED** — flagged at
> v0.9.4, annotated rather than silently deleted. Verified absent from `src/`: per-core CPU,
> swap (`/proc/swaps` appears nowhere, though §2 lists it as a 1 Hz source), cached/buffers,
> per-device disk I/O, per-interface network I/O, and sort/column by user (there is no USER
> column). The live table header is `PID S CPU% MEM% CMD` and the memory line is used/total only.
>
> **Per-core meters, a swap meter and a USER column are htop's default screen**, and this project's
> stated goal is to replace htop/btop. Shipping 1.0.0 against a §1 that lists them as in-scope
> publishes a false contract on day one. Each needs an explicit decision — **implement**, or move to
> §12 with a descope note. This is a v1.0 blocker recorded in
> [roadmap.md](development/roadmap.md).
- Kill selected process (with confirm)
- Plain-snapshot mode (`-p`) — single-frame text dump, pipeable
- AI explanation of selected row / system state via the `hoosh` LLM gateway (HTTP) — shipped in the `shu-ai` build (v0.7.3+)
- Anomaly flagging via aegis's event sink — shipped v0.8.0 (`--watch`)

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

Refresh rate configurable via `--rate <hz>` (**integer 1-10**; the "0.2–10" this line claimed until v0.9.4 is not what the binary accepts — see the `--rate` note in §7, where the open decision is recorded).

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
| Watch | `--watch [PATH]` | Tail-mode: show security events as they occur, from aegis's append-only NDJSON sink. **Lean `shu`** — see §6.4. |

---

## 6. AI Integration (M3)

**§6.1–§6.3 are implemented in the `shu-ai` build (v0.7.2–v0.7.4)**; the lean `shu` has no AI surface — `--explain`/`?` there point users at `shu-ai`. **§6.4's `--watch` shipped at v0.8.0 in the LEAN build**, because tailing a local event file needs no gateway; see §6.4 for why that placement changed.

### 6.1 Trigger surface

- `?` key — explain the selected process row
- `--explain <pid>` — non-interactive one-shot
- `--watch` — anomaly stream

No other code path makes AI calls.

### 6.2 Prompt assembly

For "explain process N", the prompt includes:

- Basic process metadata: name, pid, ppid, uid (resolved to username), state, start time, cpu%, mem%
- The first 256 bytes of `/proc/[pid]/cmdline` with a redaction pass (drop anything matching common secret patterns: `--password=`, `--token=`, `*KEY*`, etc. — niyama-driven once M3 lands)
- Recent log context, if the user opted in via `--with-logs` (v0.8.1). **Not per-pid**: sakshi tags no line with a pid (its text target emits `[ts] [LEVEL] msg` and has zero pid references), so this is system-level recent log context plus the newest anomaly events. Every line is redacted exactly as cmdline is.
- The current system snapshot: load avg, mem pressure, top 5 processes by cpu/mem

Excluded: env vars, /home paths, file contents, network packets.

### 6.3 Transport

> **Corrected v0.7.3 (was: "daimon over sandhi JSON-RPC, Unix socket — `daimon.sock`").** The real AGNOS LLM path is `hoosh`'s **OpenAI-compatible HTTP API** (`hoosh` is an HTTP server per its ADR-001), not a Unix-socket JSON-RPC to `daimon`.

- **HTTP `POST /v1/chat/completions`** to the `hoosh` gateway via `sandhi`'s HTTP client. Default `http://127.0.0.1:8088`; override with `$CHAKSHU_HOOSH_URL`. Model via `$CHAKSHU_MODEL`. Bearer auth via `$CHAKSHU_HOOSH_TOKEN` (hoosh 2.3.5+).
- OpenAI request `{model, messages:[{role:"user", content:<prompt>}]}`; answer extracted from the response `content`.
- The `?` overlay sets `"stream":true` and renders the **SSE** deltas incrementally into a modal overlay; **Esc/q cancels** (non-blocking poll). `--explain` is request→render (one-shot). On any failure it falls back to printing the redacted context.
- Caveat: `sandhi` dlopens libc (`getaddrinfo`/libssl), so this path runs only on a libc host — see [`state.md`](development/state.md) "runtime-libc caveat".

> If `hoosh` later exposes a Unix socket for internal use, a socket transport can be added behind the same `$CHAKSHU_HOOSH_URL` selection. For now it's HTTP.

### 6.4 Anomaly stream + log context

**Corrected at v0.8.0.** This section previously asserted that "`aegis` and `phylax`
already publish events" and left the transport as "TBD — sandhi pub/sub or polling the
relevant hoosh/phylax HTTP endpoint". All three claims were wrong, and the design was
rebuilt on what actually exists:

- **aegis did not publish.** Through 1.1.6 its daemon was a stub (`println("aegis ready")`,
  return 0) and the codebase contained **zero** `sys_write` / `sys_socket` / `sys_bind`
  calls — every `sys_open` was `O_RDONLY`. It could *serialize* an event
  (`security_event_to_json`) but never wrote the bytes anywhere.
- **phylax does not publish.** Its Unix socket is a scan RPC: send a path, get
  `{"findings":N,"status":"ok"}`, connection closed. A second connection receives no
  unsolicited bytes.
- **"sandhi pub/sub" does not exist.** sandhi exports no subscribe/topic/listen surface.

**Transport (settled):** an append-only **NDJSON** file — one complete JSON object per
line, written by the producer in a single `write(2)` under `O_APPEND`. That framing is the
contract: because the record and its newline land atomically, a consumer that stops at the
last complete `\n` can never observe a torn record, so no lock, watermark, or producer
cooperation is required. aegis **1.1.7** implements the producer side
(`aegis_set_event_sink`, `AEGIS_EVENT_LOG`).

**`--watch` lands in the LEAN `shu`, not `shu-ai`** — the second correction. Tailing a
local file needs no libc, no network and no new dependency; the syscalls are already in
the lean manifest. This means `--watch` works on a pure no-libc AGNOS host where `shu-ai`
cannot run at all (sandhi dlopens libc), and it *strengthens* the "AI is opt-in at the
binary level" rule rather than weakening it: reading a file another process wrote is not a
network reach. Only AI **triage** of a flagged event needs the gateway, and that stays in
`shu-ai`.

Path resolution: `--watch <path>` argument, then `$CHAKSHU_WATCH_PATH`, then
`/var/log/aegis/events.jsonl`. Non-TTY renders a deterministic escape-free dump (the `-p`
posture of §2.2); a TTY gets the live panel.

- `--with-logs` (shipped v0.8.1, `shu-ai` only): opt-in to fold recent log lines and
  recent anomaly events into the `--explain`/`?` prompt (§6.2). Off by default; every
  line passes the same redactor as cmdline. **Corrected from the original wording**
  ("last N sakshi lines *for that pid*"): sakshi carries no pid on a log line, so
  per-pid attribution is impossible — this is system-level log context, plus the
  per-event anomaly ring that `--watch` already maintains.


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
  -p                      Plain snapshot mode (single frame, no TUI)
  --sort cpu|mem|pid|name Process-table sort key (default cpu)
  --top N                 Process-table row count (default 10)
  --rate <HZ>             TUI refresh rate — INTEGER 1-10, default 1
  --color <when>          auto | always | never (default auto; TUI only)
                          auto honours $NO_COLOR, $TERM and isatty(stdout)
  --theme <name>          dark | light | auto (default dark; TUI only)
                          auto reads $COLORFGBG
  --pid <PID>             Focus a single process (validates PID at startup)
  --explain <PID>         Ask hoosh to explain PID and exit (shu-ai build)
  --watch [PATH]          Anomaly stream mode. Reads aegis's NDJSON event log;
                          path, else $CHAKSHU_WATCH_PATH, else
                          /var/log/aegis/events.jsonl. Non-TTY prints a plain dump.
                          LEAN build — works on a no-libc AGNOS box.
  --with-logs             Fold recent log + anomaly context into AI prompts
                          (shu-ai only; off by default). Shipped v0.8.1.
  -h, --help              Show help
  -V, --version           Show version

Exit codes: 0 success · 1 runtime failure · 2 usage error.

⚠ `--rate` READ THIS: this block said "0.2–10" until v0.9.4 while the code has always rejected
anything below 1 (`--rate 0` exits 2). The spec has been corrected to match the binary rather than
the reverse, because publishing a range the binary refuses is the worse failure. But the DECISION is
open and must be settled before the v1.0 freeze: **integer Hz 1-10 yields only 100-1000 ms, and
neither incumbent's default is expressible — htop defaults to 1.5 s, btop to 2000 ms.** A monitor
whose goal is replacing them should be settable to their default refresh. Options: implement
fractional Hz as originally specified, or switch to a millisecond interval in btop's shape
(`--update <ms>`). Either is breaking after the freeze.
```

---

## 8. Performance Targets

Measured at v0.9.0 under a real pseudo-terminal at `--rate 1`, 295 processes on a
16-core box, unless noted.

| Target | Goal | Status |
|--------|------|--------|
| Cold start (`shu --version`) | < 5 ms | **met** — ~2.0 ms |
| First TUI frame | < 50 ms | ⚠ **depends on the definition — unsettled.** First bytes on the wire measure 1.0 ms; the first COMPLETE frame (cpu/disk/net rates + PID header) measures ~109 ms median, gated by the deliberate 100 ms sample window. The `-p` row is qualified as "< 30 ms of *work*" and is met; this row carries no such qualifier and is 2.2x over on the complete-frame reading. Pick a definition and restate before the freeze. |
| Steady-state CPU at 1 Hz | < 0.5% of one core | **met, at the margin** — 0.433–0.500% over five 60 s windows, mean 0.473% |
| Memory resident | < 8 MB | **met** — 4.56 MB, flat |
| `-p` snapshot | < 30 ms of work | met — ~12 ms (plus a deliberate 100 ms sample window) |
| Lean `shu` binary | **< 768 KB** | met — 622 KB |

### On the binary-size target (revised at v0.9.0)

This originally read **`< 256 KB`**. That figure was set at M0, before chakshu took
its dependencies, and it is not reachable while the lean monitor links `mihi` (for
identity probes) and `ai-hwaccel` (for the GPU panel):

- The binary peaked at 861 KB and is now 622 KB. The single biggest win —
  −290 KB — came from getting bayan's 641 KB monolith out of the closure by fixing
  two upstream repos (see `docs/development/p1-sweep-findings.md`).
- **No chakshu-side lever remains.** The remaining safe stdlib drops (`bench`,
  `freelist`, `tagged`, `slice`) total ~25 KB combined.
- **DCE is not a lever either.** Since cycc 6.5.16 the compiler emits every
  *declared* stdlib module and `CYRIUS_DCE=1` NOPs dead code in place — it produces
  a byte-identical binary. It is a parity check, not an optimizer.

The rest is bulk inside the mihi/ai-hwaccel dist bundles, which is upstream work,
not chakshu's. Rather than carry a permanently-red target, §8 now states a number
the architecture can actually hold: **< 768 KB**, which keeps the headroom the
target existed to protect. The user-facing comparison is unchanged — btop installs
at ~1.7 MB, htop more once its ncurses and libc are counted, and `shu` is
self-contained with neither.

`shu-ai` is explicitly out of scope for this budget: it is the opt-in heavy build
(~3.2 MB) and carries the TLS/HTTP chain by design.


---

## 9. Error Handling

Errors go to stderr as `chakshu: <reason>`. The TUI always restores termios state on exit, including SIGTERM / SIGINT / panic paths. ⚠ **STRUCK v0.9.4:** this sentence used to promise that "a double-fault path resets termios via direct syscall before re-raising". No such code exists (zero grep hits in `src/tui.cyr`); teardown is the ordinary `_tui_teardown()` path off the signalfd loop exit. A v1.0 spec must not promise a recovery path the binary lacks. Note the one genuinely unrecoverable case is documented in `tests/MANUAL.md` §3: `kill -9` cannot be handled, leaves the terminal raw, and `reset` recovers it.

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

- ~~GPU monitoring (NVIDIA/AMD/Intel)~~ — **SHIPPED v0.9.1**, not deferred: live busy% / VRAM / temperature from DRM sysfs, matched to devices by PCI id (`src/gpu.cyr`), with a smoke gate. Left here struck rather than deleted so the deferral decision stays legible.
- Per-cgroup view (containers/services without becoming `bcicen/ctop`)
- Historical replay (chakshu reading from a sakshi-backed time-series store)
- Mobile/dashboard frontends — pure backend protocol over sandhi

These do not gate v1.0.
