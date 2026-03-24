# install.sh CLI Args Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `install.sh` に `TYPE:NAME` 形式の引数を追加し、個別インストールを可能にする。

**Architecture:** 引数なし=全件インストール（現状維持）。引数あり=指定された TYPE:NAME のみインストール。skills インストール時に SKILL.md の `hooks:` フィールドから依存 hooks を自動解決する。

**Tech Stack:** bash, awk (frontmatter パース)

---

## ファイルマップ

| 操作 | パス | 役割 |
| --- | --- | --- |
| Modify | `install.sh` | 引数パース・選択的インストール |
| Modify | `skills/handover/SKILL.md` | `hooks:` フィールド追加 |
| Create | `tests/test_install.sh` | 回帰テスト |

---

### Task 1: SKILL.md に hooks フィールドを追加

**Files:**
- Modify: `skills/handover/SKILL.md`

- [ ] **Step 1: frontmatter に hooks フィールドを追記**

```yaml
---
name: handover
description: Use when the user runs /handover, when a session is ending, when context compaction is about to happen, or when the user asks to generate a session summary, handover note, or 引き継ぎノート. Also use when context is running low and key decisions should be preserved before they are lost.
hooks:
  - stop-handover-reminder.sh
  - precompact-handover.sh
---
```

- [ ] **Step 2: awk でパースできることを確認**

```bash
awk '/^---$/{f++; next} f==1 && /^hooks:/{h=1; next} f==1 && h && /^  - /{print $2; next} f==1 && h && !/^  /{h=0}' skills/handover/SKILL.md
```

期待出力:

```text
stop-handover-reminder.sh
precompact-handover.sh
```

- [ ] **Step 3: コミット**

```bash
git add skills/handover/SKILL.md
git commit -m "feat: add hooks dependency declaration to handover SKILL.md"
```

---

### Task 2: テストスクリプトを作成

**Files:**
- Create: `tests/test_install.sh`

- [ ] **Step 1: テストスクリプトを作成**

```bash
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

echo "=== Test 1: no args → install everything ==="
d=$(run_install)
assert_symlink  "${d}/skills/handover"                    "skills/handover installed"
assert_symlink  "${d}/agents/terraform-code-reviewer.md"  "agents installed"
assert_symlink  "${d}/hooks/stop-handover-reminder.sh"    "hooks installed"

echo "=== Test 2: skills:handover → skill + dep hooks ==="
d=$(run_install skills:handover)
assert_symlink  "${d}/skills/handover"                    "handover installed"
assert_symlink  "${d}/hooks/stop-handover-reminder.sh"    "dep hook installed"
assert_symlink  "${d}/hooks/precompact-handover.sh"       "dep hook installed"
assert_no_entry "${d}/agents/terraform-code-reviewer.md"  "agents not installed"

echo "=== Test 3: agents:terraform-code-reviewer ==="
d=$(run_install agents:terraform-code-reviewer)
assert_symlink  "${d}/agents/terraform-code-reviewer.md"  "agent installed"
assert_no_entry "${d}/skills/handover"                    "skills not installed"
assert_no_entry "${d}/hooks/stop-handover-reminder.sh"    "hooks not installed"

echo "=== Test 4: hooks:stop-handover-reminder.sh ==="
d=$(run_install hooks:stop-handover-reminder.sh)
assert_symlink  "${d}/hooks/stop-handover-reminder.sh"    "hook installed"
assert_no_entry "${d}/hooks/precompact-handover.sh"       "other hook not installed"
assert_no_entry "${d}/skills/handover"                    "skills not installed"

echo "=== Test 5: multiple targets ==="
d=$(run_install skills:handover agents:terraform-code-reviewer)
assert_symlink  "${d}/skills/handover"                    "skill installed"
assert_symlink  "${d}/agents/terraform-code-reviewer.md"  "agent installed"
assert_symlink  "${d}/hooks/stop-handover-reminder.sh"    "dep hook installed"

echo "=== Test 6: invalid type → WARNING ==="
warn=$(CLAUDE_CODE_DIR="${TMPDIR_BASE}/t6" bash "${REPO_DIR}/install.sh" skils:foo 2>&1 || true)
echo "${warn}" | grep -q "WARNING" && pass "WARNING on invalid type" || fail "no WARNING on invalid type"

echo "=== Test 7: unknown name → WARNING ==="
warn=$(CLAUDE_CODE_DIR="${TMPDIR_BASE}/t7" bash "${REPO_DIR}/install.sh" skills:nonexistent 2>&1 || true)
echo "${warn}" | grep -q "WARNING" && pass "WARNING on unknown name" || fail "no WARNING on unknown name"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
```

