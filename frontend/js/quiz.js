// js/quiz.js — Full adaptive quiz engine (frontend) — FIXED
"use strict";

// ── State ────────────────────────────────────────────────────────
let quizState = {
  sessionId: null,
  questions: [],
  current: 0,
  answers: [],
  startTime: null,
  timerInterval: null,
  questionType: "",
  streakDisplay: 0,
};

const QUESTION_TIMEOUT_MS = 8000;

// ── Entry point ──────────────────────────────────────────────────

window.startQuiz = function (type = "") {
  quizState.questionType = type;
  showView("quiz");
  showQuizSection("lobby");

  // FIX: Update lobby title to reflect selected type
  const titleEl = document.getElementById("quiz-lobby-title");
  if (titleEl) {
    const typeLabels = {
      "": "Tất Cả",
      hiragana: "Hiragana", // FIXED: was "Higarana"
      katakana: "Katakana",
      kanji: "Kanji",
    };
    titleEl.textContent = `Phiên Luyện Tập — ${typeLabels[type] || "Tất Cả"}`;
  }
};

// ── Lobby ────────────────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  document
    .getElementById("btn-begin-quiz")
    ?.addEventListener("click", beginQuiz);
  document
    .getElementById("btn-retry")
    ?.addEventListener("click", () => showQuizSection("lobby"));
  document.getElementById("btn-view-stats")?.addEventListener("click", () => {
    showView("stats");
    window.loadStats?.();
  });
});

async function beginQuiz() {
  const size = parseInt(document.getElementById("quiz-size")?.value || "10");
  const type = quizState.questionType;

  console.log(`[beginQuiz] size=${size} type="${type}"`);

  try {
    let questionData = [];

    // ── ALWAYS try structured review quiz first (for hiragana/katakana modes)
    // For kanji or "all", use the adaptive engine which respects reading_kana
    if (type === "kanji" || type === "all" || type === "") {
      // Use adaptive quiz generator (returns correct_display already set)
      const params = new URLSearchParams({ size });
      if (type) params.set("type", type);
      const data = await api.get(`/quiz/generate?${params}`);
      quizState.sessionId = data.sessionId;
      quizState.questions = (data.questions || []).map(normalizeQuestion);
    } else {
      // hiragana / katakana: try review quiz first, fall back to generate
      const reviewParams = new URLSearchParams({ size });
      reviewParams.set("script", type);
      const reviewData = await api.get(
        `/structured-lessons/review-quiz?${reviewParams}`
      );

      if (Array.isArray(reviewData) && reviewData.length > 0) {
        quizState.sessionId = `review-${Date.now()}`;
        quizState.questions = reviewData.map((q) =>
          normalizeReviewQuestion(q, type)
        );
      } else {
        const params = new URLSearchParams({ size, type });
        const data = await api.get(`/quiz/generate?${params}`);
        quizState.sessionId = data.sessionId;
        quizState.questions = (data.questions || []).map(normalizeQuestion);
      }
    }

    if (!quizState.questions.length) {
      alert("Không có câu hỏi nào. Vui lòng thử lại sau.");
      return;
    }

    quizState.current = 0;
    quizState.answers = [];
    quizState.streakDisplay = 0;

    console.log(`[beginQuiz] loaded ${quizState.questions.length} questions`);
    showQuizSection("active");
    renderQuestion();
  } catch (err) {
    console.error("[beginQuiz] ERROR:", err);
    alert("Không thể tải câu hỏi. Máy chủ có thể chưa hoạt động.");
  }
}

/**
 * Normalize a question from /quiz/generate endpoint.
 * correct_display is already set by the backend following the rule:
 *   kanji → reading_kana,  hiragana/katakana → romaji
 */
function normalizeQuestion(q) {
  return {
    characterId: q.characterId,
    character: q.character,
    romaji: q.romaji,
    reading_kana: q.reading_kana,
    type: q.type,
    groupName: q.groupName,
    weaknessScore: q.weaknessScore,
    difficultyClass: q.difficultyClass || "medium",
    correct_display: q.correct_display || q.romaji || "",
    choices: q.choices || [],
  };
}

/**
 * Normalize a question from the structured review quiz endpoint.
 * For review questions, answers are always the option text itself.
 */
function normalizeReviewQuestion(q, scriptType) {
  const correctAnswer = q.correct_answer || "";
  return {
    characterId: q.id,
    character: q.question || q.kanji || q.hiragana || q.katakana || "？",
    romaji: q.romaji || "",
    type: "review",
    groupName: "",
    weaknessScore: 0,
    difficultyClass: "medium",
    correct_display: correctAnswer,
    choices: (q.options || []).map((option) => ({
      romaji: option,
      correct: option === correctAnswer,
    })),
  };
}

// ── Question rendering ───────────────────────────────────────────

