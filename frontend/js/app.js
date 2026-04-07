// js/app.js — Shinkateki core: API client + view router
"use strict";

// ── Configuration ────────────────────────────────────────────────
const API_BASE = "http://localhost:8004/api";

// ── Shared Application State ─────────────────────────────────────
window.App = {
  token: localStorage.getItem("token"),
  user: JSON.parse(localStorage.getItem("user") || "null"),
  language: "en", // default language

  setAuth(token, user) {
    this.token = token;
    this.user = user;
    this.language = user.language || "en";
    localStorage.setItem("token", token);
    localStorage.setItem("user", JSON.stringify(user));
  },

  clearAuth() {
    this.token = null;
    this.user = null;
    this.language = "en";
    localStorage.removeItem("token");
    localStorage.removeItem("user");
  },

  isLoggedIn() {
    return !!this.token;
  },

  setLanguage(language) {
    this.language = language;
    if (this.user) {
      this.user.language = language;
      localStorage.setItem("user", JSON.stringify(this.user));
    }
  },
};

// ── API Helper ───────────────────────────────────────────────────

window.api = {
  async request(method, path, body = null) {
    const opts = {
      method,
      headers: { "Content-Type": "application/json" },
    };
    if (App.token) opts.headers["Authorization"] = `Bearer ${App.token}`;
    if (body) opts.body = JSON.stringify(body);

    const res = await fetch(`${API_BASE}${path}`, opts);
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      throw Object.assign(new Error(data.error || "Request failed"), {
        status: res.status,
        data,
      });
    }
    return data;
  },

  get(path) {
    return this.request("GET", path);
  },
  post(path, body) {
    return this.request("POST", path, body);
  },
};

// ── View Router ──────────────────────────────────────────────────

function showScreen(id) {
  ["loading-screen", "auth-screen", "app-screen"].forEach((s) => {
    const el = document.getElementById(s);
    if (el) el.classList.toggle("hidden", s !== id);
  });
}

function showView(name) {
  document.querySelectorAll(".view").forEach((v) => v.classList.add("hidden"));
  const target = document.getElementById(`view-${name}`);
  if (target) target.classList.remove("hidden");

  document.querySelectorAll(".nav-btn").forEach((b) => {
    b.classList.toggle("active", b.dataset.view === name);
  });

  if (
    name === "home" ||
    name === "quiz" ||
    name === "stats" ||
    name === "profile" ||
    name === "lessons"
  ) {
    setRandomBackground();
  }
}

// ── Bootstrap ────────────────────────────────────────────────────

function setRandomBackground() {
  const palettes = [
    ["#2b2d42", "#8d99ae"],
    ["#011627", "#2ec4b6"],
    ["#0b3c5d", "#328cc1"],
    ["#2a2e45", "#6e5773"],
    ["#1a1f3b", "#bfb1d2"],
    ["#0f172a", "#7c3aed"],
    ["#132f4c", "#fcc419"],
    ["#2a2231", "#ef8354"],
  ];

  const c = palettes[Math.floor(Math.random() * palettes.length)];
  document.body.style.background = `linear-gradient(135deg, ${c[0]}, ${c[1]})`;
}

document.addEventListener("DOMContentLoaded", async () => {
  setRandomBackground();

  // Let loading animation play
  await delay(2000);

  if (App.isLoggedIn()) {
    try {
      // Verify token still valid
      const { user } = await api.get("/auth/me");
      App.setAuth(App.token, user);
      enterApp();
    } catch {
      App.clearAuth();
      showScreen("auth-screen");
    }
  } else {
    showScreen("auth-screen");
  }
});

// Called after successful login/register
window.enterApp = function () {
  showScreen("app-screen");
  updateNavUser();
  showView("home");
  loadHomeData();
};

function updateNavUser() {
  const u = App.user;
  if (!u) return;
  document.getElementById("nav-username").textContent = u.username;
  document.getElementById("nav-score").textContent = `${
    u.total_score ?? 0
  } pts`;
  document.getElementById("hero-username").textContent = u.username;
  document.getElementById("hero-greeting").textContent = timeGreeting();
}

