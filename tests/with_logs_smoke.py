#!/usr/bin/env python3
"""End-to-end gate for `--with-logs` (v0.8.1).

The privacy-critical assertion in one place: when log context is folded into an
AI prompt, every secret shape the v0.7.13 redaction sweep closed must STILL be
stripped. `--with-logs` widens what reaches the prompt, so it is exactly the
change that could reopen that hole — and it would reopen it silently, because
nothing else asserts on prompt contents.

This works without a live hoosh gateway: when the gateway is unreachable,
`shu-ai --explain` prints the redacted context it *would* have sent, which is
the same text that would go on the wire. So the prompt is inspectable offline.

Run:
    python3 tests/with_logs_smoke.py [path/to/shu-ai]
Default binary: ../ai/build/shu-ai relative to this file.
"""

import os
import subprocess
import sys
import tempfile

SHU_AI_DEFAULT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "ai", "build", "shu-ai"
)

# Each entry: (log line written, must NOT appear in the prompt, must appear).
# The "must appear" half matters as much as the redaction: a redactor that
# blanked the whole line would pass a leak test while destroying the context
# the feature exists to provide.
CASES = [
    ("[1] [ERROR] auth failed for --password=hunter2", "hunter2", "--password="),
    ("[2] [INFO] connected postgres://bob:s3cret@db.internal/app", "s3cret", "db.internal"),
    # NB the surrounding word here is deliberately NOT one of the redactor's
    # trigger words. With the aggressive vocabulary chosen at v0.7.13, a bare
    # secret-looking token ("token", "auth", "session"...) arms a cross-token
    # lookback that redacts the FOLLOWING word too — so "token rejected: <jwt>"
    # correctly yields "token ***" and loses "rejected". That is accepted
    # collateral, not a defect; asserting on an adjacent word would be
    # asserting the redactor is weaker than it is.
    ("[3] [WARN] handshake eyJhbGciOiJIUzI1NiJ9.body.sig", "eyJhbGciOiJIUzI1NiJ9", "handshake"),
    ("[4] [INFO] aws key AKIAIOSFODNN7EXAMPLE rotated", "AKIAIOSFODNN7EXAMPLE", "rotated"),
    ("[5] [INFO] PASSWORD=uppercase_secret in env dump", "uppercase_secret", "PASSWORD="),
]

failures = []


def check(label, cond, detail=""):
    if cond:
        print(f"  ok: {label}")
    else:
        print(f"  FAIL: {label}{(': ' + detail) if detail else ''}")
        failures.append(label)


def run(shu_ai, log_path, with_logs):
    env = dict(os.environ)
    env["CHAKSHU_LOG_PATH"] = log_path
    # Point at a port nothing is listening on so the fallback path prints the
    # prompt rather than trying to reach a real gateway.
    env["CHAKSHU_HOOSH_URL"] = "http://127.0.0.1:1/v1/chat/completions"
    args = [shu_ai]
    if with_logs:
        args.append("--with-logs")
    args += ["--explain", "1"]
    p = subprocess.run(args, capture_output=True, text=True, env=env, timeout=30)
    return p.stdout + p.stderr


def main():
    shu_ai = sys.argv[1] if len(sys.argv) > 1 else SHU_AI_DEFAULT
    if not os.path.exists(shu_ai):
        print(f"with-logs smoke: SKIP (no {shu_ai})")
        return 0

    fh = tempfile.NamedTemporaryFile(mode="w", suffix=".log",
                                     prefix="chakshu-withlogs-", delete=False)
    for line, _, _ in CASES:
        fh.write(line + "\n")
    fh.close()

    try:
        print("[1] opt-in is genuinely off by default")
        base = run(shu_ai, fh.name, with_logs=False)
        check("no log section without --with-logs", "recent log:" not in base)
        for line, secret, _ in CASES:
            if secret in base:
                check(f"secret {secret!r} absent without --with-logs", False)
                break
        else:
            check("no log content leaks without the flag", True)

        print("[2] --with-logs folds log context in")
        out = run(shu_ai, fh.name, with_logs=True)
        check("log section present", "recent log:" in out,
              "prompt had no 'recent log:' section")

        print("[3] every secret shape is still redacted")
        for line, secret, keep in CASES:
            check(f"{secret[:18]!r} stripped", secret not in out)
            check(f"context {keep!r} preserved", keep in out)

        print("[4] the prompt still carries the process facts")
        check("process line intact", "process:" in out)
        check("system line intact", "system:" in out)
    finally:
        try:
            os.unlink(fh.name)
        except OSError:
            pass

    print()
    if failures:
        print(f"with-logs smoke: FAIL ({len(failures)} checks)")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("with-logs smoke: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
