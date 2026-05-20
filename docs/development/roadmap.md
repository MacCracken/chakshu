# chakshu — Roadmap

> **Status**: M2.5 closed (v0.6.0); M3 (AI integration) is now the active milestone | **Last Updated**: 2026-05-20
>
> The path from v0.1.0 (scaffold) to v1.0 (ships as the AGNOS default system monitor, replacing the third-party `htop`/`btop` Bazaar packages).

---

## Closed milestones

- **M0 — Scaffold (v0.1.0, 2026-05-07)** ✓ Repo structure, manifest, CLAUDE.md, design-spec, ADR-0001 (binary name `shu`), `--help`/`--version`. Open carry-forward: list chakshu in [agnosticos shared-crates registry](https://github.com/MacCracken/agnosticos) (lives in another repo).
- **M1 — Plain snapshot (v0.2.0, 2026-05-07)** ✓ `shu -p` produces a complete single-frame system view (host/uptime/load/mem/cpu/disk/net + sortable top-N process table). 110 ms wall, ~10 ms work — under the `< 30 ms` per-frame target with 3× margin. See CHANGELOG `[0.2.0]`.
- **M2 — Full TUI (v0.5.0, 2026-05-19)** ✓ Full interactive monitor: alt-screen, signal-safe cleanup (signalfd), 1Hz refresh, SIGWINCH-driven re-layout, ↑↓ select, `s` sort cycle, `f` filter (comm+cmdline), `k` kill with confirm, `--pid N` focus mode, 16-color theme, PTY integration smoke. G.4 close audit clean: privacy invariants intact, no FFI/libc, exhaustive signal cleanup, largest single-fn stack 29 922 B (47% under 64 KiB threshold), `-p` work portion meets <30 ms target with 3× margin. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code. Binary size grew 183 → 293 KB across M2; investigation pinned the bulk to Cyrius 5.10.20→6.0.1 codegen drift (carried to M4). M2-deferred items for the record: threads/FDs in focus, per-focused-pid CPU%, true `--color auto`, fractional `--rate`, username resolution, USER column, swap reporting. See CHANGELOG `[0.5.0]` for the M2 arc summary.
- **M2.5 — mihi integration (v0.6.0, 2026-05-20)** ✓ Identity / static-fact reads (hostname / kernel / distro / cpu_model / cpu_count / mem_total / mem_free / uptime / gpu_*) now flow through `lib/mihi.cyr`; per-frame deltas stay chakshu-local. Cyrius pin bumped 5.10.20 → 6.0.1 (matches mihi + host). New `-p` identity block (kern / proc / gpu lines) + GPU panel slot in TUI table mode. Smoke and PTY gates re-baselined for the new header shape (7/7 PTY tests green, 14/14 smoke checks green, 57/57 unit tests). mihi pinned at v0.8.0 (acknowledgment cut — bundle byte-identical to 0.7.0). **mihi v1.0 is now unblocked** — mihi's M6 gate was this consumer integration. Binary size grew 293 → 772 KB on the cut — driven by ai-hwaccel's full backend stack being linked-but-DCE-NOPed; carried to M4. See CHANGELOG `[0.6.0]`.

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
