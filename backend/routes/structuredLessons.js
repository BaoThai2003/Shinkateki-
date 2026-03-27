// routes/structuredLessons.js
"use strict";

const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const {
  getChapters,
  getLesson,
  completeLesson,
  getLessonQuiz,
  submitQuizAttempt,
  getQuizResults,
} = require("../controllers/structuredLessonsController");

// All routes require authentication
router.use(auth.authenticate);

// Get all chapters with sections and lessons
router.get("/chapters", getChapters);

// Get a specific lesson
router.get("/:id", getLesson);

// Mark lesson as completed
router.post("/:id/complete", completeLesson);

// Get quiz questions for a lesson
router.get("/:id/quiz", getLessonQuiz);

// Submit quiz attempt
router.post("/quiz/attempt", submitQuizAttempt);

// Get quiz results for a lesson
router.get("/:id/quiz/results", getQuizResults);

module.exports = router;
