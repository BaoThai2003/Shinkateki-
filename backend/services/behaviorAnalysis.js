// services/behaviorAnalysis.js
//
// ════════════════════════════════════════════════════════════════
//  SHINKATEKI — BEHAVIOURAL ANALYSIS SERVICE
//
//  Analyses patterns in a user's learning history to surface:
//  1. Best / worst time of day to study
//  2. Weekly accuracy trends
//  3. Weakest characters
//  4. Learning velocity (improvement rate over time)
//  5. Personalised textual recommendations
// ════════════════════════════════════════════════════════════════
"use strict";

const { query, queryOne } = require("../config/db");

// ── Time-of-Day Analysis ─────────────────────────────────────────

/**
 * Return the hour slots sorted by accuracy_rate descending.
 * Also labels morning / afternoon / evening / night.
 */
async function getTimeOfDayInsights(userId) {
  const rows = await query(
    `SELECT hour_slot, total_attempts, correct_count,
            avg_response_ms, accuracy_rate
     FROM time_of_day_stats
     WHERE user_id = ? AND total_attempts >= 3
     ORDER BY accuracy_rate DESC`,
    [userId]
  );

  return rows.map((r) => ({
    hour: r.hour_slot,
    label: _timeLabel(r.hour_slot),
    totalAttempts: r.total_attempts,
    accuracy: parseFloat((r.accuracy_rate * 100).toFixed(1)),
    avgResponseMs: r.avg_response_ms,
  }));
}

function _timeLabel(hour) {
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 21) return "evening";
  return "night";
}

/**
 * Return the single best time-of-day slot with enough data.
 * Used for the "Optimal study time" recommendation.
 */
async function getOptimalStudyTime(userId) {
  const insights = await getTimeOfDayInsights(userId);
  if (!insights.length) return null;
  const best = insights[0]; // already sorted by accuracy
  return { hour: best.hour, label: best.label, accuracy: best.accuracy };
}

// ── Weekly Accuracy Trend ────────────────────────────────────────

/**
 * Return daily accuracy + attempt count for the last N days.
 */
async function getWeeklyTrend(userId, days = 7) {
  const rows = await query(
    `SELECT
       DATE(created_at)        AS day,
       COUNT(*)                AS total,
       SUM(is_correct)         AS correct,
       AVG(response_time)      AS avg_ms
     FROM attempts
     WHERE user_id = ?
       AND created_at >= NOW() - INTERVAL ? DAY
     GROUP BY DATE(created_at)
     ORDER BY day ASC`,
    [userId, days]
  );

  return rows.map((r) => ({
    date: r.day,
    total: r.total,
    correct: r.correct,
    accuracy:
      r.total > 0 ? parseFloat(((r.correct / r.total) * 100).toFixed(1)) : 0,
    avgMs: Math.round(r.avg_ms),
  }));
}

// ── Weakest Characters ───────────────────────────────────────────

/**
 * Return the N characters with the highest weakness_score.
 */
async function getWeakestCharacters(userId, limit = 10) {
  return query(
    `SELECT c.kana AS kana_char, c.romaji, c.type, c.group_name,
            ps.weakness_score, ps.difficulty_class,
            ps.correct_count, ps.wrong_count,
            ps.avg_response_ms, ps.mistake_streak
     FROM performance_stats ps
     JOIN characters c ON c.id = ps.character_id
     WHERE ps.user_id = ?
     ORDER BY ps.weakness_score DESC
     LIMIT ${limit}`,
    [userId]
  );
}
// ── Learning Velocity ─────────────────────────────────────────────

/**
 * Compare the average accuracy of the first half vs the second half
 * of all attempts to measure improvement.
 */
async function getLearningVelocity(userId) {
  const countRow = await queryOne(
    `SELECT COUNT(*) AS total FROM attempts WHERE user_id = ?`,
    [userId]
  );
  const total = countRow?.total ?? 0;
  if (total < 10) return { status: "insufficient_data", improvementPct: null };

  const half = Math.floor(total / 2);

  const firstHalf = await queryOne(
    `SELECT AVG(is_correct) AS acc FROM (
       SELECT is_correct FROM attempts WHERE user_id = ? ORDER BY created_at ASC LIMIT ?
     ) t`,
    [userId, half]
  );
  const secondHalf = await queryOne(
    `SELECT AVG(is_correct) AS acc FROM (
       SELECT is_correct FROM attempts WHERE user_id = ? ORDER BY created_at DESC LIMIT ?
     ) t`,
    [userId, half]
  );

  const first = parseFloat(firstHalf?.acc ?? 0) * 100;
  const second = parseFloat(secondHalf?.acc ?? 0) * 100;
  const delta = second - first;

  return {
    firstHalfAccuracy: parseFloat(first.toFixed(1)),
    secondHalfAccuracy: parseFloat(second.toFixed(1)),
    improvementPct: parseFloat(delta.toFixed(1)),
    trend: delta > 2 ? "improving" : delta < -2 ? "declining" : "stable",
  };
}