function timeGreeting() {
  const h = new Date().getHours();
  if (h < 5) return "おやすみ";
  if (h < 12) return "おはよう";
  if (h < 17) return "こんにちは";
  return "こんばんは";
}

// ── Home data ────────────────────────────────────────────────────

async function loadHomeData() {
  try {
    const dash = await api.get("/stats/dashboard");
    const { overall, optimalStudyTime, recommendations } = dash;

    // Mini stats
    setText("ms-accuracy", `${overall.overallAccuracy}%`);
    setText("ms-mastered", overall.masteredCount);
    setText("ms-attempts", overall.totalAttempts);

    // Optimal study time
    const otDiv = document.getElementById("optimal-time-display");
    if (optimalStudyTime) {
      otDiv.innerHTML = `
        <div class="ot-time">${_hourLabel(optimalStudyTime.hour)}</div>
        <div class="ot-label">${optimalStudyTime.label}</div>
        <div class="ot-accuracy">${optimalStudyTime.accuracy}% accuracy</div>
      `;
    }

    // Recommendations
    const recList = document.getElementById("recommendations-list");
    recList.innerHTML = recommendations
      .map((r) => `<div class="rec-item ${r.type}">${r.text}</div>`)
      .join("");

    // Public lessons on homepage
    const publicLessons = await api.get("/lessons/public");
    const publicList = document.getElementById("public-lessons-list");
    if (publicLessons && publicList) {
      publicList.innerHTML = publicLessons.length
        ? publicLessons
            .slice(0, 3)
            .map(
              (l) =>
                `<div class='public-lesson'><strong>${escapeHtml(
                  l.title
                )}</strong><p>${escapeHtml(l.content)}</p></div>`
            )
            .join("")
        : `<p style='color:var(--fog)'>No public lessons yet.</p>`;
    }
  } catch (err) {
    console.warn("Home data load failed", err);
  }
}
function _safeOpenLesson(lessonId) {
  if (!lessonId) return;
  openCustomLesson(lessonId);
}

function _hourLabel(hour) {
  const ampm = hour >= 12 ? "PM" : "AM";
  const h12 = hour % 12 || 12;
  return `${h12}:00 ${ampm}`;
}

// ── Lesson support ───────────────────────────────────────────────

function formatLessonCard(lesson) {
  const visibility = lesson.is_public ? "Public" : "Private";
  return `
    <div class="lesson-item" data-lesson-id="${
      lesson.id
    }" onclick="_safeOpenLesson(${lesson.id})">
      <h4>${escapeHtml(lesson.title)}</h4>
      <p>${escapeHtml(lesson.content)}</p>
      <p><strong>Questions:</strong> ${lesson.question_count}</p>
      <p><strong>Visibility:</strong> ${visibility}</p>
      <div class="lesson-actions-inline">
        <button class="btn-ghost btn-open-lesson" data-id="${
          lesson.id
        }">Open</button>
        <button class="btn-ghost btn-toggle-visibility" data-id="${
          lesson.id
        }" data-visible="${lesson.is_public ? "true" : "false"}">
          Set ${lesson.is_public ? "Private" : "Public"}
        </button>
      </div>
    </div>
  `;
}

