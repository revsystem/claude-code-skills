# implement-verify-record スキル 実装計画

日時: 2026-06-28
関連調査: `.claude/docs/research/2026-06-28-implement-verify-record-research.md`
関連設計仕様: `.claude/docs/specs/2026-06-28-gated-implementation-skill-spec.md`

## 概要

research-plan-annotate が生成した plan.md のユニット・グルーピングを入力に、実装をユニット単位のゲートで区切る新スキル implement-verify-record を新設する。各ユニットで「実装 → 検証 → レビュー → 承認」を回し、全ユニット完了後に result.md を記録する。あわせて research-plan-annotate の Phase 5 Handoff を、run-to-completion 指示から新スキルへの引き継ぎへ差し替える。

## アプローチ

spec のアーキテクチャ判断（案 B）に従い、計画スキルと実装スキルを対称的な単一責任に分離する。新スキルは research-plan-annotate の構造・規約・assets を流用しつつ別スキルとして新設する。ゲート選択ロジックは参照ファイルを新設せず SKILL.md にインライン化する（過去の論点2=A と整合）。result.md は別スキルの assets を実行時参照すると脆いため、新スキル本文に節構成を内包し散文で参照する（テンプレートファイルは複製しない）。

採用しなかった案: research-plan-annotate の拡張（案 A、実装時の強制力が弱い）、統合スキルへの再設計（案 C、肥大化）。いずれも spec で却下済み。

## 変更内容

### 変更1: 新スキル SKILL.md を新規作成

対象: `skills/implement-verify-record/SKILL.md`（新規）

````markdown
---
name: implement-verify-record
description: Gated implementation of a unit-grouped plan.md produced by research-plan-annotate. Runs each unit through implement, verify, human review, and approval before advancing, then records a result.md. The execution-phase counterpart to research-plan-annotate.
disable-model-invocation: true
---

# implement-verify-record ワークフロー

research-plan-annotate が生成した plan.md のユニット・グルーピングを入力に、実装をユニット単位のゲートで区切りながら進めるスキル。各ユニットで「実装 → 検証 → レビュー → 承認」を回し、全ユニット完了後に result.md を記録する。

計画フェーズ（research-plan-annotate）の核心が「don't implement yet」なら、実装フェーズの核心は「ゲートを越えて次のユニットに進まない」。承認なしに走り続けることを禁じる、同じ精神の実装フェーズ版とする。

## いつ使うか

- research-plan-annotate で plan.md を固めた後、実装に移るとき
- 中断したセッションの実装を、未完了ユニットから再開するとき
- 計画スキルを通さない小規模作業を、最小計画を挟んでゲート付きで実装するとき

このスキルは現在の作業ディレクトリの `.claude/docs/` のみを参照する。別プロジェクトの成果物は横断参照しない。

## 着手前: 計画の解決（ゼロ番目のゲート）

実装ループに入る前に、どの plan.md を実装するかを確定し、ユーザーの確認を取る。これが最初のゲート。

1. 引数で対象を指定された場合（例: `/implement-verify-record プロジェクトAの実装を開始して`）、その語を `.claude/docs/plans/` のファイル名・トピックslugに照合する。
   - 一意に決まれば、その plan.md と、ヘッダがリンクする spec.md / research.md を読み、「この計画を実装します」と対象パスを提示して確認を取る。
   - 複数候補に当たる場合は候補を一覧にして選ばせる。
2. 引数なしの場合、`.claude/docs/plans/` の plan.md を日付の新しい順に、トピック名・日付・完了状況を添えて一覧提示し、どれを実装するか選ばせる。最新を黙って自動選択しない。誤った計画の実装は巻き戻しの利かない高コストの失敗になるため。
3. 選んだ plan.md のユニットに既に完了マークがある場合、中断セッションと判断し「次の未完了ユニットから再開するか、最初からやり直すか」を確認する。

plan.md が見つからない場合は「plan.md が無い場合のフォールバック」へ進む。

## ゲート種別と自動選択

ユニットごとに、3種のゲートから1つ（高リスクでは2つ）を選ぶ。

- 事前宣言型: 着手前に「このユニットで何をするか」を宣言し、承認を取ってから着手する。
- diff レビュー型: 完了後に diff を見せ、承認を取ってから次へ進む。
- 進捗確認型: 完了後に何をやったかを要約報告し、続行可否だけ確認する。

### リスク判定

ユニットを次の観点で評価する。1つでも該当すれば高リスク寄りに倒す。

- 不可逆性: マイグレーション、データ削除、外部 API への書き込み、デプロイ
- セキュリティ機微: 認証、権限、秘密情報、課金
- 影響範囲: 共有モジュール、コア抽象、依存元の多いコード
- 不確実性: plan.md で残決定事項だった箇所、不慣れな領域、実装中に新たな設計判断が要る箇所

