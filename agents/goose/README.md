# Connect Goose to the gateway

Goose talks to MCP servers through extensions. We point one extension at the gateway instead of a direct server.

## Option A: the CLI wizard

```bash
goose configure
```

1. Pick **Add Extension**
2. Pick **Remote Extension (Streaming HTTP)**
3. Name it `team-tools`
4. For the endpoint, enter `http://localhost:3000/mcp`
5. Accept the defaults for the rest

## Option B: edit the config file

Open `~/.config/goose/config.yaml` and add this under `extensions`:

```yaml
extensions:
  team-tools:
    enabled: true
    name: team-tools
    type: streamable_http
    uri: http://localhost:3000/mcp
    envs: {}
    headers: {}
    timeout: 300
```

Note: field names can shift between Goose releases. If the snippet above does not match your version, use Option A. The wizard always writes the correct shape.

## Try it

```bash
goose session
```

Then ask:

> Use the add_note tool. Author is goose. Text is: deploy plan drafted, please review.

Goose calls the tool through the gateway. The gateway forwards the call to the team-notes server. Check the gateway logs and you will see the request.

## Bonus: route Goose's LLM calls through the gateway too

Start the second gateway process with `gateway/llm.yaml` (see the root README). Then set Goose's OpenAI provider to a custom base URL:

```bash
export OPENAI_HOST=http://localhost:4000
goose configure   # pick OpenAI as provider; any placeholder key works, the gateway holds the real one
```

Now every model call from Goose also passes through one place with logs and limits.
