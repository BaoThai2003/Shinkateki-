// js/learning.js — Structured Japanese learning system (FIXED)
"use strict";

let currentLesson = null;
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
  const trimmed = String(term || "").trim();
  if (!trimmed) return;
  const list = _getSearchHistory();
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
    container.innerHTML = "<p>Chưa có từ nào được xem gần đây.</p>";
    return;
  }
  container.innerHTML = `
    <h4>Đã xem gần đây</h4>
    <ul class="recent-words">
      ${recent
        .slice(0, 10)
        .map(
          (w) => `
        <li>
          <strong>${w.kanji || w.hiragana || w.katakana || "?"}</strong>
          <small>${w.romaji}</small> — ${w.meaning}
        </li>
      `
        )
        .join("")}
    </ul>
  `;
}

// ── Navigation ────────────────────────────────────────────────────

window.showLearningView = function () {
  console.log("[showLearningView] opening learning view");
  showView("learning");
  loadChapters();
  loadProgress();
};

window.showDictionaryView = function () {
  console.log("[showDictionaryView] opening dictionary view");
  showView("dictionary");
  loadDictionary();
};

// ── Progress ──────────────────────────────────────────────────────

async function loadProgress() {
  try {
    const progressEl = document.getElementById("learning-progress");
    if (!progressEl) return;

    const chapters = await api.request("GET", "/structured-lessons/chapters");
    if (!Array.isArray(chapters) || !chapters.length) {
      progressEl.innerHTML = "";
      return;
    }

    let totalLessons = 0,
      completedLessons = 0;
    chapters.forEach((chapter) => {
      (chapter.sections || []).forEach((section) => {
        (section.lessons || []).forEach((lesson) => {
          totalLessons++;
          if (lesson.is_completed) completedLessons++;
        });
      });
    });

    const percentage =
      totalLessons > 0
        ? Math.round((completedLessons / totalLessons) * 100)
        : 0;

    progressEl.innerHTML = `
      <div class="progress-section">
        <div class="progress-header">
          <h3>Tiến Độ Của Bạn</h3>
          <span class="progress-percent">${percentage}%</span>
        </div>
        <div class="progress-label">
          <span>${completedLessons} đã hoàn thành</span>
          <span>${totalLessons} tổng cộng</span>
        </div>
        <div class="progress-bar">
          <div class="progress-fill" style="width: ${percentage}%"></div>
        </div>
      </div>
    `;
  } catch (err) {
    console.error("[loadProgress] failed:", err);
  }
}

// ── Chapters ──────────────────────────────────────────────────────

async function loadChapters() {
  console.log("[loadChapters] fetching chapters...");
  try {
    const chapters = await api.request("GET", "/structured-lessons/chapters");
    const container = document.getElementById("learning-content");
    container.innerHTML = "";

    if (!Array.isArray(chapters) || !chapters.length) {
      container.innerHTML = `
        <div class="fallback-message">
          <p>📚 Chưa có bài học nào. Vui lòng kiểm tra lại sau!</p>
        </div>
      `;
      return;
    }

    console.log(`[loadChapters] rendering ${chapters.length} chapters`);
    chapters.forEach((chapter) => {
      container.insertAdjacentHTML("beforeend", createChapterElement(chapter));
    });
  } catch (err) {
    console.error("[loadChapters] ERROR:", err);
    const container = document.getElementById("learning-content");
    if (container) {
      container.innerHTML = `
        <div class="fallback-message">
          <p>📚 Không thể tải bài học. Vui lòng thử lại.</p>
        </div>
      `;
    }
  }
}

function normalizeText(text) {
  if (typeof text !== "string") return text || "";
  return text.normalize ? text.normalize("NFC") : text;
}

