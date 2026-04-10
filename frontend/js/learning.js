// js/learning.js — Structured Japanese learning system
"use strict";

// Use shared API helper from app.js (includes token, error handling)

let currentLesson = null;
let currentQuiz = null;
let quizQuestions = [];
let quizCurrentIndex = 0;
let quizAnswers = [];
let dictionaryQuery = "";
const DICTIONARY_DEBOUNCE_TIME = 300;

function debounce(fn, delay) {
  let timer = null;
  return function (...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delay);
  };
}

function _highlight(text, query) {
  if (!query || !text) return text;
  const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`(${escaped})`, "gi");
  return String(text).replace(re, "<mark>$1</mark>");
}

function _getSearchHistory() {
  return JSON.parse(localStorage.getItem("dictionaryHistory") || "[]");
}

function _addSearchHistory(term) {
  const list = _getSearchHistory();
  const trimmed = String(term || "").trim();
  if (!trimmed) return;
  const updated = [trimmed, ...list.filter((x) => x !== trimmed)].slice(0, 10);
  localStorage.setItem("dictionaryHistory", JSON.stringify(updated));
  _renderSearchHistory(updated);
}

function _renderSearchHistory(hItems) {
  const el = document.getElementById("dictionary-recent");
  if (!el) return;
  const items = (hItems || _getSearchHistory()).slice(0, 10);
  el.innerHTML = items
    .map(
      (item) =>
        `<a href="#" class="dictionary-history-item" data-term="${item}">${item}</a>`
    )
    .join(", ");
}

function _renderRecentlyViewed(items) {
  const container = document.getElementById("dictionary-recently-viewed");
  if (!container) return;
  const recent =
    items || JSON.parse(localStorage.getItem("dictionaryViewed") || "[]");
  if (!recent.length) {
    container.innerHTML = "<p>No recently viewed words yet.</p>";
    return;
  }

  container.innerHTML = `
    <h4>Recently Viewed</h4>
    <ul class="recent-words">
      ${recent
        .slice(0, 10)
        .map(
          (w) =>
            `<li>${w.kanji || w.hiragana || w.katakana || "?"} <small>${
              w.romaji
            }</small> - ${w.meaning}</li>`
        )
        .join("")}
    </ul>
  `;
}

// ── Navigation ──────────────────────────────────────────────────

window.showLearningView = function () {
  showView("learning");
  loadChapters();
  loadProgress();
};

window.showDictionaryView = function () {
  showView("dictionary");
  loadDictionary();
};

// ── Progress Tracking ────────────────────────────────────────────

async function loadProgress() {
  try {
    const progressEl = document.getElementById("learning-progress");
    if (!progressEl) return;

    const chapters = await api.request("GET", "/structured-lessons/chapters");

    if (!Array.isArray(chapters) || chapters.length === 0) {
      progressEl.innerHTML = "";
      return;
    }

    // Calculate progress across all lessons
    let totalLessons = 0;
    let completedLessons = 0;

    chapters.forEach((chapter) => {
      if (chapter.sections) {
        chapter.sections.forEach((section) => {
          if (section.lessons) {
            section.lessons.forEach((lesson) => {
              totalLessons++;
              if (lesson.is_completed) {
                completedLessons++;
              }
            });
          }
        });
      }
    });

    const percentage =
      totalLessons > 0
        ? Math.round((completedLessons / totalLessons) * 100)
        : 0;

    progressEl.innerHTML = `
      <div class="progress-section">
        <div class="progress-header">
          <h3>Your Progress</h3>
          <span class="progress-percent">${percentage}%</span>
        </div>
        <div class="progress-label">
          <span>${completedLessons} completed</span>
          <span>${totalLessons} total</span>
        </div>
        <div class="progress-bar">
          <div class="progress-fill" style="width: ${percentage}%"></div>
        </div>
      </div>
    `;
  } catch (err) {
    console.error("Failed to load progress:", err);
  }
}

// ── Chapters and Lessons ─────────────────────────────────────────

