// routes/stats.js
'use strict';
const router = require('express').Router();
const ctrl   = require('../controllers/statsController');
const { authenticate } = require('../middleware/auth');

router.get('/dashboard',    authenticate, ctrl.dashboard);
router.get('/weakest',      authenticate, ctrl.weakest);
router.get('/weekly',       authenticate, ctrl.weekly);
router.get('/time-of-day',  authenticate, ctrl.timeOfDay);
router.get('/performance',  authenticate, ctrl.characterPerformance);

module.exports = router;
