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
 * - For "all" or null type: includes Hiragana, Katakana, AND Kanji
 *
 * @param {number} userId
 * @param {object} opts  { size, type }  type = 'hiragana'|'katakana'|'kanji'|null
 * @returns {Array}  Array of character objects with distractors
 */
async function generateQuiz(
  userId,
  { size = DEFAULT_QUIZ_SIZE, type = null } = {}
) {
  // 1. Check for compassion mode
  const compassionMode = await _isCompassionMode(userId);

  // 2. Build type filter — if type is null/all, include all three; otherwise filter by type
  let typeFilter = "";
  let typeParams = [];
  if (type && type !== "all") {
    typeFilter = "AND c.type = ?";
    typeParams = [type];
  }

  // 3. Fetch all characters the user has stats for, split by class
  const statsRows = await query(
    `SELECT ps.character_id, ps.weakness_score, ps.difficulty_class,
          ps.mistake_streak, ps.next_review,
          c.kana, c.romaji, c.type, c.group_name, c.difficulty
   FROM performance_stats ps
   JOIN characters c ON c.id = ps.character_id
   WHERE ps.user_id = ? ${typeFilter}
   ORDER BY ps.weakness_score DESC`,
    [userId, ...typeParams]
  );

  // 4. Fetch characters the user has NEVER seen (no stat row)
  const seenIds = statsRows.map((r) => r.character_id);
  const unseenRows = await query(
    `SELECT id AS character_id, 0 AS weakness_score,
          'medium' AS difficulty_class, 0 AS mistake_streak,
          NULL AS next_review,
          kana, romaji, type, group_name, difficulty
   FROM characters
   ${typeFilter ? "WHERE " + typeFilter.replace("AND", "") : ""}
   ORDER BY difficulty ASC
   LIMIT 50`,
    typeParams
  );

  // 5. Bucket characters
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

  // 6. Fill to `size` if pools were too small
  if (selected.length < size) {
    const allRemaining = [
      ...buckets.weak,
      ...buckets.medium,
      ...buckets.strong,
      ...unseenRows,
    ].filter((r) => !selected.find((s) => s.character_id === r.character_id));
    selected.push(..._sample(allRemaining, size - selected.length));
  }

  // Shuffle the final list for true randomness
  selected = _shuffle(selected).slice(0, size);

  // 7. Attach multiple-choice distractors to each question
  const allChars = await query(
    `SELECT id, kana, romaji, type FROM characters ${
      typeFilter ? "WHERE " + typeFilter.replace("AND", "") : ""
    }`,
    typeParams
  );

  return selected.map((item) => ({
    characterId: item.character_id,
    character: item.kana,
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
 * ENSURES: No duplicate romaji answers, must be 100% different
 */
function _buildChoices(targetChar, allChars, count) {
  const correct = {
    id: targetChar.character_id,
    romaji: targetChar.romaji,
    correct: true,
  };

  // Filter out the correct answer and get candidates with UNIQUE romaji
  const usedRomaji = new Set([targetChar.romaji]);
  const pool = [];

  // Shuffle allChars first, then take unique romaji only
  const shuffled = _shuffle(
    allChars.filter((c) => c.id !== targetChar.character_id)
  );

  for (const char of shuffled) {
    if (pool.length >= count - 1) break;
    if (!usedRomaji.has(char.romaji)) {
      pool.push({
        id: char.id,
        romaji: char.romaji,
        correct: false,
      });
      usedRomaji.add(char.romaji);
    }
  }

  // If we don't have enough unique options, log a warning but continue
  if (pool.length < count - 1) {
    console.warn(
      `Warning: Only ${pool.length} unique distractors found for ${targetChar.romaji}`
    );
  }

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
  // True randomness using Fisher-Yates shuffle
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
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
  generateVocabularyQuiz,
  computeWeaknessScore,
  classify,
  DIFFICULTY,
  THRESHOLD,
  COMPASSION_THRESHOLD,
};

/**
 * Generate vocabulary questions from the vocabulary table
 * @param {number} userId
 * @param {object} opts { size, jlptLevel }
 * @returns {Array} Array of vocabulary question objects
 */
async function generateVocabularyQuiz(
  userId,
  { size = 10, jlptLevel = "N5" } = {}
) {
  const questionsCount = Math.min(size, 20);

  // Get vocabulary words to quiz on
  const vocabQuestions = await query(
    `SELECT id, word_kanji, word_hiragana, word_katakana, romaji, meaning_en, meaning_vi, part_of_speech
     FROM vocabulary
     WHERE jlpt_level = ?
     ORDER BY RAND()
     LIMIT ?`,
    [jlptLevel, questionsCount]
  );

  if (!vocabQuestions || vocabQuestions.length === 0) {
    return [];
  }

  // Get all vocabulary for distractors
  const allVocab = await query(
    `SELECT romaji FROM vocabulary WHERE jlpt_level = ? LIMIT 100`,
    [jlptLevel]
  );

  return vocabQuestions.map((word) => {
    // Display form (kanji if available, else hiragana, else katakana)
    const displayForm =
      word.word_kanji || word.word_hiragana || word.word_katakana || "?";

    // Create unique romaji options including the correct answer
    const usedRomaji = new Set([word.romaji]);
    const options = [word.romaji];

    for (const vocab of _shuffle(allVocab)) {
      if (options.length >= 4) break;
      if (!usedRomaji.has(vocab.romaji)) {
        options.push(vocab.romaji);
        usedRomaji.add(vocab.romaji);
      }
    }

    // Ensure we have 4 options
    while (options.length < 4) {
      const fallback = `option${options.length + 1}`;
      options.push(fallback);
    }

    return {
      id: word.id,
      type: "vocabulary",
      question: displayForm,
      questionText: `What is the romaji for "${displayForm}"?`,
      romaji: word.romaji,
      meaning: word.meaning_en,
      meaningVi: word.meaning_vi,
      correctAnswer: word.romaji,
      choices: _shuffle(options).map((opt) => ({
        romaji: opt,
        correct: opt === word.romaji,
      })),
    };
  });
}
