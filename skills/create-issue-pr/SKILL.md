---
name: create-issue-pr
description: >
  Create a GitHub Issue, push the branch, and open a PR linked to the
  Issue (Closes #N) in one gated workflow, enforcing the issue-first
  convention — never opens a standalone PR. Presents drafts of the
  Issue and PR bodies for user approval before writing anything to the
  remote. The Issue is the single source of truth for test items.
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(gh label list:*), Bash(gh issue list:*)
---

# Issue先行PR作成

## 概要

「PRを作る前に対応するIssueを先に作成し、PRをIssueに紐付ける」運用を自動化するスキル。単独でPRだけを作る操作は行わない。

IssueとPRはリモートの共有状態であり、一度作成すると編集しても履歴が残る。このため、実際に `gh issue create` / `gh pr create` を実行する前に、必ずタイトルと本文の下書きを提示してユーザーの承認を取る。承認なしにリモートへ書き込まない。この承認ゲートを手順の中心（手順3）に置いている。

## 手順

### 1. 前提条件を確認する

作業ブランチとコミットの状態を確かめてから始める。

```bash
git branch --show-current
git status
git log --oneline origin/main..HEAD
```

（既定ブランチが main でない場合は読み替える）

- main / master にいる場合はここで停止し、先に作業ブランチを作成する。
- PRに載せるべき変更が未コミットのまま残っている場合、先にコミットするかユーザーに確認する。
- PR対象のコミットが1つも無い場合は、その旨を伝えて停止する。

### 2. 対応するIssueがまだ無いか確認する

```bash
gh issue list --search "<関連キーワード>"
```

- 該当する既存Issueが1件に定まる場合は、新規作成せずその番号を使う（手順3ではPR下書きのみ提示し、手順4をスキップする）。
- 複数ヒットして判断が割れる場合は、候補を一覧提示してユーザーに選ばせる。勝手に選ばない。

### 3. IssueとPRの下書きを提示し、承認を取る（ゲート）

まずリポジトリに存在するラベルを確認する。

```bash
gh label list
```

`assets/issue-template.md` と `assets/pr-template.md` を読み、それぞれの雛形に従ってIssue本文とPR本文の下書きを作成する。Issueのタイトル・ラベル・本文、PRのタイトル・本文を揃えて一度に提示し、承認を得てから次へ進む。修正指示があれば反映して再提示する。

テスト項目はIssue側にのみ置く。PR本文はSummaryと `Closes #<N>` を核とし、同じチェックリストをIssueとPRに二重管理しない（実行結果の反映箇所が2つに分かれ、更新漏れの温床になるため）。

PR本文の `Closes #<N>` は、この時点ではIssue番号が未確定のためプレースホルダのままでよい（手順6で埋める）。

### 4. Issueを作成する

承認された内容で作成し、出力URLの末尾からIssue番号を機械的に取得する（目視転記による取り違えを防ぐ）。

```bash
issue_url=$(gh issue create --title "<タイトル>" --label "<ラベル>" --body "<手順3で承認された本文>")
issue_number="${issue_url##*/}"
```

### 5. ブランチをpushする

```bash
git push -u origin "$(git branch --show-current)"
```

pushが拒否された場合（リモートに別の履歴がある等）は、`--force` で押し切らず、状況を報告して指示を仰ぐ。

### 6. Issueに紐付いたPRを作成する

手順3で承認されたPR本文の `Closes #<N>` に手順4のIssue番号を埋めて作成する。

```bash
gh pr create --title "<PRタイトル>" --body "<Closes #番号を埋めた承認済み本文>"
```

`Closes #<N>` を本文に含めることで、PRマージ時にIssueが自動クローズされる。

### 7. テスト結果をIssueに反映する

Issueの「テスト項目」にチェックリストを書いた場合、テストを実際に実行してから `gh issue edit` で該当項目にチェックを付ける（実行コマンドと結果を `gh issue comment` で残してもよい）。この時点で未実施の項目が残る場合は、チェックせずその旨をユーザーに伝えて締める。

## 注意（Gotchas）

- 承認ゲート（手順3）を飛ばしてリモートに書き込まない。実行モードがautoでも、Issue・PRの作成は人間の承認を要する操作として扱う。
- チェックリストは実行した証拠（コマンドと出力）があるものだけチェックする。未実施のままチェックしない。
- このスキルは `disable-model-invocation: true` のため自動発火せず、起動は `/create-issue-pr` の明示実行のみ。Issue先行の運用自体を常用したいプロジェクトでは、CLAUDE.mdに「PRを作成する際は対応するIssueを先に作成し紐付ける（/create-issue-pr を使う）」と明記しておく。
