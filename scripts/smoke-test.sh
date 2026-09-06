#!/usr/bin/env bash
# Smoke test: prove the full chain works without any agent installed.
# It acts as two fake agents. "goose" writes a note, "kimchi" reads it.
#
# Needs: the team-notes server on :8081 and agentgateway on :3000
# Run ./scripts/start-all.sh first.

set -euo pipefail

GATEWAY_URL="${GATEWAY_URL:-http://localhost:3000/mcp}"
HDR_FILE="$(mktemp)"

jsonrpc() {
  local session="$1"
  local body="$2"
  curl -s -X POST "$GATEWAY_URL" \
    -H "mcp-session-id: $session" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d "$body"
}

echo "1. Open an MCP session through the gateway"
curl -s -D "$HDR_FILE" -o /dev/null -X POST "$GATEWAY_URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"smoke-test","version":"0.0.1"}}}'

SESSION="$(grep -i mcp-session-id "$HDR_FILE" | tr -d '\r' | awk '{print $2}')"
if [ -z "$SESSION" ]; then
  echo "FAIL: no session id. Is the gateway up on :3000?"
  exit 1
fi
echo "   session opened"

jsonrpc "$SESSION" '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null

echo "2. List tools through the gateway"
jsonrpc "$SESSION" '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | grep -o '"name":"[a-z_]*"' | sort -u

echo "3. Fake goose writes a note"
jsonrpc "$SESSION" '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add_note","arguments":{"author":"goose","text":"deploy plan drafted, please review"}}}' | grep -o 'Saved note [a-z0-9]*'

echo "4. Fake kimchi reads it back"
jsonrpc "$SESSION" '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"list_notes","arguments":{}}}' | grep -o '\[.*review'

echo
echo "PASS: one gateway, two agents, one shared tool."
rm -f "$HDR_FILE"
