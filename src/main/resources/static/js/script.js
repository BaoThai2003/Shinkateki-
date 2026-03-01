const authModal = document.getElementById("authModal");
const mainContent = document.getElementById("mainContent");
const loginForm = document.getElementById("loginForm");
const registerForm = document.getElementById("registerForm");
const toggleRegister = document.getElementById("toggleRegister");
const toggleLogin = document.getElementById("toggleLogin");
const logoutBtn = document.getElementById("logoutBtn");
const hamburger = document.getElementById("hamburger");
const navbarMenu = document.getElementById("navbarMenu");
const navLinks = document.querySelectorAll(".nav-link");
const darkModeToggle = document.getElementById("darkModeToggle");
const userGreeting = document.getElementById("userGreeting");
const startQuizBtn = document.getElementById("startQuizBtn");
const startQuizActualBtn = document.getElementById("startQuizActualBtn");
const quizIntro = document.getElementById("quizIntro");
const quizQuestion = document.getElementById("quizQuestion");
const quizResult = document.getElementById("quizResult");
const quitQuizBtn = document.getElementById("quitQuizBtn");
const nextQuestionBtn = document.getElementById("nextQuestionBtn");
const retakeQuizBtn = document.getElementById("retakeQuizBtn");
const backToDashboardBtn = document.getElementById("backToDashboardBtn");
const optionsContainer = document.getElementById("optionsContainer");
const characterQuestion = document.getElementById("characterQuestion");
const timerValue = document.getElementById("timerValue");
const questionNumber = document.getElementById("questionNumber");
const reviewWeakBtn = document.getElementById("reviewWeakBtn");
const practiceBtn = document.getElementById("practiceBtn");
const viewStatsBtn = document.getElementById("viewStatsBtn");

// State
let currentUser = null;
let quizStarted = false;
let currentQuestionIndex = 0;
let quizScore = 0;
let quizResponses = [];
let timerInterval = null;

// Sample characters for demo
const characters = [
  { id: 1, char: "あ", romaji: "a", type: "hiragana", weakness: 2 },
  { id: 2, char: "い", romaji: "i", type: "hiragana", weakness: 1 },
  { id: 3, char: "う", romaji: "u", type: "hiragana", weakness: 3 },
  { id: 4, char: "え", romaji: "e", type: "hiragana", weakness: 2 },
  { id: 5, char: "お", romaji: "o", type: "hiragana", weakness: 1 },
  { id: 6, char: "か", romaji: "ka", type: "hiragana", weakness: 4 },
  { id: 7, char: "き", romaji: "ki", type: "hiragana", weakness: 5 },
  { id: 8, char: "く", romaji: "ku", type: "hiragana", weakness: 3 },
  { id: 9, char: "け", romaji: "ke", type: "hiragana", weakness: 2 },
  { id: 10, char: "こ", romaji: "ko", type: "hiragana", weakness: 1 },
];

// Authentication
function toggleAuthForms() {
  loginForm.classList.toggle("auth-form-active");
  registerForm.classList.toggle("auth-form-active");
}
toggleRegister.addEventListener("click", (e) => {
  e.preventDefault();
  toggleAuthForms();
});
toggleLogin.addEventListener("click", (e) => {
  e.preventDefault();
  toggleAuthForms();
});

// Login Form Submission
document.querySelectorAll("form")[0].addEventListener("submit", (e) => {
  e.preventDefault();
  const email = document.getElementById("loginEmail").value;
  // Simulate login
  currentUser = {
    username: email.split("@")[0] || email,
    email: email,
    level: "Beginner",
  };
  loginSuccessful();
});

// Register Form Submission
document.querySelectorAll("form")[1].addEventListener("submit", (e) => {
  e.preventDefault();
  const username = document.getElementById("registerUsername").value;
  const email = document.getElementById("registerEmail").value;

  // Simulate registration
  currentUser = {
    username: username,
    email: email,
    level: "Beginner",
  };

  loginSuccessful();
});

function loginSuccessful() {
  authModal.classList.remove("modal-active");
  mainContent.style.display = "block";
  userGreeting.textContent = `Welcome, ${currentUser.username}!`;
  document.getElementById("profileUsername").textContent = currentUser.username;
  document.getElementById("profileEmail").textContent = currentUser.email;
  document.getElementById("profileLevel").textContent = currentUser.level;
  updateDashboardStats();
}

