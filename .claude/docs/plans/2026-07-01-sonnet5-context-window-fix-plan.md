# Sonnet 5 コンテキストウィンドウ対応 実装計画

日時: 2026-07-01
関連調査: `.claude/docs/research/2026-07-01-sonnet5-context-window-research.md`

## 概要
- `hooks/stop-handover-reminder.sh` のモデル→context window推定ロジックに、Sonnet 5専用の分岐（1M固定）を追加する
- 現状はSonnet系をすべてデフォルト分岐（200K）に落としており、Sonnet 5利用時に実際の1Mに対して過小評価してしまうバグを修正するため

## アプローチ
- 既存の `case "$MODEL" in ... esac` パターンを踏襲し、Fable 5導入時（commit `9cf02fe`）と同じ形で `*sonnet-5*` の分岐を追加する
- 代替案（デフォルト分岐の200Kをそのまま1Mに変更する等）は、Sonnet 4.6以前とHaikuを巻き添えで誤判定させるため採用しない。既存モデルへの影響がない形で、`*sonnet-5*` 分岐を1つ追加するに留める（`CLAUDE_CODE_DISABLE_1M_CONTEXT` 判定を含むため分岐自体は複数行のif文になる。既存分岐の記述量とは変わらない）

## 変更内容

### 変更1: 設定ブロックのコメント修正
対象: `hooks/stop-handover-reminder.sh`（7〜10行目）

現状（前回セッションで「Sonnet 4.6」→「Sonnet 5」に書き換え済みだが、内容が不正確）:
```bash
# 文脈ウィンドウのトークン数。空のときは下部で model 名から自動推定する
# （Opus 4.x / Fable 5=1M、Sonnet/Haiku=200K）。Sonnet 5 は 200K版/1M版で
# model 名が同一で自動判別できないため、1M版を使う場合はここに明示する（例: 1000000）。
# モデルに関わらず任意の文脈サイズを固定したい場合もここに値を入れる。
```

変更後:
```bash
# 文脈ウィンドウのトークン数。空のときは下部で model 名から自動推定する
# （Opus 4.x / Fable 5 / Sonnet 5 = 1M、Sonnet 4.6以前・Haiku = 200K）。
# Sonnet 4.6以前は200K版/1M版で model 名が同一で自動判別できないため、
# 1M版（[1m]サフィックス指定時）を使う場合はここに明示する（例: 1000000）。
# Sonnet 5 は常に1M（200K版は存在しない）だが、環境変数
# CLAUDE_CODE_DISABLE_1M_CONTEXT=1 で200Kに強制している場合は下記 case 文で自動的に200Kへ倒す。
# ANTHROPIC_BASE_URL 経由でLLM gatewayを使っている場合も1M保証されないが、
# gateway判定の精度が低いためhookでは自動判別しない（既知の制約）。該当環境では200000を指定する。
# モデルに関わらず任意の文脈サイズを固定したい場合もここに値を入れる。
CONTEXT_WINDOW_OVERRIDE=""
```

### 変更2: case文にSonnet 5分岐を追加（CLAUDE_CODE_DISABLE_1M_CONTEXT対応込み）
対象: `hooks/stop-handover-reminder.sh`（66〜70行目）

現状:
```bash
  case "$MODEL" in
    *opus-4-*)  CONTEXT_WINDOW=1000000 ;;  # Opus 4.x = 1M
    *fable-5*)  CONTEXT_WINDOW=1000000 ;;  # Fable 5 = 1M（transcript には claude-fable-5 と記録される）
    *)          CONTEXT_WINDOW=200000  ;;  # Sonnet/Haiku 既定 = 200K（Sonnet 1M は OVERRIDE で指定）
  esac
```

変更後（論点1の回答Bを反映。`CLAUDE_CODE_DISABLE_1M_CONTEXT=1` の場合はSonnet 5でも200Kに倒す）:
```bash
  case "$MODEL" in
    *opus-4-*) CONTEXT_WINDOW=1000000 ;;  # Opus 4.x = 1M
    *fable-5*) CONTEXT_WINDOW=1000000 ;;  # Fable 5 = 1M（transcript には claude-fable-5 と記録される）
    *sonnet-5*)
      if [ "${CLAUDE_CODE_DISABLE_1M_CONTEXT:-}" = "1" ]; then
        CONTEXT_WINDOW=200000   # Sonnet 5だが CLAUDE_CODE_DISABLE_1M_CONTEXT=1 で200Kに強制されている
      else
        CONTEXT_WINDOW=1000000  # Sonnet 5 = 1M固定（200K版は存在しない）
      fi
      ;;
    *) CONTEXT_WINDOW=200000 ;;  # Sonnet 4.6以前/Haiku 既定 = 200K（1M版は OVERRIDE で指定）
  esac
```

