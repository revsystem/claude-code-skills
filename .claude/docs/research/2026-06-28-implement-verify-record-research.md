# implement-verify-record スキル新設 調査レポート

日時: 2026-06-28
関連設計仕様: `.claude/docs/specs/2026-06-28-gated-implementation-skill-spec.md`

## 対象範囲

- `skills/research-plan-annotate/SKILL.md`（Phase 5 Handoff の差し替え対象、土台パターン）
- `skills/research-plan-annotate/assets/`（result-template / plan-template / task-list-template / research-template / spec-template）
- `skills/research-plan-annotate/references/similarity-scan-prompts.md`
- `skills/handover/SKILL.md`（スキル記法のもう一つの実例）
- `README.md`（スキル一覧表・使用方法・アーキテクチャツリー）
- `install.sh` / `tests/`（スキル追加が波及するかの確認）

## アーキテクチャ概要

このリポジトリは Claude Code のスキル・エージェント・フックを Git 管理する。配布経路が2系統ある。

- スキル: `gh skill install` で `~/.claude/skills/<name>/` にファイルがコピーされる。install.sh の対象外。`installed_plugins.json` にも登録されない。frontmatter で版管理される。
- エージェント・フック: install.sh が `~/.claude/{agents,hooks}` にシンボリックリンクを張る。

新スキルはスキル系統に属するので、install.sh と tests/test_install.sh には一切波及しない。追加作業は skills/ 配下のファイル作成と README 追記に閉じる。

新スキルの設計上の位置づけは2スキル・パイプライン。research-plan-annotate（計画、Inception）が plan.md を生成し、implement-verify-record（実装、Construction→Operations 入口）がその plan.md のユニット・グルーピングをゲート境界として消費する。接合面は plan.md。

## 既存類似実装

- `skills/research-plan-annotate/SKILL.md` — 中類似度。同一機能ではないが、新スキルの土台パターン。採用方針: 構造・規約・assets を流用しつつ別スキルとして新設（spec のアーキテクチャ判断＝案 B）。流用する具体物は後述。
- `skills/handover/SKILL.md` — 参考のみ。スキル記法（frontmatter は description のみ、`disable-model-invocation` は未設定＝モデル起動可）の対照例。新スキルは research-plan-annotate 側（`disable-model-invocation: true`）に倣う。
- 同一機能のスキルは無し。重複実装の懸念はない。

## 既存パターンと規約

研究で確認した、新スキルが従うべき規約。

- frontmatter: `name` と `description`（英語の一文）。research-plan-annotate は加えて `disable-model-invocation: true` を持つ。新スキルもこれを踏襲し、人が明示起動する設計にする。
- 本文構成: 「いつ使うか」→ フェーズ/手順 → ゲート文面（`>` 引用で提示文を明示）→「原則」。文体は日本語・絵文字なし・箇条書き最小。
- 残決定事項の選択式: spec/plan で `A/B/C + [Answer]:` 形式。各案に利点・欠点・推奨を付す。
- 成果物の配置: 設計は `.claude/docs/specs/`、調査は `.claude/docs/research/`、計画は `.claude/docs/plans/`、結果は `.claude/docs/reports/`。ファイル名は `YYYY-MM-DD-<topic>-<kind>.md`。
- タスクリスト書式（`assets/task-list-template.md`）: 大区分=ユニット（並列可/不可と依存を明記）、配下に `- [ ]` のチェックボックス。これが新スキルがゲート境界として読む単位そのもの。
- result.md（`assets/result-template.md`）: 冒頭に関連計画・関連調査リンク、サマリ表、検証内容、結果、副次的発見、別Issue候補、残課題、結論。reports は「参考の出発点」で厳密な型ではないと付録に明記されている。

## 重要な発見

差し替え・追記の正確なアンカーと、ドッグフードの安全手順を特定した。

1. research-plan-annotate の Phase 5 本文に run-to-completion 指示がある。
   - 該当文: 「plan.mdに従ってすべてを実装してください。…すべてのタスクとフェーズが完了するまで停止しないでください。…」
   - これはユニットゲートと正面から矛盾する。新スキルへの引き継ぎ文へ差し替える（spec のスコープが定める唯一の既存スキル変更）。
   - 同ファイルの「原則」「付録: result.mdのテンプレート」は変更不要。付録の result-template はむしろ新スキルが参照し続ける正本になる。

2. README の追記アンカーは3箇所。
   - スキル一覧表（research-plan-annotate 行の直後に1行追加）
   - 使用方法（research-plan-annotate 小節の直後、`## アーキテクチャ` の前に小節追加）
   - アーキテクチャツリー（research-plan-annotate エントリが現在ツリー末尾 `└──`。新スキル追加で `├──` に変わる）

3. result.md テンプレートの扱い。spec は「新設せず research-plan-annotate の assets/result-template.md を流用」と定める。ただしスキルは独立コピーで `~/.claude/skills/` に入るため、別スキルの assets を実行時にパス参照するのは脆い。研究上の結論: 新スキル SKILL.md からは「research-plan-annotate の result-template に倣う」と散文で参照し、result.md の節構成を本文に短く内包する。テンプレートファイルは複製しない（spec の「テンプレート新設しない」意図と、過去の論点2=A＝参照ファイルを増やさずインライン化、の双方に整合）。

4. ドッグフードの同期は「上書き」ではなく「退避 → 同期 → 検証 → 復元」にする。
   - `~/.claude/skills/` の既存ファイルは gh skill 管理下で frontmatter により版管理される。リポジトリ版で直接上書きすると、インストール済みの版情報と実体が乖離し `gh skill update` が効かなくなる。
   - research-plan-annotate（既存・gh管理下）: 現行 `SKILL.md` を退避してから dev 版を置き、検証後に退避した正本を戻す。
   - implement-verify-record（新規・未リリース）: 退避対象がないので dev 版を仮置きし、検証後にディレクトリごと削除する（将来の `gh skill install` がクリーンに入るように）。
   - 退避・復元・仮置き削除のコマンドは plan.md の検証タスクに具体化する。

## 注意点・リスク

- 既存インストール済みスキルを上書きすると gh skill の版管理が壊れる（発見4）。ドッグフードは必ず退避・復元方式で行い、検証後に元状態へ戻す。
- スキル本文はセッション開始時にキャッシュされる。編集後の動作確認は (1) リポジトリ版を `~/.claude/skills/` へ同期 → (2) 新セッションで実行、の2段が必須。同一セッションでは旧版のまま。これは設計では消せないメカニクス由来の制約。
- インストール先への同期で `cp` を使うと対話 alias（`-i`）に化けて上書きされないことがある。`/bin/cp -f` でフルパス実行する（過去セッションのハマりどころ）。
- gh skill のリリースは、リモート main に同期したローカルからタグを切る。遅れたローカルでタグを切ると古いツリーを指し、`gh skill update` で新内容が降りてこない。配布フェーズで注意（本計画の範囲外だが申し送り）。
- 新スキル追加は install.sh / tests に波及しない。よって既存の自動テスト（test_install.sh）への影響はゼロ。新スキル自体の検証は新セッションでのドッグフード（手動）になる。
- 別スキルの assets を実行時参照する設計は避ける（発見3）。スキル間の硬い結合を作らない。