function createChapterElement(chapter) {
  return `
    <div class="chapter">
      <div class="chapter-header">
        <h3 class="chapter-title">${normalizeText(chapter.title)}</h3>
        <p class="chapter-description">${normalizeText(chapter.description)}</p>
      </div>
      <div class="sections-container">
        ${(chapter.sections || []).map((s) => createSectionElement(s)).join("")}
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
        ${(section.lessons || []).map((l) => createLessonCard(l)).join("")}
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
    ? "✓ Đã Hoàn Thành"
    : lesson.is_unlocked
    ? "Có Thể Học"
    : "🔒 Chưa Mở";

  // FIX: Use onclick with a named global function; add console.log
  return `
    <div
      class="lesson-card ${statusClass}"
      onclick="openLesson(${lesson.id})"
      role="button"
      tabindex="0"
      onkeypress="if(event.key==='Enter')openLesson(${lesson.id})"
      style="cursor:${lesson.is_unlocked ? "pointer" : "not-allowed"}"
    >
      <div class="lesson-number">Bài ${lesson.lesson_number}</div>
      <h5 class="lesson-title">${normalizeText(lesson.title)}</h5>
      <div class="lesson-status">${statusText}</div>
    </div>
  `;
}

// ── Lesson View ───────────────────────────────────────────────────

// FIX: Make openLesson a global function (accessible from onclick)
window.openLesson = async function openLesson(lessonId) {
  console.log("[openLesson] Lesson clicked:", lessonId);

  try {
    currentLesson = await api.request("GET", `/structured-lessons/${lessonId}`);
    console.log("[openLesson] loaded lesson:", currentLesson?.title);

    showView("lesson");
    renderLesson();
  } catch (err) {
    console.error("[openLesson] ERROR:", err);
    if (err.status === 403) {
      alert("Bài học này chưa được mở khoá. Hãy hoàn thành các bài học trước.");
    } else {
      alert("Không thể tải bài học. Vui lòng thử lại.");
    }
  }
};

function renderLesson() {
  const titleEl = document.getElementById("lesson-title");
  if (titleEl) {
    titleEl.textContent = `Bài ${currentLesson.lesson_number}: ${currentLesson.title}`;
  }

  // Render markdown-ish content
  const contentEl = document.getElementById("lesson-content");
  if (contentEl) {
    if (currentLesson.content && currentLesson.content.trim()) {
      contentEl.innerHTML = parseMarkdown(currentLesson.content);
    } else if (
      Array.isArray(currentLesson.vocabulary) &&
      currentLesson.vocabulary.length
    ) {
      contentEl.innerHTML = currentLesson.vocabulary
        .map(
          (word) => `
        <div class="vocab-item">
          <strong>${
            word.kanji || word.hiragana || word.katakana || "?"
          }</strong>
          <span class="romaji">${word.romaji}</span> —
          <span class="meaning">${word.meaning}</span>
        </div>
      `
        )
        .join("");
    } else {
      contentEl.innerHTML = `<p style="color:var(--fog);font-style:italic">Chưa có nội dung cho bài học này.</p>`;
    }
  }

  const actionsEl = document.getElementById("lesson-actions");
  if (!actionsEl) return;

  if (!currentLesson.is_completed) {
    actionsEl.innerHTML = `
      <button class="btn-primary" onclick="startLessonQuiz()">Bắt Đầu Ôn Tập →</button>
      <button class="btn-ghost" onclick="completeLesson()">Đánh Dấu Đã Đọc</button>
    `;
  } else {
    actionsEl.innerHTML = `
      <button class="btn-primary" onclick="startLessonQuiz()">Ôn Tập Lại →</button>
      <p class="lesson-status" style="color:var(--gold)">✓ Đã Hoàn Thành</p>
    `;
  }
}

/** Very minimal markdown-to-HTML converter for lesson content */
function parseMarkdown(md) {
  return md
    .replace(/^#{3} (.+)$/gm, "<h3>$1</h3>")
    .replace(/^#{2} (.+)$/gm, "<h2>$1</h2>")
    .replace(/^#{1} (.+)$/gm, "<h1>$1</h1>")
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/\*(.+?)\*/g, "<em>$1</em>")
    .replace(/\n\n/g, "</p><p>")
    .replace(/\n/g, "<br>")
    .replace(/^/, "<p>")
    .replace(/$/, "</p>");
}

async function completeLesson() {
  try {
    await api.request(
      "POST",
      `/structured-lessons/${currentLesson.id}/complete`
    );
    currentLesson.is_completed = true;
    renderLesson();
    loadChapters();
    console.log(`[completeLesson] lesson ${currentLesson.id} marked complete`);
  } catch (err) {
    console.error("[completeLesson] ERROR:", err);
    alert("Không thể đánh dấu hoàn thành. Vui lòng thử lại.");
  }
}

// ── Lesson Quiz ───────────────────────────────────────────────────

async function startLessonQuiz() {
  console.log("[startLessonQuiz] loading quiz for lesson", currentLesson?.id);
  try {
    quizQuestions = await api.request(
      "GET",
      `/structured-lessons/${currentLesson.id}/quiz`
    );
    quizCurrentIndex = 0;
    quizAnswers = [];
    window.lessonQuizStartTime = Date.now();

    if (!quizQuestions.length) {
      alert("Bài học này chưa có câu hỏi ôn tập.");
      return;
    }

    showView("lesson-quiz");
    renderQuizQuestion();
  } catch (err) {
    console.error("[startLessonQuiz] ERROR:", err);
    alert("Không thể tải câu hỏi. Vui lòng thử lại.");
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
            (option) => `
          <label class="option">
            <input type="radio" name="quiz-option" value="${option}" />
            ${option}
          </label>
        `
          )
          .join("")}
      </div>
    </div>
  `;

  document.getElementById("lesson-quiz-actions").innerHTML = `
    <button class="btn-primary" onclick="submitLessonQuizAnswer()">Xác Nhận</button>
  `;
}