function renderQuestion() {
  const q = quizState.questions[quizState.current];
  const idx = quizState.current;
  const tot = quizState.questions.length;

  if (!q) {
    finishQuiz();
    return;
  }

  // Progress
  const pct = (idx / tot) * 100;
  const fill = document.getElementById("quiz-progress-fill");
  if (fill) fill.style.width = `${pct}%`;
  setText("quiz-counter", `${idx + 1} / ${tot}`);

  // Streak
  const streakEl = document.getElementById("quiz-streak-display");
  if (streakEl) {
    streakEl.textContent =
      quizState.streakDisplay >= 2
        ? `🔥 ${quizState.streakDisplay} correct streak`
        : "";
  }

  // Type badge — FIX "Higarana" typo and use proper labels
  const typeBadgeMap = {
    hiragana: "Hiragana",
    katakana: "Katakana",
    kanji: "Kanji",
    review: "Ôn Tập",
    "": "Tất Cả",
  };
  setText("quiz-type-badge", typeBadgeMap[q.type] || q.type);

  // Character display
  const charEl = document.getElementById("quiz-character");
  if (charEl) {
    charEl.textContent = q.character || "？";
  }

  // Prompt text — adjust based on type
  const promptEl = document.getElementById("quiz-prompt");
  if (promptEl) {
    if (q.type === "kanji") {
      promptEl.textContent = "Cách đọc kana là gì?";
    } else {
      promptEl.textContent = "Romaji là gì?";
    }
  }

  // Render choices
  const choicesEl = document.getElementById("quiz-choices");
  if (choicesEl) {
    choicesEl.innerHTML = "";
    q.choices.forEach((choice) => {
      const btn = document.createElement("button");
      btn.className = "choice-btn";
      btn.textContent = choice.romaji; // "romaji" holds display value (kana or romaji)
      btn.dataset.display = choice.romaji;
      btn.dataset.correct = choice.correct ? "1" : "0";
      btn.addEventListener("click", () => handleAnswer(choice.romaji, btn));
      choicesEl.appendChild(btn);
    });
  }

  // Reset feedback
  const feedbackEl = document.getElementById("quiz-feedback");
  if (feedbackEl) {
    feedbackEl.className = "quiz-feedback hidden";
    feedbackEl.textContent = "";
  }

  // Reset card state
  const card = document.getElementById("quiz-card");
  if (card) card.classList.remove("correct", "incorrect");

  startQuestionTimer();
  quizState.startTime = Date.now();
}

// ── Answer handling ──────────────────────────────────────────────

function handleAnswer(selectedDisplay, clickedBtn) {
  if (!quizState.startTime) return; // already answered

  const responseTimeMs = Date.now() - quizState.startTime;
  quizState.startTime = null;
  stopQuestionTimer();

  const q = quizState.questions[quizState.current];

  // ── CRITICAL FIX: Compare display values (kana for kanji, romaji for kana)
  const isCorrect =
    (selectedDisplay || "").trim().toLowerCase() ===
    (q.correct_display || "").trim().toLowerCase();

  console.log(
    `[handleAnswer] type=${q.type} selected="${selectedDisplay}" correct="${q.correct_display}" → ${isCorrect}`
  );

  if (isCorrect) {
    quizState.streakDisplay++;
  } else {
    quizState.streakDisplay = 0;
  }

  // Disable buttons, highlight correct/wrong
  document.querySelectorAll(".choice-btn").forEach((btn) => {
    btn.disabled = true;
    if (btn.dataset.correct === "1") btn.classList.add("correct-ans");
  });
  if (!isCorrect) clickedBtn.classList.add("wrong-ans");

  const card = document.getElementById("quiz-card");
  if (card) card.classList.add(isCorrect ? "correct" : "incorrect");

  const feedbackEl = document.getElementById("quiz-feedback");
  if (feedbackEl) {
    feedbackEl.className = `quiz-feedback ${
      isCorrect ? "correct" : "incorrect"
    }`;
    feedbackEl.textContent = isCorrect
      ? `✓ Đúng! ${q.correct_display}`
      : `✗ Đáp án: "${q.correct_display}"`;
  }

  // Store answer — send the display value as choiceRomaji
  // Backend will re-derive correct answer from the same rule
  quizState.answers.push({
    characterId: q.characterId,
    choiceRomaji: selectedDisplay,
    responseTimeMs,
  });

  setTimeout(
    () => {
      quizState.current++;
      renderQuestion();
    },
    isCorrect ? 900 : 1500
  );
}

// ── Timer ────────────────────────────────────────────────────────