### 選択ロジック

- 高リスク: 事前宣言で着手前に方向を承認させ、完了後に diff レビューも挟む（前後で挟み込む）。
- 中リスク（通常のユニット）: 完了後の diff レビュー。
- 低リスク（機械的・自己完結・容易に巻き戻せる）: 進捗確認だけで素通し。

### 深度による調整

深度は plan.md から引き継ぐ（research-plan-annotate が計画時に宣言する minimal / standard / comprehensive）。深度がベースラインを決める。

- minimal: ゲートなしで通し、最後に一度だけ確認する。
- standard: diff レビューを基準に、高リスクで挟み込み・低リスクで進捗確認に緩和する。
- comprehensive: 挟み込みを厚めにする。

着手前のゼロ番目のゲートで、各ユニットに割り当てる予定のゲート種別を一覧で提示し、合意を取ってからループに入る。

## ユニットごとの実装ループ

ユニットを1つずつ、次の順で処理する。

1. （事前宣言型のユニットのみ）着手前に宣言し、承認を取る。
2. 実装する。plan.md のそのユニットのタスクに従う。
3. 検証する。プロジェクトのテスト・ビルドコマンドを実際に実行する。コマンドが不明なら確認する。
4. ゲートにかける。検証結果（実行したコマンドと出力）を添えて、選んだゲート種別で提示する。「やったと主張するコード」ではなく「動く証拠付きのコード」をレビューに出す。
5. 承認を待つ。承認が出るまで次のユニットに進まない。修正指示があれば反映し、再度ゲートにかける。
6. plan.md のそのユニットを完了としてマークする。
7. 次のユニットへ。並列化可能と明示されたユニット群がある場合も、ゲートは1ユニットずつ取る。

承認なしにゲートを越えない。これがこのスキルの核心。

## plan.md が無い場合のフォールバック

plan.md が見つからない、または計画スキルを通さず直接呼ばれた場合、いきなり実装に入らず、頑なに拒否もしない。作業規模で挙動を分ける。

- 作業が小規模: スキル内で軽量なユニット分解を一度挟む。対象コードを読み、作業をユニットに割り、ユニット一覧と各ユニットの想定ゲート種別を提示して承認を取り、実装ループに入る（research-plan-annotate の minimal 深度に相当する最小計画）。
- 作業が実質的（複数ファイル横断・高リスク・ドメイン理解が必要）: その場分解で押し切らず、research-plan-annotate を先に通すことを勧める。ユーザーが承知のうえで続行を選べば、その場分解で進めつつ「research による裏付けが無い」ことを明示してから始める。

## 完了: result.md 記録と Handoff

全ユニットの実装・検証・承認が完了したら、結果を result.md に記録する。

保存先はプロジェクトルートの `.claude/docs/reports/` に `YYYY-MM-DD-<topic>-result.md`。構成は research-plan-annotate の `assets/result-template.md`（reports は「参考の出発点」であり厳密な型ではない）に倣い、最低限つぎを含める: 冒頭に実装した plan.md / research.md へのリンク、サマリ（合否・主要な発見）、検証内容（実行コマンドと結果）、残課題・次のアクション、結論。単体実行で上流アーティファクトが無い場合は、リンクを空にせず「上流計画なし（単体実行）」と明記する。

記録後、次のメッセージで締める:

> 全ユニットの実装・検証・承認が完了しました。
>
> - 実装計画: `.claude/docs/plans/YYYY-MM-DD-<feature-name>-plan.md`（全ユニット完了マーク済み）
> - 検証結果: `.claude/docs/reports/YYYY-MM-DD-<topic>-result.md`
>
> 残課題やフォローアップがあれば result.md の「残課題・次のアクション」に記載しています。

## 原則

- ゲートを越えて次のユニットに進まない。承認なしに走り続けない。これが実装フェーズの「don't implement yet」。
- 各ユニットは検証してからゲートにかける。証拠（実行コマンドと出力）を添えてレビューに出す。
- ゲート種別はリスクと深度で自動選択する。低リスクは進捗確認に緩和し、ボトルネックを避ける。
- plan.md を入力の基点とし、進行に伴って完了マークを更新する。中断時は未完了ユニットから再開する。
- 計画スキルを通さない実質的な作業では research-plan-annotate へ誘導する。読んでいないファイルを変更しない。
- 完了後は result.md に検証結果と残課題を残し、後続セッションが追えるようにする。
````

### 変更2: research-plan-annotate の Phase 5 Handoff を差し替え

対象: `skills/research-plan-annotate/SKILL.md`

置換前（exact）:

