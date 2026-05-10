#!/usr/bin/env python3
"""End-to-end smoke for chakshu's TUI.

Spawns shu under a real PTY (so tty_raw succeeds) and drives recorded
key-event sequences. Validates Slices A-F end-to-end:
    A — alt-screen entry, q/Ctrl-C exit, clean teardown
    C — render loop produces the expected lines
    E — sort cycle (`s`)
    E.5 — filter mode (`f` + typed text + Enter)
    F — kill key + cancel path (`k` then anything-but-y)

Patterned on cyim/tests/integration_smoke.py. Each "key event" is one
os.write call so multi-byte sequences (arrow keys → ESC [ A/B/C/D)
arrive atomically and chakshu's _tui_read_key sees them as one CSI
sequence rather than three separate bytes.

Run:
    python3 tests/integration_smoke.py [path/to/shu]
Default binary: ../build/shu relative to this file.
"""

import fcntl
import os
import pty
import select
import struct
import sys
import termios
import time

SHU_DEFAULT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "build", "shu"
)


def drive(key_events, args=None, timeout=5.0, shu_path=SHU_DEFAULT):
    """Spawn shu under a PTY, send key_events one-by-one, drain output,
    wait for exit. Returns (output_bytes, exit_code).

    key_events is a list of bytes; each element is sent as a single
    os.write call (so 3-byte arrow sequences land as one packet).
    A short pause after each write lets the input loop consume the
    bytes before the next event arrives.
    """
    if args is None:
        args = []

    pid, fd = pty.fork()
    if pid == 0:
        # Child — replace with shu. PTY is wired to stdin/stdout/stderr.
        os.execv(shu_path, [shu_path] + args)

    # Set the PTY size so chakshu's tty_winsize returns sensible
    # rows/cols. Without this, pty.fork() leaves the slave at 0x0
    # and chakshu's defensive default (24x80) kicks in — but we
    # want the test to exercise winsize-aware layout for real.
    # struct winsize: rows, cols, xpix, ypix (all u16).
    winsz = struct.pack("HHHH", 24, 80, 0, 0)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, winsz)

    # Parent — interleave writes (key events) with reads (output drain).
    deadline = time.time() + timeout
    sink = bytearray()
    next_event = 0

    # Initial settle: chakshu's first frame includes a 100ms sample
    # window. Sending the first key before that completes is fine
    # (the byte queues in the PTY buffer until epoll_wait reads it),
    # but a tiny delay here makes the substring-match assertions
    # below see the rendered headers consistently.
    time.sleep(0.15)

    while True:
        if time.time() > deadline:
            try:
                os.kill(pid, 9)
                os.waitpid(pid, 0)
            except OSError:
                pass
            raise TimeoutError(
                f"shu did not exit within {timeout}s; "
                f"sent {next_event}/{len(key_events)} events; "
                f"output so far ({len(sink)} bytes): {bytes(sink)[-300:]!r}"
            )

        # Reap if exited.
        try:
            wpid, status = os.waitpid(pid, os.WNOHANG)
            if wpid == pid:
                # Drain anything still buffered.
                try:
                    while True:
                        chunk = os.read(fd, 4096)
                        if not chunk:
                            break
                        sink.extend(chunk)
                except OSError:
                    pass
                rc = os.waitstatus_to_exitcode(status)
                return bytes(sink), rc
        except ChildProcessError:
            return bytes(sink), 0

        ready_r, _, _ = select.select([fd], [], [], 0.05)
        if fd in ready_r:
            try:
                chunk = os.read(fd, 4096)
                if chunk:
                    sink.extend(chunk)
            except OSError:
                pass

        if next_event < len(key_events):
            try:
                os.write(fd, key_events[next_event])
                next_event += 1
                # Brief pause so the TUI's input loop reads/processes
                # this event before the next arrives.
                time.sleep(0.05)
            except OSError:
                pass


def fail(label, msg):
    print(f"  FAIL: {label}: {msg}")


def passed(label):
    print(f"  ok: {label}")


def expect_in(label, needle, haystack, failures):
    if needle in haystack:
        passed(label)
    else:
        fail(label, f"missing {needle!r} in output (last 200 bytes: {haystack[-200:]!r})")
        failures.append(label)


def expect_rc(label, rc, want, failures):
    if rc == want:
        passed(label)
    else:
        fail(label, f"exit code {rc}, want {want}")
        failures.append(label)


def main():
    shu = sys.argv[1] if len(sys.argv) > 1 else SHU_DEFAULT
    if not os.path.isfile(shu) or not os.access(shu, os.X_OK):
        print(
            f"PTY smoke: {shu} not executable — run "
            f"'cyrius build src/main.cyr build/shu' first",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"PTY smoke: driving {shu}")
    failures = []

    # ---------------- 1: launch + q quit ----------------
    print("[1] launch + q quit")
    out, rc = drive([b"q"], shu_path=shu)
    expect_rc("q exits 0", rc, 0, failures)
    expect_in("'host:' in render", b"host:", out, failures)
    expect_in("'PID' header in render", b"PID", out, failures)
    expect_in("alt-screen enter (CSI ?1049h)", b"\x1b[?1049h", out, failures)
    expect_in("alt-screen leave (CSI ?1049l)", b"\x1b[?1049l", out, failures)

    # ---------------- 2: Ctrl-C exit ----------------
    print("[2] Ctrl-C exit")
    out, rc = drive([b"\x03"], shu_path=shu)
    expect_rc("Ctrl-C exits 0", rc, 0, failures)

    # ---------------- 3: sort cycle (s, q) ----------------
    print("[3] sort cycle")
    out, rc = drive([b"s", b"q"], shu_path=shu)
    expect_rc("s + q exits 0", rc, 0, failures)
    expect_in("'PID' header still present after sort", b"PID", out, failures)

    # ---------------- 4: filter mode round-trip ----------------
    # f → type "init" → Enter (apply, back to Normal) → q
    print("[4] filter mode round-trip")
    out, rc = drive(
        [b"f", b"i", b"n", b"i", b"t", b"\r", b"q"],
        shu_path=shu,
    )
    expect_rc("filter round-trip exits 0", rc, 0, failures)
    expect_in("'filter' label in status line", b"filter", out, failures)

    # ---------------- 5: kill confirm cancel ----------------
    # k (capture pid) → n (cancel — anything-but-y) → q
    # SAFETY: this never sends 'y' so no signal is ever sent.
    print("[5] kill confirm cancel")
    out, rc = drive([b"k", b"n", b"q"], shu_path=shu)
    expect_rc("k + n + q exits 0", rc, 0, failures)
    expect_in("'Kill PID' confirm shown", b"Kill PID", out, failures)
    expect_in("'[y/N]' prompt shown", b"[y/N]", out, failures)

    # ---------------- 6: arrow key (CSI sequence) ----------------
    # ESC [ B (down arrow) sent atomically as one PTY write so
    # _tui_read_key sees the full sequence in one read. Verifies the
    # multi-byte CSI parsing path works under PTY too.
    print("[6] down-arrow + q")
    out, rc = drive([b"\x1b[B", b"q"], shu_path=shu)
    expect_rc("↓ + q exits 0", rc, 0, failures)

    # ---------------- summary ----------------
    print()
    if failures:
        print(f"PTY smoke: FAIL ({len(failures)} of 6 tests)")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("PTY smoke: PASS (6/6)")


if __name__ == "__main__":
    main()