async function loadChapters() {
  try {
    const chapters = await api.request("GET", "/structured-lessons/chapters");
    console.log("LESSON DATA:", chapters);

    const container = document.getElementById("learning-content");
    container.innerHTML = "";

    if (!Array.isArray(chapters) || chapters.length === 0) {
      // FALLBACK: Show loading message with better UX
      container.innerHTML = `
        <div class="fallback-message">
          <p>📚 No structured lessons available at the moment. Please check back soon!</p>
          <p style="font-size: 0.9rem; color: var(--fog); margin-top: 1rem;">
            In the meantime, you can explore the dictionary or review previous lessons.
          </p>
        </div>
      `;
      return;
    }

    chapters.forEach((chapter) => {
      const chapterEl = createChapterElement(chapter);
      container.insertAdjacentHTML("beforeend", chapterEl);
    });
  } catch (err) {
    console.error("Failed to load chapters:", err);
    const container = document.getElementById("learning-content");
    container.innerHTML = `
      <div class="fallback-message">
        <p>📚 Unable to load lessons. The server might be temporarily unavailable.</p>
        <p style="font-size: 0.9rem; color: var(--fog); margin-top: 1rem;">
          Please refresh the page or try again later.
        </p>
      </div>
    `;
  }
}

function normalizeText(text) {
  if (typeof text !== "string") return text;
  try {
    // Safely normalize while preserving proper Unicode Japanese glyphs
    return text.normalize ? text.normalize("NFC") : text;
  } catch (_) {
    return text;
  }
}

function createChapterElement(chapter) {
  return `
    <div class="chapter">
      <div class="chapter-header">
        <h3 class="chapter-title">${normalizeText(chapter.title)}</h3>
        <p class="chapter-description">${normalizeText(chapter.description)}</p>
      </div>
      <div class="sections-container">
        ${chapter.sections
          .map((section) => createSectionElement(section))
          .join("")}
      </div>
    </div>
  `;
}

function createSectionElement(section) {
  return `
    <div class="section">
      <div class="section-header">
        <h4 class="section-title">${normalizeText(section.title)}</h4>
        <p class="section-description">${normalizeText(section.description)}</p>
      </div>
      <div class="lessons-grid">
        ${section.lessons.map((lesson) => createLessonCard(lesson)).join("")}
      </div>
    </div>
  `;
}

function createLessonCard(lesson) {
  const statusClass = lesson.is_completed
    ? "completed"
    : lesson.is_unlocked
    ? "unlocked"
    : "locked";
  const statusText = lesson.is_completed
    ? "✓ Completed"
    : lesson.is_unlocked
    ? "Available"
    : "Locked";

  return `
    <div class="lesson-card ${statusClass}" onclick="openLesson(${lesson.id})">
      <div class="lesson-number">Lesson ${lesson.lesson_number}</div>
      <h5 class="lesson-title">${normalizeText(lesson.title)}</h5>
      <div class="lesson-status">${statusText}</div>
    </div>
  `;
}

// ── Lesson View ─────────────────────────────────────────────────

async function openLesson(lessonId) {
  try {
    currentLesson = await api.request("GET", `/structured-lessons/${lessonId}`);

    // Allow access to lesson if it exists, regardless of unlock status
    // (Backend will handle prerequisites)

    showView("lesson");
    renderLesson();
  } catch (err) {
    console.error("Failed to load lesson:", err);
    alert("Failed to load lesson. Please try again.");
  }
}

function renderLesson() {
  document.getElementById(
    "lesson-title"
  ).textContent = `Lesson ${currentLesson.lesson_number}: ${currentLesson.title}`;

  const contentEl = document.getElementById("lesson-content");

  // Display lesson content with fallback
  if (currentLesson.content && currentLesson.content.trim()) {
    contentEl.innerHTML = currentLesson.content;
  } else {
    // FALLBACK: Display vocabulary list if no content
    if (
      Array.isArray(currentLesson.vocabulary) &&
      currentLesson.vocabulary.length > 0
    ) {
      const vocabHTML = currentLesson.vocabulary
        .map(
          (word) => `
          <div class="vocab-item">
            <strong>${
              word.kanji || word.hiragana || word.katakana || "?"
            }</strong>
            <span class="romaji">${word.romaji}</span>
            <span class="meaning">${word.meaning}</span>
          </div>
        `
        )
        .join("");
      contentEl.innerHTML = `<div class="vocabulary-section">${vocabHTML}</div>`;
    } else {
      contentEl.innerHTML = `<p style="color: var(--fog); font-style: italic;">No content available for this lesson yet.</p>`;
    }
  }

  const actionsEl = document.getElementById("lesson-actions");
  actionsEl.innerHTML = "";

  if (currentLesson.type === "reading") {
    if (!currentLesson.is_completed) {
      actionsEl.innerHTML = `
        <button class="btn-primary" onclick="completeLesson()">Mark as Complete</button>
      `;
    } else {
      actionsEl.innerHTML = `
        <p class="lesson-status">✓ This reading lesson is completed.</p>
      `;
    }
  } else if (currentLesson.type === "interactive") {
    if (!currentLesson.is_completed) {
      actionsEl.innerHTML = `
        <button class="btn-primary" onclick="startLessonQuiz()">Start Review Quiz</button>
      `;
    } else {
      actionsEl.innerHTML = `
        <button class="btn-primary" onclick="startLessonQuiz()">Retake Quiz</button>
      `;
    }
  }
}

