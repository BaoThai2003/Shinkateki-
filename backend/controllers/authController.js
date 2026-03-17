"use strict";

const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { query, queryOne } = require("../config/db");

// ================= REGISTER =================
async function register(req, res) {
  try {
    const { username, email, password } = req.body;

    // Validate
    if (!username || !email || !password) {
      return res.status(422).json({ error: "Missing required fields." });
    }

    if (password.length < 6) {
      return res
        .status(422)
        .json({ error: "Password must be at least 6 characters." });
    }

    // Check duplicate
    const existing = await queryOne(
      `SELECT id FROM users WHERE username = ? OR email = ? LIMIT 1`,
      [username, email]
    );

    if (existing) {
      return res
        .status(409)
        .json({ error: "Username or email already taken." });
    }

    // Hash password
    const hash = await bcrypt.hash(password, 12);

    const result = await query(
      `INSERT INTO users (username, email, password_hash, level, total_score)
       VALUES (?, ?, ?, 1, 0)`,
      [username, email, hash]
    );

    const token = _issueToken(result.insertId, username);

    return res.status(201).json({
      message: "Account created.",
      token,
      user: {
        id: result.insertId,
        username,
        email,
        level: 1,
        total_score: 0,
      },
    });
  } catch (err) {
    console.error("[register]", err);
    return res.status(500).json({ error: "Registration failed." });
  }
}

// ================= LOGIN =================
//Cho phép login bằng username HOẶC email
async function login(req, res) {
  try {
    const { identifier, password } = req.body;

    // Validate
    if (!identifier || !password) {
      return res.status(422).json({ error: "Missing identifier or password." });
    }

    // Tìm user bằng username hoặc email
    const user = await queryOne(
      `SELECT id, username, email, password_hash, level, total_score
       FROM users
       WHERE username = ? OR email = ?`,
      [identifier, identifier]
    );

    if (!user) {
      return res.status(401).json({ error: "Invalid credentials." });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: "Invalid credentials." });
    }

    // Update last_active
    await query(`UPDATE users SET last_active = NOW() WHERE id = ?`, [user.id]);

    const token = _issueToken(user.id, user.username);

    return res.json({
      message: "Login successful.",
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        level: user.level,
        total_score: user.total_score,
      },
    });
  } catch (err) {
    console.error("[login]", err);
    return res.status(500).json({ error: "Login failed." });
  }
}

// ================= ME =================
async function me(req, res) {
  try {
    if (!req.user || !req.user.sub) {
      return res.status(401).json({ error: "Unauthorized." });
    }

    const user = await queryOne(
      `SELECT id, username, email, level, total_score, streak_days, last_active, created_at
       FROM users WHERE id = ?`,
      [req.user.sub]
    );

    if (!user) {
      return res.status(404).json({ error: "User not found." });
    }

    return res.json({ user });
  } catch (err) {
    console.error("[me]", err);
    return res.status(500).json({ error: "Failed to fetch profile." });
  }
}

// ================= TOKEN =================
function _issueToken(userId, username) {
  return jwt.sign(
    {
      sub: userId,
      username,
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || "7d",
    }
  );
}

module.exports = { register, login, me };
