# research-plan-annotate 類似実装スキャン機能追加 実装計画

日時: 2026-04-27
関連調査: `.claude/docs/research/2026-04-27-research-plan-annotate-similarity-scan-research.md`

## 概要

research-plan-annotate スキルのPhase 1冒頭に「類似実装スキャン」必須ステップを追加する。
ユーザーの依頼内容に類似した実装がコードベース内にないかを事前確認し、重複実装を防ぎ既存コードの再利用を促進する。

## アプローチ

SKILL.mdにスキャン手順と確認フローを追記する方式（外部ツール・スクリプト不要）。
類似度を高/中/低の3段階で評価し、ユーザーへA/B/Cの選択肢を提示してから深掘りresearchに進む。
既存のPhase 2「参照実装の活用」と統合し、スキャン→ユーザー確認→Research/Plan という一貫したフローにする。

## 変更内容

### 変更1: 類似実装スキャンセクション追加（実施済み）

対象: `skills/research-plan-annotate/SKILL.md`

Phase 1「調査の進め方」の前に「類似実装スキャン（Research開始前の必須ステップ）」セクションを追加。
スキャン手順（キーワード抽出→grep/find横断検索→類似度評価）と確認フロー（高/中/低 × A/B/C）を定義。

### 変更2: research.mdテンプレートに「既存類似実装」セクション追加（実施済み）

対象: `skills/research-plan-annotate/SKILL.md`

「## アーキテクチャ概要」の後に「## 既存類似実装」セクションを追加。
スキャン結果（ファイルパス・関数名・概要）と採用方針を記録する。

### 変更3: 原則追記（実施済み）

対象: `skills/research-plan-annotate/SKILL.md`

「## 原則」セクションに「類似実装スキャンはResearch深掘りの前の必須ステップ」を追記。

## 影響範囲

- 既存テストへの影響: なし（`tests/test_install.sh` はinstall.sh挙動のみテスト）
- API変更の有無: なし
- マイグレーションの有無: なし
- 後方互換性: あり（既存のワークフロー構造は維持、フェーズの前にステップを追加するのみ）

## 考慮事項

- skill-creator eval 2イテレーション実施済み（with_skill 100% / old_skill 25%、差分 +75%）
- スキャンはgrep/findベースのため、キーワードに依存する。スキルの指示で明示的に対処済み

## タスクリスト

### Phase 1: ドキュメント作成
- [x] 1-1: `SKILL.md` の変更を実施する（類似実装スキャンセクション追加）
- [x] 1-2: research.mdを `.claude/docs/research/` に作成する
- [x] 1-3: plan.mdを `.claude/docs/plans/` に作成する（本ファイル）

### Phase 2: クリーンアップ
- [ ] 2-1: `skills/research-plan-annotate-workspace/` を削除する
- [ ] 2-2: `skills/research-plan-annotate/evals/` を削除する

### Phase 3: Git作業
- [ ] 3-1: `feat/research-plan-annotate-similarity-scan` ブランチを作成する
- [ ] 3-2: GitHub Issueを作成する
- [ ] 3-3: `SKILL.md`・`research.md`・`plan.md` を git add してコミットする
- [ ] 3-4: リモートにプッシュし、Issueを紐付けたPRを作成する

### Phase 4: 検証
- [ ] 4-1: `bash tests/test_install.sh` を実行して全テスト通過を確認する
