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

# v0.9.4: --version must match the VERSION file. Every other gate here runs the
# BINARY, so a stale build — one compiled before the last source change — passes
# all of them. CI's "Verify version consistency" job compares VERSION against
# CHANGELOG / cyrius.cyml / src/cli.cyr, i.e. four FILES; nothing compared the
# file to the ARTIFACT. This is the gate that catches "you forgot to rebuild".
# Skipped when run from outside the repo (release.yml runs this against a
# downloaded binary with no source tree beside it).
if [ -f VERSION ]; then
    want="chakshu $(tr -d '[:space:]' < VERSION)"
    [ "$v_long" = "$want" ] || fail "--version is '$v_long', VERSION file says '$want' (stale build?)"
    pass "--version matches the VERSION file"
fi

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

# --with-logs is an AI-only MODIFIER, and this script runs against BOTH
# binaries (release.yml drives it over build/shu and, separately, build/shu-ai),
# so the assertion has to be build-aware rather than hardcode one exit code:
#
#   lean `shu`   → refuses it outright: exit 2, "needs the AI build".
#   `shu-ai`     → accepts it, then falls through to the default TUI mode and
#                  hits the non-TTY guard: exit 1, "not a TTY".
#
# Both are correct; asserting only the lean code is what broke the 0.8.1 and
# 0.8.2 release runs while CI stayed green — CI only ran this script against the
# lean binary, so the shu-ai path was never exercised until release.
set +e
"$BIN" --with-logs >"$TMPDIR/out" 2>"$TMPDIR/err"
rc=$?
set -e
[ ! -s "$TMPDIR/out" ]                         || fail "--with-logs wrote to stdout"
if grep -q "needs the AI build" "$TMPDIR/err"; then
    [ "$rc" -eq 2 ]                            || fail "lean --with-logs exit was $rc, want 2"
    pass "lean --with-logs → exit 2, stderr only"
elif grep -q "not a TTY" "$TMPDIR/err"; then
    [ "$rc" -eq 1 ]                            || fail "shu-ai --with-logs exit was $rc, want 1"
    pass "shu-ai --with-logs accepted → falls through to TUI, exit 1"
else
    fail "--with-logs stderr matched neither build's expected message: $(head -1 "$TMPDIR/err")"
fi

# ============================================================
# v0.8.0 — --watch anomaly stream
# ============================================================
echo "[M3] --watch anomaly stream"

# Missing sink → EXIT_ERR with actionable stderr, nothing on stdout.
set +e
"$BIN" --watch "$TMPDIR/no-such-stream.jsonl" >"$TMPDIR/out" 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" -eq 1 ]                                || fail "--watch missing sink exit was $rc, want 1"
[ ! -s "$TMPDIR/out" ]                         || fail "--watch missing sink wrote to stdout"
grep -q "cannot read anomaly stream" "$TMPDIR/err" || fail "--watch missing sink stderr unhelpful"
pass "--watch missing sink → exit 1, stderr only"

# A real aegis-shaped record must parse and render newest-first with severity.
cat >"$TMPDIR/events.jsonl" <<'JSONL'
{"id":"a","timestamp":"2026-08-25T00:49:17Z","event_type":"PolicyViolation","source":"aegis","agent_id":null,"threat_level":"Low","description":"first event","metadata":{},"resolved":false}
{"id":"b","timestamp":"2026-08-25T00:50:00Z","event_type":"MaliciousPayload","source":"phylax","agent_id":null,"threat_level":"Critical","description":"second event","metadata":{},"resolved":false}
JSONL
set +e
"$BIN" --watch "$TMPDIR/events.jsonl" >"$TMPDIR/out" 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" -eq 0 ]                                || fail "--watch exit was $rc, want 0"
[ ! -s "$TMPDIR/err" ]                         || fail "--watch wrote to stderr on success"
grep -q "MaliciousPayload" "$TMPDIR/out"       || fail "--watch did not render event_type"
grep -q "second event" "$TMPDIR/out"           || fail "--watch did not render description"
grep -q "CRIT" "$TMPDIR/out"                   || fail "--watch did not render severity"
grep -q "00:50:00" "$TMPDIR/out"               || fail "--watch did not render clock time"
[ "$(head -2 "$TMPDIR/out" | tail -1 | grep -c CRIT)" -eq 1 ] || fail "--watch is not newest-first"
pass "--watch renders a real aegis record, newest-first"

