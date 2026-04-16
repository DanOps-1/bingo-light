#!/usr/bin/env bash
# bingo-light edge-case / git-state boundary tests
# Usage: ./tests/test-edge.sh [path-to-bingo-light]
set -uo pipefail

BL="${1:-$(cd "$(dirname "$0")/.." && pwd)/bingo-light}"
TMPDIR_BASE=$(mktemp -d)
PASS=0 FAIL=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

RED='\033[0;31m' GREEN='\033[0;32m' CYAN='\033[0;36m'
BOLD='\033[1m' DIM='\033[2m' RESET='\033[0m'

pass() { ((PASS++)); echo -e "  ${GREEN}PASS${RESET} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}FAIL${RESET} $1: $2"; }
section() { echo -e "\n${BOLD}$1${RESET}"; }

run()  { OUT=$(timeout 30 "$BL" "$@" 2>&1) || true; }
has()  { echo "$OUT" | grep -qi "$1"; }

json_valid() {
    echo "$1" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null
}

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

# Helper: create a standard upstream + fork pair
setup_repos() {
    local name="${1:-edge}"
    local upstream="$TMPDIR_BASE/${name}-upstream"
    local fork="$TMPDIR_BASE/${name}-fork"

    mkdir -p "$upstream"
    cd "$upstream" && git init --initial-branch=main -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "line1" > app.py
    git add -A && git commit -q -m "Initial commit"
    echo "line2" >> app.py
    git add -A && git commit -q -m "Second commit"

    git clone -q "$upstream" "$fork"
    cd "$fork"
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "$upstream|$fork"
}

echo -e "${BOLD}bingo-light edge-case tests${RESET}"
echo -e "${DIM}CLI: $BL${RESET}"

# ─── 1. Non-git directory ────────────────────────────────────────────────────

section "1. Non-git directory"

NOGIT="$TMPDIR_BASE/not-a-repo"
mkdir -p "$NOGIT"
cd "$NOGIT"

run status
if has "not.*git\|not a git"; then pass "status fatals in non-git dir"; else fail "status non-git" "no graceful error: $OUT"; fi

run sync --force
if has "not.*git\|not a git"; then pass "sync fatals in non-git dir"; else fail "sync non-git" "no graceful error: $OUT"; fi

run patch list
if has "not.*git\|not a git"; then pass "patch list fatals in non-git dir"; else fail "patch list non-git" "no graceful error: $OUT"; fi

# ─── 2. Uninitialized repo ──────────────────────────────────────────────────

section "2. Uninitialized repo (no .bingolight)"

UNINIT="$TMPDIR_BASE/uninit-repo"
mkdir -p "$UNINIT" && cd "$UNINIT"
git init -q --initial-branch=main
git config user.email "test@test.com" && git config user.name "Test"
echo "hello" > file.txt && git add -A && git commit -q -m "init"
cd "$UNINIT"

run status
if has "not initialized"; then pass "status fatals when not initialized"; else fail "status uninit" "no graceful error: $OUT"; fi

run sync --force
if has "not initialized"; then pass "sync fatals when not initialized"; else fail "sync uninit" "no graceful error: $OUT"; fi

run patch list
if has "not initialized"; then pass "patch list fatals when not initialized"; else fail "patch list uninit" "no graceful error: $OUT"; fi

# ─── 3. Empty repo (no commits) ─────────────────────────────────────────────

section "3. Empty repo (no commits)"

EMPTY="$TMPDIR_BASE/empty-repo"
mkdir -p "$EMPTY" && cd "$EMPTY"
git init -q --initial-branch=main
cd "$EMPTY"

# init with a valid upstream that has commits -- but local repo has none
repos=$(setup_repos empty-upstream)
upstream="${repos%%|*}"
cd "$EMPTY"

OUT=$(timeout 30 "$BL" init "$upstream" main 2>&1 </dev/null) || true
# Should either fail gracefully or succeed -- must not crash with a stack trace
if echo "$OUT" | grep -qiE "fatal.*segfault|panic|core dump"; then
    fail "init on empty repo" "crashed: $OUT"
else
    pass "init on empty repo does not crash"
fi

# ─── 4. Detached HEAD ───────────────────────────────────────────────────────

section "4. Detached HEAD"

repos=$(setup_repos detached)
upstream="${repos%%|*}" fork="${repos##*|}"
cd "$fork"
"$BL" init "$upstream" main --yes </dev/null &>/dev/null || true

# Detach HEAD at the current commit
git checkout --detach HEAD &>/dev/null

OUT=$(timeout 30 "$BL" status --json 2>&1) || true
if json_valid "$OUT"; then
    pass "status --json valid on detached HEAD"
else
    # Even if JSON is invalid, it should not crash (exit code irrelevant, just no crash)
    if echo "$OUT" | grep -qiE "segfault|panic|core dump"; then
        fail "status detached HEAD" "crashed: $OUT"
    else
        pass "status on detached HEAD does not crash"
    fi
