# chakshu — the v1.0 CLI contract

**Status: settled at v0.12.0, freezes at 1.0.0.** Every question this document used to end with was
decided at v0.12.0, when the parser moved onto cmdit 1.5.0; the answers are recorded at the end.
Until the 1.0 tag a change here is still free; after it, the semver policy below applies.

This document exists because chakshu ships a **binary**, not a library. The ecosystem's v1.0 bar
asks for "public API frozen and documented"; for a binary that means the **command surface** — every
flag's argument shape, the exit-code matrix, the stdout/stderr contract, and the rule for what forces
a v2. Precedent: `hapi/docs/development/release-notes/1.0.0.md`.

`docs/design-spec.md` §7 describes the same surface but is a *design* document; where the two
disagree, `shu --help` is the truth and both docs are wrong.

---

## What freezes at v1.0

1. **The command surface.** Every flag's spelling and argument shape below. New flags may land in
   v1.x as additive features; existing flags may not change shape without a v2.
2. **The exit-code matrix.** A caller may branch on these.
3. **`-p`'s line shape.** Plain mode is explicitly pipe-safe (design-spec §2.2, "`-p` is sacred for
   pipes"), so its field order and line prefixes are part of the contract.

## What does NOT freeze

- **TUI layout, colour and key hints.** These are presentation and change freely. The *key
  bindings* below are contract; where a hint is drawn is not.
- **Exact numeric formatting** beyond the documented units — e.g. whether a rate prints `1 MiB/s` or
  `1.0 MiB/s`.
- **The AI prompt text** sent to hoosh. It is an internal detail of `shu-ai` and the redaction rules
  that govern it are a *security* contract (`docs/audit/`), not a CLI one.
- **Anything in `shu-ai` that requires a live gateway.** The transport is not a stable interface.

---

## Modes

Exactly one mode runs per invocation.

| Mode | Selected by |
|---|---|
| help | `-h`, `--help` |
| version | `-V`, `--version` |
| explain | `--explain <PID>` (`shu-ai`) |
| watch | `--watch` |
| plain | `-p`, `--plain` |
| TUI | *(default, no mode flag)* |

**Two mode flags together are a usage error** (exit 2): `--explain` with `-p` or `--watch`, and
`--watch` with `-p`. So is a flag the chosen mode does not use (see "Applies to" below) — never a
silent no-op. `--help` and `--version` win over all of that, but **not** over a malformed command
line: the whole argv is read first, so `--help --bogus` and `--help --rate 99` exit 2, while
`--help -p --rate 5` prints help.

## Flags

| Flag | Argument | Default | Applies to |
|---|---|---|---|
| `-p`, `--plain` | — | off | selects plain |
| `--sort` | `cpu\|mem\|pid\|name\|user` | `cpu` | plain, TUI |
| `--rows` (alias `--top`) | integer ≥ 1 | `10` | plain, TUI |
| `--rate` | decimal Hz, `0.2`–`10` | `1` | TUI, watch |
| `--color` | `auto\|always\|never` | `auto` | TUI, watch |
| `--theme` | `dark\|light\|auto` | `dark` | TUI, watch |
| `--pid` | integer ≥ 1, must exist | — | TUI |
| `--explain` | integer ≥ 1 | — | selects explain (`shu-ai`) |
| `--watch` | — | off | selects watch |
| `--watch-path` | path | `$CHAKSHU_WATCH_PATH`, else `/var/log/aegis/events.jsonl` | watch |
| `--with-logs` | — | off | TUI, explain (`shu-ai`) |
| `-h`, `--help` | — | — | — |
| `-V`, `--version` | — | — | — |

**Argument syntax.**

- A value follows its flag (`--sort mem`) or is attached with `=` (`--sort=mem`).
- A separate value that looks like a flag is refused: `--sort --rows 5` is "`--sort` requires a
  value", not a sort key of `--rows`. A negative number is still a value (`--pid -5` is out of
  range, not missing), and an attached value is taken as written (`--watch-path=-odd`).
- `--` ends the options. chakshu takes **no positional argument**, so anything after `--`, or any
  bare word, is "unexpected argument" (exit 2).
- A flag given twice keeps its **last** value (`--rows 3 --rows 4` is 4), getopt's convention.
- Enum values are **case-sensitive** (`--sort CPU` exits 2).
- Integers are strict: `--rows 5x` and a value past the 64-bit range are refused, never read as a
  prefix or wrapped.
- Short flags do not bundle (`-hV` is an unknown flag).

`--rate` accepts up to three decimal places; a fourth and beyond is below millihertz resolution and
is ignored rather than rejected (`1.0001` = `1`).

## Exit codes

| Code | Meaning |
|---|---|
| `0` | success |
| `1` | runtime failure — a required source was unreadable, a mode could not run |
| `2` | usage error — unknown flag, missing argument, out-of-range or malformed value |

⚠ **Every mode validates the whole command line.** `shu-ai --explain 1 --bogusflag` exits `2`, the
same as `-p --bogusflag`. Until v0.9.4 `--explain` was the one path that did not, and exited `0`.

⚠ `--explain` exits **0 only when the model answered**. If hoosh is unreachable or its reply is
unusable, it still prints the redacted context it would have sent — that is what makes the prompt
inspectable offline, and `tests/with_logs_smoke.py` reads it — and then exits **1** (since v0.12.0;
it exited 0 before).

