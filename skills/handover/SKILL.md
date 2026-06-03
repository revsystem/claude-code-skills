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
   - cold-read順（次セッションが最初に読むべきファイルを、読む順に3〜5件）
   - 駆動している Issue/PR と、関連する memory エントリ
5. 以下のテンプレートで引き継ぎノートを生成する。

## Quality Rules

- 事実ベースで書く。推測・曖昧な表現は禁止。
- 「捨てた選択肢と理由」は最重要セクション。次回同じ議論を繰り返さないために具体的に。
- 各セクションは原則必須。該当なしの場合は「なし」と記載（「関連メモリ」など任意明記のセクションは省略可）。
- 簡潔に、箇条書き中心。
- セクションごとの具体的な書き方ルールは、下の記入例の各見出し直下のコメントに記載。

## 記入例（このまま雛形として使う）

以下はそのまま雛形として複製でき、同時に良い記入例でもある。各セクション見出し直下のコメント（`<!-- -->`）が書き方のルール。複製して実ノートを書く際はコメント行を削除する。

```markdown
# セッション引き継ぎノート

日時: 2026-03-17 17:26
<!-- 状態: Working/レビュー前/ブロック中/完了 等。駆動: このセッションが対応する Issue/PR を1行（無ければ「なし」） -->
状態: Working（main 未マージ、レビュー前）
駆動: Issue #1「セッション引き継ぎ自動化」

## リポジトリ状態
<!-- ブランチ/未コミット/未プッシュ/テスト結果。変更なし・クリーンなら「なし（main、クリーン）」の1行で -->
- ブランチ: `feat/handover-skill`（main から分岐、未マージ）
- 未コミット: `skills/handover/SKILL.md`（新規）、`hooks/stop-handover-reminder.sh`（新規）
- 未プッシュ: 2 コミット（abc1234..def5678）
- テスト: 未実行

## 最初に読む（cold-read順）
<!-- 予備知識ゼロで再開する人がこの順に読めば文脈を復元できるファイルを3〜5件。所要時間の目安を添える -->
1. `skills/handover/SKILL.md` — スキル本体の現状と設計意図（≈5分）
2. `~/.claude/settings.json` — Stop フックの登録状況（≈2分）
3. `hooks/stop-handover-reminder.sh` — 自動起動ロジック（≈3分）

## 今回やったこと
<!-- 1行目に目的・背景を書く。以降は動詞＋対象＋状態の完了形で。体言止めは使わない（「認証機能の実装」ではなく「JWT認証ミドルウェアを実装した」） -->
- handover スキルと自動化フックの設計・実装（Issue #1「セッション引き継ぎ自動化」への対応）
- handoverスキルのSKILL.mdを新規作成した（~/.claude/skills/handover/SKILL.md）
- PreCompactフックを試作したが、compaction中はtool使用が制限されファイルを書けないと判明し不採用にした（→「捨てた選択肢」参照）
- Plugin Agent方式での実装を検討したが断念した（→「捨てた選択肢」参照）
- claude-code-skillsリポジトリを新規作成し、install.shでsymlink管理に移行した
- stop-handover-reminder.shフックを追加し、トランスクリプト末尾のusageから算出した文脈使用率が70%を超えた時点でhandoverを促す仕組みにした

## 決定事項
<!-- 判断＋理由を1行で -->
- handoverはSkill形式で管理する。Plugin Agent形式は採用しない
- 自動起動はStopフック（文脈使用率70%の閾値+フラグファイル）のみで行う。PreCompactフックはtool使用が制限され実効がないため採用しない
- hookのsystemMessageは指示注入方式（claude CLIを直接呼ぶ方式はタイムアウト・再帰リスクあり）
- Stopフックの「頻度が高い」問題は文脈使用率の閾値とフラグファイルで解決できる（1セッション1回のみ発火）

## 捨てた選択肢と理由
<!-- [選択肢名]: [却下した理由] — [代わりに採用したアプローチ]。Claudeが提案しユーザーに否定された案も記録する。最重要セクション -->
- Plugin Agent方式: sub-agentは親の会話履歴にアクセスできないため引き継ぎ品質が落ちる — Skill（inline実行）方式を採用
- Stopフック（閾値なし）: 全レスポンス後に発火しすぎる — 閾値（文脈使用率70%）+フラグファイルで1セッション1回に制限して採用
- トランスクリプトのバイト数で判定する案: バイト数は文脈使用率と相関せず誤発火する（ツール多用で早すぎ／軽量セッションでは未発火）— 末尾usageのトークン数（input+cache_read+cache_creation）から文脈使用率を算出する方式に変更
- PreCompactフックをメインにする案: compaction中はtool使用が制限されファイルを書けない — Stopフック（閾値+フラグ）に変更
- claude CLIをhookから直接呼ぶ方式: 再帰呼び出しリスクとAPIコスト・タイムアウトリスクがある — systemMessage注入方式を採用

## ハマりどころ
<!-- 現象 → 原因 → 解消方法の3点セットで書く -->
- PreCompactフックがsystemMessageを注入してもClaudeがファイルを書かない → compaction中はtool使用が制限される仕様のため → Stopフック方式に切り替えて解決

## 学び
<!-- このセッション固有の非自明な知見のみ。一般論（「型安全性は重要」など）は書かない -->
- Claude CodeのskillsとPlugin Agentsはfrontmatterフィールドが異なる（skills: description/matchのみ、agents: さらに多くのフィールド）
- PreCompactフックのsystemMessageはJSON形式で出力しないとClaude Codeに無視される
- PreCompactフックのsystemMessageはClaudeに届くが、compaction中はtool使用が制限されるためファイル書き込み不可
- Stopフックでdecisionにblockを返すとClaudeがそのメッセージを受け取り指示として実行する
- Stopフック入力のstop_hook_activeがtrueのときはスキップしないとdecision:block後に無限ループになる
- Stopフック入力には文脈使用率が含まれないため、トランスクリプト末尾のusage（input+cache_read+cache_creation）からlive文脈のトークン数を算出する。文脈ウィンドウはmodel名から推定する（Opus 4.x=1M、Sonnet/Haiku=200K）。判別不能なSonnet 4.6 1M版や任意サイズはCONTEXT_WINDOW_OVERRIDEで上書きする
- symlinkでディレクトリを張る場合、`ln -sf {dir}/` とスラッシュ付きで指定しないとシンボリックリンク自体がリンクされる

## 次にやること
<!-- [起点]最初に実行すべき確認・コマンド、[必須]必ずやること、[任意]いつかやること（なければ省略可） -->
- [起点] git status で未コミットファイルを確認してからPRマージに進む
- [必須] GitHubにリモートリポジトリを作成してpushする
- [任意] 他に管理すべきskillやhookが生まれた場合は随時追加

## 関連ファイル
<!-- パス＋一言説明 -->
- ~/.claude/skills/handover/SKILL.md（handoverスキル本体）
- ~/.claude/hooks/stop-handover-reminder.sh（Stopフック）
- ~/.claude/settings.json（フック登録）
- ~/go/src/github.com/revsystem/claude-code-skills/install.sh（symlink管理スクリプト）

## 関連メモリ
<!-- このセッションに関連する ~/.claude/.../memory/ のエントリ名。無ければ省略可 -->
- [[handover-skill-design]] — handover を Skill 形式にした設計判断の経緯
```
