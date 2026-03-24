// routes/profile.js
"use strict";

const express = require("express");
const router = express.Router();
const { authenticate } = require("../middleware/auth");
const profileController = require("../controllers/profileController");

// All profile routes require authentication
router.use(authenticate);

router.get("/quiz-history", profileController.getQuizHistory);
router.get("/grade-breakdown", profileController.getGradeBreakdown);

module.exports = router;
