#!/bin/sh
# toolchain-pin-check — every cyrius.cyml in the tree must pin the SAME toolchain
# as the ROOT manifest.
#
# Usage: sh scripts/toolchain-pin-check.sh
# Exit 0 if every manifest agrees with the root; 1 (listing each offender) otherwise.
#
# ── WHY THIS EXISTS ──────────────────────────────────────────────────────────
# CI installs EXACTLY ONE cyrius, and it reads the version from the ROOT manifest
# only — ci.yml "Install Cyrius toolchain" (:47) and release.yml's own copy (:96),
# verbatim:
#     CYRIUS_VERSION=$(grep 'cyrius *= *"' cyrius.cyml | head -1 | sed 's/.*"\(.*\)"/\1/')
# ai/cyrius.cyml's pin is therefore a CLAIM ON A TOOLCHAIN NOBODY INSTALLS.
#
# It still gets resolved, because the wrapper reads the manifest at the COMPILE
# CWD with no ancestor walk-up — cyrius cbt/deps.cyr:203 opens the bare relative
# path "cyrius.cyml". So the `cd ai` in ci.yml "Build + test shu-ai" (:150) — and
# in release.yml "Build DCE'd binary (shu-ai)" (:126) — makes every
# following `cyrius deps` / `build main.cyr build/shu-ai` / `test tests/chakshu-ai.tcyr`
# resolve ai/cyrius.cyml instead of the root. If that pin is not present under
# $CYRIUS_HOME/versions/, cbt/cyrius.cyr:135 sys_exit(1)s — a HARD ERROR:
#     error: cyrius.cyml pins version 6.2.24 but cyrius binary is not installed at
#            /home/runner/.cyrius/versions/6.2.24/bin/cyrius
# That kills CI *and* a TAG PUSH, since release.yml's build job re-installs from
# the root pin and then `cd ai` itself.
#
# ── AND THE BUG IS INVISIBLE ON THE DEV BOX ──────────────────────────────────
# Both branches were probed directly (2026-08-24, wrapper 6.5.35, 355 versions
# cached under ~/.cyrius/versions/):
#   · pin 6.5.99 (NOT installed) -> `error: ... is not installed`, rc=1.
#   · pin 6.2.24 (IS installed)  -> rc=0, NO diagnostic of any kind.
# The second case is worse than a warning: cbt/cyrius.cyr:170 execve()s into the
# pinned toolchain, so the drifted tree does not merely pass — it silently BUILDS
# WITH A DIFFERENT COMPILER and reports success. The only tell is the
# `manifest-pin:` line of `cyrius --version`, which no build step prints.
# 6.2.24 is not a hypothetical: commit d830369 moved the root to 6.2.36 and left
# ai/ on 6.2.24, and that version is cached here, so the broken tree was green on
# this machine. 86966c3 ("second manifest update") fixed it hours later.
#
# ── THE DESIGN CONSEQUENCE, WHICH IS THE WHOLE POINT ─────────────────────────
# ⭐ THIS GATE NEVER INVOKES cyrius. It is a pure text comparison of pin strings.
# Any gate that *built* something to test the pin would have its verdict decided
# by the contents of ~/.cyrius/versions/ — green on the box with 355 versions,
# red on the runner with one. That asymmetry IS the bug being closed; a gate that
# reproduced it would be worthless. This one returns the same answer on both
# machines, from the files alone, and needs no toolchain to run.
#
# ── VACUITY FLOOR ────────────────────────────────────────────────────────────
# A gate that enumerates files and compares them to a constant fails the same way
# it passes — silently, by enumerating nothing. So the manifest count is asserted
# (>= 2) and the list is PRINTED on success rather than implied: a run that says
# "1 manifest" is reporting that its own enumeration broke, not that the tree is
# clean.

set -u

# ONE level up: this script lives in scripts/, alongside smoke.sh.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

# Lists are passed between stages through files, and every loop reads them with
# `while read` fed by a REDIRECT (not a pipe, which would subshell the loop and
# discard what it accumulates). Deliberately not `for m in $LIST`: that depends
# on unquoted word splitting, which zsh does not do by default — the split-based
# version reported this very tree as broken under `zsh scripts/...`, a false RED
# that CI's dash would never have shown. Files also make paths containing spaces
# a non-issue.
TMPD="$(mktemp -d)" || { echo "toolchain-pin-check: FAILED — mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$TMPD"' EXIT INT TERM

# Use the EXACT extraction CI uses, so this gate and CI can never disagree about
# what "the pin" is. Deliberately the BRE grep + sed pair from ci.yml:28 — NOT
# grep -oP, which chakshu's workflows do not use and which would make the gate
# depend on a PCRE-capable grep that CI never needs.
read_pin() {
    grep 'cyrius *= *"' "$1" 2>/dev/null | head -1 | sed 's/.*"\(.*\)"/\1/'
}

ROOT_PIN="$(read_pin "$ROOT/cyrius.cyml")"
if [ -z "$ROOT_PIN" ]; then
    echo "toolchain-pin-check: FAILED — could not read the root pin from cyrius.cyml" >&2
    echo "  Expected a line of the exact form: cyrius = \"X.Y.Z\"" >&2
    echo "  CI reads it with the same expression; if this cannot see it, CI installs nothing." >&2
    exit 1
fi

# Shape-assert the root pin. That sed is a substitution, not a match: given a
# malformed line it cannot rewrite (an unterminated quote, say), it passes the
# WHOLE LINE THROUGH unchanged, and a non-empty garbage pin would otherwise be
# compared against ai/'s good one and reported as ai/ being the drifted file.
# CI has the same flaw and would try to fetch cyrius-<garbage>-x86_64-linux.tar.gz;
# catching it here names the real culprit.
if ! printf '%s\n' "$ROOT_PIN" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9._-]*$'; then
    echo "toolchain-pin-check: FAILED — the root pin is not version-shaped: '$ROOT_PIN'" >&2
    echo "  cyrius.cyml's [package].cyrius line is malformed. CI extracts the same string" >&2
    echo "  and would try to download cyrius-$ROOT_PIN-x86_64-linux.tar.gz." >&2
    exit 1
