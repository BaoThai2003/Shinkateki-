// js/stats.js — Analytics dashboard with hand-drawn Chart.js charts
"use strict";

let weeklyChartInstance = null;

// ── Entry point ───────────────────────────────────────────────────

window.loadStats = async function () {
  const loading = document.getElementById("stats-loading");
  const content = document.getElementById("stats-content");

  if (loading) loading.classList.remove("hidden");
  if (content) content.style.opacity = "0.3";

  try {
    const dash = await api.get("/quiz/statistics");
    renderAll(dash);
  } catch (err) {
    console.error("Stats load failed", err);
  } finally {
    if (loading) loading.classList.add("hidden");
    if (content) content.style.opacity = "1";
  }
};

// ── Main render ───────────────────────────────────────────────────

function renderInstantStats(stats) {
  const container = document.getElementById("stats-instant");
  if (!container) return;

  if (!stats || !stats.totalQuestions) {
    container.innerHTML =
      '<p style="color:var(--fog);">No instant stats yet. Complete a quiz to see immediate performance.</p>';
    return;
  }

  const topCorrect = (stats.results || [])
    .filter((r) => r.isCorrect)
    .sort((a, b) => b.isCorrect - a.isCorrect)
    .slice(0, 3);
  const topWrong = (stats.results || [])
    .filter((r) => !r.isCorrect)
    .slice(0, 3);

  container.innerHTML = `
    <div class="stats-card">
      <h4>Instant Session Stats (${stats.type})</h4>
      <p><strong>Accuracy:</strong> ${stats.accuracy}%</p>
      <p><strong>Correct:</strong> ${stats.correctAnswers}</p>
      <p><strong>Incorrect:</strong> ${stats.wrongAnswers}</p>
      <p><strong>Session:</strong> ${stats.source}</p>
      <p><strong>Completed:</strong> ${new Date(
        stats.completedAt
      ).toLocaleString()}</p>
      <div>
        <strong>Best answered</strong>
        <ul>${topCorrect
          .map((q) => `<li>${q.characterId || q.question || "?"}</li>`)
          .join("")}</ul>
      </div>
      <div>
        <strong>Needs work</strong>
        <ul>${topWrong
          .map((q) => `<li>${q.characterId || q.question || "?"}</li>`)
          .join("")}</ul>
      </div>
    </div>
  `;
}

function renderCumulativeStats(dash) {
  const container = document.getElementById("stats-cumulative");
  if (!container) return;

  if (!dash || dash.totalTests === 0) {
    container.innerHTML =
      '<p style="color:var(--fog)">No cumulative stats available yet.</p>';
    return;
  }

  const historyHTML = (dash.history || [])
    .slice(0, 10)
    .map(
      (r) =>
        `<li>${r.test_type} - ${r.score}/${r.total_questions} (${new Date(
          r.timestamp
        ).toLocaleDateString()})</li>`
    )
    .join("");

  container.innerHTML = `
    <div class="stats-card">
      <h4>Cumulative Statistics</h4>
      <p><strong>Total Tests:</strong> ${dash.totalTests}</p>
      <p><strong>Average Score:</strong> ${dash.averageScore}%</p>
      <p><strong>Accuracy:</strong> ${dash.accuracy}%</p>
      <h5>Recent History</h5>
      <ul>${historyHTML}</ul>
    </div>
  `;
}

function _dayName(dow) {
  const days = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];
  return days[dow - 1] || "Unknown";
}

function renderAll(dash) {
  renderInstantStats(window.instantStats);
  renderCumulativeStats(dash);

  if (!dash || typeof dash !== "object") {
    document.getElementById("stats-content").innerHTML =
      '<p style="color:var(--fog)">No stats available yet. Complete a quiz to start tracking.</p>';
    return;
  }

  renderWeeklyChart(dash.weeklyTrend || []);
  renderWeaknessGrid(dash.weakest || []);
  renderTimeOfDay(dash.timeInsights || []);
  renderVelocity(dash.velocity || { status: "insufficient_data" });
}

