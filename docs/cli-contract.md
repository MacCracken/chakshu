# chakshu — the v1.0 CLI contract

**Status: proposed for the v1.0 freeze. Not frozen yet** — the open questions are listed at the
end, and each must be settled *before* a 1.0 tag, because after it every one of them is a breaking
change.

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

Exactly one mode runs per invocation. Precedence, highest first:

| Order | Mode | Selected by |
|---|---|---|
| 1 | help | `-h`, `--help` |
| 2 | version | `-V`, `--version` |
| 3 | explain | `--explain <PID>` |
| 4 | watch | `--watch [PATH]` |
| 5 | plain | `-p` |
| 6 | TUI | *(default, no mode flag)* |

⚠ `--help` and `--version` win over every other mode. That is conventional, and it changed at
v0.9.4 — before then `--explain` returned from inside the argument loop and beat them.

## Flags

| Flag | Argument | Default | Applies to |
|---|---|---|---|
| `-p` | — | off | — |
| `--sort` | `cpu\|mem\|pid\|name\|user` | `cpu` | plain, TUI |
| `--top` | integer ≥ 1 | `10` | plain, TUI |
| `--rate` | decimal Hz, `0.2`–`10` | `1` | TUI, watch |
| `--color` | `auto\|always\|never` | `auto` | TUI only |
| `--theme` | `dark\|light\|auto` | `dark` | TUI only |
| `--pid` | integer ≥ 1, must exist | — | TUI only |
| `--explain` | integer ≥ 1 | — | `shu-ai` only |
| `--watch` | optional path | `$CHAKSHU_WATCH_PATH`, else `/var/log/aegis/events.jsonl` | — |
| `--with-logs` | — | off | `shu-ai` only |
| `-h`, `--help` | — | — | — |
| `-V`, `--version` | — | — | — |

**Argument form is `--flag value`, space-separated.** `--flag=value` is **not** accepted — see the
open questions.

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

⚠ `--explain` against an unreachable gateway exits **0**, printing the redacted context it would have
sent. That is deliberate — it is what makes the prompt inspectable offline, and
`tests/with_logs_smoke.py` depends on it — but it means **exit 0 does not imply the model answered**.
Flagged as an open question below.

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

Where a source is unreadable the field reads `n/a` rather than `0` — a measured zero and an
unmeasurable value are different facts. On a kernel with no procfs the `cpu:` line is
`cpu:  n/a   disk: n/a   net: n/a` and the table renders its header with no rows.

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
| `CHAKSHU_WATCH_PATH` | both | default `--watch` path |
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

## ⛔ Open questions — settle before the freeze

1. **`--watch`'s optional argument.** It swallows the next non-`-` token, so `shu --watch 5` opens a
   file named `5`, and a path beginning with `-` is unreachable. It is the only optional-argument
   flag in the surface. Options: make the argument required, or add `--watch-path P`.
2. **No `--` end-of-options.** `shu --` exits 2. This is the standard escape hatch and the thing that
   would make (1) survivable.
3. **`--flag=value` unsupported.** htop's surface is `--sort-key=`, `--delay=`, `--user=`, `--pid=`.
   Adding `=` later is additive so it is not a semver trap — but the first command a migrating htop
   user types fails with "unknown flag".
4. **`-p` has no long form,** and collides with both incumbents (`htop -p` = pid list, `btop -p` =
   preset). Adding `--plain` now makes `-p` an alias that could later be deprecated, rather than a
   name we are stuck with.
5. **`--top` reads as a mode** and collides with `top(1)`. `-n` / `--rows` / `--limit` is the
   conventional spelling for a row count.
6. **`--explain` exits 0 when the gateway is unreachable.** Inspectable-offline is a real property,
   but a caller cannot distinguish "answered" from "could not reach hoosh" by exit code alone.
7. **Mode-incompatible flags are handled inconsistently.** `-p --pid 1` is a hard error; `-p --rate 5`,
   `-p --color always` and `-p --theme light` are silent no-ops. Pick one policy — v1.0 locks
   whichever ships.
