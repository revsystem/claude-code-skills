# research-plan-annotate スキル最適化 実装計画

日時: 2026-05-29
関連調査: ../research/2026-05-29-research-plan-annotate-optimization-research.md

## 概要

382行ある research-plan-annotate の SKILL.md を、Agent Skills 仕様公認のプログレッシブディスクロージャーに沿って最適化する。フェーズ局所の出力テンプレート群を `assets/` へ外出しし、本文は5フェーズのワークフロー骨格に絞る。invocation 方針（disable-model-invocation）の見直しも本計画のスコープに含める。

## アプローチ

仕様は「SKILL.md は500行未満に保ち、詳細な参照素材は別ファイルへ移す。リソースは必要時のみロードされる」と推奨。`gh skill install` も同梱リソースを配布するため、分離は配布面でも安全（調査で確認済み）。

分離の判断基準: フェーズ局所・条件起動の素材は外出しし、毎回必ず要る手続きロジックはインライン維持する（毎回要る素材の外出しは Read を増やすだけで利得がない）。

- 出力テンプレート4種（research.md / plan.md / タスクリスト / result.md付録）= フェーズ局所 → `assets/` へ。
- 類似実装スキャン手順・subagent委譲判断・注釈反映原則 = 毎回必須 → インライン維持。
- 注釈サイクルのASCII図（7行）= 小さく本文密結合 → インライン維持。
- 類似実装の確認フロー文面（高/中/低の3メッセージ、約25行）= 類似実装が見つかった時のみ使う条件起動素材 → `references/` 候補。

## 変更内容

### 変更1: 出力テンプレートを assets/ へ分離

対象: `skills/research-plan-annotate/SKILL.md`、新規 `skills/research-plan-annotate/assets/`

以下4ファイルを新規作成し、SKILL.md の該当コードフェンス（research.md構成 139-173 / plan.md構成 213-254 / タスクリスト 312-324 / result.md付録 357-382）を削除して参照に置き換える。

```text
skills/research-plan-annotate/assets/
├── research-template.md     # 現 139-173 の中身
├── plan-template.md         # 現 213-254 の中身
├── task-list-template.md    # 現 312-324 の中身
└── result-template.md       # 現 357-382 の中身（reports は駆動対象外のため最有力の外出し候補）
```

SKILL.md 側は各フェーズで明示的に Read を指示する（ドリフト防止）。例（research.mdの構成 箇所）:

```markdown
### research.mdの構成

プロジェクトルートの `.claude/docs/research/` に `YYYY-MM-DD-<topic>-research.md` として保存する。
構成は `assets/research-template.md` を読み、その雛形に従って記述する。
```

plan.md構成・タスクリスト・付録も同形式で「`assets/<file>` を読んで使う」に置換する。ファイル参照はスキルルートから1階層（仕様準拠）。

### 変更2: 類似実装の確認フロー文面の扱い（references/ 検討）

対象: `skills/research-plan-annotate/SKILL.md` 63-87行、（採用時）新規 `skills/research-plan-annotate/references/similarity-scan-prompts.md`

確認フロー文面（高/中/低類似度の3メッセージ、現 63-87行）を `references/similarity-scan-prompts.md` へ外出しする（決定事項#2）。SKILL.md 側のスキャン手順・類似度評価（42-57行）はインライン維持し、確認フローの箇所には「類似実装が見つかったら `references/similarity-scan-prompts.md` の文面を使って方針を確認する」と1行の参照を残す。方針A選択時に Phase 2 以降を省略して Handoff へ進むルール（現 88行）は SKILL.md 本文に残す。

### 変更3: invocation 方針の見直し（不実施）

決定事項#3により `disable-model-invocation: true` を維持。frontmatter は変更しない。

### 変更4: インライン本文の軽圧縮（不実施）

決定事項#4により今回は分離のみ。圧縮は別タスクとし本文の言い回しは変えない。