async function submitLessonQuizAnswer() {
  const selected = document.querySelector('input[name="quiz-option"]:checked');
  if (!selected) {
    alert("Vui lòng chọn một đáp án.");
    return;
  }

  const answer = selected.value;
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
        responseTimeMs: 1000,
      }
    );

    const isCorrect = result.is_correct;
    const explanation = quizQuestions[quizCurrentIndex].explanation || "";

    document.getElementById("lesson-quiz-content").innerHTML += `
      <div class="quiz-feedback ${isCorrect ? "correct" : "incorrect"}">
        <p>${isCorrect ? "✓ Đúng!" : "✗ Sai."}</p>
        ${explanation ? `<p>${explanation}</p>` : ""}
      </div>
    `;

    const actionsEl = document.getElementById("lesson-quiz-actions");
    if (quizCurrentIndex < quizQuestions.length - 1) {
      actionsEl.innerHTML = `<button class="btn-primary" onclick="nextLessonQuizQuestion()">Câu Tiếp →</button>`;
    } else {
      actionsEl.innerHTML = `<button class="btn-primary" onclick="finishLessonQuiz()">Hoàn Thành →</button>`;
    }
  } catch (err) {
    console.error("[submitLessonQuizAnswer] ERROR:", err);
    alert("Không thể gửi đáp án. Vui lòng thử lại.");
  }
}

function nextLessonQuizQuestion() {
  quizCurrentIndex++;
  renderQuizQuestion();
}

