// routes/lessons.js
"use strict";
const router = require("express").Router();
const ctrl = require("../controllers/lessonController");
const { authenticate } = require("../middleware/auth");

router.get("/my", authenticate, ctrl.myLessons);
router.get("/public", authenticate, ctrl.publicLessons);
router.get("/:id", authenticate, ctrl.getLessonById);
router.post("/", authenticate, ctrl.createLesson);
router.post("/:id/visibility", authenticate, ctrl.setVisibility);

module.exports = router;
