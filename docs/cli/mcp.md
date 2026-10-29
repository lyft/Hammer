# MCP server

`hammer mcp` runs an [MCP](https://modelcontextprotocol.io) server over standard input and output, giving an AI agent every command as a tool. Commands the app adds appear as tools too, once the app is running.

With Claude Code:

```bash
claude mcp add hammer -- ~/.local/bin/hammer mcp
```

Other clients take the same command, `hammer mcp`, in their MCP settings.

From a checkout, build `hammer` first so build output doesn't mix with the MCP messages:

```bash
swift build -c release --product hammer
claude mcp add hammer -- "$(swift build -c release --show-bin-path)/hammer" mcp
```

Set `HAMMER_AGENT_PORT` and `HAMMER_AGENT_TOKEN` in the server's environment when the app uses them.

## Skills

To teach a coding agent the command line tool instead, copy [skills/hammer-cli](../../skills/hammer-cli/SKILL.md) into your project's skills, for example `.claude/skills/hammer-cli`. [skills/hammer-tests](../../skills/hammer-tests/SKILL.md) teaches it to write Hammer tests.
