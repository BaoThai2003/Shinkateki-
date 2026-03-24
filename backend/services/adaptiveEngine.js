// services/adaptiveEngine.js
//
// ════════════════════════════════════════════════════════════════
//  SHINKATEKI — ADAPTIVE LEARNING ENGINE
//
//  Responsibilities:
//  1. Compute weakness_score for a user+character after each attempt
//  2. Classify characters → strong / medium / weak
//  3. Generate an adaptive quiz with the 70/20/10 distribution
//  4. Schedule next_review using spaced repetition
// ════════════════════════════════════════════════════════════════
"use strict";

const { query, queryOne, withTransaction } = require("../config/db");

// ── Constants ────────────────────────────────────────────────────

const DIFFICULTY = {
  STRONG: "strong",
  MEDIUM: "medium",
  WEAK: "weak",
};

// Thresholds that classify weakness_score
const THRESHOLD = {
  STRONG: 3, // 0 – 3   → strong
  MEDIUM: 8, // 4 – 8   → medium
  // > 8          → weak
};

// Minutes until next review per difficulty class
const REVIEW_DELAY_MIN = {
  weak: 5,
  medium: 60 * 24, // 1 day
  strong: 60 * 24 * 3, // 3 days
};

// Quiz generation target distribution
const QUIZ_DISTRIBUTION = {
  weak: 0.7,
  medium: 0.2,
  strong: 0.1,
};

// Default quiz size
const DEFAULT_QUIZ_SIZE = 10;

// Number of consecutive wrong answers that triggers "compassion mode"
const COMPASSION_THRESHOLD = 5;

// ── Weakness Score ───────────────────────────────────────────────

/**
 * Compute a fresh weakness_score from raw attempt data.
 *
 * Formula (per-attempt contribution):
 *   score += (wrong * 2) + (response_time_s) + (mistake_streak * 3)
 *
 * The final score is a rolling weighted average:
 *   new_score = old_score * 0.6 + latest_contribution * 0.4
 *
 * This gives more weight to recent behaviour (recency bias) while
 * still remembering historical trouble with a character.
 */
function computeWeaknessScore({
  oldScore = 0,
  isCorrect,
  responseTimeMs,
  mistakeStreak = 0,
}) {
  const wrong = isCorrect ? 0 : 1;
  const responseTimeSec = responseTimeMs / 1000;

  // Raw contribution of this single attempt
  const contribution = wrong * 2 + responseTimeSec + mistakeStreak * 3;

  // Exponential moving average — recent attempts dominate
  const newScore = oldScore * 0.6 + contribution * 0.4;

  return Math.max(0, parseFloat(newScore.toFixed(4)));
}

/**
 * Map a numeric weakness_score to a difficulty class.
 */
function classify(weaknessScore) {
  if (weaknessScore <= THRESHOLD.STRONG) return DIFFICULTY.STRONG;
  if (weaknessScore <= THRESHOLD.MEDIUM) return DIFFICULTY.MEDIUM;
  return DIFFICULTY.WEAK;
}

/**
 * Compute next_review datetime from difficulty class.
 */
function nextReviewDate(difficultyClass) {
  const delayMs = REVIEW_DELAY_MIN[difficultyClass] * 60 * 1000;
  return new Date(Date.now() + delayMs);
}

// ── Database helpers ─────────────────────────────────────────────

/**
 * Load or initialise performance_stats row for user+character.
 */
async function getOrCreateStat(conn, userId, characterId) {
  const [rows] = await conn.execute(
    `SELECT * FROM performance_stats WHERE user_id = ? AND character_id = ?`,
    [userId, characterId]
  );
  if (rows[0]) return rows[0];

  // First encounter — insert a default row
  await conn.execute(
    `INSERT INTO performance_stats
       (user_id, character_id, weakness_score, difficulty_class,
        correct_count, wrong_count, avg_response_ms, mistake_streak,
        last_reviewed, next_review)
     VALUES (?, ?, 4, 'medium', 0, 0, 0, 0, NULL, NOW())`,
    [userId, characterId]
  );

  const [newRows] = await conn.execute(
    `SELECT * FROM performance_stats WHERE user_id = ? AND character_id = ?`,
    [userId, characterId]
  );
  return newRows[0];
}

// ── Core update: called after every answer ───────────────────────

/**
 * Record an attempt and update all derived state in one transaction.
 *
 * @param {object} opts
 * @param {number}  opts.userId
 * @param {number}  opts.characterId
 * @param {boolean} opts.isCorrect
 * @param {number}  opts.responseTimeMs  - client-measured round-trip ms
 * @param {string}  opts.sessionId       - UUID grouping a quiz session
 * @returns {object}  Updated performance_stats row + new weakness_score
 */
