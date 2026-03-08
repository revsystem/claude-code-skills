# Claude Code Skills - 個人スキル・フック管理リポジトリ

[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skills-blue)](https://docs.claude.com/en/docs/claude-code/overview)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Claude Codeのパーソナルスキルとフックスクリプトをgit管理するリポジトリです。`install.sh` を実行すると `~/.claude/skills/` および `~/.claude/hooks/` にシンボリックリンクが作成され、リポジトリ上での変更が即時反映されます。

## スキル一覧

### handover - セッション引き継ぎノート生成スキル

Claude Codeはセッションが切れると文脈がリセットされます。`handover` スキルはセッション終了時に構造化された引き継ぎノートを生成し、次のセッションへのコンテキスト継続をサポートします。

#### 生成する引き継ぎノートの構成

- **今回やったこと**: 作業内容と進捗
- **決定事項**: 確定した設計判断・方針・ルール
- **捨てた選択肢と理由**: 採用しなかったアプローチとその理由（次回同じ議論を繰り返さないために重要）
- **ハマりどころ**: 詰まったポイント・エラー・想定外の挙動
- **学び**: 今回得られた知見・気づき
- **次にやること**: 優先度付きで未完了タスク
- **関連ファイル**: 今回触った主要ファイルのパス

#### 自動生成（PreCompact フック連携）

コンテキスト圧縮が発生する直前に `precompact-handover.sh` フックが自動的に起動し、引き継ぎノートを生成します。長時間のセッションでコンテキストが失われる前に確実にキャプチャします。

## フック一覧

### precompact-handover.sh - PreCompact フック

コンテキスト圧縮の直前に発火し、`handover` スキルを使った引き継ぎノート生成をClaudeに指示します。

- プロジェクトに `.claude/` ディレクトリがあれば `{project}/.claude/handovers/` に保存
- プロジェクト外の場合は `~/.claude/handovers/` に保存
- ファイル名形式: `YYYY-MM-DD_HHmm.md`（同名が存在する場合は `_2`, `_3` を付与）

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
~/.claude/hooks/precompact-handover.sh  →  {REPO}/hooks/precompact-handover.sh
```

3. **PreCompact フックを `~/.claude/settings.json` に設定する**

```json
{
  "hooks": {
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

コンテキスト圧縮が発生するとフックが自動で起動し、引き継ぎノートを生成します。手動操作は不要です。

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
│   └── handover/
│       └── SKILL.md                 # handover スキル定義
└── hooks/
    └── precompact-handover.sh       # PreCompact フックスクリプト
```

### インストール後の構成

```text
~/.claude/
├── skills/
│   └── handover  →  {REPO}/skills/handover/   # symlink
├── hooks/
│   └── precompact-handover.sh  →  {REPO}/hooks/precompact-handover.sh   # symlink
├── settings.json                    # PreCompact フック設定（手動）
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

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
