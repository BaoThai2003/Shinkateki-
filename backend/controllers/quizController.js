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

    // Parse JSON options if needed
    const parsedQuestions = questions.map(q => ({
      ...q,
      options: typeof q.options === 'string' ? JSON.parse(q.options) : q.options
    }));

    console.log("✅ questions:", parsedQuestions.length);

    return res.json(parsedQuestions);
  } catch (err) {
    console.error("💥 getQuizQuestions ERROR:", err);
    return res.status(500).json({ error: "Failed to load quiz questions." });
  }
}

// GET /api/quiz/generate?size=10&type=hiragana
async function generateQuiz(req, res) {
  try {
    console.log("🔥 generateQuiz HIT");

    const userId = req.user.id;
    const size = Math.min(parseInt(req.query.size || "10"), 100);
    const type = req.query.type || null;

    console.log({ userId, size, type });

    const questions = await adaptiveEngine.generateQuiz(userId, { size, type });

    console.log("✅ questions:", questions);

    const sessionId = uuidv4();

    return res.json({ sessionId, questions, total: questions.length });
  } catch (err) {
    console.error("💥 generateQuiz ERROR:", err);
    return res.status(500).json({ error: "Failed to generate quiz." });
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
    const chars = await query("SELECT id, romaji FROM characters");
    chars.forEach((c) => (charMap[c.id] = c));

    let sessionScore = 0;

    const results = [];
    for (const answer of answers) {
      const char = charMap[answer.characterId];
      if (!char) continue;

      const isCorrect =
        char.romaji.toLowerCase() === (answer.choiceRomaji || "").toLowerCase();
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

    return res.json({ sessionId, results, accuracy, sessionScore });
  } catch (err) {
    console.error("[submitAnswers]", err);
    return res.status(500).json({ error: "Failed to submit answers." });
  }
}

module.exports = {
  getQuizQuestions,
  generateQuiz,
  submitAnswers,
};

// Points earned per correct answer based on difficulty class
function _pointsFor(cls) {
  return { weak: 30, medium: 20, strong: 10 }[cls] ?? 10;
}
