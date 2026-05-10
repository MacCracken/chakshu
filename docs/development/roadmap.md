# chakshu — Roadmap

> **Status**: M2 in progress (G.3 code landed, manual QA pending) | **Last Updated**: 2026-05-10
>
> The path from v0.1.0 (scaffold) to v1.0 (ships as the AGNOS default system monitor, replacing the third-party `htop`/`btop` Bazaar packages).

---

## Closed milestones

- **M0 — Scaffold (v0.1.0, 2026-05-07)** ✓ Repo structure, manifest, CLAUDE.md, design-spec, ADR-0001 (binary name `shu`), `--help`/`--version`. Open carry-forward: list chakshu in [agnosticos shared-crates registry](https://github.com/MacCracken/agnosticos) (lives in another repo).
- **M1 — Plain snapshot (v0.2.0, 2026-05-07)** ✓ `shu -p` produces a complete single-frame system view (host/uptime/load/mem/cpu/disk/net + sortable top-N process table). 110 ms wall, ~10 ms work — under the `< 30 ms` per-frame target with 3× margin. See CHANGELOG `[0.2.0]`.

---

## M2 — Full TUI (v0.5.0)

Interactive full-screen monitor. Parity with `htop`. The point at which chakshu can replace `htop`/`btop` for AGNOS users who don't need AI features.

### Shipped (verified + released)

- **v0.2.1** — darshana dep wired in; M2 Slice A (minimum viable TUI: alt-screen + raw mode + q/Ctrl-C).
- **v0.2.2** — Slices B (signalfd cleanup) + C (1Hz render loop + `--rate`); 3 QA-found fixes.
- **v0.2.3** — Slice E.5 (filter mode + status line) + cmdline-fall-through fix.
- **v0.2.4** — Slice F (kill key + confirm dialog → SIGTERM).
- **v0.2.5** — Slice G.1 (PTY integration smoke gate); 2 latent input/winsize bugs caught by it and fixed.
- **v0.3.0** — Slice G.2 (16-color theme + `--color` flag).

### In progress (code landed, not yet released)

- **Slice G.3 — `--pid N` focus mode (will cut as v0.4.0).**
  - [x] CLI parse + PID validation (open `/proc/N/stat`)
  - [x] `tui_render_focus_frame` (host/uptime/load + PID/comm/state header + ppid/uid/threads/rss/mem% + full cmdline + status row)
  - [x] Render dispatcher routes table vs focus by `_tui_focus_pid`
  - [x] Mode-aware key handling (sort/filter/arrows no-op in focus; `k` kills focused pid)
  - [x] "PID N has exited" path when focused process dies during refresh
  - [x] PTY smoke #7 (`shu --pid 1 → q`) green
  - [ ] **MANUAL QA before v0.4.0 cut:**
    - [ ] `./build/shu --pid <real PID>` renders the 4-row layout correctly
    - [ ] Refresh tick visibly updates RSS / mem% values every second
    - [ ] `k` → `n` cancels (no signal); `k` → `y` actually kills target
    - [ ] After kill (or external `kill <PID>`), focus view flips to red `PID N has exited.` + status hint to quit
    - [ ] Sort/filter/arrow keys are silently ignored in focus mode (no glitches)
    - [ ] `--pid 0` → exit 2; `--pid 9999999` → exit 1; `--pid` (no value) → exit 2 (CLI errors are clear)
  - [ ] After QA passes: cut **v0.4.0**

### Remaining

- **Slice G.4 — M2 close review + audit (cuts as v0.5.0).**
  - [ ] Audit pass: any FFI sneaks in? privacy invariants intact (no `/home`, no env reads)? signal cleanup paths exhaustive? large stack buffers under the 64 KiB threshold?
  - [ ] Performance recheck: `shu` TUI at 1Hz + `shu -p` wall time still meet design-spec §8 targets
  - [ ] Walk the M2 design-spec checklist (rows 5/6/9/10) end-to-end
  - [ ] Roadmap M2 → closed (this section)
  - [ ] Bump VERSION 0.4.x → **0.5.0**; CHANGELOG `[0.5.0]` summarizes the M2 arc spanning all v0.2.x patches + v0.3.0 + v0.4.0
  - [ ] Documentation pass: `docs/development/state.md` reflects M2 close; help text final review

### Deferred to M2 polish or later (called out for transparency)

- Threads list and FD enumeration in focus mode (only counts shown today; `/proc/<pid>/task/` and `/proc/<pid>/fd/` walks deferred)
- Per-focused-pid CPU% (skipped in G.3 v1; would need a per-pid sampling loop)
- True `--color auto` with `$TERM` detection (currently auto behaves as always)
- `--rate` fractional Hz (currently integer 1-10; needs atof in stdlib)
- Username resolution (uid → name via `/etc/passwd`)
- USER column in the table view
- Swap reporting in the mem line

### Pre-M2 carry-forward (for the record)

- **TTY/termios lib extraction.** Originally pre-M2 work; executed across **darshana 0.2.0** (donor port from `cyim/src/tty.cyr`) → **darshana 0.3.0** (chakshu-driven extensions: `tty_winsize`, `tty_open_signalfd`, `tty_clear_to_eol/end`, `TTY_SIGMASK_*`). Phase 3 of the original extraction plan complete. cyim's own migration to depend on darshana (Phase 4) is open in the darshana roadmap, not chakshu's.

### Gate to M3

chakshu is a usable `htop` replacement. Bazaar default switches from `htop` to `chakshu` (Bazaar recipe still ships `htop` for users who prefer it).

---

## M3 — AI integration (v0.7.0)

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

## M4 — Polish + perf (v0.9.0)

- [ ] Performance audit against design-spec §8 targets
- [ ] Memory: `< 8 MB` resident at steady state
- [ ] CPU: `< 0.5%` at 1 Hz on a 4-core box
- [ ] Cold start `< 5ms`
- [ ] Manual TTY checks documented in `tests/`
- [ ] DCE binary size budget (target: < 256 KB) — currently ~270 KB; needs trimming
- [ ] Theme support (dark / light, configurable)

**Gate to v1.0**: all design-spec performance targets met; documentation complete; one external test user (non-author) runs chakshu for a week without filing showstopper bugs.

---

## M5 — v1.0 ship (v1.0.0)

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
