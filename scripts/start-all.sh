#!/usr/bin/env bash
# Start the team-notes MCP server and agentgateway.
# Ctrl+C stops both.

set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v agentgateway > /dev/null; then
  echo "agentgateway not found. Install it first:"
  echo "  curl https://raw.githubusercontent.com/agentgateway/agentgateway/refs/heads/main/common/scripts/get-agentgateway | bash"
  exit 1
fi

if [ ! -d mcp-server/node_modules ]; then
  echo "First run: install and build the MCP server"
  (cd mcp-server && npm install && npm run build)
fi

echo "Start team-notes MCP server on :8081"
(cd mcp-server && node dist/index.js) &
NOTES_PID=$!

sleep 1

echo "Start agentgateway on :3000 (admin UI on :15000)"
agentgateway -f gateway/config.yaml &
GW_PID=$!

trap 'kill $NOTES_PID $GW_PID 2>/dev/null' EXIT
wait
