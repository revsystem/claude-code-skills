# claude-code-skills

## Project structure

- `skills/` - Skill plugins (slash commands). Installed via `gh skill`.
- `agents/` - Agent definitions (.md files). Symlinked to `~/.claude/agents/` by install.sh.
- `hooks/` - Hook scripts (.sh files). Symlinked to `~/.claude/hooks/` by install.sh.
- `.claude/docs/` - Design specs and implementation plans (committed to git).
- `.claude/handovers/` - Session handover notes (committed to git).

## Install

`bash install.sh` creates symlinks from ~/.claude/{agents,hooks} to this repo.
`bash install.sh TYPE:NAME ...` で個別インストール（例: `agents:terraform-code-reviewer hooks:stop-handover-reminder.sh`）。
`gh skill install revsystem/claude-code-skills --agent claude-code --scope user` でスキルをインストール。

## gh skill の注意点

- `gh skill install` は `~/.claude/skills/` にファイルをコピーする（シンボリックリンクではない）。`installed_plugins.json` には登録されない（プラグイン管理とは別系統）。

## Testing

- `bash tests/test_install.sh` — install.sh の回帰テスト（CLAUDE_CODE_DIR 環境変数で出力先をオーバーライド）

## Skill authoring rules

- スキルファイルはセッション開始時にキャッシュされる。編集後のテストは新セッションで行う。

## Agent authoring rules

- Agent frontmatter `mcpServers` uses mapping format (key → attributes), NOT list format.
- Setting a `tools` allowlist excludes MCP tools unless listed. `mcpServers` connects the server, but the allowlist gates callable tools — add `mcp__<server-name>` (whole server) or `mcp__<server-name>__<tool>` for each MCP server the agent needs. Omitting `tools` inherits all tools including MCP.
- This repo ships user-level agents (bare server names like `mcp__aws-documentation-mcp-server`). In plugin scope, MCP names are namespaced `mcp__plugin_<plugin-name>_<server-name>__<tool>`, coupling the allowlist to the plugin/marketplace name (breaks on rename). For plugin agents prefer `disallowedTools: Write, Edit` (MCP auto-inherited, read-only preserved) over a `tools` allowlist; for user agents the bare-name allowlist stays cleaner.
- Skills frontmatter does NOT support `mcpServers`. MCP-dependent tools must be agents.
- Agent `description` text determines when Claude autonomously spawns it — wording matters.
- Agents placed in `~/.claude/agents/` need no settings.json changes to be spawn-eligible.

## Working files

- `.claude/docs/` and `.claude/handovers/` are committed to git and tracked in this repository.
