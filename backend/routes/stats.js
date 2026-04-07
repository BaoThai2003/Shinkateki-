// routes/stats.js
"use strict";
const router = require("express").Router();
const ctrl = require("../controllers/statsController");
const { authenticate } = require("../middleware/auth");

router.get("/", ctrl.dashboard);
router.get("/dashboard", ctrl.dashboard);
router.get("/weakest", authenticate, ctrl.weakest);
router.get("/weekly", authenticate, ctrl.weekly);
router.get("/time-of-day", authenticate, ctrl.timeOfDay);
router.get("/performance", authenticate, ctrl.characterPerformance);
router.get("/quiz-history", authenticate, ctrl.quizHistory);

module.exports = router;
