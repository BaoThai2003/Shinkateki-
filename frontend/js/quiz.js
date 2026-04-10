// js/quiz.js — Full adaptive quiz engine (frontend)
"use strict";

// Use shared API helper from app.js (includes token, error handling)

// ── State ────────────────────────────────────────────────────────
let quizState = {
  sessionId: null,
  questions: [],
  current: 0,
  answers: [],
  startTime: null, // timestamp when current question was shown
  timerInterval: null,
  questionType: "",
  streakDisplay: 0,
};

const QUESTION_TIMEOUT_MS = 8000; // 8 s per question

// ── Entry point ──────────────────────────────────────────────────

window.startQuiz = function (type = "") {
  quizState.questionType = type;
  showView("quiz");
  showQuizSection("lobby");
};

// ── Lobby ────────────────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  document
    .getElementById("btn-begin-quiz")
    ?.addEventListener("click", beginQuiz);

  document.getElementById("btn-retry")?.addEventListener("click", () => {
    showQuizSection("lobby");
  });

  document.getElementById("btn-view-stats")?.addEventListener("click", () => {
    showView("stats");
    window.loadStats?.();
  });
});

async function beginQuiz() {
  const size = parseInt(document.getElementById("quiz-size")?.value || "10");
  const type = quizState.questionType;

  try {
    // Quick quiz: review-only pool (structured lessons review section)
    const params = new URLSearchParams({ size });
    if (type) params.set("script", type);

    let questionData = await api.get(
      `/structured-lessons/review-quiz?${params}`
    );

    if (!Array.isArray(questionData) || questionData.length === 0) {
      // fallback to adaptive general quiz
      const fallbackParams = new URLSearchParams({ size });
      if (type) fallbackParams.set("type", type);
      const data = await api.get(`/quiz/generate?${fallbackParams}`);
      quizState.sessionId = data.sessionId;
      quizState.questions = data.questions;
    } else {
      // map review quiz format into same question representation used by quiz engine
      quizState.sessionId = `review-${Date.now()}`;
      quizState.questions = questionData.map((q) => ({
        characterId: q.id,
        character: q.question || q.kanji || q.hiragana || q.katakana || "？",
        romaji: q.romaji || "",
        type: "review",
        choices: (q.options || []).map((option) => ({
          romaji: option,
          correct: option === q.correct_answer,
        })),
      }));
    }

    quizState.current = 0;
    quizState.answers = [];
    quizState.streakDisplay = 0;

    showQuizSection("active");
    renderQuestion();
  } catch (err) {
    alert("Could not load quiz. Is the server running?");
    console.error(err);
  }
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

  // Progress bar
  const pct = (idx / tot) * 100;
  const fill = document.getElementById("quiz-progress-fill");
  if (fill) fill.style.width = `${pct}%`;
  setText("quiz-counter", `${idx + 1} / ${tot}`);

  // Streak indicator
  const streakEl = document.getElementById("quiz-streak-display");
  if (streakEl) {
    streakEl.textContent =
      quizState.streakDisplay >= 2
        ? `🔥 ${quizState.streakDisplay} correct streak`
        : "";
  }

  // Card content
  setText("quiz-type-badge", q.type);

  // Some character payloads may be HTML-encoded or in incorrect encoding path.
  // If we get non-Japanese text here, fallback to a romaji->kana mapper.
  const labelCharacter = /^[\u3040-\u30FF\u4E00-\u9FFF]+$/.test(q.character)
    ? q.character
    : romajiToKana(q.romaji) || q.character;
  setText("quiz-character", labelCharacter);

  // Choices
  const choicesEl = document.getElementById("quiz-choices");
  if (choicesEl) {
    choicesEl.innerHTML = "";
    q.choices.forEach((choice) => {
      const btn = document.createElement("button");
      btn.className = "choice-btn";
      btn.textContent = choice.romaji;
      btn.dataset.romaji = choice.romaji;
      btn.dataset.correct = choice.correct ? "1" : "0";
      btn.addEventListener("click", () => handleAnswer(choice.romaji, btn));
      choicesEl.appendChild(btn);
    });
  }

  // Hide feedback
  const feedbackEl = document.getElementById("quiz-feedback");
  if (feedbackEl) {
    feedbackEl.className = "quiz-feedback hidden";
    feedbackEl.textContent = "";
  }

  // Remove card state classes
  const card = document.getElementById("quiz-card");
  if (card) card.classList.remove("correct", "incorrect");

  // Start timer
  startQuestionTimer();

  // Record question start time for response-time measurement
  quizState.startTime = Date.now();
}