# A malformed line must be skipped, not fatal — the stream is another
# process's output and one bad record must not kill the monitor.
printf 'not json at all\n{"event_type":"SandboxEscape","threat_level":"High","description":"after garbage"}\n' >>"$TMPDIR/events.jsonl"
set +e
"$BIN" --watch "$TMPDIR/events.jsonl" >"$TMPDIR/out" 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" -eq 0 ]                                || fail "--watch died on a malformed line (rc $rc)"
grep -q "after garbage" "$TMPDIR/out"          || fail "--watch dropped the record after a bad line"
pass "--watch skips a malformed record and keeps going"

# No terminfo escapes in the non-TTY dump — same contract as `-p` (spec §2.2).
if grep -q "$(printf '\033')" "$TMPDIR/out"; then
    fail "--watch emitted terminfo escapes in a pipe"
fi
pass "--watch pipe output is escape-free"

# Mode combinations are rejected, not silently half-honoured.
for combo in "-p" "--pid 1"; do
    set +e
    "$BIN" --watch $combo >"$TMPDIR/out" 2>"$TMPDIR/err"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]                            || fail "--watch $combo exit was $rc, want 2"
done
pass "--watch rejects -p and --pid with exit 2"

# ============================================================
# M1 — plain snapshot shape
# ============================================================
echo "[M1] -p plain snapshot"

"$BIN" -p > "$TMPDIR/snap" 2> "$TMPDIR/snap.err" || fail "-p exited non-zero"
[ ! -s "$TMPDIR/snap.err" ]                     || fail "-p wrote to stderr (should be stdout-only on success)"

# M2.5 reshape: header now has 5 fixed lines (host, kern, proc, mem,
# cpu-delta) + optional gpu line + PID table header. Order matters but
# line numbers are no longer stable across hosts (gpu may or may not be
# present). Assert by line-anchored grep rather than absolute position.
sed -n '1p' "$TMPDIR/snap" | grep -q '^host: '                 || fail "line 1 missing 'host: '"
grep -q '^kern: ' "$TMPDIR/snap"                               || fail "missing 'kern:' line"
grep -q '^proc: ' "$TMPDIR/snap"                               || fail "missing 'proc:' line"
grep -q '^mem:'   "$TMPDIR/snap"                               || fail "missing 'mem:' line"
grep -q '^cpu:'   "$TMPDIR/snap"                               || fail "missing 'cpu:' delta line"
grep -q '^   PID S' "$TMPDIR/snap"                             || fail "missing PID table header"
pass "header shape (host/kern/proc/[gpu?]/mem/cpu/PID-header)"

# v0.9.1: when a gpu line is present AND the driver publishes DRM telemetry,
# it must carry live fields rather than only the static capacity. Conditional
# on both, because a CI runner has no GPU and NVIDIA's proprietary driver
# publishes none of these nodes — absence is correct, not a failure.
if grep -q "^gpu:" "$TMPDIR/snap"; then
    if [ -r /sys/class/drm/card0/device/gpu_busy_percent ] \
    || [ -r /sys/class/drm/card1/device/gpu_busy_percent ]; then
        grep -qE "^gpu:.*busy [0-9]+%" "$TMPDIR/snap" \
            || fail "gpu line lacks live busy% despite DRM telemetry being readable"
        grep -qE "^gpu:.*vram [0-9]+/[0-9]+ MiB" "$TMPDIR/snap" \
            || fail "gpu line lacks live vram used/total"
        pass "gpu line carries live DRM telemetry"
    else
        pass "gpu line present; no DRM telemetry on this host (expected)"
    fi
fi

# Each header line should also carry its co-fields.
sed -n '1p' "$TMPDIR/snap" | grep -q 'up: '                    || fail "line 1 missing 'up: '"
sed -n '1p' "$TMPDIR/snap" | grep -q 'load: '                  || fail "line 1 missing 'load: '"
grep -q 'distro:' "$TMPDIR/snap"                               || fail "kern line missing 'distro:' co-field"
grep -q 'cores)' "$TMPDIR/snap"                                || fail "proc line missing core-count"
grep '^cpu:' "$TMPDIR/snap" | grep -q 'disk:'                  || fail "cpu line missing 'disk:'"
grep '^cpu:' "$TMPDIR/snap" | grep -q 'net:'                   || fail "cpu line missing 'net:'"
pass "header co-fields present"

