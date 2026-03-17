// routes/quiz.js
'use strict';
const router = require('express').Router();
const ctrl   = require('../controllers/quizController');
const { authenticate } = require('../middleware/auth');

router.get('/generate', authenticate, ctrl.generateQuiz);
router.post('/submit',  authenticate, ctrl.submitAnswers);

module.exports = router;
