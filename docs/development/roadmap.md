# chakshu — Roadmap

> **Forward-looking only.** Everything shipped lives in [`CHANGELOG.md`](../../CHANGELOG.md);
> current volatile state (version, pins, sizes, test counts) lives in
> [`state.md`](state.md). This file answers one question: *what is left to reach
> v1.0, and in which release does it land?*
>
> **Current: v0.9.8.** | **Last Updated**: 2026-09-02

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
| ~~0.9.5~~ | ~~design-spec §1 close-out~~ | **shipped 2026-08-25.** All six §1 features that were in scope since M0 now ship; found and fixed a double-count in the aggregate disk rate; `docs/cli-contract.md` written (criterion 1) and criterion 4 decided |
| ~~0.9.6~~ | ~~toolchain + dependency refresh~~ | **shipped 2026-09-02.** cyrius `6.5.35` → `6.5.41` (one stdlib addition, zero removals; folded sandhi 1.9.15 fixes silent SSE event loss on the `?` overlay). `bayan` 1.5.2 → 1.5.4 after cyrius 6.5.39 reversed stdlib-vs-dep precedence and left the pin naming a file that no longer linked; **ai-hwaccel held at 2.3.19** per the mihi tracking rule, though 2.3.20 exists. Both manifests cut 328 → 130 lines. `scripts/check.sh` had drifted from `ci.yml` a third time — DCE parity, three security assertions, the `ai/*.cyr` glob and three required files were all missing locally; now 20 gates |
| ~~0.9.7~~ | ~~no-libc for `shu-ai`~~ | **shipped 2026-09-02.** Removed the last libc bridge: `src/nolibc.cyr` refuses the libssl `dlopen` path, `fdlopen`/`dynlib` left `ai/cyrius.cyml`. Both binaries are pure-syscall (0 `NEEDED`), verified by capturing a real TLS 1.3 ClientHello. **`shu-ai` builds for AGNOS** — striking one of the three AGNOS blockers below |
| ~~0.9.8~~ | ~~AGNOS process table~~ | **shipped 2026-09-02.** `proclist` #99 — the table renders on AGNOS for the first time, striking the second of the three v1.0 AGNOS blockers. Untracked columns read `n/a`, never a fabricated 0. Remaining gaps audited and filed in the agnos repo |
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
| 1 | **CLI surface frozen and documented** — every flag's argument shape, the exit-code matrix, and the semver policy for what forces a v2 | ⚠️ **documented (v0.9.5), not yet frozen.** [`docs/cli-contract.md`](../cli-contract.md) states the whole surface and the freeze/no-freeze split. It ends with **7 open questions** that must be settled before a 1.0 tag, because each is a breaking change afterwards — `--watch`'s optional argument, no `--`, no `--flag=value`, `-p` colliding with both incumbents, `--top` reading as a mode, `--explain` exiting 0 on an unreachable gateway, and inconsistent mode-incompatible-flag handling |
| 2 | **Test coverage adequate for the surface** | ✅ **met (v0.9.5).** **179** monitor + 39 AI unit tests, 29 smoke gates, 14 PTY scenarios, 17 AGNOS-QEMU checks, plus the literal-length and toolchain-pin gates. Every flag in the frozen surface now has an exit-code gate, and the v0.9.5 parsers (per-core, per-device, per-interface, partition filter) are fixture-tested rather than only exercised against this host |
| 3 | **Benchmarks captured** in `docs/benchmarks.md` | ✅ **met (v0.9.4).** Captured with a stated method and a committed harness (`tests/bench_tui.py`), including what is deliberately *not* benchmarked. Surfaced two unsettled §8 rows in the process: the 1 Hz CPU budget is met only by rounding and has no stated process count, and "first TUI frame < 50 ms" has no work-vs-wall definition |
| 4 | **≥1 downstream consumer green** | ✅ **decided (v0.9.5) — substituted, with the reason recorded.** The criterion is meaningless as written for a binary with no library surface: nothing can import chakshu. Two candidates were considered and rejected — the AGNOS ISO (chakshu is not on it yet, so it would be circular) and "the smoke suite" (self-referential; a project cannot be its own downstream). The substitute is the property the criterion actually exists to check — *that the frozen surface is exercised by something other than its own unit tests*: `-p`'s pipe-safe output and the full flag surface are driven end-to-end on every push by `scripts/smoke.sh` (29 gates), `tests/integration_smoke.py` (14 PTY scenarios) and `tests/agnos_qemu.py` (17 checks on a real AGNOS kernel). ⚠ Reversible: if chakshu ever grows a library surface, restore the original criterion |
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
> - ~~the **process table is empty** and cannot be fixed from this repo — AGNOS exposes no procfs and
>   no process-enumeration syscall.~~
>   ⭐ **STRUCK at v0.9.8 — stale, like the libc reason before it.** agnos 1.56.47 minted
>   `#99 proclist` and the cyrius wrapper shipped in **6.5.35**, i.e. it was available under the pin
>   chakshu held *before* v0.9.6. Nothing re-read the syscall table, so the blocker outlived its own
>   fix. `src/proc_agnos.cyr` implements it; the table renders on a real kernel under QEMU and is
>   gated by three new `agnos_qemu.py` assertions. CPU%/MEM%/USER read `n/a` — the kernel tracks no
>   per-process cpu/rss and proclist carries no uid.
> - **load, cpu, disk and net still render `n/a`** — these are genuine gaps, filed upstream;
> - ~~**`shu-ai` cannot run at all** — sandhi dlopens libc, which AGNOS has no host for.~~
>   ⭐ **STRUCK at v0.9.7 — this reason was stale and is now false.** cyrius 6.1.21 had already made
>   the native TLS stack the default backend; chakshu was linking the libssl bridge only because
>   `lib/tls.cyr` compiles both transports in. `src/nolibc.cyr` removed it: `shu-ai` is pure-syscall
>   and `cyrius build --agnos main.cyr` produces a 2,880,824 B AGNOS ELF, gated in CI. `--with-logs`
>   fails closed on AGNOS (its validator needs procfs); `--explain` and the `?` overlay work.
>   **Two of the three reasons below still stand, and both are upstream.**
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

