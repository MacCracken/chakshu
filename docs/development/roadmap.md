# chakshu — Roadmap

> **Forward-looking only.** Everything shipped lives in [`CHANGELOG.md`](../../CHANGELOG.md);
> current volatile state (version, pins, sizes, test counts) lives in
> [`state.md`](state.md). This file answers one question: *what is left to reach
> v1.0, and in which release does it land?*
>
> **Current: v0.11.0.** | **Last Updated**: 2026-10-12

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
| ~~0.9.9~~ | ~~AGNOS telemetry: MEM%~~ | **shipped 2026-09-03.** agnos 1.56.59 closed chakshu's telemetry filing in full. MEM% ships from `proclist` rss pages. CPU% and the disk rate were each **built or read, measured, and declined** — halt-inclusive ticks and a block band that misses the mainline I/O path would both have been confident wrong numbers. Cyrius 6.5.45 |
| ~~0.10.0~~ | ~~AGNOS CPU%; Cyrius 6.6.0~~ | **shipped 2026-09-07.** agnos 1.56.60 added the halt exclusion chakshu filed for, so the CPU% column backed out at v0.9.9 now ships honestly. Cyrius 6.6.0 is a breaking minor and the deps moved with it. Lean artifact down to **399 KB** (DCE prunes again) |
| ~~0.10.1~~ | ~~AGNOS disk + net rates~~ | **shipped 2026-09-07.** Both were declined at v0.9.9 for untrustworthy counters and both were fixed upstream in response; guarded on LBA size and NIC presence, and verified with agnos's counter-MOVED oracle |
| ~~0.10.2~~ | ~~pid-0 sentinel fix; multi-core harness~~ | **shipped 2026-09-08.** Found a fabricated 59% CPU% by running the harness at `-smp 4` for the first time — the baseline map was keyed by pid and 0 is the hashmap empty sentinel. Filed with cyrius; nameless-row filter dropped now agnos 1.57.1 fixed the idle park. Cyrius 6.6.1 |
| ~~0.10.3~~ | ~~Cyrius 6.6.2~~ | **shipped 2026-09-11.** Toolchain patch only; no source change |
| ~~0.11.0~~ | ~~Cyrius 6.7.9; darshana 1.3.0; the darshana survey's defects~~ | **shipped 2026-10-12.** The 6.7 language minor needed no source change; it surfaced three build-config repairs (the `ai/` manifest's `${file:../VERSION}`, nolibc.cyr's refusals becoming redefinitions, niyama/bayan tags off the toolchain folds). darshana 1.3.0 replaced the hand-rolled SGR, TCIFLUSH, siginfo read and winsize guard; fixed C1 controls in every untrusted-text path, the aarch64 epoll tag, `shu \| head` leaving the terminal raw, the teardown order, and `?` killing shu on AGNOS |
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

## Found at v0.11.0, not scheduled

- [ ] **aarch64: the process table never renders.** `shu -p` on a Raspberry Pi 4 (Linux
      7.0.0-1020-raspi) prints every header line through `net:` and then spins at 100% CPU
      until killed; under qemu-aarch64 the same binary exits 2 at the same point; the TUI hangs
      mid-way through its first frame. **Pre-existing**: the v0.10.3 tree built with cyrius
      6.6.2 behaves identically, so it is not a 6.7 regression. `dir_list_into` over `/proc` and
      `map_u64_*` work on aarch64 in isolation, and the unit suite passes on the Pi itself
      (208/208), so the fault is somewhere in the per-pid sample → sort → render path. aarch64 is
      not a supported target (state.md), so this is recorded rather than scheduled — but it blocks
      proving the v0.11.0 epoll-tag fix end to end on ARM. That fix is proven by the unit suite on
      the Pi instead: with the old `+4` read the tag comes back as `0x25A5A5A5A`, not 2.
