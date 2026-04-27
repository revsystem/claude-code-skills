# Claude Code Skills - 個人スキル・フック管理リポジトリ

[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skills-blue)](https://docs.claude.com/en/docs/claude-code/overview)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Claude Code のパーソナルスキル、エージェント、フックスクリプトを Git 管理するリポジトリです。`install.sh` を実行すると `~/.claude/skills/`、`~/.claude/agents/`、および `~/.claude/hooks/` にシンボリックリンクが作成され、リポジトリ上の変更が即時反映されます。

## スキル一覧

| スキル | 概要 | 使い方 | 備考 |
|--------|------|--------|------|
| `handover` | セッション終了時に構造化された引き継ぎノートを生成し、次セッションへの文脈継続を支援する | `/handover` または「引き継ぎノートを生成して」 | Stop / PreCompact フックと連携 |
| `research-plan-annotate` | 実装前に「調べる → 計画する → 注釈で磨く」を回し、`research.md` / `plan.md` を成果物とする | `/research-plan-annotate` | |

スキルは Claude Code 上でインライン実行されます（自然言語や `/name` で起動）。

## エージェント一覧

| エージェント | 概要 | 起動 | モデル |
|--------------|------|------|--------|
| `terraform-code-reviewer` | Terraform のセキュリティ・ベストプラクティス・パフォーマンス・コストの観点からレビュー | `.tf` がある文脈で「この Terraform をレビューして」など自然言語 | inherit |

`inherit` は Claude Code の実行モデルを継承します。`~/.claude/agents/` に配置されたエージェントは `description` に基づき自律 spawn され、`settings.json` への追記は不要です。

## フック一覧

| フック | 種別 | 役割 |
|--------|------|------|
| `stop-handover-reminder.sh` | Stop | トランスクリプトサイズが閾値を超えたとき、1 セッション 1 回だけ `/handover` 実行を促す |
| `precompact-handover.sh` | PreCompact | コンテキスト圧縮直前のフォールバックで引き継ぎノート生成を指示する |

## インストール

### 前提条件

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) がインストールされていること
- `jq` がインストールされていること（フックスクリプトが使用）
- `uvx` がインストールされていること（`terraform-code-reviewer` エージェントの MCP サーバー起動に使用）

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### gh skill でインストール（スキルのみ）

[GitHub CLI](https://cli.github.com/) v2.90.0 以降の `gh skill` コマンドでスキルをインストールできます。

すべてのスキルをインストールする場合:

```bash
gh skill install revsystem/claude-code-skills --agent claude-code --scope user
```

個別のスキルを指定する場合:

```bash
gh skill install revsystem/claude-code-skills handover --agent claude-code --scope user
```

インストール済みスキルを最新化する場合:

```bash
gh skill update --all
```

エージェントとフックは `gh skill` の管理対象外です。これらも含めた完全なセットアップには、以下の `install.sh` を使用してください。

### install.sh でインストール（hooks と agents）

1. **リポジトリをクローンする**

```bash
git clone https://github.com/revsystem/claude-code-skills.git
cd claude-code-skills
```

2. **インストールスクリプトを実行する**

```bash
./install.sh
```

個別インストールする場合（依存フックは自動でリンクされます）:

```bash
./install.sh skills:handover agents:terraform-code-reviewer
```

以下のシンボリックリンクが作成されます（全件インストール時）。

```text
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
- 任意のタイミングで `/handover` を実行すれば手動でも引き継ぎノートを生成できる
```

## 使用方法

### handover

レスポンス終了ごとに Stop フックがコンテキスト使用量を監視し、約 70%（デフォルト 400KB）を超えた時点で自動的に引き継ぎノートを生成します。手動で生成したい場合は Claude に依頼します。

```
/handover
```

CLAUDE.md の指示により、次のセッション開始時に Claude が自動で最新の引き継ぎノートを確認します。

### 引き継ぎノートの例

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

## 捨てた選択肢と理由
- Plugin Agent 方式: sub-agent は親の会話履歴にアクセスできず、context handoff が必要になるため質が落ちる

## 次にやること
- GitHub にリモートリポジトリを作成して push する

## 関連ファイル
- ~/.claude/skills/handover/SKILL.md
- ~/.claude/hooks/precompact-handover.sh
- ~/.claude/settings.json
```

### research-plan-annotate

コードを書く前に「調べる → 計画する → 注釈で磨く」を回すワークフロースキルです。

```
/research-plan-annotate <タスクの説明>
```

## アーキテクチャ

```text
claude-code-skills/
├── install.sh                       # hooks・agents セットアップスクリプト
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

`agents/{agent-name}.md` を編集すると、シンボリックリンク経由で即時反映されます。新しいエージェントを追加した後は `./install.sh` を再実行してリンクを作成してください。スキルの開発中はローカルディレクトリからインストールする方法が便利です（`gh skill install ./path/to/skills-repo --from-local`）。

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