- [ ] **Step 2: 実行権限を付与し失敗を確認**

```bash
chmod +x tests/test_install.sh
bash tests/test_install.sh 2>&1 || true
```

期待: テスト 2〜7 が FAIL（現在の install.sh は引数を無視して全件インストールするため）

---

### Task 3: install.sh を書き換える

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: install.sh を以下の内容に書き換える**

```bash
#!/usr/bin/env bash
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CODE_DIR:-${HOME}/.claude}"

echo "Installing from: ${REPO_DIR}"

# --- 引数なし → 全件インストール ---
if [ $# -eq 0 ]; then
  # skills
  SKILLS_DST="${CLAUDE_DIR}/skills"
  mkdir -p "${SKILLS_DST}"
  for skill_dir in "${REPO_DIR}/skills"/*/; do
    [ -d "${skill_dir}" ] || continue
    name=$(basename "${skill_dir}")
    dst="${SKILLS_DST}/${name}"
    if [ -L "${dst}" ]; then rm "${dst}"
    elif [ -d "${dst}" ]; then echo "WARNING: ${dst} is a real directory. Skipping '${name}'." >&2; continue; fi
    ln -sf "${skill_dir}" "${dst}"
    echo "skill: ${name} -> ${dst}"
  done

  # hooks
  HOOKS_DST="${CLAUDE_DIR}/hooks"
  mkdir -p "${HOOKS_DST}"
  for hook in "${REPO_DIR}/hooks"/*.sh; do
    [ -f "${hook}" ] || continue
    name=$(basename "${hook}")
    dst="${HOOKS_DST}/${name}"
    if [ -L "${dst}" ]; then rm "${dst}"
    elif [ -f "${dst}" ]; then echo "WARNING: ${dst} is a real file. Replacing with symlink." >&2; rm "${dst}"; fi
    ln -sf "${hook}" "${dst}"
    chmod +x "${hook}"
    echo "hook: ${name} -> ${dst}"
  done

  # agents
  AGENTS_DST="${CLAUDE_DIR}/agents"
  mkdir -p "${AGENTS_DST}"
  for agent_file in "${REPO_DIR}/agents"/*.md; do
    [ -f "${agent_file}" ] || continue
    name=$(basename "${agent_file}")
    dst="${AGENTS_DST}/${name}"
    if [ -L "${dst}" ]; then rm "${dst}"
    elif [ -f "${dst}" ]; then echo "WARNING: ${dst} is a real file. Replacing with symlink." >&2; rm "${dst}"; fi
    ln -sf "${agent_file}" "${dst}"
    echo "agent: ${name} -> ${dst}"
  done

  echo "Done."
  exit 0
fi

# --- 引数あり → 選択的インストール ---
INSTALL_SKILLS=()
INSTALL_AGENTS=()
INSTALL_HOOKS=()

for arg in "$@"; do
  if [[ "${arg}" != *:* ]]; then
    echo "WARNING: invalid argument '${arg}' (expected TYPE:NAME format)" >&2
    continue
  fi
  type="${arg%%:*}"
  name="${arg#*:}"
  case "${type}" in
    skills) INSTALL_SKILLS+=("${name}") ;;
    agents) INSTALL_AGENTS+=("${name}") ;;
    hooks)  INSTALL_HOOKS+=("${name}") ;;
    *)      echo "WARNING: unknown type '${type}' (from '${arg}')" >&2 ;;
  esac
done

# skills インストール + hooks 依存解決
if [ ${#INSTALL_SKILLS[@]} -gt 0 ]; then
  SKILLS_DST="${CLAUDE_DIR}/skills"
  mkdir -p "${SKILLS_DST}"
  for name in "${INSTALL_SKILLS[@]}"; do
    skill_dir="${REPO_DIR}/skills/${name}/"
    if [ ! -d "${skill_dir}" ]; then
      echo "WARNING: unknown skill '${name}'" >&2
      continue
    fi
    dst="${SKILLS_DST}/${name}"
    if [ -L "${dst}" ]; then rm "${dst}"
    elif [ -d "${dst}" ]; then echo "WARNING: ${dst} is a real directory. Skipping '${name}'." >&2; continue; fi
    ln -sf "${skill_dir}" "${dst}"
    echo "skill: ${name} -> ${dst}"

    # hooks 依存解決
    skill_md="${skill_dir}SKILL.md"
    if [ -f "${skill_md}" ]; then
      while IFS= read -r hook_name; do
        [ -n "${hook_name}" ] || continue
        INSTALL_HOOKS+=("${hook_name}")
      done < <(awk '/^---$/{f++; next} f==1 && /^hooks:/{h=1; next} f==1 && h && /^  - /{print $2; next} f==1 && h && !/^  /{h=0}' "${skill_md}")
    fi
  done
fi

# agents インストール
if [ ${#INSTALL_AGENTS[@]} -gt 0 ]; then
  AGENTS_DST="${CLAUDE_DIR}/agents"
  mkdir -p "${AGENTS_DST}"
  for name in "${INSTALL_AGENTS[@]}"; do
    agent_file="${REPO_DIR}/agents/${name}.md"
    if [ ! -f "${agent_file}" ]; then
      echo "WARNING: unknown agent '${name}'" >&2
      continue
    fi
    dst="${AGENTS_DST}/${name}.md"
    if [ -L "${dst}" ]; then rm "${dst}"
    elif [ -f "${dst}" ]; then echo "WARNING: ${dst} is a real file. Replacing with symlink." >&2; rm "${dst}"; fi
    ln -sf "${agent_file}" "${dst}"
    echo "agent: ${name}.md -> ${dst}"
  done
fi

# hooks インストール
if [ ${#INSTALL_HOOKS[@]} -gt 0 ]; then
  HOOKS_DST="${CLAUDE_DIR}/hooks"
  mkdir -p "${HOOKS_DST}"
  INSTALLED_HOOKS=""
  for name in "${INSTALL_HOOKS[@]}"; do
    echo "${INSTALLED_HOOKS}" | grep -qF "${name}" && continue
    hook="${REPO_DIR}/hooks/${name}"
    if [ ! -f "${hook}" ]; then
      echo "WARNING: hook file not found: '${name}'" >&2
      continue
    fi
    dst="${HOOKS_DST}/${name}"
    if [ -L "${dst}" ]; then rm "${dst}"
    elif [ -f "${dst}" ]; then echo "WARNING: ${dst} is a real file. Replacing with symlink." >&2; rm "${dst}"; fi
    ln -sf "${hook}" "${dst}"
    chmod +x "${hook}"
    echo "hook: ${name} -> ${dst}"
    INSTALLED_HOOKS="${INSTALLED_HOOKS} ${name}"
  done
fi

echo "Done."
```

- [ ] **Step 2: 全テストを実行して全 PASS を確認**

```bash
bash tests/test_install.sh
```

期待出力:

```text
Results: 19 passed, 0 failed
```

- [ ] **Step 3: 引数なしで従来通り動くか確認**

```bash
bash install.sh
```

- [ ] **Step 4: コミット**

```bash
git add install.sh tests/test_install.sh
git commit -m "feat: add selective install via TYPE:NAME args to install.sh"
```
