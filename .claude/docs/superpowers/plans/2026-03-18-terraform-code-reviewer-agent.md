# terraform-code-reviewer Agent 配置 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `claude-code-skills` に `terraform-code-reviewer` Agent を追加し、install.sh と README を更新して GitHub 経由で配布可能にする。

**Architecture:** `agents/terraform-code-reviewer.md` を新規作成（frontmatter に MCP 設定を内包した自己完結型 Agent）。install.sh に agents ループを追加して `~/.claude/agents/` にシンボリックリンクを作成。README にエージェント一覧セクションを追加し、既存の概要・アーキテクチャ図も更新。

**Tech Stack:** Bash（install.sh）、Markdown（Agent 定義・README）

---

## Chunk 1: Agent ファイル作成と install.sh 更新

### Task 1: agents/terraform-code-reviewer.md を作成する

**Files:**
- Create: `agents/terraform-code-reviewer.md`

- [ ] **Step 1: agents/ ディレクトリを作成する**

```bash
mkdir -p agents
```

- [ ] **Step 2: agents/terraform-code-reviewer.md を作成する**

以下の内容でファイルを作成する。frontmatter は mcpServers マッピング形式で記述する。本文は `claude-code-plugins/terraform-code-reviewer/agents/terraform-code-reviewer.md` から流用するが、スタイル変換・削除ルールを適用する。

