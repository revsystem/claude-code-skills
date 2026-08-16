---
# プルリクエスト本文テンプレート

各言語ブロックの中で、概要を先に、変更の詳細を後に置く。

2言語で併記する場合は、英語のブロックを先に、もう一方の言語のブロックを後に置く。言語区切りの見出し（「English」「日本語」など）は付けず、各セクションの見出しをその言語で書くことで切り替える。1言語で運用しているチームは、下の骨組みの前半だけをその言語で書く。

Backlog記法のプロジェクトでは、見出しを `*` / `**` に、リンクを `[[label>url]]` に変換する（backlog-notation スキル参照）。チェックリスト `- [ ]` はプルリクエスト本文では機能しないので、箇条書き `-` を使う。

## 骨組み

```markdown
## Overview

<What this change adds or modifies, and why. 2-4 sentences.>
<Whether behavior changes now, or is gated behind a disabled flag.>
<If the work is split into phases, how far this PR goes.>

## Changes

- <path>: <what changed here, and the reasoning behind any design decision>
- <path>: <same>

## Notes for review

- <what to look at closely, or what to watch out for when applying>

## 概要

<この変更で何をするか。2〜4文>
<動作が変わるか、フラグで無効化されているか>
<フェーズ分割している場合、このプルリクエストがどこまでか>

## 変更点

- <path>: <何を変更したか。設計判断があれば理由も>
- <path>: <同上>

## レビュー観点

- <特に見てほしい点、または適用時の注意>
```

## 書き方

概要は数行に収める。差分の全部を説明せず、レビュアーが最初に知りたいこと（何が変わるか、今すぐ動き出すのか）を先に置く。デフォルト無効のフラグで囲われているなら、そう書くだけでレビューの緊張度が下がる。

変更点は変更ファイル単位で書く。ファイル名だけ並べても差分を見れば分かるので、そのファイルで何を決めたかを書く。既存のパターンから外れた選択をしたなら、外した理由を必ず書く。

適用順序の制約や、この変更だけでは完結しない依存（別リポジトリの設定、手動で入れる値など）は本文に明記する。マージした人が次に何をすればいいか分かる状態にする。

両言語のブロックは同じ構成の見出しを立て、対応する内容を書く。片方にしかない情報を作らない。

絵文字は使わない。Backlog API が4バイト UTF-8 を拒否する。

