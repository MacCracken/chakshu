# chakshu — Roadmap

> **Status**: M2 closed (v0.5.0); M2.5 (mihi integration) is now the active milestone | **Last Updated**: 2026-05-19
>
> The path from v0.1.0 (scaffold) to v1.0 (ships as the AGNOS default system monitor, replacing the third-party `htop`/`btop` Bazaar packages).

---

## Closed milestones

- **M0 — Scaffold (v0.1.0, 2026-05-07)** ✓ Repo structure, manifest, CLAUDE.md, design-spec, ADR-0001 (binary name `shu`), `--help`/`--version`. Open carry-forward: list chakshu in [agnosticos shared-crates registry](https://github.com/MacCracken/agnosticos) (lives in another repo).
- **M1 — Plain snapshot (v0.2.0, 2026-05-07)** ✓ `shu -p` produces a complete single-frame system view (host/uptime/load/mem/cpu/disk/net + sortable top-N process table). 110 ms wall, ~10 ms work — under the `< 30 ms` per-frame target with 3× margin. See CHANGELOG `[0.2.0]`.
- **M2 — Full TUI (v0.5.0, 2026-05-19)** ✓ Full interactive monitor: alt-screen, signal-safe cleanup (signalfd), 1Hz refresh, SIGWINCH-driven re-layout, ↑↓ select, `s` sort cycle, `f` filter (comm+cmdline), `k` kill with confirm, `--pid N` focus mode, 16-color theme, PTY integration smoke. G.4 close audit clean: privacy invariants intact, no FFI/libc, exhaustive signal cleanup, largest single-fn stack 29 922 B (47% under 64 KiB threshold), `-p` work portion meets <30 ms target with 3× margin. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code. Binary size grew 183 → 293 KB across M2; investigation pinned the bulk to Cyrius 5.10.20→6.0.1 codegen drift (carried to M4). M2-deferred items for the record: threads/FDs in focus, per-focused-pid CPU%, true `--color auto`, fractional `--rate`, username resolution, USER column, swap reporting. See CHANGELOG `[0.5.0]` for the M2 arc summary.

---

## M2.5 — mihi integration (v0.6.0)

[mihi](https://github.com/MacCracken/maccracken/mihi) v0.8.0 is sitting at its M6 gate — chakshu integration is the only thing between it and v1.0. Coordinated release: chakshu cuts v0.6.0, mihi cuts v1.0.0.

- [ ] Bump cyrius pin `5.10.20` → `6.0.1` (host already runs 6.0.1; pin is the only stale piece)
- [ ] Add `[deps.mihi]` block in `cyrius.cyml` pointed at mihi v0.8.0 release; `cyrius deps` resolves `dist/mihi.cyr` → `lib/mihi.cyr`
- [ ] Replace hand-rolled probes in `src/proc.cyr` / `src/snapshot.cyr` with mihi equivalents:
  - hostname read → `mihi_hostname`
  - uptime read → `mihi_uptime_secs`
  - meminfo total/free → `mihi_mem_total` / `mihi_mem_free`
  - ncores counting → `mihi_cpu_count`
- [ ] Surface new identity data in `-p` header: cpu model (`mihi_cpu_model`), distro (`mihi_distro`), kernel (`mihi_kernel_name`/`mihi_kernel_version`)
- [ ] **New GPU panel** in TUI + `-p` — chakshu's first GPU surface, via `mihi_gpu_*` probes (count, name, memory, family, type)
- [ ] Update `docs/design-spec.md` §2 (data sources) and §3 (TUI layout) to reflect new GPU row + identity surface
- [ ] Per-frame deltas (cpu%, disk rate, net rate, per-pid stats) stay chakshu-local — mihi only owns identity/static surface
- [ ] PTY + scripts/smoke.sh gates remain green; new gates for GPU panel render
- [ ] Binary size delta noted in state.md; investigate any further codegen drift carried over from toolchain bump
- [ ] Cut **v0.6.0**; mihi's M6 flips closed → mihi v1.0 ships

### Gate to M3

mihi v1.0 ships. chakshu has clean separation between identity (mihi) and per-frame deltas (chakshu).

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