async function finishLessonQuiz() {
  try {
    const sinceParam = window.lessonQuizStartTime
      ? `?since=${window.lessonQuizStartTime}`
      : "";

    const results = await api.request(
      "GET",
      `/structured-lessons/${currentLesson.id}/quiz/results${sinceParam}`
    );

    await api
      .request("POST", "/structured-lessons/quiz/session", {
        sessionType: "lesson-review",
        lessonId: currentLesson.id,
        totalQuestions: results.total_attempts,
        correctAnswers: results.correct_answers,
        accuracy: results.accuracy,
      })
      .catch((e) => console.warn("[finishLessonQuiz] session save:", e));

    window.instantStats = {
      source: `lesson-${currentLesson.id}`,
      type: "lesson-review",
      accuracy: results.accuracy,
      totalQuestions: results.total_questions,
      correctAnswers: results.correct_answers,
      wrongAnswers:
        (results.total_attempts || 0) - (results.correct_answers || 0),
      completedAt: new Date().toISOString(),
    };

    const passed = results.accuracy >= 75;
    if (passed && !currentLesson.is_completed) {
      await api
        .request("POST", `/structured-lessons/${currentLesson.id}/complete`)
        .catch((e) => console.warn("[finishLessonQuiz] complete lesson:", e));
      currentLesson.is_completed = true;
    }

    const contentEl = document.getElementById("lesson-quiz-content");
    const actionsEl = document.getElementById("lesson-quiz-actions");

    contentEl.innerHTML = `
      <div class="quiz-results" style="text-align:center;padding:2rem">
        <h3 style="color:var(--rice);margin-bottom:1rem">
          ${passed ? "🎉 Chúc Mừng!" : "💪 Cần Luyện Thêm!"}
        </h3>
        <div class="stats-summary">
          <div class="stat-item ${passed ? "correct" : "incorrect"}">
            <div class="stat-number">${results.accuracy}%</div>
            <div class="stat-label">Độ Chính Xác</div>
          </div>
          <div class="stat-item correct">
            <div class="stat-number">${results.correct_answers}</div>
            <div class="stat-label">Đúng</div>
          </div>
          <div class="stat-item incorrect">
            <div class="stat-number">${
              (results.total_attempts || 0) - (results.correct_answers || 0)
            }</div>
            <div class="stat-label">Sai</div>
          </div>
        </div>
      </div>
    `;

    actionsEl.innerHTML = `
      <button class="btn-primary" onclick="showView('learning'); loadChapters();">
        ← Quay Lại Bài Học
      </button>
      <button class="btn-ghost" onclick="showView('stats'); window.loadStats?.();">
        Xem Thống Kê
      </button>
    `;

    loadChapters();
  } catch (err) {
    console.error("[finishLessonQuiz] ERROR:", err);
    showView("learning");
  }
}

// ── Dictionary ────────────────────────────────────────────────────

async function loadDictionary(searchTerm = "") {
  dictionaryQuery = String(searchTerm || "").trim();
  console.log(`[loadDictionary] search="${dictionaryQuery}"`);

  const container = document.getElementById("dictionary-content");
  const suggestions = document.getElementById("dictionary-suggestions");
  if (suggestions) {
    suggestions.classList.toggle(
      "hidden",
      !dictionaryQuery || dictionaryQuery.length < 2
    );
  }

  try {
    // FIX: Pass search param correctly
    const params = dictionaryQuery
      ? `?search=${encodeURIComponent(dictionaryQuery)}`
      : "";
    const vocabulary = await api.request("GET", `/dictionary${params}`);

    container.innerHTML = "";

    if (!Array.isArray(vocabulary) || !vocabulary.length) {
      container.innerHTML = `<p style="color:var(--fog);text-align:center;padding:2rem">
        ${
          dictionaryQuery
            ? `Không tìm thấy từ nào cho "${dictionaryQuery}"`
            : "Không có từ vựng nào."
        }
      </p>`;
      return;
    }

    console.log(`[loadDictionary] rendering ${vocabulary.length} words`);
    vocabulary.forEach((word) => {
      container.appendChild(createVocabularyElement(word));
    });

    _renderRecentlyViewed();
    if (dictionaryQuery.length >= 2) {
      loadDictionarySuggestions(dictionaryQuery);
    }
  } catch (err) {
    console.error("[loadDictionary] ERROR:", err);
    container.innerHTML =
      err.status === 401
        ? "<p>Vui lòng đăng nhập để xem từ điển.</p>"
        : "<p>Lỗi tải từ điển. Vui lòng thử lại.</p>";
  }
}

/**
 * FIX: Expandable vocabulary card with toggle
 * Shows basic info by default; expands to show full detail
 */
