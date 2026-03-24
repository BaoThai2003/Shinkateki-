// js/profile.js — User profile and history dashboard
"use strict";

// ── Entry point ───────────────────────────────────────────────────

window.loadProfile = async function () {
  try {
    // Load user info
    const { user } = await api.get("/auth/me");
    renderUserInfo(user);

    // Load quiz history
    const quizHistory = await api.get("/profile/quiz-history");
    renderQuizHistory(quizHistory);

    // Load grade breakdown
    const gradeBreakdown = await api.get("/profile/grade-breakdown");
    renderGradeBreakdown(gradeBreakdown);

    // Load user's lessons
    const myLessons = await api.get("/lessons/my");
    renderProfileLessons(myLessons);
  } catch (err) {
    console.error("Profile load failed", err);
  }
};

// ── User Info ─────────────────────────────────────────────────────

function renderUserInfo(user) {
  setText("profile-username", user.username);
  setText("profile-email", user.email);
  setText("profile-score", `${user.total_score} pts`);
  setText("profile-level", user.level);
  setText("profile-joined", new Date(user.created_at).toLocaleDateString());
}

// ── Quiz History ──────────────────────────────────────────────────

function renderQuizHistory(history) {
  const container = document.getElementById("quiz-history-list");
  if (!container) return;

  if (!history || !history.length) {
    container.innerHTML =
      "<p style='color:var(--fog)'>No quiz history yet. Complete your first quiz!</p>";
    return;
  }

  container.innerHTML = history
    .map(
      (quiz) => `
    <div class="history-item">
      <div class="history-date">${new Date(
        quiz.date
      ).toLocaleDateString()}</div>
      <div class="history-details">
        <span class="history-questions">${quiz.questions_count} questions</span>
        <span class="history-accuracy">${quiz.accuracy}% accuracy</span>
        <span class="history-score">+${quiz.score} pts</span>
      </div>
      <div class="history-grade">${getGradeLetter(quiz.accuracy)}</div>
    </div>
  `
    )
    .join("");
}

// ── Grade Breakdown ───────────────────────────────────────────────

function renderGradeBreakdown(breakdown) {
  const container = document.getElementById("grade-breakdown");
  if (!container) return;

  if (!breakdown || !breakdown.length) {
    container.innerHTML = "<p style='color:var(--fog)'>No grade data yet.</p>";
    return;
  }

  const totalQuizzes = breakdown.reduce((sum, grade) => sum + grade.count, 0);

  container.innerHTML = breakdown
    .map((grade) => {
      const percentage =
        totalQuizzes > 0 ? Math.round((grade.count / totalQuizzes) * 100) : 0;
      return `
      <div class="grade-item">
        <div class="grade-letter">${grade.grade}</div>
        <div class="grade-bar">
          <div class="grade-fill" style="width: ${percentage}%"></div>
        </div>
        <div class="grade-count">${grade.count} quizzes (${percentage}%)</div>
      </div>
    `;
    })
    .join("");
}

// ── Profile Lessons ───────────────────────────────────────────────

function renderProfileLessons(lessons) {
  const container = document.getElementById("profile-lessons-list");
  if (!container) return;

  if (!lessons || !lessons.length) {
    container.innerHTML =
      "<p style='color:var(--fog)'>No lessons created yet.</p>";
    return;
  }

  container.innerHTML = lessons
    .map(
      (lesson) => `
    <div class="profile-lesson-item">
      <h4>${escapeHtml(lesson.title)}</h4>
      <p>${escapeHtml(lesson.content.substring(0, 100))}...</p>
      <div class="lesson-meta">
        <span class="lesson-visibility">${
          lesson.is_public ? "Public" : "Private"
        }</span>
        <span class="lesson-questions">${lesson.question_count} questions</span>
        <span class="lesson-date">${new Date(
          lesson.created_at
        ).toLocaleDateString()}</span>
      </div>
    </div>
  `
    )
    .join("");
}

// ── Utilities ─────────────────────────────────────────────────────

function getGradeLetter(accuracy) {
  if (accuracy >= 95) return "A+";
  if (accuracy >= 90) return "A";
  if (accuracy >= 85) return "A-";
  if (accuracy >= 80) return "B+";
  if (accuracy >= 75) return "B";
  if (accuracy >= 70) return "B-";
  if (accuracy >= 65) return "C+";
  if (accuracy >= 60) return "C";
  if (accuracy >= 55) return "C-";
  if (accuracy >= 50) return "D";
  return "F";
}

function escapeHtml(str = "") {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
