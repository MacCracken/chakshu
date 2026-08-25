# chakshu — Roadmap

> **Forward-looking only.** Everything shipped lives in [`CHANGELOG.md`](../../CHANGELOG.md);
> current volatile state (version, pins, sizes, test counts) lives in
> [`state.md`](state.md). This file answers one question: *what is left to reach
> v1.0, and in which release does it land?*
>
> **Current: v0.9.4.** | **Last Updated**: 2026-08-25

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
| ~~0.9.4~~ | ~~v1.0 readiness~~ | **shipped 2026-08-25.** Security audit PASS (14 confirmed of 38 raised); fractional `--rate`; swap/cached/buffers; benchmarks + audit artifacts; an `--agnos` CI gate and the literal-length gate the P-1 sweep specified. Two v1.0 criteria went unmet → met |
| **1.0.0** | Ship as the AGNOS default monitor | Registry promotion, ISO default, announce |

---

## v1.0 criteria

> Published here because [first-party-documentation.md:240] requires every repo to carry its own
> v1.0 criteria list in its roadmap. chakshu did not have one until v0.9.4, and that omission is
> exactly why the gaps below went unseen: the 1.0.0 section tracked five *distribution* acts and
> not one quality gate, so the repo could look finished from the inside while its published
> contract was wrong.
>
> The ecosystem has no central bar — each repo publishes its own, and the count varies (rosnet six,
> darshana five, hapi eight, kii twelve). Six is the modal shape and rosnet's list is the canonical
> instance, adapted below for a **binary**, which freezes a CLI rather than a function surface.

| # | Criterion | State |
|---|---|---|
| 1 | **CLI surface frozen and documented** — every flag's argument shape, the exit-code matrix, and the semver policy for what forces a v2 | ❌ **not met.** No contract doc exists. `docs/design-spec.md` §7 omits `--sort`, `--top` and `--theme`, misstates `--rate`'s range, and still calls `--with-logs` "pending" |
| 2 | **Test coverage adequate for the surface** | ⚠️ **close.** 130 monitor + 39 AI + 14 PTY + 17 AGNOS-QEMU + 25 smoke gates. `--rate`/`--color`/`--theme`/`--pid 0`/unknown-flag exit codes gated at v0.9.4; a literal-length gate is still absent |
| 3 | **Benchmarks captured** in `docs/benchmarks.md` | ✅ **met (v0.9.4).** Captured with a stated method and a committed harness (`tests/bench_tui.py`), including what is deliberately *not* benchmarked. Surfaced two unsettled §8 rows in the process: the 1 Hz CPU budget is met only by rounding and has no stated process count, and "first TUI frame < 50 ms" has no work-vs-wall definition |
| 4 | **≥1 downstream consumer green** | ❓ **undefined for a binary with no library surface.** Needs an explicit recorded decision — the AGNOS ISO is the closest analogue |
| 5 | **CHANGELOG complete** from v0.1.0 onward | ✅ **met** |
| 6 | **Security audit PASS** in `docs/audit/YYYY-MM-DD-audit.md` | ✅ **met (v0.9.4).** [`docs/audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md) — 4 surfaces, 38 raised, **14 confirmed** (24 refuted by an adversarial pass), all fixed and gated. Two HIGH: `--watch` silently dropped 23.7% of security events, and `$CHAKSHU_LOG_PATH` put the process environment into the AI prompt. GPU telemetry came back clean. Known gaps stated rather than hidden |

**Additional gate, specific to this project's milestone —** see the decision block below.

---

## 1.0.0 — Ship as the AGNOS default monitor

> ⛔ **BLOCKED ON A DECISION — the milestone's premise does not currently hold.**
>
> The milestone is *"ship as the AGNOS default monitor"* and the announcement line is *"AGNOS ships
> its own AI-augmented system monitor"*. On AGNOS today, verified by `tests/agnos_qemu.py` against a
> real kernel:
>
> - the **process table is empty** and cannot be fixed from this repo — AGNOS exposes no procfs and
>   no process-enumeration syscall (see *Blocked upstream* below);
> - **load, cpu, disk and net all render `n/a`** for the same reason;
> - **`shu-ai` cannot run at all** — sandhi dlopens libc, which AGNOS has no host for.
>
> So on AGNOS the "AI-augmented system monitor" shows hostname, kernel, memory total, and a bare
> column header with no rows — and neither half of the announcement is true there. Separately, the
> release pipeline **produces no AGNOS artifact at all** (`release.yml`'s matrix is `x86_64-linux`
> only), so there is currently nothing to make an ISO default.
>
> Three honest options; the choice must be recorded here before a tag:
>
> 1. **Hold 1.0** until AGNOS ships a process-enumeration syscall, then ship the milestone as written.
> 2. **Cut 1.0 as the Linux monitor** — drop "AGNOS default" from the milestone and the
>    announcement, keep AGNOS as a supported-but-degraded target, and revisit the default at 1.1.
> 3. **Ship as the AGNOS default anyway**, with the degradation documented and surfaced in the UI,
>    on the argument that hostname/kernel/memory beats no first-party monitor at all.
>
> Whichever is chosen, these are prerequisites for *any* of them: an AGNOS target in the release
> matrix (or a written statement that AGNOS users build from source), the kernel-cycle-1.56.46
> requirement encoded in the zugot recipe, and a user-facing message where the process table is
> empty — `src/tui.cyr` already argues in its own comments that an empty field "reads as a render
> bug" while `n/a` is "the honest answer", and then does not apply that rule to the primary panel.

- [ ] Promote in agnosticos `shared-crates.md`: Pre-1.0 → v1.0+ Stable Index.
- [ ] Add `docs/applications/libs/chakshu.md` in agnosticos (flat `.md`, **not** a directory), **and**
      a row in `docs/applications/binaries.md` — chakshu ships a binary, and omitting the destination
      row while deleting the pre-1.0 row is the half-done-graduation failure `shared-crates.md`'s own
      header warns about. Note the standards doc lives at
      `docs/development/first-party/first-party-standards.md` (CLAUDE.md links a path that does not exist).
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