`claude-sonnet-5` は `*opus-4-*` にも `*fable-5*` にもマッチせず、`claude-sonnet-4-5`（Sonnet 4.5）や `claude-sonnet-4-6`（Sonnet 4.6）の文字列は `sonnet-5` を部分文字列として含まないため、新しい分岐が既存モデルの判定に影響することはない（research.md「注意点・リスク」参照）。

`CLAUDE_CODE_DISABLE_1M_CONTEXT` はhookプロセスがClaude Codeの子プロセスとして起動される際に環境変数が継承される前提に立っている。未設定時は `${VAR:-}` により空文字列として扱われ、`"1"` との比較で安全にfalseになる（`set -u` 相当の未定義変数エラーを回避）。

## 検証手順
- 構文チェック: `bash -n hooks/stop-handover-reminder.sh`
- モデル名×環境変数の組み合わせで期待値を手動確認する（`case`文部分を切り出したテストスクリプトで検証）:
  - `MODEL=claude-sonnet-5`, env未設定 → `CONTEXT_WINDOW=1000000`
  - `MODEL=claude-sonnet-5`, `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` → `CONTEXT_WINDOW=200000`
  - `MODEL=claude-sonnet-4-6`（サフィックスなし） → 引き続き `CONTEXT_WINDOW=200000`（誤マッチしないこと）
  - `MODEL=claude-opus-4-8`, `MODEL=claude-fable-5` → 既存分岐が変わらず機能すること
- 実装前チェック（未実施・要検証）: 実際のClaude Code環境でStopフック実行時に `CLAUDE_CODE_DISABLE_1M_CONTEXT` がhookの子プロセスに継承されるかを確認する。確認方法の一例: 一時的にhookスクリプト冒頭に `echo "DEBUG: DISABLE_1M=${CLAUDE_CODE_DISABLE_1M_CONTEXT:-<unset>}" >> /tmp/hook-debug.log` を追加し、`CLAUDE_CODE_DISABLE_1M_CONTEXT=1` を設定したシェルからセッションを開始して実際に値が渡るかログで確認する（検証後は追加したデバッグ行を削除する）
- 継承が確認できなかった場合は論点1の選択（B）を見直し、Aに切り替える必要がある

## 影響範囲
- 既存テスト: `tests/test_install.sh` はinstall.shのシンボリックリンク回帰テストであり、このフックのロジックはテスト対象外。今回の変更で既存テストへの影響はない
- API変更: なし（bashスクリプト内部ロジックのみ）
- マイグレーション: なし。次回Stopフック発火時から新ロジックが有効になる

## 考慮事項
- パフォーマンス: 影響なし（`case`文の分岐が1つ増えるのみ）
- セキュリティ: 影響なし
- 後方互換性: Sonnet 4.6以前・Opus・Fable 5・Haikuの既存判定ロジックは変更しないため後方互換
- 設計トレードオフ: Sonnet 5は約967Kでauto-compactが発生するため、1M×70%=700Kという現行の閾値はauto-compactより手前で`/handover`を促す設計として妥当（research.md「参考情報」参照）

## 決定事項（annotationで確定済み）

### 論点1: `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` を自動検知するか — B案（自動検知）を採用

Sonnet 5は通常1M固定だが、ユーザーが環境変数 `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` を設定している場合は実際には200Kで動作する（claude-code-guideエージェントの調査結果より）。

検討した選択肢:
- A. 何もしない。ユーザーが `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` を設定している場合は `CONTEXT_WINDOW_OVERRIDE=200000` を手動設定してもらう — 利点: シンプル、他の分岐と同じ「稀なケースはOVERRIDEで対応」という設計方針に一貫する / 欠点: 気づかないと`/handover`推奨が遅れる方向のズレ（危険側）になる
- B. hookスクリプト内で `CLAUDE_CODE_DISABLE_1M_CONTEXT` 環境変数を確認し、`1`ならSonnet 5分岐でも200Kに倒す — 利点: ユーザーの手動設定が不要になり実態と自動的に一致する / 欠点: 環境変数がhookプロセスに確実に継承されるかは未検証（→「検証手順」参照）

初期推奨はA（シンプルさ優先）だったが、`CLAUDE_CODE_DISABLE_1M_CONTEXT` が公式に文書化された設定名でありSonnet 4.6の`[1m]`サフィックス（transcript消失）より検知しやすいこと、ズレの方向が危険側（handover遅延）であることから、annotationサイクルで**B案を採用**することが確定した。変更2に反映済み。

**実機検証結果（2026-07-02実施）:** `export CLAUDE_CODE_DISABLE_1M_CONTEXT=1` を設定した別セッションでStopフックを発火させ、デバッグログで環境変数が子プロセスに継承されることを確認した（タスクリスト ユニットC参照）。B案の前提は裏付けられ、Aへのフォールバックは不要と判明した。

