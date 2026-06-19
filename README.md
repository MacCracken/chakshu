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

**v0.7.6 — M3 (AI integration) nearly complete.** What works today:

- **M1 — plain snapshot** (`shu -p`): host / uptime / load / mem / cpu / disk / net + sortable top-N process table.
- **M2 — full TUI** (`shu`): alt-screen, 1 Hz refresh, ↑↓ select, `s` sort, `f` filter, `k` kill-with-confirm, `--pid N` focus, 16-colour theme.
- **M3 — AI integration** (in the `shu-ai` build): `--explain <pid>` and the `?` key send a **privacy-redacted** process context to the AGNOS LLM gateway (`hoosh`) and stream the answer back.

**Two binaries** (see [the split](#install)): the default **`shu`** is the lean monitor (~0.84 MB, zero deps, no libc); **`shu-ai`** adds the AI panel (~2.6 MB; pulls `sandhi`/`niyama`).

Remaining before v1.0: M3 close (`--watch`, `--with-logs` — v0.7.7), then M4 polish/perf and M5 ship. See [docs/development/roadmap.md](docs/development/roadmap.md).

> The AI live path needs a running `hoosh` gateway and has only been exercised in CI / on a real box — not yet field-verified. `htop` / `btop` remain the AGNOS Bazaar defaults until chakshu ships at v1.0:
> ```sh
> ark bazaar install htop
> ark bazaar install btop
> ```

---

## Install

```sh
# AGNOS / Cyrius native package manager (post-v1.0)
pkg install chakshu

# From source — Cyrius toolchain 6.2.24+ on $PATH
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

Why two binaries? The Cyrius toolchain links every declared stdlib module into the binary (dead code is NOP'd, not dropped), so the AI dep chain (`sandhi`'s TLS/HTTP stack + `niyama`'s regex/unicode tables) would bloat every build to ~2.6 MB. Confining those deps to `ai/cyrius.cyml` keeps the default `shu` at ~0.84 MB — smaller than btop's install and fully self-contained (no libc / ncurses). `shu-ai` is the opt-in heavy build; note that `sandhi` dlopens libc for DNS/TLS, so **`shu-ai` (unlike `shu`) is not a pure no-libc binary** and its live path only runs on a host with libc.

---

## Quick start

```sh
shu                  # full TUI: processes + cpu + mem + disk + net
shu -p               # plain snapshot, one frame to stdout (pipeable)
shu --pid 1234       # focus a single process

# AI (the shu-ai build only):
shu-ai --explain 1234   # ask hoosh "why is process 1234 doing what it's doing?"
shu-ai --watch          # tail-mode: anomalies flagged via aegis/phylax (v0.7.7)
```

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
| `q` / `Esc` | Quit |
| `↑` `↓` | Move selection |
| `k` | Kill selected process (with confirm) |
| `f` | Filter |
| `s` | Sort |
| `?` | AI explanation of the selected row, streamed in an overlay (`shu-ai`; Esc/q cancels) |

---

## Naming

- **Project**: `chakshu` (Sanskrit चक्षु — *the eye*) — the registry name, the GitHub repo, the package.
- **Binary**: `shu` — the command you type. A direct contraction of *chak**shu*** with the English backronym **S**ystem **H**ealth **U**tility.

`ctop` was considered and rejected during scaffolding to avoid the namespace conflict with the popular Go-based [`bcicen/ctop`](https://github.com/bcicen/ctop) Docker monitor. See [`docs/adr/0001-binary-name-shu.md`](docs/adr/0001-binary-name-shu.md) for the full reasoning.

---

## License

GPL-3.0-only. See [LICENSE](LICENSE).
