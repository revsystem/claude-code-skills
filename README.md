# Claude Code Skills - 個人スキル・フック管理リポジトリ

[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skills-blue)](https://docs.claude.com/en/docs/claude-code/overview)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Claude Codeのパーソナルスキル、エージェント、フックスクリプトをgit管理するリポジトリです。`install.sh` を実行すると `~/.claude/skills/`、`~/.claude/agents/`、および `~/.claude/hooks/` にシンボリックリンクが作成され、リポジトリ上での変更が即時反映されます。

## スキル一覧

### handover - セッション引き継ぎノート生成スキル

Claude Codeはセッションが切れると文脈がリセットされます。`handover` スキルはセッション終了時に構造化された引き継ぎノートを生成し、次のセッションへのコンテキスト継続をサポートします。

#### 参考

- [Claude Code のセッション引き継ぎを自動化する](https://izanami.dev/post/3b2789ca-30ee-403f-af43-83e2c7009fb1)
- [【Claude Code】スラッシュコマンドでセッション引き継ぎを仕組み化する](https://dev.classmethod.jp/articles/claude-code-session-handover/)

#### 生成する引き継ぎノートの構成

- **今回やったこと**: 作業内容と進捗
- **決定事項**: 確定した設計判断・方針・ルール
- **捨てた選択肢と理由**: 採用しなかったアプローチとその理由（次回同じ議論を繰り返さないために重要）
- **ハマりどころ**: 詰まったポイント・エラー・想定外の挙動
- **学び**: 今回得られた知見・気づき
- **次にやること**: 優先度付きで未完了タスク
- **関連ファイル**: 今回触った主要ファイルのパス

#### 自動生成（Stop フック連携）

レスポンス終了ごとに `stop-handover-reminder.sh` フックがトランスクリプトのサイズを監視します。コンテキストが約70%（デフォルト 400KB）を超えると Claude に `/handover` の実行を促し、compaction が必要になる前に引き継ぎノートを作成します。

### research-plan-annotate - 調査・計画・注釈サイクルスキル

コードを書く前に「調べる→計画する→注釈で磨く」を徹底するワークフロースキルです。[Boris Tane氏のHow I Use Claude Code](https://boristane.com/blog/how-i-use-claude-code/)を参考に、superpowersプラグインにない3つのフェーズをカバーします。

- Phase 1 (Research): 対象コードを深く読み込み、`research.md` に調査結果を記録
- Phase 2 (Plan): 調査を踏まえてコードスニペット付きの `plan.md` を作成
- Phase 3 (Annotate): ユーザーが `plan.md` にインライン注釈を書き込み、Claudeが反映する。1〜6回繰り返して計画を磨く

全フェーズ完了後、superpowersの `executing-plans` または `subagent-driven-development` に実装を引き継ぎます。

#### 使い方

```
この機能の実装計画を立てて
/plan [機能の説明]
```

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

`.tf` ファイルが存在するプロジェクトで以下のように依頼すると、Claude が description を判断してエージェントを起動します。

```
このTerraformコードをレビューして
```

## フック一覧

### stop-handover-reminder.sh - Stop フック（コンテキスト監視）

レスポンス終了ごとにトランスクリプトサイズを確認し、閾値を超えた時点で一度だけ引き継ぎノートの生成を Claude に指示します。

- トランスクリプトサイズが `THRESHOLD`（デフォルト 400000 bytes）を超えたとき発火
- フラグファイル `/tmp/claude-handover-triggered-{session_id}` で1セッション1回に制限
- `stop_hook_active: true` のときはスキップ（無限ループ防止）
- プロジェクトに `.claude/` ディレクトリがあれば `{project}/.claude/handovers/` に保存
- プロジェクト外の場合は `~/.claude/handovers/` に保存
- ファイル名形式: `YYYY-MM-DD_HHmm.md`（同名が存在する場合は `_2`, `_3` を付与）

### precompact-handover.sh - PreCompact フック（フォールバック）

コンテキスト圧縮の直前に発火し、`handover` スキルを使った引き継ぎノート生成を Claude に指示します。Stop フックで生成が間に合わなかった場合のフォールバックとして機能します。なお、compaction 中は tool 使用が制限されるため、ファイルが書かれない場合があります。

## インストール

### 前提条件

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) がインストールされていること
- `jq` がインストールされていること（フックスクリプトが使用）

### インストール手順

1. **リポジトリをクローンする**

```bash
git clone https://github.com/revsystem/claude-code-skills.git
cd claude-code-skills
```

2. **インストールスクリプトを実行する**

```bash
./install.sh
```

以下のシンボリックリンクが作成されます。

```text
~/.claude/skills/handover  →  {REPO}/skills/handover/
~/.claude/agents/terraform-code-reviewer.md  →  {REPO}/agents/terraform-code-reviewer.md
~/.claude/hooks/stop-handover-reminder.sh  →  {REPO}/hooks/stop-handover-reminder.sh
~/.claude/hooks/precompact-handover.sh  →  {REPO}/hooks/precompact-handover.sh
```

3. **フックを `~/.claude/settings.json` に設定する**

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/stop-handover-reminder.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/precompact-handover.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

4. **CLAUDE.md にセッション引き継ぎの指示を追加する**

`~/.claude/CLAUDE.md` に以下を追加します。

```markdown
# セッション引き継ぎ
- セッション開始時にプロジェクトルートの `.claude/handovers/` ディレクトリを確認し、ファイルが存在すれば最新のものを読み込む
- コンテキスト圧縮の直前に自動で引き継ぎノートが生成される（PreCompactフック）
- 任意のタイミングで引き継ぎノートの生成を依頼すれば手動でも生成できる
```

## 使用方法

### 自動生成（推奨）

レスポンス終了ごとに Stop フックがコンテキスト使用量を監視し、約70%を超えた時点で自動的に引き継ぎノートを生成します。コンテキスト圧縮（compaction）が必要になる前に確実にキャプチャします。

### 手動生成

セッションの区切りで手動生成したい場合は、Claudeに自然言語で依頼します。

```
引き継ぎノートを生成して
セッションの引き継ぎノートを作って
```

### 次のセッションで引き継ぎノートを参照する

CLAUDE.mdの指示により、セッション開始時にClaudeが自動的に最新の引き継ぎノートを確認します。

### 生成ファイルの例

```text
.claude/handovers/
├── 2026-03-08_2130.md
├── 2026-03-07_1845.md
└── 2026-03-06_1200.md
```

```markdown
# セッション引き継ぎノート

日時: 2026-03-08 21:30

## 今回やったこと
- handover スキルをプラグインリポジトリで管理する方式を設計・実装

## 決定事項
- スキルはリポジトリで管理し、symlink で ~/.claude/skills/ に配置する方式を採用
- Plugin Agent 方式（context handoff が必要）より Personal Skill 方式（inline 実行）が handover 生成に適している

## 捨てた選択肢と理由
- Plugin Agent 方式: sub-agent は親の会話履歴にアクセスできず、context handoff が必要になるため質が落ちる

## ハマりどころ
- なし

## 学び
- Claude Code のプラグインシステムは agents（spawnable sub-agent）と skills（inline）で仕組みが異なる

## 次にやること
- GitHub にリモートリポジトリを作成して push する

## 関連ファイル
- ~/.claude/skills/handover/SKILL.md
- ~/.claude/hooks/precompact-handover.sh
- ~/.claude/settings.json
```

## アーキテクチャ

### リポジトリ構成

```text
claude-code-skills/
├── install.sh                       # 冪等なセットアップスクリプト
├── skills/
│   ├── handover/
│   │   └── SKILL.md                 # handover スキル定義
│   └── research-plan-annotate/
│       └── SKILL.md                 # 調査・計画・注釈サイクルスキル定義
├── agents/
│   └── terraform-code-reviewer.md  # terraform-code-reviewer エージェント定義
└── hooks/
    ├── stop-handover-reminder.sh    # Stop フック（コンテキスト監視・メイン）
    └── precompact-handover.sh       # PreCompact フック（フォールバック）
```

### インストール後の構成

```text
~/.claude/
├── skills/
│   ├── handover  →  {REPO}/skills/handover/   # symlink
│   └── research-plan-annotate  →  {REPO}/skills/research-plan-annotate/   # symlink
├── agents/
│   └── terraform-code-reviewer.md  →  {REPO}/agents/terraform-code-reviewer.md   # symlink
├── hooks/
│   ├── stop-handover-reminder.sh  →  {REPO}/hooks/stop-handover-reminder.sh   # symlink
│   └── precompact-handover.sh  →  {REPO}/hooks/precompact-handover.sh   # symlink
├── settings.json                    # Stop / PreCompact フック設定（手動）
└── CLAUDE.md                        # セッション引き継ぎ指示（手動）
```

## カスタマイズ

### スキルの調整

`skills/handover/SKILL.md` を編集することでスキルの動作を変更できます。シンボリックリンクのためリポジトリへの変更は即時反映されます。

### フックのタイムアウト調整

`~/.claude/settings.json` の `timeout` 値を変更することでフックのタイムアウトを調整できます（デフォルト: 10秒）。

### 新しいスキルの追加

1. `skills/{skill-name}/SKILL.md` を作成する
2. `./install.sh` を再実行してシンボリックリンクを作成する

### 新しいエージェントの追加

1. `agents/{agent-name}.md` を作成する（frontmatter に `name`、`description`、`tools`、`mcpServers` を定義）
2. `./install.sh` を再実行してシンボリックリンクを作成する

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