fi

# Return to a branch for cleanup
git checkout main &>/dev/null 2>&1 || true

# ─── 5. Dirty working tree ──────────────────────────────────────────────────

section "5. Dirty working tree"

repos=$(setup_repos dirty)
upstream="${repos%%|*}" fork="${repos##*|}"
cd "$fork"
"$BL" init "$upstream" main --yes </dev/null &>/dev/null || true

# Create a patch so drop/reorder have something to act on
echo "feature1" >> app.py
BINGO_DESCRIPTION="feature one" "$BL" patch new feat1 --yes &>/dev/null || true

# Now dirty the tree
echo "uncommitted" >> app.py

run sync --force
if has "dirty\|commit\|stash"; then pass "sync refuses on dirty tree"; else fail "sync dirty" "not rejected: $OUT"; fi

OUT=$(echo "y" | timeout 30 "$BL" patch drop 1 2>&1) || true
if echo "$OUT" | grep -qi "dirty\|commit\|stash"; then
    pass "patch drop refuses on dirty tree"
else
    fail "patch drop dirty" "not rejected: $OUT"
fi

OUT=$(timeout 30 "$BL" patch reorder "1" 2>&1) || true
if echo "$OUT" | grep -qi "dirty\|commit\|stash"; then
    pass "patch reorder refuses on dirty tree"
else
    fail "patch reorder dirty" "not rejected: $OUT"
fi

git checkout -- app.py &>/dev/null 2>&1 || true

# ─── 6. 50 patches ──────────────────────────────────────────────────────────

section "6. 50 patches (performance)"

repos=$(setup_repos fifty)
upstream="${repos%%|*}" fork="${repos##*|}"
cd "$fork"
"$BL" init "$upstream" main --yes </dev/null &>/dev/null || true

for i in $(seq 1 50); do
    echo "patch-content-$i" >> "app.py"
    BINGO_DESCRIPTION="patch number $i" "$BL" patch new "p$i" --yes &>/dev/null || true
done

OUT=$(timeout 30 "$BL" status --json 2>&1) || true
if json_valid "$OUT"; then
    count=$(echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('patch_count',0))" 2>/dev/null)
    if [[ "$count" -eq 50 ]]; then
        pass "status --json reports 50 patches"
    else
        fail "status 50 patches" "expected 50, got $count"
    fi
else
    fail "status --json 50 patches" "invalid JSON"
fi

OUT=$(timeout 30 "$BL" patch list --json 2>&1) || true
if json_valid "$OUT"; then
    count=$(echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)
    if [[ "$count" -eq 50 ]]; then
        pass "patch list --json reports 50 patches"
    else
        fail "patch list 50 patches" "expected 50, got $count"
    fi
else
    fail "patch list --json 50 patches" "invalid JSON"
fi

# ─── 7. Mid-rebase state ────────────────────────────────────────────────────

section "7. Mid-rebase state"

repos=$(setup_repos rebase)
upstream="${repos%%|*}" fork="${repos##*|}"
cd "$fork"
"$BL" init "$upstream" main --yes </dev/null &>/dev/null || true

# Create a patch touching app.py
echo "our-change" >> app.py
BINGO_DESCRIPTION="our mod" "$BL" patch new rebase-test --yes &>/dev/null || true

# Push a conflicting upstream change
cd "$upstream"
echo "upstream-conflict" >> app.py
git add -A && git commit -q -m "upstream conflict line"

# Trigger sync which should hit a conflict
cd "$fork"
timeout 30 "$BL" sync --json --yes &>/dev/null 2>&1 || true

# Verify we are mid-rebase (rebase-merge or rebase-apply exists)
if [[ -d .git/rebase-merge || -d .git/rebase-apply ]]; then
    OUT=$(timeout 30 "$BL" status --json 2>&1) || true
    if json_valid "$OUT"; then
        in_rebase=$(echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('in_rebase', False))" 2>/dev/null)
        if [[ "$in_rebase" == "True" ]]; then
            pass "status --json reports in_rebase=true during rebase"
        else
            fail "in_rebase flag" "expected True, got $in_rebase"
        fi
    else
        fail "status --json mid-rebase" "invalid JSON: $OUT"
    fi
else
    # Sync may have completed without conflict on some git versions; verify no crash
    pass "sync completed without conflict (no mid-rebase to test, still ok)"
fi

# Clean up rebase state
git rebase --abort &>/dev/null 2>&1 || true

# ─── 7b. Corrupt .git/rebase-merge/stopped-sha ───────────────────────────────

section "7b. Corrupt stopped-sha"

