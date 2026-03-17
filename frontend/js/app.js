// js/app.js — Shinkateki core: API client + view router
'use strict';

// ── Configuration ────────────────────────────────────────────────
const API_BASE = 'http://localhost:3000/api';

// ── Shared Application State ─────────────────────────────────────
window.App = {
  token:   localStorage.getItem('shinkateki_token'),
  user:    JSON.parse(localStorage.getItem('shinkateki_user') || 'null'),

  setAuth(token, user) {
    this.token = token;
    this.user  = user;
    localStorage.setItem('shinkateki_token', token);
    localStorage.setItem('shinkateki_user',  JSON.stringify(user));
  },

  clearAuth() {
    this.token = null;
    this.user  = null;
    localStorage.removeItem('shinkateki_token');
    localStorage.removeItem('shinkateki_user');
  },

  isLoggedIn() { return !!this.token; },
};

// ── API Helper ───────────────────────────────────────────────────

window.api = {
  async request(method, path, body = null) {
    const opts = {
      method,
      headers: { 'Content-Type': 'application/json' },
    };
    if (App.token) opts.headers['Authorization'] = `Bearer ${App.token}`;
    if (body) opts.body = JSON.stringify(body);

    const res  = await fetch(`${API_BASE}${path}`, opts);
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      throw Object.assign(new Error(data.error || 'Request failed'), { status: res.status, data });
    }
    return data;
  },

  get(path)          { return this.request('GET',    path);       },
  post(path, body)   { return this.request('POST',   path, body); },
};

// ── View Router ──────────────────────────────────────────────────

function showScreen(id) {
  ['loading-screen', 'auth-screen', 'app-screen'].forEach(s => {
    const el = document.getElementById(s);
    if (el) el.classList.toggle('hidden', s !== id);
  });
}

function showView(name) {
  document.querySelectorAll('.view').forEach(v => v.classList.add('hidden'));
  const target = document.getElementById(`view-${name}`);
  if (target) target.classList.remove('hidden');

  document.querySelectorAll('.nav-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.view === name);
  });
}

// ── Bootstrap ────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
  // Let loading animation play
  await delay(2000);

  if (App.isLoggedIn()) {
    try {
      // Verify token still valid
      const { user } = await api.get('/auth/me');
      App.setAuth(App.token, user);
      enterApp();
    } catch {
      App.clearAuth();
      showScreen('auth-screen');
    }
  } else {
    showScreen('auth-screen');
  }
});

// Called after successful login/register
window.enterApp = function () {
  showScreen('app-screen');
  updateNavUser();
  showView('home');
  loadHomeData();
};

function updateNavUser() {
  const u = App.user;
  if (!u) return;
  document.getElementById('nav-username').textContent = u.username;
  document.getElementById('nav-score').textContent    = `${u.total_score ?? 0} pts`;
  document.getElementById('hero-username').textContent = u.username;
  document.getElementById('hero-greeting').textContent = timeGreeting();
}

function timeGreeting() {
  const h = new Date().getHours();
  if (h < 5)  return 'おやすみ';
  if (h < 12) return 'おはよう';
  if (h < 17) return 'こんにちは';
  return 'こんばんは';
}

// ── Home data ────────────────────────────────────────────────────

async function loadHomeData() {
  try {
    const dash = await api.get('/stats/dashboard');
    const { overall, optimalStudyTime, recommendations } = dash;

    // Mini stats
    setText('ms-accuracy', `${overall.overallAccuracy}%`);
    setText('ms-mastered', overall.masteredCount);
    setText('ms-attempts', overall.totalAttempts);

    // Optimal study time
    const otDiv = document.getElementById('optimal-time-display');
    if (optimalStudyTime) {
      otDiv.innerHTML = `
        <div class="ot-time">${_hourLabel(optimalStudyTime.hour)}</div>
        <div class="ot-label">${optimalStudyTime.label}</div>
        <div class="ot-accuracy">${optimalStudyTime.accuracy}% accuracy</div>
      `;
    }

    // Recommendations
    const recList = document.getElementById('recommendations-list');
    recList.innerHTML = recommendations
      .map(r => `<div class="rec-item ${r.type}">${r.text}</div>`)
      .join('');

  } catch (err) {
    console.warn('Home data load failed', err);
  }
}

function _hourLabel(hour) {
  const ampm = hour >= 12 ? 'PM' : 'AM';
  const h12  = hour % 12 || 12;
  return `${h12}:00 ${ampm}`;
}

// ── Nav wiring ───────────────────────────────────────────────────

document.querySelectorAll('.nav-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const view = btn.dataset.view;
    showView(view);
    if (view === 'home')  loadHomeData();
    if (view === 'stats') window.loadStats?.();
  });
});

document.getElementById('btn-logout')?.addEventListener('click', () => {
  App.clearAuth();
  showScreen('auth-screen');
});

document.getElementById('btn-start-quiz')?.addEventListener('click', () => {
  const type = document.querySelector('input[name="quiz-type"]:checked')?.value || '';
  window.startQuiz?.(type);
});

// ── Utilities ────────────────────────────────────────────────────

function setText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

function delay(ms) { return new Promise(r => setTimeout(r, ms)); }

window.showView   = showView;
window.delay      = delay;
window.setText    = setText;