fi

if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    # Tracked + untracked-but-not-ignored, so .gitignore owns the exclusions:
    # /build/, /lib/, /ai/lib/, /ai/build/ are all declared non-source there
    # (lines 2, 9, 12, 13 — confirmed with `git check-ignore -v`), which keeps
    # this free of a hand-kept skip list that would rot.
    # `--others --exclude-standard` is deliberate: a brand-new sub-project
    # manifest is gated the moment it is written, not the day it is committed.
    # The lib/ prune is belt-and-braces — chakshu's vendored `cyrius deps`
    # snapshots are gitignored today, but a future tests/* sub-project could
    # track its own lib/ the way agnos does.
    git -C "$ROOT" ls-files --cached --others --exclude-standard -- '*cyrius.cyml' \
        | grep -vE '(^|/)lib/' | sort -u > "$TMPD/all" || true
    SRC="git ls-files (build/ + lib/ via .gitignore) minus vendored */lib/ snapshots"
else
    # Tarball / no-git fallback (release.yml's source job ships a git archive).
    # Prunes the same directory names by hand; kept SECOND so the hand-kept list
    # is never the thing that normally runs.
    find . \( -name .git -o -name build -o -name lib \) -prune -o \
        -name cyrius.cyml -print | sed 's|^\./||' | sort > "$TMPD/all" || true
    SRC="find with pruned .git/build/lib (git unavailable)"
fi

# Prune entries that are not in the worktree BEFORE counting. `ls-files --cached`
# reports what the INDEX holds, so a manifest deleted with plain `rm` (or absent
# mid-rebase / in a sparse checkout) is still listed. Counting those phantoms
# would inflate N past the vacuity floor while there was nothing left to read —
# the floor would pass on a tree the gate can no longer actually check, which is
# the precise failure mode the floor exists to catch. Pruning first makes a
# deleted manifest trip the floor instead of producing a bogus "NO pin" line
# about a file that is not there.
: > "$TMPD/present"
: > "$TMPD/missing"
while IFS= read -r m; do
    [ -n "$m" ] || continue
    if [ -f "$ROOT/$m" ]; then
        printf '%s\n' "$m" >> "$TMPD/present"
    else
        printf '    %s\n' "$m" >> "$TMPD/missing"
    fi
done < "$TMPD/all"

if [ -s "$TMPD/missing" ]; then
    echo "toolchain-pin-check: note — enumerated but not present in the worktree:"
    cat "$TMPD/missing"
    echo "  (tracked in the index; not counted below)"
fi

N="$(grep -c . "$TMPD/present" || true)"
if [ "$N" -lt 2 ]; then
    echo "toolchain-pin-check: FAILED — found $N manifest(s); this gate is vacuous below 2." >&2
    echo "  enumerated via: $SRC" >&2
    echo "  chakshu has the root manifest plus ai/cyrius.cyml for the shu-ai sub-project." >&2
    echo "  Finding fewer means the enumeration broke — or a manifest was deleted from" >&2
    echo "  the worktree (see any note above) — not that the tree is clean." >&2
    exit 1
fi

: > "$TMPD/drift"
while IFS= read -r m; do
    [ -n "$m" ] || continue
    [ "$m" = "cyrius.cyml" ] && continue
    pin="$(read_pin "$ROOT/$m")"
    if [ -z "$pin" ]; then
        printf '    %s: NO cyrius pin at all (root pins %s)\n' "$m" "$ROOT_PIN" >> "$TMPD/drift"
    elif [ "$pin" != "$ROOT_PIN" ]; then
        printf '    %s: pins %s  (root pins %s)\n' "$m" "$pin" "$ROOT_PIN" >> "$TMPD/drift"
    fi
done < "$TMPD/present"

if [ -s "$TMPD/drift" ]; then
    echo "toolchain-pin-check: FAILED — nested cyrius.cyml pins disagree with the ROOT pin ($ROOT_PIN)"
    cat "$TMPD/drift"
    echo ""
    echo "  CI installs ONLY $ROOT_PIN — its 'Install Cyrius toolchain' step reads the ROOT"
    echo "  manifest. The 'Build + test shu-ai' step then does 'cd ai', so every cyrius call"
    echo "  there resolves the manifest listed above instead and hard-errors with 'pins version"
    echo "  X but cyrius binary is not installed'. release.yml does the same 'cd ai' when it"
    echo "  builds shu-ai, so a TAG PUSH breaks with it."
    echo "  This is GREEN on a dev box with every version cached — where the wrapper silently"
    echo "  execve()s into the stale toolchain — which is why it needs a gate, not a warning."
    echo "  Fix: set every manifest listed above to  cyrius = \"$ROOT_PIN\"  in the SAME edit"
    echo "  as the root."
    exit 1
fi

echo "toolchain-pin-check: OK — $N manifests, all pin $ROOT_PIN"
sed 's/^/    /' "$TMPD/present"
exit 0
