# 課題本文テンプレート

必須は Overview / Todo List / References の3セクション。Target environment と Out of scope は条件を満たすときだけ足す。この5つ以外の見出しを増やさない。

スラッシュで併記された見出し（`Overview / Purpose / Background` など）は、そのまま1つの見出しとして書く。いずれかを選ぶ形ではない。

Backlog記法のプロジェクトでは、見出しを `*` / `**` に、リンクを `[[label>url]]` に変換する（backlog-notation スキル参照）。箇条書き `-` とチェックリスト `- [ ]` / `- [x]` は両記法で同じ書き方で通る。ただしチェックリストが機能するのは課題の説明欄だけで、コメント欄では機能しない。

## 骨組み

```markdown
# Overview / Purpose / Background

<なぜこの課題が必要か。親課題や前フェーズとの関係、現状の何が問題か、この課題で何を変えるか。3〜6文>

# Target environment

- [ ] dev
- [ ] staging
- [ ] production

# Todo List / Complete condition

- [ ] <レビューまたは検証できる単位のタスク>
- [ ] <検証手順。何をどう見て成功と判断するか>

# Out of scope

- <対象外の項目と、外す理由>

# References / Slack Link

- Parent: PROJ-100
- PR: <プルリクエストの URL>
- Spec: <設計ドキュメントの URL>
- Chat: <チャットスレッドの URL>
```

## 各セクションの書き方

Overview / Purpose / Background は必須。背景と目的をここに集約する。「前提条件」「注意点」といった見出しを別に立てず、この文章に畳む。読者がこの課題単体を読んで、何が済んでいて何が残っているか分かる状態にする。起票後に確定した作業ブランチ名を書く場合も、見出しを増やさずこの節の末尾に1行で足す。

Target environment は複数環境へ順次展開する課題でだけ使う。Overview の直後に置き、チェックボックスをロールアウトの進捗トラッカーとして使う。1環境だけの課題では書かない。1環境内の複数ホストへ順次適用する場合も使わず、Todo List で追う（環境跨ぎか否かで判断する）。

Todo List / Complete condition は必須。完了条件を兼ねるので、検証項目を必ず含める。粒度は SKILL.md 参照。

Out of scope は、意図的に含めない範囲があって書かないと誤解される場合だけ使う。Todo List の後に置く。典型は、ツールの管理外で手作業する手順を柵で囲うケース。

References / Slack Link は必須。課題は裸のキー（`PROJ-100`）で書けば自動リンクされる。プルリクエスト・ドキュメント・チャットは絶対 URL で書く。書けるものが何も無くても見出しは消さず、最低でも関連する課題を1つ挙げる。見出しの後半（`/ Slack Link` の部分）は、チームが使っているチャットの名前に合わせて読み替えてよい。
