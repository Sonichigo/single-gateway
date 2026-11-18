#!/usr/bin/env bash
# Small helper: read or add a note through the MCP gateway with plain curl.
#
#   mcp-note.sh read                       print the notes
#   mcp-note.sh add <author> "<text>"      save one note
#
# Needs curl and node (any Node image has both).

set -euo pipefail

GATEWAY_URL="${GATEWAY_URL:-http://gateway-mcp.agent-ci.svc.cluster.local:3000/mcp}"
ACCEPT='Accept: application/json, text/event-stream'
HDR_FILE="$(mktemp)"

curl -s -D "$HDR_FILE" -o /dev/null -X POST "$GATEWAY_URL" \
  -H 'Content-Type: application/json' -H "$ACCEPT" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"mcp-note","version":"0.1.0"}}}'

# The gateway gives a session id. A bare note server does not, so it is optional.
SESSION="$(grep -i mcp-session-id "$HDR_FILE" | tr -d '\r' | awk '{print $2}' || true)"
rm -f "$HDR_FILE"
SESSION_HDR=()
[ -n "$SESSION" ] && SESSION_HDR=(-H "mcp-session-id: $SESSION")

curl -s -X POST "$GATEWAY_URL" "${SESSION_HDR[@]}" \
  -H 'Content-Type: application/json' -H "$ACCEPT" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null

call() {
  curl -s -X POST "$GATEWAY_URL" "${SESSION_HDR[@]}" \
    -H 'Content-Type: application/json' -H "$ACCEPT" -d "$1"
}

case "${1:-}" in
  read)
    call '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_notes","arguments":{}}}' \
      | sed -n 's/^data: //p' | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).result.content[0].text)}catch(e){console.log(s)}})'
    ;;
  add)
    AUTHOR="${2:?author}"; TEXT="${3:?text}"
    BODY="$(AUTHOR="$AUTHOR" TEXT="$TEXT" node -e 'console.log(JSON.stringify({jsonrpc:"2.0",id:3,method:"tools/call",params:{name:"add_note",arguments:{author:process.env.AUTHOR,text:process.env.TEXT}}}))')"
    call "$BODY" | sed -n 's/^data: //p' | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).result.content[0].text)}catch(e){console.log(s)}})'
    ;;
  *) echo "usage: mcp-note.sh read | add <author> <text>" >&2; exit 2 ;;
esac