async function completeLesson() {
  try {
    await api.request(
      "POST",
      `/structured-lessons/${currentLesson.id}/complete`
    );
    currentLesson.is_completed = true;
    renderLesson();
    // Refresh chapters to show updated progress
    loadChapters();
  } catch (err) {
    console.error("Failed to complete lesson:", err);
    alert("Failed to complete lesson. Please try again.");
  }
}

// ── Lesson Quiz ─────────────────────────────────────────────────

async function startLessonQuiz() {
  try {
    quizQuestions = await api.request(
      "GET",
      `/structured-lessons/${currentLesson.id}/quiz`
    );
    quizCurrentIndex = 0;
    quizAnswers = [];
    window.lessonQuizStartTime = Date.now();

    showView("lesson-quiz");
    renderQuizQuestion();
  } catch (err) {
    console.error("Failed to load quiz:", err);
    alert("Failed to load quiz questions. Please try again.");
  }
}

function renderQuizQuestion() {
  const question = quizQuestions[quizCurrentIndex];
  const progress = ((quizCurrentIndex + 1) / quizQuestions.length) * 100;

  document.getElementById(
    "lesson-quiz-progress-fill"
  ).style.width = `${progress}%`;
  document.getElementById("lesson-quiz-counter").textContent = `${
    quizCurrentIndex + 1
  } / ${quizQuestions.length}`;

  const contentEl = document.getElementById("lesson-quiz-content");
  contentEl.innerHTML = `
    <div class="quiz-question">
      <div class="question-text">${question.question}</div>
      ${
        question.romaji
          ? `<div class="question-romaji">(${question.romaji})</div>`
          : ""
      }
      <div class="question-options">
        ${question.options
          .map(
            (option, index) =>
              `<label class="option">
            <input type="radio" name="quiz-option" value="${option}" />
            ${option}
          </label>`
          )
          .join("")}
      </div>
    </div>
  `;

  const actionsEl = document.getElementById("lesson-quiz-actions");
  actionsEl.innerHTML = `
    <button class="btn-primary" onclick="submitQuizAnswer()" id="btn-submit-answer">
      Submit Answer
    </button>
  `;
}

async function submitQuizAnswer() {
  const selectedOption = document.querySelector(
    'input[name="quiz-option"]:checked'
  );
  if (!selectedOption) {
    alert("Please select an answer.");
    return;
  }

  const answer = selectedOption.value;
  quizAnswers.push({
    questionId: quizQuestions[quizCurrentIndex].id,
    selectedAnswer: answer,
  });

  try {
    const result = await api.request(
      "POST",
      "/structured-lessons/quiz/attempt",
      {
        lessonId: currentLesson.id,
        questionId: quizQuestions[quizCurrentIndex].id,
        selectedAnswer: answer,
        responseTimeMs: 1000, // TODO: track actual response time
      }
    );

    // Show feedback
    const contentEl = document.getElementById("lesson-quiz-content");
    const isCorrect = result.is_correct;
    const question = quizQuestions[quizCurrentIndex];

    contentEl.innerHTML += `
      <div class="quiz-feedback ${isCorrect ? "correct" : "incorrect"}">
        <p>${isCorrect ? "Correct!" : "Incorrect."}</p>
        ${question.explanation ? `<p>${question.explanation}</p>` : ""}
      </div>
    `;

    // Update actions
    const actionsEl = document.getElementById("lesson-quiz-actions");
    if (quizCurrentIndex < quizQuestions.length - 1) {
      actionsEl.innerHTML = `
        <button class="btn-primary" onclick="nextQuizQuestion()">Next Question</button>
      `;
    } else {
      actionsEl.innerHTML = `
        <button class="btn-primary" onclick="finishQuiz()">Finish Quiz</button>
      `;
    }
  } catch (err) {
    console.error("Failed to submit answer:", err);
    alert("Failed to submit answer. Please try again.");
  }
}

