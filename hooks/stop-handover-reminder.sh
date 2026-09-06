#!/usr/bin/env bash
set -euo pipefail

# === 設定 ===========================================================
# 文脈の何%で引き継ぎ（/handover）を促すか。
TRIGGER_PCT=70
# 文脈ウィンドウのトークン数。空のときは下部の case 文が model 名から推定する
# （Opus 5 / Sonnet 5 / Fable 5 / Opus 4.7・4.8 = 1M、それ以外 = 200K）。
# 推定の根拠は Claude Code の仕様（code.claude.com/docs/en/model-config）:
# - Anthropic API 直結なら Fable 5.1 / Fable 5 / Sonnet 5 / Opus 4.7以降 は既定で1M。
#   case 文は 4.7 と 4.8 だけを列挙しているので、新しい Opus 4.x が出たら足す。
#   列挙漏れは200K側に落ちる（促しが早まるだけで、遅れるより実害が小さい）。
# - Sonnet 5 に200K版は無く [1m] サフィックスも不要。Opus 5 には [1m] 指定が存在し、
#   Bedrock / Google Cloud / Foundry 経由では200Kで動く。
# - Sonnet 4.6 と Opus 4.6 は既定200Kで、[1m] 指定のときだけ1Mになる。
# - Opus 4.5以前とHaikuは、ドキュメントの1M対応モデル一覧に載っていない。
# ただし transcript の model 名に [1m] は現れないため（Opus 5 で実測。ドキュメントは
# provider へ送る前に取り除くとだけ書いており transcript には言及していない）、
# 200K版か1M版かは判別できない。1M保証の無い経路（サードパーティ提供、
# ANTHROPIC_BASE_URL のLLM gateway）も同様に model 名からは判別できない。
# 該当する環境と、モデルに関わらず任意の文脈サイズを固定したい場合はここに値を入れる。
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
elif [ "${CLAUDE_CODE_DISABLE_1M_CONTEXT:-}" = "1" ]; then
  # 1M無効化。ネイティブ1Mのモデルも200Kに倒れるので model 判定より先に見る
  CONTEXT_WINDOW=200000
else
  case "$MODEL" in
    # transcript には [1m] を除いた model 名が記録される（例: claude-opus-5）
    *opus-5*|*sonnet-5*|*fable-5*) CONTEXT_WINDOW=1000000 ;;  # Opus 5 / Sonnet 5 / Fable 5 = 既定1M
    *opus-4-7*|*opus-4-8*)         CONTEXT_WINDOW=1000000 ;;  # Opus 4.7 / 4.8 = 既定1M
    # 残りは全てここ。Sonnet 4.6以前、Haiku、未知の model 名、上に無い Opus 4.x を含む。
    # Sonnet 4.6 / Opus 4.6 で [1m] 版を使っている場合は OVERRIDE に 1000000 を書く
    *) CONTEXT_WINDOW=200000 ;;
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
