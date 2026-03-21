#!/usr/bin/env bash
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CODE_DIR:-${HOME}/.claude}"

echo "Installing from: ${REPO_DIR}"

# --- ヘルパー関数 ---

install_skill() {
  local skill_dir="$1"
  local name
  name=$(basename "${skill_dir}")
  local dst="${SKILLS_DST}/${name}"

  if [ -L "${dst}" ]; then rm "${dst}"
  elif [ -d "${dst}" ]; then echo "WARNING: ${dst} is a real directory. Skipping '${name}'." >&2; return; fi

  ln -sf "${skill_dir}" "${dst}"
  echo "skill: ${name} -> ${dst}"
}

resolve_hooks() {
  local skill_dir="$1"
  local skill_md="${skill_dir}SKILL.md"
  [ -f "${skill_md}" ] || return 0
  awk 'BEGIN{f=0;h=0} /^---$/{f++;next} f==1 && /^hooks:/{h=1;next} f==1 && h && /^  - /{print $2;next} f==1 && h{h=0}' "${skill_md}"
}

install_hook() {
  local hook="$1"
  local name
  name=$(basename "${hook}")
  local dst="${HOOKS_DST}/${name}"

  if [ -L "${dst}" ]; then rm "${dst}"
  elif [ -f "${dst}" ]; then echo "WARNING: ${dst} is a real file. Replacing with symlink." >&2; rm "${dst}"; fi

  ln -sf "${hook}" "${dst}"
  chmod +x "${hook}"
  echo "hook: ${name} -> ${dst}"
}

install_agent() {
  local agent_file="$1"
  local name
  name=$(basename "${agent_file}")
  local dst="${AGENTS_DST}/${name}"

  if [ -L "${dst}" ]; then rm "${dst}"
  elif [ -f "${dst}" ]; then echo "WARNING: ${dst} is a real file. Replacing with symlink." >&2; rm "${dst}"; fi

  ln -sf "${agent_file}" "${dst}"
  echo "agent: ${name} -> ${dst}"
}

# --- 引数なし → 全件インストール ---

if [ $# -eq 0 ]; then
  SKILLS_DST="${CLAUDE_DIR}/skills"
  mkdir -p "${SKILLS_DST}"
  for skill_dir in "${REPO_DIR}/skills"/*/; do
    [ -d "${skill_dir}" ] || continue
    install_skill "${skill_dir}"
  done

  HOOKS_DST="${CLAUDE_DIR}/hooks"
  mkdir -p "${HOOKS_DST}"
  for hook in "${REPO_DIR}/hooks"/*.sh; do
    [ -f "${hook}" ] || continue
    install_hook "${hook}"
  done

  AGENTS_DST="${CLAUDE_DIR}/agents"
  mkdir -p "${AGENTS_DST}"
  for agent_file in "${REPO_DIR}/agents"/*.md; do
    [ -f "${agent_file}" ] || continue
    install_agent "${agent_file}"
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

# skills + hooks 依存解決
if [ ${#INSTALL_SKILLS[@]} -gt 0 ]; then
  SKILLS_DST="${CLAUDE_DIR}/skills"
  mkdir -p "${SKILLS_DST}"
  for name in "${INSTALL_SKILLS[@]}"; do
    skill_dir="${REPO_DIR}/skills/${name}/"
    if [ ! -d "${skill_dir}" ]; then
      echo "WARNING: unknown skill '${name}'" >&2
      continue
    fi
    install_skill "${skill_dir}"
    while IFS= read -r hook_name; do
      [ -n "${hook_name}" ] || continue
      INSTALL_HOOKS+=("${hook_name}")
    done < <(resolve_hooks "${skill_dir}")
  done
fi

# agents
if [ ${#INSTALL_AGENTS[@]} -gt 0 ]; then
  AGENTS_DST="${CLAUDE_DIR}/agents"
  mkdir -p "${AGENTS_DST}"
  for name in "${INSTALL_AGENTS[@]}"; do
    agent_file="${REPO_DIR}/agents/${name}.md"
    if [ ! -f "${agent_file}" ]; then
      echo "WARNING: unknown agent '${name}'" >&2
      continue
    fi
    install_agent "${agent_file}"
  done
fi

# hooks (明示指定 + 依存解決分、重複除去)
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
    install_hook "${hook}"
    INSTALLED_HOOKS="${INSTALLED_HOOKS} ${name}"
  done
fi

echo "Done."
