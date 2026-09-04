# chakshu

> **चक्षु** — *the eye.* An AI-augmented system monitor for AGNOS / Cyrius.

`chakshu` (binary: `shu` — **S**ystem **H**ealth **U**tility) shows you what your machine is actually doing — processes, CPU, memory, disks, network — and, when something looks wrong, asks the LLM in your OS to explain it. Think `htop` / `btop`, but the OS itself helps you read the numbers.

The Sanskrit name **चक्षु** *chakṣu* means *the eye* / *the faculty of sight*. It belongs to the same observational family as the planned `drishti-*` video codecs (दृष्टि — *vision*).

---

## Why chakshu?

`htop` and `btop` are excellent and ship in the AGNOS Bazaar today. The first-party version exists because in an AI-native OS, the system monitor is a natural place to put the *interpretive* layer:

- A spike in CPU usage is data. *"`firefox.bin` is spiking because the open YouTube tab just started a 4K stream"* is information. AGNOS already has the model gateway (`hoosh`), the agent runtime (`daimon`), the threat detector (`phylax`), and the audit chain (`libro`) — `chakshu` is the panel that surfaces them in the moment.
- The third-party tools assume a Linux system administrator who reads `/proc` for a living. AGNOS targets a wider audience — the AI shell users, the home-lab tinkerers, the people who want the OS to meet them halfway.
- `htop`/`btop` are excellent C/C++ projects. Reading `/proc` directly via Cyrius syscalls keeps the AGNOS dependency tree clean and fits the sovereign-stack pattern (no procps-ng, no ncurses).

---

## Status

**v0.9.9 — monitor feature-complete and audited; v1.0 is gated on the criteria in
[docs/development/roadmap.md](docs/development/roadmap.md), not on features.** What works today:

- **Plain snapshot** (`shu -p`) — host / uptime / load / mem / cpu / disk / net, GPU telemetry, and a
  sortable top-N process table. One frame to stdout, pipe-safe.
- **Full TUI** (`shu`) — alt-screen, configurable refresh, `↑↓` select, `s` sort, `f` filter,
  `k` kill-with-confirm, `--pid N` focus, severity-banded colour, `--theme dark|light|auto`.
- **GPU telemetry** (v0.9.1) — live busy% / VRAM / temperature from DRM sysfs, matched to devices by
  PCI id.
- **Swap, cached and buffers** (v0.9.4) — on both `-p` and the TUI. Cached matters: Linux page cache
  is reclaimable, so "used" alone overstates memory pressure badly.
- **Per-core CPU, per-device disk, per-interface network, and a USER column** (v0.9.5) — the
  aggregate hides what you are usually looking for: one pegged core on an idle 16-core box reads as
  6%. `--sort user` sorts by owner. `-p` prints the full breakdown; the TUI shows per-core when the
  terminal is wide enough.
- **Anomaly stream** (`shu --watch`, v0.8.0) — tails aegis's append-only NDJSON event log. **In the
  lean build**, so it works on a no-libc AGNOS box.
- **AI integration** (`shu-ai` only) — `--explain <pid>` and the `?` key send a *privacy-redacted*
  process context to the AGNOS LLM gateway (`hoosh`) and stream the answer back. `--with-logs`
  (v0.8.1) optionally folds log + anomaly context in.
- **AGNOS** (v0.9.3) — both `-p` and the **TUI** run on AGNOS, via a poll loop over `kbscan` #42 and
  `winsize` #60 in place of the Linux termios/SIGWINCH/epoll trio. See the caveats below.

**Two binaries.** The default **`shu`** is the lean monitor (**664 KB**, no AI deps, no libc, no
network); **`shu-ai`** adds the AI panel (**2.96 MB**; pulls `sandhi` / `niyama`).

### Running on AGNOS — read this first

chakshu builds and runs on AGNOS, but the platform constrains what a monitor can show:

- **The process table works as of v0.9.8**, via `proclist` #99, and **v0.9.9 added a real MEM%
  column** from the per-process rss agnos 1.56.59 started reporting. `--sort mem` and `--sort name`
  are genuine; `--sort cpu` falls back to pid.
- **CPU% reads `n/a` on purpose.** The kernel does track per-process ticks, but it charges them to a
  *halted* process too, so a sleeping program reads 100%. That is not CPU utilisation and chakshu
  will not print it under a column head that means `utime+stime` on Linux. Filed upstream.
