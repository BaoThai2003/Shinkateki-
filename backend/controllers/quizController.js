// controllers/quizController.js
"use strict";

const { v4: uuidv4 } = require("uuid");
const { query } = require("../config/db");
const adaptiveEngine = require("../services/adaptiveEngine");

// GET /api/quiz - Return quiz questions from database
async function getQuizQuestions(req, res) {
  try {
    console.log("🔥 getQuizQuestions HIT");

    const sql = `
      SELECT
        id,
        question_vi as question,
        options_vi as options,
        correct_answer_vi as correct_answer,
        explanation_vi as explanation,
        difficulty_level,
        points
      FROM quiz_questions
      ORDER BY order_index
      LIMIT 10
    `;

    const questions = await query(sql);

    // Always return an array, never null
    if (!questions || !Array.isArray(questions)) {
      return res.json([]);
    }

    // Parse JSON options if needed
    const parsedQuestions = questions.map((q) => ({
      ...q,
      options:
        typeof q.options === "string" ? JSON.parse(q.options) : q.options || [],
    }));

    console.log("✅ questions:", parsedQuestions.length);

    return res.json(parsedQuestions);
  } catch (err) {
    console.error("💥 getQuizQuestions ERROR:", err);
    return res.json([]); // Return empty array on error
  }
}

// GET /api/quiz/generate?size=10&type=hiragana|katakana|kanji|all
async function generateQuiz(req, res) {
  try {
    console.log("🔥 generateQuiz HIT");

    const userId = req.user.id;
    const size = Math.min(parseInt(req.query.size || "10"), 100);
    const type = req.query.type || "all"; // default to "all" which includes Hiragana, Katakana, Kanji

    console.log({ userId, size, type });

    const questions = await adaptiveEngine.generateQuiz(userId, { size, type });

    console.log("✅ questions:", questions.length);

    // Always return an array, never null
    if (!questions || !Array.isArray(questions)) {
      return res.json({ sessionId: uuidv4(), questions: [], total: 0 });
    }

    const sessionId = uuidv4();

    return res.json({
      sessionId,
      questions: questions,
      total: questions.length,
    });
  } catch (err) {
    console.error("💥 generateQuiz ERROR:", err);
    return res.json({ sessionId: uuidv4(), questions: [], total: 0 }); // Return safe defaults
  }
}

// GET /api/quiz/vocabulary?size=10&level=N5
async function generateVocabularyQuiz(req, res) {
  try {
    console.log("🔥 generateVocabularyQuiz HIT");

    const userId = req.user.id;
    const size = Math.min(parseInt(req.query.size || "10"), 100);
    const level = req.query.level || "N5";

    const questions = await adaptiveEngine.generateVocabularyQuiz(userId, {
      size,
      jlptLevel: level,
    });

    console.log("✅ vocabulary questions:", questions.length);

    const sessionId = uuidv4();

    return res.json({
      sessionId,
      questions: questions || [],
      total: (questions || []).length,
    });
  } catch (err) {
    console.error("💥 generateVocabularyQuiz ERROR:", err);
    return res.json({ sessionId: uuidv4(), questions: [], total: 0 }); // Fallback
  }
}

// POST /api/quiz/submit
async function submitAnswers(req, res) {
  try {
    const userId = req.user.id;
    const { sessionId, answers } = req.body;

    if (!Array.isArray(answers) || !answers.length) {
      return res.status(400).json({ error: "answers array is required." });
    }

    // Fetch all characters once for lookup
    const charMap = {};
    const chars = await query(
      "SELECT id, romaji, reading_kana, type FROM characters"
    );
    chars.forEach((c) => (charMap[c.id] = c));

    let sessionScore = 0;

    const results = [];
    for (const answer of answers) {
      const char = charMap[answer.characterId];
      if (!char) continue;

      const correctValue =
        char.type === "kanji" ? char.reading_kana : char.romaji;
      const isCorrect =
        correctValue &&
        correctValue.toLowerCase() ===
          (answer.choiceRomaji || "").toLowerCase();
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
        correctRomaji: char.romaji,
        weaknessScore: update.weaknessScore,
        difficultyClass: update.difficultyClass,
        nextReview: update.nextReview,
      });
    }

    const accuracy = Math.round(
      (results.filter((r) => r.isCorrect).length / results.length) * 100
    );

    const totalCorrect = results.filter((r) => r.isCorrect).length;
    await query(
      "INSERT INTO test_results (user_id, test_type, score, total_questions) VALUES (?, 'quick_test', ?, ?)",
      [userId, totalCorrect, results.length]
    );

    return res.json({ sessionId, results, accuracy, sessionScore });
  } catch (err) {
    console.error("[submitAnswers]", err);
    return res.status(500).json({ error: "Failed to submit answers." });
  }
}

// GET /api/quiz/statistics
async function getStatistics(req, res) {
  try {
    const userId = req.user.id;
    const results = await query(
      "SELECT test_type, score, total_questions, timestamp FROM test_results WHERE user_id = ? ORDER BY timestamp DESC",
      [userId]
    );

    const totalTests = results.length;
    const totalScore = results.reduce((sum, r) => sum + r.score, 0);
    const totalQuestions = results.reduce(
      (sum, r) => sum + r.total_questions,
      0
    );
    const accuracy =
      totalQuestions > 0 ? ((totalScore / totalQuestions) * 100).toFixed(2) : 0;

    return res.json({
      totalTests,
      averageScore: parseFloat(accuracy),
      accuracy: parseFloat(accuracy),
      history: results,
    });
  } catch (err) {
    console.error("getStatistics error:", err);
    return res.json({
      totalTests: 0,
      averageScore: 0,
      accuracy: 0,
      history: [],
    });
  }
}

module.exports = {
  getQuizQuestions,
  generateQuiz,
  generateVocabularyQuiz,
  submitAnswers,
  getStatistics,
};

// Points earned per correct answer based on difficulty class
function _pointsFor(cls) {
  return { weak: 30, medium: 20, strong: 10 }[cls] ?? 10;
}
