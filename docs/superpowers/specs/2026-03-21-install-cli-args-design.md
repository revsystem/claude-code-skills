# install.sh コマンドライン引数追加 設計書

Date: 2026-03-21

## 概要

`install.sh` に positional arguments を追加し、インストールする skills/agents/hooks を選択的に指定できるようにする。引数なしの場合は現状通り全部インストールする（デフォルト動作は維持）。

## CLI インターフェース

```bash
./install.sh [TARGET...]
```

TARGET の形式:

| 形式 | 意味 |
|------|------|
| （引数なし） | skills/agents/hooks 全部インストール |
| `skills` | 全 skills + 各 skill の依存 hooks をインストール |
| `skills:NAME` | 指定した skill + その依存 hooks のみインストール |
| `agents` | 全 agents をインストール |
| `agents:NAME` | 指定した agent のみインストール |
| `hooks` | 全 hooks を明示的にインストール |
| `hooks:NAME` | 指定した hook のみインストール |

### 使用例

```bash
# 全部インストール（現状維持）
./install.sh

# 全 skills（+ 依存 hooks）のみ
./install.sh skills

# handover skill とその依存 hooks のみ
./install.sh skills:handover

# 全 agents のみ
./install.sh agents

# 特定 agent のみ
./install.sh agents:terraform-code-reviewer

# 複数指定：全 agents + handover skill（+ 依存 hooks）
./install.sh agents skills:handover

# hook を明示インストール（依存解決とは別に）
./install.sh hooks:stop-handover-reminder.sh
```

## SKILL.md frontmatter 拡張

skill が依存する hooks を宣言するため、`SKILL.md` の frontmatter に `hooks:` フィールドを追加する。

```yaml
---
name: handover
description: Use when the user runs /handover...
hooks:
  - stop-handover-reminder.sh
  - precompact-handover.sh
---
```

- `hooks:` フィールドは省略可能。既存の SKILL.md は変更不要（後方互換あり）。
- 値はファイル名のリスト（拡張子込み）。

## インストールロジック

処理は3段階で行う。

### Step 1: 引数パース

positional arguments をループで処理し、各引数を `:` で分割して種別と名前を判定する。

- 引数なし → `skills=all, agents=all, hooks=all`
- `skills` → `skills=all`（フラグ `INSTALL_SKILLS_ALL=true`）
- `skills:handover` → `INSTALL_SKILLS_NAMES+=("handover")`
- `agents` → `agents=all`
- `agents:terraform-code-reviewer` → `INSTALL_AGENTS_NAMES+=("terraform-code-reviewer")`
- `hooks` → `hooks=all`（明示指定）
- `hooks:stop-handover-reminder.sh` → `INSTALL_HOOKS_NAMES+=("stop-handover-reminder.sh")`

### Step 2: skills インストール + 依存 hooks 解決

各 skill をインストールする際、その `SKILL.md` frontmatter から `hooks:` フィールドを `sed`/`awk` で抽出し、依存 hooks をインストール対象セットに追加する。重複は無視。

依存解決で追加された hooks は、明示的に hooks が指定されていなくてもインストールする。

### Step 3: hooks インストール

明示指定の hooks と、依存解決で収集した hooks の union をインストールする。

## エラー処理

- 存在しない名前を指定した場合（例: `skills:nonexistent`）は WARNING を出して skip する。`set -e` でのクラッシュはしない。
- `hooks:` frontmatter フィールドに記載されているが実ファイルが存在しない hook も同様に WARNING + skip。

## 変更対象ファイル

- `install.sh` — 引数パースとインストールロジックの実装
- `skills/handover/SKILL.md` — `hooks:` フィールド追加
- （将来 hooks を持つ skill が増えた場合、各 SKILL.md に `hooks:` を追記）
