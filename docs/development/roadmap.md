# chakshu — Roadmap

> **Forward-looking only.** What shipped is in [`CHANGELOG.md`](../../CHANGELOG.md). Current
> volatile state (version, pins, sizes, test counts) is in [`state.md`](state.md). This file
> answers one question: *what is left to reach v1.0, and in which release does it land?*
>
> **Current: v0.12.1.** | **Last Updated**: 2026-10-31 (the 0.12.1 fixes)

---

## Where v1.0 stands

The monitor is feature-complete. Five of the six v1.0 criteria are met. What remains is **settling
and freezing the CLI contract**, on cmdit; **fixing what the freeze would lock in wrong**;
**refreshing the evidence** (benchmarks and a security audit, both older than three toolchain
minors); and **the distribution acts**. No new monitor features are planned before 1.0.

The release numbers below are proposals. Each version bump stays the owner's call.

| Release | Theme | Exit gate |
|---|---|---|
| ~~0.12.0~~ | ~~The CLI on cmdit; every contract question decided~~ | ✅ **shipped 2026-10-31.** No open question in `cli-contract.md`; identity bar run; `check.sh` green |
| ~~0.12.1~~ | ~~Fix what the freeze would lock in~~ | ✅ **shipped 2026-10-31.** `-p` line shape correct for every pid width; no byte-clipped UTF-8 anywhere |
| **0.13.0** | v1.0 evidence and hygiene | §8 fully defined and re-measured; delta audit filed; required root files; AGNOS artifacts in `release.yml` |
| **1.0.0** | Freeze and ship | contract marked frozen; distribution acts done |

---

## v1.0 criteria

> Published here because [first-party-documentation.md:240] requires every repo to carry its own
> list. A binary freezes a CLI rather than a function surface, so criterion 1 is the CLI contract.
> The list follows rosnet's six, the modal shape in the ecosystem.

| # | Criterion | State |
|---|---|---|
| 1 | **CLI surface frozen and documented**: every flag's argument shape, the exit-code matrix, the semver policy | ⚠️ **Settled, not frozen.** Every question in [`docs/cli-contract.md`](../cli-contract.md) was decided at v0.12.0 and is recorded there. It freezes at 1.0.0 |
| 2 | **Test coverage adequate for the surface** | ✅ **Met.** 357 monitor + 53 AI unit assertions, smoke, 16 PTY scenarios, 35 AGNOS-QEMU checks, plus the literal-length, toolchain-pin and no-libc gates. The argument parser has its own unit groups since v0.12.0 (149 assertions through `cmdit_parse_argv`, mutation-checked 11/11) |
| 3 | **Benchmarks captured** in `docs/benchmarks.md` | ⚠️ **Captured, but stale.** Taken at v0.9.6 on cyrius 6.5.41, three toolchain minors ago. It records a **miss** on the 1 Hz CPU budget (0.600 % against < 0.5 %), and §8's first-frame row has no definition. Re-measured in 0.13.0 |
| 4 | **≥1 downstream consumer green** | ✅ **Substituted (v0.9.5), reason recorded.** Nothing can import a binary. The substitute checks what the criterion exists to check: the frozen surface is driven end to end on every push by `scripts/smoke.sh`, `tests/integration_smoke.py` and, on a real AGNOS kernel, `tests/agnos_qemu.py`. ⚠ Reversible: restore the original criterion if chakshu ever grows a library surface |
| 5 | **CHANGELOG complete** from v0.1.0 onward | ✅ **Met** |
| 6 | **Security audit PASS** in `docs/audit/` | ⚠️ **Met at v0.9.4** ([`2026-08-25-audit.md`](../audit/2026-08-25-audit.md): 38 raised, 14 confirmed, all fixed and gated). The standards require an audit before every release, and the AGNOS proclist parser, the C1/UTF-8 scrubbers, the no-libc refusal and sandhi 1.13 all postdate it. A delta audit lands in 0.13.0 |