// ── Answer handling ──────────────────────────────────────────────

function handleAnswer(selectedRomaji, clickedBtn) {
  if (!quizState.startTime) return; // already answered

  const responseTimeMs = Date.now() - quizState.startTime;
  quizState.startTime = null;
  stopQuestionTimer();

  const q = quizState.questions[quizState.current];
  const isCorrect =
    selectedRomaji.toLowerCase() === q.correct_display.toLowerCase();

  // Update streak display
  if (isCorrect) {
    quizState.streakDisplay++;
  } else {
    quizState.streakDisplay = 0;
  }

  // Disable all buttons
  document.querySelectorAll(".choice-btn").forEach((btn) => {
    btn.disabled = true;
    if (btn.dataset.correct === "1") btn.classList.add("correct-ans");
  });
  if (!isCorrect) clickedBtn.classList.add("wrong-ans");

  // Card visual state
  const card = document.getElementById("quiz-card");
  if (card) card.classList.add(isCorrect ? "correct" : "incorrect");

  // Feedback message
  const feedbackEl = document.getElementById("quiz-feedback");
  if (feedbackEl) {
    feedbackEl.className = `quiz-feedback ${
      isCorrect ? "correct" : "incorrect"
    }`;
    feedbackEl.textContent = isCorrect
      ? `✓ Correct! ${q.correct_display}`
      : `✗ It was "${q.correct_display}"`;
  }

  // Store answer for batch submit
  quizState.answers.push({
    characterId: q.characterId,
    choiceRomaji: selectedRomaji,
    responseTimeMs,
  });

  // Advance after a brief pause
  setTimeout(
    () => {
      quizState.current++;
      renderQuestion();
    },
    isCorrect ? 900 : 1500
  );
}

// ── Timer ─────────────────────────────────────────────────────────

