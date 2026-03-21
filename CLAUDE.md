# claude-code-skills

## Project structure

- `skills/` - Skill plugins (slash commands). Symlinked to `~/.claude/skills/` by install.sh.
- `agents/` - Agent definitions (.md files). Symlinked to `~/.claude/agents/` by install.sh.
- `hooks/` - Hook scripts (.sh files). Symlinked to `~/.claude/hooks/` by install.sh.
- `.claude/docs/` - Design specs and implementation plans.

## Install

`bash install.sh` creates symlinks from ~/.claude/{skills,agents,hooks} to this repo.
`bash install.sh TYPE:NAME ...` で個別インストール（例: `skills:handover agents:terraform-code-reviewer`）。

## Testing

- `bash tests/test_install.sh` — install.sh の回帰テスト（CLAUDE_CODE_DIR 環境変数で出力先をオーバーライド）

## Skill authoring rules

- SKILL.md frontmatter の `hooks:` で依存 hooks を宣言できる（2スペースインデント必須）。

## Agent authoring rules

- Agent frontmatter `mcpServers` uses mapping format (key → attributes), NOT list format.
- Skills frontmatter does NOT support `mcpServers`. MCP-dependent tools must be agents.
- Agent `description` text determines when Claude autonomously spawns it — wording matters.
- Agents placed in `~/.claude/agents/` need no settings.json changes to be spawn-eligible.
