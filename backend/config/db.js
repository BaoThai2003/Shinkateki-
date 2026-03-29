// config/db.js
"use strict";

const mysql = require("mysql2/promise");
require("dotenv").config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  port: parseInt(process.env.DB_PORT || "3306"),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "shinkateki",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  charset: "utf8mb4",
  timezone: "+07:00",
});

/**
 * query(sql, params) → rows[]
 */
async function query(sql, params = []) {
  const [rows] = await pool.execute(sql, params);
  return rows;
}

/**
 * queryOne
 */
async function queryOne(sql, params = []) {
  const rows = await query(sql, params);
  return rows[0] ?? null;
}

/**
 * transaction helper
 */
async function withTransaction(callback) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await callback(conn);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

//
//TEST CONNECTION + QUERY
//
async function testDB() {
  try {
    const conn = await pool.getConnection();
    console.log("MySQL connected successfully!");

    const [rows] = await conn.query("SELECT 1");
    console.log("Query OK:", rows);

    conn.release();
  } catch (err) {
    console.error("DB ERROR:", err.message);
  }
}

// chỉ chạy test khi KHÔNG phải production
if (process.env.NODE_ENV !== "production") {
  testDB();
}

module.exports = { pool, query, queryOne, withTransaction };