---

## 0.12.0 — the CLI on cmdit, every contract question decided ✅ shipped 2026-10-31

Detail in the CHANGELOG's `[0.12.0]`. The parser is `src/cli_parse.cyr` (pure, on cmdit 1.5.0,
unit-tested); `src/cli.cyr` dispatches.

- [x] Q1–Q10 decided and recorded in `docs/cli-contract.md`.
- [x] `[deps.cmdit] tag = "1.5.0"` in both manifests.
- [x] `chakshu_main` split into parse → config and dispatch; the parse is driven with synthetic argv
      in `tests/chakshu.tcyr`.
- [x] `--rows`/`--top`, `--pid` and `--explain` are strict integers (`5x` and overflow refused).
- [x] `--pid N --help` prints help.
- [x] `--` and `--flag=value`.
- [x] Identity bar against v0.11.1: 68 lean and 9 `shu-ai` invocations; every difference is a
      decision above or a deliberate wording change, listed in the CHANGELOG.
- [x] design-spec §5 and §7 match `shu --help`.

## 0.12.1 — fix what the freeze would lock in ✅ shipped 2026-10-31

A patch, corrective only. Detail in the CHANGELOG's `[0.12.1]`.

- [x] **The `-p` PID column is 7 wide**, the width of Linux's `PID_MAX_LIMIT` (4,194,304), so
      the header stays one fixed string and every row's USER starts in column 9. The TUI's column
      moved with it.
- [x] **`-p`'s `disk:` and `net:` lines no longer end in two spaces.** The separator now goes
      before each entry after the first.
- [x] **No render-side clip ends inside a UTF-8 character.** `utf8_cut_len` (`src/proc.cyr`) is
      the one cut, used by the TUI's CMD column, kernel-thread comm, focus-panel cmdline and USER
      column, `-p`'s USER column, the `--watch` panel and the AI overlay (the last two had their
      own copies).
- [x] **The AGNOS TUI refuses a stdin that is not a terminal**, as Linux does. ⚠ This item first
      said to check `tty_isatty(1)` (stdout). That was wrong: Linux's gate is stdin
      (`tty_raw(0)`), and `shu > file` / `shu | head` are supported there (PTY scenario 15), so a
      stdout check would have made the two platforms disagree. The real gap was stdin: on AGNOS
      keys come from `kbscan#42` whatever fd 0 is, so `shu -p | shu` handed the console to the
      second stage. Gated on `tty_isatty_is_per_fd() == 1`, so an older kernel behaves as before.
- [x] Tests for each: `utf8_cut_len` unit cases; `smoke.sh` gates for trailing whitespace and for
      PID alignment, including a real 7-digit pid from a private pid namespace; PTY scenarios 17
      and 18 (a 4-byte character across the table's and the focus panel's cut points) and 19 (a
      7-digit pid row in the TUI); `agnos_qemu.py` scenario 7 (`shu -p | shu`). Each fails against
      v0.12.0. The namespace cases skip where unprivileged user namespaces are refused.

## 0.13.0 — v1.0 evidence and hygiene

A minor, because §8 changes. Nothing here adds a feature.

- [ ] **Settle §8's two undefined rows** (decisions D1 and D2), then re-capture
      `docs/benchmarks.md` on the current toolchain with `tests/bench_tui.py`. If the CPU budget
      is still missed at the named workload, apply benchmarks.md's own lead: make the rest of the
      per-pid walk lazy, as the USER read was (0.866 % → 0.517 %).
- [ ] **Make §8's size row name the shipped (DCE'd) binary.** With cmdit the plain lean build is
      791,016 B, over 768 KB, while the shipped one is 483,816 B. The row has always meant the
      shipped binary, but it does not say so.
