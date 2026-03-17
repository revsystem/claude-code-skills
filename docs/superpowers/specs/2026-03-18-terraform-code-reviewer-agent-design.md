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

```yaml
---
name: terraform-code-reviewer
description: >
  Terraform コードのレビューが必要なとき（.tf ファイルの確認依頼、
  セキュリティ・コスト・ベストプラクティス・パフォーマンスの検証など）
  に自律的に呼び出されるエージェント。
tools: Read, Write, Edit
mcpServers:
  - aws-terraform-mcp-server:
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

- `tools` から `mcp_aws-terraform-mcp-server` を削除（`mcpServers` インライン定義に移行）
- `description` を自律 spawn 向けに書き直し

### 本文

`claude-code-plugins/terraform-code-reviewer/agents/terraform-code-reviewer.md` の本文（レビューロジック、チェックリスト、出力形式）をそのまま流用する。

## install.sh の変更

既存の skills ループ・hooks ループに加えて、agents ループを追加する。

skills はディレクトリ単位のシンボリックリンク、agents はファイル単位のシンボリックリンクという違いがある。

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

`agents/` セクションを新設し、以下を記載する:

- terraform-code-reviewer の概要と自律 spawn の動作説明
- uvx（astral-sh/uv）の前提条件（MCP サーバーの起動に必要）
- インストール後の動作確認方法

## 制約・前提

- `uvx` コマンドが利用可能であること（`awslabs.terraform-mcp-server` の起動に必要）
- `claude-code-plugins` 側の terraform-code-reviewer は変更しない
- 両リポジトリの agent 本文は独立して管理する（同期の仕組みは設けない）
