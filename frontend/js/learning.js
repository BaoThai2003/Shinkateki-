// js/learning.js — Structured Japanese learning system
"use strict";

// Use shared API helper from app.js (includes token, error handling)

let currentLesson = null;
let currentQuiz = null;
let quizQuestions = [];
let quizCurrentIndex = 0;
let quizAnswers = [];

// ── Navigation ──────────────────────────────────────────────────

window.showLearningView = function () {
  showView("learning");
  loadChapters();
};

window.showDictionaryView = function () {
  showView("dictionary");
  loadDictionary();
};

// ── Chapters and Lessons ─────────────────────────────────────────

async function loadChapters() {
  try {
    const chapters = await api.request("GET", "/structured-lessons/chapters");

    const container = document.getElementById("learning-content");
    container.innerHTML = "";

    if (!Array.isArray(chapters) || chapters.length === 0) {
      container.innerHTML =
        "<p>No structured lessons available at the moment.</p>";
      return;
    }

    chapters.forEach((chapter) => {
      const chapterEl = createChapterElement(chapter);
      container.insertAdjacentHTML("beforeend", chapterEl);
    });
  } catch (err) {
    console.error("Failed to load chapters:", err);
    document.getElementById("learning-content").innerHTML =
      "<p>Error loading lessons. Please try again.</p>";
  }
}

function createChapterElement(chapter) {
  return `
    <div class="chapter">
      <div class="chapter-header">
        <h3 class="chapter-title">${chapter.title}</h3>
        <p class="chapter-description">${chapter.description}</p>
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
        <h4 class="section-title">${section.title}</h4>
        <p class="section-description">${section.description}</p>
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
      <h5 class="lesson-title">${lesson.title}</h5>
      <div class="lesson-status">${statusText}</div>
    </div>
  `;
}

// ── Lesson View ─────────────────────────────────────────────────

async function openLesson(lessonId) {
  try {
    currentLesson = await api.request("GET", `/structured-lessons/${lessonId}`);

    if (!currentLesson.is_unlocked && currentLesson.prerequisites.length > 0) {
      alert(
        "This lesson is locked. Please complete the prerequisite lessons first."
      );
      return;
    }

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
  contentEl.innerHTML = currentLesson.content;

  const actionsEl = document.getElementById("lesson-actions");
  actionsEl.innerHTML = "";

  if (currentLesson.type === "reading") {
    if (!currentLesson.is_completed) {
      actionsEl.innerHTML = `
        <button class="btn-primary" onclick="completeLesson()">Mark as Complete</button>
      `;
    } else {
      actionsEl.innerHTML = `
        <p class="lesson-status">This reading lesson is completed.</p>
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

    // Check if passed (75% accuracy)
    if (results.accuracy >= 75) {
      // Mark lesson as completed if not already
      if (!currentLesson.is_completed) {
        await api.request(
          "POST",
          `/structured-lessons/${currentLesson.id}/complete`
        );
        currentLesson.is_completed = true;
      }

      alert(
        `Congratulations! You passed with ${results.accuracy}% accuracy. Lesson completed!`
      );
    } else {
      alert(
        `You scored ${results.accuracy}%. You need 75% to pass. Try again!`
      );
    }

    showView("learning");
    loadChapters();
  } catch (err) {
    console.error("Failed to get quiz results:", err);
    showView("learning");
  }
}

// ── Dictionary ──────────────────────────────────────────────────

async function loadDictionary(searchTerm = "") {
  const container = document.getElementById("dictionary-content");
  try {
    const params = searchTerm
      ? `?search=${encodeURIComponent(searchTerm)}`
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
  const wordDiv = document.createElement("div");
  wordDiv.className = "vocabulary-entry";

  wordDiv.innerHTML = `
    <div class="vocab-header">
      <div class="vocab-japanese">
        ${word.kanji || word.hiragana}
        ${
          word.katakana && word.katakana !== word.hiragana
            ? `(${word.katakana})`
            : ""
        }
      </div>
      <div class="vocab-romaji">${word.romaji}</div>
    </div>
    <div class="vocab-meaning">${word.meaning}</div>
    ${
      word.part_of_speech
        ? `<div class="vocab-pos">${word.part_of_speech}</div>`
        : ""
    }
    ${
      word.example_sentence
        ? `<div class="vocab-example">"${word.example_sentence}"</div>`
        : ""
    }
  `;

  return wordDiv;
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
  document
    .getElementById("dictionary-search")
    ?.addEventListener("input", (e) => {
      loadDictionary(e.target.value);
    });
});
