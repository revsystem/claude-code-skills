# claude-code-skills

## Project structure

- `skills/` - Skill plugins (slash commands). Installed via `gh skill`.
- `agents/` - Agent definitions (.md files). Symlinked to `~/.claude/agents/` by install.sh.
- `hooks/` - Hook scripts (.sh files). Symlinked to `~/.claude/hooks/` by install.sh.
- `.claude/docs/` - Design specs and implementation plans.

## Install

`bash install.sh` creates symlinks from ~/.claude/{agents,hooks} to this repo.
`bash install.sh TYPE:NAME ...` で個別インストール（例: `agents:terraform-code-reviewer hooks:stop-handover-reminder.sh`）。
`gh skill install revsystem/claude-code-skills --agent claude-code --scope user` でスキルをインストール。

## Testing

- `bash tests/test_install.sh` — install.sh の回帰テスト（CLAUDE_CODE_DIR 環境変数で出力先をオーバーライド）

## Skill authoring rules

- スキルファイルはセッション開始時にキャッシュされる。編集後のテストは新セッションで行う。

## Agent authoring rules

- Agent frontmatter `mcpServers` uses mapping format (key → attributes), NOT list format.
- Skills frontmatter does NOT support `mcpServers`. MCP-dependent tools must be agents.
- Agent `description` text determines when Claude autonomously spawns it — wording matters.
- Agents placed in `~/.claude/agents/` need no settings.json changes to be spawn-eligible.

## Working files

- `.claude/docs/` and `.claude/handovers/` are untracked working directories (not committed to git).
