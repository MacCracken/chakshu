# Contributing to chakshu

Thanks for wanting to help `chakshu` see clearly.

## Prerequisites

- Cyrius toolchain 5.9.32+ (`cyrius` on `$PATH`) — <https://github.com/MacCracken/cyrius>
- A POSIX-ish host with `/proc` (Linux primary). `chakshu` reads `/proc` directly via syscalls; the kernel ABI is the contract, not procps.

## Development Workflow

1. Fork and clone
2. `cyrius deps` — populates `lib/` from `cyrius.cyml [deps]`. `lib/` is gitignored, so this step is mandatory after a fresh checkout. The toolchain pin in `cyrius.cyml [package].cyrius` is the only authority for the Cyrius version — never create a `.cyrius-toolchain` file.
3. Branch from `main`
4. Make your change
5. `cyrius test tests/chakshu.tcyr` before opening a PR
6. Reference the milestone (see [docs/development/roadmap.md](docs/development/roadmap.md)) your change belongs to

## Build / Test

```sh
cyrius deps
cyrius build src/main.cyr build/shu
cyrius test  tests/chakshu.tcyr
./build/shu --version
```

There is no Makefile — `cyrius <subcommand>` is the whole build system. Never shell out to `cc5` directly.

## Scope Discipline

`chakshu` is a system monitor. Not a process killer with extra steps, not a logging viewer (sakshi owns that), not a service manager (kybernet owns that). The [design spec](docs/design-spec.md) §1 enumerates out-of-scope items — read it before proposing a feature in those areas.

The [roadmap](docs/development/roadmap.md) is the source of truth for milestone order. One milestone at a time; don't skip ahead. AI integration (M3) does not begin until parity (M2) is closed.

## Code Style

- Direct syscalls via `lib/syscalls` — no libc, no FFI
- Read `/proc` and `/sys` as plain text; parse with `str` + `string` helpers
- Errors go to stderr as `chakshu: <reason>` — stdout is reserved for the TUI / piped output
- Prefer the Cyrius stdlib over reinventing primitives; if a primitive is missing, file an issue upstream at `cyrius/docs/development/issues/` rather than forking one locally

## Testing

- `tests/chakshu.tcyr` for unit tests
- Smoke script lands at M0 close; until then, run `./build/shu --version` and `./build/shu --help` manually
- TUI features need a real terminal — type checks can't catch ANSI regressions

## License

GPL-3.0-only. By contributing you agree your work is licensed under the same.