### 論点2: LLM Gateway（`ANTHROPIC_BASE_URL`）利用時の扱い — A案（スコープ外）を採用

公式ドキュメントより、`ANTHROPIC_BASE_URL` がLLM gatewayを指している場合もSonnet 5の1Mサポートが検証できず200K扱いになる（research.md §3-2参照）。論点1と同様の「危険側のズレ」が起こりうるが、`ANTHROPIC_BASE_URL` は他の目的（プロキシ等）でも設定されるため、非空＝200Kと単純化すると誤検知（false positive）のリスクがある。

検討した選択肢:
- A. スコープ外とする。`ANTHROPIC_BASE_URL` 利用者は `CONTEXT_WINDOW_OVERRIDE=200000` で手動対応する — 利点: 誤検知リスクを避けられる、今回のスコープ（Sonnet 5基本対応）を超えない / 欠点: Gateway利用者は今回のfix後も`/handover`推奨が遅れたままになりうる
- B. hook内で `ANTHROPIC_BASE_URL` が非空なら（gatewayの可能性があるため）Sonnet 5でも200Kに倒す — 利点: 論点1(B)と一貫した「危険側を避ける」設計 / 欠点: `ANTHROPIC_BASE_URL`を他用途（プロキシ等、1M対応済みgateway等）で設定しているユーザーには過小評価（誤検知）になる。判定の粒度が粗い

推奨通りA（`ANTHROPIC_BASE_URL`は用途が多様でgateway判定の精度が低く、誤検知コストが論点1より大きいため）が採用された。コード変更は行わず、変更1のコメントに既知の制約として追記する（下記参照）。

以上で残決定事項はすべて解決した。


## タスクリスト

大区分は独立実装可能な「ユニット」でまとめる。今回はすべて同一ファイル（`hooks/stop-handover-reminder.sh`）を対象とし、後続ユニットは前工程の完了に依存するため並列不可。ユニットCのみ実装のブロッカーではなく独立して後日実施可能。

### ユニットA: hooks/stop-handover-reminder.sh 本体の修正（並列不可: 後続ユニットの前提）
- [x] A-1: 設定ブロックのコメント（7〜10行目相当）を変更1の内容に書き換える（Sonnet 5=1M固定、Sonnet 4.6以前の200K/1M判別不能、`CLAUDE_CODE_DISABLE_1M_CONTEXT`、`ANTHROPIC_BASE_URL`の既知の制約を明記）
- [x] A-2: `case`文（66〜70行目相当）に `*sonnet-5*` 分岐（`CLAUDE_CODE_DISABLE_1M_CONTEXT`判定込みのif文）を変更2の内容で追加する

### ユニットB: 検証（並列不可: 依存 = ユニットA完了）
- [x] B-1: `bash -n hooks/stop-handover-reminder.sh` で構文チェックする → OK
- [x] B-2: `case`文部分を切り出したテストスクリプトで、MODEL×環境変数のマトリクスを手動実行し期待値と一致することを確認する（`claude-sonnet-5`単体→1M、`claude-sonnet-5`+`CLAUDE_CODE_DISABLE_1M_CONTEXT=1`→200K、`claude-sonnet-4-6`→200K・誤マッチなし、`claude-opus-4-8`/`claude-fable-5`→既存動作を維持） → 全ケース期待通り

### ユニットC: 環境変数継承の実機確認（並列可: 実装のブロッカーではなく後日実施可）
- [x] C-1: 次回以降の実セッションで `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` を設定した状態でClaude Codeを起動し、Stopフック内で当該環境変数が読み取れるかをデバッグログ（検証手順参照）で確認する → **実施完了**。別ターミナルで `export CLAUDE_CODE_DISABLE_1M_CONTEXT=1; claude` を実行し1往復会話後、`/tmp/hook-debug.log` に `DISABLE_1M=1` と記録されることを確認した（継承される）
- [x] C-2: 継承されないことが判明した場合の切り戻し検討 → **不要と判明**。継承が確認できたため論点1（B案）はそのまま維持する

### ユニットD: コミット（並列不可: 依存 = ユニットB完了）
- [x] D-1: `git diff` で変更内容を確認する
- [x] D-2: コンベンショナルコミット形式でコミットする（例: `fix(handover-reminder): detect Sonnet 5 1M context window`）。`hooks/stop-handover-reminder.sh` に加え、`.claude/docs/research/2026-07-01-sonnet5-context-window-research.md` と `.claude/docs/plans/2026-07-01-sonnet5-context-window-fix-plan.md` もコミット対象に含める（プロジェクトのファイル配置規約により`.claude/docs/`はリポジトリ管理対象） → commit `2a6f493`
