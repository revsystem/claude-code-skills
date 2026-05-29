# 検証結果レポート: research-plan-annotate assets/references 分離

実施日: 2026-05-29
対象: research-plan-annotate スキルのテンプレート分離と配布反映
関連計画: ../plans/2026-05-29-research-plan-annotate-optimization-plan.md
関連調査: ../research/2026-05-29-research-plan-annotate-optimization-research.md

## サマリ

| 項目 | 結果 |
| --- | --- |
| 合否 | 静的検証 PASS。配布反映（gh skill install）PASS。ランタイムは別セッションで確認 |
| 行数 | 382行 → 238行（144行削減） |
| 主要な発見 | gh skill install が assets/references を仕様どおり同梱コピーすることを実地確認 |

## 検証内容

- 静的検証（wc/grep/awk）: 行数238、コードフェンス2（ASCII図のみ・markdownフェンス0）、assets/references 参照5件がすべて相対1階層、frontmatter（name/description/disable-model-invocation）無変更、手続き本文（スキャン手順・subagent委譲・注釈原則・ASCII図）のインライン維持。
- 分離ファイル: `assets/`（research/plan/task-list/result-template）4件、`references/similarity-scan-prompts.md` 1件を作成。中身は元テンプレートと一致。
- result-template は実例（外部の検証レポート群）を参照し、任意セクション「副次的発見」「別Issue候補リスト」を追加。
- 配布: `gh skill install . research-plan-annotate --from-local --agent claude-code --scope user` を実行。`~/.claude/skills/research-plan-annotate/` に assets/4・references/1 が同梱コピーされ、実体ディレクトリとして配置されることを確認。

## 結果

期待どおりだった点

- フェーズ局所テンプレートの on-demand 化が成立し、本文は5フェーズの骨格に圧縮された。
- 仕様（Agent Skills）のプログレッシブディスクロージャーに準拠。`gh skill install` の同梱コピーも確認でき、配布リスクは杞憂と判明。

差分・留意が出た点

- 行数は計画の概算（250〜275）をさらに下回る238行。references 外出し分が想定以上に効いた。
- ランタイム（各フェーズで assets/references を実際に Read してから成果物生成）はスキルキャッシュの都合で別セッション確認。

## 副次的発見

- 配布作業中、`zsh` の `rm` が `rm -i`（確認付き）に alias されており、symlink 削除が確認待ちで実行されないまま `gh skill install` を走らせた結果、残存 symlink 越しにリポジトリ本体へ install メタデータが書き込まれた。`git checkout` で復元し、`command rm -f` で alias を回避して再実行。
- `gh skill install` はスキルディレクトリを丸ごとコピーするため、リポジトリ内の `skills/research-plan-annotate/.claude/settings.local.json` が配布物へ混入した。`.gitignore` に `settings.local.json` を追加し、当該ディレクトリを削除して解消。

## 別Issue候補リスト

- CLAUDE.md「Skill authoring rules」に assets/references 分割の判断基準（サイズ・起動特性で個別判断）を追記するか検討（任意）。

## 結論

テンプレート分離は静的検証・配布反映ともに成功し、SKILL.md を382→238行に圧縮した。仕様準拠の on-demand 化により、配布経路でも assets/references が確実に届くことを実地確認できたのが最大の成果。配布フロー側で `rm -i` alias と `settings.local.json` 混入という2つの落とし穴を踏んだが、いずれも復元・gitignore で解消済み。
