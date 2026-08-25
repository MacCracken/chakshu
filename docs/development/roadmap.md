# chakshu — Roadmap

> **Forward-looking only.** Everything shipped lives in [`CHANGELOG.md`](../../CHANGELOG.md);
> current volatile state (version, pins, sizes, test counts) lives in
> [`state.md`](state.md). This file answers one question: *what is left to reach
> v1.0, and in which release does it land?*
>
> **Current: v0.8.0.** | **Last Updated**: 2026-08-24

---

## Release plan to v1.0

Work is batched so each cut is independently shippable and independently
verifiable — build + lean tests + AI tests + smoke + PTY green at every tag. A
minor (`0.8.0`, `0.9.0`) opens a milestone and may change surface; patches
inside it are additive or corrective only.

| Release | Theme | Gate |
|---|---|---|
| ~~0.8.0~~ | ~~`--watch` anomaly stream~~ | **shipped 2026-08-24 — M3 closed.** Consumer in the lean `shu`; producer is aegis 1.1.7's NDJSON sink |
| **0.8.1** | `--with-logs` sakshi context | Log lines reach the prompt, still redacted |
| **0.8.2** | AI hardening + hoosh gate promotion | The stub smoke is a *hard* CI gate |
| **0.9.0** | Perf + size close-out | §8 targets either met or formally revised |
| **0.9.1** | GPU telemetry depth | Per-device stats beyond count/name/memory |
| **0.9.2** | Theming + display polish | Dark/light configurable; no layout regressions |
| **0.9.3** | AGNOS parity | `--agnos` TUI runs, not just `-p` |
| **1.0.0** | Ship as the AGNOS default monitor | Registry promotion, ISO default, announce |

---

## 0.8.1 — `--with-logs`

- [ ] Opt-in sakshi log context in prompts.
- [ ] Log lines pass the same niyama redaction as cmdline — do **not** add a
      second, weaker path. The v0.7.13 sweep widened redaction to catch
      space-separated values, JWTs, AWS key ids and URL userinfo; logs must
      inherit that, not bypass it.
- [ ] Cap the log volume that can enter a prompt (privacy + token cost).

## 0.8.2 — AI hardening

- [ ] Promote `tests/hoosh_stub_smoke.py` from `continue-on-error` to a hard CI
      gate. It is currently the **only** ungated step in either workflow. Blocked
      on a libc CI runner: sandhi's `fdlopen`→libc `getaddrinfo` cannot run in a
      no-libc/sandboxed context, which is also why the maintainer's box can't
      exercise it.
- [ ] Decide the runtime-libc posture. `shu-ai` is **not** a pure no-libc binary
      because sandhi dlopens libc; the lean `shu` is. If that becomes a problem,
      the fallback is a chakshu-local raw-HTTP-over-TCP client with no sandhi and
      no dlopen.

---

## 0.9.0 — Perf + size close-out (opens M4)

Perf was audited at v0.7.15 under a real PTY at `--rate 1`, 281 processes,
16-core box. Two of four targets are met; the CPU one is diagnosed.

- [ ] **CPU `< 0.5%` at 1 Hz — currently 0.549%.** v0.7.15 took the TUI from two
      `/proc` walks per frame to one (rolling inter-frame baseline) and cached the
      static identity facts, moving it 0.650% → 0.549%. What is left is the
      per-row `cmdline` read and the render itself: measured `--top 1` at
      **0.466%**, i.e. under target, so the remaining cost scales with visible
      rows. Options: cache cmdline per pid across frames (it rarely changes), or
      accept that the target implies a smaller table than a 281-process box shows.
- [ ] **Binary size — §8's `< 256 KB`, currently 571,480 B (~2.2× over).** No
      chakshu-side lever remains: the safe stdlib drops (`bench`, `freelist`,
      `tagged`, `slice`) total ~25 KB, and `CYRIUS_DCE=1` has been a parity check
      rather than an optimizer since cycc 6.5.16 — it NOPs dead code in place and
      emits a byte-identical binary. **Decide here: revise §8, or take it upstream**
      (what the mihi/ai-hwaccel bundles still pull in). See
      [`p1-sweep-findings.md`](p1-sweep-findings.md).
- [ ] Manual TTY checks documented in `tests/` — the PTY suite covers 12
      scenarios; the checks that still need human eyes should be written down.

## 0.9.1 — GPU telemetry depth

- [ ] Richer per-device stats beyond the count/name/memory shipped at M2.5. The
      old blocker is gone: v0.7.14 moved ai-hwaccel to 2.3.19 in lockstep with
      mihi 1.2.5, so the coordinated bump this was waiting on has happened. What
      remains is choosing which stats to surface and where in the layout.

## 0.9.2 — Theming + display polish

- [ ] Dark / light themes, configurable.
- [ ] Revisit `--color auto` (currently only always/never are meaningful).

## 0.9.3 — AGNOS parity

Today `shu -p` is the working AGNOS path; the TUI is not agnos-ready. It is built
on the Linux signalfd + epoll model — SIGWINCH-driven resize and signal
multiplexing via darshana's `TTY_SIGMASK_*` / `tty_open_signalfd` / `epoll`, all
Linux-only, with ~18 signal-path references in `src/tui.cyr`.

- [ ] Agnos-native resize/signal handling: either gate the signalfd/epoll path
      off under `CYRIUS_TARGET_AGNOS` (poll `winsize`#60 for size, `kbscan` for
      input, no SIGWINCH and no signalfd), or wait on an agnos signal primitive.
- [ ] Verify the `--agnos` build runs the TUI, not just `-p`.

---

## 1.0.0 — Ship as the AGNOS default monitor

- [ ] Promote in agnosticos `shared-crates.md`: Pre-1.0 → v1.0+ Stable Index.
- [ ] Add `docs/applications/libs/chakshu/` in agnosticos, per first-party-standards.
- [ ] zugot recipe → AGNOS ISO default.
- [ ] Keep the Bazaar `htop` / `btop` recipes available — don't break user choice.
- [ ] Announce: AGNOS ships its own AI-augmented system monitor.

---

## Post-v1 (deferred — do not pull into earlier milestones)

- Per-cgroup view, without becoming a container monitor (different scope).
- Historical replay — chakshu over a sakshi-backed time-series store.
- Mobile / dashboard frontends: same backend, different render layer.
- Themed glyphs / non-ASCII art mode (btop-style).
- Plugin surface for custom panels.

---

## Standing constraints

These bind every release above; they are not work items.

- **No libc, no FFI, no ncurses in the lean `shu`.** Documented exception:
  `shu-ai` pulls sandhi, which dlopens libc, so it is not a pure no-libc binary
  and its live path only runs on a libc host.
- **AI is opt-in at the binary level** — the lean `shu` cannot reach the network
  at all. Enforced in CI since v0.7.13.
- **Privacy**: prompts carry only what the user can already see in the TUI. No
  `/home` contents, no env vars, no unredacted cmdline.
- **Version bumps at milestone close, not per feature** — patches inside a minor
  are additive or corrective only.
