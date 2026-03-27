// routes/dictionary.js
"use strict";

const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const {
  getDictionary,
  getVocabularyByLesson,
  searchVocabulary,
} = require("../controllers/dictionaryController");

// All routes require authentication
router.use(auth.authenticate);

// Get all vocabulary from completed lessons
router.get("/", getDictionary);

// Search vocabulary
router.get("/search", searchVocabulary);

// Get vocabulary by lesson
router.get("/lesson/:lessonId", getVocabularyByLesson);

module.exports = router;