# Default top-N is 10 → 6 header lines (host/kern/proc/mem/cpu/PID) +
# 10 process rows = 16, +1 if gpu present. Allow >= 16.
total=$(wc -l < "$TMPDIR/snap")
[ "$total" -ge 16 ]                            || fail "default -p produced $total lines, want >=16"
pass "default -p ≥16 lines"

# ============================================================
# M1 — --top N
# ============================================================
echo "[M1] --top N"

"$BIN" -p --top 5 > "$TMPDIR/top5" 2>/dev/null || fail "--top 5 exited non-zero"
# M2.5 reshape: count rows AFTER the PID header rather than total lines
# — header size now varies (5 or 6 fixed lines + optional gpu) across
# hosts; the rows-after-PID count is the actual invariant.
top5_rows=$(awk '/^   PID S/ {start=1; next} start' "$TMPDIR/top5" | wc -l)
[ "$top5_rows" -eq 5 ]                         || fail "--top 5 produced $top5_rows process rows, want 5"
pass "--top 5 → 5 process rows"

"$BIN" -p --top 1 > "$TMPDIR/top1" 2>/dev/null || fail "--top 1 exited non-zero"
top1_rows=$(awk '/^   PID S/ {start=1; next} start' "$TMPDIR/top1" | wc -l)
[ "$top1_rows" -eq 1 ]                         || fail "--top 1 produced $top1_rows process rows, want 1"
pass "--top 1 → 1 process row"

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
    sort_rows=$(awk '/^   PID S/ {start=1; next} start' "$TMPDIR/sort.$key" | wc -l)
    [ "$sort_rows" -eq 5 ] \
        || fail "--sort $key produced $sort_rows process rows, want 5"
done
pass "--sort {cpu,mem,pid,name} all exit 0"

# --sort pid asc → first row PID < last row PID. PID header line is no
# longer at NR==4; awk-extract via row index 1/5 in the rows-after-PID
# stream so the assertion stays stable across header reshapes.
first_pid=$(awk '/^   PID S/ {start=1; next} start' "$TMPDIR/sort.pid" | awk 'NR==1 { print $1 }')
last_pid=$(awk '/^   PID S/ {start=1; next} start' "$TMPDIR/sort.pid" | awk 'NR==5 { print $1 }')
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
# Argument validation (design-spec §11 names these as smoke gates)
# ============================================================
echo "[args] rejection paths"

# design-spec.md:267 requires a gate for "exits non-zero on --pid 0". The
# behaviour has always been right; nothing asserted it, which is the same
# exists-on-paper-cannot-fail shape the P-1 sweep kept finding.
set +e
"$BIN" --pid 0 >/dev/null 2>&1; rc_pid0=$?
"$BIN" --rate 0 >/dev/null 2>&1; rc_rate0=$?
"$BIN" --rate 99 >/dev/null 2>&1; rc_rate99=$?
"$BIN" --color bogus >/dev/null 2>&1; rc_color=$?
"$BIN" --theme bogus >/dev/null 2>&1; rc_theme=$?
"$BIN" --bogusflag >/dev/null 2>&1; rc_unknown=$?
set -e
[ "$rc_pid0"   -ne 0 ] || fail "--pid 0 exited 0, want non-zero"
[ "$rc_rate0"  -ne 0 ] || fail "--rate 0 exited 0, want non-zero"
[ "$rc_rate99" -ne 0 ] || fail "--rate 99 exited 0, want non-zero"
[ "$rc_color"  -ne 0 ] || fail "--color bogus exited 0, want non-zero"
[ "$rc_theme"  -ne 0 ] || fail "--theme bogus exited 0, want non-zero"
[ "$rc_unknown" -ne 0 ] || fail "--bogusflag exited 0, want non-zero"
pass "invalid --pid/--rate/--color/--theme and unknown flags all rejected"

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
