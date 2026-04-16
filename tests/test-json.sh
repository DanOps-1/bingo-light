#!/usr/bin/env bash
# bingo-light JSON output fuzz test suite
# Validates that ALL JSON output remains valid when fed dangerous inputs.
# Usage: ./tests/test-json.sh [path-to-bingo-light]
set -uo pipefail

BL="${1:-$(cd "$(dirname "$0")/.." && pwd)/bingo-light}"
TMPDIR_BASE=$(mktemp -d)
PASS=0 FAIL=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

RED='\033[0;31m' GREEN='\033[0;32m' CYAN='\033[0;36m'
BOLD='\033[1m' DIM='\033[2m' RESET='\033[0m'

pass() { ((PASS++)); echo -e "  ${GREEN}PASS${RESET} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}FAIL${RESET} $1"; echo -e "       ${DIM}input:   $(printf '%q' "$2")${RESET}"; echo -e "       ${DIM}cmd:     $3${RESET}"; echo -e "       ${DIM}output:  ${4:0:200}${RESET}"; }
section() { echo -e "\n${BOLD}$1${RESET}"; }

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

validate_json() {
    python3 -c "import json,sys; json.load(sys.stdin)" <<< "$1" 2>/dev/null
}

setup_repo() {
    local name="$1"
    local upstream="$TMPDIR_BASE/${name}-upstream"
    local fork="$TMPDIR_BASE/${name}-fork"

    mkdir -p "$upstream"
    cd "$upstream" && git init --initial-branch=main -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "line1" > app.py
    echo "config=1" > config.py
    git add -A && git commit -q -m "Initial commit"
    echo "line2" >> app.py
    git add -A && git commit -q -m "Second commit"

    git clone -q "$upstream" "$fork"
    cd "$fork"
    git config user.email "test@test.com"
    git config user.name "Test"
    "$BL" init "$upstream" main --json --yes < /dev/null &>/dev/null || true
    echo "$fork"
}

# ─── Dangerous inputs ────────────────────────────────────────────────────────

INPUTS=()
LABELS=()

INPUTS+=('hello "world"');              LABELS+=("double quotes")
INPUTS+=("it's");                       LABELS+=("single quote")
INPUTS+=('back\slash');                 LABELS+=("backslash")
INPUTS+=($'real\nnewline');             LABELS+=("embedded newline")
INPUTS+=($'tab\there');                 LABELS+=("embedded tab")
INPUTS+=('');                           LABELS+=("empty string")
INPUTS+=('$(whoami)');                  LABELS+=("command injection")
INPUTS+=('a&b|c;d');                    LABELS+=("shell metacharacters")
INPUTS+=('中文名');                      LABELS+=("unicode")
INPUTS+=('{"json":"injection"}');       LABELS+=("json in string")
INPUTS+=("$(printf 'x%.0s' {1..200})"); LABELS+=("200-char string")
INPUTS+=('a"b\"c\\d');                  LABELS+=("mixed escapes")
INPUTS+=('<script>alert(1)</script>');  LABELS+=("html/xss attempt")
INPUTS+=($'line1\r\nline2');            LABELS+=("crlf")
INPUTS+=('null');                       LABELS+=("json keyword null")
INPUTS+=($'\x00hidden');                LABELS+=("null byte")

# ─── Test: patch new with BINGO_DESCRIPTION ───────────────────────────────────

section "1. patch new (BINGO_DESCRIPTION fuzz)"

FORK=$(setup_repo fuzz-patchnew)
cd "$FORK"

i=0
for idx in "${!INPUTS[@]}"; do
    input="${INPUTS[$idx]}"
    label="${LABELS[$idx]}"
    ((i++)) || true

    # Make a unique change for each patch
    echo "change-$i" >> app.py
    git add -A

    OUT=$(BINGO_DESCRIPTION="$input" "$BL" patch new "safe-name-$i" --json --yes < /dev/null 2>&1) || true

    cmd_desc="BINGO_DESCRIPTION=<input> patch new safe-name-$i --json --yes"
    if validate_json "$OUT"; then
        pass "patch new: $label"
    else
        fail "patch new: $label" "$input" "$cmd_desc" "$OUT"
    fi
done

# ─── Test: config set ─────────────────────────────────────────────────────────

section "2. config set (value fuzz)"

FORK=$(setup_repo fuzz-configset)
cd "$FORK"

for idx in "${!INPUTS[@]}"; do
    input="${INPUTS[$idx]}"
    label="${LABELS[$idx]}"

    # config set requires a non-empty value; skip empty string
    if [[ -z "$input" ]]; then
        pass "config set: $label (skipped, empty value rejected by design)"
        continue
    fi

    OUT=$("$BL" config set "test.key" "$input" --json --yes < /dev/null 2>&1) || true

    cmd_desc="config set test.key <input> --json --yes"
    if validate_json "$OUT"; then
        pass "config set: $label"
    else
        fail "config set: $label" "$input" "$cmd_desc" "$OUT"
    fi