// ── Overall Dashboard Stats ──────────────────────────────────────

async function getDashboardStats(userId) {
  const [overall, velocity, weakest, timeInsights, optimal, weekly, quizHistory] =
    await Promise.all([
      _getOverallStats(userId),
      getLearningVelocity(userId),
      getWeakestCharacters(userId, 5),
      getTimeOfDayInsights(userId),
      getOptimalStudyTime(userId),
      getWeeklyTrend(userId, 7),
      getQuizHistoryStats(userId),
    ]);

  const longTerm = await getLongTermStats(userId);
  const recommendations = _buildRecommendations({
    overall,
    velocity,
    optimal,
    weakest,
  });

  return {
    overall,
    velocity,
    weakest,
    timeInsights,
    optimalStudyTime: optimal,
    weeklyTrend: weekly,
    longTerm: { ...longTerm, ...quizHistory },
    recommendations,
  };
}

async function getLongTermStats(userId) {
  const overallRow = await queryOne(
    `SELECT COUNT(*) AS total_attempts, SUM(is_correct) AS total_correct
     FROM attempts
     WHERE user_id = ?`,
    [userId]
  );

  const totalAttempts = overallRow?.total_attempts ?? 0;
  const totalCorrect = overallRow?.total_correct ?? 0;

  const wrongAttempt = totalAttempts - totalCorrect;

  const topHit = await query(
    `SELECT c.kana, c.romaji, COUNT(*) AS attempts,
            SUM(a.is_correct) AS correct,
            100 * SUM(a.is_correct)/COUNT(*) AS accuracy
     FROM attempts a
     JOIN characters c ON c.id = a.character_id
     WHERE a.user_id = ?
     GROUP BY a.character_id
     HAVING attempts >= 3
     ORDER BY accuracy DESC, attempts DESC
     LIMIT 5`,
    [userId]
  );

  const topMiss = await query(
    `SELECT c.kana, c.romaji, COUNT(*) AS attempts,
            SUM(a.is_correct) AS correct,
            100 * SUM(a.is_correct)/COUNT(*) AS accuracy
     FROM attempts a
     JOIN characters c ON c.id = a.character_id
     WHERE a.user_id = ?
     GROUP BY a.character_id
     HAVING attempts >= 3
     ORDER BY accuracy ASC, attempts DESC
     LIMIT 5`,
    [userId]
  );

  const habitTime = await query(
    `SELECT HOUR(created_at) hour, COUNT(*) total
     FROM attempts
     WHERE user_id = ?
     GROUP BY HOUR(created_at)
     ORDER BY total DESC
     LIMIT 8`,
    [userId]
  );

  const habitWeek = await query(
    `SELECT DAYOFWEEK(created_at) day_of_week, COUNT(*) total
     FROM attempts
     WHERE user_id = ?
     GROUP BY DAYOFWEEK(created_at)
     ORDER BY total DESC
     LIMIT 7`,
    [userId]
  );

  return {
    totalAttempts,
    totalCorrect,
    totalWrong: wrongAttempt,
    accuracy:
      totalAttempts > 0
        ? parseFloat(((totalCorrect / totalAttempts) * 100).toFixed(1))
        : 0,
    topCorrect: topHit.map((r) => ({
      kana: r.kana,
      romaji: r.romaji,
      attempts: r.attempts,
      accuracy: Number(r.accuracy.toFixed(1)),
    })),
    topIncorrect: topMiss.map((r) => ({
      kana: r.kana,
      romaji: r.romaji,
      attempts: r.attempts,
      accuracy: Number(r.accuracy.toFixed(1)),
    })),
    habitTimeOfDay: habitTime.map((r) => ({
      hour: r.hour,
      label: _timeLabel(r.hour),
      count: r.total,
    })),
    habitWeekDay: habitWeek.map((r) => ({
      day: _dayName(r.day_of_week),
      count: r.total,
    })),
  };
}

