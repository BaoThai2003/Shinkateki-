// controllers/dictionaryController.js
"use strict";

const { query } = require("../config/db");

function _normalizeTerm(term) {
  return String(term || "")
    .trim()
    .toLowerCase();
}

function _levenshtein(a, b) {
  a = _normalizeTerm(a);
  b = _normalizeTerm(b);
  const matrix = Array.from({ length: a.length + 1 }, () => []);
  for (let i = 0; i <= a.length; i++) matrix[i][0] = i;
  for (let j = 0; j <= b.length; j++) matrix[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost,
      );
    }
  }
  return matrix[a.length][b.length];
}

function _fuzzyMatch(word, query) {
  const key = _normalizeTerm(query);
  if (!key) return false;

  const searchFields = [
    word.romaji,
    word.hiragana,
    word.katakana,
    word.kanji,
    word.english_meaning,
    word.vietnamese_meaning,
  ];

  const normalizedWord = searchFields
    .filter(Boolean)
    .map((s) => _normalizeTerm(s));

  if (normalizedWord.some((source) => source.includes(key))) return true;

  const closeEnough = normalizedWord.some(
    (source) =>
      _levenshtein(source, key) <= Math.max(2, Math.floor(key.length * 0.2)),
  );

  return closeEnough;
}

// Get all vocabulary from completed lessons
async function getDictionary(req, res) {
  try {
    const userId = req.user ? req.user.id : 1; // default user
    const userLanguage = req.user ? req.user.language || "en" : "en";
    const { search, lesson_id } = req.query;

    let sql = `
      SELECT v.*, sl.lesson_number, sl.title_en, sl.title_vi
      FROM vocabulary v
      LEFT JOIN structured_lessons sl ON sl.id = v.lesson_id
      WHERE 1=1
    `;
    const params = [];

    let searchTerm;
    if (search) {
      sql += ` AND (
        v.romaji LIKE ? OR v.word_hiragana LIKE ? OR v.word_katakana LIKE ? OR v.word_kanji LIKE ? OR v.meaning_en LIKE ? OR v.meaning_vi LIKE ?
      )`;
      searchTerm = `%${search}%`;
      params.push(
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
      );
    }

    if (lesson_id) {
      sql += ` AND v.lesson_id = ?`;
      params.push(lesson_id);
    }

    sql += ` ORDER BY v.id`;

    let vocabulary = await query(sql, params);

    // Fuzzy search fallback for non-completed vocabulary or typos
    if (search && vocabulary.length === 0) {
      const allVocab = await query(
        `SELECT v.*, sl.lesson_number, sl.title_en, sl.title_vi
         FROM vocabulary v
         LEFT JOIN structured_lessons sl ON sl.id = v.lesson_id
         ORDER BY sl.lesson_number, v.id
         LIMIT 500`,
      );

      vocabulary = allVocab.filter((word) => _fuzzyMatch(word, search));
    }

    let formattedVocabulary = vocabulary.map((word) => ({
      id: word.id,
      lesson_number: word.lesson_number,
      lesson_title: userLanguage === "vi" ? word.title_vi : word.title_en,
      source: userLanguage === "vi" ? word.title_vi : word.title_en,
      romaji: word.romaji,
      hiragana: word.word_hiragana,
      katakana: word.word_katakana,
      kanji: word.word_kanji,
      meaning: userLanguage === "vi" ? word.meaning_vi : word.meaning_en,
      part_of_speech: word.part_of_speech,
      example_sentence: null,
    }));

    // Fallback for users with no completed lessons: show all vocabulary
    if (!formattedVocabulary.length && !searchTerm) {
      const allWords = await query(
        `
        SELECT v.*, sl.lesson_number, sl.title_en, sl.title_vi
        FROM vocabulary v
        LEFT JOIN structured_lessons sl ON sl.id = v.lesson_id
        ORDER BY sl.lesson_number, v.id
        LIMIT 500
      `,
      );
      if (allWords) {
        formattedVocabulary = allWords.map((word) => ({
          id: word.id,
          lesson_number: word.lesson_number,
          lesson_title: userLanguage === "vi" ? word.title_vi : word.title_en,
          source: userLanguage === "vi" ? word.title_vi : word.title_en,
          romaji: word.romaji,
          hiragana: word.word_hiragana,
          katakana: word.word_katakana,
          kanji: word.word_kanji,
          meaning: userLanguage === "vi" ? word.meaning_vi : word.meaning_en,
          part_of_speech: word.part_of_speech,
          example_sentence: null,
        }));
      }
    }

    return res.json(formattedVocabulary);
  } catch (err) {
    console.error("[getDictionary]", err);
    return res.status(500).json({ error: "Failed to load dictionary." });
  }
}

