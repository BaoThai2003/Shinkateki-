// services/adaptiveEngine.js
//
// ════════════════════════════════════════════════════════════════
//  SHINKATEKI — ADAPTIVE LEARNING ENGINE  (FIXED)
//
//  KEY FIX: Answer display rule:
//  - type === 'kanji'    → display reading_kana (NEVER romaji)
//  - type === 'hiragana' → display romaji
//  - type === 'katakana' → display romaji
// ════════════════════════════════════════════════════════════════
"use strict";

const { query, queryOne, withTransaction } = require("../config/db");

// ── Constants ────────────────────────────────────────────────────

const DIFFICULTY = {
  STRONG: "strong",
  MEDIUM: "medium",
  WEAK: "weak",
};

const THRESHOLD = {
  STRONG: 3,
  MEDIUM: 8,
};

const REVIEW_DELAY_MIN = {
  weak: 5,
  medium: 60 * 24,
  strong: 60 * 24 * 3,
};

const QUIZ_DISTRIBUTION = {
  weak: 0.7,
  medium: 0.2,
  strong: 0.1,
};

const DEFAULT_QUIZ_SIZE = 10;
const COMPASSION_THRESHOLD = 5;

// ── Weakness Score ───────────────────────────────────────────────

function computeWeaknessScore({
  oldScore = 0,
  isCorrect,
  responseTimeMs,
  mistakeStreak = 0,
}) {
  const wrong = isCorrect ? 0 : 1;
  const responseTimeSec = responseTimeMs / 1000;
  const contribution = wrong * 2 + responseTimeSec + mistakeStreak * 3;
  const newScore = oldScore * 0.6 + contribution * 0.4;
  return Math.max(0, parseFloat(newScore.toFixed(4)));
}

function classify(weaknessScore) {
  if (weaknessScore <= THRESHOLD.STRONG) return DIFFICULTY.STRONG;
  if (weaknessScore <= THRESHOLD.MEDIUM) return DIFFICULTY.MEDIUM;
  return DIFFICULTY.WEAK;
}

function nextReviewDate(difficultyClass) {
  const delayMs = REVIEW_DELAY_MIN[difficultyClass] * 60 * 1000;
  return new Date(Date.now() + delayMs);
}

// ── Database helpers ─────────────────────────────────────────────