function startQuestionTimer() {
  stopQuestionTimer();

  const fill = document.getElementById("quiz-timer-fill");
  const start = Date.now();

  if (fill) fill.style.transition = "none";
  if (fill) fill.style.width = "100%";

  // Force reflow so CSS transition applies
  if (fill) void fill.offsetWidth;
  if (fill) {
    fill.style.transition = `width ${QUESTION_TIMEOUT_MS}ms linear`;
    fill.style.width = "0%";
  }

  quizState.timerInterval = setTimeout(() => {
    // Auto-submit as wrong with max response time if user doesn't answer
    if (quizState.startTime) {
      const q = quizState.questions[quizState.current];
      if (q) {
        quizState.answers.push({
          characterId: q.characterId,
          choiceRomaji: "__timeout__",
          responseTimeMs: QUESTION_TIMEOUT_MS,
        });
        quizState.startTime = null;
        quizState.streakDisplay = 0;

        // Show correct answer
        document.querySelectorAll(".choice-btn").forEach((btn) => {
          btn.disabled = true;
          if (btn.dataset.correct === "1") btn.classList.add("correct-ans");
        });
        const feedbackEl = document.getElementById("quiz-feedback");
        if (feedbackEl) {
          feedbackEl.className = "quiz-feedback incorrect";
          feedbackEl.textContent = `⏱ Time's up! Answer: "${q.romaji}"`;
        }

        setTimeout(() => {
          quizState.current++;
          renderQuestion();
        }, 1400);
      }
    }
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

// ── Quiz finish ───────────────────────────────────────────────────

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

    // Save quiz session
    await api.post("/structured-lessons/quiz/session", {
      sessionType: "quick-quiz",
      totalQuestions: data.results ? data.results.length : 0,
      correctAnswers: data.results
        ? data.results.filter((r) => r.isCorrect).length
        : 0,
      accuracy: data.accuracy,
    });

    showQuizSection("results");
    renderResults(data);

    // Instant stats for quick quiz
    window.instantStats = {
      source: `quick-quiz-${data.sessionId || Date.now()}`,
      type: "quick-quiz",
      accuracy: data.accuracy,
      totalQuestions: data.results ? data.results.length : 0,
      correctAnswers: data.results
        ? data.results.filter((r) => r.isCorrect).length
        : 0,
      wrongAnswers: data.results
        ? data.results.filter((r) => !r.isCorrect).length
        : 0,
      results: data.results || [],
      completedAt: new Date().toISOString(),
    };

    // Refresh nav score and home data
    try {
      const { user } = await api.get("/auth/me");
      App.setAuth(App.token, user);
      updateNavUser();
      window.loadHomeData?.();

      // If stats view is currently visible, refresh it too
      if (
        document.getElementById("view-stats") &&
        !document.getElementById("view-stats").classList.contains("hidden")
      ) {
        window.loadStats?.();
      }

      // Update result area from latest stats (minor user feedback)
      const miniAccuracy = document.getElementById("ms-accuracy");
      const miniAttempts = document.getElementById("ms-attempts");
      if (miniAccuracy && miniAttempts) {
        miniAccuracy.textContent = `${data.accuracy}%`;
        miniAttempts.textContent = `${data.results.length || 0}`;
      }
    } catch (e) {
      console.warn("Could not refresh stats after quiz:", e);
    }
  } catch (err) {
    console.error("Submit failed", err);
    showQuizSection("lobby");
  }
}

// ── Results rendering ─────────────────────────────────────────────

function renderResults({ results, accuracy, sessionScore }) {
  // Score header
  setText("results-accuracy", `${accuracy}%`);
  setText("results-points", `+${sessionScore || 0} pts`);

  // Calculate counts
  const correctCount = results ? results.filter((r) => r.isCorrect).length : 0;
  const incorrectCount = results
    ? results.filter((r) => !r.isCorrect).length
    : 0;
  const totalCount = results ? results.length : 0;

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

  // Summary stats
  const summaryEl = document.getElementById("results-summary");
  if (summaryEl) {
    summaryEl.innerHTML = `
      <div class="stats-summary">
        <div class="stat-item correct">
          <div class="stat-number">${correctCount}</div>
          <div class="stat-label">Correct</div>
        </div>
        <div class="stat-item incorrect">
          <div class="stat-number">${incorrectCount}</div>
          <div class="stat-label">Incorrect</div>
        </div>
        <div class="stat-item total">
          <div class="stat-number">${accuracy}%</div>
          <div class="stat-label">Accuracy</div>
        </div>
      </div>
    `;
  }

  // Per-question breakdown
  const breakdown = document.getElementById("results-breakdown");
  if (breakdown && results) {
    breakdown.innerHTML = results
      .map(
        (r, idx) => `
      <div class="result-row ${r.isCorrect ? "correct" : "incorrect"}">
        <span class="result-number">${idx + 1}.</span>
        <span class="result-char">${_charFromId(r.characterId) || "?"}</span>
        <span class="result-romaji">${r.correctRomaji}</span>
        <span class="result-icon">${r.isCorrect ? "✓" : "✗"}</span>
        <span class="result-cls ${r.difficultyClass}">${
          r.difficultyClass
        }</span>
      </div>
    `
      )
      .join("");
  }
}

// Map characterId → character glyph from loaded questions
function _charFromId(id) {
  const q = quizState.questions.find((q) => q.characterId === id);
  return q?.character || "";
}

function romajiToKana(romaji) {
  const map = {
    a: "あ",
    i: "い",
    u: "う",
    e: "え",
    o: "お",
    ka: "か",
    ki: "き",
    ku: "く",
    ke: "け",
    ko: "こ",
    sa: "さ",
    shi: "し",
    su: "す",
    se: "せ",
    so: "そ",
    ta: "た",
    chi: "ち",
    tsu: "つ",
    te: "て",
    to: "と",
    na: "な",
    ni: "に",
    nu: "ぬ",
    ne: "ね",
    no: "の",
    ha: "は",
    hi: "ひ",
    fu: "ふ",
    he: "へ",
    ho: "ほ",
    ma: "ま",
    mi: "み",
    mu: "む",
    me: "め",
    mo: "も",
    ya: "や",
    yu: "ゆ",
    yo: "よ",
    ra: "ら",
    ri: "り",
    ru: "る",
    re: "れ",
    ro: "ろ",
    wa: "わ",
    wo: "を",
    n: "ん",
    // Katakana not mapped, but can be extended as needed
  };
  return map[romaji.toLowerCase()] || null;
}

// ── Section switcher ──────────────────────────────────────────────

function showQuizSection(section) {
  ["lobby", "active", "results"].forEach((s) => {
    const el = document.getElementById(`quiz-${s}`);
    if (el) el.classList.toggle("hidden", s !== section);
  });
}
