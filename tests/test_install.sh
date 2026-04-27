#!/usr/bin/env bash
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_BASE}"' EXIT

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_symlink()  { [ -L "$1" ] && pass "$2" || fail "$2: not a symlink"; }
assert_no_entry() { [ ! -e "$1" ] && pass "$2" || fail "$2: should not exist"; }

run_install() {
  local d="${TMPDIR_BASE}/run_${RANDOM}"
  mkdir -p "${d}"
  CLAUDE_CODE_DIR="${d}" bash "${REPO_DIR}/install.sh" "$@" >/dev/null
  echo "${d}"
}

echo "=== Test 1: no args → install hooks and agents (not skills) ==="
d=$(run_install)
assert_symlink  "${d}/agents/terraform-code-reviewer.md"  "agents installed"
assert_symlink  "${d}/hooks/stop-handover-reminder.sh"    "hooks installed"
assert_no_entry "${d}/skills/handover"                    "skills not installed by install.sh"

echo "=== Test 2: agents:terraform-code-reviewer ==="
d=$(run_install agents:terraform-code-reviewer)
assert_symlink  "${d}/agents/terraform-code-reviewer.md"  "agent installed"
assert_no_entry "${d}/hooks/stop-handover-reminder.sh"    "hooks not installed"

echo "=== Test 3: hooks:stop-handover-reminder.sh ==="
d=$(run_install hooks:stop-handover-reminder.sh)
assert_symlink  "${d}/hooks/stop-handover-reminder.sh"    "hook installed"
assert_no_entry "${d}/hooks/precompact-handover.sh"       "other hook not installed"
assert_no_entry "${d}/agents/terraform-code-reviewer.md"  "agents not installed"

echo "=== Test 4: multiple targets ==="
d=$(run_install agents:terraform-code-reviewer hooks:stop-handover-reminder.sh)
assert_symlink  "${d}/agents/terraform-code-reviewer.md"  "agent installed"
assert_symlink  "${d}/hooks/stop-handover-reminder.sh"    "hook installed"
assert_no_entry "${d}/hooks/precompact-handover.sh"       "other hook not installed"

echo "=== Test 5: invalid type → WARNING ==="
warn=$(CLAUDE_CODE_DIR="${TMPDIR_BASE}/t5" bash "${REPO_DIR}/install.sh" skils:foo 2>&1 || true)
echo "${warn}" | grep -q "WARNING" && pass "WARNING on invalid type" || fail "no WARNING on invalid type"

echo "=== Test 6: unknown name → WARNING ==="
warn=$(CLAUDE_CODE_DIR="${TMPDIR_BASE}/t6" bash "${REPO_DIR}/install.sh" agents:nonexistent 2>&1 || true)
echo "${warn}" | grep -q "WARNING" && pass "WARNING on unknown name" || fail "no WARNING on unknown name"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
