// middleware/auth.js
// Validates Bearer JWT on protected routes
"use strict";

const jwt = require("jsonwebtoken");

function authenticate(req, res, next) {
  const header = req.headers["authorization"] || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: "No token provided." });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    // Attach user info so controllers can read req.user.id
    req.user = {
      id: payload.sub,
      username: payload.username,
      language: payload.language || "en",
    };
    next();
  } catch (err) {
    const msg =
      err.name === "TokenExpiredError" ? "Token expired." : "Invalid token.";
    return res.status(401).json({ error: msg });
  }
}

module.exports = { authenticate };