function createVocabularyElement(word) {
  const query = dictionaryQuery || "";

  // Primary display form
  const japDisplay = word.kanji || word.hiragana || word.katakana || "?";
  const meaning = word.meaning || "";
  const romaji = word.romaji || "";

  const highlightedDisplay = _highlight(japDisplay, query);
  const highlightedMeaning = _highlight(meaning, query);
  const highlightedRomaji = _highlight(romaji, query);

  const uniqueId = `vocab-card-${word.id}`;

  const wordDiv = document.createElement("div");
  wordDiv.className = "vocabulary-entry";
  wordDiv.dataset.wordId = word.id;

  // Track viewed
  wordDiv.addEventListener("click", () => {
    const viewed = JSON.parse(localStorage.getItem("dictionaryViewed") || "[]");
    const existing = viewed.filter((x) => x.id !== word.id);
    const next = [
      {
        id: word.id,
        kanji: word.kanji,
        hiragana: word.hiragana,
        katakana: word.katakana,
        romaji,
        meaning,
      },
      ...existing,
    ].slice(0, 10);
    localStorage.setItem("dictionaryViewed", JSON.stringify(next));
    _renderRecentlyViewed(next);
  });

  wordDiv.innerHTML = `
    <div class="vocab-header">
      <div class="vocab-japanese">${normalizeText(highlightedDisplay)}</div>
      <div class="vocab-romaji">${normalizeText(highlightedRomaji)}</div>
    </div>
    <div class="vocab-meaning">${normalizeText(highlightedMeaning)}</div>
    ${
      word.part_of_speech
        ? `<div class="vocab-pos">${normalizeText(word.part_of_speech)}</div>`
        : ""
    }
    <button
      class="btn-toggle"
      onclick="toggleVocabCard('${uniqueId}', this)"
      style="
        background:none;border:1px solid var(--ink-4);color:var(--fog);
        padding:.3rem .75rem;border-radius:var(--r);cursor:pointer;
        font-size:.8rem;margin-top:.5rem;transition:color .2s
      "
    >↓ Chi Tiết</button>
    <div id="${uniqueId}" class="vocab-expanded" style="display:none;margin-top:.75rem;border-top:1px solid var(--ink-4);padding-top:.75rem">
      ${
        word.hiragana && word.hiragana !== japDisplay
          ? `<div style="color:var(--fog);font-size:.9rem">Hiragana: <strong>${normalizeText(
              word.hiragana
            )}</strong></div>`
          : ""
      }
      ${
        word.katakana && word.katakana !== japDisplay
          ? `<div style="color:var(--fog);font-size:.9rem">Katakana: <strong>${normalizeText(
              word.katakana
            )}</strong></div>`
          : ""
      }
      ${
        romaji
          ? `<div style="color:var(--fog);font-size:.9rem">Romaji: <strong>${romaji}</strong></div>`
          : ""
      }
      ${
        word.example_sentence
          ? `<div class="vocab-example" style="margin-top:.5rem">"${normalizeText(
              word.example_sentence
            )}"</div>`
          : ""
      }
      ${
        word.lesson_number
          ? `<div style="color:var(--fog);font-size:.75rem;margin-top:.4rem;font-family:var(--font-mono)">Bài ${word.lesson_number}</div>`
          : ""
      }
    </div>
  `;

  return wordDiv;
}

/**
 * FIX: Toggle expand/collapse for vocabulary card
 */
window.toggleVocabCard = function toggleVocabCard(id, btn) {
  const el = document.getElementById(id);
  if (!el) return;
  const isExpanded = el.style.display !== "none";
  el.style.display = isExpanded ? "none" : "block";
  btn.textContent = isExpanded ? "↓ Chi Tiết" : "↑ Thu Gọn";
};

async function loadDictionarySuggestions(searchTerm = "") {
  const suggestions = document.getElementById("dictionary-suggestions");
  if (!suggestions) return;
  const q = String(searchTerm || "").trim();
  if (!q || q.length < 2) {
    suggestions.classList.add("hidden");
    return;
  }

  try {
    const data = await api.request(
      "GET",
      `/dictionary/search?q=${encodeURIComponent(q)}`
    );
    if (!Array.isArray(data) || !data.length) {
      suggestions.innerHTML = "<li>Không tìm thấy gợi ý nào</li>";
      suggestions.classList.remove("hidden");
      return;
    }

    suggestions.innerHTML = data
      .slice(0, 10)
      .map((w) => {
        const display = w.kanji || w.hiragana || w.katakana || w.romaji;
        const meaning = w.meaning || "";
        return `<li data-term="${w.romaji || display}">${display} (${
          w.romaji
        }) — ${meaning}</li>`;
      })
      .join("");

    suggestions.classList.remove("hidden");
  } catch (err) {
    console.error("[loadDictionarySuggestions] ERROR:", err);
    suggestions.classList.add("hidden");
  }
}

// ── Event Listeners ───────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  document
    .getElementById("btn-learning-japanese")
    ?.addEventListener("click", showLearningView);
  document
    .getElementById("btn-dictionary")
    ?.addEventListener("click", showDictionaryView);

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

  // Dictionary search with debounce
  const debouncedSearch = debounce((value) => {
    dictionaryQuery = value.trim();
    if (dictionaryQuery) _addSearchHistory(dictionaryQuery);
    loadDictionary(value);
  }, DICTIONARY_DEBOUNCE_TIME);

  document
    .getElementById("dictionary-search")
    ?.addEventListener("input", (e) => {
      debouncedSearch(e.target.value);
    });

  // Suggestion click
  document
    .getElementById("dictionary-suggestions")
    ?.addEventListener("click", (e) => {
      const item = e.target.closest("li[data-term]");
      if (!item) return;
      const term = item.dataset.term;
      const input = document.getElementById("dictionary-search");
      if (input) input.value = term;
      dictionaryQuery = term;
      _addSearchHistory(term);
      loadDictionary(term);
      document
        .getElementById("dictionary-suggestions")
        ?.classList.add("hidden");
    });

  // History link click
  document
    .getElementById("dictionary-recent")
    ?.addEventListener("click", (e) => {
      const link = e.target.closest("a[data-term]");
      if (!link) return;
      e.preventDefault();
      const term = link.dataset.term;
      const input = document.getElementById("dictionary-search");
      if (input) input.value = term;
      loadDictionary(term);
    });

  // Add vocabulary
  document
    .getElementById("btn-add-vocab")
    ?.addEventListener("click", async (e) => {
      e.preventDefault();
      await addVocabularyWord();
    });

  _renderSearchHistory();
});

async function addVocabularyWord() {
  const lessonId = Number(document.getElementById("add-lesson-id")?.value);
  const romaji = document.getElementById("add-romaji")?.value.trim();
  const hiragana = document.getElementById("add-hiragana")?.value.trim();
  const katakana = document.getElementById("add-katakana")?.value.trim();
  const kanji = document.getElementById("add-kanji")?.value.trim();
  const meaning = document.getElementById("add-meaning")?.value.trim();
  const partOfSpeech = document.getElementById("add-pos")?.value.trim();
  const statusEl = document.getElementById("add-vocab-status");

  console.log("[addVocabularyWord]", { lessonId, romaji, meaning });

  if (!lessonId || !romaji || !meaning) {
    if (statusEl) {
      statusEl.textContent = "Vui lòng nhập ID Bài Học, Romaji và Nghĩa.";
      statusEl.classList.remove("hidden");
    }
    return;
  }

  try {
    await api.post("/dictionary", {
      lesson_id: lessonId,
      romaji,
      hiragana: hiragana || null,
      katakana: katakana || null,
      kanji: kanji || null,
      english_meaning: meaning,
      vietnamese_meaning: meaning,
      part_of_speech: partOfSpeech || null,
    });

    if (statusEl) {
      statusEl.textContent = "✓ Thêm từ vựng thành công!";
      statusEl.style.color = "#9de0b8";
      statusEl.classList.remove("hidden");
    }

    // Clear form
    [
      "add-lesson-id",
      "add-romaji",
      "add-hiragana",
      "add-katakana",
      "add-kanji",
      "add-meaning",
      "add-pos",
    ].forEach((id) => {
      const el = document.getElementById(id);
      if (el) el.value = "";
    });

    loadDictionary();
  } catch (err) {
    console.error("[addVocabularyWord] ERROR:", err);
    if (statusEl) {
      statusEl.textContent = err.data?.error || "Không thể thêm từ vựng.";
      statusEl.style.color = "#ff8f8f";
      statusEl.classList.remove("hidden");
    }
  }
}
