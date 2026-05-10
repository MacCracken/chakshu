#!/usr/bin/env bash
# chakshu smoke test — gates M0 + M1 closed-milestone behavior.
# Usage: bash scripts/smoke.sh [path/to/shu]    (default: build/shu)
#
# bash (not /bin/sh dash) is required: process substitution `<(...)`
# and `$'\x...'` C-string escapes are used below.

set -eu

BIN="${1:-build/shu}"

if [ ! -x "$BIN" ]; then
    echo "smoke: $BIN not executable — run 'cyrius build src/main.cyr build/shu' first" >&2
    exit 1
fi

TMPDIR="${TMPDIR:-/tmp}/shu-smoke-$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

fail() { echo "smoke: FAIL — $1" >&2; exit 1; }
pass() { echo "  ok: $1"; }

# ============================================================
# M0 — version / help / exit-code matrix
# ============================================================
echo "[M0] version / help / exit codes"

v_long=$("$BIN" --version) || fail "--version exited non-zero"
[ -n "$v_long" ]            || fail "--version emitted nothing"

v_short=$("$BIN" -V) || fail "-V exited non-zero"
[ "$v_long" = "$v_short" ]  || fail "-V disagrees with --version"

case "$v_long" in
    "chakshu "*) pass "version starts with 'chakshu '" ;;
    *) fail "--version output does not start with 'chakshu ': $v_long" ;;
esac

h_long=$("$BIN" --help) || fail "--help exited non-zero"
[ -n "$h_long" ]         || fail "--help emitted nothing"

h_short=$("$BIN" -h) || fail "-h exited non-zero"
[ "$h_long" = "$h_short" ] || fail "-h disagrees with --help"
pass "help short/long parity"

# Bare invocation launches the TUI (M2 Slice A). In non-TTY contexts
# (CI runners, scripts with stdin redirected) tui_run exits 1 with
# "stdin is not a TTY (use -p for plain mode)". Force stdin to
# /dev/null so this assertion is deterministic regardless of where
# smoke.sh is invoked from. The actual TUI surface is exercised by
# the PTY-based smoke gate that lands at M2 Slice G.
set +e
"$BIN" </dev/null >/dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" -eq 1 ]                                || fail "bare in non-TTY exit was $rc, want 1"
grep -q "not a TTY" "$TMPDIR/err"              || fail "bare non-TTY missing 'not a TTY' message"
pass "bare in non-TTY → exit 1 with not-a-TTY stderr"

# Unknown flag → EXIT_USAGE (2), error to stderr.
set +e
"$BIN" --bogus >"$TMPDIR/out" 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" -eq 2 ]                                || fail "--bogus exit was $rc, want 2"
grep -q "unknown flag" "$TMPDIR/err"           || fail "--bogus stderr missing 'unknown flag'"
[ ! -s "$TMPDIR/out" ]                         || fail "--bogus wrote to stdout (should be stderr-only)"
pass "unknown flag → exit 2, stderr only"

# Recognized but unimplemented flag → EXIT_ERR (1), stderr message.
set +e
"$BIN" --watch >"$TMPDIR/out" 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" -eq 1 ]                                || fail "--watch exit was $rc, want 1"
grep -q "not implemented" "$TMPDIR/err"        || fail "--watch stderr missing 'not implemented'"
pass "unimplemented flag → exit 1, stderr only"

# ============================================================
# M1 — plain snapshot shape
# ============================================================
echo "[M1] -p plain snapshot"

"$BIN" -p > "$TMPDIR/snap" 2> "$TMPDIR/snap.err" || fail "-p exited non-zero"
[ ! -s "$TMPDIR/snap.err" ]                     || fail "-p wrote to stderr (should be stdout-only on success)"

# Header lines 1–4: each must contain its expected marker. Order matters.
sed -n '1p' "$TMPDIR/snap" | grep -q '^host: '                 || fail "line 1 missing 'host: '"
sed -n '2p' "$TMPDIR/snap" | grep -q '^mem:'                   || fail "line 2 missing 'mem:'"
sed -n '3p' "$TMPDIR/snap" | grep -q '^cpu:'                   || fail "line 3 missing 'cpu:'"
sed -n '4p' "$TMPDIR/snap" | grep -q 'PID'                     || fail "line 4 missing 'PID' table header"
pass "lines 1–4 shape (host/mem/cpu/PID-header)"

