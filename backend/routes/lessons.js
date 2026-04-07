// routes/lessons.js
"use strict";
const router = require("express").Router();
const ctrl = require("../controllers/lessonController");
const structuredCtrl = require("../controllers/structuredLessonsController");
const { authenticate } = require("../middleware/auth");

router.get("/", structuredCtrl.getChapters);
router.get("/my", ctrl.myLessons);
router.get("/public", authenticate, ctrl.publicLessons);
router.get("/:id", authenticate, ctrl.getLessonById);
router.post("/", authenticate, ctrl.createLesson);
router.post("/:id/visibility", authenticate, ctrl.setVisibility);

module.exports = router;
