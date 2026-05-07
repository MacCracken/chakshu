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

**v0.1.0 — scaffold.** Skeleton + design spec. Nothing useful runs yet. See [docs/development/roadmap.md](docs/development/roadmap.md) for the M0–M5 milestone arc to v1.0.

If you want a working system monitor *today* on AGNOS, install `htop` or `btop` from the Bazaar:

```sh
ark bazaar install htop
ark bazaar install btop
```

`chakshu` will replace those defaults once it reaches parity (M2) and surpasses them with AI integration (M3).

---

## Install

```sh
# AGNOS / Cyrius native package manager (post-v1.0)
pkg install chakshu

# From source — Cyrius toolchain 5.9.32+ on $PATH
git clone https://github.com/MacCracken/chakshu
cd chakshu
cyrius deps
cyrius build src/main.cyr build/shu
./build/shu
```

---

## Quick start

```sh
shu                  # full TUI: processes + cpu + mem + disk + net
shu -p               # plain snapshot, one frame to stdout (pipeable)
shu --pid 1234       # focus a single process
shu --explain 1234   # AI: "why is process 1234 doing what it's doing?" (M3+)
shu --watch          # tail-mode: anomalies flagged via aegis/phylax (M3+)
```

Inside the TUI:

| Key | Action |
|-----|--------|
| `q` / `Esc` | Quit |
| `↑` `↓` | Move selection |
| `k` | Kill selected process (with confirm) |
| `?` | AI explanation of the selected row (M3+) |
| `f` | Filter |
| `s` | Sort |

---

## Naming

- **Project**: `chakshu` (Sanskrit चक्षु — *the eye*) — the registry name, the GitHub repo, the package.
- **Binary**: `shu` — the command you type. A direct contraction of *chak**shu*** with the English backronym **S**ystem **H**ealth **U**tility.

`ctop` was considered and rejected during scaffolding to avoid the namespace conflict with the popular Go-based [`bcicen/ctop`](https://github.com/bcicen/ctop) Docker monitor. See [`docs/adr/0001-binary-name-shu.md`](docs/adr/0001-binary-name-shu.md) for the full reasoning.

---

## License

GPL-3.0-only. See [LICENSE](LICENSE).
