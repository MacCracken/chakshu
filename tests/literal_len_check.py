#!/usr/bin/env python3
"""Assert every hand-counted string-literal length in the tree is correct.

WHY THIS EXISTS. Cyrius's write path is `syscall(1, fd, "text", N)` — the length is
typed by a human, and the compiler does not check it against the literal. Too small
truncates the message; too large runs past the literal into whatever follows it in
.rodata. The build stays green either way, so the only way this has ever surfaced is
by eye, in output nobody was reading closely.

`src/cli.cyr` says the class "has already bitten us twice". The v0.7.13 P-1 sweep
found five more and specified this gate as its highest bug-finding-power item; the
gate was never written. The v0.9.4 audit then found three more still shipping —
including a 65-byte error string declared as 62, which cut the stream-unavailable
message off mid-word, in the exact path a user hits when their event log is missing.

Run: python3 tests/literal_len_check.py [paths...]   (default: src/ ai/ tests/)
"""

import os
import re
import sys

# syscall(1, <fd>, "<literal>", <len>) — the only shape that hand-counts.
CALL = re.compile(
    r'syscall\(\s*1\s*,\s*\d+\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*(\d+)\s*\)'
)

# Cyrius escape set, decoded to the bytes the compiler actually emits.
SIMPLE = {'n': b'\n', 't': b'\t', 'r': b'\r', '0': b'\0',
          '\\': b'\\', '"': b'"', "'": b"'"}


def decode(lit):
    """Return the byte length of a Cyrius string literal, or None if unparseable."""
    out = bytearray()
    i = 0
    while i < len(lit):
        c = lit[i]
        if c != '\\':
            out += c.encode('utf-8')   # a literal UTF-8 char is its own bytes
            i += 1
            continue
        if i + 1 >= len(lit):
            return None
        e = lit[i + 1]
        if e == 'x':
            if i + 3 >= len(lit):
                return None
            try:
                out.append(int(lit[i + 2:i + 4], 16))
            except ValueError:
                return None
            i += 4
        elif e in SIMPLE:
            out += SIMPLE[e]
            i += 2
        else:
            return None
    return len(out)


def main():
    roots = sys.argv[1:] or ["src", "ai", "tests"]
    files = []
    for r in roots:
        if os.path.isfile(r):
            files.append(r)
            continue
        for dirpath, _, names in os.walk(r):
            if "lib" in dirpath.split(os.sep) or "build" in dirpath.split(os.sep):
                continue
            for n in names:
                if n.endswith((".cyr", ".tcyr")):
                    files.append(os.path.join(dirpath, n))

    bad, checked, skipped = [], 0, 0
    for path in sorted(set(files)):
        with open(path, encoding="utf-8") as fh:
            for lineno, line in enumerate(fh, 1):
                for m in CALL.finditer(line):
                    lit, declared = m.group(1), int(m.group(2))
                    actual = decode(lit)
                    if actual is None:
                        skipped += 1
                        continue
                    checked += 1
                    if actual != declared:
                        bad.append((path, lineno, lit, declared, actual))

    for path, lineno, lit, declared, actual in bad:
        show = lit if len(lit) <= 56 else lit[:53] + "..."
        verb = "TRUNCATES" if declared < actual else "OVER-READS past the literal"
        print(f"  FAIL {path}:{lineno}: declared {declared}, actual {actual} — {verb}")
        print(f'       "{show}"')

    print()
    print(f"literal-len: {checked} literal(s) checked, {len(bad)} wrong"
          + (f", {skipped} unparseable (skipped)" if skipped else ""))
    if bad:
        print("literal-len: FAIL")
        return 1
    print("literal-len: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
