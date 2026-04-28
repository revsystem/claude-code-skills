#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

# stop_hook_active=true のときは無限ループを防ぐためスキップ
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# 1セッションにつき1回だけ発火するフラグファイル
FLAG_FILE="/tmp/claude-handover-triggered-${SESSION_ID}"
if [ -f "$FLAG_FILE" ]; then
  exit 0
fi

# トランスクリプトファイルが存在しない場合はスキップ
if [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

SIZE=$(wc -c < "$TRANSCRIPT")
# 閾値: 1MB (Sonnet 4.6の600Kトークンコンテキストに対して約60-65%が埋まった目安)
THRESHOLD=1000000

if [ "$SIZE" -gt "$THRESHOLD" ]; then
  touch "$FLAG_FILE"
  cat <<EOF
{
  "decision": "block",
  "reason": "Context is getting full (transcript: ${SIZE} bytes). Please run the /handover skill now to save the session state before context is compacted."
}
EOF
fi

exit 0
