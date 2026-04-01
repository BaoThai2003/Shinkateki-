// controllers/structuredLessonsController.js
"use strict";

const { query, withTransaction } = require("../config/db");

// Get all chapters with sections and lessons
async function getChapters(req, res) {
  try {
    const userId = req.user ? req.user.id : 1; // Use test user ID if no auth
    const userLanguage = req.user ? req.user.language || "en" : "vi";

    console.log(
      "Getting chapters for userId:",
      userId,
      "language:",
      userLanguage
    );

    // Get chapters with sections and lessons
    const chapters = await query(
      `
      SELECT
        c.id, c.title_en, c.title_vi, c.description_en, c.description_vi, c.order_index,
        s.id as section_id, s.title_en as section_title_en, s.title_vi as section_title_vi,
        s.description_en as section_description_en, s.description_vi as section_description_vi,
        s.order_index as section_order,
        sl.id as lesson_id, sl.lesson_number, sl.title_en as lesson_title_en, sl.title_vi as lesson_title_vi,
        sl.content_en, sl.content_vi, sl.lesson_type as type, sl.prerequisite_lesson_id,
        up.completed as is_completed
      FROM chapters c
      LEFT JOIN sections s ON s.chapter_id = c.id
      LEFT JOIN structured_lessons sl ON sl.section_id = s.id
      LEFT JOIN user_progress up ON up.lesson_id = sl.id AND up.user_id = ?
      ORDER BY c.order_index, s.order_index, sl.lesson_number
    `,
      [userId]
    );

    // Group by chapters and sections
    const result = {};
    chapters.forEach((row) => {
      if (!result[row.id]) {
        result[row.id] = {
          id: row.id,
          title: userLanguage === "vi" ? row.title_vi : row.title_en,
          description:
            userLanguage === "vi" ? row.description_vi : row.description_en,
          order_index: row.order_index,
          sections: {},
        };
      }

      if (row.section_id && !result[row.id].sections[row.section_id]) {
        result[row.id].sections[row.section_id] = {
          id: row.section_id,
          title:
            userLanguage === "vi" ? row.section_title_vi : row.section_title_en,
          description:
            userLanguage === "vi"
              ? row.section_description_vi
              : row.section_description_en,
          order_index: row.section_order,
          lessons: [],
        };
      }

      if (row.lesson_id) {
        const prerequisites = row.prerequisite_lesson_id
          ? [row.prerequisite_lesson_id]
          : [];
        const isFirstLesson = Number(row.lesson_number) === 1;
        const isUnlocked =
          isFirstLesson || prerequisites.length === 0 || row.is_completed === 1; // completed implies unlocked

        result[row.id].sections[row.section_id].lessons.push({
          id: row.lesson_id,
          lesson_number: row.lesson_number,
          title:
            userLanguage === "vi" ? row.lesson_title_vi : row.lesson_title_en,
          content_en: row.content_en,
          content_vi: row.content_vi,
          content: userLanguage === "vi" ? row.content_vi : row.content_en,
          type: row.type,
          prerequisites,
          unlocks: [], // No unlocks column, so empty array
          is_completed: !!row.is_completed,
          is_unlocked: !!isUnlocked,
        });
      }
    });

    // Convert to array format
    const chaptersArray = Object.values(result).map((chapter) => ({
      ...chapter,
      sections: Object.values(chapter.sections),
    }));

    return res.json(chaptersArray);
  } catch (err) {
    console.error("[getChapters]", err);
    return res.status(500).json({ error: "Failed to load chapters." });
  }
}