async function getOrCreateStat(conn, userId, characterId) {
  const [rows] = await conn.execute(
    `SELECT * FROM performance_stats WHERE user_id = ? AND character_id = ?`,
    [userId, characterId]
  );
  if (rows[0]) return rows[0];

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

// ── Core update ──────────────────────────────────────────────────

async function recordAttempt({
  userId,
  characterId,
  isCorrect,
  responseTimeMs,
  sessionId,
}) {
  return withTransaction(async (conn) => {
    const stat = await getOrCreateStat(conn, userId, characterId);
    const newStreak = isCorrect ? 0 : stat.mistake_streak + 1;

    const newScore = computeWeaknessScore({
      oldScore: stat.weakness_score,
      isCorrect,
      responseTimeMs,
      mistakeStreak: newStreak,
    });

    const difficultyClass = classify(newScore);
    const totalAttempts = stat.correct_count + stat.wrong_count + 1;
    const newAvgMs = Math.round(
      (stat.avg_response_ms * (totalAttempts - 1) + responseTimeMs) /
        totalAttempts
    );
    const nextReview = nextReviewDate(difficultyClass);
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
 * FIX: Answer display rule enforced here:
 *   kanji   → correct_display = reading_kana  (kana reading, e.g. "いち")
 *   hiragana/katakana → correct_display = romaji (e.g. "a", "ka")
 *
 * _buildChoices also respects this rule for distractor options.
 */
async function generateQuiz(
  userId,
  { size = DEFAULT_QUIZ_SIZE, type = null } = {}
) {
  const compassionMode = await _isCompassionMode(userId);

  let typeFilterJoined = "";
  let typeFilterSimple = "";
  let typeParams = [];
  if (type && type !== "all") {
    typeFilterJoined = "AND c.type = ?";
    typeFilterSimple = "WHERE type = ?";
    typeParams = [type];
  }

  let selected = [];

  if (type === "all") {
    // Balanced distribution across all three types
    const hiraganaChars = await query(
      `SELECT id AS character_id, kana, romaji, reading_kana, 'hiragana' AS type, group_name, difficulty
       FROM characters WHERE type = 'hiragana' ORDER BY RAND() LIMIT ${Math.ceil(
         size * 0.35
       )}`
    );
    const katakanaChars = await query(
      `SELECT id AS character_id, kana, romaji, reading_kana, 'katakana' AS type, group_name, difficulty
       FROM characters WHERE type = 'katakana' ORDER BY RAND() LIMIT ${Math.ceil(
         size * 0.35
       )}`
    );
    const kanjiChars = await query(
      `SELECT id AS character_id, kana, romaji, reading_kana, 'kanji' AS type, group_name, difficulty
       FROM characters WHERE type = 'kanji' ORDER BY RAND() LIMIT ${Math.ceil(
         size * 0.35
       )}`
    );
    selected = [...hiraganaChars, ...katakanaChars, ...kanjiChars];

    if (selected.length < size) {
      const remaining = await query(
        `SELECT id AS character_id, kana, romaji, reading_kana, type, group_name, difficulty
         FROM characters ORDER BY RAND() LIMIT ${size - selected.length}`
      );
      selected.push(...remaining);
    }
    selected = selected.slice(0, size);
  } else if (type === "hiragana" || type === "katakana" || type === "kanji") {
    selected = await query(
      `SELECT id AS character_id, kana, romaji, reading_kana, type, group_name, difficulty
       FROM characters WHERE type = ? ORDER BY RAND() LIMIT ?`,
      [type, size]
    );
  } else {
    // Adaptive mode
    const statsRows = await query(
      `SELECT ps.character_id, ps.weakness_score, ps.difficulty_class,
              ps.mistake_streak, ps.next_review,
              c.kana, c.romaji, c.reading_kana, c.type, c.group_name, c.difficulty
       FROM performance_stats ps
       JOIN characters c ON c.id = ps.character_id
       WHERE ps.user_id = ? ${typeFilterJoined}
       ORDER BY ps.weakness_score DESC`,
      [userId, ...typeParams]
    );

    const unseenRows = await query(
      `SELECT id AS character_id, 0 AS weakness_score,
              'medium' AS difficulty_class, 0 AS mistake_streak,
              NULL AS next_review,
              kana, romaji, reading_kana, type, group_name, difficulty
       FROM characters
       ${typeFilterSimple ? typeFilterSimple : ""}
       ORDER BY difficulty ASC
       LIMIT 50`,
      typeParams
    );

    const buckets = {
      weak: statsRows.filter((r) => r.difficulty_class === "weak"),
      medium: [
        ...statsRows.filter((r) => r.difficulty_class === "medium"),
        ...unseenRows,
      ],
      strong: statsRows.filter((r) => r.difficulty_class === "strong"),
    };

    if (compassionMode) {
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

    if (selected.length < size) {
      const allRemaining = [
        ...buckets.weak,
        ...buckets.medium,
        ...buckets.strong,
        ...unseenRows,
      ].filter((r) => !selected.find((s) => s.character_id === r.character_id));
      selected.push(..._sample(allRemaining, size - selected.length));
    }
  }

  if (selected.length === 0) {
    selected = await query(
      `SELECT id AS character_id, kana, romaji, reading_kana, type, group_name, difficulty
       FROM characters ORDER BY RAND() LIMIT ?`,
      [size]
    );
  }

  selected = _shuffle(selected).slice(0, size);

  // Load all characters for distractor pool
  const allChars = await query(
    `SELECT id, kana, romaji, reading_kana, type FROM characters`
  );

  return selected.map((item) => {
    // ── CRITICAL FIX: Answer display rule ──
    // kanji → show kana reading (reading_kana)
    // hiragana/katakana → show romaji
    const correctDisplay = _getCorrectDisplay(item);

    return {
      characterId: item.character_id,
      character: item.kana,
      romaji: item.romaji,
      reading_kana: item.reading_kana,
      type: item.type,
      groupName: item.group_name,
      weaknessScore: parseFloat(item.weakness_score || 0),
      difficultyClass: item.difficulty_class ?? "medium",
      correct_display: correctDisplay,
      choices: _buildChoices(item, allChars, 4),
    };
  });
}

/**
 * CRITICAL FIX: Determine what value to display as the correct answer.
 * kanji    → reading_kana (e.g. "いち", "ニホン")
 * hiragana → romaji       (e.g. "a", "ka", "shi")
 * katakana → romaji       (e.g. "a", "ka", "shi")
 */
function _getCorrectDisplay(char) {
  if (char.type === "kanji") {
    // Use reading_kana; fallback to romaji only if reading_kana is missing
    const kana = char.reading_kana || char.kana;
    if (!kana) {
      console.warn(
        `[AdaptiveEngine] Kanji ${char.kana} missing reading_kana — falling back to romaji`
      );
    }
    return kana || char.romaji || "?";
  }
  // hiragana and katakana: always romaji
  return char.romaji || "?";
}

/**
 * Build multiple-choice options.
 * Distractors are selected from same type, using same display rule.
 * No duplicate display values allowed.
 */
function _buildChoices(targetChar, allChars, count) {
  const correctDisplay = _getCorrectDisplay(targetChar);
  const correct = {
    id: targetChar.character_id,
    romaji: correctDisplay, // "romaji" field is reused for display value
    correct: true,
  };

  // Only compare against same type
  const candidates = allChars.filter(
    (c) => c.type === targetChar.type && c.id !== targetChar.character_id
  );

  const usedDisplay = new Set([correctDisplay]);
  const pool = [];
  const shuffled = _shuffle(candidates);

  for (const char of shuffled) {
    if (pool.length >= count - 1) break;
    const display = _getCorrectDisplay(char);
    if (display && !usedDisplay.has(display)) {
      pool.push({ id: char.id, romaji: display, correct: false });
      usedDisplay.add(display);
    }
  }

  if (pool.length < count - 1) {
    console.warn(
      `[AdaptiveEngine] Only ${pool.length} unique distractors for "${correctDisplay}" (type: ${targetChar.type})`
    );
  }

  return _shuffle([correct, ...pool]);
}

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
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

async function _isCompassionMode(userId) {
  const row = await queryOne(
    `SELECT MAX(mistake_streak) AS maxStreak FROM performance_stats WHERE user_id = ?`,
    [userId]
  );
  return (row?.maxStreak ?? 0) >= COMPASSION_THRESHOLD;
}

// ── Vocabulary Quiz ───────────────────────────────────────────────

async function generateVocabularyQuiz(
  userId,
  { size = 10, jlptLevel = "N5" } = {}
) {
  const questionsCount = Math.min(size, 20);

  const vocabQuestions = await query(
    `SELECT id, word_kanji, word_hiragana, word_katakana, romaji,
            meaning_en, meaning_vi, part_of_speech
     FROM vocabulary
     WHERE jlpt_level = ?
     ORDER BY RAND()
     LIMIT ?`,
    [jlptLevel, questionsCount]
  );

  if (!vocabQuestions || vocabQuestions.length === 0) return [];

  const allVocab = await query(
    `SELECT romaji FROM vocabulary WHERE jlpt_level = ? LIMIT 100`,
    [jlptLevel]
  );

  return vocabQuestions.map((word) => {
    const displayForm =
      word.word_kanji || word.word_hiragana || word.word_katakana || "?";

    const usedRomaji = new Set([word.romaji]);
    const options = [word.romaji];

    for (const vocab of _shuffle(allVocab)) {
      if (options.length >= 4) break;
      if (!usedRomaji.has(vocab.romaji)) {
        options.push(vocab.romaji);
        usedRomaji.add(vocab.romaji);
      }
    }

    while (options.length < 4) {
      options.push(`option${options.length + 1}`);
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
