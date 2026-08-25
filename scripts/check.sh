#!/usr/bin/env bash
# check.sh — run locally exactly what CI runs, in CI's order.
#
# ⛔ WHY THIS EXISTS. Twice in v0.9.4/v0.9.5, work passed a hand-rolled local sweep
# and then failed CI — once because the AI-privacy scan lives in a different job
# and was never run locally, once because the fmt gate covers `tests/*.tcyr` and
# `ai/tests/*.tcyr` while the local loop only walked `src/` and `ai/`. Both were
# the same mistake: a local check that RESEMBLES the CI gate instead of BEING it.
#
# ⚠ THE FILE SETS AND COMMANDS BELOW MUST TRACK .github/workflows/ci.yml. If you
# add a gate there, add it here in the same edit — a local runner that silently
# lags CI is worse than none, because it manufactures false confidence.
#
# Not covered here (needs hardware or network CI does not have either):
#   · tests/agnos_qemu.py  — boots a real AGNOS kernel under QEMU; run by hand
#                            before tagging anything touching the AGNOS path.
# Usage: bash scripts/check.sh

set -u
pass=0
fail=0

check() {   # check <label> <rc>
    if [ "$2" = "0" ]; then echo "  PASS: $1"; pass=$((pass + 1))
    else echo "  FAIL: $1"; fail=$((fail + 1)); fi
}

echo "=== chakshu check (mirrors .github/workflows/ci.yml) ==="
echo ""

echo "--- Toolchain ---"
sh scripts/toolchain-pin-check.sh > /tmp/chk-pin.log 2>&1 && rc=0 || rc=$?
check "toolchain pin consistency" $rc
[ "$rc" = "0" ] || cat /tmp/chk-pin.log
echo ""

echo "--- Build ---"
mkdir -p build
cyrius build src/main.cyr build/shu > /tmp/chk-build.log 2>&1 && rc=0 || rc=$?
check "lean build" $rc
[ "$rc" = "0" ] || tail -20 /tmp/chk-build.log
xxd -l 4 build/shu 2>/dev/null | grep -q "7f45 4c46" && rc=0 || rc=1
check "lean ELF magic" $rc
# The AGNOS build was the only unguarded one in the project until v0.9.4, and it
# is the target the v1.0 milestone is named after.
cyrius build --agnos src/main.cyr build/shu-agnos > /tmp/chk-agnos.log 2>&1 && rc=0 || rc=$?
check "AGNOS build" $rc
[ "$rc" = "0" ] || tail -20 /tmp/chk-agnos.log
xxd -l 4 build/shu-agnos 2>/dev/null | grep -q "7f45 4c46" && rc=0 || rc=1
check "AGNOS ELF magic" $rc
echo ""

