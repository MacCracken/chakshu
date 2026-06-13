# chakshu — Roadmap

> **Status**: M0–M2.5 closed; **M3 (AI integration) nearly done** — live `--explain` + streamed `?` overlay via hoosh shipped across v0.7.2–v0.7.4 (lean/AI binary split); v0.7.5 was an interim toolchain/dep refresh (Cyrius 6.2.2, niyama 1.0.5). **One cut left to close M3: v0.7.6 (`--watch` + `--with-logs`).** Then M4 (polish/perf) and M5 (v1.0 ship). | **Last Updated**: 2026-06-13
>
> The path from v0.1.0 (scaffold) to v1.0 (ships as the AGNOS default system monitor, replacing the third-party `htop`/`btop` Bazaar packages).

---

## Closed milestones

- **M0 — Scaffold (v0.1.0, 2026-05-07)** ✓ Repo structure, manifest, CLAUDE.md, design-spec, ADR-0001 (binary name `shu`), `--help`/`--version`.
- **M1 — Plain snapshot (v0.2.0, 2026-05-07)** ✓ `shu -p` produces a complete single-frame system view (host/uptime/load/mem/cpu/disk/net + sortable top-N process table). 110 ms wall, ~10 ms work — under the `< 30 ms` per-frame target with 3× margin. See CHANGELOG `[0.2.0]`.
- **M2 — Full TUI (v0.5.0, 2026-05-19)** ✓ Full interactive monitor: alt-screen, signal-safe cleanup (signalfd), 1Hz refresh, SIGWINCH-driven re-layout, ↑↓ select, `s` sort cycle, `f` filter (comm+cmdline), `k` kill with confirm, `--pid N` focus mode, 16-color theme, PTY integration smoke. G.4 close audit clean: privacy invariants intact, no FFI/libc, exhaustive signal cleanup, largest single-fn stack 29 922 B (47% under 64 KiB threshold), `-p` work portion meets <30 ms target with 3× margin. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code. M2-deferred items for the record: threads/FDs in focus, per-focused-pid CPU%, true `--color auto`, fractional `--rate`, username resolution, USER column, swap reporting. See CHANGELOG `[0.5.0]`.
- **M2.5 — mihi integration (v0.6.0, 2026-05-20)** ✓ Identity / static-fact reads (hostname / kernel / distro / cpu_model / cpu_count / mem_total / mem_free / uptime / gpu_*) now flow through `lib/mihi.cyr`; per-frame deltas stay chakshu-local. New `-p` identity block (kern / proc / gpu lines) + GPU panel slot in TUI table mode — **basic GPU monitoring is live** (deepening it is tracked under M4). mihi was pinned v0.8.0 at the cut; **mihi has since shipped v1.0 and chakshu pins `1.0.0` as of v0.7.1**. Binary size grew 293 → 772 KB at the cut (ai-hwaccel backend stack linked-but-DCE-NOPed; carried to M4). See CHANGELOG `[0.6.0]`.

## Interim cuts (toolchain / dep refreshes — no new feature surface)

- **v0.6.1 (2026-05-20)** — darshana 0.3.0 → 0.4.1 forward-compat refresh. No behavior change.
- **v0.7.0 (2026-06-06) — AGNOS build-target cycle opened.** `shu` targets AGNOS: system stats via mihi `uname` / `sysinfo`. The **`klug` kernel-log view** (via the `klog` syscall) is **deferred until the AGNOS cycle picks up** — described at cut-time but not yet implemented in `src/`.
- **v0.7.1 (2026-06-10)** — Cyrius 6.0.1 → 6.1.27; mihi 0.8.0 → 1.0.0; stdlib `json` → `bayan` (6.1.x rename); ai-hwaccel held at 2.2.6 to match mihi's transitive pin. No behavior change at the chakshu surface. See CHANGELOG `[0.7.1]`.
- **v0.7.5 (2026-06-13)** — Cyrius 6.1.29 → 6.2.2 (both manifests); niyama 1.0.4 → 1.0.5 (AI build). darshana 0.7.0 / mihi 1.0.0 already latest; ai-hwaccel still held at 2.2.6 (mihi pin). Both builds + smoke green on 6.2.2; no behavior change. The M3-closing `--watch` / `--with-logs` feature cut moved here from 0.7.5 → **0.7.6**. See CHANGELOG `[0.7.5]`.

---

## M3 — AI integration — substantive milestone, in progress