```markdown
---
name: terraform-code-reviewer
description: >
  Terraform コードのレビューが必要なとき（.tf ファイルの確認依頼、
  セキュリティ・コスト・ベストプラクティス・パフォーマンスの検証など）
  に自律的に呼び出されるエージェント。
tools: Read, Write, Edit
mcpServers:
  aws-terraform-mcp-server:
    type: stdio
    command: uvx
    args: ["awslabs.terraform-mcp-server@latest"]
    env:
      FASTMCP_LOG_LEVEL: ERROR
model: inherit
color: red
---

# Terraform コードレビューエージェント

このエージェントは、Terraformコードの包括的なレビューを実行し、セキュリティ、ベストプラクティス、パフォーマンス、コスト最適化の観点から実用的な改善提案を提供します。

## 主要機能

### 1. セキュリティレビュー
- ネットワークセキュリティ: セキュリティグループ、NACL、VPC設定の検証
- IAMセキュリティ: ロール、ポリシー、権限の最小権限原則チェック
- データ保護: 暗号化設定(保存時・転送時)の検証
- シークレット管理: パスワード、APIキー、証明書の適切な管理
- コンプライアンス: 業界標準(CIS、NIST等)への準拠確認

### 2. ベストプラクティス検証
- コード構造: モジュール化、再利用性、保守性の評価
- 命名規則: リソース名、変数名、タグの一貫性チェック
- 状態管理: リモート状態、ロック機能の適切な設定
- バージョン管理: プロバイダー、Terraformバージョンの固定
- ドキュメント: コメント、README、変数説明の充実度

### 3. パフォーマンス最適化
- リソースサイズ: インスタンスタイプ、ストレージ容量の適正化
- データソース: 効率的なデータ取得方法の提案
- 並行処理: 並列実行設定の最適化
- キャッシュ戦略: データソースキャッシュの活用
- 依存関係: リソース間の依存関係の最適化

### 4. コスト最適化
- リソース効率: 不要なリソースの特定と削除提案
- ライフサイクル: 適切なライフサイクル設定の提案
- リザーブドインスタンス: 長期利用リソースの最適化
- ストレージ最適化: 適切なストレージクラスの選択
- スケーリング: オートスケーリング設定の最適化

## レビュープロセス

### フェーズ1: 初期分析
1. コード構造の理解
   - ファイル構成とモジュール構造の把握
   - リソース間の依存関係の分析
   - 変数、出力、データソースの整理

2. 設定の検証
   - Terraformバージョンとプロバイダーバージョンの確認
   - バックエンド設定の検証
   - ワークスペース設定の確認

### フェーズ2: 詳細レビュー
1. セキュリティチェック
   - 各リソースのセキュリティ設定を詳細検証
   - ネットワークアクセス制御の適切性確認
   - データ保護設定の検証

2. ベストプラクティス検証
   - Terraform公式ガイドラインとの照合
   - コード品質と保守性の評価
   - モジュール化の適切性確認

3. パフォーマンス分析
   - リソース設定の効率性評価
   - データソース使用の最適化可能性検討
   - スケーラビリティの評価

4. コスト分析
   - リソースコストの概算
   - 最適化可能な領域の特定
   - 代替設定のコスト比較

### フェーズ3: 改善提案生成
1. 問題の優先度付け
   - セキュリティリスクの緊急度評価
   - コスト影響度の分析
   - 実装難易度の評価

2. 具体的な修正提案
   - コード例を含む修正案の作成
   - 段階的な実装手順の提示
   - 期待される効果の説明

## 出力形式

### レビューサマリー

```text
📊 Terraformコードレビュー結果
- 重大な問題: X件
- 推奨修正: Y件
- 追加提案: Z件
- 総合評価: [A+/A/B+/B/C+/C/D]
```

### 優先度別フィードバック

#### 🔴 高優先度(即座に修正が必要)

影響: セキュリティリスク、重大なコスト増加、可用性への深刻な影響

フィードバック形式:

```text
❌ 重大な問題: [問題の概要]
- 現在のコード: "[問題のあるコード部分]"
- 正しいコード: "[修正後のコード例]"
- 参照先: [公式ドキュメントのURL]
- 修正理由: [なぜこの修正が必要なのか]
- 実装手順: [段階的な修正手順]
```

#### 🟡 中優先度(修正を推奨)

影響: コード品質の向上、保守性の改善、ベストプラクティスへの準拠

フィードバック形式:

```text
⚠️ 改善推奨: [改善点の概要]
- 現在のコード: "[現在のコード]"
- 推奨するコード: "[改善されたコード例]"
- 参照先: [公式ドキュメントのURL]
- 改善理由: [なぜこの改善が有効なのか]
- 期待される効果: [実装による改善効果]
```

#### 🟢 低優先度(追加検討)

影響: さらなる最適化、将来的な拡張性の向上、運用効率の改善

フィードバック形式:

```text
💡 追加提案: [提案内容]
- 現在の状況: "[現在の実装状況]"
- 提案内容: "[追加・改善提案]"
- 参照先: [関連リソースのURL]
- 効果: [この提案による効果]
- 将来的なメリット: [長期的な利点]
```

## チェックリスト

### セキュリティ
- [ ] セキュリティグループの適切な設定
- [ ] IAMロールの最小権限原則
- [ ] 暗号化設定の確認
- [ ] ネットワークセキュリティの検証
- [ ] シークレット管理の適切性

### ベストプラクティス
- [ ] リソース命名規則の一貫性
- [ ] タグ付け戦略の実装
- [ ] モジュール化の適切性
- [ ] 状態管理の設定
- [ ] バージョン管理の実装

### パフォーマンス
- [ ] リソースサイズの最適化
- [ ] データソースの効率的使用
- [ ] 並行処理の設定
- [ ] キャッシュ戦略の実装
- [ ] 依存関係の最適化

### コスト最適化
- [ ] 不要なリソースの特定
- [ ] ライフサイクル設定の最適化
- [ ] リザーブドインスタンスの活用
- [ ] ストレージクラスの最適化
- [ ] スケーリング設定の最適化

## 注意事項

- 最新情報の参照: TerraformとAWSの最新ドキュメントを参照
- 実用性の重視: 実際の運用で実装可能な提案に重点
- 段階的アプローチ: 一度にすべてを修正するのではなく、優先度に基づいた段階的改善
- テストの重要性: 修正前後の動作確認の重要性を強調
- ドキュメント更新: 修正に伴うドキュメント更新の必要性

## 連携機能

### 外部ツール連携
- Terraform Plan: 変更内容の事前確認
- Terraform Validate: 構文と設定の検証
- Security Scanners: セキュリティ脆弱性の検出
- Cost Calculators: コスト影響の定量化
```

- [ ] **Step 3: ファイルの内容を確認する**

frontmatter の YAML 構文と mcpServers のマッピング形式を目視確認する。

