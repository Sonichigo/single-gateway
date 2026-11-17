# Builds the team-notes MCP server.
# Lives at the repo root so a default CI build step finds it with no extra settings.

FROM node:22-alpine
WORKDIR /app

COPY mcp-server/package*.json ./
RUN npm install

COPY mcp-server/tsconfig.json ./
COPY mcp-server/src ./src
RUN npm run build && npm prune --omit=dev

RUN mkdir /data
ENV PORT=8081
ENV NOTES_FILE=/data/notes.json
EXPOSE 8081

CMD ["node", "dist/index.js"]
