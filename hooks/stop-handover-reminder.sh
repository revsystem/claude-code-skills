#!/usr/bin/env bash
set -euo pipefail

# === 設定 ===========================================================
# 文脈の何%で引き継ぎ（/handover）を促すか。
TRIGGER_PCT=70
# 文脈ウィンドウのトークン数。空のときは下部で model 名から自動推定する
# （Opus 4.x=1M、Sonnet/Haiku=200K）。Sonnet 4.6 は 200K版/1M版で model 名が
# 同一で自動判別できないため、1M版を使う場合はここに明示する（例: 1000000）。
# モデルに関わらず任意の文脈サイズを固定したい場合もここに値を入れる。
CONTEXT_WINDOW_OVERRIDE=""
# ====================================================================

INPUT=$(cat)

# stop_hook_active=true のときは無限ループを防ぐためスキップ
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')

# 1セッションにつき1回だけ発火するフラグファイル
FLAG_FILE="/tmp/claude-handover-triggered-${SESSION_ID}"
if [ -f "$FLAG_FILE" ]; then
  exit 0
fi

# トランスクリプトファイルが存在しない場合はスキップ
if [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# --- live コンテキストのトークン数を算出 ---------------------------------
# Stop フックの入力には文脈使用率が含まれないため、トランスクリプト末尾の
# assistant メッセージが記録する usage から live コンテキスト相当を求める。
# input + cache_read + cache_creation は、その turn のプロンプト規模であり
# 現在の文脈トークン数にほぼ一致する（ステータスライン表示値と整合）。
# jq -s でファイルを直接読む（パイプ + head を使わない）ことで、pipefail と
# SIGPIPE による誤爆を避ける。usage を持つ最後のメッセージを採用する。
USAGE_TSV=$(jq -s -rc '
  (map(select(.message.usage? != null)) | last) as $m
  | if $m == null then empty
    else [ (($m.message.usage.input_tokens // 0)
            + ($m.message.usage.cache_read_input_tokens // 0)
            + ($m.message.usage.cache_creation_input_tokens // 0)),
           ($m.message.model // "unknown") ] | @tsv
    end
' "$TRANSCRIPT" 2>/dev/null || true)

# usage が取れなければ判定不能としてスキップ（誤発火しない方に倒す）
if [ -z "$USAGE_TSV" ]; then
  exit 0
fi
IFS=$'\t' read -r CTX_TOKENS MODEL <<< "$USAGE_TSV"
if ! [[ "${CTX_TOKENS:-}" =~ ^[0-9]+$ ]] || [ "$CTX_TOKENS" -le 0 ]; then
  exit 0
fi

# --- 文脈ウィンドウの決定（OVERRIDE 優先、無ければ model から自動推定） ---
if [ -n "$CONTEXT_WINDOW_OVERRIDE" ]; then
  CONTEXT_WINDOW="$CONTEXT_WINDOW_OVERRIDE"
else
  case "$MODEL" in
    *opus-4-*) CONTEXT_WINDOW=1000000 ;;  # Opus 4.x = 1M
    *)         CONTEXT_WINDOW=200000  ;;  # Sonnet/Haiku 既定 = 200K（Sonnet 1M は OVERRIDE で指定）
  esac
fi

THRESHOLD=$(( CONTEXT_WINDOW * TRIGGER_PCT / 100 ))

if [ "$CTX_TOKENS" -gt "$THRESHOLD" ]; then
  touch "$FLAG_FILE"
  USED_PCT=$(( CTX_TOKENS * 100 / CONTEXT_WINDOW ))
  cat <<EOF
{
  "decision": "block",
  "reason": "Context is getting full (~${CTX_TOKENS} tokens, ~${USED_PCT}% of ${CONTEXT_WINDOW}). Please run the /handover skill now to save the session state before context is compacted. Also consider if any non-obvious findings from this session (gotchas, new model capabilities, workflow improvements) should be added to CLAUDE.md."
}
EOF
fi

exit 0