function nextQuizQuestion() {
  quizCurrentIndex++;
  renderQuizQuestion();
}

async function finishQuiz() {
  try {
    const sinceParam = window.lessonQuizStartTime
      ? `?since=${window.lessonQuizStartTime}`
      : "";

    const results = await api.request(
      "GET",
      `/structured-lessons/${currentLesson.id}/quiz/results${sinceParam}`
    );

    // Save quiz session
    await api.request("POST", "/structured-lessons/quiz/session", {
      sessionType: "lesson-review",
      lessonId: currentLesson.id,
      totalQuestions: results.total_attempts,
      correctAnswers: results.correct_answers,
      accuracy: results.accuracy,
    });

    // Track instant lesson quiz stats for dashboard/quick look
    window.instantStats = {
      source: `lesson-${currentLesson.id}`,
      type: "lesson-review",
      accuracy: results.accuracy,
      totalQuestions: results.total_questions,
      correctAnswers: results.correct_answers,
      wrongAnswers: results.total_attempts - results.correct_answers,
      attempts: results.attempts || [],
      completedAt: new Date().toISOString(),
    };

    // Check if passed (75% accuracy)
    const passed = results.accuracy >= 75;
    if (passed) {
      // Mark lesson as completed if not already
      if (!currentLesson.is_completed) {
        await api.request(
          "POST",
          `/structured-lessons/${currentLesson.id}/complete`
        );
        currentLesson.is_completed = true;
      }
    }

    // Show immediate stats
    showView("lesson-quiz");
    const contentEl = document.getElementById("lesson-quiz-content");
    const actionsEl = document.getElementById("lesson-quiz-actions");

    contentEl.innerHTML = `
      <div class="quiz-results">
        <h3>${passed ? "Congratulations!" : "Keep practicing!"}</h3>
        <div class="results-stats">
          <div class="stat-item">
            <span class="stat-label">Accuracy:</span>
            <span class="stat-value">${results.accuracy}%</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">Correct:</span>
            <span class="stat-value">${results.correct_answers}/${
      results.total_attempts
    }</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">Incorrect:</span>
            <span class="stat-value">${
              results.total_attempts - results.correct_answers
            }/${results.total_attempts}</span>
          </div>
        </div>
        ${
          results.attempts &&
          results.attempts.filter((a) => !a.is_correct).length > 0
            ? `
          <div class="incorrect-list">
            <h4>Questions to review:</h4>
            <ul>
              ${results.attempts
                .filter((a) => !a.is_correct)
                .slice(0, 5)
                .map((a) => `<li>${a.question_id || "Question"}</li>`)
                .join("")}
            </ul>
          </div>
        `
            : ""
        }
      </div>
    `;

    actionsEl.innerHTML = `
      <button class="btn-primary" onclick="showView('learning'); loadChapters();">Back to Lessons</button>
      <button class="btn-ghost" onclick="showView('stats'); window.loadStats?.();">View Full Stats</button>
    `;

    // Refresh chapters to show updated progress
    loadChapters();
  } catch (err) {
    console.error("Failed to get quiz results:", err);
    showView("learning");
  }
}

// ── Dictionary ──────────────────────────────────────────────────

