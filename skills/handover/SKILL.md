---
name: handover
description: Use when the user runs /handover, when a session is ending, when context compaction is about to happen, or when the user asks to generate a session summary, handover note, or 引き継ぎノート. Also use when context is running low and key decisions should be preserved before they are lost.
---

# セッション引き継ぎノート生成

このノートの読み手は、会話履歴を持たない次のClaudeセッション（または翌日の開発者自身）。
「この文脈を知らない人が読んで迷わず再開できるか」を基準に書く。

## Process

1. タイムスタンプ取得: `date '+%Y-%m-%d_%H%M'`
2. ディレクトリ確保: プロジェクトルートの `.claude/handovers/` を使用。プロジェクト外なら `~/.claude/handovers/`。`mkdir -p` で作成。
3. ファイル名決定: `YYYY-MM-DD_HHmm.md`。同名が存在する場合は `_2`, `_3` を末尾に付与。
4. 会話全体を振り返り、以下を意識的に確認する:
   - 明示・暗示を問わず却下されたアプローチ（Claudeが提案してユーザーに否定されたものも含む）
   - セッション序盤に行われた設計判断（長いセッションでは忘れがちなため）
   - エラーや詰まりがあったポイントとその解消方法
   - 現在のgit状態（ブランチ名、未コミット・未プッシュのファイル、テスト実行結果）
5. 以下のテンプレートで引き継ぎノートを生成する。

## テンプレート

```markdown
# セッション引き継ぎノート

日時: YYYY-MM-DD HH:MM

## リポジトリ状態

- ブランチ: `feat/xxx`（main から分岐、未マージ）
- 未コミット: `src/foo.ts`（新規）、`README.md`（変更）
- 未プッシュ: 2 コミット（abc1234..def5678）
- テスト: PASS（`bash tests/test_install.sh` 18/18）/ 未実行
（変更なし・クリーンな状態なら「なし（main、クリーン）」と1行で）

## 今回やったこと
- (1行目にセッションの目的・背景を書く。例: 「Issue #5『install.sh CLI引数対応』への対応」。以降は動詞+対象+状態で書く。例: 「JWTミドルウェアを実装した（src/middleware/auth.ts）」「Redis案を検討したが断念した」「マイグレーション確認は未完了」)

## 決定事項
- (判断＋理由を1行で。例: 「セッションストアはRedisを採用。RDB案は書き込みボトルネックになるため却下」)

## 捨てた選択肢と理由
- [選択肢名]: [却下した理由] — [代わりに採用したアプローチ]
（例: 「Plugin Agent方式: sub-agentは親会話履歴にアクセス不可で品質が落ちる — Skill inline実行を採用」）
（Claudeが提案してユーザーに否定されたケースも含めて記録する）

## ハマりどころ
- (現象 → 原因 → 解消方法の3点セットで書く。例: 「ts-node実行時にCannot find moduleエラー → tsconfig pathsがts-node-devに認識されない → tsconfig-paths/register追加で解消」)

## 学び
- (このセッション固有の非自明な知見のみ。例: 「PreCompactフックのsystemMessageはJSON形式でないとClaude Codeに無視される」)

## 次にやること
- [起点] 次セッションが最初に実行すべきコマンドや確認事項（例: 「git status と bash tests/test_install.sh で現状確認」）
- [必須] 次セッションで必ずやること（例: 「DBマイグレーションの動作確認（ローカルで未実行）」）
- [任意] いつかやること（なければ省略可）

## 関連ファイル
- (パス＋一言説明。例: 「src/middleware/auth.ts（JWTミドルウェア、新規作成）」)
```

## Quality Rules

- 事実ベースで書く。推測・曖昧な表現は禁止。
- 「捨てた選択肢と理由」は最重要セクション。次回同じ議論を繰り返さないために具体的に。
- 各セクションは必須。該当なしの場合は「なし」と記載。
- 簡潔に、箇条書き中心。
- 「今回やったこと」は動詞で完了状態を示す。体言止め禁止: `認証機能の実装` → `JWT認証ミドルウェアを実装した（src/middleware/auth.ts）`
- 「学び」はこのセッション固有の非自明な知見のみ。一般論禁止: `型安全性は重要` → 書かない