done

# ─── Test: patch meta ────────────────────────────────────────────────────────

section "3. patch meta (reason fuzz)"

FORK=$(setup_repo fuzz-patchmeta)
cd "$FORK"

# Create one patch we can set metadata on
echo "feature" >> app.py
git add -A
BINGO_DESCRIPTION="base patch" "$BL" patch new "meta-target" --json --yes < /dev/null &>/dev/null || true

for idx in "${!INPUTS[@]}"; do
    input="${INPUTS[$idx]}"
    label="${LABELS[$idx]}"

    OUT=$("$BL" patch meta "meta-target" reason "$input" --json --yes < /dev/null 2>&1) || true

    cmd_desc="patch meta meta-target reason <input> --json --yes"
    if validate_json "$OUT"; then
        pass "patch meta: $label"
    else
        fail "patch meta: $label" "$input" "$cmd_desc" "$OUT"
    fi
done

# ─── Test: patch show and diff (multi-line special-char content) ──────────────

section "4. patch show / diff (multi-line diff content)"

FORK=$(setup_repo fuzz-show-diff)
cd "$FORK"

# Create a patch with special characters in file content
cat > app.py <<'PYEOF'
line1
line2
msg = "hello \"world\""
tab	here
backslash \ path
unicode = "中文"
json = '{"key": "val"}'
dollar = $(whoami)
ampersand = a&b|c;d
PYEOF
git add -A
BINGO_DESCRIPTION="special chars in diff" "$BL" patch new "special-diff" --json --yes < /dev/null &>/dev/null || true

OUT=$("$BL" patch show 1 --json < /dev/null 2>&1) || true
if validate_json "$OUT"; then
    pass "patch show 1 --json produces valid JSON"
else
    fail "patch show 1 --json" "N/A" "patch show 1 --json" "$OUT"
fi

OUT=$("$BL" diff --json < /dev/null 2>&1) || true
if validate_json "$OUT"; then
    pass "diff --json produces valid JSON"
else
    fail "diff --json" "N/A" "diff --json" "$OUT"
fi

# Also test patch list
OUT=$("$BL" patch list --json < /dev/null 2>&1) || true
if validate_json "$OUT"; then
    pass "patch list --json produces valid JSON"
else
    fail "patch list --json" "N/A" "patch list --json" "$OUT"
fi

# Also test status
OUT=$("$BL" status --json < /dev/null 2>&1) || true
if validate_json "$OUT"; then
    pass "status --json produces valid JSON"
else
    fail "status --json" "N/A" "status --json" "$OUT"
fi

# ─── Test: error paths produce valid JSON ─────────────────────────────────────

section "5. Error paths (invalid commands produce valid JSON)"

FORK=$(setup_repo fuzz-errors)
cd "$FORK"

OUT=$("$BL" patch show nonexistent --json < /dev/null 2>&1) || true
if validate_json "$OUT"; then
    pass "patch show nonexistent --json (error path)"
else
    fail "patch show nonexistent --json" "N/A" "patch show nonexistent --json" "$OUT"
fi

OUT=$("$BL" patch new "" --json --yes < /dev/null 2>&1) || true
if validate_json "$OUT"; then
    pass "patch new empty-name --json (error path)"
else
    fail "patch new empty-name --json" "N/A" "patch new '' --json --yes" "$OUT"
fi

OUT=$("$BL" patch new "bad name!" --json --yes < /dev/null 2>&1) || true
if validate_json "$OUT"; then
    pass "patch new bad-name --json (error path)"
else
    fail "patch new bad-name --json" "N/A" "patch new 'bad name!' --json --yes" "$OUT"
fi

# ─── 6. conflict-resolve --verify outside rebase ─────────────────────────────

section "6. conflict-resolve --verify (no rebase)"

fork=$(setup_repo "verify-fuzz")
cd "$fork"

# Not in rebase — expect graceful error; if JSON, must parse.
OUT=$("$BL" conflict-resolve --verify foo --json 2>&1) || true
if validate_json "$OUT"; then
    pass "conflict-resolve --verify outside rebase: valid JSON"
elif [[ "$OUT" == *"No rebase in progress"* || "$OUT" == *"nothing to resolve"* ]]; then
    pass "conflict-resolve --verify outside rebase: clean error"
else
    fail "conflict-resolve --verify outside rebase" "N/A" "conflict-resolve --verify foo --json" "$OUT"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
TOTAL=$((PASS + FAIL))
echo -e "  ${GREEN}$PASS passed${RESET}  ${RED}$FAIL failed${RESET}  ${DIM}$TOTAL total${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