- [ ] **Move mihi / ai-hwaccel when mihi pins a 6.7-built ai-hwaccel.** ai-hwaccel 2.3.22
      calls `bayan_json_v_obj_get`, which the 6.7.9 bayan fold marks `#deprecated` — three
      warnings in the `shu-ai` build — and its optional-bayan code is what leaves seven
      `undefined function 'bayan_json_v_*'` warnings in the lean build. Both are dependency code
      and both clear at a dep bump; the tracking rule (ai-hwaccel follows mihi's own pin) means
      mihi moves first. mihi 1.2.7 still pins 2.3.22.

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

---

## Adopting cmdit (CLI parsing)

This is demand-gated, not a forced sweep, but the **timing** matters. v1.0 criterion 1 freezes the
CLI (`docs/cli-contract.md`). Before that, syntax changes cost nothing; after it, each one is a
semver event. chakshu is a Tier-3 candidate in the 2026-06-25 ecosystem CLI review
(`agnosticos/docs/development/planning/cmdit.md`).

**What is hand-rolled.** `chakshu_main` (`src/cli.cyr:88-392`) is shared by both entries
(`src/main.cyr`, `ai/main.cyr`). It already has cmdit's shape: accumulate, then dispatch. Underneath
it is `args_init`/`argc`/`argv` + `streq`, values must be space-separated, there is no `--`, and
any non-flag token is reported as `unknown flag` (`:345`). The exit codes 0/1/2 (`:13-15`) are
exactly `CMDIT_EXIT_OK/RUN/USAGE`. Help (`:22-61`) and version (`:17-20`) go to **stdout**. Every
error is a custom `chakshu: …` line on stderr that echoes the bad token or value (`:81-86`,
`:167-169`, `:235-237`, `:254-256`).

**Site → cmdit.**

- [ ] `cmdit_new("chakshu")`. The automatic `-h`/`--help` and `-V`/`--version` match exactly, and
      so does help-before-version (`:349-350`). Keep `CHAKSHU_VERSION` at `:10`, because
      `.github/workflows/ci.yml:474`, `release.yml:55` and `scripts/check.sh:191` grep for it there.
- [ ] `-p` → `cmdit_bool(h, 112, 0, …)`, since cmdit allows a short-only flag. The `--plain` from
      open question 4 is the same call with a long name.
- [ ] `--sort cpu|mem|pid|name|user` (`:155-174`) → `cmdit_enum`; the index is
      `SORT_CPU..SORT_USER` (`src/processes.cyr:43-47`). `--theme dark|light|auto` (`:225-242`) is
      0/1/2 the same way. `--color auto|always|never` (`:244-261`) stores 1/2/0, so it needs a
      small mapping table.
- [ ] `--top`, `--pid` and `--explain` (`:203-216`, `:267-276`, `:298-307`) → `cmdit_int` +
      `cmdit_range(h, f, 1, <i64 max>)`. Stdlib `atoi` accepts `5x` as 5 and wraps on overflow,
      and cmdit rejects both. Move the `--pid` `/proc` probe (`:277-288`, exit 1) to after
      help/version dispatch. Then `--pid 99999 --help` prints help, following the contract's
      "help wins" rule.
- [ ] `--with-logs` → `cmdit_bool`. The pre-scan (`:101-113`) exists only for order independence,
      and reading the flag after the parse already gives that. In the lean build,
      `shu --with-logs --bogus` then reports the unknown flag instead of "needs the AI build"
      (both exit 2).
- [ ] Mode precedence (`:348-391`) and the `--watch` × `-p`/`--pid` and `-p` × `--pid` rejections
      (`:366-383`) stay as they are. The comment at `:120-122` says "the last one wins", but the
      code implements a fixed precedence.

**Gaps.**

- **`--watch [PATH]` (`:328-339`) has no cmdit equivalent**, because optional-value flags are in the
  v2 backlog. This is contract open question 1, so settle it first. Both options the contract
  names can be expressed in cmdit:
  - **`--watch-path P`**: `cmdit_env(h, f, "CHAKSHU_WATCH_PATH")` reproduces the CLI → env →
    default order of `src/watch_render.cyr:15-19`.
  - **A required argument**: a plain `cmdit_str`.
  - **Stopgap closest to today**: `--watch` as a bool plus at most one positional
    (`cmdit_require_positionals_max(h, 1)`), rejected unless `--watch` is set. It is looser than
    today, because PATH no longer has to follow `--watch` directly.
- `--rate` is a float flag (v2 backlog): fixed-point milli-Hz, 0.2–10, parsed in
  `src/rate.cyr:33`. It stays `cmdit_str` + `parse_rate_mhz` + the bounds at `:188-195`, and does
  not block adoption.
- Open question 5, renaming `--top` but keeping it as an alias, would take two registrations,
  because cmdit only supports long aliases for verbs.
- `NO_COLOR`/`TERM`/`COLORFGBG` (`src/tui.cyr:367-386`) drive `auto` resolution and are not
  fallbacks for any flag. `CHAKSHU_HOOSH_*`/`CHAKSHU_MODEL`/`CHAKSHU_LOG_PATH`
  (`src/ai.cyr:850`, `:960`) are read from the environment only. All of these stay caller-side.
  The `CHAKSHU_*` allowlist at `check.sh:177` scans the AI source, not `lib/`, so cmdit's own
  `getenv` does not trip it.
- Adopting cmdit also answers open questions 2 and 3: `--` and `--flag=value` start working. The
  contract counts both as additive. Its line "`--flag=value` is **not** accepted" must change in the
  same commit.

**Output identity.** Keep `print_help`/`print_version` and the custom messages, and branch on
`cmdit_error(h)` + `cmdit_err_flag(h)`. `cmdit_help_flags` writes to stderr. The contract puts help
on stdout, and `scripts/smoke.sh:53-58` captures it there. `cmdit_help` would print `Usage:
chakshu`, while the binary is `shu`. `cmdit_print_error` echoes no token, and cmdit does not store
the unknown token or the rejected value. So the `'foo'`/`--bogus` echoes must come from
`cmdit_raw_argv`.

**Manifests — both of them.** The AI build has its own manifest (`ai/cyrius.cyml`). Neither manifest
declares stdlib `flags`, and both already carry `"args"` and `"io"`. kii and anuenue already pin
cmdit under cyrius 6.7.9. Add this to `cyrius.cyml` **and** `ai/cyrius.cyml`:

    [deps.cmdit]
    git = "https://github.com/MacCracken/cmdit.git"
    tag = "1.3.0"
    modules = ["dist/cmdit.cyr"]

**Tests and gates.** No unit test drives `chakshu_main`. `tests/chakshu.tcyr` includes modules
directly (`:4-6`). Its `parse_rate_mhz` group (`:601-621`) stays, and `:58-59` are cosmetic `streq`
checks. The bar is `scripts/smoke.sh`, which `scripts/check.sh` runs against `shu`, `shu-ai` and the
DCE'd `shu` (`:76`, `:89`, `:122`). It checks help parity on stdout (`:53-58`), that an unknown flag
exits 2 with stderr only (`:76-82`), build-aware `--with-logs` (`:96-108`), `--watch` combinations
(`:161-168`), `--top` (`:262-273`), `--sort foo` with "unknown key" (`:298-304`) and the rejection
matrix (`:309-328`). The PTY gates drive flags too: `tests/integration_smoke.py:167`, `:246`, `:406`,
`:593-594`, `:620`, `tests/with_logs_smoke.py:124-125` and `tests/hoosh_stub_smoke.py:93`.

- [ ] Identity bar: byte-compare stdout, stderr and exit status before and after, for every
      invocation above plus `--bogus`, `foo`, `--sort` (no value), `--top 5x` and
      `--pid 99999 --help`. Each changed line must be either intended, and recorded in the CHANGELOG
      and `docs/cli-contract.md`, or fixed.

References: cmdit `README.md` (API reference), `docs/adr/0001-flag-modifiers.md` (scope),
`docs/development/roadmap.md` (v2 backlog: optional-value and float flags). Worked examples: kii,
anuenue (custom help framing), dig (Tier-3).
