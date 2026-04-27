# research-plan-annotate スキル 類似実装スキャン機能 調査レポート

日時: 2026-04-27

## 対象範囲

- `skills/research-plan-annotate/SKILL.md`（改善対象スキル）
- `skills/handover/SKILL.md`（eval実施時の類似機能調査対象）
- `install.sh`（eval実施時の調査対象）

## アーキテクチャ概要

research-plan-annotate スキルは Research → Plan → Annotate → Todo → Handoff の5フェーズ構成。
Phase 1（Research）はユーザー依頼を受けてすぐに深掘りresearchを開始する設計だった。
Phase 2（Plan）の「参照実装の活用」セクションにユーザー提示の参照実装を取り込む仕組みはあったが、自律的なスキャンは行わなかった。

## 既存類似実装

- スキャンなし（改善前）: 類似実装を事前確認する仕組みなし
- Phase 2「参照実装の活用」: ユーザーが参照実装を提示した場合のみ反応する受け身の設計
- 採用方針: Phase 1冒頭に「類似実装スキャン」ステップを新設し、プロアクティブなスキャンを追加する

## 既存パターンと規約

- スキルのフェーズは順番に完了するチェックリスト形式
- ユーザー承認なしに次フェーズへ進まないのが原則（「don't implement yet」の徹底）
- 同様のパターンをスキャンにも適用: ユーザー確認なしにResearchの深掘りへ進まない

## 重要な発見

### eval結果（skill-creator を使った2イテレーション）

**iteration-1**（eval × 3ケース × with_skill/old_skill）:
- with_skill平均: 89%、old_skill平均: 44%（差分 +45%）
- Eval 2のプロンプトに対象ファイル名（install.sh）を明示したため差が縮まった（old_skill 75%）

**iteration-2**（プロンプト設計を改善後）:
- with_skill平均: 100%、old_skill平均: 25%（差分 +75%）
- Eval 2プロンプトからファイル名ヒントを除去し、スキャン能力を正確に測定できた
- Eval 3のアサーション設計も修正（スキャン後にresearch実行する動作を検証可能にした）

### スキャン動作の検証結果（iteration-2）

| ケース | 類似度 | with_skill | old_skill |
|---|---|---|---|
| session-handover | 高 | handoverスキルを能動的に発見しA/B/C提示、deep research前に停止 ✅ | handoverを付随的に発見するが通知なし、即座に深掘り ❌ |
| hook-install | 高 | ファイル名ヒントなしでinstall.shをスキャン経由で発見 ✅ | research後に発見を報告 ❌ |
| github-actions | 低 | 類似なしと正しく判定しresearchフェーズに移行 ✅ | スキャンステップなし ❌ |

### パフォーマンス改善

with_skillはold_skillより平均36秒速く、12113トークン少ない。
類似実装が見つかった場合に早期停止するため、無駄な深掘りresearchを省ける。

## 注意点・リスク

- graderがEval 2のold_skillに対し「research.md確認メッセージで代替案を提示した」とPASS判定するケースがあった（アサーション設計の弱点）
- 「A/B/C選択肢」アサーションは、with_skillの形式的なフォーマットを確認するには有効だが、actual情報の正確性は別途検証が必要
- スキャンはgrep/findベースで実施するため、キーワード抽出の精度に依存する（この点はスキル本文で「依頼内容からキーワードを抽出する」と明記して対処）