# Each header line should also carry its co-fields.
sed -n '1p' "$TMPDIR/snap" | grep -q 'up: '                    || fail "line 1 missing 'up: '"
sed -n '1p' "$TMPDIR/snap" | grep -q 'load: '                  || fail "line 1 missing 'load: '"
sed -n '3p' "$TMPDIR/snap" | grep -q 'disk:'                   || fail "line 3 missing 'disk:'"
sed -n '3p' "$TMPDIR/snap" | grep -q 'net:'                    || fail "line 3 missing 'net:'"
pass "header co-fields present"

# Default top-N is 10 → 4 header lines + 10 process rows = 14.
total=$(wc -l < "$TMPDIR/snap")
[ "$total" -ge 14 ]                            || fail "default -p produced $total lines, want >=14"
pass "default -p ≥14 lines"

# ============================================================
# M1 — --top N
# ============================================================
echo "[M1] --top N"

"$BIN" -p --top 5 > "$TMPDIR/top5" 2>/dev/null || fail "--top 5 exited non-zero"
[ "$(wc -l < "$TMPDIR/top5")" -ge 9 ]          || fail "--top 5 produced too few lines"
[ "$(wc -l < "$TMPDIR/top5")" -le 9 ]          || fail "--top 5 produced too many lines (>9)"
pass "--top 5 → 9 lines"

"$BIN" -p --top 1 > "$TMPDIR/top1" 2>/dev/null || fail "--top 1 exited non-zero"
[ "$(wc -l < "$TMPDIR/top1")" -eq 5 ]          || fail "--top 1 should be 5 lines (4 header + 1 row)"
pass "--top 1 → 5 lines"

# Invalid --top values → EXIT_USAGE.
set +e
"$BIN" -p --top 0  >/dev/null 2>"$TMPDIR/err"; rc=$?
set -e
[ "$rc" -eq 2 ]                                || fail "--top 0 exit was $rc, want 2"
pass "--top 0 → exit 2"

set +e
"$BIN" -p --top    >/dev/null 2>"$TMPDIR/err"; rc=$?
set -e
[ "$rc" -eq 2 ]                                || fail "--top (no value) exit was $rc, want 2"
pass "--top (no value) → exit 2"

# ============================================================
# M1 — --sort cpu|mem|pid|name
# ============================================================
echo "[M1] --sort"

for key in cpu mem pid name; do
    "$BIN" -p --sort "$key" --top 5 > "$TMPDIR/sort.$key" 2>/dev/null \
        || fail "--sort $key exited non-zero"
    [ "$(wc -l < "$TMPDIR/sort.$key")" -eq 9 ] \
        || fail "--sort $key produced wrong line count"
done
pass "--sort {cpu,mem,pid,name} all exit 0"

# --sort pid asc → first row PID < last row PID.
first_pid=$(awk 'NR==5 { print $1 }' "$TMPDIR/sort.pid")
last_pid=$(awk 'NR==9 { print $1 }' "$TMPDIR/sort.pid")
[ "$first_pid" -lt "$last_pid" ] \
    || fail "--sort pid asc broken: first=$first_pid last=$last_pid"
pass "--sort pid is ascending"

# Invalid sort key → EXIT_USAGE.
set +e
"$BIN" -p --sort foo >/dev/null 2>"$TMPDIR/err"; rc=$?
set -e
[ "$rc" -eq 2 ]                                || fail "--sort foo exit was $rc, want 2"
grep -q "unknown key" "$TMPDIR/err"            || fail "--sort foo stderr missing 'unknown key'"
pass "--sort foo → exit 2"

# ============================================================
# M1 — pipe sanity (design-spec §2.2: -p is sacred for pipes)
# ============================================================
echo "[M1] pipe sanity"

# wc -l should not choke on the output (no embedded NULs, no escapes).
piped_count=$("$BIN" -p | wc -l)
[ "$piped_count" -ge 14 ]                      || fail "piped wc -l = $piped_count"
pass "shu -p | wc -l works"

# `time` budget: watch -n 1 needs each frame to fit in 1 second.
# Wall is ~110 ms (100 ms sample + ~10 ms work). Set a generous
# 800 ms ceiling to absorb runner variance.
secs=$( { TIMEFORMAT='%R'; time "$BIN" -p > /dev/null 2>&1; } 2>&1 )
# Cross-shell-safe: bash prints e.g. "0.110" for TIMEFORMAT=%R.
awk -v s="$secs" 'BEGIN { exit (s+0 < 0.8 ? 0 : 1) }' \
    || fail "shu -p wall = ${secs}s, want < 0.8s"
pass "wall time ${secs}s < 0.8s budget"

echo
echo "smoke: PASS ($BIN)"
