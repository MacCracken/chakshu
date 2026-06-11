# chakshu — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (version, binary size,
> line counts, milestone status) lives in
> [`docs/development/state.md`](docs/development/state.md). Do not inline
> state here.

## Project Identity

**chakshu** — Sanskrit चक्षु (*chakṣu*, "the eye"). An AI-augmented system monitor for AGNOS / Cyrius. Binary: `shu` — **S**ystem **H**ealth **U**tility, a contraction of *chak**shu***. See [`docs/adr/0001-binary-name-shu.md`](docs/adr/0001-binary-name-shu.md).

- **Type**: Binary
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md)

## Goal

Replace `htop`/`btop` as the AGNOS default system monitor, then surpass them with AI integration. The substantive case for first-party: AGNOS already ships the LLM gateway (`hoosh`), agent runtime (`daimon`), threat detector (`phylax`), and audit chain (`libro`). A Cyrius-native monitor is the natural panel that surfaces them in the moment a user asks "what is happening on this machine?"

## Quick Start

Two binaries (see [`docs/development/state.md`](docs/development/state.md) for the lean/AI split rationale):

```bash
# Lean monitor — default `shu` (no AI deps)
cyrius deps                                          # populate lib/ from cyrius.cyml
cyrius build src/main.cyr build/shu                  # build
cyrius test  tests/chakshu.tcyr                      # monitor tests (57)
./build/shu --version

# AI build — `shu-ai` (ai/ sub-project; shares ../src/* so needs the env flag)
cd ai && cyrius deps
CYRIUS_ALLOW_PARENT_INCLUDES=1 cyrius build main.cyr build/shu-ai
CYRIUS_ALLOW_PARENT_INCLUDES=1 cyrius test tests/chakshu-ai.tcyr   # AI tests (13)
```

## Architecture

Shared monitor source (`src/`), compiled into BOTH builds:

- **`cli.cyr`** — shared CLI: `chakshu_main()`, version/help, arg parsing, mode dispatch. `CHAKSHU_VERSION` lives here.
- **`proc.cyr`** — `/proc` parsers (`/proc/[pid]/stat`+`status`, `meminfo`, `stat`, `diskstats`, `net/dev`)
- **`processes.cyr`** — process table model, per-pid CPU%/MEM%, sort
- **`snapshot.cyr`** — `-p` plain-mode render; **`tui.cyr`** — TUI render loop, panels, key bindings (via `darshana`)
- Identity/static facts (hostname/kernel/distro/cpu/mem/gpu) come from **`mihi`** (`lib/mihi.cyr`).

Build-specific entries + AI module:

- **`src/main.cyr`** (lean entry) → includes `src/ai_stub.cyr` (a no-op `ai_explain`/`ai_tui_explain` pointing at `shu-ai`). Builds `shu`.
- **`ai/main.cyr`** (AI entry, in the `ai/` sub-project) → includes the real **`src/ai.cyr`** + the `sandhi`/`niyama` dep chain. Builds `shu-ai`.
- **`src/ai.cyr`** — secret redaction (`niyama` re2), prompt assembly from the `/proc` snapshot, and the hoosh HTTP client (`sandhi`): `--explain` one-shot + the streamed `?` overlay.

## Key Constraints

- **No libc, no FFI — in the lean `shu`.** `/proc` is plain text; the kernel ABI is the contract. The default monitor stays pure. **Exception (documented):** `shu-ai` pulls `sandhi`, whose HTTP/TLS client dlopens libc (`getaddrinfo`/libssl), so the AI build is *not* a pure no-libc binary and its live path only runs on a libc host. Keep the AI deps out of the root manifest (`cyrius.cyml`) — they live only in `ai/cyrius.cyml`.
- **No external deps until justified.** AI envelope: `sandhi` (hoosh HTTP transport) + `niyama` (re2 redaction), both confined to the `ai/` build. No ncurses, no procps, no sysinfo.
- **AI is opt-in — at the binary level.** Only `shu-ai` makes LLM calls, and only on `--explain` / the `?` key. The lean `shu` cannot reach the network at all.
- **Privacy.** When asking hoosh "why is process X spiking", send only the data the user can already see in the TUI. No /home contents, no env vars, no command-line args without redaction (secret patterns stripped via niyama re2).

## Development Process

### Work Loop

1. Pick the next item from `docs/development/roadmap.md`
2. Implement
3. `cyrius build` → `cyrius test`
4. Manual TUI check on a real terminal — type checks can't catch ANSI regressions or termios state leaks
5. Update `CHANGELOG.md`
6. Update `docs/development/state.md` if version, binary size, deps, or milestone status changed
7. Version bump only at milestone close, not per feature

### Cyrius Idioms

- Programs call `main()` at top level — Cyrius does not auto-invoke `fn main()`:
  ```cyrius
  fn main() { ... return 0; }
  var exit_code = main();
  syscall(60, exit_code);
  ```
- Study `cyrius/programs/*.cyr` and the `owl` repo before writing new code — both are working Cyrius binaries with patterns worth copying.
- Never use raw `cat file | cc5` — always `cyrius build`.

## Don't

- Don't add features beyond the current milestone
- Don't introduce libc / FFI / ncurses
- Don't read `/home`, command-line args (without redaction), or env vars when assembling AI prompts
- Don't commit or push (the user handles git operations)
