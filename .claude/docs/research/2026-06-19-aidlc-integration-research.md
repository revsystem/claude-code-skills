# AI-DLC概念のresearch-plan-annotateスキルへの組み込み 調査レポート

日時: 2026-06-19

依頼: 「research-plan-annotate skills に AI-DLC の概念を組み込むことは可能か」の可否判断。本レポートは Research フェーズの成果物であり、実装方針（Plan）は別途 plan.md で扱う。

## 対象範囲

調査・参照したもの:

- `skills/research-plan-annotate/SKILL.md`（改修対象の正本、Phase 0〜5）
- `skills/research-plan-annotate/assets/{spec,research,plan,task-list,result}-template.md`
- AWS Labs AI-DLC 一次情報: リポジトリ `awslabs/aidlc-workflows`（README.md / `aws-aidlc-rules/core-workflow.md` / `aws-aidlc-rule-details/common/{process-overview,terminology}.md` / extensions・inception・construction 配下のファイル名）
- AI-DLC Method Definition Paper（`prod.d13rzhkk8cj2z0.amplifyapp.com`、SPAのため本文は未取得。README/ルールから内容を補完）
- 本リポジトリ規約: ルート `CLAUDE.md`、`README.md`

## アーキテクチャ概要

### AI-DLC（AWS Labs）

AIコーディングエージェント向けの「steering rules（プロジェクトルール）」集として配布される方法論。Kiro / Amazon Q / Cursor / Cline / Claude Code / Copilot / Codex に、各エージェントのルールファイル（CLAUDE.md, AGENTS.md, .cursor/rules 等）として設置し、常時適用される。ユーザーが「Using AI-DLC, ...」と宣言すると起動する。

三フェーズの適応型ワークフロー:

- Inception（WHAT / WHY）: Workspace Detection（常時）→ Reverse Engineering（ブラウンフィールド条件付き）→ Requirements Analysis（常時・深度可変）→ User Stories（条件付き）→ Workflow Planning（常時）→ Application Design（条件付き）→ Units Generation（条件付き）
- Construction（HOW）: ユニットごとのループ（Functional Design / NFR Requirements / NFR Design / Infrastructure Design / Code Generation〔常時〕）→ 全ユニット完了後に Build and Test（常時）
- Operations: 現状プレースホルダ（デプロイ・監視は将来拡張）

成果物は `aidlc-docs/` に集約。状態管理は `aidlc-state.md`（ステージ進捗）と `audit.md`（全ユーザー入力の生ログ、追記専用、タイムスタンプ付き）。プラン/ステージの2階層チェックボックス追跡。

横断的特徴:

- 適応性: 価値を生むステージのみ実行。着手前に実行計画を提示して合意を取る
- 深度可変: minimal / standard / comprehensive を複雑度・リスクで選択
- 質問駆動: チャットではなくファイル内に A/B/C/D/E + Other の選択式質問を書き、`[Answer]:` タグで回答
- Human in the loop: 各ステージで明示承認。「エージェントが提案、人が承認」。Construction は標準2択完了メッセージに固定（emergent behavior 禁止）
- Extensions: security / testing / resiliency などの横断ルールを opt-in で積層。有効化後はブロッキング制約として各ステージでコンプライアンス判定
- テネット: 重複排除 / 方法論ファースト / 再現性 / ツール非依存 / human-in-the-loop
- 付随ツール: AIDLC Evaluator（ゴールデンテスト）、AIDLC Design Reviewer（Critique/Alternatives/Gap Analysisの多エージェントレビュー、Bedrock経由）

### research-plan-annotate（本リポジトリ）

ユーザー起動の Claude Code スキル（`disable-model-invocation: true`）。コードを書く前に「設計→調査→計画→注釈」を徹底し、承認後に実装フェーズへ引き継ぐ。

- Phase 0 Design Spec: 設計判断（何を・なぜ）を spec.md に固定。残決定事項は Annotation で確定
- Phase 1 Research: 類似実装スキャン（必須）→ subagent委譲判断 → 深い読解 → research.md
- Phase 2 Plan: 変更対象ファイルを実読し、コードスニペット付きで plan.md。残決定事項を案出し
- Phase 3 Annotation Cycle: ユーザーがplan.mdへインライン注釈、1〜6回往復。ユーザーが迷う点は複数案（利点/欠点/推奨）提示
- Phase 4 Todo List: フェーズ/タスクの2階層チェックリストを plan.md に追加
- Phase 5 Handoff: 実装フェーズへ引き継ぎ。reports（成果記録）は駆動対象外で申し送りのみ

成果物は `.claude/docs/{specs,research,plans}/`。中核原則は「don't implement yet」と「注釈サイクル」。

## 既存類似実装

本件の「類似実装」は research-plan-annotate スキルそのもの。AI-DLC の Inception 系概念と設計思想（コード前の計画・human-in-the-loop・ファイル成果物・承認ゲート・設計と実装の分離）が高い一致を示す。

採用方針: 新規実装ではなく既存スキルの拡張。AI-DLC を丸ごと移植するのではなく、本スキルの責務境界（実装の手前で止め、Handoffで渡す）を保ったまま、Inception 側の概念を選択的に取り込む。

## 既存パターンと規約

組み込み時に守るべき本リポジトリの制約:

- 成果物の保存先は `.claude/docs/{specs,plans,research,reports}/`（CLAUDE.md のファイル配置規約）。AI-DLC の `aidlc-docs/` は採用しない
- スキルは `disable-model-invocation: true` の明示的ユーザー起動。AI-DLC の常時適用 steering rules モデルとは起動方式が異なる
- スキルファイルはセッション開始時にキャッシュされる。編集後のテストは新セッションで行う（CLAUDE.md）
- 設計思想は「シンプルさ優先・いたずらに行数を増やさない」。AI-DLC 全機能の移植は本方針と相反する

