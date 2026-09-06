/**
 * team-notes-mcp
 *
 * A small MCP server that stores shared notes in one JSON file.
 * It speaks Streamable HTTP, so agentgateway can sit in front of it.
 *
 * Why notes? Because it makes the demo easy to see:
 *   1. Goose writes a note through the gateway.
 *   2. Kimchi reads that same note through the gateway.
 * Two different agents, one shared tool, one front door.
 *
 * The server runs in stateless mode. Every request stands on its own.
 * That keeps the setup simple and plays well with a proxy in front.
 */

import express from "express";
import { randomUUID } from "node:crypto";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";

const PORT = Number(process.env.PORT ?? 8081);
const NOTES_FILE = process.env.NOTES_FILE ?? "notes.json";

interface Note {
  id: string;
  author: string; // which agent wrote it: "goose", "kimchi", or anything else
  text: string;
  createdAt: string;
}

function loadNotes(): Note[] {
  if (!existsSync(NOTES_FILE)) return [];
  try {
    return JSON.parse(readFileSync(NOTES_FILE, "utf-8")) as Note[];
  } catch {
    return [];
  }
}

function saveNotes(notes: Note[]): void {
  writeFileSync(NOTES_FILE, JSON.stringify(notes, null, 2));
}

function buildServer(): McpServer {
  const server = new McpServer({
    name: "team-notes",
    version: "0.1.0",
  });

  server.tool(
    "add_note",
    "Save a note that every connected agent can read later.",
    {
      author: z
        .string()
        .describe("Name of the agent or person who wrote the note"),
      text: z.string().describe("The content of the note"),
    },
    async ({ author, text }) => {
      const notes = loadNotes();
      const note: Note = {
        id: randomUUID().slice(0, 8),
        author,
        text,
        createdAt: new Date().toISOString(),
      };
      notes.push(note);
      saveNotes(notes);
      return {
        content: [
          {
            type: "text",
            text: `Saved note ${note.id} from ${author}.`,
          },
        ],
      };
    }
  );

  server.tool(
    "list_notes",
    "Read all notes that any agent saved so far.",
    {},
    async () => {
      const notes = loadNotes();
      if (notes.length === 0) {
        return {
          content: [{ type: "text", text: "No notes yet." }],
        };
      }
      const lines = notes.map(
        (n) => `[${n.id}] ${n.author} at ${n.createdAt}: ${n.text}`
      );
      return {
        content: [{ type: "text", text: lines.join("\n") }],
      };
    }
  );

  server.tool(
    "clear_notes",
    "Delete every note. Useful to reset the demo.",
    {},
    async () => {
      saveNotes([]);
      return {
        content: [{ type: "text", text: "All notes deleted." }],
      };
    }
  );

  return server;
}

const app = express();
app.use(express.json());

// Stateless Streamable HTTP: one fresh transport per request.
app.post("/mcp", async (req, res) => {
  const server = buildServer();
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined, // stateless mode
  });
  res.on("close", () => {
    transport.close();
    server.close();
  });
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

// Stateless mode does not keep sessions, so GET and DELETE return 405.
const methodNotAllowed = (_req: express.Request, res: express.Response) => {
  res.status(405).json({
    jsonrpc: "2.0",
    error: { code: -32000, message: "Method not allowed in stateless mode." },
    id: null,
  });
};
app.get("/mcp", methodNotAllowed);
app.delete("/mcp", methodNotAllowed);

app.get("/healthz", (_req, res) => {
  res.json({ ok: true, notes: loadNotes().length });
});

app.listen(PORT, () => {
  console.log(`team-notes MCP server ready on http://localhost:${PORT}/mcp`);
});
