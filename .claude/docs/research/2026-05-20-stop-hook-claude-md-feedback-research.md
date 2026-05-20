# stop-handover-reminder.sh CLAUDE.md フィードバックループ調査レポート

日時: 2026-05-20

## 対象範囲

- 調査URL: [Claude Code in Large Codebases](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start)
- `hooks/stop-handover-reminder.sh`

## 背景

Claude公式ブログがClaude Code大規模コードベースのベストプラクティスを公開した。その中で「Stopフックはセッションを振り返り、CLAUDE.mdへの更新を提案できる」と明示されている。

> Stop hooks can "reflect on what happened during a session and propose CLAUDE.md updates"

## 現状の stop-handover-reminder.sh

トランスクリプトが1MB超になった時点で`decision: block`を返し、handoverスキルの実行を促す。

```bash
{
  "decision": "block",
  "reason": "Context is getting full (transcript: ${SIZE} bytes). Please run the /handover skill now to save the session state before context is compacted."
}
```

## ギャップ分析

現在のStopフックはhandover（セッション状態の保存）に特化しており、CLAUDE.mdへのフィードバックループが含まれていない。

| 目的 | 現状 |
| --- | --- |
| セッション状態の保存（handover） | 対応済み |
| CLAUDE.mdへの知見フィードバック | 未対応 |

## 既存類似実装

- handoverスキル自体は「学び」セクションを持ち、非自明な知見を記録する仕組みがある
- しかし handover → CLAUDE.md の橋渡しは明示されていない

## アプローチ検討

### 案A: reasonメッセージへの追記（採用）

`reason`文字列にCLAUDE.md更新を促す一文を追加する。シンプルで後方互換性があり、既存の動作を変えない。

### 案B: 別途CLAUDE.mdレビュースキルの新設

CLAUDE.md専用のスキルを作り、セッション末に呼び出す。実装コストが高く、呼び出しタイミングの調整も必要になる。

### 案C: reasonに別途decision:blockを追加

2回blockする仕組みにする。フラグファイル管理が複雑化する。

採用理由: 案Aが最もシンプルで効果的。reasonメッセージはClaudeへの指示として機能するため、一文追記するだけで目的を達成できる。

## 注意点

- stop_hook_active=trueのスキップ処理は既存のまま維持する
- フラグファイルによる1セッション1回発火の制限も変更不要
