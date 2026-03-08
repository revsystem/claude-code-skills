---
name: handover
description: Use when the user runs /handover, when a session is ending, when context compaction is about to happen, or when the user asks to generate a session summary, handover note, or 引き継ぎノート. Also use when context is running low and key decisions should be preserved before they are lost.
---

# セッション引き継ぎノート生成

## Process

1. タイムスタンプ取得: `date '+%Y-%m-%d_%H%M'`
2. ディレクトリ確保: プロジェクトルートの `.claude/handovers/` を使用。プロジェクト外なら `~/.claude/handovers/`。`mkdir -p` で作成。
3. ファイル名決定: `YYYY-MM-DD_HHmm.md`。同名が存在する場合は `_2`, `_3` を末尾に付与。
4. 以下のテンプレートで引き継ぎノートを生成する。

## テンプレート

```markdown
# セッション引き継ぎノート

日時: YYYY-MM-DD HH:MM

## 今回やったこと
- (作業内容と進捗)

## 決定事項
- (確定した設計判断・方針・ルール)

## 捨てた選択肢と理由
- (採用しなかったアプローチとその理由 — 次回同じ議論を繰り返さないために必須)

## ハマりどころ
- (詰まったポイント・エラー・想定外の挙動)

## 学び
- (今回得られた知見・気づき)

## 次にやること
- (優先度付きで未完了タスク)

## 関連ファイル
- (今回触った主要ファイルのパス)
```

## Quality Rules

- 事実ベースで書く。推測・曖昧な表現は禁止。
- 「捨てた選択肢と理由」は最重要セクション。次回同じ議論を繰り返さないために具体的に。
- 各セクションは必須。該当なしの場合は「なし」と記載。
- 簡潔に、箇条書き中心。