## 影響範囲

- 既存テスト: `tests/test_install.sh` は install.sh の symlink 回帰テストでスキル本文・assets を検証しない。assets/ は symlink されたディレクトリ配下に入るため参照可能。影響なし（要確認）。
- 配布: `gh skill install` は仕様準拠でディレクトリ同梱リソースを配布。assets/・references/ とも配布される。
- CLAUDE.md: 「Skill authoring rules」に assets/references の分割方針を1行追記するか任意で検討。
- frontmatter: 変更3を採る場合のみ disable-model-invocation と description を変更。name は不変。
- 行数: 382行 → 概算250〜275行（テンプレート約115行を外出し＋参照行を追加。圧縮併用時はさらに減）。

## 考慮事項

- ドリフト防止: 各フェーズに assets の Read 指示を明記しないと、Claude が記憶でテンプレートを再構成して出力がぶれる。参照は必ず相対パスで残す。
- 分離の前例がリポジトリ内にゼロ。新パターン導入のため、handover 側に揃える必要はないか（handover は96行で分離不要）を一応確認。整合の結論は「サイズと起動特性が異なるため individual 判断でよい」。
- スキルはセッション開始時にキャッシュされる。編集後の挙動確認（assets の Read が走るか）は新セッションで行う。

## 決定事項（annotation で確定）

1. 分離スコープ = 案A。出力テンプレート4種すべてを `assets/` へフル分離する。
2. references/ の要否 = 案B。確認フロー文面（約25行）を `references/similarity-scan-prompts.md` へ外出しする。ファイル増の管理コストは許容する。
3. invocation 方針 = 案A。`disable-model-invocation: true` を維持する（過剰起動コストが大きく明示起動が安全、最適化とは別軸のため変更しない）。変更3は実施しない。
4. インライン圧縮 = 案B。今回は分離のみ。圧縮は別タスクとし、変更4は実施しない。

## タスクリスト

### Phase 1: assets/ テンプレート分離

- [x] 1-1: `skills/research-plan-annotate/assets/research-template.md` を作成し、現 139-173 のテンプレート中身（コードフェンス内）を移す
- [x] 1-2: `assets/plan-template.md` を作成し、現 213-254 の中身を移す
- [x] 1-3: `assets/task-list-template.md` を作成し、現 312-324 の中身を移す
- [x] 1-4: `assets/result-template.md` を作成し、現 357-382 の付録の中身を移す
- [x] 1-5: SKILL.md の該当4フェンスを削除し、各箇所に「`assets/<file>` を読んで雛形に従う」の参照1〜2行へ置換する（research.mdの構成／plan.mdの構成／タスクリスト／付録）

### Phase 2: references/ 確認フロー外出し

- [x] 2-1: `skills/research-plan-annotate/references/similarity-scan-prompts.md` を作成し、現 63-87 の高/中/低類似度の確認フロー文面を移す
- [x] 2-2: SKILL.md の確認フロー文面箇所を「類似実装が見つかったら `references/similarity-scan-prompts.md` の文面で方針を確認する」の参照1行へ置換する（スキャン手順42-57・方針A選択時のHandoff省略ルール88はインライン維持）

### Phase 3: 検証

- [x] 3-1: SKILL.md の行数を確認（382→238行。目標250〜275をさらに下回り、references 外出し分が効いた）
- [x] 3-2: SKILL.md 内の相対パス参照（assets/4件・references/1件）がすべて1階層で正しいことを確認
- [x] 3-3: 残存コードフェンス2（注釈サイクルのASCII図1対のみ、markdownフェンス0）・手続き本文（スキャン手順・subagent委譲・注釈原則・ASCII図）のインライン維持を確認
- [x] 3-4: frontmatter（name/description/disable-model-invocation）が無変更であることを確認
- [x] 3-5: 分離した5ファイルの中身が元テンプレートと一致（欠落・重複なし）を確認
