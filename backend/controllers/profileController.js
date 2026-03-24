// controllers/profileController.js
"use strict";

const { query } = require("../config/db");

// GET /api/profile/quiz-history
async function getQuizHistory(req, res) {
  try {
    const userId = req.user.id;

    // Get quiz sessions with aggregated data
    const quizHistory = await query(
      `
      SELECT
        DATE(a.created_at) as date,
        COUNT(DISTINCT a.session_id) as session_count,
        COUNT(*) as questions_count,
        ROUND(AVG(a.is_correct) * 100) as accuracy,
        SUM(CASE WHEN a.is_correct THEN
          CASE
            WHEN ps.difficulty_class = 'weak' THEN 30
            WHEN ps.difficulty_class = 'medium' THEN 20
            ELSE 10
          END
        ELSE 0 END) as score
      FROM attempts a
      LEFT JOIN performance_stats ps ON ps.user_id = a.user_id AND ps.character_id = a.character_id
      WHERE a.user_id = ?
      GROUP BY DATE(a.created_at)
      ORDER BY date DESC
      LIMIT 50
    `,
      [userId]
    );

    return res.json(quizHistory);
  } catch (err) {
    console.error("[getQuizHistory]", err);
    return res.status(500).json({ error: "Failed to fetch quiz history." });
  }
}

// GET /api/profile/grade-breakdown
async function getGradeBreakdown(req, res) {
  try {
    const userId = req.user.id;

    // Get daily quiz sessions with accuracy
    const dailyQuizzes = await query(
      `
      SELECT
        DATE(a.created_at) as date,
        ROUND(AVG(a.is_correct) * 100) as accuracy
      FROM attempts a
      WHERE a.user_id = ?
      GROUP BY DATE(a.created_at)
      ORDER BY date DESC
    `,
      [userId]
    );

    // Categorize by grade
    const gradeCounts = {};
    dailyQuizzes.forEach((quiz) => {
      const grade = getGradeLetter(quiz.accuracy);
      gradeCounts[grade] = (gradeCounts[grade] || 0) + 1;
    });

    // Convert to array format
    const breakdown = Object.entries(gradeCounts)
      .map(([grade, count]) => ({ grade, count }))
      .sort((a, b) => {
        const order = [
          "A+",
          "A",
          "A-",
          "B+",
          "B",
          "B-",
          "C+",
          "C",
          "C-",
          "D",
          "F",
        ];
        return order.indexOf(a.grade) - order.indexOf(b.grade);
      });

    return res.json(breakdown);
  } catch (err) {
    console.error("[getGradeBreakdown]", err);
    return res.status(500).json({ error: "Failed to fetch grade breakdown." });
  }
}

function getGradeLetter(accuracy) {
  if (accuracy >= 95) return "A+";
  if (accuracy >= 90) return "A";
  if (accuracy >= 85) return "A-";
  if (accuracy >= 80) return "B+";
  if (accuracy >= 75) return "B";
  if (accuracy >= 70) return "B-";
  if (accuracy >= 65) return "C+";
  if (accuracy >= 60) return "C";
  if (accuracy >= 55) return "C-";
  if (accuracy >= 50) return "D";
  return "F";
}

module.exports = { getQuizHistory, getGradeBreakdown };
