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

使用する変数:

```bash
INSTALL_SKILLS_ALL=false      # true = 全 skills
INSTALL_SKILLS_NAMES=()       # 個別名リスト（拡張子なし）
INSTALL_AGENTS_ALL=false
INSTALL_AGENTS_NAMES=()       # 個別名リスト（拡張子なし、.md を除いた名前）
INSTALL_HOOKS_ALL=false
INSTALL_HOOKS_NAMES=()        # 個別名リスト（拡張子あり、例: stop-handover-reminder.sh）
```

パースルール:

- 引数なし → `INSTALL_SKILLS_ALL=true, INSTALL_AGENTS_ALL=true, INSTALL_HOOKS_ALL=true`
- `skills` → `INSTALL_SKILLS_ALL=true`
- `skills:handover` → `INSTALL_SKILLS_NAMES+=("handover")`
- `agents` → `INSTALL_AGENTS_ALL=true`
- `agents:terraform-code-reviewer` → `INSTALL_AGENTS_NAMES+=("terraform-code-reviewer")`（拡張子 `.md` は除く）
- `hooks` → `INSTALL_HOOKS_ALL=true`
- `hooks:stop-handover-reminder.sh` → `INSTALL_HOOKS_NAMES+=("stop-handover-reminder.sh")`（拡張子 `.sh` を含む）
- 認識できない type トークン（例: `skils`）→ WARNING を出して skip

混在時の優先順位: `INSTALL_SKILLS_ALL=true` は `INSTALL_SKILLS_NAMES` より優先する（all が指定されていれば名前リストは無視）。agents/hooks も同様。

### Step 2: skills インストール + 依存 hooks 解決

`RESOLVED_HOOKS=()` 配列を用意し、依存解決で見つかった hook 名を蓄積する。

各 skill をインストールする際、その `SKILL.md` frontmatter から `hooks:` フィールドを awk で抽出する。frontmatter は `---` から `---` の範囲。抽出アルゴリズム:

```awk
awk '/^---$/{f++; next} f==1 && /^hooks:/{h=1; next} f==1 && h && /^  - /{print $2; next} f==1 && h && !/^  /{h=0}' SKILL.md
```

抽出した各 hook ファイル名を `RESOLVED_HOOKS` に追加する（重複は後続ステップで無視）。

依存解決で追加された hooks は、`hooks` 系引数の有無に関わらずインストールする。

### Step 3: hooks インストール

インストール対象を以下の union で決定する:

- `INSTALL_HOOKS_ALL=true` → 全 hook ファイルをインストール。この場合 `RESOLVED_HOOKS` は全 hooks の部分集合なので無視してよい。
- `INSTALL_HOOKS_ALL=false` → `INSTALL_HOOKS_NAMES` と `RESOLVED_HOOKS` を順にループし、インストール済み追跡配列 `INSTALLED_HOOKS=()` を使って重複を除去する。

重複除去のフロー（`INSTALL_HOOKS_ALL=false` の場合）:

```bash
INSTALLED_HOOKS=()
for name in "${INSTALL_HOOKS_NAMES[@]}" "${RESOLVED_HOOKS[@]}"; do
  [[ " ${INSTALLED_HOOKS[*]} " =~ " ${name} " ]] && continue
  # インストール処理
  INSTALLED_HOOKS+=("${name}")
done
```

## エラー処理

`set -euo pipefail` は維持する。WARNING + skip が必要なパスでは `|| true` を使い非ゼロ終了を抑制する。具体的には:

- 存在しない名前を指定した場合（例: `skills:nonexistent`）→ `echo "WARNING: ..." >&2` を出力して `continue`（ループ内のため `set -e` の影響なし）
- `hooks:` frontmatter に記載されているが実ファイルが存在しない hook → 同様に WARNING + `continue`
- 認識できない type トークン → WARNING + `continue`

## 変更対象ファイル

- `install.sh` — 引数パースとインストールロジックの実装
- `skills/handover/SKILL.md` — `hooks:` フィールド追加
- （将来 hooks を持つ skill が増えた場合、各 SKILL.md に `hooks:` を追記）
