#!/usr/bin/env bash
# CI gate: read the shared notes through the gateway and decide pass or fail.
#
# It checks three things:
#   1. Goose left a note        (the review happened)
#   2. Kimchi left a note       (the handoff happened)
#   3. Goose did not say RISK: high
#
# Exit 0 means the pipeline can go on. Exit 1 stops it.

set -euo pipefail

GATEWAY_URL="${GATEWAY_URL:-http://gateway-mcp.agent-ci.svc.cluster.local:3000/mcp}"
HDR_FILE="$(mktemp)"
ACCEPT='Accept: application/json, text/event-stream'

curl -s -D "$HDR_FILE" -o /dev/null -X POST "$GATEWAY_URL" \
  -H 'Content-Type: application/json' -H "$ACCEPT" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"ci-gate","version":"0.1.0"}}}'

SESSION="$(grep -i mcp-session-id "$HDR_FILE" | tr -d '\r' | awk '{print $2}')"
if [ -z "$SESSION" ]; then
  echo "GATE FAIL: could not open a session at $GATEWAY_URL"
  exit 1
fi

curl -s -X POST "$GATEWAY_URL" -H "mcp-session-id: $SESSION" \
  -H 'Content-Type: application/json' -H "$ACCEPT" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null

NOTES="$(curl -s -X POST "$GATEWAY_URL" -H "mcp-session-id: $SESSION" \
  -H 'Content-Type: application/json' -H "$ACCEPT" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_notes","arguments":{}}}')"

echo "Notes seen through the gateway:"
echo "$NOTES" | sed 's/\\n/\n/g'
echo

if ! echo "$NOTES" | grep -q '\] goose at'; then
  echo "GATE FAIL: goose left no note"
  exit 1
fi
if ! echo "$NOTES" | grep -q '\] kimchi at'; then
  echo "GATE FAIL: kimchi left no note"
  exit 1
fi
if echo "$NOTES" | grep -qi 'RISK: *high'; then
  echo "GATE FAIL: goose marked this change as high risk"
  exit 1
fi

echo "GATE PASS: both agents reported and the risk is not high."
rm -f "$HDR_FILE"