## 重要な発見（AI-DLC概念のマッピング）

AI-DLC の各概念を「既にカバー済み」「組み込み可能（追加価値あり）」「組み込み非推奨（責務逸脱・重複）」に分類した。

### 既にカバー済み（取り込んでも追加価値が小さい / AI-DLCが現設計を追認）

- Human in the loop の承認ゲート: 本スキルは各フェーズで承認必須、「don't implement yet」を徹底済み
- ブラウンフィールドの既存コード理解（Reverse Engineering）: Phase 1 Research + 類似実装スキャンが実質同等。本スキルは既存コード変更が主用途
- コード前計画・ファイル成果物・設計と実装の分離: 本スキルの中核
- 判断保留時の複数案提示（Phase 3）: AI-DLC の質問駆動と目的が一致（形式は相違）

### 組み込み可能（追加価値が大きく、責務と衝突しない）

1. 深度レベル（minimal / standard / comprehensive）の明示化
   現状の「小修正では Phase 0 を省略してよい」という非形式的な適応を、各フェーズに適用する明示的な深度選択に格上げできる。低リスクで具体的。

2. 着手前のワークフロー宣言（Workflow Planning相当）
   スキル開始時に「どのPhase（0〜4）をどの深度で実行するか」を提示して合意を取る。現状はフェーズ省略をその場判断しているが、AI-DLC の「実行計画を事前提示」を取り込むと透明性が上がる。

3. 残決定事項の構造化選択式フォーマット
   spec.md / plan.md の残決定事項を、AI-DLC の A/B/C/D/E + Other + `[Answer]:` タグ規約で記述できる。自由記述の注釈に加えて選択式を併用すると、注釈サイクルの判断が速く・曖昧さが減る。Phase 0/2/3 を補強。

4. ユニット・オブ・ワークによる Phase 4 Todo のグルーピング
   タスクを独立実装可能なユニット単位でまとめ、並列化可能なものを明示する。本スキル既存の subagent 並列委譲の発想と接続する。

5. NFR を調査/計画の明示レンズに
   spec.md / plan.md に非機能要件（性能・セキュリティ・スケーラビリティ）の確認観点を軽量チェックとして追加。AI-DLC の NFR Requirements/Design を「観点」として借用（独立ステージ化はしない）。

6. opt-in Extensions（任意・重め）
   security / testing / resiliency の横断チェックリストを Plan 時に opt-in で適用する仕組み。価値はあるが本スキルを重くするため優先度は低い。

### 組み込み非推奨（責務逸脱または既存資産との重複）

- Construction フェーズ（Code Generation, Build & Test）と Operations フェーズ
  本スキルは実装の手前で止めて Handoff する設計。これらを取り込むと中核テネット「don't implement yet」を破壊し、別物の大型ツールになる。Handoff 以降の実装/検証工程の領分。取り込まない。

- audit.md（追記専用の生入力ログ）/ aidlc-state.md / session-continuity
  本リポジトリには既に handover スキルがありセッション継続を担う。AI-DLC 自身のテネット「重複排除」に照らしても、並行する監査/状態管理機構の新設は重複。handover に委ねる。

- 常時適用の steering-rules 起動モデル（モデル自律起動）
  本スキルは意図的に `disable-model-invocation: true`（ユーザー起動）。起動方式は変更しない。

- 成果物ディレクトリ `aidlc-docs/`
  本リポジトリ規約の `.claude/docs/...` を維持する。

## 注意点・リスク

- 用語衝突: AI-DLC の「Phase」は Inception/Construction/Operations、本スキルの「Phase」は 0〜5 の番号付きステップ。さらに双方が「Plan」「spec」を使う。AI-DLC 語彙を取り込む場合は二重定義を避け、本スキルの番号体系を正とする
- スコープ膨張リスク: AI-DLC は完全 SDLC を志向する。取り込み範囲を Inception 側に限定しないと、本スキルの簡潔さ（CLAUDE.md のシンプルさ優先）と「don't implement yet」境界が崩れる
- キャッシュ規約: SKILL.md 改修後の検証は新セッションで行う必要がある
- 配布版の遅延: ユーザーが実行した `~/.claude/skills/research-plan-annotate`（gh skill install のコピー）は Phase 0 を含まない旧版だった。改修後はリリースタグ作成前にリモート main と同期する運用（CLAUDE.md の gh skill 注意点）を守る

## 結論（可否判断）

可能。ただし全面移植ではなく選択的取り込みが妥当。

理由: AI-DLC と research-plan-annotate は「コード前の計画・human-in-the-loop・ファイルベースの承認ゲート」という同一思想を共有し、AI-DLC の Inception 側概念は本スキルへ素直に対応づく。価値が高く摩擦の小さい追加は、深度レベルの明示化（1）、着手前のワークフロー宣言（2）、残決定事項の構造化選択式フォーマット（3）。中程度の追加としてユニット・グルーピング（4）と NFR レンズ（5）。

取り込まないべきもの: AI-DLC の Construction/Operations フェーズ（本スキルの停止境界と衝突）、audit/state/session-continuity 機構（handover スキルと重複）、常時適用の起動モデル（`disable-model-invocation` と衝突）。

次工程: どの概念を実際に組み込むかをユーザーが選び、Plan フェーズで SKILL.md の具体的改修案（差分・テンプレート変更）を設計する。
