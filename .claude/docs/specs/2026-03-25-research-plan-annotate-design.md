# research-plan-annotate スキル設計記録

日時: 2026-03-25

## 背景

Boris Tane氏のブログ記事 [How I Use Claude Code](https://boristane.com/blog/how-i-use-claude-code/) で紹介されているワークフローを、再利用可能なClaude Codeスキルとして形式化する。記事はResearch → Planning → Annotation Cycle → Implementation という4段階のパイプラインを提唱しており、「計画が承認されるまでコードを書かない」という原則を徹底している。

## superpowersプラグインとの重複分析

既存のsuperpowersプラグインがカバーする範囲と、Boris氏のワークフロー固有の価値を分離するため、全スキルを精査した。

### 重複度マッピング

| Boris Taneのフェーズ | superpowers対応スキル | 重複度 |
|---|---|---|
| Research (deep read → research.md) | brainstorming (explore project context) | 低〜中 |
| Planning (plan.md with code snippets) | writing-plans | 高 |
| Annotation Cycle (inline notes → iterate) | brainstorming (design sections + user approval) | 低 |
| Todo List | writing-plans (checkbox tasks) | 高 |
| Implementation (implement it all) | executing-plans / subagent-driven-development | 中 |
| Feedback (terse corrections) | なし | なし |
| Reference implementation活用 | なし | なし |

### superpowersにない価値

1. 調査フェーズの独立化と持続的アーティファクト（research.md）。superpowersのbrainstormingはコンテキスト探索を一ステップとして含むが、調査結果を独立文書に記録する仕組みがない。
2. 注釈サイクル。plan.mdを「共有ミュータブルステート」として扱い、人間がインライン注釈を書き、AIが更新するパターン。superpowersのbrainstormingは質問→承認の対話フローであり、文書ベースの反復修正ではない。
3. 参照実装の活用。OSSや他プロジェクトの実装例をplan作成のインプットとして明示的に取り込むテクニック。
4. 「don't implement yet」ガード。各フェーズにユーザー承認ゲートを設け、承認前の実装を禁止する。

### superpowersと重複する領域（委譲）

- 計画ドキュメントの詳細タスク分解（writing-plansに準ずる粒度を指定）
- TDD、コードレビュー、検証（実装フェーズ全体をsuperpowersに引き継ぎ）
- サブエージェントの活用（subagent-driven-developmentに委譲）

## 設計判断

### 判断1: スコープを「考えるフェーズ」に限定する

Research → Plan → Annotation Cycleの3フェーズに集中し、実装フェーズはsuperpowersに引き継ぐ。理由は以下の通り。

- 実装時のTDD、検証、コードレビューはsuperpowersが十分にカバーしている
- 同じ機能を再実装すると保守コストが二重になる
- Boris氏のワークフローの真の差別化ポイントは「実装前の品質」にある

### 判断2: research.mdをplan.mdから分離する

Boris氏のワークフローではresearch.mdとplan.mdが別ファイル。これを踏襲する。調査は計画の根拠であり、plan.mdからresearch.mdへリンクすることで、計画の判断根拠を追跡可能にする。

### 判断3: 注釈サイクルを明示的にガイドする

Boris氏は「plan.mdに直接メモを書き込む」と述べているが、Claude Codeのスキルとしてフォーマル化する際は、注釈の入れ方の具体例をユーザーに提示する。初見のユーザーが「インライン注釈」と言われても何をすべきかわからないため。

### 判断4: Handoffで3つの選択肢を提示する

superpowersを使っていないユーザーも考慮し、直接実装の選択肢を含める。

1. `superpowers:subagent-driven-development`（推奨）
2. `superpowers:executing-plans`
3. superpowersなしで直接実装

### 判断5: ファイル配置はCLAUDE.mdの規約に従う

- research.md → `.claude/docs/research/`
- plan.md → `.claude/docs/plans/`

superpowersは`docs/superpowers/`配下を使うが、このスキルはsuperpowersのサブスキルではないため、CLAUDE.mdで定義された`.claude/docs/`配下の規約に従う。

## 捨てた選択肢

### superpowersのbrainstormingを拡張する案

brainstormingスキルに調査フェーズと注釈サイクルを追加する方法も考えられた。不採用の理由:

- superpowersはサードパーティプラグインであり、直接編集すると更新時に上書きされる
- brainstormingの「質問ベースの設計探索」と「文書ベースの注釈サイクル」は異なるアプローチであり、同一スキルに混在させると複雑になる
- 独立スキルのほうがbrainstormingの代替としても、補完としても使える

### 実装フェーズも含める案

Boris氏のワークフロー全体（実装時のフィードバックスタイルや型チェック指示を含む）をスキル化する案。不採用の理由:

- superpowersのexecuting-plans、subagent-driven-development、test-driven-development、verification-before-completionと大幅に重複する
- 実装フェーズの品質ゲートはsuperpowersのほうが成熟している（2段階レビュー、TDD強制等）

### Boris氏のプロンプトテンプレートをそのまま収録する案

「implement it all. when you're done with a task or phase, mark it as completed...」のような定型プロンプトをスキルに含める案。不採用の理由:

- これらのプロンプトはClaude Code固有の操作指示であり、スキルのdescriptionやフェーズ遷移の仕組みで自然に実現される
- テンプレートの丸写しは元記事の文脈でのみ有効であり、汎用スキルとしては冗長

## 成果物

- `skills/research-plan-annotate/SKILL.md` (238行)
- README.mdのスキル一覧とリポジトリ構成図を更新
- `~/.claude/skills/research-plan-annotate` にsymlinkをinstall.shで作成

## 参考資料

- [How I Use Claude Code - Boris Tane](https://boristane.com/blog/how-i-use-claude-code/)
- superpowers 5.0.5: brainstorming, writing-plans, executing-plans, subagent-driven-development, test-driven-development, verification-before-completion
