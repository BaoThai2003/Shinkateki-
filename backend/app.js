// app.js — Shinkateki API server
"use strict";

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const rateLimit = require("express-rate-limit");

const authRoutes = require("./routes/auth");
const quizRoutes = require("./routes/quiz");
const statsRoutes = require("./routes/stats");
const profileRoutes = require("./routes/profile");
const lessonRoutes = require("./routes/lessons");
const structuredLessonsRoutes = require("./routes/structuredLessons");
const dictionaryRoutes = require("./routes/dictionary");
const structuredLessonsController = require("./controllers/structuredLessonsController");
const authMiddleware = require("./middleware/auth");

const app = express();
const PORT = process.env.PORT || 8000; // match frontend default API_BASE
console.log(`Starting server on port ${PORT}`);

// ── Middleware ────────────────────────────────────────────────────

app.use(
  cors({
    origin: process.env.FRONTEND_ORIGIN || "*",
    credentials: true,
  })
);

app.use(express.json({ limit: "1mb" }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting — protect auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests. Please wait." },
});

// ── Routes ────────────────────────────────────────────────────────

app.use("/api/auth", authLimiter, authRoutes);
app.use("/api/quiz", quizRoutes);
app.use("/api/stats", statsRoutes);
app.use("/api/profile", profileRoutes);
app.use("/api/lessons", lessonRoutes);
app.use("/api/structured-lessons", structuredLessonsRoutes);
app.use("/api/dictionary", dictionaryRoutes);

// Alias for legacy route and assignment requirement
app.get(
  "/api/chapters",
  authMiddleware.authenticate,
  structuredLessonsController.getChapters
);

// ── Health check ──────────────────────────────────────────────────

app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// ── 404 handler ───────────────────────────────────────────────────

app.use((_req, res) => {
  res.status(404).json({ error: "Route not found." });
});

// ── Global error handler ──────────────────────────────────────────

app.use((err, _req, res, _next) => {
  console.error("[Unhandled error]", err);
  res.status(500).json({ error: "Internal server error." });
});

// ── Start ─────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log("🔥 SERVER STARTED");
  console.log("PORT:", PORT);
});

module.exports = app;