```
全フェーズ完了後、以下のメッセージで実装フェーズへ引き継ぐ:

> Design Spec → Research → Plan → Annotateが完了しました。
>
> - 設計仕様: `.claude/docs/specs/YYYY-MM-DD-<topic>-spec.md`
> - 調査レポート: `.claude/docs/research/YYYY-MM-DD-<topic>-research.md`
> - 実装計画: `.claude/docs/plans/YYYY-MM-DD-<feature-name>-plan.md`
>
> plan.mdにタスクリストが入っています。以下の指示で実装を開始できます:
>
> 「plan.mdに従ってすべてを実装してください。タスクまたはフェーズが完了したら、plan.mdで完了としてマークしてください。すべてのタスクとフェーズが完了するまで停止しないでください。不要なコメントを追加しないでください。」
>
> 実装とローカル/ステージング検証が完了したら、結果を `.claude/docs/reports/YYYY-MM-DD-<topic>-result.md` に記録してください（検証結果・残課題・判断材料を後続セッションや関係者が追えるように）。
```

置換後:

```
全フェーズ完了後、以下のメッセージで実装フェーズへ引き継ぐ:

> Design Spec → Research → Plan → Annotateが完了しました。
>
> - 設計仕様: `.claude/docs/specs/YYYY-MM-DD-<topic>-spec.md`
> - 調査レポート: `.claude/docs/research/YYYY-MM-DD-<topic>-research.md`
> - 実装計画: `.claude/docs/plans/YYYY-MM-DD-<feature-name>-plan.md`
>
> plan.md にユニット・グルーピング済みのタスクリストが入っています。実装は implement-verify-record スキルで、ユニットごとにゲート（実装 → 検証 → レビュー → 承認）を挟みながら進めます。次のように開始してください:
>
> 「/implement-verify-record この計画の実装を開始して」
>
> implement-verify-record は承認なしに次のユニットへ進みません。全ユニット完了後、検証結果を `.claude/docs/reports/YYYY-MM-DD-<topic>-result.md` に記録します。
```

### 変更3: README にスキルを追記（3箇所）

対象: `README.md`

3-1. スキル一覧表。置換前（exact）:

```
| `research-plan-annotate` | 実装前に「調べる → 計画する → 注釈で磨く」を回し、`research.md` / `plan.md` を成果物とする | `/research-plan-annotate` | |
```

置換後:

```
| `research-plan-annotate` | 実装前に「調べる → 計画する → 注釈で磨く」を回し、`research.md` / `plan.md` を成果物とする | `/research-plan-annotate` | |
| `implement-verify-record` | plan.md のユニットをゲート境界に、実装 → 検証 → レビュー → 承認をユニットごとに回し、`result.md` を記録する | `/implement-verify-record <計画の指定>` | research-plan-annotate と連携 |
```

3-2. 使用方法。置換前（exact）:

````
### research-plan-annotate

コードを書く前に「調べる → 計画する → 注釈で磨く」を回すワークフロースキルです。

```
/research-plan-annotate <タスクの説明>
```

## アーキテクチャ
````

置換後:

````
### research-plan-annotate

コードを書く前に「調べる → 計画する → 注釈で磨く」を回すワークフロースキルです。

```
/research-plan-annotate <タスクの説明>
```

### implement-verify-record

research-plan-annotate が作った plan.md を、ユニットごとにゲート（実装 → 検証 → レビュー → 承認）を挟みながら実装するワークフロースキルです。承認なしに次のユニットへ進みません。全ユニット完了後に `result.md` を記録します。

```
/implement-verify-record <計画の指定>
```

## アーキテクチャ
````

3-3. アーキテクチャツリー。置換前（exact）:

```
│   └── research-plan-annotate/
│       └── SKILL.md                 # 調査・計画・注釈サイクルスキル定義
```

置換後:

```
│   ├── research-plan-annotate/
│   │   └── SKILL.md                 # 調査・計画・注釈サイクルスキル定義
│   └── implement-verify-record/
│       └── SKILL.md                 # ゲート付き実装サイクルスキル定義
```

## 影響範囲

- 既存テスト: 影響なし。スキルは gh skill 系統で install.sh / tests/test_install.sh の対象外。
- API変更: なし。
- マイグレーション: なし。
- 既存スキルへの影響: research-plan-annotate の Phase 5 本文のみ変更。原則・付録（result-template）は不変。付録の result-template は新スキルが参照し続ける正本。
- 配布: implement-verify-record は新規スキルのため、リリース後に `gh skill install ... implement-verify-record` で個別配布する。research-plan-annotate は内容更新のため `gh skill update`（タグはリモート main 同期後に作成）。

## 考慮事項

ドッグフード（動作確認）の安全手順。`~/.claude/skills/` の既存ファイルは gh skill 管理下で frontmatter により版管理されるため、上書きすると `gh skill update` が効かなくなる。退避・復元方式で行う。