async function loadDictionary(searchTerm = "") {
  dictionaryQuery = String(searchTerm || "").trim();
  const container = document.getElementById("dictionary-content");
  const suggestions = document.getElementById("dictionary-suggestions");
  if (suggestions) {
    suggestions.classList.toggle(
      "hidden",
      !dictionaryQuery || dictionaryQuery.length < 2
    );
  }

  try {
    const params = dictionaryQuery
      ? `?search=${encodeURIComponent(dictionaryQuery)}`
      : "";
    const vocabulary = await api.request("GET", `/dictionary${params}`);

    container.innerHTML = "";

    if (!Array.isArray(vocabulary) || vocabulary.length === 0) {
      container.innerHTML = "<p>No vocabulary found.</p>";
      return;
    }

    vocabulary.forEach((word) => {
      const wordEl = createVocabularyElement(word);
      container.appendChild(wordEl);
    });
    _renderRecentlyViewed();
    await loadDictionarySuggestions(dictionaryQuery);
  } catch (err) {
    console.error("Failed to load dictionary:", err);
    if (err.status === 401 || err.status === 403) {
      container.innerHTML =
        "<p>Please log in to view the dictionary, then reload the page.</p>";
    } else {
      container.innerHTML =
        "<p>Error loading dictionary. Please try again.</p>";
    }
  }
}

