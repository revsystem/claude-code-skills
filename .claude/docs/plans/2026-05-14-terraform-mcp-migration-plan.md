# terraform-code-reviewer (skills) MCP 移行計画

日時: 2026-05-14
関連調査: `.claude/docs/research/2026-05-14-terraform-mcp-migration-research.md`

## 概要

`agents/terraform-code-reviewer.md` の frontmatter `mcpServers` を、yanked 済みの
`awslabs.terraform-mcp-server` から `aws-documentation-mcp-server` + `aws-knowledge-mcp-server` に置き換える。

## 変更内容

対象: `agents/terraform-code-reviewer.md`

```yaml
# 変更前
mcpServers:
  aws-terraform-mcp-server:
    type: stdio
    command: uvx
    args: ["awslabs.terraform-mcp-server@latest"]
    env:
      FASTMCP_LOG_LEVEL: ERROR

# 変更後
mcpServers:
  aws-documentation-mcp-server:
    type: stdio
    command: uvx
    args: ["awslabs.aws-documentation-mcp-server@latest"]
    env:
      FASTMCP_LOG_LEVEL: ERROR
      AWS_DOCUMENTATION_PARTITION: aws
      MCP_USER_AGENT: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
  aws-knowledge-mcp-server:
    type: http
    url: https://knowledge-mcp.global.api.aws
```

`tools:` は変更しない（`Read, Write, Edit` のまま）。

## タスクリスト

### Phase 1: 実装
- [x] 1-1: `agents/terraform-code-reviewer.md` の frontmatter `mcpServers` を更新する

### Phase 2: コミット・PR
- [ ] 2-1: ブランチを作成してコミットする
- [ ] 2-2: Issue を作成して PR に紐付ける