## 記入例

```markdown
# セッション引き継ぎノート

日時: 2026-03-17 17:26

## リポジトリ状態

- ブランチ: `feat/handover-skill`（main から分岐、未マージ）
- 未コミット: `skills/handover/SKILL.md`（新規）、`hooks/precompact-handover.sh`（新規）
- 未プッシュ: 2 コミット（abc1234..def5678）
- テスト: 未実行

## 今回やったこと

- handover スキルと自動化フックの設計・実装（Issue #1「セッション引き継ぎ自動化」への対応）
- handoverスキルのSKILL.mdを新規作成した（~/.claude/skills/handover/SKILL.md）
- precompact-handover.shフックを作成しsettings.jsonに登録したが、compaction中はtool使用が制限されファイルを書けないことが判明した
- Plugin Agent方式での実装を検討したが断念した（→「捨てた選択肢」参照）
- claude-code-skillsリポジトリを新規作成し、install.shでsymlink管理に移行した
- stop-handover-reminder.shフックを追加し、コンテキスト70%時点で自動的にhandoverを起動する仕組みに切り替えた

## 決定事項

- handoverはSkill形式で管理する。Plugin Agent形式は採用しない
- 自動起動はStopフック（閾値400KB+フラグファイル）をメインにする。PreCompactフックはtool使用が制限されるためフォールバックに留める
- hookのsystemMessageは指示注入方式（claude CLIを直接呼ぶ方式はタイムアウト・再帰リスクあり）
- Stopフックの「頻度が高い」問題はトランスクリプトサイズ閾値とフラグファイルで解決できる（1セッション1回のみ発火）

## 捨てた選択肢と理由

- Plugin Agent方式: sub-agentは親の会話履歴にアクセスできないため引き継ぎ品質が落ちる — Skill（inline実行）方式を採用
- Stopフック（閾値なし）: 全レスポンス後に発火しすぎる — 閾値（400KB）+フラグファイルで1セッション1回に制限して採用
- PreCompactフックをメインにする案: compaction中はtool使用が制限されファイルを書けない — Stopフック（閾値+フラグ）に変更
- claude CLIをhookから直接呼ぶ方式: 再帰呼び出しリスクとAPIコスト・タイムアウトリスクがある — systemMessage注入方式を採用

## ハマりどころ

- PreCompactフックがsystemMessageを注入してもClaudeがファイルを書かない → compaction中はtool使用が制限される仕様のため → Stopフック方式に切り替えて解決

## 学び

- Claude CodeのskillsとPlugin Agentsはfrontmatterフィールドが異なる（skills: description/matchのみ、agents: さらに多くのフィールド）
- PreCompactフックのsystemMessageはJSON形式で出力しないとClaude Codeに無視される
- PreCompactフックのsystemMessageはClaudeに届くが、compaction中はtool使用が制限されるためファイル書き込み不可
- Stopフックでdecisionにblockを返すとClaudeがそのメッセージを受け取り指示として実行する
- Stopフック入力のstop_hook_activeがtrueのときはスキップしないとdecision:block後に無限ループになる
- symlinkでディレクトリを張る場合、`ln -sf {dir}/` とスラッシュ付きで指定しないとシンボリックリンク自体がリンクされる

## 次にやること

- [起点] git status で未コミットファイルを確認してからPRマージに進む
- [必須] GitHubにリモートリポジトリを作成してpushする
- [任意] 他に管理すべきskillやhookが生まれた場合は随時追加

## 関連ファイル

- ~/.claude/skills/handover/SKILL.md（handoverスキル本体）
- ~/.claude/hooks/stop-handover-reminder.sh（Stopフック・メイン）
- ~/.claude/hooks/precompact-handover.sh（PreCompactフック・フォールバック）
- ~/.claude/settings.json（フック登録）
- ~/go/src/github.com/revsystem/claude-code-skills/install.sh（symlink管理スクリプト）
```