// Get a specific lesson with content
async function getLesson(req, res) {
  try {
    const userId = req.user.id;
    const lessonId = req.params.id;
    const userLanguage = req.user.language || "en";

    // Get lesson details
    const lessons = await query(
      `
      SELECT sl.*, ulp.is_completed, ulp.is_unlocked
      FROM structured_lessons sl
      LEFT JOIN user_lesson_progress ulp ON ulp.lesson_id = sl.id AND ulp.user_id = ?
      WHERE sl.id = ?
    `,
      [userId, lessonId]
    );

    if (lessons.length === 0) {
      return res.status(404).json({ error: "Lesson not found." });
    }

    const lesson = lessons[0];

    let prerequisites = [];
    if (lesson.prerequisites) {
      try {
        prerequisites = JSON.parse(lesson.prerequisites);
      } catch (_err) {
        prerequisites = [];
      }
    }

    // Check if lesson is unlocked
    const lessonNumber = lesson.lesson_number;
    if (!lesson.is_unlocked && lessonNumber !== 1) {
      if (Array.isArray(prerequisites) && prerequisites.length > 0) {
        const completedPrerequisites = await query(
          `
        SELECT COUNT(*) as count FROM user_lesson_progress
        WHERE user_id = ? AND lesson_id IN (?) AND is_completed = 1
      `,
          [userId, prerequisites]
        );

        if (completedPrerequisites[0].count < prerequisites.length) {
          return res
            .status(403)
            .json({ error: "Lesson prerequisites not met." });
        }
      } else {
        // Allow lessons with no prerequisites
        lesson.is_unlocked = 1;
      }
    } else {
      // Always allow lesson 1
      lesson.is_unlocked = 1;
    }

    // Get vocabulary for this lesson
    const vocabulary = await query(
      `
      SELECT * FROM vocabulary WHERE lesson_id = ? ORDER BY id
    `,
      [lessonId]
    );

    // Format vocabulary based on language
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

    const response = {
      id: lesson.id,
      lesson_number: lesson.lesson_number,
      title: userLanguage === "vi" ? lesson.title_vi : lesson.title_en,
      content: userLanguage === "vi" ? lesson.content_vi : lesson.content_en,
      type: lesson.type,
      script_type: lesson.script_type,
      prerequisites: lesson.prerequisites
        ? JSON.parse(lesson.prerequisites)
        : [],
      is_completed: !!lesson.is_completed,
      is_unlocked: !!lesson.is_unlocked,
      vocabulary: formattedVocabulary,
    };

    return res.json(response);
  } catch (err) {
    console.error("[getLesson]", err);
    return res.status(500).json({ error: "Failed to load lesson." });
  }
}
// Get a random quick quiz from all review lessons
async function getReviewQuiz(req, res) {
  try {
    const userLanguage = req.user.language || "en";
    const size = Math.min(Math.max(parseInt(req.query.size || "15"), 10), 20);
    const script = (req.query.script || "").toLowerCase();

    const scriptFilter =
      script === "hiragana"
        ? "AND (sl.script_type IN ('hiragana', 'both'))"
        : script === "katakana"
        ? "AND (sl.script_type IN ('katakana', 'both'))"
        : "";

    const questions = await query(
      `SELECT qq.* FROM quiz_questions qq
       JOIN structured_lessons sl ON sl.id = qq.lesson_id
       WHERE sl.type = 'review' ${scriptFilter}
       ORDER BY RAND() LIMIT ?`,
      [size]
    );

    const formatted = questions.map((q) => ({
      id: q.id,
      lesson_id: q.lesson_id,
      question: userLanguage === "vi" ? q.question_text_vi : q.question_text_en,
      romaji: q.romaji,
      options: [q.option_a, q.option_b, q.option_c, q.option_d].filter(Boolean),
      correct_answer: q.correct_answer,
      explanation: userLanguage === "vi" ? q.explanation_vi : q.explanation_en,
    }));

    return res.json(formatted);
  } catch (err) {
    console.error("[getReviewQuiz]", err);
    return res.status(500).json({ error: "Failed to load quick review quiz." });
  }
}
// Mark lesson as completed
async function completeLesson(req, res) {
  try {
    const userId = req.user.id;
    const lessonId = req.params.id;

    await withTransaction(async (connection) => {
      // Mark lesson as completed
      await connection.query(
        `
        INSERT INTO user_lesson_progress (user_id, lesson_id, is_completed, completed_at)
        VALUES (?, ?, 1, NOW())
        ON DUPLICATE KEY UPDATE is_completed = 1, completed_at = NOW()
      `,
        [userId, lessonId]
      );

      // Check if this unlocks other lessons
      const lesson = await connection.query(
        `
        SELECT unlocks FROM structured_lessons WHERE id = ?
      `,
        [lessonId]
      );

      if (lesson.length > 0 && lesson[0].unlocks) {
        const unlocks = JSON.parse(lesson[0].unlocks);
        for (const unlockId of unlocks) {
          await connection.query(
            `
            INSERT INTO user_lesson_progress (user_id, lesson_id, is_unlocked)
            VALUES (?, ?, 1)
            ON DUPLICATE KEY UPDATE is_unlocked = 1
          `,
            [userId, unlockId]
          );
        }
      }
    });

    return res.json({ success: true });
  } catch (err) {
    console.error("[completeLesson]", err);
    return res.status(500).json({ error: "Failed to complete lesson." });
  }
}

