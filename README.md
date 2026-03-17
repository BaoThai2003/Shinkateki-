# 進化的 Shinkateki — Adaptive Japanese Learning System

> *Shinkateki (進化的) means "evolutionary" in Japanese.*  
> A full-stack adaptive learning platform that analyzes your behaviour  
> and dynamically adjusts every quiz to make you stronger, faster.

---

## Architecture Overview

```
shinkateki/
├── backend/
│   ├── app.js                        ← Express server entry point
│   ├── config/
│   │   └── db.js                     ← MySQL connection pool + helpers
│   ├── middleware/
│   │   └── auth.js                   ← JWT Bearer token validation
│   ├── routes/
│   │   ├── auth.js                   ← POST /register, /login · GET /me
│   │   ├── quiz.js                   ← GET /generate · POST /submit
│   │   └── stats.js                  ← GET /dashboard, /weakest, /weekly, etc.
│   ├── controllers/
│   │   ├── authController.js         ← Register, login, profile
│   │   ├── quizController.js         ← Generate adaptive quiz, submit answers
│   │   └── statsController.js        ← Analytics endpoints
│   └── services/
│       ├── adaptiveEngine.js         ← ★ Core algorithm (weakness score, quiz gen, SR)
│       └── behaviorAnalysis.js       ← ★ Time-of-day, velocity, recommendations
├── frontend/
│   ├── index.html
│   ├── css/style.css                 ← Ink-wash dark Japanese aesthetic
│   └── js/
│       ├── app.js                    ← API client, view router, home data
│       ├── auth.js                   ← Login / register forms
│       ├── quiz.js                   ← Quiz flow, timer, answer handling
│       └── stats.js                  ← Charts, weakness grid, velocity
└── database/
    └── schema.sql                    ← Full MySQL schema + seed data
```

---

## Database Design

```
users                     characters
─────────────────         ──────────────────────────
id (PK)                   id (PK)
username (UNIQUE)         character  (e.g. "あ")
email    (UNIQUE)         romaji     (e.g. "a")
password_hash             type       hiragana|katakana
level                     group_name (vowels, k-row…)
total_score               difficulty (1–5 base)
streak_days
last_active

attempts                  performance_stats
──────────────────        ──────────────────────────
id (PK)                   user_id  + character_id  (PK)
user_id   → users         weakness_score  FLOAT
character_id → characters difficulty_class strong|medium|weak
is_correct                correct_count
response_time (ms)        wrong_count
mistake_streak            avg_response_ms
hour_of_day               mistake_streak
session_id (UUID)         last_reviewed
created_at                next_review   ← spaced repetition

time_of_day_stats
──────────────────────────
user_id + hour_slot (PK)
total_attempts
correct_count
avg_response_ms
accuracy_rate  (0.0–1.0)
```

---

## The Adaptive Algorithm

### 1 · Weakness Score

After every answer the engine computes a new score using an **exponential moving average** — recent behaviour dominates but history is never forgotten:

```
contribution  = (wrong × 2) + (response_time_sec) + (mistake_streak × 3)
new_score     = old_score × 0.6  +  contribution × 0.4
```

| Score range | Classification |
|-------------|---------------|
| 0 – 3       | ✅ Strong      |
| 4 – 8       | 🟡 Medium      |
| > 8         | 🔴 Weak        |

### 2 · Adaptive Quiz Distribution

```
70% questions  ←  Weak   characters
20% questions  ←  Medium characters
10% questions  ←  Strong characters  (maintenance)
```

Within each bucket, **due-for-review** characters are served first (spaced repetition priority queue).

### 3 · Spaced Repetition

```
Weak   → next_review = NOW + 5 minutes
Medium → next_review = NOW + 1 day
Strong → next_review = NOW + 3 days
```

### 4 · Compassion Mode

If any character reaches **5+ consecutive mistakes**, the engine detects it and temporarily reshuffles the quiz:

```
80% easy (strong/medium)  ←  rebuild confidence
20% weak                  ←  still push gently
```

### 5 · Time-of-Day Analysis

Every attempt records the UTC hour. The `time_of_day_stats` table maintains rolling accuracy averages per slot. The dashboard highlights the user's **statistically best learning window**.

### 6 · Learning Velocity

Compares early-session accuracy vs recent-session accuracy to produce an improvement trend: `improving`, `stable`, or `declining`.

---

## REST API Reference

### Auth
| Method | Endpoint             | Auth | Description         |
|--------|----------------------|------|---------------------|
| POST   | /api/auth/register   | —    | Create account      |
| POST   | /api/auth/login      | —    | Get JWT token       |
| GET    | /api/auth/me         | ✓    | Current user info   |

### Quiz
| Method | Endpoint             | Auth | Description                     |
|--------|----------------------|------|---------------------------------|
| GET    | /api/quiz/generate   | ✓    | Generate adaptive quiz          |
| POST   | /api/quiz/submit     | ✓    | Submit answers, update engine   |

**GET /api/quiz/generate** query params:
- `size` — number of questions (default 10, max 30)
- `type` — `hiragana` | `katakana` | (omit for both)

**POST /api/quiz/submit** body:
```json
{
  "sessionId": "uuid",
  "answers": [
    { "characterId": 1, "choiceRomaji": "a", "responseTimeMs": 1200 }
  ]
}
```

### Stats
| Method | Endpoint              | Auth | Description                  |
|--------|-----------------------|------|------------------------------|
| GET    | /api/stats/dashboard  | ✓    | Full analytics dashboard     |
| GET    | /api/stats/weakest    | ✓    | Weakest characters list      |
| GET    | /api/stats/weekly     | ✓    | Daily accuracy last N days   |
| GET    | /api/stats/time-of-day| ✓    | Per-hour-slot performance    |
| GET    | /api/stats/performance| ✓    | Paginated character stats    |

---

## Setup & Running

### Prerequisites
- Node.js 18+
- MySQL 8+

### 1. Database
```bash
mysql -u root -p < database/schema.sql
```

### 2. Backend
```bash
cd backend
cp .env.example .env
# edit .env — set DB_PASSWORD and JWT_SECRET
npm install
npm run dev
# → http://localhost:3000
```

### 3. Frontend
Open `frontend/index.html` in a browser, or serve it:
```bash
npx serve frontend
# → http://localhost:3000  (or whatever port serve picks)
```

---

## Development Roadmap

| Level | Status | Features |
|-------|--------|---------|
| 1 | ✅ Done | Quiz system, attempt storage, JWT auth |
| 2 | ✅ Done | Weakness Score algorithm, adaptive distribution |
| 3 | ✅ Done | Spaced repetition, compassion mode |
| 4 | ✅ Done | Time-of-day analysis, velocity, recommendations |
| 5 | 🔜 Next | Kanji module, vocabulary, sentence building |

### Level 5 Ideas
- Add a `vocabulary` table (words → kanji + readings)
- Sentence-level cloze exercises
- Streak calendar (GitHub-style heat map)
- WebSocket live multiplayer quiz mode
- Export progress report as PDF

---

## Key Design Decisions

**Exponential Moving Average over simple counters**  
A raw average would weigh your first-ever answer the same as today's. The 0.6/0.4 EMA means the last 5 sessions dominate the score — much more representative of *current* ability.

**Per-attempt `mistake_streak` stored in attempts table**  
This lets you replay the exact state the algorithm was in at any historical point — useful for debugging or auditing the engine.

**`session_id` UUID on every attempt**  
Allows session-level analytics later (e.g. "Did users who practiced in the morning have longer sessions?") without schema changes.

**Single HTML + vanilla JS frontend**  
No build tooling required. The backend is the interesting part — the frontend is intentionally simple so you can replace it with React when ready.