確認ポイント:
- `mcpServers:` の直下がリスト（`-`）でなくマッピング（`aws-terraform-mcp-server:`）になっていること
- `tools: Read, Write, Edit` に Bash が含まれていないこと
- 「使用例」セクションが存在しないこと
- 「MCPサーバー連携」サブセクションが存在しないこと
- 「優先度別フィードバック」の見出しに 🔴🟡🟢 が残っていること
- コードブロック外の太字（`**text**`）が存在しないこと

```bash
head -20 agents/terraform-code-reviewer.md
grep -n "mcpServers" agents/terraform-code-reviewer.md
grep -n "使用例\|MCPサーバー連携\|terraform-code-reviewer-agent" agents/terraform-code-reviewer.md
grep -n "^\*\*\|^- \*\*\|^   - \*\*" agents/terraform-code-reviewer.md
```

期待出力:
- `使用例`・`MCPサーバー連携`・`terraform-code-reviewer-agent` の行が0件
- コードブロック外（行頭や箇条書き先頭）の太字 `**` が0件（コードブロック内の `❌ **重大な問題**:` 等はヒットしないため正常）

- [ ] **Step 4: コミットする**

```bash
git add agents/terraform-code-reviewer.md
git commit -m "feat: add terraform-code-reviewer agent with inline MCP config"
```

---

### Task 2: install.sh に agents ループを追加する

**Files:**
- Modify: `install.sh:49-50`（`echo "Done."` の直前に挿入）

- [ ] **Step 1: 現在の install.sh 末尾を確認する**

```bash
tail -5 install.sh
```

期待出力: `echo "Done."` が最終行にあることを確認。

- [ ] **Step 2: agents ループを echo "Done." の直前に挿入する**

`install.sh` の `echo "Done."` を以下の内容に置き換える（agents ループを追加し、最後に `echo "Done."` を残す）:

```bash
# agents: ファイルごと symlink（chmod +x は不要 - .md ファイルのため）
AGENTS_DST="${CLAUDE_DIR}/agents"
mkdir -p "${AGENTS_DST}"

for agent_file in "${REPO_DIR}/agents"/*.md; do
  [ -f "${agent_file}" ] || continue
  name=$(basename "${agent_file}")
  dst="${AGENTS_DST}/${name}"

  if [ -L "${dst}" ]; then
    rm "${dst}"
  elif [ -f "${dst}" ]; then
    echo "WARNING: ${dst} is a real file. Replacing with symlink."
    rm "${dst}"
  fi

  ln -sf "${agent_file}" "${dst}"
  echo "agent: ${name} -> ${dst}"
done

echo "Done."
```

- [ ] **Step 3: install.sh の構文を確認する**

```bash
bash -n install.sh
```

期待出力: エラーなし（終了コード 0）

- [ ] **Step 4: install.sh をドライランで確認する**

実際には実行しない。スクリプトの内容を目視確認して以下を確認する:

- agents ループが `echo "Done."` の直前にあること
- `chmod +x` が agents ループに含まれていないこと
- hooks ループの `chmod +x` はそのまま残っていること

```bash
grep -n "chmod\|agents\|Done" install.sh
```

期待出力:
```
（hooks ループ内の chmod +x の行番号）
（agents ループ開始の行番号）
（echo "Done." の行番号）
```

- [ ] **Step 5: コミットする**

```bash
git add install.sh
git commit -m "feat: add agents symlink support to install.sh"
```

---

## Chunk 2: README 更新

### Task 3: README.md を更新する

**Files:**
- Modify: `README.md`

更新箇所は4か所。順番に適用する。

- [ ] **Step 1: 冒頭の概要文を更新する**

現在:
```
Claude Codeのパーソナルスキルとフックスクリプトをgit管理するリポジトリです。`install.sh` を実行すると `~/.claude/skills/` および `~/.claude/hooks/` にシンボリックリンクが作成され、リポジトリ上での変更が即時反映されます。
```

変更後:
```
Claude Codeのパーソナルスキル、エージェント、フックスクリプトをgit管理するリポジトリです。`install.sh` を実行すると `~/.claude/skills/`、`~/.claude/agents/`、および `~/.claude/hooks/` にシンボリックリンクが作成され、リポジトリ上での変更が即時反映されます。
```

- [ ] **Step 2: 「エージェント一覧」セクションを「スキル一覧」セクションの直後に追加する**