The substantive case for first-party. `chakshu` becomes the panel where the AGNOS LLM stack meets the live system view. Landing across 0.7.2–0.7.6 (incremental cuts rather than one big v0.8.0).

**Foundation — shipped v0.7.2** (`src/ai.cyr`):

- [x] Prompt assembly per design-spec §6.2 (with privacy redaction)
- [x] niyama-driven secret-pattern redaction in cmdline args (re2; `src/ai.cyr`)
- [x] `--explain <pid>` — non-interactive one-shot (redacted-context preview)

**Live transport — shipped v0.7.3:**

- [x] hoosh HTTP client via sandhi — `--explain` POSTs `/v1/chat/completions`, prints the answer, falls back to the redacted context on failure. (design-spec §6.3 corrected: HTTP, not the stale Unix-socket framing.)
- [x] `?` key — in-TUI explain **overlay** (`ai_tui_explain`); request→render for now
- [x] **lean/AI binary split** — default `shu` (monitor, ~0.84 MB) vs `shu-ai` (+AI, ~2.57 MB); AI deps confined to `ai/cyrius.cyml`

**SSE streaming + hoosh 2.3.5 — shipped v0.7.4:**

- [x] Incremental streamed render in the `?` overlay via `sandhi_http_stream` (fnptr `_ai_stream_cb` extracts each OpenAI `delta.content`) + Esc/q cancel (non-blocking `poll(stdin)`). Falls back to the context preview if nothing streams.
- [x] hoosh **2.3.5** bearer-token auth — `Authorization: Bearer $CHAKSHU_HOOSH_TOKEN` when set (token-less gateway still open).
- [x] Smoke gate: `tests/hoosh_stub_smoke.py` stands up an OpenAI-shaped stub and runs `shu-ai --explain` against it (POST + content extraction + Bearer header). **Soft CI gate** — sandhi's `fdlopen`→libc `getaddrinfo` can't run in a no-libc/sandbox context, so it's pending its first green on a libc CI runner (then promote to hard).

**Logs + anomaly stream — v0.7.6 (closes M3):**

- [ ] `--watch` — anomaly stream (subscribe to aegis/phylax events)
- [ ] `--with-logs` opt-in for sakshi log context in prompts

**Gate to M4**: a user can ask "why is this process spiking" and get a coherent answer that quotes real /proc data.

> **Runtime-libc caveat (0.7.4):** sandhi's HTTP client dlopens libc (`getaddrinfo`/libssl), so **`shu-ai` is not a pure no-libc binary** and its live path only runs on a libc host (CI/AGNOS). The lean `shu` (no sandhi) stays pure no-libc per CLAUDE.md. If this becomes a problem, the fallback is a chakshu-local raw-HTTP-over-TCP client (no sandhi, no dlopen).

> **Size note:** the lean/AI split keeps the default `shu` at ~0.84 MB (under btop's install); the AI heft (~2.57 MB) is confined to the opt-in `shu-ai`. M4 size work targets the lean monitor only (design-spec §8 `<256 KB`, still ~3.3× over).

---

## M4 — Polish + perf (v0.9.0)

- [ ] Performance audit against design-spec §8 targets
- [ ] Memory: `< 8 MB` resident at steady state
- [ ] CPU: `< 0.5%` at 1 Hz on a 4-core box
- [ ] Cold start `< 5ms`
- [ ] Manual TTY checks documented in `tests/`
- [ ] Binary size budget — **target `< 1 MB` for now** (interim relaxation; design-spec §8's `< 256 KB` stays the long-term aspiration). **Currently ~1.38 MB — over budget** as of 0.7.2: niyama's re2 pulls the `unicode` tables (~350 KB) + its unused engines (~248 KB), on top of ai-hwaccel's DCE-NOPed backend stack. Decide here: pursue real codegen `--strip-dead` of the unused niyama engines + unicode data, or revert redaction to a chakshu-local matcher (drops the niyama dep entirely).
- [ ] Deepen GPU telemetry — basic GPU panel shipped at M2.5; richer per-device stats means **updating the `ai-hwaccel` dep** (currently held at 2.2.6 to match mihi's own pin, so this may need a coordinated mihi bump).
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

- Per-cgroup view (without becoming a container monitor — that's a different scope)
- Historical replay (chakshu over a sakshi-backed time-series store)
- Mobile / dashboard frontends — same backend, different render layer
- Themed glyphs / non-ASCII art mode (btop-style)
- Plugin surface for custom panels
