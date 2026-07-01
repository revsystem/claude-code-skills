# Sonnet 5 コンテキストウィンドウ調査レポート

日時: 2026-07-01

深度: minimal（Phase 0 Design Specは対象外の小修正のため省略）

## 対象範囲
- `hooks/stop-handover-reminder.sh`（Stopフック。transcriptのmodel名からcontext windowサイズを推定し、70%閾値超過で`/handover`を促す）
- claude-apiスキル（Anthropic API公式ドキュメント相当のキャッシュ情報）
- claude-code-guideエージェント経由でのClaude Code公式ドキュメント（`code.claude.com/docs/en/model-config`）調査

## 既存類似実装
- `hooks/stop-handover-reminder.sh` 内のmodel→context window判定 `case` 文がそのもの。Fable 5導入時（commit `9cf02fe`）に同様のパターン追加が行われている
- 類似度: 高（同一ファイル・同一 `case` 文構造の拡張で対応可能）。具体的な実装方針・分岐ロジックの決定はplan.mdに譲る（本節は「使えるパターンが既にある」という事実のみを記録する）

## 重要な発見

### 1. Sonnet 5 は 200K/1M の分岐が存在しない（Sonnet 4.6 以前とは仕様が異なる）
Claude Code公式ドキュメント（`code.claude.com/docs/en/model-config#sonnet-5-context-window`）より:
> "On the Anthropic API, Sonnet 5 always runs with the 1M context window. There is no 200K variant, no `[1m]` suffix to select, and no usage credits required on any plan."

claude-apiスキルのモデルカタログでも `claude-sonnet-5` の Context 列は `1M` と明記されており（Sonnet 4.6と同じ表記）、この点は独立した2ソースで整合している。

これは既存のフックスクリプトの前提（「Sonnetは200Kデフォルト、1Mはoverrideが必要」）が **Sonnet 5には当てはまらない** ことを意味する。現在の `case` 文はSonnet系をすべてデフォルト分岐（200K）に落としているため、**Sonnet 5利用時は実際の1Mに対して200Kという過小評価になり、`/handover`推奨のタイミングが早すぎる** バグになる。

### 2. Sonnet 4.6以前は引き続き200K/1Mの分岐があり、model名からは判別不能
- Sonnet 4.6以前で1M contextを使う場合は `[1m]` サフィックス（例: `claude-sonnet-4-6[1m]`）または `ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-6[1m]"` で明示的にoptしなければ200Kのまま
- **`[1m]` サフィックスはAPI送信前に取り除かれ、transcriptの `message.model` フィールドには残らない**（claude-code-guideエージェントの確認事項4への回答）。つまりhookのモデル名文字列だけからは200K版か1M版か判別できず、既存の `CONTEXT_WINDOW_OVERRIDE` による手動指定が引き続き唯一の回避策
- 既存コメント（Sonnet 4.6を指して「200K版/1M版で model 名が同一で自動判別できない」）はSonnet 4.6以前については引き続き正確

### 3. `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` という例外
このenv varを設定すると、Sonnet 5であっても200K扱いに強制される（エージェント回答より）。Sonnet 4.6の `[1m]` サフィックス（transcriptに残らず検知不能）とは異なり、この環境変数は公式に文書化された設定名そのものであり、hookプロセスがClaude Codeの子プロセスとして起動される場合は継承できる可能性がある。したがって「hookからは検知できない」と断定はできず、実際にhook内で参照可能かは実装前の検証課題（継承の実機検証は本調査では未実施）。継承されない場合の代替は既存の `CONTEXT_WINDOW_OVERRIDE=200000` による手動対応。hook内で自動検知するか手動OVERRIDEに委ねるかはplan.mdの残決定事項として判断する。

### 3-2. LLM Gateway利用時（`ANTHROPIC_BASE_URL`）も1Mが保証されない
公式ドキュメント（`code.claude.com/docs/en/model-config#sonnet-5-context-window`）には、`CLAUDE_CODE_DISABLE_1M_CONTEXT=1` と並ぶもう一つの200Kフォールバック条件として、`ANTHROPIC_BASE_URL` がLLM gatewayを指している場合はClaude Codeが1Mサポートの有無を検証できず200K扱いになる旨の記述がある。この場合もtranscriptの `message.model` は `claude-sonnet-5` のままで変化しないため、model名だけでは判別できない。`ANTHROPIC_BASE_URL` は他の目的（プロキシ経由等）でも設定され得るため、非空＝200Kと単純に断定すると誤検知（false positive）のリスクがある。この扱いもplan.mdの残決定事項とする。

### 4. 旧モデル選択・設定の仕組み（副次質問への回答）
- `settings.json` の `model` キー、または `ANTHROPIC_DEFAULT_SONNET_MODEL` / `ANTHROPIC_DEFAULT_OPUS_MODEL` 等の環境変数で、モデルのフルID（例: `claude-sonnet-4-6`）を指定すればエイリアス（`sonnet`, `opus`）ではなく特定バージョンに固定できる
- モデルエイリアス（`sonnet`, `opus` 等）は常に最新版に解決される
- この機能自体は本フックスクリプトの動作には直接影響しない（transcriptのmodel名はいずれにせよ実際に使われたモデルIDがそのまま記録されるため、`case`文のワイルドカードマッチングは変わらず機能する）

## 注意点・リスク
- `*sonnet-5*` という新しいワイルドカードパターンを追加する場合、既存の `claude-sonnet-4-5`（Sonnet 4.5）や `claude-sonnet-4-6` にマッチしないことを確認する必要がある。文字列 `"claude-sonnet-4-5"` は部分文字列として `"sonnet-5"` を含まない（`"sonnet-4-5"` であり `"sonnet-5"` ではない）ため、誤マッチのリスクはない
- `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` および `ANTHROPIC_BASE_URL`（LLM gateway）を設定しているユーザー環境では、Sonnet 5でも実際は200Kであるにもかかわらずhookが1Mと誤判定するリスクがある（閾値到達が遅れる＝`/handover`推奨が遅れる方向のズレであり、コンテキスト枯渇の観点では安全側ではなく危険側に倒れる）。この2条件をhook内で自動検知するか、既存の`CONTEXT_WINDOW_OVERRIDE`による手動対応に委ねるかはplan.mdの残決定事項とする
- 情報源のうち `claude-dev.tools/docs/jsonl-format` は非公式ドメインであり信頼度が低い。`[1m]`サフィックスがtranscriptに残らないという点について、公式ドキュメント（`code.claude.com/docs/en/model-config`）は allowlist マッチング時にサフィックスが取り除かれる旨は記載しているが、transcriptの `message.model` フィールドへの記録内容までは明示していない。Fable 5先例（`claude-fable-5`がサフィックスなしで記録される）との類推、および既存hookスクリプトの前提（Sonnet 4.6の200K/1M判別不能）とは整合するが、確度は「公式ドキュメントで直接確認済み」ではなく「複数の間接的傍証から妥当と推測」にとどまる

## 参考情報（実装に必須ではないが記録しておく事実）
- Sonnet 5 は約967Kトークンでauto-compactが発生する。現行の70%閾値は1M×70%=700Kであり、auto-compactより手前で`/handover`を促す設計として妥当に機能する
- `claude-opus-4-8`（Opus 4.8）は常時1M契約であり、既存の `*opus-4-*` パターンで既にカバーされている（追加対応不要）

## バグ調査の場合
該当なし（新機能対応・仕様変更への追従）
