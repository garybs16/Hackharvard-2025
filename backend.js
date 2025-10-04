// backend.js
// ReadAR backend (Node.js + Express, ESM)
// Run:  node backend.js
// Deps: npm i express cors node-fetch dotenv

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

// ------------------------------------------------------
// Health
// ------------------------------------------------------
app.get("/api/health", (_req, res) => {
  res.json({ ok: true });
});

// ------------------------------------------------------
// Features (to mirror your UI “Key Features”)
// ------------------------------------------------------
app.get("/api/features", (_req, res) => {
  res.json({
    items: [
      { color: "#3b82f6", title: "Eye tracking",    subtitle: "Dynamic text highlight" },
      { color: "#8b5cf6", title: "Focus modes",     subtitle: "Line • Word • Syllable" },
      { color: "#22c55e", title: "Word lookup",     subtitle: "Tap to define / speak" },
      { color: "#f59e0b", title: "Narration",       subtitle: "Read-aloud sync" },
      { color: "#14b8a6", title: "Accessibility",   subtitle: "Dyslexia & ADHD" }
    ]
  });
});

// ------------------------------------------------------
// Definitions (free fallback: dictionaryapi.dev)
// ------------------------------------------------------
app.get("/api/define", async (req, res) => {
  const q = (req.query.q || "").toString().trim();
  if (!q) return res.status(400).json({ error: "missing q" });

  try {
    const r = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(q)}`);
    if (r.ok) {
      const js = await r.json();
      const def = js?.[0]?.meanings?.[0]?.definitions?.[0]?.definition || "Definition not found.";
      return res.json({ word: q, definition: def });
    }
    return res.json({ word: q, definition: "Definition not found." });
  } catch {
    // Keep a 200 so the client UX stays smooth
    return res.status(200).json({ word: q, definition: "Definition service unavailable." });
  }
});

// ------------------------------------------------------
// Explanation (OpenAI optional; falls back if no key)
// ------------------------------------------------------
app.get("/api/explain", async (req, res) => {
  const q = (req.query.q || "").toString().trim();
  if (!q) return res.status(400).json({ error: "missing q" });

  const OPENAI_KEY = process.env.OPENAI_API_KEY;
  if (!OPENAI_KEY) {
    return res.json({ word: q, definition: `Explanation: "${q}" depends on context.` });
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
  } catch {
    return res.json({ word: q, definition: "Explanation service unavailable." });
  }
});

// ------------------------------------------------------
// Syllabify (no external lib; simple heuristic)
// Input: { text: string }
// Output: { tokens: [{ raw, syllables: [] }] }
// ------------------------------------------------------
const tokenRegex = /[A-Za-z]+(?:'[A-Za-z]+)?|[0-9]+|[^\w\s]/g;

function splitTokens(text) {
  return text.match(tokenRegex) || [];
}

function syllabifyWord(word) {
  // Very simple fallback heuristic:
  // split before vowels, but keep consonant clusters with the vowel that follows
  // This is not perfect, but works offline without extra deps.
  const parts = word.match(/[^aeiouyAEIOUY]*[aeiouyAEIOUY]+(?:[^aeiouyAEIOUY]|$)/g);
  if (parts && parts.length) return parts.map(p => p.trim()).filter(Boolean);
  return [word];
}

app.post("/api/syllabify", (req, res) => {
  const text = (req.body?.text || "").toString();
  const tokens = splitTokens(text).map(tok => {
    if (/^[A-Za-z]+$/.test(tok)) {
      return { raw: tok, syllables: syllabifyWord(tok) };
    }
    return { raw: tok, syllables: [tok] };
  });
  res.json({ tokens });
});

// ------------------------------------------------------
// Readability (Flesch Reading Ease + FK Grade)
// Input: { text }
// ------------------------------------------------------
function readabilityMetrics(text) {
  const sentences = Math.max(1, (text.match(/[.!?]+/g) || []).length || 1);
  const tokens = splitTokens(text);
  const words = tokens.filter(w => /^[A-Za-z]+$/.test(w));
  const totalWords = Math.max(1, words.length);
  const totalSyllables = words.reduce((acc, w) => acc + Math.max(1, syllabifyWord(w).length), 0);

  const fre = 206.835 - 1.015 * (totalWords / sentences) - 84.6 * (totalSyllables / totalWords);
  const fkgl = 0.39 * (totalWords / sentences) + 11.8 * (totalSyllables / totalWords) - 15.59;

  return {
    flesch_kincaid_grade: Number(fkgl.toFixed(2)),
    flesch_reading_ease: Number(fre.toFixed(2)),
    total_words: totalWords,
    total_sentences: sentences,
    total_syllables: totalSyllables
  };
}

app.post("/api/readability", (req, res) => {
  const text = (req.body?.text || "").toString();
  return res.json(readabilityMetrics(text));
});

// ------------------------------------------------------
// Focus suggest (demo logic)
// Input: { lines: string[], current_index: number }
// ------------------------------------------------------
app.post("/api/focus/suggest", (req, res) => {
  const lines = Array.isArray(req.body?.lines) ? req.body.lines : [];
  const current = Number.isInteger(req.body?.current_index) ? req.body.current_index : 0;
  if (!lines.length) return res.json({ next_index: 0 });
  const next = (current + 1) % lines.length;
  res.json({ next_index: next });
});

// ------------------------------------------------------
// Narrate: returns SSML for client-side TTS
// Input: { text: string, voice_hint?: "en-US", rate?: 0.5..2.0 }
// ------------------------------------------------------
app.post("/api/narrate", (req, res) => {
  const text = (req.body?.text || "").toString();
  const voice = (req.body?.voice_hint || "en-US").toString();
  const rate = Math.min(2.0, Math.max(0.5, Number(req.body?.rate ?? 1.0)));
  const ssml = `<speak xml:lang="${voice}"><prosody rate="${Math.round(rate * 100)}%">${escapeXml(text)}</prosody></speak>`;
  res.json({ ssml });
});

function escapeXml(s) {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

// ------------------------------------------------------
// Preferences (in-memory). Replace with DB in prod.
// GET /api/preferences/:key
// PUT /api/preferences/:key  { font_size?, line_spacing?, theme? }
// ------------------------------------------------------
const PREFS = new Map(); // key -> { font_size, line_spacing, theme }

app.get("/api/preferences/:key", (req, res) => {
  const key = req.params.key;
  const value = PREFS.get(key) ?? { font_size: 18, line_spacing: 1.3, theme: "light" };
  res.json(value);
});

app.put("/api/preferences/:key", (req, res) => {
  const key = req.params.key;
  const incoming = req.body || {};
  const current = PREFS.get(key) ?? { font_size: 18, line_spacing: 1.3, theme: "light" };
  const merged = {
    font_size: clampNumber(incoming.font_size ?? current.font_size, 10, 48),
    line_spacing: clampNumber(incoming.line_spacing ?? current.line_spacing, 1.0, 2.5),
    theme: typeof incoming.theme === "string" ? incoming.theme : current.theme
  };
  PREFS.set(key, merged);
  res.json(merged);
});

function clampNumber(v, min, max) {
  const n = Number(v);
  if (Number.isNaN(n)) return min;
  return Math.min(max, Math.max(min, n));
}

// ------------------------------------------------------
// Root
// ------------------------------------------------------
app.get("/", (_req, res) => {
  res.json({
    name: "ReadAR API",
    version: "1.0.0",
    docs_hint: "Hit /api/* endpoints directly",
    endpoints: [
      "GET  /api/health",
      "GET  /api/features",
      "GET  /api/define?q=word",
      "GET  /api/explain?q=word",
      "POST /api/syllabify { text }",
      "POST /api/readability { text }",
      "POST /api/focus/suggest { lines, current_index }",
      "POST /api/narrate { text, voice_hint?, rate? }",
      "GET  /api/preferences/:key",
      "PUT  /api/preferences/:key { font_size?, line_spacing?, theme? }"
    ]
  });
});

app.listen(PORT, () => {
  console.log(`✅ ReadAR API running on http://localhost:${PORT}`);
});