// Get vocabulary by lesson
async function getVocabularyByLesson(req, res) {
  try {
    const lessonId = req.params.lessonId;
    const userLanguage = req.user.language || "en";

    const vocabulary = await query(
      `
      SELECT * FROM vocabulary WHERE lesson_id = ? ORDER BY id
    `,
      [lessonId],
    );

    const formattedVocabulary = vocabulary.map((word) => ({
      id: word.id,
      romaji: word.romaji,
      hiragana: word.word_hiragana,
      katakana: word.word_katakana,
      kanji: word.word_kanji,
      meaning: userLanguage === "vi" ? word.meaning_vi : word.meaning_en,
      part_of_speech: word.part_of_speech,
      example_sentence: null,
    }));

    return res.json(formattedVocabulary);
  } catch (err) {
    console.error("[getVocabularyByLesson]", err);
    return res.status(500).json({ error: "Failed to load vocabulary." });
  }
}

// Search vocabulary
async function searchVocabulary(req, res) {
  try {
    const userId = req.user.id;
    const { q: searchTerm } = req.query;
    const userLanguage = req.user.language || "en";

    console.log("Dictionary search term:", searchTerm);

    if (!searchTerm || searchTerm.length < 2) {
      return res.json([]);
    }

    let vocabulary = await query(
      `
      SELECT v.*, sl.lesson_number, sl.title_en, sl.title_vi
      FROM vocabulary v
      LEFT JOIN structured_lessons sl ON sl.id = v.lesson_id
      WHERE v.romaji LIKE ? OR v.word_hiragana LIKE ? OR v.word_katakana LIKE ? OR v.word_kanji LIKE ?
         OR v.meaning_en LIKE ? OR v.meaning_vi LIKE ?
      ORDER BY sl.lesson_number, v.id
      LIMIT 50
    `,
      [
        `%${searchTerm}%`,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
      ],
    );

    if (!vocabulary.length) {
      const allVocab = await query(
        `SELECT v.*, sl.lesson_number
         FROM vocabulary v
         JOIN structured_lessons sl ON sl.id = v.lesson_id
         ORDER BY sl.lesson_number, v.id
         LIMIT 1000`,
      );
      vocabulary = allVocab.filter((word) => _fuzzyMatch(word, searchTerm));
    }

    const formattedVocabulary = vocabulary.map((word) => ({
      id: word.id,
      lesson_number: word.lesson_number,
      lesson_title: userLanguage === "vi" ? word.title_vi : word.title_en,
      source: userLanguage === "vi" ? word.title_vi : word.title_en,
      romaji: word.romaji,
      hiragana: word.word_hiragana,
      katakana: word.word_katakana,
      kanji: word.word_kanji,
      meaning: userLanguage === "vi" ? word.meaning_vi : word.meaning_en,
      part_of_speech: word.part_of_speech,
      example_sentence: null,
    }));

    return res.json(formattedVocabulary);
  } catch (err) {
    console.error("[searchVocabulary]", err);
    return res.status(500).json({ error: "Failed to search vocabulary." });
  }
}

async function addVocabulary(req, res) {
  try {
    const userId = req.user.id; // currently not used but keeps consistency
    const {
      lesson_id,
      romaji,
      hiragana,
      katakana,
      kanji,
      english_meaning,
      vietnamese_meaning,
      part_of_speech,
      example_sentence_en,
      example_sentence_vi,
    } = req.body;

    if (!lesson_id || !romaji || !english_meaning) {
      return res
        .status(400)
        .json({ error: "lesson_id, romaji and english_meaning are required" });
    }

    const result = await query(
      `INSERT INTO vocabulary
         (lesson_id, romaji, hiragana, katakana, kanji,
          english_meaning, vietnamese_meaning, part_of_speech,
          example_sentence_en, example_sentence_vi)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        lesson_id,
        romaji,
        hiragana || null,
        katakana || null,
        kanji || null,
        english_meaning,
        vietnamese_meaning || null,
        part_of_speech || null,
        example_sentence_en || null,
        example_sentence_vi || null,
      ],
    );

    const created = await query(`SELECT * FROM vocabulary WHERE id = ?`, [
      result.insertId,
    ]);

    return res.status(201).json({ success: true, word: created[0] });
  } catch (err) {
    console.error("[addVocabulary]", err);
    return res.status(500).json({ error: "Failed to add vocabulary." });
  }
}

module.exports = {
  getDictionary,
  getVocabularyByLesson,
  searchVocabulary,
  addVocabulary,
};