function renderLessonForms(questions = []) {
  const container = document.getElementById("question-form-list");
  if (!container) return;

  if (!questions.length) {
    questions = [createBlankQuestion()];
  }

  container.innerHTML = questions
    .map((q, i) => {
      return `
      <div class="lesson-question-card" data-index="${i}">
        <div class="question-card-header">
          <h5>Question ${i + 1}</h5>
          <button type="button" class="btn-delete-question" data-index="${i}" title="Delete question">✕</button>
        </div>
        <textarea class="question-text" placeholder="Enter question text here..." rows="3">${escapeHtml(
          q.questionText
        )}</textarea>
        <div class="options-grid">
          <div class="option-row">
            <input type="text" class="option-val" value="${escapeHtml(
              q.options[0]
            )}" placeholder="Option A" />
            <label class="radio-label"><input type="radio" name="correct-${i}" value="0" ${
        q.correctIndex === 0 ? "checked" : ""
      }/> Correct</label>
          </div>
          <div class="option-row">
            <input type="text" class="option-val" value="${escapeHtml(
              q.options[1]
            )}" placeholder="Option B" />
            <label class="radio-label"><input type="radio" name="correct-${i}" value="1" ${
        q.correctIndex === 1 ? "checked" : ""
      }/> Correct</label>
          </div>
          <div class="option-row">
            <input type="text" class="option-val" value="${escapeHtml(
              q.options[2]
            )}" placeholder="Option C" />
            <label class="radio-label"><input type="radio" name="correct-${i}" value="2" ${
        q.correctIndex === 2 ? "checked" : ""
      }/> Correct</label>
          </div>
          <div class="option-row">
            <input type="text" class="option-val" value="${escapeHtml(
              q.options[3]
            )}" placeholder="Option D" />
            <label class="radio-label"><input type="radio" name="correct-${i}" value="3" ${
        q.correctIndex === 3 ? "checked" : ""
      }/> Correct</label>
          </div>
        </div>
      </div>
      `;
    })
    .join("");

  // Attach delete button handlers
  container.querySelectorAll(".btn-delete-question").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      const idx = parseInt(btn.dataset.index, 10);
      const allCards = Array.from(
        document.querySelectorAll(".lesson-question-card")
      );
      if (allCards.length <= 1) {
        alert("You must have at least one question.");
        return;
      }
      const currentQuestions = allCards
        .map((card, cardIdx) => {
          if (cardIdx === idx) return null;
          return {
            questionText: card.querySelector(".question-text").value,
            options: Array.from(card.querySelectorAll(".option-val")).map(
              (inp) => inp.value
            ),
            correctIndex: parseInt(
              card.querySelector(`input[name='correct-${cardIdx}']:checked`)
                ?.value || 0,
              10
            ),
          };
        })
        .filter((q) => q !== null);
      renderLessonForms(currentQuestions);
    });
  });
}

function createBlankQuestion() {
  return {
    questionText: "",
    options: ["", "", "", ""],
    correctIndex: 0,
  };
}

function applyTextFormat(format) {
  const textarea = document.getElementById("lesson-content");
  if (!textarea) return;

  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  const selectedText = textarea.value.substring(start, end);

  if (!selectedText) return;

  let formattedText = selectedText;
  switch (format) {
    case "bold":
      formattedText = `**${selectedText}**`;
      break;
    case "italic":
      formattedText = `*${selectedText}*`;
      break;
    case "underline":
      formattedText = `__${selectedText}__`;
      break;
    case "large":
      formattedText = `# ${selectedText}`;
      break;
    case "medium":
      formattedText = `## ${selectedText}`;
      break;
    case "small":
      formattedText = `### ${selectedText}`;
      break;
  }

  const newValue =
    textarea.value.substring(0, start) +
    formattedText +
    textarea.value.substring(end);
  textarea.value = newValue;
  textarea.focus();
  textarea.setSelectionRange(
    start + formattedText.length,
    start + formattedText.length
  );
}

async function loadLessons() {
  try {
    const myLessons = await api.get("/lessons/my");
    const publicLessons = await api.get("/lessons/public");

    const lessonGrid = document.getElementById("lesson-grid");
    lessonGrid.innerHTML = myLessons.length
      ? myLessons.map(formatLessonCard).join("")
      : "<p style='color:var(--fog)'>No lessons yet. Create one to get started.</p>";

    document.getElementById("public-lessons-list").innerHTML =
      publicLessons.length
        ? publicLessons
            .map(
              (l) =>
                `<div class='public-lesson'><strong>${escapeHtml(
                  l.title
                )}</strong><p>${escapeHtml(l.content)}</p></div>`
            )
            .join("")
        : "<p style='color:var(--fog)'>No public lessons yet.</p>";

    document.querySelectorAll(".btn-open-lesson").forEach((btn) => {
      btn.addEventListener("click", () => {
        const lessonId = btn.dataset.id;
        openCustomLesson(lessonId);
      });
    });

    document.querySelectorAll(".btn-toggle-visibility").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const lessonId = btn.dataset.id;
        const currentlyPublic = btn.dataset.visible === "true";
        await api.post(`/lessons/${lessonId}/visibility`, {
          isPublic: !currentlyPublic,
        });
        loadLessons();
      });
    });
  } catch (err) {
    console.error("Lessons loading failed", err);
  }
}

