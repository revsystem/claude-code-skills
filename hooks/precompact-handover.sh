#!/usr/bin/env bash
set -euo pipefail

# Read hook input (provides session_id, transcript_path, cwd)
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Determine handover directory
if [ -n "$CWD" ] && [ -d "$CWD/.claude" ]; then
  HANDOVER_DIR="$CWD/.claude/handovers"
else
  HANDOVER_DIR="$HOME/.claude/handovers"
fi

TIMESTAMP=$(date '+%Y-%m-%d_%H%M')

cat <<EOF
{
  "systemMessage": "Context compaction is about to happen. Before summarizing, generate a session handover note at ${HANDOVER_DIR}/${TIMESTAMP}.md using the handover skill. Create the directory if needed. If a file with that name already exists, add _2 suffix."
}
EOF

exit 0
