#!/bin/sh
# nolibc-check — both binaries must be pure-syscall: statically linked, with no
# dynamic loader and no dlopen bridge of any kind.
#
# Usage: sh scripts/nolibc-check.sh
# Exit 0 if both binaries are clean; 1 (naming each offender) otherwise.
#
# ── WHY THIS IS A SHARED SCRIPT AND NOT INLINE YAML ──────────────────────────
# It is invoked identically by .github/workflows/ci.yml and by scripts/check.sh,
# the same way scripts/toolchain-pin-check.sh is. That is deliberate, and it is
# the fix for a bug this gate shipped with at v0.9.7.
#
# The gate was first written twice: once inline in ci.yml, once inline in
# check.sh. Same logic, but GitHub Actions runs `run:` blocks under `bash -e`
# while check.sh runs under `set -u` with no `-e`. And `grep -c` EXITS 1 WHEN
# THE COUNT IS ZERO. So:
#
#     n=$(readelf -d "$b" | grep -c NEEDED)   # 0 matches -> grep rc=1
#
# killed the whole step under `-e` — on a CORRECTLY STATIC binary. The gate
# failed precisely when the tree was clean, and died before printing a single
# diagnostic, so the CI log showed only "exit code 1" with no reason. Locally it
# passed, because check.sh has no `-e`.
#
# Two lessons, both encoded here: every count is taken with `|| true`, and there
# is now exactly ONE implementation, so the two callers cannot diverge in logic
# OR in shell flags again.
#
# ── WHAT IS DELIBERATELY *NOT* ASSERTED ──────────────────────────────────────
# `libssl.so.3` / `libcrypto.so.3` survive as dead .rodata in lib/tls.cyr's
# unreachable libssl branch: every preprocessor guard in that file is
# CYRIUS_TLS_LIBSSL-only, so there is no upstream flag that compiles the libssl
# half out. No code path can reach them — src/nolibc.cyr refuses
# fdlopen_helper_available(), which tls.cyr:218 gates the entire path on. The
# MACHINERY is what is gated below. Asserting their absence would be asserting
# something false; fixing it needs a CYRIUS_TLS_NATIVE_ONLY guard upstream.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

FAIL=0
N=0

for b in build/shu ai/build/shu-ai; do
    if [ ! -f "$b" ]; then
        echo "nolibc-check: FAILED — missing binary: $b" >&2
        echo "  Build both before running this gate (ci.yml does; so does check.sh)." >&2
        FAIL=1
        continue
    fi
    N=$((N + 1))

    # `|| true` on EVERY count: grep -c exits 1 on a zero count, which is the
    # PASSING case here. Without it this gate kills itself under `bash -e`.
    needed="$(readelf -d "$b" 2>/dev/null | grep -c NEEDED || true)"
    [ "$needed" = "0" ] || { echo "  $b: $needed NEEDED entries (dynamically linked)"; FAIL=1; }

    interp="$(readelf -l "$b" 2>/dev/null | grep -c 'program interpreter' || true)"
    [ "$interp" = "0" ] || { echo "  $b: has a program interpreter"; FAIL=1; }

    hits="$(strings "$b" | grep -xE 'dlopen|dlsym|getaddrinfo|ld-linux-x86-64\.so\.2|/lib64/ld-linux-x86-64\.so\.2' || true)"
    [ -n "$hits" ] && { echo "  $b: links dlopen machinery:"; echo "$hits" | sed 's/^/      /'; FAIL=1; }

    helper="$(strings "$b" | grep -c 'dlopen-helper' || true)"
    [ "$helper" = "0" ] || { echo "  $b: references the toolchain dlopen-helper"; FAIL=1; }
done

# The manifest must not re-declare the on-ramps. (The lean/root manifest is
# covered by ci.yml's security-job lean_net check; this is its ai/ counterpart.)
ai_ffi="$(sed -n '/^\[deps\]/,/^\[/p' ai/cyrius.cyml | grep -oE '"(dynlib|fdlopen|cffi|pam)"' || true)"
[ -n "$ai_ffi" ] && { echo "  ai/cyrius.cyml re-declares an FFI on-ramp: $ai_ffi"; FAIL=1; }

# ...and the refusal that makes it all work must still be there. Deleting
# src/nolibc.cyr would otherwise pass silently once fdlopen came back.
grep -q 'fn fdlopen_helper_available' src/nolibc.cyr 2>/dev/null \
    || { echo "  src/nolibc.cyr no longer defines the fdlopen refusal"; FAIL=1; }

# ── VACUITY FLOOR ────────────────────────────────────────────────────────────
# A gate that enumerates binaries and asserts things about them fails the same
# way it passes — silently, by enumerating nothing. Both binaries must have been
# examined, or this run proved nothing.
if [ "$N" -lt 2 ]; then
    echo "nolibc-check: FAILED — examined $N binary/binaries; this gate is vacuous below 2." >&2
    exit 1
fi

if [ "$FAIL" -ne 0 ]; then
    echo ""
    echo "nolibc-check: FAILED — CLAUDE.md's no-libc rule covers BOTH binaries since v0.9.7."
    echo "  Do NOT fix a TLS problem by re-declaring fdlopen/dynlib in ai/cyrius.cyml —"
    echo "  that restores the libc bridge and the AGNOS regression with it. TLS runs on"
    echo "  the Cyrius-native stack; fix it there. See src/nolibc.cyr."
    exit 1
fi

echo "nolibc-check: OK — $N binaries, static, no interpreter, no dlopen bridge"
exit 0
