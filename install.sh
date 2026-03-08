#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

echo "Installing from: ${REPO_DIR}"

# skills: ディレクトリごと symlink
SKILLS_DST="${CLAUDE_DIR}/skills"
mkdir -p "${SKILLS_DST}"

for skill_dir in "${REPO_DIR}/skills"/*/; do
  [ -d "${skill_dir}" ] || continue
  name=$(basename "${skill_dir}")
  dst="${SKILLS_DST}/${name}"

  if [ -L "${dst}" ]; then
    rm "${dst}"
  elif [ -d "${dst}" ]; then
    echo "WARNING: ${dst} is a real directory. Skipping '${name}'."
    continue
  fi

  ln -sf "${skill_dir}" "${dst}"
  echo "skill: ${name} -> ${dst}"
done

# hooks: ファイルごと symlink + 実行権限
HOOKS_DST="${CLAUDE_DIR}/hooks"
mkdir -p "${HOOKS_DST}"

for hook in "${REPO_DIR}/hooks"/*.sh; do
  [ -f "${hook}" ] || continue
  name=$(basename "${hook}")
  dst="${HOOKS_DST}/${name}"

  if [ -L "${dst}" ]; then
    rm "${dst}"
  elif [ -f "${dst}" ]; then
    echo "WARNING: ${dst} is a real file. Replacing with symlink."
    rm "${dst}"
  fi

  ln -sf "${hook}" "${dst}"
  chmod +x "${hook}"
  echo "hook: ${name} -> ${dst}"
done

echo "Done."