async function openCustomLesson(lessonId) {
  try {
    const lesson = await api.get(`/lessons/${lessonId}`);
    if (!lesson) throw new Error("Lesson not found.");

    showView("lesson");
    document.getElementById("lesson-title").textContent = lesson.title;
    document.getElementById("lesson-content").innerHTML = lesson.content;

    const actionsEl = document.getElementById("lesson-actions");
    actionsEl.innerHTML = "";

    if (lesson.questions && lesson.questions.length) {
      actionsEl.innerHTML = `
        <button class="btn-primary" onclick="startCustomLessonQuiz()">Start Quiz</button>
      `;
      window.customLessonQuiz = {
        lessonId: lesson.id,
        questions: lesson.questions,
        currentIndex: 0,
        answers: [],
      };
    } else {
      actionsEl.innerHTML = `<p style='color:var(--fog)'>No quiz questions available for this lesson.</p>`;
      window.customLessonQuiz = null;
    }
  } catch (err) {
    console.error("Failed to open lesson:", err);
    alert("Failed to open lesson. Please try again.");
  }
}

function startCustomLessonQuiz() {
  if (!window.customLessonQuiz || !window.customLessonQuiz.questions.length) {
    alert("No quiz available.");
    return;
  }

  showView("lesson-quiz");
  renderCustomQuizQuestion();
}

function renderCustomQuizQuestion() {
  const quiz = window.customLessonQuiz;
  const question = quiz.questions[quiz.currentIndex];

  document.getElementById("lesson-quiz-counter").textContent = `${
    quiz.currentIndex + 1
  } / ${quiz.questions.length}`;
  document.getElementById("lesson-quiz-progress-fill").style.width = `${
    ((quiz.currentIndex + 1) / quiz.questions.length) * 100
  }%`;

  const contentEl = document.getElementById("lesson-quiz-content");
  contentEl.innerHTML = `
    <div class="quiz-question">
      <div class="question-text">${escapeHtml(question.question_text)}</div>
      <div class="question-options">
        ${[
          question.option_a,
          question.option_b,
          question.option_c,
          question.option_d,
        ]
          .map(
            (option, index) => `
            <label class="option">
              <input type="radio" name="quiz-option" value="${escapeHtml(
                option
              )}" />
              ${escapeHtml(option)}
            </label>
          `
          )
          .join("")}
      </div>
    </div>
  `;

  document.getElementById("lesson-quiz-actions").innerHTML = `
    <button class="btn-primary" onclick="submitCustomQuizAnswer()">Submit Answer</button>
  `;
}

function submitCustomQuizAnswer() {
  const selectedOption = document.querySelector(
    'input[name="quiz-option"]:checked'
  );
  if (!selectedOption) {
    alert("Please select an answer.");
    return;
  }

  const quiz = window.customLessonQuiz;
  const question = quiz.questions[quiz.currentIndex];
  const isCorrect = selectedOption.value === question[`correct_option`];

  quiz.answers.push({ questionId: question.id, isCorrect });

  const contentEl = document.getElementById("lesson-quiz-content");
  contentEl.innerHTML += `<div class="quiz-feedback ${
    isCorrect ? "correct" : "incorrect"
  }"><p>${isCorrect ? "Correct!" : "Incorrect."}</p></div>`;

  if (quiz.currentIndex < quiz.questions.length - 1) {
    document.getElementById(
      "lesson-quiz-actions"
    ).innerHTML = `<button class="btn-primary" onclick="nextCustomQuizQuestion()">Next Question</button>`;
  } else {
    document.getElementById(
      "lesson-quiz-actions"
    ).innerHTML = `<button class="btn-primary" onclick="finishCustomQuiz()">Finish Quiz</button>`;
  }
}

function nextCustomQuizQuestion() {
  window.customLessonQuiz.currentIndex++;
  renderCustomQuizQuestion();
}

function finishCustomQuiz() {
  const quiz = window.customLessonQuiz;
  const correctCount = quiz.answers.filter((a) => a.isCorrect).length;
  const accuracy = Math.round((correctCount / quiz.questions.length) * 100);
  alert(
    `Quiz complete! ${correctCount}/${quiz.questions.length} correct (${accuracy}%)`
  );
  showView("lessons");
  loadLessons();
}

