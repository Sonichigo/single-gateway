# One Gateway, Many Agents

Run two different AI agents, [Goose](https://github.com/block/goose) and [Kimchi](https://github.com/getkimchi/kimchi), behind one [agentgateway](https://github.com/agentgateway/agentgateway). Both agents share the same MCP tools through a single front door.

![Architecture](docs/images/architecture.png)

## The problem

Every agent you install brings its own config, its own copy of every MCP server entry, and its own API keys. Two agents and three MCP servers means six connections to manage. Nobody can answer a simple question: which agent called which tool, and when?

## The idea

Put one gateway in the middle. Agents connect to one URL. The gateway holds the server list, the keys, the logs, and the limits.

| Without a gateway | With agentgateway |
|---|---|
| Each agent has its own MCP server list | One list in `gateway/config.yaml` |
| Keys live in every agent config | Keys live in one place |
| No shared record of tool calls | One access log for every call |
| New server means N config edits | New server means one config edit |

## What is in this repo

```
one-gateway-many-agents/
├── gateway/
│   ├── config.yaml        # MCP front door on :3000
│   └── llm.yaml           # optional LLM front door on :4000
├── mcp-server/            # team-notes: a tiny MCP server (TypeScript, Streamable HTTP)
├── agents/
│   ├── goose/README.md    # connect Goose to the gateway
│   └── kimchi/README.md   # connect Kimchi to the gateway
├── scripts/
│   ├── start-all.sh       # run the note server + gateway
│   └── smoke-test.sh      # prove the chain works, no agent needed
├── docs/images/           # diagrams
└── blog/                  # the companion blog post
```

The demo tool is a shared notepad. Goose writes a note. Kimchi reads it. Both go through the gateway, so the gateway logs show both agents by name.

## Quickstart

Prereqs: Node.js 20+, curl, and the agentgateway binary.

```bash
# 1. Install agentgateway
curl https://raw.githubusercontent.com/agentgateway/agentgateway/refs/heads/main/common/scripts/get-agentgateway | bash

# 2. Start everything
./scripts/start-all.sh

# 3. In a second terminal, prove the chain works
./scripts/smoke-test.sh
```

Expected output:

```
1. Open an MCP session through the gateway
   session opened
2. List tools through the gateway
"name":"add_note"
"name":"clear_notes"
"name":"list_notes"
3. Fake goose writes a note
Saved note d76b7b14
4. Fake kimchi reads it back
[d76b7b14] goose at 2026-07-12T15:23:37.612Z: deploy plan drafted, please review

PASS: one gateway, two agents, one shared tool.
```

Then connect the real agents:

- [Goose setup](agents/goose/README.md)
- [Kimchi setup](agents/kimchi/README.md)

## How the pieces relate

![Relationships](docs/images/relationship.png)

- **Goose** and **Kimchi** are MCP clients. They only know one URL: `http://localhost:3000/mcp`.
- **agentgateway** is the proxy. It accepts MCP over Streamable HTTP, applies policies (CORS here; auth, rate limits, and more if you want), and forwards calls to targets.
- **team-notes** is an MCP target. It never faces an agent directly.

Add a new target in `gateway/config.yaml` and every agent sees the new tools on the next session. No agent config changes.

## Watch the traffic

Open the admin UI at `http://localhost:15000/ui` while agents make calls. Every tool call shows up with the route it took. That single view is the whole point.

## Versions used

Tested with agentgateway v1.4.0-alpha.1, `@modelcontextprotocol/sdk` 1.x, Node.js 22. Goose and Kimchi both move fast; if a config field name changed, their built-in wizards (`goose configure`, `kimchi setup`) write the correct shape.

## License

Apache-2.0