最小経路（gh管理ファイルを一切触らない）。implement-verify-record は新規なので、退避不要で仮置きし、検証後に削除する。これが主経路。

```bash
# 仮置き（新規スキルのみ。gh管理ファイルは触らない）
mkdir -p ~/.claude/skills/implement-verify-record
/bin/cp -f skills/implement-verify-record/SKILL.md ~/.claude/skills/implement-verify-record/SKILL.md
# （新セッションで /implement-verify-record をドッグフード）
# 後始末（将来の gh skill install がクリーンに入るように削除）
rm -rf ~/.claude/skills/implement-verify-record
```

任意経路（research-plan-annotate の新 Handoff 文言も確認したい場合）。gh管理下の正本を退避してから dev 版を置き、検証後に必ず戻す。二重退避で正本を壊さないようガードする。

```bash
# 退避（正本が未退避のときだけ退避）
BAK=~/.claude/skills/research-plan-annotate/SKILL.md.orig
[ -e "$BAK" ] || /bin/cp -f ~/.claude/skills/research-plan-annotate/SKILL.md "$BAK"
# dev 版を同期
/bin/cp -f skills/research-plan-annotate/SKILL.md ~/.claude/skills/research-plan-annotate/SKILL.md
# （新セッションで確認）
# 復元（退避した正本を戻し、退避ファイルを消す）
/bin/cp -f "$BAK" ~/.claude/skills/research-plan-annotate/SKILL.md && rm -f "$BAK"
```

その他の考慮事項:

- スキル本文はセッション開始時にキャッシュされる。同期後の確認は必ず新セッションで行う。同一セッションでは旧版のまま。
- `cp` は対話 alias（`-i`）に化けて上書きされないことがあるため `/bin/cp -f` を使う。
- セキュリティ: 秘密情報を含むファイルは扱わない。新スキルはドキュメントのみ。
- 後方互換性: research-plan-annotate の利用者は Phase 5 の案内文が変わるだけで、既存 plan.md の形式は不変。

## タスクリスト

大区分は独立実装可能な「ユニット」でまとめる。ユニットA/B/C は互いに異なるファイルを触り依存しないため並列実装（subagent 委譲）可能。ユニットD は A・B の成果物を同期して検証するため並列不可。

### ユニットA: 新スキル SKILL.md 作成（並列可: 依存なし）
- [x] A-1: `skills/implement-verify-record/SKILL.md` を変更1の内容で新規作成する
- [x] A-2: `head -5 skills/implement-verify-record/SKILL.md` で `name: implement-verify-record` と `disable-model-invocation: true` を確認する
- [x] A-3: `grep -c '^## ' skills/implement-verify-record/SKILL.md` が6以上、`grep -c 'ゲートを越えて次のユニットに進まない' skills/implement-verify-record/SKILL.md` が2であることを確認する
- [x] A-4: `git add` して `feat(implement-verify-record): add gated implementation skill` でコミットする

### ユニットB: research-plan-annotate Phase 5 差し替え（並列可: 依存なし）
- [x] B-1: 変更2 の置換を `skills/research-plan-annotate/SKILL.md` に適用する
- [x] B-2: `grep -c 'すべてのタスクとフェーズが完了するまで停止しないでください' skills/research-plan-annotate/SKILL.md` が0、`grep -c '/implement-verify-record' skills/research-plan-annotate/SKILL.md` が1であることを確認する
- [x] B-3: `git add` して `feat(research-plan-annotate): hand off to implement-verify-record at Phase 5` でコミットする

### ユニットC: README 追記（並列可: 依存なし）
- [x] C-1: 変更3-1（スキル一覧表に行追加）を適用する
- [x] C-2: 変更3-2（使用方法に小節追加）を適用する
- [x] C-3: 変更3-3（アーキテクチャツリー更新）を適用する
- [x] C-4: `grep -c 'implement-verify-record' README.md` が4以上であることを確認し、`docs(readme): list implement-verify-record skill` でコミットする

### ユニットD: ドッグフード検証（並列不可: 依存 = A, B）
- [x] D-1: 考慮事項の最小経路コマンドで新スキルを `~/.claude/skills/implement-verify-record/` に仮置きする
- [x] D-2: 新セッションで `/implement-verify-record` を引数なし実行 → plan.md 一覧提示・選択要求（自動選択しない）を確認する
- [x] D-3: 本計画を選択 → 着手前にゲート種別の割り当て提示と承認要求が出ること、承認まで実装に進まないことを確認する
- [x] D-4: 後始末（`rm -rf ~/.claude/skills/implement-verify-record`）。任意経路（research-plan-annotate の退避→同期→復元）は低リスクにつき不実施
