# chakshu — Roadmap

> **Forward-looking only.** Everything shipped lives in [`CHANGELOG.md`](../../CHANGELOG.md);
> current volatile state (version, pins, sizes, test counts) lives in
> [`state.md`](state.md). This file answers one question: *what is left to reach
> v1.0, and in which release does it land?*
>
> **Current: v0.9.3.** | **Last Updated**: 2026-08-24

---

## Release plan to v1.0

Work is batched so each cut is independently shippable and independently
verifiable — build + lean tests + AI tests + smoke + PTY green at every tag. A
minor (`0.8.0`, `0.9.0`) opens a milestone and may change surface; patches
inside it are additive or corrective only.

| Release | Theme | Gate |
|---|---|---|
| ~~0.8.0~~ | ~~`--watch` anomaly stream~~ | **shipped 2026-08-24 — M3 closed.** Consumer in the lean `shu`; producer is aegis 1.1.7's NDJSON sink |
| ~~0.8.1~~ | ~~`--with-logs` log + anomaly context~~ | **shipped 2026-08-24.** Per-pid attribution proved impossible (sakshi carries no pid); ships system-level context + the anomaly ring |
| ~~0.8.2~~ | ~~AI hardening + hoosh gate promotion~~ | **shipped 2026-08-24.** The blocker was a whitespace-intolerant JSON parse misreported as a transport error, not libc |
| ~~0.9.0~~ | ~~Perf + size close-out~~ | **shipped 2026-08-24.** All §8 targets met; the size target formally revised 256 KB → 768 KB with the reason recorded |
| ~~0.9.1~~ | ~~GPU telemetry depth~~ | **shipped 2026-08-24.** Live busy%/VRAM/temp from DRM sysfs, matched to devices by PCI id |
| ~~0.9.2~~ | ~~Theming + display polish~~ | **shipped 2026-08-24.** `--theme dark\|light\|auto`; `--color auto` now honours NO_COLOR/TERM/isatty instead of aliasing `always` |
| ~~0.9.3~~ | ~~AGNOS parity~~ | **shipped 2026-08-24.** TUI runs on AGNOS via `kbscan`/`winsize` polling. Root-caused an AGNOS kernel bug (12 KB usable of a 2 MB stack page) and fixed it upstream in cycle 1.56.46 |
| **1.0.0** | Ship as the AGNOS default monitor | Registry promotion, ISO default, announce |

---

## 1.0.0 — Ship as the AGNOS default monitor

- [ ] Promote in agnosticos `shared-crates.md`: Pre-1.0 → v1.0+ Stable Index.
- [ ] Add `docs/applications/libs/chakshu/` in agnosticos, per first-party-standards.
- [ ] zugot recipe → AGNOS ISO default.
- [ ] Keep the Bazaar `htop` / `btop` recipes available — don't break user choice.
- [ ] Announce: AGNOS ships its own AI-augmented system monitor.

---

## Blocked upstream (not schedulable here)

- **Process table on AGNOS.** AGNOS exposes no procfs and no process-enumeration
  syscall (`getpid`/`spawn`/`waitpid`/`kill` only), so `shu` on AGNOS renders the
  column header and no rows. Needs a kernel enumeration primitive first; there is
  no chakshu-side workaround.

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
