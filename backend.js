// backend.js
// ReadAR backend (Node.js + Express, ESM)
// Run:  node backend.js
// Deps:
//   npm i express cors node-fetch dotenv multer pdf-parse pdfkit pdf-lib

import express from "express";
import cors from "cors";
import dotenv from "dotenv";
dotenv.config();

const app = express();
app.use(cors({ origin: process.env.CORS_ORIGINS?.split(",") || "*" }));
app.use(express.json({ limit: "2mb" }));

const PORT = process.env.PORT || 5055;

app.get("/api/health", (_req, res) => res.json({ ok: true }));

app.get("/api/features", (_req, res) => {
  const items = [
    { color: "#FF6B6B", title: "Define", subtitle: "Look up terms fast" },
    { color: "#4D96FF", title: "Explain", subtitle: "Explain a passage" },
    { color: "#6BCB77", title: "PDF", subtitle: "Preview and annotate" }
  ];
  res.json({ items });
});

app.post("/api/define", (req, res) => {
  const term = String(req.body?.term || "").trim();
  if (!term) return res.status(400).json({ error: "Missing term" });
  res.json({ term, definition: `${term}: a concise, stubbed definition for demo purposes.` });
});

app.post("/api/explain", (req, res) => {
  const text = String(req.body?.text || "").trim();
  if (!text) return res.status(400).json({ error: "Missing text" });
  res.json({ explanation: `Explanation of: ${text}` });
});

app.listen(PORT, () => {
  console.log(`ReadAR backend listening on http://127.0.0.1:${PORT}`);
});
