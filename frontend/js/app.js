// js/app.js — Shinkateki core: API client + view router
"use strict";

// ── Configuration ────────────────────────────────────────────────
const API_BASE = "http://localhost:8005/api";

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
    name === "profile"
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

    // Public lesson cards are no longer used because custom lesson creation has been removed.
  } catch (err) {
    console.warn("Home data load failed", err);
  }
}

function _hourLabel(hour) {
  const ampm = hour >= 12 ? "PM" : "AM";
  const h12 = hour % 12 || 12;
  return `${h12}:00 ${ampm}`;
}

// ── Lesson support ───────────────────────────────────────────────

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
      if (view === "learning") {
        showLearningView();
        return;
      }
      if (view === "dictionary") {
        showDictionaryView();
        return;
      }
      if (view === "profile") window.loadProfile?.();
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
