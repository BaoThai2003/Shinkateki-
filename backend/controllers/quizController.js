// controllers/quizController.js  (FIXED)
"use strict";

const { v4: uuidv4 } = require("uuid");
const { query } = require("../config/db");
const adaptiveEngine = require("../services/adaptiveEngine");

// ── GET /api/quiz ────────────────────────────────────────────────
async function getQuizQuestions(req, res) {
  try {
    console.log("[getQuizQuestions] HIT");
    const sql = `
      SELECT id,
             question_vi  AS question,
             options_vi   AS options,
             correct_answer_vi AS correct_answer,
             explanation_vi    AS explanation,
             difficulty_level,
             points
      FROM quiz_questions
      ORDER BY order_index
      LIMIT 10
    `;
    const questions = await query(sql);
    if (!questions || !Array.isArray(questions)) return res.json([]);

    const parsed = questions.map((q) => ({
      ...q,
      options:
        typeof q.options === "string" ? JSON.parse(q.options) : q.options || [],
    }));

    console.log(`[getQuizQuestions] returning ${parsed.length} questions`);
    return res.json(parsed);
  } catch (err) {
    console.error("[getQuizQuestions] ERROR:", err);
    return res.json([]);
  }
}

// ── GET /api/quiz/generate?size=10&type=hiragana|katakana|kanji|all ──
async function generateQuiz(req, res) {
  try {
    console.log("[generateQuiz] HIT", req.query);

    const userId = req.user.id;
    const size = Math.min(parseInt(req.query.size || "10"), 100);
    const type = req.query.type || "all";

    console.log(`[generateQuiz] userId=${userId} size=${size} type=${type}`);

    const questions = await adaptiveEngine.generateQuiz(userId, { size, type });

    if (!questions || !Array.isArray(questions)) {
      return res.json({ sessionId: uuidv4(), questions: [], total: 0 });
    }

    const sessionId = uuidv4();
    console.log(`[generateQuiz] generated ${questions.length} questions`);
    return res.json({ sessionId, questions, total: questions.length });
  } catch (err) {
    console.error("[generateQuiz] ERROR:", err);
    return res.json({ sessionId: uuidv4(), questions: [], total: 0 });
  }
}

// ── GET /api/quiz/vocabulary?size=10&level=N5 ────────────────────
async function generateVocabularyQuiz(req, res) {
  try {
    console.log("[generateVocabularyQuiz] HIT", req.query);

    const userId = req.user.id;
    const size = Math.min(parseInt(req.query.size || "10"), 100);
    const level = req.query.level || "N5";

    const questions = await adaptiveEngine.generateVocabularyQuiz(userId, {
      size,
      jlptLevel: level,
    });

    console.log(`[generateVocabularyQuiz] ${questions.length} questions`);
    return res.json({
      sessionId: uuidv4(),
      questions: questions || [],
      total: (questions || []).length,
    });
  } catch (err) {
    console.error("[generateVocabularyQuiz] ERROR:", err);
    return res.json({ sessionId: uuidv4(), questions: [], total: 0 });
  }
}

// ── POST /api/quiz/submit ─────────────────────────────────────────
async function submitAnswers(req, res) {
  try {
    const userId = req.user.id;
    const { sessionId, answers } = req.body;

    console.log(`[submitAnswers] userId=${userId} answers=${answers?.length}`);

    if (!Array.isArray(answers) || !answers.length) {
      return res.status(400).json({ error: "answers array is required." });
    }

    // Fetch all characters for lookup
    const chars = await query(
      "SELECT id, kana, romaji, reading_kana, type FROM characters"
    );
    const charMap = {};
    chars.forEach((c) => (charMap[c.id] = c));

    let sessionScore = 0;
    const results = [];

    for (const answer of answers) {
      const char = charMap[answer.characterId];
      if (!char) {
        console.warn(
          `[submitAnswers] characterId ${answer.characterId} not found`
        );
        continue;
      }

      // ── CRITICAL FIX: Use same display rule as frontend ──
      // kanji    → compare against reading_kana
      // hiragana/katakana → compare against romaji
      let correctValue;
      if (char.type === "kanji") {
        correctValue = (char.reading_kana || char.kana || "").trim();
      } else {
        correctValue = (char.romaji || "").trim();
      }

      const userChoice = (answer.choiceRomaji || "").trim();
      const isCorrect = correctValue.toLowerCase() === userChoice.toLowerCase();

      const responseMs = Math.max(100, parseInt(answer.responseTimeMs || 3000));

      const update = await adaptiveEngine.recordAttempt({
        userId,
        characterId: answer.characterId,
        isCorrect,
        responseTimeMs: responseMs,
        sessionId: sessionId || uuidv4(),
      });

      if (isCorrect) sessionScore += _pointsFor(update.difficultyClass);

      results.push({
        characterId: answer.characterId,
        isCorrect,
        // Return the correct display value (kana for kanji, romaji for kana)
        correctRomaji: correctValue,
        weaknessScore: update.weaknessScore,
        difficultyClass: update.difficultyClass,
        nextReview: update.nextReview,
      });
    }

    const accuracy = results.length
      ? Math.round(
          (results.filter((r) => r.isCorrect).length / results.length) * 100
        )
      : 0;

    const totalCorrect = results.filter((r) => r.isCorrect).length;

    // Save to test_results
    await query(
      `INSERT INTO test_results (user_id, test_type, score, total_questions)
       VALUES (?, 'quick_test', ?, ?)`,
      [userId, totalCorrect, results.length]
    );

    console.log(`[submitAnswers] accuracy=${accuracy}% score=${sessionScore}`);
    return res.json({ sessionId, results, accuracy, sessionScore });
  } catch (err) {
    console.error("[submitAnswers] ERROR:", err);
    return res.status(500).json({ error: "Failed to submit answers." });
  }
}

// ── GET /api/quiz/statistics ──────────────────────────────────────
async function getStatistics(req, res) {
  try {
    const userId = req.user.id;
    console.log(`[getStatistics] userId=${userId}`);

    const results = await query(
      `SELECT test_type, score, total_questions, timestamp
       FROM test_results
       WHERE user_id = ?
       ORDER BY timestamp DESC`,
      [userId]
    );

    const totalTests = results.length;
    const totalScore = results.reduce((s, r) => s + r.score, 0);
    const totalQuestions = results.reduce((s, r) => s + r.total_questions, 0);
    const accuracy =
      totalQuestions > 0
        ? parseFloat(((totalScore / totalQuestions) * 100).toFixed(2))
        : 0;

    return res.json({
      totalTests,
      averageScore: accuracy,
      accuracy,
      history: results,
    });
  } catch (err) {
    console.error("[getStatistics] ERROR:", err);
    return res.json({
      totalTests: 0,
      averageScore: 0,
      accuracy: 0,
      history: [],
    });
  }
}

// ── Helpers ───────────────────────────────────────────────────────

function _pointsFor(cls) {
  return { weak: 30, medium: 20, strong: 10 }[cls] ?? 10;
}

module.exports = {
  getQuizQuestions,
  generateQuiz,
  generateVocabularyQuiz,
  submitAnswers,
  getStatistics,
};
