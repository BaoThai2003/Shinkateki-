// controllers/statsController.js
"use strict";

const behaviorAnalysis = require("../services/behaviorAnalysis");
const { query } = require("../config/db");

/**
 * Analyze quiz results and return comprehensive stats
 * @param {Array} questions - Original questions
 * @param {Array} answers - User's answers
 * @returns {Object} Stats with correct/incorrect/accuracy
 */
function analyzeResult(questions, answers) {
  if (!Array.isArray(questions) || !Array.isArray(answers)) {
    return {
      totalQuestions: 0,
      correctAnswers: 0,
      incorrectAnswers: 0,
      accuracy: 0,
      details: [],
    };
  }

  let correctCount = 0;
  const details = [];

  for (let i = 0; i < questions.length; i++) {
    const q = questions[i];
    const a = answers[i];
    const isCorrect = a && a.isCorrect;

    if (isCorrect) {
      correctCount++;
    }

    details.push({
      questionIndex: i + 1,
      question: q.question || q.character || "?",
      userAnswer: a ? a.choiceRomaji : "No Answer",
      correctAnswer: q.romaji || q.correctAnswer || "?",
      isCorrect: !!isCorrect,
      responseTimeMs: a ? a.responseTimeMs : 0,
    });
  }

  const accuracy =
    questions.length > 0
      ? Math.round((correctCount / questions.length) * 100)
      : 0;

  return {
    totalQuestions: questions.length,
    correctAnswers: correctCount,
    incorrectAnswers: questions.length - correctCount,
    accuracy,
    details,
  };
}

// GET /api/stats/dashboard
async function dashboard(req, res) {
  try {
    const userId = req.user ? req.user.id : 1;
    const stats = await behaviorAnalysis.getDashboardStats(userId);
    return res.json(stats || {});
  } catch (err) {
    console.error("[dashboard]", err);
    // Return safe fallback stats
    return res.json({
      totalQuestions: 0,
      correctAnswers: 0,
      accuracy: 0,
      type: "general",
      results: [],
      weakest: [],
      weekly: [],
      timeOfDay: { best: "morning", worst: "evening" },
      performance: [],
    });
  }
}

// POST /api/stats/analyze
async function analyzeQuizResults(req, res) {
  try {
    const { questions, answers } = req.body;
    const stats = analyzeResult(questions, answers);
    return res.json(stats);
  } catch (err) {
    console.error("[analyzeQuizResults]", err);
    return res.status(400).json({ error: "Failed to analyze results." });
  }
}

// GET /api/stats/weakest?limit=10
async function weakest(req, res) {
  try {
    const limit = Math.min(parseInt(req.query.limit || "10"), 50);
    const userId = req.user ? req.user.id : 1;
    const chars = await behaviorAnalysis.getWeakestCharacters(userId, limit);
    return res.json({ characters: chars || [] });
  } catch (err) {
    console.error("[weakest]", err);
    return res.json({ characters: [] });
  }
}

// GET /api/stats/weekly?days=7
async function weekly(req, res) {
  try {
    const days = Math.min(parseInt(req.query.days || "7"), 90);
    const userId = req.user ? req.user.id : 1;
    const trend = await behaviorAnalysis.getWeeklyTrend(userId, days);
    return res.json({ trend: trend || [] });
  } catch (err) {
    console.error("[weekly]", err);
    return res.json({ trend: [] });
  }
}

// GET /api/stats/time-of-day
async function timeOfDay(req, res) {
  try {
    const userId = req.user ? req.user.id : 1;
    const insights = await behaviorAnalysis.getTimeOfDayInsights(userId);
    return res.json({ insights: insights || {} });
  } catch (err) {
    console.error("[timeOfDay]", err);
    return res.json({ insights: {} });
  }
}

// GET /api/stats/performance?type=hiragana&page=1&limit=20
async function characterPerformance(req, res) {
  try {
    const userId = req.user ? req.user.id : 1;
    const type = req.query.type || null;
    const page = Math.max(1, parseInt(req.query.page || "1"));
    const limit = Math.min(parseInt(req.query.limit || "20"), 100);
    const offset = (page - 1) * limit;

    const rows = await query(
      `SELECT c.kana, c.romaji, c.type, c.group_name,
              ps.weakness_score, ps.difficulty_class,
              ps.correct_count, ps.wrong_count,
              ps.avg_response_ms, ps.mistake_streak,
              ps.last_reviewed, ps.next_review
       FROM performance_stats ps
       JOIN characters c ON c.id = ps.character_id
       WHERE ps.user_id = ?
         ${type ? "AND c.type = ?" : ""}
       ORDER BY ps.weakness_score DESC
       LIMIT ? OFFSET ?`,
      type ? [userId, type, limit, offset] : [userId, limit, offset]
    );

    const countQuery = await query(
      `SELECT COUNT(*) AS total FROM performance_stats ps
       JOIN characters c ON c.id = ps.character_id
       WHERE ps.user_id = ? ${type ? "AND c.type = ?" : ""}`,
      type ? [userId, type] : [userId]
    );

    const total = countQuery && countQuery[0] ? countQuery[0].total : 0;

    return res.json({ characters: rows || [], total, page, limit });
  } catch (err) {
    console.error("[characterPerformance]", err);
    return res.json({ characters: [], total: 0, page: 1, limit: 20 });
  }
}

// GET /api/stats/quiz-history
async function quizHistory(req, res) {
  try {
    const userId = req.user ? req.user.id : 1;
    const limit = Math.min(parseInt(req.query.limit || "20"), 100);

    const sessions = await query(
      `SELECT qs.*, sl.title_en, sl.title_vi
       FROM quiz_sessions qs
       LEFT JOIN structured_lessons sl ON sl.id = qs.lesson_id
       WHERE qs.user_id = ?
       ORDER BY qs.created_at DESC
       LIMIT ?`,
      [userId, limit]
    );

    return res.json({
      sessions: sessions || [],
      mostCorrect: [],
      mostIncorrect: [],
      dayOfWeek: [],
      timeOfDay: [],
    });
  } catch (err) {
    console.error("[quizHistory]", err);
    return res.json({
      sessions: [],
      mostCorrect: [],
      mostIncorrect: [],
      dayOfWeek: [],
      timeOfDay: [],
    });
  }
}

module.exports = {
  dashboard,
  weakest,
  weekly,
  timeOfDay,
  characterPerformance,
  quizHistory,
  analyzeQuizResults,
  analyzeResult, // Export for testing/usage
};