async function recordAttempt({
  userId,
  characterId,
  isCorrect,
  responseTimeMs,
  sessionId,
}) {
  return withTransaction(async (conn) => {
    // 1. Load current stat (creates if missing)
    const stat = await getOrCreateStat(conn, userId, characterId);

    // 2. Update mistake_streak
    const newStreak = isCorrect ? 0 : stat.mistake_streak + 1;

    // 3. Compute new weakness score
    const newScore = computeWeaknessScore({
      oldScore: stat.weakness_score,
      isCorrect,
      responseTimeMs,
      mistakeStreak: newStreak,
    });

    // 4. Classify
    const difficultyClass = classify(newScore);

    // 5. Running average of response time
    const totalAttempts = stat.correct_count + stat.wrong_count + 1;
    const newAvgMs = Math.round(
      (stat.avg_response_ms * (totalAttempts - 1) + responseTimeMs) /
        totalAttempts
    );

    // 6. Next review schedule
    const nextReview = nextReviewDate(difficultyClass);

    // 7. Insert attempt record
    const hourOfDay = new Date().getUTCHours();
    await conn.execute(
      `INSERT INTO attempts
         (user_id, character_id, is_correct, response_time,
          mistake_streak, hour_of_day, session_id)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        userId,
        characterId,
        isCorrect ? 1 : 0,
        responseTimeMs,
        newStreak,
        hourOfDay,
        sessionId,
      ]
    );

    // 8. Upsert performance_stats
    await conn.execute(
      `UPDATE performance_stats SET
         weakness_score   = ?,
         difficulty_class = ?,
         correct_count    = correct_count + ?,
         wrong_count      = wrong_count  + ?,
         avg_response_ms  = ?,
         mistake_streak   = ?,
         last_reviewed    = NOW(),
         next_review      = ?
       WHERE user_id = ? AND character_id = ?`,
      [
        newScore,
        difficultyClass,
        isCorrect ? 1 : 0,
        isCorrect ? 0 : 1,
        newAvgMs,
        newStreak,
        nextReview,
        userId,
        characterId,
      ]
    );

    // 9. Update time-of-day stats (upsert)
    await _updateTimeOfDayStat(
      conn,
      userId,
      hourOfDay,
      isCorrect,
      responseTimeMs
    );

    return {
      weaknessScore: newScore,
      difficultyClass,
      mistakeStreak: newStreak,
      nextReview,
    };
  });
}

/**
 * Maintain a running accuracy/response-time average per hour-slot.
 */
async function _updateTimeOfDayStat(
  conn,
  userId,
  hourSlot,
  isCorrect,
  responseTimeMs
) {
  const [[existing]] = await conn.execute(
    `SELECT * FROM time_of_day_stats WHERE user_id = ? AND hour_slot = ?`,
    [userId, hourSlot]
  );

  if (!existing) {
    await conn.execute(
      `INSERT INTO time_of_day_stats
         (user_id, hour_slot, total_attempts, correct_count, avg_response_ms, accuracy_rate)
       VALUES (?, ?, 1, ?, ?, ?)`,
      [
        userId,
        hourSlot,
        isCorrect ? 1 : 0,
        responseTimeMs,
        isCorrect ? 1.0 : 0.0,
      ]
    );
  } else {
    const newTotal = existing.total_attempts + 1;
    const newCorrect = existing.correct_count + (isCorrect ? 1 : 0);
    const newAvgMs = Math.round(
      (existing.avg_response_ms * existing.total_attempts + responseTimeMs) /
        newTotal
    );
    await conn.execute(
      `UPDATE time_of_day_stats SET
         total_attempts  = ?,
         correct_count   = ?,
         avg_response_ms = ?,
         accuracy_rate   = ?
       WHERE user_id = ? AND hour_slot = ?`,
      [newTotal, newCorrect, newAvgMs, newCorrect / newTotal, userId, hourSlot]
    );
  }
}

// ── Quiz Generation ──────────────────────────────────────────────

/**
 * Generate an adaptive quiz for a user.
 *
 * Behaviour:
 * - Prefer characters whose next_review <= NOW (due for review)
 * - Apply 70/20/10 distribution across weak/medium/strong
 * - If user has a long mistake_streak (≥ COMPASSION_THRESHOLD),
 *   temporarily inject easy characters to rebuild confidence
 * - New characters (no stat row) are treated as medium
 *
 * @param {number} userId
 * @param {object} opts  { size, type }  type = 'hiragana'|'katakana'|null
 * @returns {Array}  Array of character objects with distractors
 */
async function generateQuiz(
  userId,
  { size = DEFAULT_QUIZ_SIZE, type = null } = {}
) {
  // 1. Check for compassion mode
  const compassionMode = await _isCompassionMode(userId);

  // 2. Fetch all characters the user has stats for, split by class
  const statsRows = await query(
    `SELECT ps.character_id, ps.weakness_score, ps.difficulty_class,
            ps.mistake_streak, ps.next_review,
            c.symbol, c.hina, c.kana, c.romaji, c.type, c.group_name, c.difficulty
     FROM performance_stats ps
     JOIN characters c ON c.id = ps.character_id
     WHERE ps.user_id = ?
       ${type ? "AND c.type = ?" : ""}
     ORDER BY ps.weakness_score DESC`,
    type ? [userId, type] : [userId]
  );

  // 3. Fetch characters the user has NEVER seen (no stat row)
  const seenIds = statsRows.map((r) => r.character_id);
  const unseenRows = await query(
    `SELECT id AS character_id, 0 AS weakness_score,
            'medium' AS difficulty_class, 0 AS mistake_streak,
            NULL AS next_review,
            character, romaji, type, group_name, difficulty
     FROM characters
     WHERE ${type ? "type = ? AND" : ""}
           id NOT IN (${
             seenIds.length ? seenIds.map(() => "?").join(",") : "NULL"
           })
     ORDER BY difficulty ASC
     LIMIT 20`,
    [...(type ? [type] : []), ...(seenIds.length ? seenIds : [])]
  );

  // 4. Bucket characters
  const buckets = {
    weak: statsRows.filter((r) => r.difficulty_class === "weak"),
    medium: [
      ...statsRows.filter((r) => r.difficulty_class === "medium"),
      ...unseenRows,
    ],
    strong: statsRows.filter((r) => r.difficulty_class === "strong"),
  };

  let selected;

  if (compassionMode) {
    // In compassion mode: 80% strong/medium (easiest first) + 20% weak
    const easyPool = [...buckets.strong, ...buckets.medium].sort(
      (a, b) => a.weakness_score - b.weakness_score
    );
    selected = [
      ..._sampleDue(easyPool, Math.ceil(size * 0.8)),
      ..._sampleDue(buckets.weak, Math.ceil(size * 0.2)),
    ];
  } else {
    selected = [
      ..._sampleDue(buckets.weak, Math.round(size * QUIZ_DISTRIBUTION.weak)),
      ..._sampleDue(
        buckets.medium,
        Math.round(size * QUIZ_DISTRIBUTION.medium)
      ),
      ..._sampleDue(
        buckets.strong,
        Math.round(size * QUIZ_DISTRIBUTION.strong)
      ),
    ];
  }

  // 5. Fill to `size` if pools were too small
  if (selected.length < size) {
    const allRemaining = [
      ...buckets.weak,
      ...buckets.medium,
      ...buckets.strong,
      ...unseenRows,
    ].filter((r) => !selected.find((s) => s.character_id === r.character_id));
    selected.push(..._sample(allRemaining, size - selected.length));
  }

  // Shuffle the final list
  selected = _shuffle(selected).slice(0, size);

  // 6. Attach multiple-choice distractors to each question
  const allChars = await query(
    `SELECT id, character, romaji, type FROM characters ${
      type ? "WHERE type = ?" : ""
    }`,
    type ? [type] : []
  );

  return selected.map((item) => ({
    characterId: item.character_id,
    character: item.character,
    romaji: item.romaji,
    type: item.type,
    groupName: item.group_name,
    weaknessScore: parseFloat(item.weakness_score),
    difficultyClass: item.difficulty_class ?? "medium",
    choices: _buildChoices(item, allChars, 4),
  }));
}

/**
 * Build an array of N multiple-choice options including the correct answer.
 */
function _buildChoices(targetChar, allChars, count) {
  const correct = {
    id: targetChar.character_id,
    romaji: targetChar.romaji,
    correct: true,
  };
  const pool = allChars
    .filter((c) => c.id !== targetChar.character_id)
    .sort(() => Math.random() - 0.5)
    .slice(0, count - 1)
    .map((c) => ({ id: c.id, romaji: c.romaji, correct: false }));

  return _shuffle([correct, ...pool]);
}

/**
 * Sample up to `n` items, prioritising those due for review (next_review <= NOW).
 */
function _sampleDue(pool, n) {
  if (!pool.length || n <= 0) return [];
  const now = Date.now();
  const due = pool.filter(
    (r) => !r.next_review || new Date(r.next_review).getTime() <= now
  );
  const notDue = pool.filter(
    (r) => r.next_review && new Date(r.next_review).getTime() > now
  );
  return _sample([..._shuffle(due), ..._shuffle(notDue)], n);
}

function _sample(arr, n) {
  return arr.slice(0, Math.min(n, arr.length));
}
function _shuffle(arr) {
  return arr.sort(() => Math.random() - 0.5);
}

/**
 * Check whether any character for this user has a live streak >= threshold.
 */
async function _isCompassionMode(userId) {
  const row = await queryOne(
    `SELECT MAX(mistake_streak) AS maxStreak
     FROM performance_stats
     WHERE user_id = ?`,
    [userId]
  );
  return (row?.maxStreak ?? 0) >= COMPASSION_THRESHOLD;
}

// ── Exports ───────────────────────────────────────────────────────

module.exports = {
  recordAttempt,
  generateQuiz,
  computeWeaknessScore,
  classify,
  DIFFICULTY,
  THRESHOLD,
  COMPASSION_THRESHOLD,
};
