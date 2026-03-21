# install.sh コマンドライン引数追加 設計書

Date: 2026-03-21

## 概要

`install.sh` に positional arguments を追加し、インストール対象を個別に指定できるようにする。引数なしの場合は現状通り全部インストールする。

## CLI インターフェース

```bash
./install.sh [TYPE:NAME ...]
```

引数は `TYPE:NAME` 形式のみ。TYPE だけの指定（`skills` 等）はサポートしない。

使用例:

```bash
# 全部インストール（現状維持）
./install.sh

# handover skill + 依存 hooks のみ
./install.sh skills:handover

# 特定 agent のみ
./install.sh agents:terraform-code-reviewer

# 特定 hook のみ
./install.sh hooks:stop-handover-reminder.sh

# 複数指定
./install.sh skills:handover agents:terraform-code-reviewer
```

NAME の規則: skills は拡張子なし、agents は `.md` を除いた名前、hooks は拡張子 `.sh` 込み。

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

`hooks:` フィールドは省略可能（後方互換あり）。値はファイル名のリスト（拡張子込み、2スペースインデント必須）。

## インストールロジック

引数なし: 現状の全件インストール処理をそのまま実行する。

引数あり: 各引数を `:` で分割し、TYPE ごとに振り分ける。

```bash
INSTALL_SKILLS=()    # skill 名リスト
INSTALL_AGENTS=()    # agent 名リスト（.md なし）
INSTALL_HOOKS=()     # hook 名リスト（.sh あり）
```

処理順:

1. skills をインストールし、各 SKILL.md の `hooks:` から依存 hooks を `INSTALL_HOOKS` に追加する
2. agents をインストールする
3. `INSTALL_HOOKS` をインストールする

依存 hooks の抽出は awk で行う:

```awk
awk '/^---$/{f++; next} f==1 && /^hooks:/{h=1; next} f==1 && h && /^  - /{print $2; next} f==1 && h && !/^  /{h=0}' SKILL.md
```

## エラー処理

`set -eo pipefail` を使用する（`set -u` は配列処理を複雑にするため除外）。

- 認識できない TYPE（例: `skils:foo`）→ WARNING + continue
- 存在しない NAME（例: `skills:nonexistent`）→ WARNING + continue
- コロンなしの引数（例: `skills`）→ WARNING + continue

## 変更対象ファイル

- `install.sh` — 引数パースと選択的インストール
- `skills/handover/SKILL.md` — `hooks:` フィールド追加
