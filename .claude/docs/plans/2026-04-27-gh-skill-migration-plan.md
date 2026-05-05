---
name: gh skill 移行計画
description: skills 管理を gh skill に移行し、install.sh を hooks/agents 専用に整理する
type: plan
---

# gh skill 移行計画

日時: 2026-04-27
関連調査: `.claude/docs/research/2026-04-27-gh-skill-command-research.md`

## 概要

skills の管理を `npx skills` から `gh skill` に移行し、`install.sh` を hooks/agents 専用スクリプトに整理する。npx skills の案内は廃止する。

## アプローチ

- `install.sh` から skills インストール処理（`install_skill`・`resolve_hooks`・スキルループ）を削除する。hooks/agents のみを管理するスクリプトにする。
- skills は `gh skill install revsystem/claude-code-skills <skill-name> --agent claude-code --scope user` でインストールする。
- `README.md` の「npx skills でインストール」セクションを「gh skill でインストール」に置き換える。
- `README.md` の `install.sh` セクションを hooks/agents 専用の位置づけに更新する。

代替案: `install.sh` にスキル処理を残しつつ npx を gh skill に差し替える案もあるが、スクリプトの肥大化を避けるため今回は gh skill に一本化する。

## 変更内容

### 変更1: install.sh — skills 処理を削除

対象: `install.sh`

```bash
# 削除する関数
install_skill() { ... }   # 削除
resolve_hooks() { ... }   # 削除

# 全件インストールブロックのうち削除する部分
SKILLS_DST="${CLAUDE_DIR}/skills"
mkdir -p "${SKILLS_DST}"
for skill_dir in "${REPO_DIR}/skills"/*/; do
  [ -d "${skill_dir}" ] || continue
  install_skill "${skill_dir}"
done

# 選択的インストールブロックのうち削除する部分
INSTALL_SKILLS=()
# ...
skills) INSTALL_SKILLS+=("${name}") ;;
# ...
if [ ${#INSTALL_SKILLS[@]} -gt 0 ]; then ... fi
# skills + hooks 依存解決ブロック全体
```

削除後: `install_hook`・`install_agent` 関数と、hooks/agents の全件インストール・選択的インストールのみ残す。引数の `TYPE:NAME` 形式は hooks/agents のみ対応に変わる。

### 変更2: handover/SKILL.md — hooks フィールドを削除

対象: `skills/handover/SKILL.md`

```yaml
# 削除するフィールド（install.sh の resolve_hooks() のみが参照していたため不要になる）
hooks:
  - stop-handover-reminder.sh
  - precompact-handover.sh
```

削除後: `name`・`description` のみのフロントマターになる。hooks の設定方法は README に記載する。

### 変更3: README.md — npx skills セクションを gh skill セクションに置き換え

対象: `README.md`

```markdown
### gh skill でインストール（スキルのみ）

[GitHub CLI](https://cli.github.com/) v2.90.0 以降の `gh skill` コマンドでスキルをインストールできます。

すべてのスキルをインストールする場合:

\`\`\`bash
gh skill install revsystem/claude-code-skills --agent claude-code --scope user
\`\`\`

個別のスキルを指定する場合:

\`\`\`bash
gh skill install revsystem/claude-code-skills handover --agent claude-code --scope user
\`\`\`

インストール済みスキルを最新化する場合:

\`\`\`bash
gh skill update --all
\`\`\`

エージェントとフックは `gh skill` の管理対象外です。これらも含めた完全なセットアップには、以下の `install.sh` を使用してください。
```

### 変更4: README.md — install.sh セクションの説明を hooks/agents 専用に更新

対象: `README.md`

変更前:
```markdown
### install.sh でインストール（全コンポーネント）
```
変更後:
```markdown
### install.sh でインストール（hooks と agents）
```

本文中の「全件インストール時」のシンボリックリンク一覧からスキルの行を削除し、hooks/agents のみに更新する。また「新しいスキル・エージェントを追加した後は `./install.sh` を再実行して」という記述を「新しいエージェントを追加した後は」に修正する。

### 変更5: CLAUDE.md — インストール方法の案内を更新

対象: `CLAUDE.md`

```markdown
# 変更前
`npx skills add revsystem/claude-code-skills` でスキルのみインストール可（vercel-labs/skills CLI）。

# 変更後
`gh skill install revsystem/claude-code-skills --agent claude-code --scope user` でスキルのみインストール可。
```

## 影響範囲

- `install.sh` の `skills:NAME` 形式の選択的インストールが使えなくなる。hooks/agents のみ対応。
- `handover/SKILL.md` の `hooks:` フィールドが消えるが、README にフックのインストール手順が明記されているため情報は失われない。
- `gh skill update --all` でスキルの更新追跡が可能になる（改善）。
- テスト (`tests/test_install.sh`) の skills 関連テストケースを削除・更新する必要がある。

## 考慮事項

- `gh skill install` はファイルをコピーするため、開発中にリポジトリ内を直接編集しても `~/.claude/skills/` に即時反映されない。開発時は `--from-local` フラグで都度再インストールするか、引き続き `install.sh` で手動 symlink を張る。今回はドキュメントに注記を追加するにとどめる。
- `gh skill publish --dry-run` の警告 (`license` フィールド欠如) は本タスクのスコープ外とし、別途対応する。

## タスクリスト

### Phase 1: install.sh の整理
- [x] 1-1: `install_skill()` 関数を削除する
- [x] 1-2: `resolve_hooks()` 関数を削除する
- [x] 1-3: 全件インストールブロックの skills ループを削除する
- [x] 1-4: 選択的インストールブロックの `INSTALL_SKILLS=()` および `skills)` ケースを削除する
- [x] 1-5: 選択的インストールブロックの skills + hooks 依存解決ブロックを削除する（hooks の明示指定インストールは残す）

### Phase 2: SKILL.md の更新
- [x] 2-1: `skills/handover/SKILL.md` から `hooks:` フィールドを削除する

### Phase 3: README.md の更新
- [x] 3-1: 「npx skills でインストール（スキルのみ）」セクション全体を「gh skill でインストール（スキルのみ）」セクションに置き換える
- [x] 3-2: 「install.sh でインストール（全コンポーネント）」の見出しを「install.sh でインストール（hooks と agents）」に変更する
- [x] 3-3: シンボリックリンク一覧からスキルの行を削除する
- [x] 3-4: アーキテクチャセクションの install.sh コメントを更新する
- [x] 3-5: 「新しいスキル・エージェントを追加した後は」の記述を「エージェントを追加した後は」に修正する

### Phase 4: CLAUDE.md の更新
- [x] 4-1: `npx skills add` の案内を `gh skill install` に変更する

### Phase 5: テストの更新
- [x] 5-1: `tests/test_install.sh` のスキル関連テストケースを確認し、不要なケースを削除・更新する
