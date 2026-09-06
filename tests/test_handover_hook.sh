#!/usr/bin/env bash
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${REPO_DIR}/hooks/stop-handover-reminder.sh"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_BASE}"' EXIT

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# model 名と live トークン数を与えてフックの標準出力を返す。
# セッションIDを毎回変えるのは、1セッション1回のフラグファイルが残ると
# 以降の実行が黙って exit 0 し「発火しなかった」と誤読されるため。
run_hook() {
  local model="$1" tokens="$2" disable_1m="${3:-}"
  local sid="test-${RANDOM}-${RANDOM}"
  local transcript="${TMPDIR_BASE}/${sid}.jsonl"
  printf '{"message":{"model":"%s","usage":{"input_tokens":%s}}}\n' "${model}" "${tokens}" > "${transcript}"
  # 環境変数は常に明示的に渡す。未指定時に親シェルから継承すると、開発者の
  # シェルに CLAUDE_CODE_DISABLE_1M_CONTEXT=1 があるだけで結果が反転する。
  printf '{"session_id":"%s","transcript_path":"%s"}' "${sid}" "${transcript}" \
    | CLAUDE_CODE_DISABLE_1M_CONTEXT="${disable_1m}" bash "${HOOK}"
  rm -f "/tmp/claude-handover-triggered-${sid}"
}

# 発火の有無だけでなく reason に載るウィンドウ値も見る。
# トークン数が大きいと 200K/1M どちらの判定でも発火し、有無だけでは検証にならない。
assert_window() {
  local out="$1" want="$2" desc="$3"
  case "${out}" in
    *"of ${want})"*) pass "${desc}" ;;
    "")              fail "${desc}: 発火しなかった（期待: ${want} で発火）" ;;
    *)               fail "${desc}: 期待ウィンドウ ${want} 以外の出力: ${out}" ;;
  esac
}

assert_silent() {
  [ -z "$1" ] && pass "$2" || fail "$2: 発火した: $1"
}

echo "=== Test 1: 1M モデルは 300K では発火しない ==="
assert_silent "$(run_hook claude-opus-5    300000)" "Opus 5 = 1M"
assert_silent "$(run_hook claude-sonnet-5  300000)" "Sonnet 5 = 1M"
assert_silent "$(run_hook claude-fable-5   300000)" "Fable 5 = 1M"
assert_silent "$(run_hook claude-fable-5-1 300000)" "Fable 5.1 = 1M"
assert_silent "$(run_hook claude-opus-4-8  300000)" "Opus 4.8 = 1M"
assert_silent "$(run_hook claude-opus-4-7  300000)" "Opus 4.7 = 1M"

echo "=== Test 2: 1M モデルは閾値（70%）超えで 1M として発火する ==="
assert_window "$(run_hook claude-opus-5   800000)" 1000000 "Opus 5 発火時のウィンドウ"
assert_window "$(run_hook claude-sonnet-5 800000)" 1000000 "Sonnet 5 発火時のウィンドウ"

echo "=== Test 3: 200K 既定のモデルは 300K で 200K として発火する ==="
assert_window "$(run_hook claude-sonnet-4-6 300000)" 200000 "Sonnet 4.6 = 200K"
assert_window "$(run_hook claude-haiku-4-5  300000)" 200000 "Haiku 4.5 = 200K"
assert_window "$(run_hook unknown           300000)" 200000 "未知モデルは 200K に倒す"
# *sonnet-5* を *sonnet-*5* のように緩めると、旧 Sonnet が 1M 判定に化ける
assert_window "$(run_hook claude-sonnet-4-5          300000)" 200000 "Sonnet 4.5 は 1M 分岐に当たらない"
assert_window "$(run_hook claude-sonnet-4-5-20250929 300000)" 200000 "日付付き旧 Sonnet も 200K"
# Opus 4.6 は既定200K（1Mは [1m] 指定時のみ）。*opus-4-* に戻すとここが 1M に化ける
assert_window "$(run_hook claude-opus-4-6            300000)" 200000 "Opus 4.6 = 既定200K"
assert_window "$(run_hook claude-opus-4-5            300000)" 200000 "Opus 4.5 = 200K"
assert_window "$(run_hook claude-opus-4-5-20251101   300000)" 200000 "日付付き旧 Opus も 200K"

echo "=== Test 4: CLAUDE_CODE_DISABLE_1M_CONTEXT=1 は全モデルを 200K に倒す ==="
assert_window "$(run_hook claude-opus-5     300000 1)" 200000 "Opus 5 + 1M無効化"
assert_window "$(run_hook claude-sonnet-5   300000 1)" 200000 "Sonnet 5 + 1M無効化"
assert_window "$(run_hook claude-fable-5    300000 1)" 200000 "Fable 5 + 1M無効化"
assert_window "$(run_hook claude-opus-4-8   300000 1)" 200000 "Opus 4.8 + 1M無効化"
assert_window "$(run_hook claude-sonnet-4-6 300000 1)" 200000 "200Kモデルは変化なし"

echo "=== Test 5: 判定不能な入力ではスキップする ==="
assert_silent "$(printf '{"session_id":"x","transcript_path":"/nonexistent.jsonl"}' | bash "${HOOK}")" \
  "transcript が無ければスキップ"
assert_silent "$(printf '{"session_id":"x","stop_hook_active":true,"transcript_path":"/nonexistent.jsonl"}' | bash "${HOOK}")" \
  "stop_hook_active=true ならスキップ"

echo
echo "PASS: ${PASS}, FAIL: ${FAIL}"
[ "${FAIL}" -eq 0 ]