function escapeHtml(str = "") {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// ── Nav wiring + All event listeners ──────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  // Nav buttons
  document.querySelectorAll(".nav-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const view = btn.dataset.view;
      showView(view);
      if (view === "home") loadHomeData();
      if (view === "stats") window.loadStats?.();
      if (view === "profile") window.loadProfile?.();
      if (view === "lessons") loadLessons();
    });
  });

  // Logout button
  document.getElementById("btn-logout")?.addEventListener("click", () => {
    App.clearAuth();
    showScreen("auth-screen");
  });

  // Start quiz button (home page)
  document.getElementById("btn-start-quiz")?.addEventListener("click", () => {
    const type =
      document.querySelector('input[name="quiz-type"]:checked')?.value || "";
    window.startQuiz?.(type);
  });

  // Learning Japanese button (home page)
  document
    .getElementById("btn-learning-japanese")
    ?.addEventListener("click", () => {
      showLearningView();
    });

  // Dictionary button (home page)
  document.getElementById("btn-dictionary")?.addEventListener("click", () => {
    showDictionaryView();
  });

  // Initialize lesson form
  renderLessonForms();

  // Add question button
  document.getElementById("btn-add-question")?.addEventListener("click", () => {
    const container = document.getElementById("question-form-list");
    if (!container) return;
    const current = container.querySelectorAll(".lesson-question-card").length;
    if (current >= 25)
      return alert("A lesson can have at most 25 quiz questions.");
    const questions = Array.from(
      container.querySelectorAll(".lesson-question-card")
    ).map((card, idx) => {
      return {
        questionText: card.querySelector(".question-text").value,
        options: Array.from(card.querySelectorAll(".option-val")).map(
          (i) => i.value
        ),
        correctIndex: parseInt(
          card.querySelector(`input[name='correct-${idx}']:checked`)?.value ||
            0,
          10
        ),
      };
    });
    questions.push(createBlankQuestion());
    renderLessonForms(questions);
  });

  // Save lesson button
  document
    .getElementById("btn-save-lesson")
    ?.addEventListener("click", async (e) => {
      e.preventDefault && e.preventDefault();
      const errorEl = document.getElementById("lesson-error");
      if (errorEl) {
        errorEl.classList.add("hidden");
        errorEl.textContent = "";
      }

      try {
        const title = document.getElementById("lesson-title").value.trim();
        const content = document.getElementById("lesson-content").value.trim();
        const isPublic =
          document.getElementById("lesson-visibility").value === "public";

        const cards = Array.from(
          document.querySelectorAll(".lesson-question-card")
        );
        if (!title || !content || cards.length === 0) {
          throw new Error(
            "Please fill lesson title, content, and at least one question."
          );
        }

        const questions = cards.map((card, idx) => {
          const questionText = card
            .querySelector(".question-text")
            .value.trim();
          const options = Array.from(card.querySelectorAll(".option-val")).map(
            (input) => input.value.trim()
          );
          const checked = card.querySelector(
            `input[name='correct-${idx}']:checked`
          );
          return {
            questionText,
            options,
            correctIndex: checked ? parseInt(checked.value, 10) : 0,
          };
        });

        if (!questions.length || questions.length > 25) {
          throw new Error("A lesson must include 1 to 25 questions.");
        }

        if (
          questions.some((q) => !q.questionText || q.options.some((o) => !o))
        ) {
          throw new Error("Every question and option must be non-empty.");
        }

        const payload = { title, content, isPublic, questions };
        await api.post("/lessons", payload);

        alert("Lesson saved successfully.");
        document.getElementById("lesson-title").value = "";
        document.getElementById("lesson-content").value = "";
        document.getElementById("lesson-visibility").value = "private";
        renderLessonForms();
        loadLessons();
      } catch (err) {
        if (errorEl) {
          errorEl.textContent = err.message || "Lesson save failed.";
          errorEl.classList.remove("hidden");
        }
      }
    });
});

// ── Utilities ────────────────────────────────────────────────────

function setText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

function delay(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

window.showView = showView;
window.delay = delay;
window.setText = setText;