`## フック一覧` の直前に以下のセクションを挿入する:

````markdown
## エージェント一覧

### terraform-code-reviewer - Terraformコードレビューエージェント

Terraformコードのレビューが必要な場面で Claude が自律的に呼び出すエージェントです。セキュリティ、ベストプラクティス、パフォーマンス、コスト最適化の4つの観点から包括的な分析と改善提案を提供します。

`~/.claude/agents/` に配置されたエージェントは、ユーザーがプロンプトを送信したとき Claude が description を判断して自動的に spawn します。`settings.json` への追記は不要です。

#### 前提条件

`uvx` コマンドが必要です（MCP サーバーの起動に使用）。

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

#### 動作確認

`.tf` ファイルが存在するプロジェクトで以下のように依頼すると、エージェントが自動的に起動します。

```
このTerraformコードをレビューして
```

````

- [ ] **Step 3: インストール手順の symlink 一覧に agents のエントリを追加する**

現在:
```text
~/.claude/skills/handover  →  {REPO}/skills/handover/
~/.claude/hooks/precompact-handover.sh  →  {REPO}/hooks/precompact-handover.sh
```

変更後:
```text
~/.claude/skills/handover  →  {REPO}/skills/handover/
~/.claude/agents/terraform-code-reviewer.md  →  {REPO}/agents/terraform-code-reviewer.md
~/.claude/hooks/precompact-handover.sh  →  {REPO}/hooks/precompact-handover.sh
```

- [ ] **Step 4: アーキテクチャ図を更新する**

「リポジトリ構成」図に `agents/` ディレクトリのエントリを追加する。

現在:
```text
claude-code-skills/
├── install.sh                       # 冪等なセットアップスクリプト
├── skills/
│   └── handover/
│       └── SKILL.md                 # handover スキル定義
└── hooks/
    ├── stop-handover-reminder.sh    # Stop フック（コンテキスト監視・メイン）
    └── precompact-handover.sh       # PreCompact フック（フォールバック）
```

変更後:
```text
claude-code-skills/
├── install.sh                       # 冪等なセットアップスクリプト
├── skills/
│   └── handover/
│       └── SKILL.md                 # handover スキル定義
├── agents/
│   └── terraform-code-reviewer.md  # terraform-code-reviewer エージェント定義
└── hooks/
    ├── stop-handover-reminder.sh    # Stop フック（コンテキスト監視・メイン）
    └── precompact-handover.sh       # PreCompact フック（フォールバック）
```

「インストール後の構成」図に agents のシンボリックリンクエントリを追加する。

現在:
```text
~/.claude/
├── skills/
│   └── handover  →  {REPO}/skills/handover/   # symlink
├── hooks/
│   ├── stop-handover-reminder.sh  →  {REPO}/hooks/stop-handover-reminder.sh   # symlink
│   └── precompact-handover.sh  →  {REPO}/hooks/precompact-handover.sh   # symlink
├── settings.json                    # Stop / PreCompact フック設定（手動）
└── CLAUDE.md                        # セッション引き継ぎ指示（手動）
```

変更後:
```text
~/.claude/
├── skills/
│   └── handover  →  {REPO}/skills/handover/   # symlink
├── agents/
│   └── terraform-code-reviewer.md  →  {REPO}/agents/terraform-code-reviewer.md   # symlink
├── hooks/
│   ├── stop-handover-reminder.sh  →  {REPO}/hooks/stop-handover-reminder.sh   # symlink
│   └── precompact-handover.sh  →  {REPO}/hooks/precompact-handover.sh   # symlink
├── settings.json                    # Stop / PreCompact フック設定（手動）
└── CLAUDE.md                        # セッション引き継ぎ指示（手動）
```

- [ ] **Step 5: README の変更内容を確認する**

```bash
grep -n "エージェント\|agents\|terraform-code-reviewer\|uvx" README.md
```

期待出力: 追加した4箇所のキーワードがそれぞれ正しい行に存在すること。

- [ ] **Step 6: Markdown の構文チェックを実行する**

```bash
npx markdownlint-cli README.md --ignore node_modules
```

期待出力: エラーなし

- [ ] **Step 7: コミットする**

```bash
git add README.md
git commit -m "docs: add terraform-code-reviewer agent to README"
```