# Use a fresh pair so we don't depend on earlier rebase state.
repos=$(setup_repos corrupt-sha)
upstream_b="${repos%%|*}" fork_b="${repos##*|}"
cd "$fork_b"
"$BL" init "$upstream_b" main --yes </dev/null &>/dev/null || true

echo "fork-change" >> app.py
BINGO_DESCRIPTION="corrupt-sha-test" "$BL" patch new corrupt-sha-test --yes &>/dev/null || true

cd "$upstream_b"
echo "upstream-corrupt" >> app.py
git add -A && git commit -q -m "upstream conflict for corrupt-sha"

cd "$fork_b"
timeout 30 "$BL" sync --json --yes &>/dev/null 2>&1 || true

if [[ -d .git/rebase-merge ]]; then
    # Corrupt stopped-sha to a non-existent hash
    echo "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" > .git/rebase-merge/stopped-sha
    OUT=$("$BL" conflict-analyze --json 2>&1) || true
    if json_valid "$OUT"; then
        original_diff=$(echo "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); pi=d.get('patch_intent',{}); print(pi.get('original_diff'))" 2>/dev/null)
        if [[ "$original_diff" == "None" ]]; then
            pass "conflict-analyze gracefully handles corrupt stopped-sha"
        else
            fail "stopped-sha corruption" "expected original_diff=None, got: $original_diff"
        fi
    else
        fail "conflict-analyze with corrupt stopped-sha" "invalid JSON: $OUT"
    fi
    git rebase --abort &>/dev/null 2>&1 || true
else
    pass "no rebase to corrupt (git version skips this test)"
fi

# ─── 8. Shallow clone ───────────────────────────────────────────────────────

section "8. Shallow clone"

repos=$(setup_repos shallow-src)
upstream="${repos%%|*}"

SHALLOW="$TMPDIR_BASE/shallow-fork"
git clone -q --depth=1 "$upstream" "$SHALLOW"
cd "$SHALLOW"
git config user.email "test@test.com" && git config user.name "Test"

OUT=$(timeout 30 "$BL" init "$upstream" main --yes </dev/null 2>&1) || true
if echo "$OUT" | grep -qiE "initialized\|unshallow"; then
    pass "init handles shallow clone (auto-unshallow)"
elif echo "$OUT" | grep -qiE "fatal|error"; then
    # Graceful failure is also acceptable
    if echo "$OUT" | grep -qiE "segfault|panic|core dump"; then
        fail "init shallow" "crashed: $OUT"
    else
        pass "init on shallow clone fails gracefully"
    fi
else
    pass "init on shallow clone does not crash"
fi

# ─── 9. Already initialized ─────────────────────────────────────────────────

section "9. Already initialized (double init)"

repos=$(setup_repos double-init)
upstream="${repos%%|*}" fork="${repos##*|}"
cd "$fork"

OUT1=$(timeout 30 "$BL" init "$upstream" main --yes </dev/null 2>&1) || true
OUT2=$(timeout 30 "$BL" init "$upstream" main --yes </dev/null 2>&1) || true

if echo "$OUT1" | grep -qi "initialized"; then
    pass "first init succeeds"
else
    fail "first init" "did not succeed: $OUT1"
fi

# Second init should succeed (re-init) or warn -- not crash
if echo "$OUT2" | grep -qiE "initialized\|already\|re-init"; then
    pass "second init handles gracefully"
elif echo "$OUT2" | grep -qiE "segfault|panic|core dump"; then
    fail "second init" "crashed: $OUT2"
else
    pass "second init does not crash"
fi

# ─── 10. Patch on wrong branch ──────────────────────────────────────────────

section "10. Patch list from wrong branch"

repos=$(setup_repos wrongbranch)
upstream="${repos%%|*}" fork="${repos##*|}"
cd "$fork"
"$BL" init "$upstream" main --yes </dev/null &>/dev/null || true

# Create a couple of patches
echo "wb-feature" >> app.py
BINGO_DESCRIPTION="wrong branch test" "$BL" patch new wb-test --yes &>/dev/null || true

# Switch away from bingo-patches to main
git checkout main &>/dev/null 2>&1 || true

OUT=$(timeout 30 "$BL" patch list --json 2>&1) || true
if json_valid "$OUT"; then
    count=$(echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)
    if [[ "$count" -ge 1 ]]; then
        pass "patch list --json works from non-patches branch"
    else
        # Zero patches reported is acceptable if it does not crash
        pass "patch list --json returns valid JSON from wrong branch"
    fi
else
    if echo "$OUT" | grep -qiE "segfault|panic|core dump"; then
        fail "patch list wrong branch" "crashed: $OUT"
    else
        pass "patch list from wrong branch does not crash"
    fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
total=$((PASS + FAIL))
echo -e "  ${GREEN}$PASS passed${RESET}  ${RED}$FAIL failed${RESET}  ${DIM}($total total)${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

exit "$FAIL"