function createVocabularyElement(word) {
  const query = dictionaryQuery || "";
  const highlightedKanji = _highlight(word.kanji || word.hiragana || "", query);
  const highlightedRomaji = _highlight(word.romaji || "", query);
  const highlightedMeaning = _highlight(word.meaning || "", query);
  const highlightedExample = _highlight(word.example_sentence || "", query);

  const wordDiv = document.createElement("div");
  wordDiv.className = "vocabulary-entry";

  wordDiv.dataset.wordId = word.id;
  wordDiv.addEventListener("click", () => {
    const viewed = JSON.parse(localStorage.getItem("dictionaryViewed") || "[]");
    const existing = viewed.filter((x) => x.id !== word.id);
    const next = [
      {
        id: word.id,
        kanji: word.kanji,
        hiragana: word.hiragana,
        katakana: word.katakana,
        romaji: word.romaji,
        meaning: word.meaning,
      },
      ...existing,
    ].slice(0, 10);
    localStorage.setItem("dictionaryViewed", JSON.stringify(next));
    _renderRecentlyViewed(next);
  });

  wordDiv.innerHTML = `
    <div class="vocab-header">
      <div class="vocab-japanese">
        ${normalizeText(highlightedKanji)}
        ${
          word.katakana && word.katakana !== word.hiragana
            ? `(${normalizeText(word.katakana)})`
            : ""
        }
      </div>
      <div class="vocab-romaji">${normalizeText(word.romaji)}</div>
    </div>
    <div class="vocab-meaning">${normalizeText(highlightedMeaning)}</div>
    ${
      word.part_of_speech
        ? `<div class="vocab-pos">${normalizeText(word.part_of_speech)}</div>`
        : ""
    }
    ${
      word.example_sentence
        ? `<div class="vocab-example">"${normalizeText(
            highlightedExample
          )}"</div>`
        : ""
    }
    <div class="vocab-actions">
      <button class="btn-toggle" onclick="toggleCard(${
        word.id
      })">↓ Show More</button>
    </div>
    <div class="vocab-expanded" id="expanded-${word.id}" style="display: none;">
      <div class="vocab-kana">${normalizeText(
        word.hiragana || word.katakana || ""
      )}</div>
      <div class="vocab-romaji">${normalizeText(word.romaji)}</div>
      <div class="vocab-example">${normalizeText(
        word.example_sentence || ""
      )}</div>
      <div class="vocab-detailed">${normalizeText(
        word.detailed_explanation || ""
      )}</div>
    </div>
  `;

  return wordDiv;
}

function toggleCard(id) {
  const expanded = document.getElementById(`expanded-${id}`);
  const btn = event.target;
  if (expanded.style.display === "none") {
    expanded.style.display = "block";
    btn.textContent = "↑ Show Less";
  } else {
    expanded.style.display = "none";
    btn.textContent = "↓ Show More";
  }
}

async function loadDictionarySuggestions(searchTerm = "") {
  const suggestions = document.getElementById("dictionary-suggestions");
  if (!suggestions) return;
  const q = String(searchTerm || "").trim();
  if (!q || q.length < 2) {
    suggestions.classList.add("hidden");
    suggestions.innerHTML = "";
    return;
  }

  try {
    const data = await api.request(
      "GET",
      `/dictionary/search?q=${encodeURIComponent(q)}`
    );
    if (!Array.isArray(data) || data.length === 0) {
      suggestions.innerHTML = "<li>No suggestions found</li>";
      suggestions.classList.remove("hidden");
      return;
    }

    suggestions.innerHTML = data
      .slice(0, 10)
      .map(
        (w) =>
          `<li data-term="${w.romaji || w.kanji || w.hiragana || w.katakana}">${
            w.kanji || w.hiragana || w.katakana
          } (${w.romaji}) — ${w.meaning}</li>`
      )
      .join("");

    suggestions.classList.remove("hidden");
  } catch (err) {
    console.error("Failed to load dictionary suggestions", err);
    suggestions.classList.add("hidden");
    suggestions.innerHTML = "";
  }
}
// ── Event Listeners ─────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  // Navigation buttons
  document
    .getElementById("btn-learning-japanese")
    ?.addEventListener("click", showLearningView);
  document
    .getElementById("btn-dictionary")
    ?.addEventListener("click", showDictionaryView);

  // Back buttons
  document
    .getElementById("btn-back-from-lesson")
    ?.addEventListener("click", () => {
      showView("learning");
      loadChapters();
    });

  document
    .getElementById("btn-back-from-quiz")
    ?.addEventListener("click", () => {
      showView("lesson");
      renderLesson();
    });

  // Dictionary search
  const debouncedLookup = debounce((value) => {
    dictionaryQuery = value.trim();
    _addSearchHistory(value);
    loadDictionary(value);
    loadDictionarySuggestions(value);
  }, DICTIONARY_DEBOUNCE_TIME);

  document
    .getElementById("dictionary-search")
    ?.addEventListener("input", (e) => {
      debouncedLookup(e.target.value);
    });

  document
    .getElementById("btn-add-vocab")
    ?.addEventListener("click", async (e) => {
      e.preventDefault();
      await addVocabularyWord();
    });

  document
    .getElementById("dictionary-suggestions")
    ?.addEventListener("click", (e) => {
      const item = e.target.closest("li[data-term]");
      if (item) {
        const term = item.dataset.term;
        const input = document.getElementById("dictionary-search");
        if (input) input.value = term;
        dictionaryQuery = term;
        _addSearchHistory(term);
        loadDictionary(term);
        loadDictionarySuggestions(term);
      }
    });

  // Show previous history at startup
  _renderSearchHistory();
});

async function addVocabularyWord() {
  const lessonId = Number(document.getElementById("add-lesson-id").value);
  const romaji = document.getElementById("add-romaji").value.trim();
  const hiragana = document.getElementById("add-hiragana").value.trim();
  const katakana = document.getElementById("add-katakana").value.trim();
  const kanji = document.getElementById("add-kanji").value.trim();
  const meaning = document.getElementById("add-meaning").value.trim();
  const partOfSpeech = document.getElementById("add-pos").value.trim();
  const statusEl = document.getElementById("add-vocab-status");

  if (!lessonId || !romaji || !meaning) {
    statusEl.textContent =
      "Please provide Lesson ID, Romaji, and English meaning.";
    statusEl.classList.remove("hidden");
    return;
  }

  try {
    const body = {
      lesson_id: lessonId,
      romaji,
      hiragana: hiragana || null,
      katakana: katakana || null,
      kanji: kanji || null,
      english_meaning: meaning,
      vietnamese_meaning: meaning,
      part_of_speech: partOfSpeech || null,
      example_sentence_en: `Practice: ${romaji}`,
      example_sentence_vi: `Practice: ${romaji}`,
    };

    const resp = await api.post("/dictionary", body);
    statusEl.textContent = "Vocabulary added successfully.";
    statusEl.classList.remove("hidden");
    statusEl.style.color = "#9de0b8";

    // Clear form and reload dictionary
    document.getElementById("add-lesson-id").value = "";
    document.getElementById("add-romaji").value = "";
    document.getElementById("add-hiragana").value = "";
    document.getElementById("add-katakana").value = "";
    document.getElementById("add-kanji").value = "";
    document.getElementById("add-meaning").value = "";
    document.getElementById("add-pos").value = "";

    loadDictionary();
  } catch (err) {
    console.error("Failed to add vocabulary:", err);
    statusEl.textContent =
      err.data?.error || "Could not add vocabulary. Check fields and retry.";
    statusEl.classList.remove("hidden");
    statusEl.style.color = "#ff8f8f";
  }
}
