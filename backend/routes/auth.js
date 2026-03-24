// routes/auth.js
"use strict";
const router = require("express").Router();
const { body } = require("express-validator");
const ctrl = require("../controllers/authController");
const { authenticate } = require("../middleware/auth");

const registerRules = [
  body("username")
    .trim()
    .isLength({ min: 3, max: 30 })
    .withMessage("Username must be 3–30 chars."),
  body("email").isEmail().normalizeEmail(),
  body("password")
    .isLength({ min: 6 })
    .withMessage("Password must be at least 6 chars."),
];

const loginRules = [
  body("identifier").trim().notEmpty().withMessage("Identifier is required"),
  body("password").notEmpty().withMessage("Password is required"),
];

function validate(req, res, next) {
  const { validationResult } = require("express-validator");
  const errors = validationResult(req);
  if (!errors.isEmpty())
    return res.status(422).json({ errors: errors.array() });
  next();
}

router.post("/register", registerRules, validate, ctrl.register);
router.post("/login", loginRules, validate, ctrl.login);
router.get("/me", authenticate, ctrl.me);

module.exports = router;

console.log("AUTH ROUTE LOADED");