// ── Weekly Accuracy Chart (vanilla Canvas, no library needed) ─────

function renderWeeklyChart(trend) {
  const canvas = document.getElementById("weekly-chart");
  if (!canvas) return;

  const ctx = canvas.getContext("2d");
  const W = canvas.offsetWidth || 700;
  const H = canvas.offsetHeight || 180;

  // Hi-DPI
  const dpr = window.devicePixelRatio || 1;
  canvas.width = W * dpr;
  canvas.height = H * dpr;
  canvas.style.width = W + "px";
  canvas.style.height = H + "px";
  ctx.scale(dpr, dpr);

  ctx.clearRect(0, 0, W, H);

  if (!trend.length) {
    ctx.fillStyle = "rgba(107,113,148,.5)";
    ctx.font = '14px "IBM Plex Mono", monospace';
    ctx.textAlign = "center";
    ctx.fillText("No data yet — complete a quiz to see trends.", W / 2, H / 2);
    return;
  }

  const pad = { top: 20, right: 20, bottom: 40, left: 48 };
  const cW = W - pad.left - pad.right;
  const cH = H - pad.top - pad.bottom;
  const n = trend.length;

  const xStep = n > 1 ? cW / (n - 1) : cW;
  const points = trend.map((d, i) => ({
    x: pad.left + (n > 1 ? i * xStep : cW / 2),
    y: pad.top + cH - (d.accuracy / 100) * cH,
    d,
  }));

  // ── Grid lines ──
  ctx.strokeStyle = "rgba(58,63,92,.6)";
  ctx.lineWidth = 1;
  [0, 25, 50, 75, 100].forEach((pct) => {
    const y = pad.top + cH - (pct / 100) * cH;
    ctx.beginPath();
    ctx.moveTo(pad.left, y);
    ctx.lineTo(pad.left + cW, y);
    ctx.stroke();

    ctx.fillStyle = "rgba(107,113,148,.7)";
    ctx.font = '10px "IBM Plex Mono", monospace';
    ctx.textAlign = "right";
    ctx.fillText(`${pct}%`, pad.left - 8, y + 4);
  });

  // ── Area fill under the line ──
  if (points.length > 1) {
    const grad = ctx.createLinearGradient(0, pad.top, 0, pad.top + cH);
    grad.addColorStop(0, "rgba(201,64,64,.35)");
    grad.addColorStop(1, "rgba(201,64,64,.02)");

    ctx.beginPath();
    ctx.moveTo(points[0].x, pad.top + cH);
    points.forEach((p) => ctx.lineTo(p.x, p.y));
    ctx.lineTo(points[points.length - 1].x, pad.top + cH);
    ctx.closePath();
    ctx.fillStyle = grad;
    ctx.fill();
  }

  // ── Line ──
  if (points.length > 1) {
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i < points.length; i++) {
      // Smooth bezier
      const cp1x = (points[i - 1].x + points[i].x) / 2;
      ctx.bezierCurveTo(
        cp1x,
        points[i - 1].y,
        cp1x,
        points[i].y,
        points[i].x,
        points[i].y
      );
    }
    ctx.strokeStyle = "rgba(201,64,64,.9)";
    ctx.lineWidth = 2.5;
    ctx.stroke();
  }

  // ── Dots + labels ──
  points.forEach((p) => {
    // Dot
    ctx.beginPath();
    ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
    ctx.fillStyle = "#c94040";
    ctx.fill();
    ctx.strokeStyle = "#0d0f14";
    ctx.lineWidth = 2;
    ctx.stroke();

    // Date label
    ctx.fillStyle = "rgba(107,113,148,.8)";
    ctx.font = '10px "IBM Plex Mono", monospace';
    ctx.textAlign = "center";
    const label = _shortDate(p.d.date);
    ctx.fillText(label, p.x, H - pad.bottom + 18);

    // Accuracy label above dot
    ctx.fillStyle = "rgba(200,196,176,.7)";
    ctx.font = '10px "IBM Plex Mono", monospace';
    ctx.fillText(`${p.d.accuracy}%`, p.x, p.y - 10);
  });
}