function startQuestionTimer() {
  stopQuestionTimer();
  const fill = document.getElementById("quiz-timer-fill");
  if (fill) {
    fill.style.transition = "none";
    fill.style.width = "100%";
    void fill.offsetWidth; // reflow
    fill.style.transition = `width ${QUESTION_TIMEOUT_MS}ms linear`;
    fill.style.width = "0%";
  }

  quizState.timerInterval = setTimeout(() => {
    if (!quizState.startTime) return;
    const q = quizState.questions[quizState.current];
    if (!q) return;

    quizState.answers.push({
      characterId: q.characterId,
      choiceRomaji: "__timeout__",
      responseTimeMs: QUESTION_TIMEOUT_MS,
    });
    quizState.startTime = null;
    quizState.streakDisplay = 0;

    document.querySelectorAll(".choice-btn").forEach((btn) => {
      btn.disabled = true;
      if (btn.dataset.correct === "1") btn.classList.add("correct-ans");
    });

    const feedbackEl = document.getElementById("quiz-feedback");
    if (feedbackEl) {
      feedbackEl.className = "quiz-feedback incorrect";
      feedbackEl.textContent = `⏱ Hết giờ! Đáp án: "${q.correct_display}"`;
    }

    setTimeout(() => {
      quizState.current++;
      renderQuestion();
    }, 1400);
  }, QUESTION_TIMEOUT_MS);
}

function stopQuestionTimer() {
  if (quizState.timerInterval) {
    clearTimeout(quizState.timerInterval);
    quizState.timerInterval = null;
  }
  const fill = document.getElementById("quiz-timer-fill");
  if (fill) {
    fill.style.transition = "none";
    fill.style.width = "100%";
  }
}

// ── Quiz finish ──────────────────────────────────────────────────

async function finishQuiz() {
  stopQuestionTimer();

  if (!quizState.answers.length) {
    showQuizSection("lobby");
    return;
  }

  try {
    const data = await api.post("/quiz/submit", {
      sessionId: quizState.sessionId,
      answers: quizState.answers,
    });

    // Save session summary
    const correctCount = data.results
      ? data.results.filter((r) => r.isCorrect).length
      : 0;
    await api
      .post("/structured-lessons/quiz/session", {
        sessionType: "quick-quiz",
        totalQuestions: data.results ? data.results.length : 0,
        correctAnswers: correctCount,
        accuracy: data.accuracy,
      })
      .catch((e) => console.warn("[finishQuiz] session save failed:", e));

    showQuizSection("results");
    renderResults(data);

    // Store for stats view
    window.instantStats = {
      source: `quick-quiz`,
      type: "quick-quiz",
      accuracy: data.accuracy,
      totalQuestions: data.results ? data.results.length : 0,
      correctAnswers: correctCount,
      wrongAnswers: (data.results ? data.results.length : 0) - correctCount,
      results: data.results || [],
      completedAt: new Date().toISOString(),
    };

    // Refresh user score in nav
    try {
      const { user } = await api.get("/auth/me");
      App.setAuth(App.token, user);
      updateNavUser?.();
    } catch (e) {
      console.warn("[finishQuiz] nav refresh failed:", e);
    }
  } catch (err) {
    console.error("[finishQuiz] submit failed:", err);
    showQuizSection("lobby");
  }
}

// ── Results rendering ────────────────────────────────────────────

function renderResults({ results, accuracy, sessionScore }) {
  setText("results-accuracy", `${accuracy}%`);
  setText("results-points", `+${sessionScore || 0} pts`);

  const correctCount = results ? results.filter((r) => r.isCorrect).length : 0;
  const incorrectCount = results
    ? results.filter((r) => !r.isCorrect).length
    : 0;

  const emojiEl = document.getElementById("results-emoji");
  if (emojiEl) {
    emojiEl.textContent =
      accuracy >= 90
        ? "🏆"
        : accuracy >= 70
        ? "🎯"
        : accuracy >= 50
        ? "💪"
        : "🌱";
  }

  const summaryEl = document.getElementById("results-summary");
  if (summaryEl) {
    summaryEl.innerHTML = `
      <div class="stats-summary">
        <div class="stat-item correct">
          <div class="stat-number">${correctCount}</div>
          <div class="stat-label">Đúng</div>
        </div>
        <div class="stat-item incorrect">
          <div class="stat-number">${incorrectCount}</div>
          <div class="stat-label">Sai</div>
        </div>
        <div class="stat-item total">
          <div class="stat-number">${accuracy}%</div>
          <div class="stat-label">Độ Chính Xác</div>
        </div>
      </div>
    `;
  }

  const breakdown = document.getElementById("results-breakdown");
  if (breakdown && results) {
    breakdown.innerHTML = results
      .map((r, idx) => {
        const q = quizState.questions.find(
          (q) => q.characterId === r.characterId
        );
        const charDisplay = q ? q.character : "?";
        return `
        <div class="result-row ${r.isCorrect ? "correct" : "incorrect"}">
          <span class="result-number">${idx + 1}.</span>
          <span class="result-char">${charDisplay}</span>
          <span class="result-romaji">${r.correctRomaji}</span>
          <span class="result-icon">${r.isCorrect ? "✓" : "✗"}</span>
          <span class="result-cls ${r.difficultyClass}">${
          r.difficultyClass
        }</span>
        </div>
      `;
      })
      .join("");
  }
}

// ── Section switcher ─────────────────────────────────────────────

function showQuizSection(section) {
  ["lobby", "active", "results"].forEach((s) => {
    const el = document.getElementById(`quiz-${s}`);
    if (el) el.classList.toggle("hidden", s !== section);
  });
}
