// backend.js
// Simple ReadAR backend: dictionary + explanation
// Run:  node backend.js    (after `npm i express cors node-fetch dotenv`)

import express from "express";
import cors from "cors";
import fetch from "node-fetch";
import dotenv from "dotenv";
dotenv.config();

const app = express();
const PORT = process.env.PORT || 5055;
const ORIGINS = (process.env.CORS_ORIGINS || "*").split(",");

app.use(cors({ origin: ORIGINS, credentials: false }));
app.use(express.json());

app.get("/api/health", (req, res) => {
  res.json({ ok: true });
});

// ------------ Definitions (free fallback) ---------------
app.get("/api/define", async (req, res) => {
  const q = (req.query.q || "").toString().trim();
  if (!q) return res.status(400).json({ error: "missing q" });

  try {
    // Fallback: dictionaryapi.dev (free, no key)
    const r = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(q)}`);
    if (r.ok) {
      const js = await r.json();
      const def = js?.[0]?.meanings?.[0]?.definitions?.[0]?.definition || "Definition not found.";
      return res.json({ word: q, definition: def });
    }
    return res.json({ word: q, definition: "Definition not found." });
  } catch (e) {
    return res.status(200).json({ word: q, definition: "Definition service unavailable." });
  }
});

// ------------ Explanation (OpenAI optional) -------------
app.get("/api/explain", async (req, res) => {
  const q = (req.query.q || "").toString().trim();
  if (!q) return res.status(400).json({ error: "missing q" });

  const OPENAI_KEY = process.env.OPENAI_API_KEY;
  if (!OPENAI_KEY) {
    // Simple fallback
    return res.json({ word: q, definition: `Explanation: "${q}" means something that depends on context.` });
  }

  try {
    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: "Explain like I'm 12. Keep it to 1-2 sentences." },
          { role: "user", content: q }
        ],
        temperature: 0.2
      })
    });
    const js = await r.json();
    const text = js?.choices?.[0]?.message?.content?.trim() || "No explanation.";
    return res.json({ word: q, definition: text });
  } catch (e) {
    return res.json({ word: q, definition: "Explanation service unavailable." });
  }
});

app.listen(PORT, () => console.log(`ReadAR API running on http://localhost:${PORT}`));
