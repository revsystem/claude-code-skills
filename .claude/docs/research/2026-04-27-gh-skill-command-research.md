---
name: gh skill コマンド有用性調査
description: このプロジェクトへの gh skill コマンド導入可否の調査
type: research
---

# gh skill コマンド有用性調査

日時: 2026-04-27

## 対象範囲

- `install.sh` および `npx skills` の現行インストール機構
- `gh skill` (GitHub CLI v2.90.0以降で利用可能)のコマンド仕様
- Agent Skills 仕様 (agentskills.io) との整合性
- 現行 `SKILL.md` フロントマターとの互換性確認

## アーキテクチャ概要

現行のインストール機構は以下の2層で構成されている。

- `npx skills add revsystem/claude-code-skills`: スキルのみをインストールする。`~/.claude/skills/` にシンボリックリンクを作成する。
- `bash install.sh`: スキル・エージェント・フックをすべてインストールする。`~/.claude/skills/`, `~/.claude/agents/`, `~/.claude/hooks/` にシンボリックリンクを作成する。

`install.sh` は `SKILL.md` フロントマターの `hooks:` フィールドを解析し、スキルが依存するフックを自動でリンクする仕組みを持つ。

## 既存類似実装

- `install.sh`の skills インストール部分: `gh skill install` が代替候補
- `npx skills add`: `gh skill install` が代替候補（同一 Agent Skills 仕様に準拠）

採用方針: `gh skill` は `npx skills` の代替として評価する。完全置き換えではなく、skills 管理の主要経路として採用を検討する。

## gh skill コマンドの概要

GitHub CLI v2.90.0 以降で `gh skill` コマンドが利用可能（2026-04-16 Public Preview）。
現在の環境では v2.91.0 がインストール済みで `gh skill` は使用可能。

利用可能なサブコマンド:
- `gh skill install <repo> [skill]` — リポジトリからスキルをインストール
- `gh skill search <keyword>` — スキルを検索
- `gh skill preview <repo> skill` — インストール前に内容確認
- `gh skill update --all` — インストール済みスキルを最新化
- `gh skill publish` — スキルを GitHub リリースとして公開・バリデーション

インストール先: `--agent claude-code` フラグで Claude Code 向け配置先を自動解決、`--scope user` でユーザースコープ（`~/.claude/skills/`）に配置。

## gh skill と npx skills の差分

| 機能 | npx skills | gh skill |
|------|-----------|----------|
| インストール | あり | あり |
| バージョン固定 | 不明 | あり (git SHA/タグ) |
| インストール後の更新検知 | なし | あり (SHA比較) |
| プレビュー | なし | あり |
| 検索 | なし | あり |
| 公開フロー | なし | あり (GitHub Release連動) |
| エージェント対応数 | 少数 | 40+ |

## gh skill がカバーしない領域

`gh skill` がスキル管理に特化しており、以下は対象外:

1. フック (`.sh` ファイル): 管理対象外。手動セットアップか `install.sh` が引き続き必要。
2. エージェント (`.md` ファイル): 管理対象外。`install.sh` が引き続き必要。
3. `settings.json` のフック登録: 対象外。手動設定が必要。

## 現行 SKILL.md との互換性

`gh skill publish --dry-run` を実行した結果:
- エラーなし
- 警告: `license` フィールドが推奨フィールドとして未記載（2件）
- 警告: タグ保護ルールセットが未設定

既存のスキルは Agent Skills 仕様に準拠しており、即座に `gh skill` で配布可能な状態。

### 注意: カスタム hooks フィールドの扱い

現行 `handover/SKILL.md` の `hooks:` フィールドはプロジェクト独自の形式:
```yaml
hooks:
  - stop-handover-reminder.sh
  - precompact-handover.sh
```

この形式は `install.sh` の `resolve_hooks()` 関数が解析する独自仕様で、Agent Skills 標準の `hooks:` フィールド（PreToolUse/PostToolUse 等のイベント型）とは別物。`gh skill` はこのフィールドを無視する（エラーにはならない）。

`gh skill` では hooks 依存の自動解決は行われないため、フックのインストールは引き続き手動または `install.sh` に依存する。

## 現行 npx skills コマンドの地位

`npx skills` CLI (vercel-labs/skills) も同一の Agent Skills 仕様に準拠しており、`gh skill` と互換性がある。両者は並存可能。`gh skill` は GitHub ネイティブのエコシステムとの統合（リリース管理、検索、更新追跡）が優れる。

## 重要な発見

1. `gh skill` は現環境で即座に使用可能（v2.91.0 インストール済み）。
2. 現行スキルは `gh skill publish --dry-run` を警告2件（license欠如）のみでパスする。
3. `gh skill` はスキル管理に特化しており、フック・エージェント管理は対象外。
4. `install.sh` は hooks と agents の管理に引き続き必要。ただしスキル部分は `gh skill` で代替可能。
5. `gh skill publish` を使えばリリースタグを切って配布バージョン管理ができる。
6. `gh skill update --all` でインストール済みスキルの更新を追跡できる（SHA ベース）。

## 注意点・リスク

- `gh skill install` はデフォルトでファイルをコピーする（シンボリックリンクではない）。`install.sh` はシンボリックリンクを使うため、編集即時反映の利便性は `install.sh` 方式の方が高い。開発中はシンボリックリンク、配布時は `gh skill` という使い分けが自然。
- `gh skill` でインストールしたスキルには追跡メタデータがフロントマターに埋め込まれる。`gh skill publish --fix` で除去可能だが、ファイルが変更されることを意識する必要がある。
- フック自動解決（`resolve_hooks()`）は `gh skill` では行われない。フック付きスキルのセットアップには引き続き `install.sh` または手順書が必要。
