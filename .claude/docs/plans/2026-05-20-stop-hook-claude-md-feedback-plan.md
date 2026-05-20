# stop-handover-reminder.sh CLAUDE.md フィードバック追加 実装計画

日時: 2026-05-20
関連調査: `.claude/docs/research/2026-05-20-stop-hook-claude-md-feedback-research.md`

## 概要

Stopフックのblockメッセージに、CLAUDE.mdへの知見フィードバックを促す一文を追加する。Claude公式ブログの推奨に沿ったもので、変更は1行のみ。

## 変更内容

対象: `hooks/stop-handover-reminder.sh`

```diff
-  "reason": "Context is getting full (transcript: ${SIZE} bytes). Please run the /handover skill now to save the session state before context is compacted."
+  "reason": "Context is getting full (transcript: ${SIZE} bytes). Please run the /handover skill now to save the session state before context is compacted. Also consider if any non-obvious findings from this session (gotchas, new model capabilities, workflow improvements) should be added to CLAUDE.md."
```

## 影響範囲

- 既存の動作（decision: block、フラグファイル、閾値）は変更なし
- reasonメッセージが長くなるが、Claudeへの指示として正常に機能する
- シンボリックリンク経由のため、スクリプト保存後すぐに有効

## タスクリスト

### Phase 1: 実装

- [x] 1-1: `hooks/stop-handover-reminder.sh` の `reason` 文字列に一文を追加する

### Phase 2: ドキュメントとPR

- [x] 2-1: research.md を `.claude/docs/research/` に作成する
- [x] 2-2: plan.md を `.claude/docs/plans/` に作成する
- [x] 2-3: GitHub Issue を作成する（#33）
- [x] 2-4: フィーチャーブランチにコミットしてPushする
- [x] 2-5: PRを作成しIssueに紐付ける（#34）
