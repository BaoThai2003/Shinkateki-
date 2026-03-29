// controllers/statsController.js
'use strict';

const behaviorAnalysis = require('../services/behaviorAnalysis');
const { query }        = require('../config/db');

// GET /api/stats/dashboard
async function dashboard(req, res) {
  try {
    const stats = await behaviorAnalysis.getDashboardStats(req.user.id);
    return res.json(stats);
  } catch (err) {
    console.error('[dashboard]', err);
    return res.status(500).json({ error: 'Failed to load dashboard stats.' });
  }
}

// GET /api/stats/weakest?limit=10
async function weakest(req, res) {
  try {
    const limit = Math.min(parseInt(req.query.limit || '10'), 50);
    const chars = await behaviorAnalysis.getWeakestCharacters(req.user.id, limit);
    return res.json({ characters: chars });
  } catch (err) {
    console.error('[weakest]', err);
    return res.status(500).json({ error: 'Failed to fetch weakest characters.' });
  }
}

// GET /api/stats/weekly?days=7
async function weekly(req, res) {
  try {
    const days  = Math.min(parseInt(req.query.days || '7'), 90);
    const trend = await behaviorAnalysis.getWeeklyTrend(req.user.id, days);
    return res.json({ trend });
  } catch (err) {
    console.error('[weekly]', err);
    return res.status(500).json({ error: 'Failed to fetch weekly trend.' });
  }
}

// GET /api/stats/time-of-day
async function timeOfDay(req, res) {
  try {
    const [insights, optimal] = await Promise.all([
      behaviorAnalysis.getTimeOfDayInsights(req.user.id),
      behaviorAnalysis.getOptimalStudyTime(req.user.id),
    ]);
    return res.json({ insights, optimalStudyTime: optimal });
  } catch (err) {
    console.error('[timeOfDay]', err);
    return res.status(500).json({ error: 'Failed to fetch time-of-day stats.' });
  }
}

// GET /api/stats/performance?type=hiragana&page=1&limit=20
async function characterPerformance(req, res) {
  try {
    const userId = req.user.id;
    const type   = req.query.type || null;
    const page   = Math.max(1, parseInt(req.query.page  || '1'));
    const limit  = Math.min(   parseInt(req.query.limit || '20'), 100);
    const offset = (page - 1) * limit;

    const rows = await query(
      `SELECT c.character, c.romaji, c.type, c.group_name,
              ps.weakness_score, ps.difficulty_class,
              ps.correct_count, ps.wrong_count,
              ps.avg_response_ms, ps.mistake_streak,
              ps.last_reviewed, ps.next_review
       FROM performance_stats ps
       JOIN characters c ON c.id = ps.character_id
       WHERE ps.user_id = ?
         ${type ? 'AND c.type = ?' : ''}
       ORDER BY ps.weakness_score DESC
       LIMIT ? OFFSET ?`,
      type ? [userId, type, limit, offset] : [userId, limit, offset]
    );

    const [[{ total }]] = await query(
      `SELECT COUNT(*) AS total FROM performance_stats ps
       JOIN characters c ON c.id = ps.character_id
       WHERE ps.user_id = ? ${type ? 'AND c.type = ?' : ''}`,
      type ? [userId, type] : [userId]
    ).then(r => [r]);

    return res.json({ characters: rows, total, page, limit });
  } catch (err) {
    console.error('[characterPerformance]', err);
    return res.status(500).json({ error: 'Failed to fetch character performance.' });
  }
}

// GET /api/stats/quiz-history
async function quizHistory(req, res) {
  try {
    const limit = Math.min(parseInt(req.query.limit || '20'), 100);
    const sessions = await query(
      `SELECT qs.*, sl.title_en, sl.title_vi
       FROM quiz_sessions qs
       LEFT JOIN structured_lessons sl ON sl.id = qs.lesson_id
       WHERE qs.user_id = ?
       ORDER BY qs.completed_at DESC
       LIMIT ?`,
      [req.user.id, limit]
    );

    // Get most correct/incorrect questions
    const questionStats = await query(
      `SELECT qq.id, qq.question_text_en, qq.question_text_vi,
              COUNT(*) as total_attempts,
              SUM(uqa.is_correct) as correct_count,
              (SUM(uqa.is_correct) / COUNT(*)) * 100 as accuracy
       FROM user_quiz_attempts uqa
       JOIN quiz_questions qq ON qq.id = uqa.question_id
       WHERE uqa.user_id = ?
       GROUP BY qq.id
       ORDER BY accuracy DESC`,
      [req.user.id]
    );

    const mostCorrect = questionStats.slice(0, 5);
    const mostIncorrect = questionStats.slice(-5).reverse();

    // User behavior
    const dayOfWeekStats = await query(
      `SELECT DAYOFWEEK(completed_at) as day, COUNT(*) as count
       FROM quiz_sessions
       WHERE user_id = ?
       GROUP BY DAYOFWEEK(completed_at)
       ORDER BY day`,
      [req.user.id]
    );

    const timeOfDayStats = await query(
      `SELECT HOUR(completed_at) as hour, COUNT(*) as count
       FROM quiz_sessions
       WHERE user_id = ?
       GROUP BY HOUR(completed_at)
       ORDER BY hour`,
      [req.user.id]
    );

    return res.json({
      sessions,
      mostCorrect,
      mostIncorrect,
      dayOfWeek: dayOfWeekStats,
      timeOfDay: timeOfDayStats,
    });
  } catch (err) {
    console.error('[quizHistory]', err);
    return res.status(500).json({ error: 'Failed to fetch quiz history.' });
  }
}

module.exports = { dashboard, weakest, weekly, timeOfDay, characterPerformance, quizHistory };
