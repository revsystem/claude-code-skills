---
name: create-issue-pr
description: Issue作成→ブランチpush→紐付いたPR作成までを一括実行する。「対応するIssueを先に作成し、PRをIssueに紐付ける」運用を徹底したいときに使う
---

# Issue先行PR作成

## 概要

「PRを作る前に対応するIssueを先に作成し、PRをIssueに紐付ける」運用を自動化するスキル。単独でPRだけを作る操作は行わない。

## 手順

### 1. 対応するIssueがまだ無いか確認する

```
gh issue list --search "<関連キーワード>"
```

既存Issueがあれば新規作成せずそれを使う。

### 2. Issueを作成する

```
gh issue create --title "<タイトル>" --label "<enhancement|bug|documentation 等、リポジトリに存在するラベル>" --body "$(cat <<'EOF'
## 背景

<なぜこの変更が必要か>

## やること

- <変更点1>
- <変更点2>

## テスト項目

- [ ] <実行したテスト・確認したこと>
EOF
)"
```

出力されるURL（`.../issues/<N>`）からIssue番号を控える。ラベルは `gh label list` で存在するものを使う。

### 3. ブランチをpushする

```
git push -u origin <branch-name>
```

### 4. Issueに紐付いたPRを作成する

```
gh pr create --title "<PRタイトル>" --body "$(cat <<'EOF'
## Summary

<変更内容の要約>

Closes #<Issue番号>

## Test Plan

- [ ] <検証項目>
EOF
)"
```

`Closes #<N>` を本文に含めることで、PRマージ時にIssueが自動クローズされる。

## 注意（Gotchas）

- Issueの「テスト項目」にチェックリストを書いた場合、実際にテストを実行してからチェックを付ける（未実施のままチェックしない）
- このワークフローを常に自動適用したい場合は、対象プロジェクトのCLAUDE.mdに「PRを作成する際は対応するIssueを先に作成し紐付ける」と明記しておくと、Claudeがこのスキルの使用を検討しやすくなる
