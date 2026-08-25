# Manual TTY checks

Everything that can be automated **is** — `tests/integration_smoke.py` drives 14
scenarios under a real pseudo-terminal, and CI runs it on every push. This file
lists only the checks that still need human eyes, and says *why* each one resists
automation. If you find a way to automate one, delete it from here.

Run these against a real terminal emulator before a minor release (`0.x.0`), and
after any change to `src/tui.cyr`'s render path. CLAUDE.md's work loop already
calls for a manual TUI check after TUI changes — this is that checklist.

```bash
cyrius build src/main.cyr build/shu && ./build/shu
```

**The AGNOS target is not on this list.** It has its own automated harness —
`tests/agnos_qemu.py` boots the `--agnos` build on a real AGNOS kernel under QEMU
and drives it with `sendkey`. Add AGNOS checks there, not here.

---

## 1. Colour actually looks right

**Why not automated:** the PTY suite asserts escape *sequences* are present, which
proves bytes were emitted — not that the result is legible. Contrast, and whether
the severity bands read correctly against a real background, is a judgement.

- CPU%/MEM% shift green → yellow → red as a process gets busier. Start a CPU
  burner (`yes > /dev/null`) and watch its row cross the bands.
- Process states are distinguishable: `R` green, `D`/`T` yellow, `Z` red,
  `I` cyan (kernel idle threads — `[kworker/...]` rows).
- The selected row's reverse-video block does not swallow the text inside it.
- `--color=never` emits no colour. Note it *does* still emit reverse video
  (`CSI 7m`/`CSI 0m`) for the selected row — that is deliberate, and is the only
  way selection is visible on a monochrome terminal. Colour absence, not escape
  absence, is the contract.
- `--theme light` on an actually-light terminal: the mid band (magenta) and idle
  state (blue) must be readable, and the pid column must not vanish. This is the
  half a byte-level test cannot judge — scenario 13 proves the *palette changed*,
  only your eyes can confirm it changed for the better.

## 2. Resize behaves under a real window manager

**Why not automated:** the suite sets a fixed 24×80 winsize via `TIOCSWINSZ`. A
real drag-resize produces a *stream* of SIGWINCH with intermediate geometries,
which is a different code path from one clean resize.

- Drag the window narrower and wider continuously. The header must not scroll off
  the top, and rows must re-clip rather than wrap.
- Shrink to very small (≈20 columns, ≈6 rows). The layout should degrade, not
  corrupt: no wrapped rows, no lost status line.
- Widen to very large (200+ columns). Long cmdlines should extend, not truncate at
  a stale width.
- Resize **while** the `?` overlay is open, and while the kill confirm is showing.

## 3. Terminal state is left clean

**Why not automated:** darshana's own PTY tests already assert termios is restored
byte-for-byte, so this is about the *emulator's* state — scrollback, alternate
screen, cursor visibility — which the PTY harness cannot observe.

After each exit path below, the shell prompt must return normally, the cursor must
be visible, and scrollback must contain what it did before `shu` started:

- `q` from Normal mode.
- `Ctrl-C`.
- `kill <pid>` from another terminal.
- `kill -9 <pid>` — this one *will* leave the terminal raw and in the alt screen,
  because SIGKILL cannot be handled. `reset` should recover it. Confirm nothing
  worse than that (this is expected, not a bug).
- Closing the terminal window outright (SIGHUP).

## 4. Wide/multi-byte characters

**Why not automated:** chakshu clips by *bytes*, not display columns. Asserting
correct behaviour needs a width table the lean build deliberately does not link.

- Run a process with CJK or emoji in its argv and watch its row at a narrow width.
  A clipped multi-byte glyph may render as a replacement character — acceptable.
  A row that *overflows its width and wraps* is not: it scrolls the header off.

## 5. `--watch` against a live producer

**Why not automated:** scenario 12 covers the panel with a fixture file. What it
cannot cover is a real aegis writing concurrently.

```bash
AEGIS_EVENT_LOG=/tmp/aegis.jsonl aegis &
./build/shu --watch /tmp/aegis.jsonl
```

- Events appear as they are written, without a restart.
- Rotating or truncating the file mid-watch does not produce garbage rows (the
  reader resets rather than splicing a stale offset).
- With no producer running, the panel shows an empty stream — not an error.

## 6. The `?` overlay against a real gateway

**Why not automated:** `tests/hoosh_stub_smoke.py` covers the transport with a stub
and is a hard CI gate. What it cannot judge is whether a *real* model answer is
readable in the overlay.

Needs `shu-ai` and a running hoosh:

- The streamed answer wraps sensibly and does not corrupt the frame.
- `Esc`/`q` cancels mid-stream and returns to the table cleanly.
- `kill <pid>` while the overlay is open still exits (regression guard for the
  v0.7.13 signal fix — scenario 11 covers it, but confirm with a real stream).