echo "--- Format + lint ---"
# ⚠ THIS FILE SET IS THE ONE THAT BIT US. It must match ci.yml's loop exactly.
fmtfail=0
for f in src/*.cyr tests/*.tcyr ai/*.cyr ai/tests/*.tcyr; do
    [ -f "$f" ] || continue
    cyrius fmt --check "$f" >/dev/null 2>&1 || { echo "      drift: $f"; fmtfail=1; }
done
check "fmt (src + tests + ai + ai/tests)" $fmtfail
lintfail=0
for f in src/*.cyr; do
    out=$(cyrlint "$f" 2>&1)
    echo "$out" | grep -qE '^[1-9][0-9]* (untracked|warnings)' && { echo "      $f: $(echo "$out" | tail -2 | tr '\n' ' ')"; lintfail=1; }
done
check "lint (src)" $lintfail
echo ""

echo "--- Tests ---"
cyrius test tests/chakshu.tcyr > /tmp/chk-test.log 2>&1 && rc=0 || rc=$?
check "monitor unit tests ($(grep -oE '[0-9]+ passed' /tmp/chk-test.log | head -1))" $rc
[ "$rc" = "0" ] || tail -20 /tmp/chk-test.log
python3 tests/literal_len_check.py > /tmp/chk-lit.log 2>&1 && rc=0 || rc=$?
check "literal-length" $rc
[ "$rc" = "0" ] || cat /tmp/chk-lit.log
bash scripts/smoke.sh > /tmp/chk-smoke.log 2>&1 && rc=0 || rc=$?
check "smoke (lean)" $rc
[ "$rc" = "0" ] || tail -12 /tmp/chk-smoke.log
python3 tests/integration_smoke.py > /tmp/chk-pty.log 2>&1 && rc=0 || rc=$?
check "PTY integration smoke" $rc
[ "$rc" = "0" ] || tail -12 /tmp/chk-pty.log
echo ""

echo "--- AI variant ---"
( cd ai && CYRIUS_ALLOW_PARENT_INCLUDES=1 cyrius build main.cyr build/shu-ai \
  && CYRIUS_ALLOW_PARENT_INCLUDES=1 cyrius test tests/chakshu-ai.tcyr ) > /tmp/chk-ai.log 2>&1 && rc=0 || rc=$?
check "shu-ai build + tests ($(grep -oE '[0-9]+ passed' /tmp/chk-ai.log | head -1))" $rc
[ "$rc" = "0" ] || tail -20 /tmp/chk-ai.log
bash scripts/smoke.sh ai/build/shu-ai > /tmp/chk-smoke-ai.log 2>&1 && rc=0 || rc=$?
check "smoke (shu-ai)" $rc
[ "$rc" = "0" ] || tail -12 /tmp/chk-smoke-ai.log
python3 tests/with_logs_smoke.py > /tmp/chk-wl.log 2>&1 && rc=0 || rc=$?
check "with-logs privacy smoke" $rc
[ "$rc" = "0" ] || tail -12 /tmp/chk-wl.log
python3 tests/hoosh_stub_smoke.py > /tmp/chk-hoosh.log 2>&1 && rc=0 || rc=$?
check "hoosh-stub smoke" $rc
[ "$rc" = "0" ] || tail -12 /tmp/chk-hoosh.log
echo ""

echo '--- Security scan (a SEPARATE CI job) ---'
# ⚠ A SEPARATE CI JOB, which is precisely why it was never run locally and why
# v0.9.4 shipped a red build. Mirrors ci.yml's AI-privacy scan.
AI_SRC="src/ai.cyr src/ai_stub.cyr ai/main.cyr"
secfail=0
marked=$(grep -n 'privacy: DENY' $AI_SRC 2>/dev/null || true)
bad_marker=$(echo "$marked" | grep -v 'return 0;' | grep . || true)
[ -n "$bad_marker" ] && { echo "      marker not on a refusal line:"; echo "$bad_marker"; secfail=1; }
home_hits=$(grep -n '"/home/' $AI_SRC 2>/dev/null | grep -v 'privacy: DENY' || true)
[ -n "$home_hits" ] && { echo "      unmarked /home/ reference:"; echo "$home_hits"; secfail=1; }
for deny in '/proc/' '/sys/' '/dev/' '/home/'; do
    grep -q "\"$deny\".*privacy: DENY" $AI_SRC 2>/dev/null || { echo "      denylist no longer refuses $deny"; secfail=1; }
done
lean_net=$(sed -n '/^\[deps\]/,/^\[/p' cyrius.cyml | grep -oE '"(sandhi|net|http|tls|ws|dynlib|fdlopen|niyama)"' || true)
[ -n "$lean_net" ] && { echo "      lean manifest declares a network module: $lean_net"; secfail=1; }
sfd_hits=$(grep -rnE 'file_close\(\s*sfd' src/ 2>/dev/null || true)
[ -n "$sfd_hits" ] && { echo "      bare file_close on a signalfd:"; echo "$sfd_hits"; secfail=1; }
check "AI privacy + opt-in + signalfd hygiene" $secfail
echo ""

echo '--- Docs (a SEPARATE CI job) ---'
V=$(tr -d '[:space:]' < VERSION)
vfail=0
grep -qE "^## \[${V}\]" CHANGELOG.md || { echo "      CHANGELOG has no [${V}] section"; vfail=1; }
grep -qE '^version *= *"\$\{file:VERSION\}"' cyrius.cyml || { echo "      cyrius.cyml no longer pulls version from VERSION"; vfail=1; }
grep -qE "CHAKSHU_VERSION *= *\"chakshu ${V}\"" src/cli.cyr || { echo "      CHAKSHU_VERSION != ${V}"; vfail=1; }
check "version consistency (VERSION=${V})" $vfail
dfail=0
for f in README.md CHANGELOG.md VERSION LICENSE CLAUDE.md docs/design-spec.md \
         docs/development/roadmap.md docs/development/state.md; do
    [ -f "$f" ] || { echo "      missing: $f"; dfail=1; }
done
check "required files present" $dfail
echo ""

echo "=========================="
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
