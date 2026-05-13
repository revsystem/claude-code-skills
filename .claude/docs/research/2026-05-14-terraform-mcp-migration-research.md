# terraform-code-reviewer (skills) MCP 移行調査レポート

日時: 2026-05-14

## 対象範囲

- `agents/terraform-code-reviewer.md`（frontmatter の `mcpServers` フィールド）

## 問題の背景

plugins 側と同一。`uvx awslabs.terraform-mcp-server@latest` が全バージョン yanked されており起動不能。
本リポジトリ（skills）の `agents/terraform-code-reviewer.md` も同じ MCP を frontmatter で参照している。

## 現在の frontmatter

```yaml
tools: Read, Write, Edit
mcpServers:
  aws-terraform-mcp-server:
    type: stdio
    command: uvx
    args: ["awslabs.terraform-mcp-server@latest"]
    env:
      FASTMCP_LOG_LEVEL: ERROR
```

`tools:` に MCP 名は含まれていない（skills 側は frontmatter の `mcpServers` で完結する仕様）。

## plugins 側との仕組みの違い

| 観点 | plugins | skills |
|---|---|---|
| MCP 定義場所 | `mcps/*.json` + `marketplace.json` | agent frontmatter の `mcpServers:` |
| `tools:` への記載 | 必要（`mcp_サーバー名`） | 不要 |
| JSON ファイル | 必要 | 不要 |

## 変更方針

plugins 側で採用した方針をそのまま適用する。

- `aws-terraform-mcp-server` エントリを削除
- `aws-documentation-mcp-server`（uvx、stdio）を追加
- `aws-knowledge-mcp-server`（http）を追加

`tools:` フィールドは変更不要（`Read, Write, Edit` のまま）。

## 注意点

- `aws-knowledge-mcp-server` は `type: http` で `url:` を指定する形式（stdio ではない）
- plugins 側の JSON から値を参照:
  - documentation: `uvx awslabs.aws-documentation-mcp-server@latest`
  - knowledge: `url: https://knowledge-mcp.global.api.aws`
