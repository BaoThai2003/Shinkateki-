// controllers/quizController.js
"use strict";

const { v4: uuidv4 } = require("uuid");
const { query } = require("../config/db");
const adaptiveEngine = require("../services/adaptiveEngine");

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
// Body: { sessionId, answers: [{ characterId, choiceRomaji, responseTimeMs }] }
async function submitAnswers(req, res) {
  try {
    const userId = req.user.id;
    const { sessionId, answers } = req.body;

    if (!Array.isArray(answers) || !answers.length) {
      return res.status(400).json({ error: "answers array is required." });
    }

    // Fetch all characters once for lookup
    const charMap = {};
    const charIds = [...new Set(answers.map((a) => a.characterId))];
    const chars = await query(
      `SELECT id, romaji FROM characters WHERE id IN (${charIds
        .map(() => "?")
        .join(",")})`,
      charIds
    );
    chars.forEach((c) => {
      charMap[c.id] = c;
    });

    // Process each answer
    const results = [];
    let sessionScore = 0;

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

    // Award session score to user
    await query(`UPDATE users SET total_score = total_score + ? WHERE id = ?`, [
      sessionScore,
      userId,
    ]);

    const accuracy = Math.round(
      (results.filter((r) => r.isCorrect).length / results.length) * 100
    );

    return res.json({ sessionId, results, accuracy, sessionScore });
  } catch (err) {
    console.error("[submitAnswers]", err);
    return res.status(500).json({ error: "Failed to submit answers." });
  }
}

// Points earned per correct answer based on difficulty class
function _pointsFor(cls) {
  return { weak: 30, medium: 20, strong: 10 }[cls] ?? 10;
}

module.exports = { generateQuiz, submitAnswers };