⚠ **The AI-only flags on the lean `shu`** — `--explain` and `--with-logs` — are usage errors,
exit **2**, with a message naming `shu-ai`. (Until v0.12.0 `--explain` exited 1 there.)

## Output streams

- **stdout** — all data. `-p` writes nothing else, so it pipes cleanly.
- **stderr** — diagnostics only, always `chakshu: <reason>`, one per line (design-spec §9).
- `-p` writing anything to stderr on a successful run is a defect, and `scripts/smoke.sh` gates it.

## `-p` line contract

Fixed order. Optional lines are marked; everything else always appears.

```
host: <hostname>  up: <Nd HH:MM>  load: <l1 l5 l15>|n/a
kern: <kernel>  distro: <distro>
proc: <cpu model> (<N> cores)
gpu:  <name> (PCI <vendor>:<device>)[  busy <N>%  vram <U>/<T> MiB  <N>°C]   (optional)
mem:  <U> MiB used / <T> MiB total
      buff <N> MiB / cache <N> MiB
swap: <U> MiB used / <T> MiB total | none configured
cpu:  <N>%   disk: rd <rate> wr <rate>   net: rx <rate> tx <rate>
core: <N> <N> ...                                                            (one field per core)
disk: <dev> rd <rate> wr <rate>  ...                                         (whole disks only)
net:  <iface> rx <rate> tx <rate>  ...                                       (excludes lo)
    PID USER      S  CPU%  MEM% CMD
<rows>
```

The PID field is **7 wide**, right-aligned: the width of Linux's largest possible pid
(`PID_MAX_LIMIT`, 4,194,304 on 64-bit), so USER starts in column 9 on the header and on every row.
It was 6 wide until v0.12.1, and a pid past 999,999 pushed its row one column right. USER is 9
wide, clipped (never widened) and never cut inside a UTF-8 character. **No line above the table
ends in whitespace**; the `disk:` and `net:` lines did until v0.12.1. A table row ends with the
process's own cmdline, which may.

Where a source is unreadable the field reads `n/a` rather than `0` — a measured zero and an
unmeasurable value are different facts. AGNOS has no procfs: there the table and the cpu, disk and
net rates come from agnos syscalls (`proclist` #99 and its counters, since v0.9.8 – v0.10.1), and
`load:` reads `n/a` because agnos exposes no load average.

## TUI key bindings

| Key | Action |
|---|---|
| `q` | quit |
| `↑` `↓` | move selection |
| `s` | cycle sort: cpu → mem → pid → name → user → cpu |
| `f` | filter — type to narrow, `Enter` applies, `Esc` clears |
| `k` | kill selected (confirm required) |
| `?` | AI explanation overlay (`shu-ai`; `Esc`/`q` cancels) |

⚠ `Esc` clears the filter and cancels the overlay. It does **not** quit.

## Environment

| Variable | Used by | Purpose |
|---|---|---|
| `CHAKSHU_WATCH_PATH` | both | the `--watch` log when `--watch-path` is not given |
| `CHAKSHU_LOG_PATH` | `shu-ai` | `--with-logs` source; validated — regular files only, never `/proc`, `/sys`, `/dev`, `/home` |
| `CHAKSHU_HOOSH_URL` | `shu-ai` | gateway endpoint |
| `CHAKSHU_MODEL` | `shu-ai` | model name |
| `CHAKSHU_HOOSH_TOKEN` | `shu-ai` | `Authorization: Bearer` |
| `NO_COLOR`, `TERM`, `COLORFGBG` | both | consulted by `--color auto` / `--theme auto` |

## Semver policy

- **v2 required:** removing a flag; changing a flag's argument shape or its default; changing an
  exit code's meaning; reordering or removing a `-p` line.
- **v1.x allowed:** new flags; new optional `-p` lines *appended within their section*; new TUI keys;
  wording changes to diagnostics; any TUI presentation change.
- **Patch:** behaviour that was already documented here but implemented incorrectly.

---

## Decisions settled at v0.12.0

The questions this document ended with until v0.12.0, and their answers. The reasoning is in
[`development/roadmap.md`](development/roadmap.md#decisions-before-the-freeze); the parser that
implements them is `src/cli_parse.cyr`, unit-tested in `tests/chakshu.tcyr`.

| # | Question | Decision |
|---|---|---|
| 1 | `--watch [PATH]` swallowed the next non-`-` token (`shu --watch 5` opened a file named `5`) | `--watch` takes no argument; the path is `--watch-path PATH`. `--watch PATH` is exit 2 with a message naming `--watch-path` |
| 2 | No `--` | `--` ends the options |
| 3 | No `--flag=value` | Accepted for every value flag |
| 4 | `-p` had no long form | `--plain` |
| 5 | `--top` reads as a mode | `--rows`; `--top` stays as an alias |
| 6 | `--explain` exited 0 when hoosh could not answer | Exits 1, after printing the context |
| 7 | Mode-incompatible flags were sometimes errors, sometimes silent no-ops | Always an error (exit 2) |
| 8 | On the lean build `--with-logs` exited 2, `--explain` 1 | Both exit 2 |
| 9 | A repeated flag's behaviour was undocumented | Last value wins |
| 10 | Enum case was undocumented | Case-sensitive |
