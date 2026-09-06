# Connect Kimchi to the gateway

Kimchi reads MCP servers from one file:

```
~/.config/kimchi/harness/mcp.json
```

The file uses the same `mcpServers` shape that Claude Code uses. In fact, Kimchi can migrate servers straight from a Claude Code install on first run.

## Add the gateway as a server

Open `~/.config/kimchi/harness/mcp.json` and add:

```json
{
  "mcpServers": {
    "team-tools": {
      "type": "http",
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

If the file already has other servers, add `team-tools` next to them. Kimchi keeps your existing entries on name conflicts.

## Try it

```bash
kimchi
```

Then ask:

> Use the list_notes tool and tell me what the team wrote.

If Goose saved a note first, Kimchi reads it here. Two agents, one shared brain, one front door.

## Why not point Kimchi at the note server directly?

You could. But then every agent on your machine holds its own copy of the server list. The gateway keeps that list in one file. Add a server once, and Goose, Kimchi, and any future agent get it at the same time.
