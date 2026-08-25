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
    # v0.9.4 audit F2 — the single most common credential line in any real log, and
    # it leaked until v0.9.4. The R2 lookback carries ONE token, so "Authorization:"
    # armed it, the scheme word "Bearer" spent it, and the credential shipped
    # verbatim. A scheme word is never itself the secret, so the carry now re-arms
    # across it. Both shapes are gated because they take different code paths:
    # the Basic value's only '=' is base64 padding at the END, which the
    # "token without '='" test waved through as a key=value pair.
    ("[6] [WARN] Authorization: Bearer ghp_A1b2C3d4E5f6G7h8I9j0",
     "ghp_A1b2C3d4E5f6G7h8I9j0", "Authorization"),
    ("[7] [WARN] Authorization: Basic dXNlcjpwYXNzd29yZA==",
     "dXNlcjpwYXNzd29yZA==", "Authorization"),
    # v0.9.4 audit A2 — the shape vocabulary knew only eyJ/AKIA/ASIA, all years
    # old, so every modern provider token walked through as a BARE value with no
    # key beside it. That is exactly how they appear in real logs.
    ("[8] [INFO] pushing with ghp_A1b2C3d4E5f6G7h8I9j0K1l2",
     "ghp_A1b2C3d4E5f6G7h8I9j0K1l2", "pushing"),
    ("[9] [INFO] slack post xoxb-1234-5678-abcdefghijkl",
     "xoxb-1234-5678-abcdefghijkl", "slack"),
    ("[10] [INFO] charge via sk_live_51H8xKfLmNoPqRsTuVwX",
     "sk_live_51H8xKfLmNoPqRsTuVwX", "charge"),
    # v0.9.4 audit A3/A6 — only the FIRST '=' in a token was examined, so a
    # connection string with a benign leading key leaked every later credential.
    # The non-secret fragments must SURVIVE: blanking the whole token would
    # destroy the context this feature exists to provide.
    ("[11] [ERROR] dsn Server=db1;Password=hunter2345;Db=app",
     "hunter2345", "Server=db1"),
    ("[12] [INFO] callback a=1&token=deadbeefsecret&b=2",
     "deadbeefsecret", "a=1"),
    ("[13] [INFO] cfg x=1,apikey=zzsecretzz,y=2",
     "zzsecretzz", "y=2"),
]

# Lines that must survive UNTOUCHED. The redaction lookback is a blunt instrument
# and the failure mode when it is over-tuned is silent: context the feature exists
# to provide gets blanked, the leak tests still pass, and nobody notices. An
# earlier cut of the F2 fix added general filler words ("is", "the", "for") to the
# re-arm list and blanked "deploy" in ordinary log lines — caught only because
# this half existed. Each entry: (line written, substring that must SURVIVE).
KEEP_CASES = [
    ("[8] [INFO] deploy to prod started ok", "deploy to prod started ok"),
    ("[9] [INFO] pg --password hunter2 --port=8080", "--port=8080"),
]

failures = []


def check(label, cond, detail=""):
    if cond:
        print(f"  ok: {label}")
    else:
        print(f"  FAIL: {label}{(': ' + detail) if detail else ''}")
        failures.append(label)


# src/ai.cyr:430 — `AI_LOG_LINES = 6`. The prompt folds in only the last SIX log
# lines, so a fixture longer than that silently drops its earliest entries and the
# checks against them fail for a reason that has nothing to do with redaction.
# That is exactly what happened when this file grew to nine cases at v0.9.4. Batch
# accordingly rather than writing one long fixture.
AI_LOG_LINES = 6


def write_fixture(lines):
    fh = tempfile.NamedTemporaryFile(mode="w", suffix=".log",
                                     prefix="chakshu-withlogs-", delete=False)
    for line in lines:
        fh.write(line + "\n")
    fh.close()
    return fh.name


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

    fixtures = []

    def out_for(lines):
        path = write_fixture(lines)
        fixtures.append(path)
        return run(shu_ai, path, with_logs=True)

    try:
        print("[1] opt-in is genuinely off by default")
        base_path = write_fixture([c[0] for c in CASES[:AI_LOG_LINES]])
        fixtures.append(base_path)
        base = run(shu_ai, base_path, with_logs=False)
        check("no log section without --with-logs", "recent log:" not in base)
        for line, secret, _ in CASES:
            if secret in base:
                check(f"secret {secret!r} absent without --with-logs", False)
                break
        else:
            check("no log content leaks without the flag", True)

        print("[2] --with-logs folds log context in")
        out = out_for([c[0] for c in CASES[:AI_LOG_LINES]])
        check("log section present", "recent log:" in out,
              "prompt had no 'recent log:' section")
        check("process line intact", "process:" in out)
        check("system line intact", "system:" in out)

        print("[3] every secret shape is still redacted")
        # One batch per AI_LOG_LINES-sized group, so no case is pushed out of the
        # tail window by a later addition.
        for i in range(0, len(CASES), AI_LOG_LINES):
            group = CASES[i:i + AI_LOG_LINES]
            out = out_for([c[0] for c in group])
            for line, secret, keep in group:
                check(f"{secret[:18]!r} stripped", secret not in out)
                check(f"context {keep!r} preserved", keep in out)

        print("[4] the log path cannot be pointed at env vars or /home")
        # CLAUDE.md's binding rule: prompts carry no /home contents and no env
        # vars. $CHAKSHU_LOG_PATH is a legitimate config knob, so it is validated
        # rather than removed — and validation has to survive INDIRECTION. A
        # string-prefix denylist on the raw path (the v0.9.4 first attempt) is
        # defeated by all four of these, and each one still put the whole
        # environment on the wire to hoosh.
        #
        # ⚠ A type check alone does not help either: /proc/self/environ reports
        # S_IFREG. The denylist has to be applied to the RESOLVED path.
        marker = "leakme-prod-db-01"
        symlink = os.path.join(tempfile.gettempdir(), "chakshu-symenv")
        try:
            os.unlink(symlink)
        except OSError:
            pass
        try:
            os.symlink("/proc/self/environ", symlink)
        except OSError:
            symlink = None
        vectors = [
            ("direct /proc", "/proc/self/environ"),
            ("doubled slash", "//proc/self/environ"),
            ("relative ../..", "../../proc/self/environ"),
        ]
        if symlink:
            vectors.append(("symlink -> /proc", symlink))
        for label, vec in vectors:
            env = dict(os.environ)
            env["SECRET_XYZ"] = marker
            env["CHAKSHU_LOG_PATH"] = vec
            env["CHAKSHU_HOOSH_URL"] = "http://127.0.0.1:1/v1/chat/completions"
            p = subprocess.run([shu_ai, "--with-logs", "--explain", "1"],
                               capture_output=True, text=True, env=env, timeout=30)
            blob = p.stdout + p.stderr
            check(f"{label} does not leak the environment", marker not in blob,
                  "an environment variable reached the prompt")
        if symlink:
            try:
                os.unlink(symlink)
            except OSError:
                pass

        print("[5] ordinary context is NOT over-redacted")
        out = out_for([c[0] for c in KEEP_CASES])
        for line, keep in KEEP_CASES:
            check(f"{keep[:26]!r} survives", keep in out,
                  "the redactor blanked ordinary context")
    finally:
        for path in fixtures:
            try:
                os.unlink(path)
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
