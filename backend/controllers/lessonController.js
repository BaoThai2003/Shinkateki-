// controllers/lessonController.js
"use strict";

const { query, withTransaction } = require("../config/db");

async function myLessons(req, res) {
  try {
    const userId = req.user.id;
    const rows = await query(
      `SELECT l.id, l.title, l.content, l.is_public, l.created_at,
              COUNT(q.id) AS question_count
       FROM lessons l
       LEFT JOIN lesson_questions q ON q.lesson_id = l.id
       WHERE l.user_id = ?
       GROUP BY l.id
       ORDER BY l.created_at DESC`,
      [userId]
    );

    return res.json(rows);
  } catch (err) {
    console.error("[myLessons]", err);
    return res.status(500).json({ error: "Failed to load lessons." });
  }
}

async function publicLessons(req, res) {
  try {
    const rows = await query(
      `SELECT l.id, l.title, l.content, l.user_id, u.username,
              COUNT(q.id) AS question_count
       FROM lessons l
       JOIN users u ON u.id = l.user_id
       LEFT JOIN lesson_questions q ON q.lesson_id = l.id
       WHERE l.is_public = 1
       GROUP BY l.id
       ORDER BY l.created_at DESC
       LIMIT 50`
    );
    return res.json(rows);
  } catch (err) {
    console.error("[publicLessons]", err);
    return res.status(500).json({ error: "Failed to load public lessons." });
  }
}

async function createLesson(req, res) {
  const userId = req.user.id;
  const { title, content, isPublic = false, questions } = req.body;

  if (
    !title ||
    !content ||
    !Array.isArray(questions) ||
    questions.length === 0
  ) {
    return res.status(422).json({ error: "Invalid lesson payload." });
  }

  if (questions.length > 25) {
    return res.status(422).json({ error: "Max 25 quiz questions per lesson." });
  }

  for (const q of questions) {
    if (
      !q.questionText ||
      !Array.isArray(q.options) ||
      q.options.length !== 4
    ) {
      return res
        .status(422)
        .json({ error: "Each question must have 4 options." });
    }
    if (q.options.some((o) => typeof o !== "string" || !o.trim())) {
      return res.status(422).json({ error: "All options are required." });
    }
    if (![0, 1, 2, 3].includes(Number(q.correctIndex))) {
      return res
        .status(422)
        .json({ error: "A correct answer must be chosen for each question." });
    }
  }

  try {
    const result = await withTransaction(async (conn) => {
      const [insertResult] = await conn.execute(
        `INSERT INTO lessons (user_id, title, content, is_public) VALUES (?, ?, ?, ?)`,
        [userId, title, content, isPublic ? 1 : 0]
      );
      const lessonId = insertResult.insertId;

      const qInsertSql = `INSERT INTO lesson_questions
        (lesson_id, question_text, option_a, option_b, option_c, option_d, correct_option)
        VALUES (?, ?, ?, ?, ?, ?, ?)`;

      for (const q of questions) {
        await conn.execute(qInsertSql, [
          lessonId,
          q.questionText,
          q.options[0],
          q.options[1],
          q.options[2],
          q.options[3],
          ["a", "b", "c", "d"][Number(q.correctIndex)],
        ]);
      }

      return lessonId;
    });

    return res
      .status(201)
      .json({ message: "Lesson created.", lessonId: result });
  } catch (err) {
    console.error("[createLesson]", err);
    return res.status(500).json({ error: "Failed to create lesson." });
  }
}

async function getLessonById(req, res) {
  try {
    const userId = req.user.id;
    const lessonId = Number(req.params.id);

    const lessons = await query(
      `SELECT l.*, u.username FROM lessons l JOIN users u ON u.id = l.user_id WHERE l.id = ? LIMIT 1`,
      [lessonId]
    );

    if (!lessons.length) {
      return res.status(404).json({ error: "Lesson not found." });
    }

    const lesson = lessons[0];

    if (!lesson.is_public && lesson.user_id !== userId) {
      return res
        .status(403)
        .json({ error: "Not allowed to access this lesson." });
    }

    const questions = await query(
      `SELECT id, question_text, option_a, option_b, option_c, option_d, correct_option FROM lesson_questions WHERE lesson_id = ? ORDER BY id`,
      [lessonId]
    );

    return res.json({
      id: lesson.id,
      title: lesson.title,
      content: lesson.content,
      is_public: lesson.is_public === 1,
      questions,
    });
  } catch (err) {
    console.error("[getLessonById]", err);
    return res.status(500).json({ error: "Failed to load lesson." });
  }
}

async function setVisibility(req, res) {
  try {
    const userId = req.user.id;
    const lessonId = Number(req.params.id);
    let { isPublic } = req.body;

    // Allow both JSON boolean and string-form boolean for compatibility
    if (typeof isPublic === "string") {
      isPublic = isPublic === "true" || isPublic === "1";
    }

    if (typeof isPublic !== "boolean") {
      return res.status(422).json({ error: "isPublic must be boolean." });
    }

    const lesson = await query(
      "SELECT id FROM lessons WHERE id = ? AND user_id = ? LIMIT 1",
      [lessonId, userId]
    );

    if (!lesson.length) {
      return res.status(404).json({ error: "Lesson not found." });
    }

    await query("UPDATE lessons SET is_public = ? WHERE id = ?", [
      isPublic ? 1 : 0,
      lessonId,
    ]);
    return res.json({ message: "Visibility updated." });
  } catch (err) {
    console.error("[setVisibility]", err);
    return res.status(500).json({ error: "Failed to set visibility." });
  }
}

module.exports = {
  myLessons,
  publicLessons,
  createLesson,
  getLessonById,
  setVisibility,
};