- [ ] **Delta security audit** → `docs/audit/YYYY-MM-DD-audit.md`, covering what postdates
      2026-08-25:
  - the AGNOS proclist parser (`src/proc_agnos.cyr`);
  - every `tty_sanitize_buf` path (comm, cmdline, log lines, the watch ring, the model's answer);
  - the `src/nolibc.cyr` refusal under 6.6.20's last-definition binding;
  - the cmdit parse surface;
  - sandhi 1.10 → 1.13 (the hoosh transport);
  - `--watch`'s NDJSON reader and `--with-logs`' path validator, re-read against today's code.
- [ ] **Required root files**: `SECURITY.md` and `CODE_OF_CONDUCT.md`. The standards say every
      repo ships them and that `cyrius init` scaffolds them; take them from its templates rather
      than hand-rolling.
- [ ] **AGNOS artifacts in `release.yml`**: `shu-agnos` and `shu-ai-agnos`, as owl and kii already
      ship theirs. The runner cannot execute them, so the release job checks the ELF and
      `agnos_qemu.py` stays a pre-tag step.
- [ ] **`scripts/version-bump.sh`**, from the standards' layout. A cut edits `VERSION`,
      `CHAKSHU_VERSION` and the CHANGELOG by hand today, and `check.sh` only catches a mismatch
      afterwards.
- [ ] **State the process ceiling.** `PROC_MAX` is a hard 8,192 (`src/processes.cyr:35`), coupled
      to `_tui_filtered_idx`. Past it, processes are left out of the table, the busiest
      included. Either document it under the contract's limits or size both from the live count.
- [ ] Record the AGNOS decision (D3) and the versioning ADR (D4).

## 1.0.0 — freeze and ship

- [ ] `docs/cli-contract.md` status → **frozen**. Criterion 1 met.
- [ ] Run the manual checklist (`tests/MANUAL.md`) and `tests/agnos_qemu.py` on the release
      candidate.
- [ ] agnosticos: move chakshu from the Pre-1.0 table in
      `docs/development/planning/shared-crates.md` to the v1.0+ index. Add
      `docs/applications/libs/chakshu.md` (a flat `.md`, like `cyim.md` and `iam.md`) **and** a row
      in `docs/applications/binaries.md`. Leaving out the destination row while deleting the
      pre-1.0 row is the half-done graduation `shared-crates.md` warns about.
- [ ] zugot: `base/chakshu.cyml`, on the `base/owl.cyml` pattern (install the release tarball),
      in groups `base` / `core` / `tier1`. Encode the minimum agnos kernel: ≥ 1.57.1 for everything
      `agnos_qemu.py` checks, ≥ 1.57.13 for darshana's per-fd isatty and typeahead flush. Confirm
      the floor by running the harness on that kernel before writing it in.
- [ ] AGNOS ISO: chakshu is already planned as a T1 base-CLI component
      (`agnosticos/docs/development/iso-stage4-plan.md`).
- [ ] Keep the Bazaar `htop` / `btop` recipes available. Don't break user choice.
- [ ] Announce. The wording follows D3.

---

## Decisions before the freeze

Each decision becomes a breaking change once 1.0 is tagged. Recommendations are proposals; the
owner decides.

### The CLI — decided and implemented at v0.12.0

Each recommendation below was taken as written; `docs/cli-contract.md` records the outcome.

| # | Question | Before 0.12.0 | Recommendation (taken) |
|---|---|---|---|
| Q1 | `--watch`'s optional argument | swallows the next non-`-` token: `shu --watch 5` opens a file named `5` (exit 1) | A required-value `--watch-path P` beside a bare `--watch`. cmdit has no optional-value flags (its v2 backlog). `CHAKSHU_WATCH_PATH` keeps working through `watch_resolve_path`, not `cmdit_env` (see below) |
| Q2 | `--` end of options | `shu --` exits 2 | Accept it (free with cmdit) |
| Q3 | `--flag=value` | `--sort=cpu` exits 2 | Accept it (free with cmdit). htop's surface is all `--key=value` |
| Q4 | `-p` has no long form, and collides with `htop -p` and `btop -p` | `--plain` exits 2 | Add `--plain`; `-p` stays as its short form |
| Q5 | `--top` reads as a mode and collides with `top(1)` | — | Add `--rows`, keeping `--top` as a `cmdit_long_alias`. cmdit 1.3.6 added long aliases for flags; the old plan said only verbs had them |
| Q6 | `--explain` exits 0 when hoosh is unreachable | exit 0, prints the redacted context | Exit 1, still printing the context. `with_logs_smoke.py` needs only the printed context, so check it rather than the status |
| Q7 | Mode-incompatible flags | `-p --pid 1` exits 2, but `-p --rate 5`, `-p --color always`, `-p --theme light` and `--explain 1 -p` are silent no-ops | One rule: a flag given explicitly to a mode that ignores it exits 2. `cmdit_seen` makes "given explicitly" checkable. Note `--color` and `--theme` do apply to `--watch` |
| Q8 | AI-only flags in the lean `shu` | `--with-logs` exits **2** ("needs the AI build"); `--explain 1` exits **1** ("not in this build") | Both exit 2. The invocation is wrong for this binary, and that is known before any work starts |
| Q9 | A flag given twice | last wins (`--top 3 --top 4` → 4), undocumented | Keep last-wins, and document it. Use `cmdit_once` only if this is reversed |
| Q10 | Enum case | `--sort CPU` exits 2 | Keep it case-sensitive; `cmdit_enum_nocase` exists if wanted |

### The design contract (land in 0.13.0)

| # | Question | Recommendation |
|---|---|---|
| D1 | §8's CPU budget (< 0.5 % of a core at 1 Hz) names no workload, and its cost is linear in the process count | State it per process count, e.g. "< 0.5 % at 300 processes", and benchmark at that count |
| D2 | §8's "first TUI frame < 50 ms" has no definition: first bytes take 1.0 ms, the first complete frame ~109 ms (the 100 ms sample window) | Define it as first bytes, plus a separate row for the first complete frame stated as window + work, as the `-p` row already is |
| D3 | The milestone premise: "ship as the AGNOS default monitor" | See below |
| D4 | Versioning: the standards put binaries on CalVer; chakshu, like hapi, kii, owl and cyim, is SemVer with a CLI contract | Keep SemVer; record it in ADR 0002 |

### D3 — the AGNOS premise, re-read on 2026-10-31

The decision block this file carried until v0.11.1 listed three blockers. **Two are struck** and
the third is down to one field. On agnos 1.57.14 under QEMU (`agnos_qemu.py`, 35/35):

- the process table renders (`proclist` #99), with CPU%, MEM% and USER;
- the cpu, disk and net rates are real numbers;
- the TUI, the filter, the kill confirm and the `?` overlay all work;
- `shu-ai` builds for AGNOS.

What remains degraded on AGNOS: **load average reads `n/a`** (upstream; see below), and
`--with-logs` fails closed, because its path validator needs procfs.

⚠ **New constraint.** The first base ISO deliberately excludes the T4 AI layer, hoosh included
(`iso-stage4-plan.md`). So on the base image `shu-ai` would have no gateway, and "AI-augmented"
would not be true there.

**Recommendation:** ship 1.0 as the AGNOS default monitor with the lean `shu` in the T1 base image.
`shu-ai` joins the AI profile when hoosh ships. The announcement then reads "AGNOS ships its own
system monitor", plus "AI-augmented under the AI profile".

---

## Adopting cmdit 1.5.0 — done

Implemented at v0.12.0. The site map this section held is now code:
`src/cli_parse.cyr` registers every flag on cmdit, maps its errors onto chakshu's messages (the
flag named as typed, echoed text sanitized), and applies the mode rules; `src/cli.cyr` keeps
`print_help` / `print_version` (stdout, `Usage: shu`) and dispatches. Two choices worth knowing:

- **`CHAKSHU_WATCH_PATH` is not a `cmdit_env` fallback.** `cmdit_seen` counts an env-set value as
  seen, so `CHAKSHU_WATCH_PATH=… shu -p` would have tripped Q7's rule. The env fallback stays in
  `watch_resolve_path` (`src/watch_render.cyr`).
- **`--rate` stays a `cmdit_str`** validated by `parse_rate_mhz`: float flags are on cmdit's v2
  backlog.

---

## Improvements — optional, additive in any 1.x

None gates 1.0; each is allowed after the freeze by the contract's semver policy.

- **Shell completions** from `cmdit_completions(h, shell)` (bash, zsh, fish), behind a
  `--completions SHELL` flag or as files in the release tarball.
- **A man page.** Low value on AGNOS, which has no man viewer in any ISO tier, but expected by
  Linux packagers.
- **aarch64: the process table never renders.** `shu -p` on a Raspberry Pi 4 prints every header
  line through `net:`, then spins at 100 % CPU; under qemu-aarch64 it exits 2 at the same point.
  It is pre-existing (v0.10.3 behaves the same). The unit suite passes on the Pi (208/208), so the
  fault is in the per-pid sample → sort → render path. aarch64 is not a supported target, and its
  lean build is over the 768 KB target. Fix before adding it to the release matrix.
- **The lean build's ten `undefined function 'bayan_json_v_*'` warnings** are ai-hwaccel 2.5.5
  code that is never reached, and DCE removes it. They clear when ai-hwaccel stops referencing
  bayan without requiring it. Supplying `bayan-json` would add bytes only to silence a warning.

---

## Blocked upstream

- **Load average on AGNOS.** agnos `sysinfo` #35 is a 40-byte struct with no `loads[]`, so `load:`
  reads `n/a`. Filed upstream. (The process table, per-process CPU% / MEM%, and the disk and net
  counters that used to be listed here were all resolved by v0.10.1; see the CHANGELOG.)

---

## Post-v1 (deferred — do not pull into earlier milestones)

- Per-cgroup view, without becoming a container monitor.
- Historical replay: chakshu over a sakshi-backed time-series store.
- Mobile / dashboard frontends: same backend, a different render layer.
- Themed glyphs / a non-ASCII art mode (btop-style).
- Focus-panel depth: a thread list, fd enumeration, per-pid CPU% for the focused process. The
  focus panel already shows status, cmdline and the kill flow.
- A plugin surface for custom panels.

---

## Completed milestones

Per-release detail is in the CHANGELOG.

| Milestone | Closed | |
|---|---|---|
| M0 Scaffold | v0.1.x | build, test, `--version` / `--help` |
| M1 Plain snapshot | v0.2.0 | `shu -p` |
| M2 Full TUI | v0.5.0 | on darshana; no termios or ANSI of chakshu's own |
| M2.5 mihi integration | v0.6.0 | identity probes, the GPU panel |
| M3 AI integration | v0.8.2 | `--explain`, the `?` overlay, `--watch`, `--with-logs`, the hoosh gate |
| M4 Polish + perf | v0.9.0 – v0.9.3 | §8 runtime targets, GPU depth, theming, AGNOS parity |
| AGNOS target | v0.9.3 – v0.10.1 | TUI, process table, CPU% / MEM%, disk and net rates on a real kernel |
| M5 v1.0 ship | *open* | this file |

---

## Standing constraints

These bind every release above; they are not work items.

- **No libc, no FFI, no ncurses**, in either binary. Both are static, pure-syscall, zero `NEEDED`
  (since v0.9.7).
- **AI is opt-in at the binary level.** The lean `shu` cannot reach the network at all; enforced in
  CI.
- **Privacy:** prompts carry only what the user can already see in the TUI. No `/home` contents, no
  environment variables, no unredacted cmdline.
- **Version bumps at milestone close, not per feature**, and always the owner's call. Patches
  inside a minor are additive or corrective only.