- ~~**Process table on AGNOS.**~~ **RESOLVED at v0.9.8** — `#99 proclist` (agnos
  1.56.47, cyrius wrapper since 6.5.35). Implemented in `src/proc_agnos.cyr`.
- **Per-process CPU time, RSS and uid on AGNOS.** proclist reserves `+56` for cpu
  and rss and the kernel does not track them yet; the record carries no uid. So
  CPU%, MEM% and USER read `n/a`. Filed upstream.
- **Disk and network I/O counters on AGNOS.** No equivalent of `/proc/diskstats`
  or `/proc/net/dev`, so the `disk:` and `net:` RATE lines read `n/a`. Volume
  *capacity* is available (`statfs` #103, `blk_enum` #75) and is a separate,
  implementable panel. Filed upstream.
- **Load average on AGNOS.** agnos `sysinfo` #35 is a 40-byte struct with no
  `loads[]`. Filed upstream.

---

## Post-v1 (deferred — do not pull into earlier milestones)

- Per-cgroup view, without becoming a container monitor (different scope).
- Historical replay — chakshu over a sakshi-backed time-series store.
- Mobile / dashboard frontends: same backend, different render layer.
- Themed glyphs / non-ASCII art mode (btop-style).
- Focus-panel depth: threads list, fd enumeration, and per-focused-pid CPU%
  (`src/tui.cyr` head comment). None gates v1.0 — the focus panel already shows
  status, cmdline and the kill flow.
- Promote reverse-video (`_tui_invert_on`/`_off`) into darshana. The trigger is a
  SECOND consumer wanting the same primitive; cyim's syntax highlighting needs
  richer attributes, so it is not that consumer (`src/tui.cyr:~200`).
- Plugin surface for custom panels.

---

## Standing constraints

These bind every release above; they are not work items.

- **No libc, no FFI, no ncurses in the lean `shu`.** Documented exception:
  ~~`shu-ai` pulls sandhi, which dlopens libc~~ — **exception removed at v0.9.7**;
  both binaries are now statically linked, pure-syscall, zero `NEEDED`.
- **AI is opt-in at the binary level** — the lean `shu` cannot reach the network
  at all. Enforced in CI since v0.7.13.
- **Privacy**: prompts carry only what the user can already see in the TUI. No
  `/home` contents, no env vars, no unredacted cmdline.
- **Version bumps at milestone close, not per feature** — patches inside a minor
  are additive or corrective only.
