# terraform-code-reviewer Agent 配置設計

Date: 2026-03-18

## 目的

`claude-code-plugins` で管理している `terraform-code-reviewer` を、`claude-code-skills` にも Agent として配置し、GitHub 経由で配布可能にする。

`claude-code-plugins` 側は変更せずそのまま残す（両リポジトリに共存する形）。

## 背景と選択理由

### Skills ではなく Agents を選んだ理由

Skills の frontmatter は `mcpServers` フィールドを未サポート。Skills が MCP を使うにはセッションレベルでグローバル設定済みである必要があり、配布物として「ユーザー側の事前設定が必要」という依存関係が生じる。

Agents の frontmatter は `mcpServers` のインライン定義をサポートしており、Agent 単一ファイルに MCP 設定を内包して完全自己完結できる。

### 自律 spawn 方式を選んだ理由

スラッシュコマンド（Skills）経由より、Claude が description を読んで自律的に spawn する方式の方が UX が自然。Terraform コードを扱う場面で自動的にレビューが走る。

## リポジトリ構造

```text
claude-code-skills/
├── install.sh                          # agents/ 対応を追加
├── skills/
│   └── handover/
│       └── SKILL.md
├── agents/
│   └── terraform-code-reviewer.md     # 新規追加
└── hooks/
    ├── stop-handover-reminder.sh
    └── precompact-handover.sh
```

インストール後:

```text
~/.claude/
├── skills/
│   └── handover  →  {REPO}/skills/handover/
├── agents/
│   └── terraform-code-reviewer.md  →  {REPO}/agents/terraform-code-reviewer.md
└── hooks/
    ├── stop-handover-reminder.sh  →  {REPO}/hooks/stop-handover-reminder.sh
    └── precompact-handover.sh     →  {REPO}/hooks/precompact-handover.sh
```

## Agent ファイル仕様

### ファイルパス

`agents/terraform-code-reviewer.md`

### frontmatter

`mcpServers` はリスト形式ではなくマッピング形式で記述する（Claude Code agents の仕様）。

```yaml
---
name: terraform-code-reviewer
description: >
  Terraform コードのレビューが必要なとき（.tf ファイルの確認依頼、
  セキュリティ・コスト・ベストプラクティス・パフォーマンスの検証など）
  に自律的に呼び出されるエージェント。
tools: Read, Write, Edit
mcpServers:
  aws-terraform-mcp-server:
    type: stdio
    command: uvx
    args: ["awslabs.terraform-mcp-server@latest"]
    env:
      FASTMCP_LOG_LEVEL: ERROR
model: inherit
color: red
---
```

`claude-code-plugins` の agent 定義との差分:

- `name` を `terraform-code-reviewer-agent` から `terraform-code-reviewer` に変更。自律 spawn では description が判断基準であり `-agent` サフィックスは不要なため省く
- `tools` から `mcp_aws-terraform-mcp-server` を削除。`mcpServers` インライン定義により MCP ツールは自動的に利用可能になるため、`tools` への明示は不要
- `description` を自律 spawn 向けに書き直し（Claude が「いつ使うか」を判断できる文言に）
- AWS_PROFILE / AWS_REGION は不要。`aws-terraform-mcp-server` は Terraform プロバイダードキュメントの参照・検証ツールであり、AWS API への直接アクセスを行わない

### 本文（流用元からの変更点）

`claude-code-plugins/terraform-code-reviewer/agents/terraform-code-reviewer.md` の本文を流用するが、以下のセクションを削除する。

削除対象: 「連携機能 > MCPサーバー連携」セクション全体（AWS Knowledge MCP・AWS Documentation MCP・AWS Terraform MCP の 3 行）。`claude-code-skills` の Agent は `aws-terraform-mcp-server` のみを持ち、他の MCP は利用できないため、このセクションは実態と合わない。代替記述は設けない（frontmatter の `mcpServers` に明記されているため重複になる）。

「連携機能 > 外部ツール連携」セクション（Terraform Plan / Validate / Security Scanners / Cost Calculators）はそのまま残す。これらは Agent が直接実行するツールではなく、ユーザーが別途実行することを想定した参考情報として機能する。

`tools` には `Bash` を含まない。このエージェントの役割はコードの読み取りと分析・改善提案の生成であり、terraform コマンドの実行は行わない。これは意図的な設計判断であり、ユーザー環境への副作用（terraform apply 等の誤実行）を防ぐためでもある。

`tools` に `Write` と `Edit` を含む理由: レビュー結果として改善されたコードをファイルに直接書き込むケース（ユーザーが修正適用を依頼した場合など）に対応するため。読み取りのみではなく、提案の適用まで担う設計。

流用元の本文に含まれる絵文字と太字（`**text**`）について、以下のルールで処理する。

除去する対象:
- 箇条書きや文章の中に埋め込まれた太字（例: `**ネットワークセキュリティ**`）
- サマリー行の `📊` 等の装飾的な絵文字