async function getQuizHistoryStats(userId) {
  // Quiz sessions
  const sessions = await query(
    `SELECT session_type, COUNT(*) as count, AVG(accuracy) as avg_accuracy
     FROM quiz_sessions
     WHERE user_id = ?
     GROUP BY session_type`,
    [userId]
  );

  // Most correct/incorrect questions
  const questionStats = await query(
    `SELECT qq.question_text_en, qq.question_text_vi,
            COUNT(*) as total_attempts,
            SUM(uqa.is_correct) as correct_count,
            (SUM(uqa.is_correct) / COUNT(*)) * 100 as accuracy
     FROM user_quiz_attempts uqa
     JOIN quiz_questions qq ON qq.id = uqa.question_id
     WHERE uqa.user_id = ?
     GROUP BY qq.id
     ORDER BY accuracy DESC`,
    [userId]
  );

  const mostCorrectQuestions = questionStats.slice(0, 5);
  const mostIncorrectQuestions = questionStats.slice(-5).reverse();

  // User behavior for quizzes
  const dayOfWeekStats = await query(
    `SELECT DAYOFWEEK(completed_at) as day, COUNT(*) as count
     FROM quiz_sessions
     WHERE user_id = ?
     GROUP BY DAYOFWEEK(completed_at)
     ORDER BY day`,
    [userId]
  );

  const timeOfDayStats = await query(
    `SELECT HOUR(completed_at) as hour, COUNT(*) as count
     FROM quiz_sessions
     WHERE user_id = ?
     GROUP BY HOUR(completed_at)
     ORDER BY hour`,
    [userId]
  );

  return {
    quizSessions: sessions,
    mostCorrectQuestions,
    mostIncorrectQuestions,
    quizDayOfWeek: dayOfWeekStats,
    quizTimeOfDay: timeOfDayStats,
  };
}

function _dayName(dow) {
  const days = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];
  return days[(dow - 1 + 7) % 7];
}

async function _getOverallStats(userId) {
  const row = await queryOne(
    `SELECT
       COUNT(*)           AS total_attempts,
       SUM(is_correct)    AS total_correct,
       AVG(response_time) AS avg_response_ms,
       MAX(created_at)    AS last_attempt
     FROM attempts
     WHERE user_id = ?`,
    [userId]
  );

  const total = row?.total_attempts ?? 0;
  const correct = row?.total_correct ?? 0;

  const masteredRow = await queryOne(
    `SELECT COUNT(*) AS count FROM performance_stats
     WHERE user_id = ? AND difficulty_class = 'strong'`,
    [userId]
  );

  return {
    totalAttempts: total,
    totalCorrect: correct,
    overallAccuracy:
      total > 0 ? parseFloat(((correct / total) * 100).toFixed(1)) : 0,
    avgResponseMs: Math.round(row?.avg_response_ms ?? 0),
    masteredCount: masteredRow?.count ?? 0,
    lastAttempt: row?.last_attempt ?? null,
  };
}

// ── Recommendation Engine ─────────────────────────────────────────

function _buildRecommendations({ overall, velocity, optimal, weakest }) {
  const recs = [];

  // Accuracy-based advice
  if (overall.overallAccuracy < 50) {
    recs.push({
      type: "warning",
      text: "Your overall accuracy is below 50%. Focus on your weakest characters before advancing.",
    });
  } else if (overall.overallAccuracy >= 80) {
    recs.push({
      type: "success",
      text: "Excellent work! You're above 80% accuracy — consider enabling katakana practice.",
    });
  }

  // Velocity-based advice
  if (velocity.trend === "improving") {
    recs.push({
      type: "success",
      text: `You've improved by ${velocity.improvementPct}% compared to your early sessions. Keep it up!`,
    });
  } else if (velocity.trend === "declining") {
    recs.push({
      type: "warning",
      text: "Your recent accuracy is dropping. Try shorter, more focused sessions.",
    });
  }

  // Time-of-day advice
  if (optimal) {
    recs.push({
      type: "info",
      text: `You perform best during the ${optimal.label} (${optimal.accuracy}% accuracy). Try to study then.`,
    });
  }

  // Weak characters spotlight
  if (weakest.length > 0) {
    const chars = weakest
      .slice(0, 3)
      .map((c) => `${c.character} (${c.romaji})`)
      .join(", ");
    recs.push({
      type: "info",
      text: `Focus on your hardest characters: ${chars}.`,
    });
  }

  return recs;
}

module.exports = {
  getTimeOfDayInsights,
  getOptimalStudyTime,
  getWeeklyTrend,
  getWeakestCharacters,
  getLearningVelocity,
  getDashboardStats,
};
