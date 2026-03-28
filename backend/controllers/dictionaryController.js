// controllers/dictionaryController.js
"use strict";

const { query } = require("../config/db");

// Get all vocabulary from completed lessons
async function getDictionary(req, res) {
  try {
    const userId = req.user.id;
    const userLanguage = req.user.language || "en";
    const { search, lesson_id } = req.query;

    let sql = `
      SELECT v.*, sl.lesson_number, sl.title_en, sl.title_vi
      FROM vocabulary v
      JOIN structured_lessons sl ON sl.id = v.lesson_id
      JOIN user_lesson_progress ulp ON ulp.lesson_id = sl.id AND ulp.user_id = ? AND ulp.is_completed = 1
      WHERE 1=1
    `;
    const params = [userId];

    if (search) {
      sql += ` AND (v.romaji LIKE ? OR v.hiragana LIKE ? OR v.katakana LIKE ? OR v.kanji LIKE ? OR v.english_meaning LIKE ? OR v.vietnamese_meaning LIKE ?)`;
      const searchTerm = `%${search}%`;
      params.push(
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm
      );
    }

    if (lesson_id) {
      sql += ` AND v.lesson_id = ?`;
      params.push(lesson_id);
    }

    sql += ` ORDER BY sl.lesson_number, v.id`;

    const vocabulary = await query(sql, params);

    let formattedVocabulary = vocabulary.map((word) => ({
      id: word.id,
      lesson_number: word.lesson_number,
      lesson_title: userLanguage === "vi" ? word.title_vi : word.title_en,
      romaji: word.romaji,
      hiragana: word.hiragana,
      katakana: word.katakana,
      kanji: word.kanji,
      meaning:
        userLanguage === "vi" ? word.vietnamese_meaning : word.english_meaning,
      part_of_speech: word.part_of_speech,
      example_sentence:
        userLanguage === "vi"
          ? word.example_sentence_vi
          : word.example_sentence_en,
    }));

    // Fallback for users with no completed lessons: show all vocabulary
    if (!formattedVocabulary.length && !searchTerm) {
      const allWords = await query(
        `
        SELECT v.*, sl.lesson_number, sl.title_en, sl.title_vi
        FROM vocabulary v
        JOIN structured_lessons sl ON sl.id = v.lesson_id
        ORDER BY sl.lesson_number, v.id
        LIMIT 200
      `
      );
      formattedVocabulary = allWords.map((word) => ({
        id: word.id,
        lesson_number: word.lesson_number,
        lesson_title: userLanguage === "vi" ? word.title_vi : word.title_en,
        romaji: word.romaji,
        hiragana: word.hiragana,
        katakana: word.katakana,
        kanji: word.kanji,
        meaning:
          userLanguage === "vi"
            ? word.vietnamese_meaning
            : word.english_meaning,
        part_of_speech: word.part_of_speech,
        example_sentence:
          userLanguage === "vi"
            ? word.example_sentence_vi
            : word.example_sentence_en,
      }));
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
    const userId = req.user.id;
    const lessonId = req.params.lessonId;
    const userLanguage = req.user.language || "en";

    // Check if lesson is completed
    const progress = await query(
      `
      SELECT is_completed FROM user_lesson_progress
      WHERE user_id = ? AND lesson_id = ?
    `,
      [userId, lessonId]
    );

    if (!progress.length || !progress[0].is_completed) {
      return res
        .status(403)
        .json({ error: "Lesson must be completed to view vocabulary." });
    }

    const vocabulary = await query(
      `
      SELECT * FROM vocabulary WHERE lesson_id = ? ORDER BY id
    `,
      [lessonId]
    );

    const formattedVocabulary = vocabulary.map((word) => ({
      id: word.id,
      romaji: word.romaji,
      hiragana: word.hiragana,
      katakana: word.katakana,
      kanji: word.kanji,
      meaning:
        userLanguage === "vi" ? word.vietnamese_meaning : word.english_meaning,
      part_of_speech: word.part_of_speech,
      example_sentence:
        userLanguage === "vi"
          ? word.example_sentence_vi
          : word.example_sentence_en,
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

    if (!searchTerm || searchTerm.length < 2) {
      return res.json([]);
    }

    const vocabulary = await query(
      `
      SELECT v.*, sl.lesson_number
      FROM vocabulary v
      JOIN structured_lessons sl ON sl.id = v.lesson_id
      JOIN user_lesson_progress ulp ON ulp.lesson_id = sl.id AND ulp.user_id = ? AND ulp.is_completed = 1
      WHERE v.romaji LIKE ? OR v.hiragana LIKE ? OR v.katakana LIKE ? OR v.kanji LIKE ?
         OR v.english_meaning LIKE ? OR v.vietnamese_meaning LIKE ?
      ORDER BY sl.lesson_number, v.id
      LIMIT 50
    `,
      [
        userId,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
        `%${searchTerm}%`,
      ]
    );

    const formattedVocabulary = vocabulary.map((word) => ({
      id: word.id,
      lesson_number: word.lesson_number,
      romaji: word.romaji,
      hiragana: word.hiragana,
      katakana: word.katakana,
      kanji: word.kanji,
      meaning:
        userLanguage === "vi" ? word.vietnamese_meaning : word.english_meaning,
      part_of_speech: word.part_of_speech,
      example_sentence:
        userLanguage === "vi"
          ? word.example_sentence_vi
          : word.example_sentence_en,
    }));

    return res.json(formattedVocabulary);
  } catch (err) {
    console.error("[searchVocabulary]", err);
    return res.status(500).json({ error: "Failed to search vocabulary." });
  }
}

module.exports = {
  getDictionary,
  getVocabularyByLesson,
  searchVocabulary,
};