除去しない対象:
- コードブロック（``` 区切り）内の絵文字（エージェントの出力フォーマット例であるため）
- 「優先度別フィードバック」セクションの見出しに含まれる `🔴` `🟡` `🟢`（高・中・低優先度の視覚的マーカーとして機能しており、除去すると優先度の区別が失われるため残す）

「使用例」セクション（流用元の「基本的な使用方法」「特定の観点でのレビュー」「段階的改善の提案」）は削除する。本文中に `terraform-code-reviewer-agent` という旧名が記載されており、このエージェントの name と不一致になるため。

それ以外のセクション（主要機能、レビュープロセス、出力形式、チェックリスト、注意事項）はそのまま流用する。

## install.sh の変更

既存の skills ループ・hooks ループに加えて、agents ループを追加する。追加位置は最終行の `echo "Done."` の直前とする。

skills はディレクトリ単位のシンボリックリンク、agents はファイル単位のシンボリックリンクという違いがある。

シンボリックリンクは `REPO_DIR`（スクリプト冒頭で `$(cd "$(dirname ...)" && pwd)` により絶対パスに解決済み）を使って絶対パスで作成する。これは既存の hooks ループと同じパターン。

既存ファイルの上書きポリシーは hooks ループと同じとする（実ファイルが存在する場合は警告を出した上で削除してシンボリックリンクに置き換える）。skills ループが実ディレクトリを保護してスキップするのは、ディレクトリ内に手動で追加したファイルが存在しうるためであり、単一ファイルの agents にはその懸念がない。

agents ループには `chmod +x` を行わない。`.md` ファイルであり実行権限は不要（hooks ループが `chmod +x` をする理由はシェルスクリプトだから）。

```bash
# agents: ファイルごと symlink
AGENTS_DST="${CLAUDE_DIR}/agents"
mkdir -p "${AGENTS_DST}"

for agent_file in "${REPO_DIR}/agents"/*.md; do
  [ -f "${agent_file}" ] || continue
  name=$(basename "${agent_file}")
  dst="${AGENTS_DST}/${name}"

  if [ -L "${dst}" ]; then
    rm "${dst}"
  elif [ -f "${dst}" ]; then
    echo "WARNING: ${dst} is a real file. Replacing with symlink."
    rm "${dst}"
  fi

  ln -sf "${agent_file}" "${dst}"
  echo "agent: ${name} -> ${dst}"
done
```

## README の更新

「スキル一覧」セクションの直後に「エージェント一覧」セクションを新設する。記載内容:

- terraform-code-reviewer の概要（セキュリティ・コスト・ベストプラクティス・パフォーマンスの自律レビュー）
- 自律 spawn の動作説明（`~/.claude/agents/` に配置された Agent は、ユーザーがプロンプトを送信したとき Claude が description を判断して自動的に spawn する。「このコードをレビューして」などの自然言語依頼が起点となる。`settings.json` への追記は不要）
- 前提条件として `uvx` コマンドが必要であることと、インストール方法（`curl -LsSf https://astral.sh/uv/install.sh | sh`）を「エージェント一覧」セクション内に記載する（グローバルな「前提条件」セクションには追記しない。`uvx` は Agent を使う場合にのみ必要であり、handover skill だけ使うユーザーへの誤解を避けるため）
- 動作確認の例（`.tf` ファイルが存在するプロジェクトで「このTerraformコードをレビューして」と依頼すると、Agent が自動的に起動することを示す。既存 README の「使用方法」セクションに合わせてコードブロック形式でプロンプト例を示す）

既存の README の以下の箇所も合わせて更新する:

- 冒頭の概要文（「Claude Codeのパーソナルスキルとフックスクリプトをgit管理する」）を agents も含む表現に変更する
- 「インストール手順」の symlink 一覧に `~/.claude/agents/terraform-code-reviewer.md → {REPO}/agents/terraform-code-reviewer.md` を追記する（現行 README の symlink 一覧に `stop-handover-reminder.sh` が欠落しているが、その修正はこのタスクのスコープ外とする）
- アーキテクチャ図の「リポジトリ構成」に `agents/terraform-code-reviewer.md` のエントリを追記し、「インストール後の構成」に `~/.claude/agents/terraform-code-reviewer.md → {REPO}/agents/terraform-code-reviewer.md` のエントリを追記する（既存エントリは変更しない）

## 制約・前提

- `uvx` コマンドが利用可能であること（`awslabs.terraform-mcp-server` の起動に必要）
- `claude-code-plugins` 側の terraform-code-reviewer は変更しない
- 両リポジトリの agent 本文は独立して管理する（同期の仕組みは設けない）
- `settings.json` へのユーザー側設定変更は不要（自律 spawn は `~/.claude/agents/` への配置のみで機能する）
- `claude-code-plugins` と `claude-code-skills` の両方をインストールしたユーザーには `terraform-code-reviewer-agent`（プラグイン側）と `terraform-code-reviewer`（スキルズ側）の2つの Agent が存在する。name が異なるため衝突は起きないが、description が類似しているため Claude が両方を spawn 候補として認識する可能性がある。これは許容範囲とし、対処はしない