function _shortDate(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

// ── Weakness Grid ─────────────────────────────────────────────────

function renderWeaknessGrid(chars) {
  const grid = document.getElementById("weakness-grid");
  if (!grid) return;

  if (!chars.length) {
    grid.innerHTML =
      '<p style="color:var(--fog);font-size:.9rem;">No data yet.</p>';
    return;
  }

  grid.innerHTML = chars
    .map(
      (c) => `
    <div class="wk-card">
      <div class="wk-char">${c.character}</div>
      <div class="wk-romaji">${c.romaji}</div>
      <div class="wk-score ${c.difficulty_class}">
        ${Number(c.weakness_score).toFixed(1)}
      </div>
      <div style="font-size:.7rem;color:var(--fog);margin-top:.25rem;font-family:var(--font-mono)">
        ${_accuracyStr(c.correct_count, c.wrong_count)}
      </div>
    </div>
  `
    )
    .join("");
}

function _accuracyStr(correct, wrong) {
  const total = correct + wrong;
  if (!total) return "—";
  return `${Math.round((correct / total) * 100)}% (${total})`;
}

// ── Time of Day ───────────────────────────────────────────────────

function renderTimeOfDay(insights) {
  const grid = document.getElementById("tod-grid");
  if (!grid) return;

  if (!insights.length) {
    grid.innerHTML =
      '<p style="color:var(--fog);font-size:.9rem;">Study at different times to unlock this analysis.</p>';
    return;
  }

  const maxAcc = Math.max(...insights.map((i) => i.accuracy), 1);
  const best = insights[0]; // sorted by accuracy desc

  grid.innerHTML = insights
    .map((item) => {
      const isBest = item.hour === best.hour;
      const barPct = Math.round((item.accuracy / maxAcc) * 100);
      return `
      <div class="tod-card ${isBest ? "tod-best" : ""}">
        <div class="tod-hour">${_hourLabel(item.hour)}</div>
        <div class="tod-label">${item.label}</div>
        <div class="tod-acc">${item.accuracy}%</div>
        <div class="tod-bar-wrap">
          <div class="tod-bar" style="width:${barPct}%"></div>
        </div>
        <div style="font-size:.7rem;color:var(--fog);margin-top:.4rem;font-family:var(--font-mono)">
          ${item.totalAttempts} attempts · ${
        Math.round(item.avgResponseMs / 100) / 10
      }s avg
        </div>
        ${
          isBest
            ? '<div style="font-size:.7rem;color:#9de0b8;margin-top:.25rem">★ best time</div>'
            : ""
        }
      </div>
    `;
    })
    .join("");
}

function _hourLabel(hour) {
  const ampm = hour >= 12 ? "PM" : "AM";
  const h12 = hour % 12 || 12;
  return `${h12}:00 ${ampm}`;
}

// ── Learning Velocity ─────────────────────────────────────────────

function renderVelocity(v) {
  const card = document.getElementById("velocity-card");
  if (!card) return;

  if (!v || v.status === "insufficient_data") {
    card.innerHTML =
      '<p style="color:var(--fog);font-size:.9rem;">Complete at least 10 attempts to unlock velocity tracking.</p>';
    return;
  }

  const delta = v.improvementPct;
  const sign = delta >= 0 ? "+" : "";
  const trendCls = v.trend;
  const valCls = delta > 2 ? "up" : delta < -2 ? "down" : "";

  card.innerHTML = `
    <div class="vel-stat">
      <span class="vel-val">${v.firstHalfAccuracy}%</span>
      <span class="vel-lbl">Early accuracy</span>
    </div>
    <div class="vel-stat">
      <span class="vel-val">${v.secondHalfAccuracy}%</span>
      <span class="vel-lbl">Recent accuracy</span>
    </div>
    <div class="vel-stat">
      <span class="vel-val ${valCls}">${sign}${delta}%</span>
      <span class="vel-lbl">Change</span>
      <span class="vel-trend ${trendCls}">${trendCls}</span>
    </div>
  `;
}
