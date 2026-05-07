# chakshu — Roadmap

> **Status**: M0 (scaffold) | **Last Updated**: 2026-05-07
>
> The path from v0.1.0 (scaffold) to v1.0 (ships as the AGNOS default system monitor, replacing the third-party `htop`/`btop` Bazaar packages).

---

## Milestones

### M0 — Scaffold (v0.1.0) — **gate cleared**

Repo exists, compiles, runs, exits cleanly. Nothing useful happens yet.

- [x] Repo structure (`src/`, `docs/`, `tests/`)
- [x] `cyrius.cyml` manifest, toolchain pinned (post-fix: `time` → `chrono`, `termios` deferred to M2)
- [x] `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CLAUDE.md`
- [x] `docs/design-spec.md`
- [x] ADR 0001 (binary name)
- [x] `src/main.cyr` skeleton with `--help` / `--version` (rewritten against real stdlib API — `argc`/`argv`/`streq`/`println`/`eprint`)
- [x] `tests/chakshu.tcyr` smoke test (10 assertions passing)
- [ ] Listed in `agnosticos` shared-crates registry — open; lives in a different repo

**Gate to M1** *(cleared 2026-05-07)*: `cyrius build src/main.cyr build/shu` succeeds; `./build/shu --version` prints version; `cyrius test` passes.

---

### M1 — Plain snapshot (`-p`) (v0.2.0) — **closed**

Single-frame text dump of the system state to stdout. No TUI, no termios, no alt-buffer. The smallest useful version of chakshu.

- [x] `/proc/stat` parser → CPU usage (aggregate; per-core + ncores counter; per-core display lives in M2 TUI)
- [x] `/proc/meminfo` parser → memory (swap reported when SwapTotal lands in M2 — not on the M1 critical path)
- [x] `/proc/loadavg`, `/proc/uptime`, `/proc/sys/kernel/hostname`
- [x] `/proc/[pid]/{stat,cmdline}` walker → process list (status / Uid resolution lives in M2 alongside /etc/passwd → username)
- [x] `/proc/diskstats` parser → disk rates (delta over sample window)
- [x] `/proc/net/dev` parser → network rates
- [x] Plain renderer: header line + resource summary + top-N process table
- [x] Sort flag (`--sort cpu|mem|pid|name`, default cpu)
- [x] Limit flag (`--top N`, default 10)
- [x] Smoke gate: `shu -p` produces non-empty output, exits 0

**Gate to M2** *(cleared 2026-05-07)*: `watch -n 1 shu -p` runs comfortably (110 ms wall against a 1000 ms budget); work-portion is ~10 ms — under the `< 30 ms` per-frame target with 3× margin.

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

**Pre-M2 — TTY/termios lib extraction.** chakshu is the second AGNOS first-party tool to need raw mode (`cyim/src/tty.cyr` is the working donor — TCGETS/TCSETS, alt-screen, cursor, ANSI helpers; `cyrius-doom/src/input.cyr` is adjacent). On entering M2, extract `cyim/src/tty.cyr` into a new shared first-party repo (working name TBD — observation/sense family, e.g. `darshana` / `drishya`) rather than vendoring termios into `chakshu/lib/`. The second-consumer moment is when the right API seams become visible (chakshu wants SIGWINCH + render-loop integration that cyim does not need); deferring to M2 entry lets chakshu drive that surface instead of designing it in the abstract. Termios is **not** stdlib and the cyrius toolchain should not grow it.

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