// Get quiz questions for a lesson
async function getLessonQuiz(req, res) {
  try {
    const userId = req.user.id;
    const lessonId = req.params.id;
    const userLanguage = req.user.language || "en";

    // Check if lesson is completed (required for quiz)
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
        .json({ error: "Lesson must be completed before taking quiz." });
    }

    // Get quiz questions
    const questions = await query(
      `
      SELECT * FROM quiz_questions WHERE lesson_id = ? ORDER BY id
    `,
      [lessonId]
    );

    const formattedQuestions = questions.map((q) => ({
      id: q.id,
      type: q.question_type,
      question: userLanguage === "vi" ? q.question_text_vi : q.question_text_en,
      romaji: q.romaji,
      options: [q.option_a, q.option_b, q.option_c, q.option_d].filter(Boolean),
      correct_answer: q.correct_answer,
      explanation: userLanguage === "vi" ? q.explanation_vi : q.explanation_en,
    }));

    return res.json(formattedQuestions);
  } catch (err) {
    console.error("[getLessonQuiz]", err);
    return res.status(500).json({ error: "Failed to load quiz questions." });
  }
}

// Submit quiz attempt
async function submitQuizAttempt(req, res) {
  try {
    const userId = req.user.id;
    const { lessonId, questionId, selectedAnswer, responseTimeMs } = req.body;

    // Get the correct answer
    const question = await query(
      `
      SELECT correct_answer FROM quiz_questions WHERE id = ?
    `,
      [questionId]
    );

    if (!question.length) {
      return res.status(404).json({ error: "Question not found." });
    }

    const isCorrect = question[0].correct_answer === selectedAnswer;

    // Record the attempt
    await query(
      `
      INSERT INTO user_quiz_attempts (user_id, lesson_id, question_id, selected_answer, is_correct, response_time_ms)
      VALUES (?, ?, ?, ?, ?, ?)
    `,
      [userId, lessonId, questionId, selectedAnswer, isCorrect, responseTimeMs]
    );

    return res.json({ is_correct: isCorrect });
  } catch (err) {
    console.error("[submitQuizAttempt]", err);
    return res.status(500).json({ error: "Failed to submit quiz attempt." });
  }
}

// Get quiz results for a lesson
async function getQuizResults(req, res) {
  try {
    const userId = req.user.id;
    const lessonId = req.params.id;
    const since = req.query.since
      ? new Date(parseInt(req.query.since, 10))
      : null;

    let attemptsSql = `
      SELECT uqa.*, qq.correct_answer
      FROM user_quiz_attempts uqa
      JOIN quiz_questions qq ON qq.id = uqa.question_id
      WHERE uqa.user_id = ? AND uqa.lesson_id = ?
    `;
    const attemptParams = [userId, lessonId];

    if (since && !Number.isNaN(since.getTime())) {
      attemptsSql += ` AND uqa.attempt_date >= ?`;
      attemptParams.push(since);
    }

    attemptsSql += ` ORDER BY uqa.attempt_date DESC`;

    const attempts = await query(attemptsSql, attemptParams);

    const totalQuestions = await query(
      `
      SELECT COUNT(*) as count FROM quiz_questions WHERE lesson_id = ?
    `,
      [lessonId]
    );

    const correctCount = attempts.filter((a) => a.is_correct).length;
    const totalAttempts = attempts.length;

    const accuracy =
      totalAttempts > 0 ? (correctCount / totalAttempts) * 100 : 0;

    return res.json({
      lesson_id: lessonId,
      total_questions: totalQuestions[0].count,
      correct_answers: correctCount,
      total_attempts: totalAttempts,
      accuracy: Math.round(accuracy * 100) / 100,
      attempts: attempts.slice(0, 25), // Last 25 attempts
    });
  } catch (err) {
    console.error("[getQuizResults]", err);
    return res.status(500).json({ error: "Failed to load quiz results." });
  }
}

// Save quiz session for stats
async function saveQuizSession(req, res) {
  try {
    const userId = req.user.id;
    const { sessionType, lessonId, totalQuestions, correctAnswers, accuracy } =
      req.body;

    await query(
      `INSERT INTO quiz_sessions (user_id, session_type, lesson_id, total_questions, correct_answers, accuracy)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        userId,
        sessionType,
        lessonId || null,
        totalQuestions,
        correctAnswers,
        accuracy,
      ]
    );

    return res.json({ success: true });
  } catch (err) {
    console.error("[saveQuizSession]", err);
    return res.status(500).json({ error: "Failed to save quiz session." });
  }
}

module.exports = {
  getChapters,
  getLesson,
  completeLesson,
  getLessonQuiz,
  submitQuizAttempt,
  getQuizResults,
  getReviewQuiz,
  saveQuizSession,
};
