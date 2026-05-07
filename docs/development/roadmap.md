# chakshu — Roadmap

> **Status**: M0 (scaffold) | **Last Updated**: 2026-05-07
>
> The path from v0.1.0 (scaffold) to v1.0 (ships as the AGNOS default system monitor, replacing the third-party `htop`/`btop` Bazaar packages).

---

## Milestones

### M0 — Scaffold (v0.1.0) — **current**

Repo exists, compiles, runs, exits cleanly. Nothing useful happens yet.

- [x] Repo structure (`src/`, `docs/`, `tests/`)
- [x] `cyrius.cyml` manifest, toolchain pinned
- [x] `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CLAUDE.md`
- [x] `docs/design-spec.md`
- [x] ADR 0001 (binary name)
- [x] `src/main.cyr` skeleton with `--help` / `--version`
- [x] `tests/chakshu.tcyr` smoke test
- [ ] Listed in `agnosticos` shared-crates registry

**Gate to M1**: `cyrius build src/main.cyr build/shu` succeeds; `./build/shu --version` prints version; `cyrius test` passes.

---

### M1 — Plain snapshot (`-p`) (v0.2.0)

Single-frame text dump of the system state to stdout. No TUI, no termios, no alt-buffer. The smallest useful version of chakshu.

- [ ] `/proc/stat` parser → CPU usage (per-core + aggregate, computed across two samples ~100ms apart)
- [ ] `/proc/meminfo` parser → memory + swap
- [ ] `/proc/loadavg`, `/proc/uptime`, `/proc/sys/kernel/hostname`
- [ ] `/proc/[pid]/{stat,status,cmdline}` walker → process list
- [ ] `/proc/diskstats` parser → disk rates (delta over sample window)
- [ ] `/proc/net/dev` parser → network rates
- [ ] Plain renderer: header line + resource summary + top-N process table
- [ ] Sort flag (`--sort cpu|mem|pid|name`, default cpu)
- [ ] Limit flag (`--top N`, default 10)
- [ ] Smoke gate: `shu -p` produces non-empty output, exits 0

**Gate to M2**: a user can `watch -n 1 shu -p` and use it as a poor-man's monitor; performance target `< 30ms` per frame on the dev box.

---

### M2 — Full TUI (v0.5.0)

Interactive full-screen monitor. Parity with `htop`. The point at which chakshu can replace `htop`/`btop` for AGNOS users who don't need AI features.

- [ ] Termios raw mode + cleanup on every exit path (incl. SIGINT/SIGTERM)
- [ ] Alt-buffer entry/exit (`\e[?1049h` / `\e[?1049l`)
- [ ] Render loop: 1 Hz default, configurable via `--rate`
- [ ] Layout: header / resource bars / process table / status bar
- [ ] Keybinds: `q`, `↑`/`↓`, `k` (kill with confirm), `f` (filter), `s` (sort), `?` (placeholder for M3)
- [ ] Filter: substring match against cmd or user
- [ ] Single-process focus mode (`--pid N`)
- [ ] Color: 16-color default, `--color=auto|always|never`
- [ ] Resize handling (SIGWINCH)
- [ ] Smoke gate: TUI starts, refreshes, exits cleanly

**Gate to M3**: chakshu is a usable `htop` replacement. Bazaar default switches from `htop` to `chakshu` (Bazaar recipe still ships `htop` for users who prefer it).

---

### M3 — AI integration (v0.7.0)

The substantive case for first-party. `chakshu` becomes the panel where the AGNOS LLM stack meets the live system view.

- [ ] daimon JSON-RPC client (sandhi)
- [ ] hoosh streaming response renderer (modal overlay in the TUI)
- [ ] Prompt assembly per design-spec §6.2 (with privacy redaction)
- [ ] `?` key — "explain selected process"
- [ ] `--explain <pid>` — non-interactive one-shot
- [ ] `--watch` — anomaly stream (subscribe to aegis/phylax events)
- [ ] `--with-logs` opt-in for sakshi log context in prompts
- [ ] niyama-driven secret-pattern redaction in cmdline args
- [ ] Smoke gate: `--explain <self-pid>` returns something model-shaped

**Gate to M4**: a user can ask "why is this process spiking" and get a coherent answer that quotes real /proc data.

---

### M4 — Polish + perf (v0.9.0)

- [ ] Performance audit against design-spec §8 targets
- [ ] Memory: `< 8 MB` resident at steady state
- [ ] CPU: `< 0.5%` at 1 Hz on a 4-core box
- [ ] Cold start `< 5ms`
- [ ] Manual TTY checks documented in `tests/`
- [ ] DCE binary size budget (target: < 256 KB)
- [ ] Theme support (dark / light, configurable)

**Gate to v1.0**: all design-spec performance targets met; documentation complete; one external test user (non-author) runs chakshu for a week without filing showstopper bugs.

---

### M5 — v1.0 ship (v1.0.0)

- [ ] Promote in agnosticos `shared-crates.md` from Pre-1.0 → v1.0+ Stable Index
- [ ] Add `docs/applications/libs/chakshu/` page in agnosticos (per first-party-standards)
- [ ] zugot recipe → AGNOS ISO default
- [ ] Bazaar `htop` and `btop` recipes remain available (don't break user choice)
- [ ] Announce: AGNOS now ships its own AI-augmented system monitor

---

## Post-v1 Ideas (deferred — do not sneak into earlier milestones)

- GPU monitoring via `ai-hwaccel`
- Per-cgroup view (without becoming a container monitor — that's a different scope)
- Historical replay (chakshu over a sakshi-backed time-series store)
- Mobile / dashboard frontends — same backend, different render layer
- Themed glyphs / non-ASCII art mode (btop-style)
- Plugin surface for custom panels
