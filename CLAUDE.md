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

```bash
cyrius deps                                          # populate lib/ from cyrius.cyml
cyrius build src/main.cyr build/shu                  # build
cyrius test  tests/chakshu.tcyr                      # tests
./build/shu --version
```

## Architecture

Module responsibilities (planned — not all files exist yet at v0.1.0):

- **`main.cyr`** — entry, CLI parsing, mode dispatch (TUI vs `-p` plain snapshot vs `--explain`)
- **`proc/` (planned)** — `/proc` parsers (`/proc/[pid]/stat`, `/proc/[pid]/status`, `/proc/meminfo`, `/proc/stat`, `/proc/diskstats`, `/proc/net/dev`)
- **`tui/` (planned)** — render loop, panel layout (process table, CPU graph, memory bar, disk/net rates), termios raw mode, key bindings
- **`ai/` (planned, M3+)** — daimon JSON-RPC client (sandhi), prompt assembly from `/proc` snapshot + recent log context, hoosh streaming responses

## Key Constraints

- **No libc, no FFI.** `/proc` is plain text; the kernel ABI is the contract.
- **No external deps until justified.** Stdlib + sandhi (M3) + niyama (M3) are the planned envelope. No ncurses, no procps, no sysinfo.
- **AI is opt-in.** `--explain` and `?` key trigger LLM calls; the TUI never makes a network/IPC call without an explicit user action.
- **Privacy.** When asking daimon "why is process X spiking", send only the data the user can already see in the TUI. No /home contents, no env vars, no command-line args without redaction.

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