// Navigation
navLinks.forEach((link) => {
  link.addEventListener("click", (e) => {
    e.preventDefault();
    // Remove active class from all links
    navLinks.forEach((l) => l.classList.remove("active"));
    link.classList.add("active");
    // Hide all sections
    document.querySelectorAll(".section").forEach((section) => {
      section.classList.remove("section-active");
    });
    // Show selected section
    const sectionId = link.getAttribute("data-section");
    const section = document.getElementById(sectionId);
    section.classList.add("section-active");
    // Close mobile menu
    navbarMenu.classList.remove("active");
  });
});

hamburger.addEventListener("click", () => {
  navbarMenu.classList.toggle("active");
});

// Logout
logoutBtn.addEventListener("click", () => {
  currentUser = null;
  mainContent.style.display = "none";
  authModal.classList.add("modal-active");
  loginForm.classList.add("auth-form-active");
  registerForm.classList.remove("auth-form-active");
  navbarMenu.classList.remove("active");
});

// Dark Mode
darkModeToggle.addEventListener("change", () => {
  document.body.classList.toggle("dark-mode");
  localStorage.setItem(
    "darkMode",
    document.body.classList.contains("dark-mode")
  );
});

// Load dark mode preference
if (localStorage.getItem("darkMode") === "true") {
  document.body.classList.add("dark-mode");
  darkModeToggle.checked = true;
}

// Dashboard
function updateDashboardStats() {
  document.getElementById("streakValue").textContent = "5";
  document.getElementById("accuracyValue").textContent = "85%";
  document.getElementById("charactersValue").textContent = "46";
  document.getElementById("timeValue").textContent = "5.5h";
  document.getElementById("hiraganaPercent").textContent = "60%";
  document.getElementById("katakanaPercent").textContent = "40%";
  document.getElementById("hiraganaFill").style.width = "60%";
  document.getElementById("katakanaFill").style.width = "40%";
}

viewStatsBtn.addEventListener("click", () => {
  document.querySelector('.nav-link[data-section="stats"]').click();
});

// Quiz Functionality
let quizQuestions = [];
let timerSeconds = 30;

// Generate weighted quiz questions
function generateQuizQuestions() {
  const weak = characters.filter((c) => c.weakness >= 4);
  const medium = characters.filter((c) => c.weakness >= 2 && c.weakness < 4);
  const strong = characters.filter((c) => c.weakness < 2);
  quizQuestions = [];

  // Add 70% weak, 20% medium, 10% strong
  const weakCount = Math.ceil(10 * 0.7);
  const mediumCount = Math.ceil(10 * 0.2);
  const strongCount = 10 - weakCount - mediumCount;

  quizQuestions.push(...shuffleArray(weak).slice(0, weakCount));
  quizQuestions.push(...shuffleArray(medium).slice(0, mediumCount));
  quizQuestions.push(...shuffleArray(strong).slice(0, strongCount));

  quizQuestions = shuffleArray(quizQuestions);
}

function generateOptions(correctChar) {
  const options = [correctChar];

  // Add 3 random incorrect options
  while (options.length < 4) {
    const random = characters[Math.floor(Math.random() * characters.length)];
    if (!options.find((c) => c.id === random.id)) {
      options.push(random);
    }
  }

  return shuffleArray(options);
}

function displayQuestion(index) {
  if (index >= quizQuestions.length) {
    showQuizSummary();
    return;
  }

  const question = quizQuestions[index];
  characterQuestion.textContent = question.char;
  questionNumber.textContent = index + 1;
  document.getElementById("totalQuestions").textContent = quizQuestions.length;

  const fillPercent = ((index + 1) / quizQuestions.length) * 100;
  document.getElementById("quizProgressFill").style.width = fillPercent + "%";

  // Generate and display options
  const options = generateOptions(question);
  optionsContainer.innerHTML = "";

  options.forEach((option) => {
    const optionBtn = document.createElement("button");
    optionBtn.className = "option";
    optionBtn.textContent = option.romaji;
    optionBtn.addEventListener("click", () => selectAnswer(option, question));
    optionsContainer.appendChild(optionBtn);
  });

  startTimer();
}