- **Load, disk and network rates read `n/a`.** AGNOS has no `/proc/diskstats` or `/proc/net/dev`
  equivalent and its `sysinfo` carries no load average. Host, kernel, memory and GPU identity work.
  Volume *capacity* is available to the kernel (`statfs` #103) and is not yet surfaced here.
- ⚠ **Untracked values always read `n/a`, never `0`.** A measured zero and an unmeasurable value are
  different facts, and a monitor that prints `0` for the second is inventing data.
- **`shu-ai` builds for AGNOS as of v0.9.7.** The old "`sandhi` dlopens libc" blocker is gone — TLS
  runs on the Cyrius-native TLS 1.3 stack and DNS on sandhi's own UDP resolver, so the AI build is
  now pure-syscall too. `--explain` and the `?` overlay work; `--with-logs` fails closed there,
  because its path validator canonicalises through procfs, which AGNOS does not have. The lean
  `shu` is still the recommended AGNOS build — it is a quarter the size.
- **Requires AGNOS ≥ 1.56.46.** Earlier kernels gave a ring-3 process only 12 KB of usable stack out
  of a mapped 2 MB page, so `shu -p` was page-fault-killed (`run: exit 142`). Fixed upstream in that
  cycle.

`htop` / `btop` remain available in the AGNOS Bazaar and are not going away:

```sh
ark bazaar install htop
ark bazaar install btop
```

---

## Install

```sh
# AGNOS / Cyrius native package manager (post-v1.0)
pkg install chakshu

# From source — Cyrius toolchain 6.5.41+ on $PATH
git clone https://github.com/MacCracken/chakshu
cd chakshu

# Lean monitor — the default `shu` (no AI deps, no libc)
cyrius deps
cyrius build src/main.cyr build/shu
./build/shu

# AI build — `shu-ai` (adds --explain / ? via the hoosh gateway).
# Lives in ai/ as a sub-project sharing the monitor source via ../src/*,
# so it needs CYRIUS_ALLOW_PARENT_INCLUDES=1.
cd ai
cyrius deps
CYRIUS_ALLOW_PARENT_INCLUDES=1 cyrius build main.cyr build/shu-ai
./build/shu-ai
```

Why two binaries? The Cyrius toolchain links every declared stdlib module into the binary (dead code is NOP'd, not dropped — and since cycc 6.5.16 it emits every *declared* module rather than pruning to what `main` reaches, so `CYRIUS_DCE=1` no longer shrinks the output at all). The AI dep chain (`sandhi`'s TLS/HTTP stack + `niyama`'s regex/unicode tables) would bloat every build to ~3.0 MB. Confining those deps to `ai/cyrius.cyml` keeps the default `shu` at ~664 KB — still smaller than btop's install and fully self-contained (no libc / ncurses). `shu-ai` is the opt-in heavy build. **As of v0.9.7 both binaries are pure no-libc** — statically linked, zero `NEEDED`, no `dlopen` of any kind: TLS runs on the Cyrius-native TLS 1.3 stack and DNS on sandhi's own UDP resolver.

---

## Quick start

```sh
shu                       # full TUI: processes + cpu + mem + disk + net + gpu
shu -p                    # plain snapshot, one frame to stdout (pipeable)
shu --pid 1234            # focus a single process
shu --sort mem --top 25   # sort by memory, show 25 rows
shu --sort user           # group the table by owning user
shu --rate 0.5            # refresh every 2s (btop's default; 0.2-10, fractional OK)
shu --theme light         # re-tint for a light terminal background
shu --color never         # no colour (auto honours $NO_COLOR / $TERM / isatty)
shu --watch               # anomaly stream — tails aegis's NDJSON event log

# AI — the shu-ai build only:
shu-ai --explain 1234              # ask hoosh to explain what PID 1234 is doing
shu-ai --with-logs --explain 1234  # ...and fold in recent log + anomaly context
```

`--watch` is in the **lean** build deliberately, so an AGNOS box with no libc can still read the
anomaly stream. Only `--explain`, `--with-logs` and the `?` overlay need `shu-ai`.

The AI build talks to the `hoosh` gateway over HTTP. Configure via env:

| Variable | Default | Purpose |
|----------|---------|---------|
| `CHAKSHU_HOOSH_URL` | `http://127.0.0.1:8088/v1/chat/completions` | gateway endpoint |
| `CHAKSHU_MODEL` | `default` | model name passed to hoosh |
| `CHAKSHU_HOOSH_TOKEN` | *(unset)* | sent as `Authorization: Bearer …` when set (hoosh 2.3.5+ auth) |

Only the redacted, on-screen process facts are sent — no `/home` contents, no env vars, no un-redacted command-line args (secrets like `--password=`/`--token=`/`*KEY*` are stripped). The lean `shu` is monitor-only; `--explain` / `?` there point you at `shu-ai`.

Inside the TUI:

| Key | Action |
|-----|--------|
| `q` | Quit |
| `↑` `↓` | Move selection |
| `k` | Kill selected process (with confirm) |
| `f` | Filter — type to narrow, `Enter` applies, `Esc` clears |
| `s` | Cycle sort key |
| `?` | AI explanation of the selected row, streamed in an overlay (`shu-ai`; `Esc`/`q` cancels) |

`Esc` clears the filter and cancels the AI overlay — it does **not** quit. `q` quits.

---

## Naming

- **Project**: `chakshu` (Sanskrit चक्षु — *the eye*) — the registry name, the GitHub repo, the package.
- **Binary**: `shu` — the command you type. A direct contraction of *chak**shu*** with the English backronym **S**ystem **H**ealth **U**tility.

`ctop` was considered and rejected during scaffolding to avoid the namespace conflict with the popular Go-based [`bcicen/ctop`](https://github.com/bcicen/ctop) Docker monitor. See [`docs/adr/0001-binary-name-shu.md`](docs/adr/0001-binary-name-shu.md) for the full reasoning.

---

## License

GPL-3.0-only. See [LICENSE](LICENSE).