function selectAnswer(selectedChar, correctChar) {
  clearInterval(timerInterval);
  const isCorrect = selectedChar.id === correctChar.id;

  if (isCorrect) {
    quizScore++;
    document.getElementById("resultFeedback").textContent = "✓ Correct!";
    document.getElementById("resultFeedback").className =
      "result-feedback correct";
  } else {
    document.getElementById(
      "resultFeedback"
    ).textContent = `✗ Incorrect! It was ${correctChar.romaji}`;
    document.getElementById("resultFeedback").className =
      "result-feedback incorrect";
  }

  quizResponses.push({
    character: correctChar.char,
    selected: selectedChar.romaji,
    correct: isCorrect,
    time: 30 - parseInt(timerValue.textContent),
  });

  quizQuestion.style.display = "none";
  quizResult.style.display = "block";
  nextQuestionBtn.style.display = "inline-flex";

  // Disable all option buttons
  document.querySelectorAll(".option").forEach((btn) => {
    btn.disabled = true;
  });

  // Show correct/incorrect styling
  document.querySelectorAll(".option").forEach((btn) => {
    if (btn.textContent === correctChar.romaji) {
      btn.classList.add("correct");
    } else if (btn.textContent === selectedChar.romaji) {
      btn.classList.add("incorrect");
    }
  });
}

function startTimer() {
  timerSeconds = 30;
  timerValue.textContent = timerSeconds;

  timerInterval = setInterval(() => {
    timerSeconds--;
    timerValue.textContent = timerSeconds;

    if (timerSeconds <= 0) {
      clearInterval(timerInterval);
      document.getElementById("resultFeedback").textContent = "⏱ Time's up!";
      document.getElementById("resultFeedback").className =
        "result-feedback incorrect";
      quizQuestion.style.display = "none";
      quizResult.style.display = "block";
      nextQuestionBtn.style.display = "inline-flex";

      document
        .querySelectorAll(".option")
        .forEach((btn) => (btn.disabled = true));
    }
  }, 1000);
}

function showQuizSummary() {
  nextQuestionBtn.style.display = "none";
  document.getElementById("quizSummary").style.display = "block";
  document.getElementById(
    "finalScore"
  ).textContent = `${quizScore}/${quizQuestions.length}`;

  const accuracy = Math.round((quizScore / quizQuestions.length) * 100);
  document.getElementById("finalAccuracy").textContent = `${accuracy}%`;

  const avgTime =
    quizResponses.length > 0
      ? Math.round(
          quizResponses.reduce((sum, r) => sum + r.time, 0) /
            quizResponses.length
        )
      : 0;
  document.getElementById("avgTime").textContent = `${avgTime}s`;
}

startQuizBtn.addEventListener("click", () => {
  document.querySelector('.nav-link[data-section="quiz"]').click();
});

startQuizActualBtn.addEventListener("click", () => {
  quizStarted = true;
  quizScore = 0;
  quizResponses = [];
  currentQuestionIndex = 0;

  generateQuizQuestions();

  quizIntro.style.display = "none";
  quizQuestion.style.display = "block";
  quizResult.style.display = "none";
  document.getElementById("quizSummary").style.display = "none";
  nextQuestionBtn.style.display = "none";

  displayQuestion(0);
});

nextQuestionBtn.addEventListener("click", () => {
  currentQuestionIndex++;
  quizQuestion.style.display = "block";
  quizResult.style.display = "none";
  displayQuestion(currentQuestionIndex);
});

quitQuizBtn.addEventListener("click", () => {
  if (confirm("Are you sure you want to quit the quiz?")) {
    clearInterval(timerInterval);
    quizStarted = false;
    quizIntro.style.display = "block";
    quizQuestion.style.display = "none";
    quizResult.style.display = "none";
    document.getElementById("quizSummary").style.display = "none";
  }
});

retakeQuizBtn.addEventListener("click", () => {
  quizScore = 0;
  quizResponses = [];
  currentQuestionIndex = 0;

  generateQuizQuestions();

  quizIntro.style.display = "none";
  quizQuestion.style.display = "block";
  quizResult.style.display = "none";
  document.getElementById("quizSummary").style.display = "none";
  nextQuestionBtn.style.display = "none";

  displayQuestion(0);
});

backToDashboardBtn.addEventListener("click", () => {
  document.querySelector('.nav-link[data-section="dashboard"]').click();
});

// Practice & Review Functions
reviewWeakBtn.addEventListener("click", () => {
  alert("Review weak areas feature coming soon!");
});

practiceBtn.addEventListener("click", () => {
  alert("Practice mode coming soon!");
});

// Utility Functions
function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

// Local Storage
// Save user preferences
window.addEventListener("beforeunload", () => {
  if (currentUser) {
    localStorage.setItem("shinkateki_user", JSON.stringify(currentUser));
  }
});

// Load user if exists
function loadUserFromStorage() {
  const savedUser = localStorage.getItem("shinkateki_user");
  if (savedUser) {
    currentUser = JSON.parse(savedUser);
    loginSuccessful();
  }
}

// Initialize
document.addEventListener("DOMContentLoaded", () => {
  loadUserFromStorage();
});
