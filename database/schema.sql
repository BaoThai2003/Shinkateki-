-- ============================================================
-- SHINKATEKI (進化的) — Adaptive Japanese Learning System
-- Database Schema and Seed Data
-- Version: 2.1.0
--
-- Languages: Vietnamese (default) and English
-- Curriculum: Chapter 1 (Alphabet) — Lessons 1–5 (sample seed)
-- Database: MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS shinkateki CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE shinkateki;

-- ===========================================================================
-- TABLE DEFINITIONS
-- ===========================================================================

-- Every learner needs a home. This table stores user accounts along with
-- language preference, current level, and engagement metrics like streak days.
CREATE TABLE users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  UNIQUE NOT NULL,
    email         VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255)        NOT NULL,
    full_name     VARCHAR(100),
    language      ENUM('vi', 'en')    DEFAULT 'vi',
    level         INT                 DEFAULT 1,
    total_score   INT                 DEFAULT 0,
    streak_days   INT                 DEFAULT 0,
    last_active   TIMESTAMP           NULL,
    last_login    TIMESTAMP           NULL,
    is_active     BOOLEAN             DEFAULT TRUE,
    created_at    TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP           DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Structured lessons are the backbone of the curriculum — predefined,
-- ordered, and capable of unlocking subsequent content once a threshold is met.
CREATE TABLE structured_lessons (
    id                     INT AUTO_INCREMENT PRIMARY KEY,
    lesson_number          INT          NOT NULL,
    title_vi               VARCHAR(255) NOT NULL,
    title_en               VARCHAR(255) NOT NULL,
    content_vi             LONGTEXT     NOT NULL,
    content_en             LONGTEXT     NOT NULL,
    lesson_type            ENUM('introduction', 'character_learning', 'practice', 'review', 'final_quiz') NOT NULL,
    script_type            ENUM('hiragana', 'katakana', 'kanji', 'both') DEFAULT 'both',
    order_index            INT          NOT NULL,
    is_active              BOOLEAN      DEFAULT TRUE,
    prerequisite_lesson_id INT          NULL,
    unlock_threshold       DECIMAL(5,2) DEFAULT 0.75,
    unlocks                JSON,
    created_at             TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (prerequisite_lesson_id) REFERENCES structured_lessons(id) ON DELETE SET NULL,
    INDEX idx_lesson_number (lesson_number),
    INDEX idx_lesson_type   (lesson_type)
);

-- User-created lessons let learners build and share their own content.
-- Pairing these with lesson_questions gives them a lightweight quiz layer.
CREATE TABLE lessons (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT          NOT NULL,
    title      VARCHAR(255) NOT NULL,
    content    LONGTEXT     NOT NULL,
    is_public  BOOLEAN      DEFAULT FALSE,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_created (user_id, created_at)
);

-- Simple four-option questions attached to user-created lessons.
CREATE TABLE lesson_questions (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id      INT         NOT NULL,
    question_text  TEXT        NOT NULL,
    option_a       VARCHAR(500) NOT NULL,
    option_b       VARCHAR(500) NOT NULL,
    option_c       VARCHAR(500) NOT NULL,
    option_d       VARCHAR(500) NOT NULL,
    correct_option CHAR(1)     NOT NULL CHECK (correct_option IN ('a','b','c','d')),
    created_at     TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
);

-- Characters are the atoms of the writing system — each row captures a
-- single kana or kanji along with its readings, mnemonics, and audio link.
CREATE TABLE characters (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    kana             VARCHAR(10)  NOT NULL,
    romaji           VARCHAR(50)  NOT NULL,
    hiragana         VARCHAR(10),
    katakana         VARCHAR(10),
    kanji            VARCHAR(10),
    type             ENUM('hiragana','katakana','kanji') DEFAULT 'hiragana',
    group_name       VARCHAR(50),
    difficulty       ENUM('beginner','intermediate','advanced') DEFAULT 'beginner',
    stroke_order     TEXT,
    mnemonic_vi      TEXT,
    mnemonic_en      TEXT,
    audio_url        VARCHAR(500),
    position_in_group INT,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_kana     (kana),
    INDEX idx_romaji   (romaji),
    INDEX idx_hiragana (hiragana),
    INDEX idx_katakana (katakana),
    INDEX idx_kanji    (kanji),
    INDEX idx_type     (type)
);

-- The adaptive engine lives here. Weakness score and difficulty class are
-- updated after every session so the system knows what to surface next.
CREATE TABLE performance_stats (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT            NOT NULL,
    character_id     INT            NOT NULL,
    weakness_score   DECIMAL(5,4)   DEFAULT 0.0000,
    difficulty_class ENUM('strong','medium','weak') DEFAULT 'medium',
    correct_count    INT            DEFAULT 0,
    wrong_count      INT            DEFAULT 0,
    total_attempts   INT            DEFAULT 0,
    avg_response_ms  INT            DEFAULT 0,
    mistake_streak   INT            DEFAULT 0,
    last_reviewed    TIMESTAMP      NULL,
    next_review      TIMESTAMP      NULL,
    created_at       TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)      REFERENCES users(id)      ON DELETE CASCADE,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_character (user_id, character_id),
    INDEX idx_user_weakness (user_id, weakness_score),
    INDEX idx_next_review   (next_review)
);

-- Every quiz attempt is logged here so the adaptive engine can spot
-- patterns — which characters slow a learner down, and when.
CREATE TABLE attempts (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT          NOT NULL,
    character_id   INT          NOT NULL,
    is_correct     BOOLEAN      NOT NULL,
    response_time  INT          NOT NULL,  -- milliseconds
    mistake_streak INT          DEFAULT 0,
    hour_of_day    INT          NOT NULL,  -- 0–23
    session_id     VARCHAR(100) NOT NULL,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)      REFERENCES users(id)      ON DELETE CASCADE,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    INDEX idx_user_session (user_id, session_id),
    INDEX idx_created_at   (created_at)
);

-- Aggregated hourly performance — useful for surfacing study-time
-- recommendations ("you tend to score better before 10 AM").
CREATE TABLE time_of_day_stats (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT          NOT NULL,
    hour_slot      INT          NOT NULL CHECK (hour_slot >= 0 AND hour_slot <= 23),
    total_attempts INT          DEFAULT 0,
    correct_count  INT          DEFAULT 0,
    avg_response_ms INT         DEFAULT 0,
    accuracy_rate  DECIMAL(3,2) DEFAULT 0.00,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_hour (user_id, hour_slot)
);

-- The vocabulary table is the dictionary at the heart of Shinkateki.
-- Each word links back to a lesson and, optionally, a specific character,
-- and carries full-text search support across all reading forms.
CREATE TABLE vocabulary (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id             INT NULL,
    character_id          INT NULL,
    word_kanji            VARCHAR(100),
    word_hiragana         VARCHAR(100),
    word_katakana         VARCHAR(100),
    romaji                VARCHAR(100) NOT NULL,
    meaning_vi            VARCHAR(255) NOT NULL,
    meaning_en            VARCHAR(255) NOT NULL,
    detailed_explanation_vi LONGTEXT,
    detailed_explanation_en LONGTEXT,
    part_of_speech        ENUM('noun','verb','adjective','adverb','particle','expression','conjunction') NOT NULL,
    jlpt_level            ENUM('N5','N4','N3','N2','N1') DEFAULT 'N5',
    difficulty_level      ENUM('beginner','intermediate','advanced') DEFAULT 'beginner',
    audio_url             VARCHAR(500),
    order_index           INT       NOT NULL,
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id)    REFERENCES lessons(id)    ON DELETE SET NULL,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE SET NULL,
    FULLTEXT INDEX ft_word_search     (word_hiragana, word_katakana, romaji, word_kanji, meaning_vi, meaning_en),
    INDEX idx_romaji_vocab   (romaji),
    INDEX idx_hiragana_vocab (word_hiragana),
    INDEX idx_katakana_vocab (word_katakana),
    INDEX idx_kanji_vocab    (word_kanji)
);

-- Example sentences bring vocabulary to life, showing each word in context
-- alongside its romaji reading, translations, and grammar notes.
CREATE TABLE examples (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    vocabulary_id         INT  NOT NULL,
    jp_sentence_hiragana  TEXT NOT NULL,
    jp_sentence_kanji     TEXT,
    jp_sentence_katakana  TEXT,
    romaji_sentence       TEXT NOT NULL,
    vi_meaning            TEXT NOT NULL,
    en_meaning            TEXT NOT NULL,
    grammar_note_vi       TEXT,
    grammar_note_en       TEXT,
    order_index           INT  NOT NULL,
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vocabulary_id) REFERENCES vocabulary(id) ON DELETE CASCADE
);

-- Structured quiz questions support multiple formats — from simple
-- multiple-choice to romaji-to-kana conversion challenges.
CREATE TABLE quiz_questions (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id        INT          NOT NULL,
    question_type    ENUM('multiple_choice','romaji_to_kana','kana_to_meaning','sentence_completion') NOT NULL,
    question_vi      TEXT         NOT NULL,
    question_en      TEXT         NOT NULL,
    romaji           VARCHAR(100),
    options_vi       JSON         NOT NULL,
    options_en       JSON         NOT NULL,
    correct_answer_vi VARCHAR(500) NOT NULL,
    correct_answer_en VARCHAR(500) NOT NULL,
    explanation_vi   TEXT,
    explanation_en   TEXT,
    difficulty_level ENUM('easy','medium','hard') DEFAULT 'easy',
    points           INT          DEFAULT 1,
    order_index      INT          NOT NULL,
    created_at       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
);

-- Tracks how far each user has progressed through any given lesson,
-- including their best score, time invested, and unlock status.
CREATE TABLE user_progress (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT          NOT NULL,
    lesson_id    INT          NOT NULL,
    completed    BOOLEAN      DEFAULT FALSE,
    score        DECIMAL(5,2) NULL,
    time_spent   INT          DEFAULT 0,
    attempts     INT          DEFAULT 0,
    last_attempt TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_unlocked  BOOLEAN      DEFAULT FALSE,
    created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_lesson (user_id, lesson_id),
    INDEX idx_user_completed (user_id, completed)
);

-- A lightweight completion record for user-created lessons,
-- separate from structured-lesson progress so neither clutters the other.
CREATE TABLE user_lesson_progress (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT       NOT NULL,
    lesson_id    INT       NOT NULL,
    is_completed BOOLEAN   DEFAULT FALSE,
    completed_at TIMESTAMP NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)  REFERENCES users(id)   ON DELETE CASCADE,
    FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_lesson_progress (user_id, lesson_id)
);

-- Individual quiz answer records, storing what the user picked,
-- whether they got it right, and how long they took to decide.
CREATE TABLE user_quiz_attempts (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT          NOT NULL,
    lesson_id        INT          NOT NULL,
    question_id      INT          NOT NULL,
    selected_answer  VARCHAR(500) NOT NULL,
    is_correct       BOOLEAN      NOT NULL,
    response_time_ms INT          NOT NULL,
    attempt_date     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)     REFERENCES users(id)          ON DELETE CASCADE,
    FOREIGN KEY (lesson_id)   REFERENCES lessons(id)        ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES quiz_questions(id) ON DELETE CASCADE,
    INDEX idx_user_lesson  (user_id, lesson_id),
    INDEX idx_attempt_date (attempt_date)
);

-- A high-level summary of each completed quiz session — handy for
-- dashboards that show accuracy trends over time.
CREATE TABLE quiz_sessions (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT          NOT NULL,
    session_type     VARCHAR(50)  NOT NULL,
    lesson_id        INT          NULL,
    total_questions  INT          NOT NULL,
    correct_answers  INT          NOT NULL,
    accuracy         DECIMAL(5,2) NOT NULL,
    created_at       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)   REFERENCES users(id)   ON DELETE CASCADE,
    FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    INDEX idx_user_created (user_id, created_at)
);

-- Search history gives the app context for smart autocomplete and
-- helps identify which terms learners struggle to find or spell.
CREATE TABLE search_history (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT          NULL,
    search_term VARCHAR(255) NOT NULL,
    search_type ENUM('hiragana','katakana','kanji','romaji','meaning') NOT NULL,
    result_count INT         DEFAULT 0,
    searched_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_search_term  (search_term),
    INDEX idx_user_search  (user_id, searched_at)
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CHAPTERS & SECTIONS — Organizational layers grouping structured lessons
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE TABLE chapters (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    title_en       VARCHAR(255) NOT NULL,
    title_vi       VARCHAR(255) NOT NULL,
    description_en TEXT,
    description_vi TEXT,
    order_index    INT NOT NULL,
    is_active      BOOLEAN DEFAULT TRUE,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_order (order_index)
);

CREATE TABLE sections (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    chapter_id     INT NOT NULL,
    title_en       VARCHAR(255) NOT NULL,
    title_vi       VARCHAR(255) NOT NULL,
    description_en TEXT,
    description_vi TEXT,
    order_index    INT NOT NULL,
    is_active      BOOLEAN DEFAULT TRUE,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE,
    INDEX idx_chapter (chapter_id),
    INDEX idx_order (order_index)
);

-- Add section_id to structured_lessons
ALTER TABLE structured_lessons ADD COLUMN section_id INT NULL;
ALTER TABLE structured_lessons ADD FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE SET NULL;

-- ===========================================================================
-- SEED DATA
-- ===========================================================================

-- A default test account so developers can explore the app right away.
INSERT INTO users (username, email, password_hash, full_name, language) VALUES
('testuser', 'test@example.com', '$2b$10$dummy.hash.for.test.user', 'Test User', 'en');

-- INSERT CHAPTERS
INSERT INTO chapters (title_en, title_vi, description_en, description_vi, order_index) VALUES
('Chapter 1: Alphabet Basics', 'Chapter 1: Cơ Bản Bảng Chữ Cái', 'Master the fundamental hiragana and katakana', 'Làm chủ bảng chữ cái cơ bản', 1),
('Chapter 2: Kanji Fundamentals', 'Chapter 2: Kanji Cơ Bản', 'Introduction to basic kanji characters', 'Giới thiệu về các ký tự kanji cơ bản', 2);

-- INSERT SECTIONS FOR CHAPTER 1
INSERT INTO sections (chapter_id, title_en, title_vi, description_en, description_vi, order_index) VALUES
(1, 'Section 1.1: Vowels', 'Section 1.1: Nguyên Âm', 'Learn hiragana and katakana vowels', 'Học nguyên âm hiragana và katakana', 1),
(1, 'Section 1.2: Consonants', 'Section 1.2: Phụ Âm', 'K, S, T rows and consonant combinations', 'Hàng K, S, T và các kết hợp phụ âm', 2);

-- INSERT KANJI CHARACTERS
INSERT INTO characters (kana, romaji, hiragana, katakana, kanji, type, group_name, difficulty, mnemonic_vi, mnemonic_en) VALUES
('赤', 'aka', NULL, NULL, '赤', 'kanji', 'colors', 'beginner', 'Chữ cộng chữ với - là cái túi, màu đỏ', 'Radical + fire stroke = red'),
('青', 'ao', NULL, NULL, '青', 'kanji', 'colors', 'beginner', 'Giống hình khu vườn, xanh lá', 'Looks like growing plant = blue/green'),
('木', 'ki', NULL, NULL, '木', 'kanji', 'nature', 'beginner', '3 gốc cây = rừng', 'Single tree character'),
('火', 'hi', NULL, NULL, '火', 'kanji', 'nature', 'beginner', 'Hình lửa với đầu lửa', 'Looks like flames, fire'),
('水', 'mizu', NULL, NULL, '水', 'kanji', 'nature', 'beginner', 'Ba nháy = nước chảy', 'Three lines = flowing water'),
('日', 'hi', NULL, NULL, '日', 'kanji', 'time', 'beginner', 'Hộp vuông = mặt trời', 'Square = sun'),
('月', 'tsuki', NULL, NULL, '月', 'kanji', 'time', 'beginner', 'Cửa sổ = mặt trăng', 'Window = moon'),
('人', 'hito', NULL, NULL, '人', 'kanji', 'people', 'beginner', 'Hình người đứng = con người', 'Looks like standing person'),
('子', 'ko', NULL, NULL, '子', 'kanji', 'people', 'beginner', 'Hình trẻ em ngồi = con', 'Child sitting = child'),
('女', 'onna', NULL, NULL, '女', 'kanji', 'people', 'beginner', 'Kneeling person = phụ nữ', 'Kneeling person = woman'),
('男', 'otoko', NULL, NULL, '男', 'kanji', 'people', 'beginner', 'Đồng ruộng + người = nam giới', 'Field + person = man'),
('大', 'dai', NULL, NULL, '大', 'kanji', 'size', 'beginner', 'Người với tay ngang = to', 'Person with arms spread = big'),
('小', 'shou', NULL, NULL, '小', 'kanji', 'size', 'beginner', 'Người nhỏ với 3 vạch = bé', 'Small person with 3 lines = small'),
('金', 'kin', NULL, NULL, '金', 'kanji', 'materials', 'beginner', 'Khoáng sản = vàng/tiền', 'Mineral deposits = gold/money'),
('食', 'taberu', NULL, NULL, '食', 'kanji', 'action', 'beginner', 'Tay che mặt ăn = ăn', 'Hand covering mouth = eat');

-- UPDATE structured_lessons with section_id 
UPDATE structured_lessons SET section_id = 1, content_vi = 'Học cách phát âm 5 nguyên âm cơ bản: あ い う え お. Đây là nền tảng cho tất cả các âm tiếng Nhật.', content_en = 'Learn to pronounce the 5 basic vowels: あ い う え お. This is the foundation for all Japanese sounds.' WHERE lesson_number = 1;
UPDATE structured_lessons SET section_id = 1, content_vi = 'Học cách phát âm các nguyên âm katakana: ア イ ウ エ オ. Katakana được sử dụng cho từ vựng ngoại lai.', content_en = 'Learn the katakana vowels: ア イ ウ エ オ. Katakana is used for foreign loanwords.' WHERE lesson_number = 2 AND lesson_type = 'character_learning';
UPDATE structured_lessons SET section_id = 2 WHERE lesson_type IN ('character_learning', 'practice') AND lesson_number IN (2, 3, 4) AND lesson_type != 'character_learning' OR lesson_number > 5;

-- Hiragana and katakana characters grouped by consonant row.
-- Each row also carries its katakana equivalent in the same record.
-- Also includes Kanji for advanced learners.
INSERT INTO characters (kana, romaji, hiragana, katakana, kanji, type, group_name, difficulty, mnemonic_vi, mnemonic_en) VALUES
-- Hiragana vowels
('あ', 'a',   'あ', 'ア', NULL, 'hiragana', 'a', 'beginner', 'Nguyên âm cơ bản A', 'The basic vowel A'),
('い', 'i',   'い', 'イ', NULL, 'hiragana', 'i', 'beginner', 'Hai nét song song như chữ I', 'Two parallel strokes like the letter I'),
('う', 'u',   'う', 'ウ', NULL, 'hiragana', 'u', 'beginner', 'Tròn như miệng khi nói U', 'Round like your mouth when saying U'),
('え', 'e',   'え', 'エ', NULL, 'hiragana', 'e', 'beginner', 'Nguyên âm E với dấu chéo', 'Vowel E with a crossing stroke'),
('お', 'o',   'お', 'オ', NULL, 'hiragana', 'o', 'beginner', 'Tròn như chữ O', 'Round like the letter O'),
-- Hiragana K row
('か', 'ka',  'か', 'カ', 'hiragana', 'k', 'beginner', 'K kết hợp với A', 'K combined with A'),
('き', 'ki',  'き', 'キ', 'hiragana', 'k', 'beginner', 'K kết hợp với I', 'K combined with I'),
('く', 'ku',  'く', 'ク', 'hiragana', 'k', 'beginner', 'K kết hợp với U — trông như mỏ chim', 'K combined with U — looks like a bird beak'),
('け', 'ke',  'け', 'ケ', 'hiragana', 'k', 'beginner', 'K kết hợp với E', 'K combined with E'),
('こ', 'ko',  'こ', 'コ', 'hiragana', 'k', 'beginner', 'K kết hợp với O — hai nét nằm ngang', 'K combined with O — two horizontal strokes'),
-- Hiragana S row
('さ', 'sa',  'さ', 'サ', 'hiragana', 's', 'beginner', 'S kết hợp với A', 'S combined with A'),
('し', 'shi', 'し', 'シ', 'hiragana', 's', 'beginner', 'S kết hợp với I — như cái móc câu', 'S combined with I — like a fishing hook'),
('す', 'su',  'す', 'ス', 'hiragana', 's', 'beginner', 'S kết hợp với U', 'S combined with U'),
('せ', 'se',  'せ', 'セ', 'hiragana', 's', 'beginner', 'S kết hợp với E', 'S combined with E'),
('そ', 'so',  'そ', 'ソ', 'hiragana', 's', 'beginner', 'S kết hợp với O — như sóng nước', 'S combined with O — like a ripple'),
-- Hiragana T row
('た', 'ta',  'た', 'タ', 'hiragana', 't', 'beginner', 'T kết hợp với A', 'T combined with A'),
('ち', 'chi', 'ち', 'チ', 'hiragana', 't', 'beginner', 'T kết hợp với I — đọc là "chi"', 'T combined with I — read as "chi"'),
('つ', 'tsu', 'つ', 'ツ', 'hiragana', 't', 'beginner', 'T kết hợp với U — đọc là "tsu"', 'T combined with U — read as "tsu"'),
('て', 'te',  'て', 'テ', 'hiragana', 't', 'beginner', 'T kết hợp với E', 'T combined with E'),
('と', 'to',  'と', 'ト', 'hiragana', 't', 'beginner', 'T kết hợp với O — như cái cây', 'T combined with O — looks like a small tree'),
-- Katakana vowels
('ア', 'a',   'あ', 'ア', 'katakana', 'a', 'beginner', 'Katakana A — nét thẳng góc', 'Katakana A — angular strokes'),
('イ', 'i',   'い', 'イ', 'katakana', 'i', 'beginner', 'Katakana I — hai gạch chéo', 'Katakana I — two diagonal strokes'),
('ウ', 'u',   'う', 'ウ', 'katakana', 'u', 'beginner', 'Katakana U — hình chén úp', 'Katakana U — like an upside-down cup'),
('エ', 'e',   'え', 'エ', 'katakana', 'e', 'beginner', 'Katakana E — chữ H nằm ngang', 'Katakana E — like a sideways H'),
('オ', 'o',   'お', 'オ', 'katakana', 'o', 'beginner', 'Katakana O — chữ thập có móc', 'Katakana O — a cross with a hook'),
-- Katakana K row
('カ', 'ka',  'か', 'カ', 'katakana', 'k', 'beginner', 'Katakana KA', 'Katakana KA'),
('キ', 'ki',  'き', 'キ', 'katakana', 'k', 'beginner', 'Katakana KI — như cây thước', 'Katakana KI — like a ruler'),
('ク', 'ku',  'く', 'ク', 'katakana', 'k', 'beginner', 'Katakana KU — như mỏ chim sắc hơn', 'Katakana KU — a sharper bird beak'),
('ケ', 'ke',  'け', 'ケ', 'katakana', 'k', 'beginner', 'Katakana KE', 'Katakana KE'),
('コ', 'ko',  'こ', 'コ', 'katakana', 'k', 'beginner', 'Katakana KO — hai vạch ngang ngắn', 'Katakana KO — two short horizontal lines');

-- Structured lessons form the default curriculum pathway.
INSERT INTO structured_lessons (lesson_number, title_vi, title_en, content_vi, content_en, lesson_type, order_index) VALUES
(1, 'Nguyên âm cơ bản',  'Basic Vowels',     'Học cách phát âm 5 nguyên âm cơ bản: あ い う え お', 'Learn to pronounce the 5 basic vowels: あ い う え お', 'character_learning', 1),
(2, 'Hàng K',            'K Row',             'Học hàng K: か き く け こ',                           'Learn the K row: か き く け こ',                       'character_learning', 2),
(3, 'Hàng S',            'S Row',             'Học hàng S: さ し す せ そ',                           'Learn the S row: さ し す せ そ',                       'character_learning', 3),
(4, 'Hàng T',            'T Row',             'Học hàng T: た ち つ て と',                           'Learn the T row: た ち つ て と',                       'character_learning', 4),
(5, 'Ôn tập tổng hợp',   'Review Quiz',       'Kiểm tra kiến thức nguyên âm và phụ âm đã học',       'Test your knowledge of the vowels and consonants covered so far', 'review', 5);

-- User-created lessons (tied to the test account).
INSERT INTO lessons (user_id, title, content, is_public) VALUES
(1, 'Basic Hiragana Vowels',  'Learn the 5 basic hiragana vowels: あ い う え お', 1),
(1, 'Hiragana K Row',         'Learn the K row: か き く け こ',                  1),
(1, 'Hiragana S Row',         'Learn the S row: さ し す せ そ',                  1),
(1, 'Hiragana T Row',         'Learn the T row: た ち つ て と',                  1),
(1, 'Basic Katakana Vowels',  'Learn the 5 katakana vowels: ア イ ウ エ オ',      1),
(1, 'Katakana K Row',         'Learn the katakana K row: カ キ ク ケ コ',         1),
(1, 'Review Quiz',            'Test your knowledge of basic hiragana and katakana', 1);

-- Lesson questions for user-created lessons.
INSERT INTO lesson_questions (lesson_id, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
(1, 'What is the romaji for あ?', 'a',   'i',   'u',   'e',  'a'),
(1, 'What is the romaji for い?', 'a',   'i',   'u',   'e',  'b'),
(2, 'What is the romaji for か?', 'ka',  'ki',  'ku',  'ke', 'a'),
(2, 'What is the romaji for き?', 'ka',  'ki',  'ku',  'ke', 'b'),
(3, 'What is the romaji for さ?', 'sa',  'shi', 'su',  'se', 'a'),
(3, 'What is the romaji for し?', 'sa',  'shi', 'su',  'se', 'b');

-- Structured quiz questions with bilingual support.
INSERT INTO quiz_questions (lesson_id, question_type, question_vi, question_en, romaji, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, difficulty_level, points, order_index) VALUES
(1, 'multiple_choice', 'あ đọc là gì?',        'How is あ pronounced?',    'a',  '["a","i","u","e"]',         '["a","i","u","e"]',         'a',  'a',  'あ là nguyên âm cơ bản a', 'あ is the basic vowel a', 'easy', 1, 1),
(1, 'romaji_to_kana',  'Hiragana của "a" là?', 'Which hiragana spells "a"?','a',  '["あ","い","う","え"]',      '["あ","い","う","え"]',      'あ', 'あ', 'あ đọc là a',              'あ reads as a',           'easy', 1, 2),
(2, 'multiple_choice', 'か đọc là gì?',        'How is か pronounced?',    'ka', '["ka","ki","ku","ke"]',      '["ka","ki","ku","ke"]',      'ka', 'ka', 'か là ka',                'か reads as ka',          'easy', 1, 3),
(2, 'kana_to_meaning', 'か phát âm thế nào?',  'What sound does か make?', 'ka', '["ka","ki","ku","ke"]',      '["ka","ki","ku","ke"]',      'ka', 'ka', 'か phát âm là ka',        'か is pronounced ka',     'easy', 1, 4);

-- ===========================================================================
-- VOCABULARY SEED DATA  (~110 entries, N5 beginner — grouped by lesson row)
-- ===========================================================================

INSERT INTO vocabulary (lesson_id, word_kanji, word_hiragana, romaji, meaning_vi, meaning_en, detailed_explanation_vi, detailed_explanation_en, part_of_speech, jlpt_level, difficulty_level, order_index) VALUES

-- ── Lesson 1 · Vowel row (あ い う え お) ─────────────────────────────────
(1, '赤い',     'あかい',     'akai',      'màu đỏ',         'red',
 'Tính từ chỉ màu đỏ tươi. Dùng trong cả nghĩa đen (quả táo đỏ) lẫn nghĩa bóng (mặt đỏ xấu hổ).',
 'An i-adjective meaning bright red. Used both literally (red apple) and figuratively (red face from embarrassment).',
 'adjective', 'N5', 'beginner', 1),

(1, '朝',       'あさ',       'asa',       'buổi sáng',      'morning',
 'Khoảng thời gian từ lúc mặt trời mọc đến trưa. Gắn liền với bữa sáng và nhịp sống hằng ngày.',
 'The period from sunrise to noon. Closely tied to breakfast routines in Japanese daily life.',
 'noun', 'N5', 'beginner', 2),

(1, '頭',       'あたま',     'atama',     'cái đầu',        'head',
 'Bộ phận cơ thể phía trên cổ. Cũng dùng theo nghĩa bóng chỉ trí tuệ: "atama ga ii" (thông minh).',
 'The body part above the neck. Also used figuratively: "atama ga ii" means someone is smart.',
 'noun', 'N5', 'beginner', 3),

(1, '雨',       'あめ',       'ame',       'mưa',            'rain',
 'Nước rơi từ trời. Nhật Bản có mùa mưa (tsuyu) kéo dài từ tháng 6 đến tháng 7.',
 'Water falling from the sky. Japan has a rainy season called tsuyu that runs through June and July.',
 'noun', 'N5', 'beginner', 4),

(1, '青い',     'あおい',     'aoi',       'màu xanh lam / xanh lá',  'blue / green',
 'Tính từ bao gồm cả xanh lá và xanh lam trong tiếng Nhật. Bầu trời xanh là "aoi sora".',
 'An i-adjective covering both blue and green. "Aoi sora" means blue sky.',
 'adjective', 'N5', 'beginner', 5),

(1, '家',       'いえ',       'ie',        'ngôi nhà',       'house / home',
 'Nơi sinh sống của gia đình. Khác với "uchi" (nhà mình) thường mang sắc thái cá nhân hơn.',
 'Where a family lives. Slightly more formal than "uchi", which has a warmer, personal feel.',
 'noun', 'N5', 'beginner', 6),

(1, '犬',       'いぬ',       'inu',       'con chó',        'dog',
 'Thú nuôi phổ biến ở Nhật Bản. Các giống chó như Shiba Inu xuất phát từ Nhật.',
 'A popular pet in Japan. Breeds like the Shiba Inu originated there.',
 'noun', 'N5', 'beginner', 7),

(1, '今',       'いま',       'ima',       'bây giờ',        'now',
 'Chỉ thời điểm hiện tại. Thường xuất hiện trong câu hỏi như "ima nanji desu ka?" (Bây giờ là mấy giờ?).',
 'Refers to the present moment. Appears in common phrases like "ima nanji desu ka?" (What time is it now?).',
 'adverb', 'N5', 'beginner', 8),

(1, NULL,       'いい',       'ii',        'tốt / được',     'good / fine',
 'Tính từ đặc biệt biểu thị sự hài lòng. Dạng phủ định là "yokunai" chứ không phải "ikunai".',
 'An irregular i-adjective expressing approval or quality. Its negative form is "yokunai", not "ikunai".',
 'adjective', 'N5', 'beginner', 9),

(1, '海',       'うみ',       'umi',       'biển',           'sea',
 'Vùng nước mặn bao quanh đất liền. Nhật Bản là đảo quốc nên biển có ý nghĩa văn hóa sâu sắc.',
 'The saltwater expanse surrounding land. As an island nation, the sea is deeply embedded in Japanese culture.',
 'noun', 'N5', 'beginner', 10),

(1, '歌',       'うた',       'uta',       'bài hát',        'song',
 'Âm nhạc kết hợp với lời. Hát karaoke (カラオケ) là một nét văn hóa xã hội nổi bật ở Nhật.',
 'Music combined with lyrics. Karaoke (カラオケ) is a prominent social tradition in Japan.',
 'noun', 'N5', 'beginner', 11),

(1, '駅',       'えき',       'eki',       'ga tàu / bến xe', 'station',
 'Nơi tàu hỏa hoặc xe buýt dừng đón khách. Tokyo Station là một trong những ga lớn nhất thế giới.',
 'A stop for trains or buses. Tokyo Station is one of the busiest transit hubs in the world.',
 'noun', 'N5', 'beginner', 12),

(1, '絵',       'え',         'e',         'bức tranh',      'picture / drawing',
 'Tác phẩm được tạo ra bằng cách vẽ hoặc sơn. "E o kaku" có nghĩa là vẽ tranh.',
 'A work created by drawing or painting. "E o kaku" means to draw a picture.',
 'noun', 'N5', 'beginner', 13),

(1, '大きい',   'おおきい',   'ookii',     'to lớn',         'big / large',
 'Tính từ mô tả kích thước lớn. "Ookii koe" là giọng nói to.',
 'Describes large size. "Ookii koe" means a loud voice.',
 'adjective', 'N5', 'beginner', 14),

(1, '音楽',     'おんがく',   'ongaku',    'âm nhạc',        'music',
 'Nghệ thuật kết hợp âm thanh và nhịp điệu. Nhật có nhiều thể loại riêng như J-pop và enka.',
 'The art of combining sound and rhythm. Japan has distinct genres like J-pop and enka.',
 'noun', 'N5', 'beginner', 15),

-- ── Lesson 2 · K row (か き く け こ) ─────────────────────────────────────
(2, '傘',       'かさ',       'kasa',      'cái ô / dù',     'umbrella',
 'Vật dụng che mưa hoặc nắng. Ô là vật không thể thiếu trong mùa mưa ở Nhật.',
 'A tool for blocking rain or sun. Umbrellas are indispensable during Japan''s rainy season.',
 'noun', 'N5', 'beginner', 16),

(2, '体',       'からだ',     'karada',    'cơ thể',         'body',
 'Toàn bộ thân hình của con người. "Karada ni ki o tsukete" nghĩa là "giữ gìn sức khỏe nhé".',
 'The entire human form. "Karada ni ki o tsukete" means "take care of your health".',
 'noun', 'N5', 'beginner', 17),

(2, '顔',       'かお',       'kao',       'khuôn mặt',      'face',
 'Phần trước của đầu. Cũng mang nghĩa bóng như "danh tiếng / thể diện".',
 'The front of the head. Also carries the figurative meaning of reputation or face-saving.',
 'noun', 'N5', 'beginner', 18),

(2, '川',       'かわ',       'kawa',      'con sông',       'river',
 'Dòng nước chảy ra biển hoặc hồ. Sông Sumida chảy qua trung tâm Tokyo là biểu tượng của thành phố.',
 'A flowing body of water. The Sumida River running through central Tokyo is one of its iconic landmarks.',
 'noun', 'N5', 'beginner', 19),

(2, '学校',     'がっこう',   'gakkou',    'trường học',     'school',
 'Cơ sở giáo dục. Nhật Bản có hệ thống giáo dục bắt buộc từ lớp 1 đến lớp 9.',
 'An educational institution. Japan''s compulsory education runs from grade 1 through grade 9.',
 'noun', 'N5', 'beginner', 20),

(2, '聞く',     'きく',       'kiku',      'nghe / hỏi',     'to listen / to ask',
 'Động từ nhóm 1. Vừa có nghĩa là lắng nghe âm thanh vừa có nghĩa là đặt câu hỏi.',
 'A Group 1 verb. Means both to listen to sound and to ask a question, depending on context.',
 'verb', 'N5', 'beginner', 21),

(2, '木',       'き',         'ki',        'cây / gỗ',       'tree / wood',
 'Thực vật lớn có thân gỗ hoặc chất liệu gỗ. Nhật Bản nổi tiếng với rừng tuyết tùng và anh đào.',
 'A tall woody plant, or the material wood. Japan is known for its cedar forests and cherry blossom trees.',
 'noun', 'N5', 'beginner', 22),

(2, '切る',     'きる',       'kiru',      'cắt',            'to cut',
 'Động từ chỉ hành động cắt bằng dụng cụ sắc bén. Không nhầm với "kiru" (着る) nghĩa là mặc quần áo.',
 'The act of cutting with something sharp. Not to be confused with "kiru" (着る), which means to wear clothes.',
 'verb', 'N5', 'beginner', 23),

(2, '黄色い',   'きいろい',   'kiiroi',    'màu vàng',       'yellow',
 'Tính từ chỉ màu vàng như hoa hướng dương hoặc ánh đèn. Dùng với danh từ thì thêm "kiiroi".',
 'Describes the color yellow, like sunflowers or warm lamplight.',
 'adjective', 'N5', 'beginner', 24),

(2, '口',       'くち',       'kuchi',     'miệng',          'mouth',
 'Bộ phận dùng để ăn và nói. "Kuchi ga karui" (miệng nhẹ) nghĩa là người hay nói chuyện.',
 'The body part used for eating and speaking. "Kuchi ga karui" (light mouth) describes a chatty person.',
 'noun', 'N5', 'beginner', 25),

(2, '靴',       'くつ',       'kutsu',     'giày dép',       'shoes',
 'Đồ vật đi vào chân. Ở Nhật phải tháo giày trước khi vào nhà.',
 'Footwear. In Japan, removing shoes before entering a home is standard etiquette.',
 'noun', 'N5', 'beginner', 26),

(2, '来る',     'くる',       'kuru',      'đến',            'to come',
 'Động từ bất quy tắc. Chia thành "kimasu" (đến — lịch sự) hoặc "kita" (đã đến — quá khứ).',
 'An irregular verb. Conjugates to "kimasu" (polite) or "kita" (past tense).',
 'verb', 'N5', 'beginner', 27),

(2, '消す',     'けす',       'kesu',      'tắt / xóa',      'to turn off / to erase',
 'Hành động tắt đèn, lửa hoặc máy móc; cũng có nghĩa là xóa chữ viết.',
 'The act of switching off lights, fire, or machines; also means to erase written text.',
 'verb', 'N5', 'beginner', 28),

(2, '今日',     'きょう',     'kyou',      'hôm nay',        'today',
 'Ngày hiện tại. "Kyou wa ii tenki desu ne" nghĩa là "Hôm nay thời tiết đẹp nhỉ".',
 'The current day. "Kyou wa ii tenki desu ne" means "The weather is nice today, isn''t it?"',
 'noun', 'N5', 'beginner', 29),

(2, 'ここ',     'ここ',       'koko',      'ở đây',          'here',
 'Phó từ chỉ vị trí gần người nói. Cặp với "soko" (đó) và "asoko" (kia).',
 'An adverb indicating a location near the speaker. Pairs with "soko" (there) and "asoko" (over there).',
 'adverb', 'N5', 'beginner', 30),

-- ── Lesson 3 · S row (さ し す せ そ) ─────────────────────────────────────
(3, '魚',       'さかな',     'sakana',    'con cá',         'fish',
 'Sinh vật sống dưới nước. Cá là nguồn thực phẩm quan trọng trong ẩm thực Nhật Bản.',
 'An aquatic animal. Fish is a staple ingredient in Japanese cuisine, from sashimi to grilled dishes.',
 'noun', 'N5', 'beginner', 31),

(3, '酒',       'さけ',       'sake',      'rượu',           'alcohol / sake',
 'Đồ uống có cồn; đặc biệt chỉ rượu sake truyền thống của Nhật làm từ gạo.',
 'An alcoholic beverage; specifically refers to Japanese rice wine in many contexts.',
 'noun', 'N5', 'beginner', 32),

(3, '寒い',     'さむい',     'samui',     'lạnh',           'cold (weather)',
 'Tính từ chỉ nhiệt độ thấp của môi trường xung quanh. Khác "tsumetai" chỉ vật lạnh khi chạm vào.',
 'Describes low ambient temperature. Unlike "tsumetai", which describes something cold to the touch.',
 'adjective', 'N5', 'beginner', 33),

(3, '塩',       'しお',       'shio',      'muối',           'salt',
 'Gia vị cơ bản trong ẩm thực. "Shio ramen" là ramen nước dùng trong có vị muối thanh.',
 'A fundamental seasoning. "Shio ramen" features a clear, lightly salted broth.',
 'noun', 'N5', 'beginner', 34),

(3, '仕事',     'しごと',     'shigoto',   'công việc',      'work / job',
 'Hoạt động nghề nghiệp hoặc nhiệm vụ cần hoàn thành. "Shigoto ga isogashii" nghĩa là bận rộn với công việc.',
 'Professional activity or a task that needs completing. "Shigoto ga isogashii" means swamped with work.',
 'noun', 'N5', 'beginner', 35),

(3, '知る',     'しる',       'shiru',     'biết',           'to know',
 'Động từ nhóm 1 diễn đạt việc có thông tin. "Shirimasen" là cách lịch sự để nói "Tôi không biết".',
 'A Group 1 verb expressing having information. "Shirimasen" is the polite way to say "I don''t know".',
 'verb', 'N5', 'beginner', 36),

(3, '好き',     'すき',       'suki',      'yêu thích',      'to like / favorite',
 'Tính từ na diễn tả sở thích. "Sushi ga suki desu" nghĩa là "Tôi thích sushi".',
 'A na-adjective expressing fondness. "Sushi ga suki desu" means "I like sushi".',
 'adjective', 'N5', 'beginner', 37),

(3, '少し',     'すこし',     'sukoshi',   'một chút',       'a little / a few',
 'Phó từ chỉ số lượng nhỏ. "Sukoshi matte kudasai" nghĩa là "Xin vui lòng đợi một chút".',
 'An adverb indicating a small amount. "Sukoshi matte kudasai" means "Please wait a moment".',
 'adverb', 'N5', 'beginner', 38),

(3, '空',       'そら',       'sora',      'bầu trời',       'sky',
 'Không gian trên cao. Từ này mang vẻ thơ mộng và xuất hiện nhiều trong thơ ca Nhật Bản.',
 'The expanse above. This word carries a poetic quality and appears frequently in Japanese literature.',
 'noun', 'N5', 'beginner', 39),

(3, 'そこ',     'そこ',       'soko',      'ở đó',           'there (near you)',
 'Phó từ chỉ vị trí gần người nghe. Đứng giữa "koko" (đây) và "asoko" (kia).',
 'An adverb for a location near the listener. Sits between "koko" (here) and "asoko" (over there).',
 'adverb', 'N5', 'beginner', 40),

(3, '背中',     'せなか',     'senaka',    'lưng',           'back (body)',
 'Mặt sau của thân người. "Senaka ga itai" nghĩa là "Đau lưng".',
 'The back side of the human torso. "Senaka ga itai" means "My back hurts".',
 'noun', 'N5', 'beginner', 41),

(3, '先生',     'せんせい',   'sensei',    'giáo viên / thầy cô', 'teacher',
 'Người dạy học; cũng dùng kính trọng với bác sĩ, luật sư. Nghĩa gốc là "người sinh trước".',
 'A teacher; also used respectfully for doctors and lawyers. Literally means "one born before".',
 'noun', 'N5', 'beginner', 42),

(3, '外',       'そと',       'soto',      'bên ngoài',      'outside',
 'Phía bên ngoài tòa nhà hoặc khu vực. Đối lập với "uchi" (trong nhà).',
 'The area beyond a building or boundary. Contrasts with "uchi" (inside the home).',
 'noun', 'N5', 'beginner', 43),

-- ── Lesson 4 · T row (た ち つ て と) ─────────────────────────────────────
(4, '高い',     'たかい',     'takai',     'cao / đắt',      'tall / expensive',
 'Tính từ mang hai nghĩa: độ cao vật lý và giá tiền cao. Ngữ cảnh quyết định nghĩa nào được dùng.',
 'An i-adjective with two meanings: physically tall and monetarily expensive. Context clarifies which is meant.',
 'adjective', 'N5', 'beginner', 44),

(4, '食べる',   'たべる',     'taberu',    'ăn',             'to eat',
 'Động từ nhóm 2. "Nani o tabemasu ka?" nghĩa là "Bạn ăn gì?".',
 'A Group 2 verb. "Nani o tabemasu ka?" means "What will you eat?"',
 'verb', 'N5', 'beginner', 45),

(4, '楽しい',   'たのしい',   'tanoshii',  'vui vẻ / thú vị', 'fun / enjoyable',
 'Tính từ diễn tả sự vui thích. "Tanoshikatta" là dạng quá khứ, nghĩa là "đã vui".',
 'Describes an enjoyable experience. "Tanoshikatta" is the past form meaning "it was fun".',
 'adjective', 'N5', 'beginner', 46),

(4, '近い',     'ちかい',     'chikai',    'gần',            'near / close',
 'Tính từ chỉ khoảng cách ngắn. "Chikaku ni" nghĩa là "ở gần đây".',
 'An i-adjective describing short distance. "Chikaku ni" means "nearby".',
 'adjective', 'N5', 'beginner', 47),

(4, '地下鉄',   'ちかてつ',   'chikatetsu','tàu điện ngầm',  'subway / metro',
 'Hệ thống tàu chạy dưới lòng đất. Tokyo có một trong những mạng lưới tàu điện ngầm phức tạp nhất thế giới.',
 'An underground rail system. Tokyo''s metro network is one of the most extensive in the world.',
 'noun', 'N5', 'beginner', 48),

(4, '月',       'つき',       'tsuki',     'mặt trăng / tháng', 'moon / month',
 'Thiên thể hoặc đơn vị thời gian. "Tsuki ga kirei desu ne" là câu nổi tiếng Soseki dùng để nói "Tôi yêu bạn".',
 'The celestial body or a unit of time. "Tsuki ga kirei desu ne" is the phrase novelist Soseki used to express love.',
 'noun', 'N5', 'beginner', 49),

(4, '使う',     'つかう',     'tsukau',    'sử dụng',        'to use',
 'Động từ nhóm 1. "Sumimasen, kono isu o tsukatte mo ii desu ka?" nghĩa là "Xin lỗi, tôi có thể dùng ghế này không?".',
 'A Group 1 verb. "Sumimasen, kono isu o tsukatte mo ii desu ka?" means "Excuse me, may I use this chair?"',
 'verb', 'N5', 'beginner', 50),

(4, '疲れる',   'つかれる',   'tsukareru', 'mệt mỏi',        'to get tired',
 'Động từ nhóm 2 mô tả trạng thái kiệt sức. "Tsukareta" (quá khứ) là "đã mệt rồi".',
 'A Group 2 verb describing exhaustion. "Tsukareta" in the past form means "I got tired".',
 'verb', 'N5', 'beginner', 51),

(4, '手紙',     'てがみ',     'tegami',    'lá thư',         'letter (mail)',
 'Thư viết tay gửi qua bưu điện. Dù email phổ biến, thư tay vẫn được trân trọng ở Nhật.',
 'A handwritten letter sent by post. Despite the prevalence of email, handwritten letters are still valued in Japan.',
 'noun', 'N5', 'beginner', 52),

(4, '天気',     'てんき',     'tenki',     'thời tiết',      'weather',
 'Tình trạng khí quyển bên ngoài. "Kyou wa ii tenki desu ne" là câu mở đầu trò chuyện phổ biến.',
 'The state of the atmosphere outside. "Kyou wa ii tenki desu ne" is a common conversation opener.',
 'noun', 'N5', 'beginner', 53),

(4, '時計',     'とけい',     'tokei',     'đồng hồ',        'clock / watch',
 'Thiết bị đo thời gian. Nhật Bản nổi tiếng với đồng hồ chính xác của các thương hiệu như Seiko và Citizen.',
 'A device for measuring time. Japan is renowned for precision watchmaking through brands like Seiko and Citizen.',
 'noun', 'N5', 'beginner', 54),

(4, '友達',     'ともだち',   'tomodachi', 'bạn bè',         'friend',
 'Người thân thiết ngoài gia đình. "Tomodachi ga hoshii" nghĩa là "Tôi muốn có bạn bè".',
 'A person close to you outside of family. "Tomodachi ga hoshii" means "I want to make friends".',
 'noun', 'N5', 'beginner', 55),

(4, '飛ぶ',     'とぶ',       'tobu',      'bay',            'to fly / to jump',
 'Động từ nhóm 1 mô tả chuyển động trên không. "Toridori ga tondeiru" nghĩa là "những con chim đang bay".',
 'A Group 1 verb describing movement through the air. "Tori ga tondeiru" means "a bird is flying".',
 'verb', 'N5', 'beginner', 56),

-- ── Lesson 5 · Review — mixed high-frequency N5 words ────────────────────
(5, '花',       'はな',       'hana',      'bông hoa',       'flower',
 'Phần sinh sản của thực vật. Hoa anh đào (sakura) là biểu tượng quốc gia của Nhật Bản.',
 'The reproductive part of a plant. Cherry blossoms (sakura) are Japan''s most iconic national symbol.',
 'noun', 'N5', 'beginner', 57),

(5, '話す',     'はなす',     'hanasu',    'nói chuyện',     'to speak / to talk',
 'Động từ nhóm 1. "Nihongo o hanashimasu ka?" nghĩa là "Bạn có nói tiếng Nhật không?".',
 'A Group 1 verb. "Nihongo o hanashimasu ka?" means "Do you speak Japanese?"',
 'verb', 'N5', 'beginner', 58),

(5, '春',       'はる',       'haru',      'mùa xuân',       'spring',
 'Mùa ấm áp sau đông lạnh. Mùa xuân gắn với hoa anh đào và lễ hội hanami (ngắm hoa).',
 'The warm season after winter. Spring is associated with cherry blossoms and the hanami flower-viewing festival.',
 'noun', 'N5', 'beginner', 59),

(5, '本',       'ほん',       'hon',       'cuốn sách',      'book',
 'Tập hợp các trang in được đóng gáy. Nhật Bản có tỉ lệ đọc sách và xuất bản manga rất cao.',
 'A bound collection of printed pages. Japan has high reading rates and is the home of manga publishing.',
 'noun', 'N5', 'beginner', 60),

(5, '水',       'みず',       'mizu',      'nước (lạnh)',     'water (cold)',
 'Chất lỏng không màu, không mùi. Phân biệt với "oyu" là nước nóng.',
 'A colorless, tasteless liquid. Distinct from "oyu", which refers to hot water.',
 'noun', 'N5', 'beginner', 61),

(5, '耳',       'みみ',       'mimi',      'tai',            'ear',
 'Cơ quan thính giác. "Mimi ga tooi" (tai xa) nghĩa là nghe kém.',
 'The hearing organ. "Mimi ga tooi" (distant ears) means hard of hearing.',
 'noun', 'N5', 'beginner', 62),

(5, '見る',     'みる',       'miru',      'nhìn / xem',     'to see / to watch',
 'Động từ nhóm 2. "Eiga o mimasu" nghĩa là "Xem phim".',
 'A Group 2 verb. "Eiga o mimasu" means "to watch a movie".',
 'verb', 'N5', 'beginner', 63),

(5, '道',       'みち',       'michi',     'con đường',      'road / path',
 'Lối đi dành cho người hoặc xe. "Michi ni mayotta" nghĩa là "Tôi đã bị lạc đường".',
 'A route for people or vehicles. "Michi ni mayotta" means "I got lost".',
 'noun', 'N5', 'beginner', 64),

(5, '山',       'やま',       'yama',      'núi',            'mountain',
 'Địa hình cao nổi lên từ mặt đất. Núi Phú Sĩ (Fujisan) là biểu tượng địa lý của Nhật Bản.',
 'Elevated terrain rising from the earth. Mount Fuji (Fujisan) is Japan''s defining geographical icon.',
 'noun', 'N5', 'beginner', 65),

(5, '休む',     'やすむ',     'yasumu',    'nghỉ ngơi',      'to rest / to take a day off',
 'Động từ nhóm 1. "Kyou wa yasumimasu" nghĩa là "Hôm nay tôi nghỉ".',
 'A Group 1 verb. "Kyou wa yasumimasu" means "I''m taking today off".',
 'verb', 'N5', 'beginner', 66),

(5, '夜',       'よる',       'yoru',      'ban đêm',        'night / evening',
 'Thời gian từ khi trời tối đến sáng. Đối lập với "asa" (buổi sáng).',
 'The time from dark to dawn. Contrasts with "asa" (morning).',
 'noun', 'N5', 'beginner', 67),

(5, '読む',     'よむ',       'yomu',      'đọc',            'to read',
 'Động từ nhóm 1. "Shimbun o yomimasu" nghĩa là "Đọc báo".',
 'A Group 1 verb. "Shimbun o yomimasu" means "to read the newspaper".',
 'verb', 'N5', 'beginner', 68),

(5, '良い',     'よい',       'yoi',       'tốt',            'good (formal)',
 'Dạng trang trọng của "ii". Thường gặp trong văn viết và biểu đạt lịch sự hơn.',
 'A more formal version of "ii". More common in written Japanese and polite registers.',
 'adjective', 'N5', 'beginner', 69),

(5, '料理',     'りょうり',   'ryouri',    'nấu ăn / món ăn', 'cooking / dish',
 'Việc chế biến thức ăn hoặc bản thân món ăn đó. "Ryouri ga jouzu" nghĩa là "nấu ăn giỏi".',
 'The act of preparing food, or the food itself. "Ryouri ga jouzu" means "good at cooking".',
 'noun', 'N5', 'beginner', 70),

(5, '旅行',     'りょこう',   'ryokou',    'du lịch / chuyến đi', 'travel / trip',
 'Hành trình đến nơi khác. Nhật Bản nổi tiếng với văn hóa du lịch nội địa phong phú.',
 'A journey to another place. Japan has a rich domestic travel culture centered on regional food and hot springs.',
 'noun', 'N5', 'beginner', 71),

(5, '林',       'はやし',     'hayashi',   'khu rừng nhỏ',   'grove / small forest',
 'Khu vực có nhiều cây nhưng nhỏ hơn "mori" (rừng lớn). Thường xuất hiện trong thơ haiku.',
 'An area with many trees, smaller than "mori" (forest). Frequently appears in haiku poetry.',
 'noun', 'N5', 'beginner', 72),

(5, '風',       'かぜ',       'kaze',      'gió / cảm lạnh', 'wind / cold (illness)',
 'Hai nghĩa rất khác nhau: luồng gió và bệnh cảm. "Kaze o hiku" nghĩa là "bị cảm".',
 'Two very different meanings: wind in the air, and catching a cold. "Kaze o hiku" means to catch a cold.',
 'noun', 'N5', 'beginner', 73),

(5, '子供',     'こども',     'kodomo',    'trẻ em',         'child / children',
 'Người còn nhỏ tuổi chưa trưởng thành. "Kodomo no hi" (5/5) là Ngày Trẻ em ở Nhật.',
 'A young person who has not yet grown up. "Kodomo no hi" (May 5) is Children''s Day in Japan.',
 'noun', 'N5', 'beginner', 74),

(5, '言葉',     'ことば',     'kotoba',    'ngôn ngữ / từ ngữ', 'language / word',
 'Hệ thống ngôn ngữ hoặc một từ đơn lẻ. "Yasashii kotoba" nghĩa là "những lời nói dịu dàng".',
 'A language system or an individual word. "Yasashii kotoba" means "gentle words".',
 'noun', 'N5', 'beginner', 75),

(5, '今日は',   'こんにちは', 'konnichiwa', 'xin chào (ban ngày)', 'hello / good afternoon',
 'Lời chào phổ biến nhất trong tiếng Nhật. Dùng từ khoảng 10 giờ sáng đến tối.',
 'The most widely known Japanese greeting. Used roughly from 10 AM until evening.',
 'expression', 'N5', 'beginner', 76),

(5, 'さようなら','さようなら', 'sayounara', 'tạm biệt',       'goodbye',
 'Lời chào khi chia tay, thường ngụ ý chia tay lâu dài. "Ja mata" dùng khi hẹn gặp lại sớm.',
 'A farewell greeting implying a longer separation. "Ja mata" is used when you''ll see each other again soon.',
 'expression', 'N5', 'beginner', 77),

(5, 'ありがとう','ありがとう', 'arigatou',  'cảm ơn',         'thank you',
 'Lời cảm ơn thông thường. Dạng lịch sự đầy đủ là "arigatou gozaimasu".',
 'A standard expression of thanks. The full polite form is "arigatou gozaimasu".',
 'expression', 'N5', 'beginner', 78),

(5, 'すみません','すみません', 'sumimasen', 'xin lỗi / xin phép', 'excuse me / sorry',
 'Dùng để xin lỗi hoặc gây sự chú ý. "Sumimasen" cũng dùng để gọi nhân viên phục vụ.',
 'Used to apologize or get someone''s attention. Also the standard way to call a waiter in a restaurant.',
 'expression', 'N5', 'beginner', 79),

(5, '何',       'なに',       'nani',      'cái gì',         'what',
 'Từ để hỏi. "Nani?" đứng một mình dùng để hỏi lại (biểu cảm ngạc nhiên).',
 'An interrogative word. "Nani?" alone is used as a surprised or clarifying "What?"',
 'adverb', 'N5', 'beginner', 80),

(5, '名前',     'なまえ',     'namae',     'tên',            'name',
 'Danh xưng của một người hoặc sự vật. "Onamae wa nan desu ka?" nghĩa là "Bạn tên là gì?".',
 'The identifier of a person or thing. "Onamae wa nan desu ka?" means "What is your name?"',
 'noun', 'N5', 'beginner', 81),

(5, '日本語',   'にほんご',   'nihongo',   'tiếng Nhật',     'Japanese language',
 'Ngôn ngữ của người Nhật. Hệ thống chữ viết bao gồm hiragana, katakana và kanji.',
 'The language spoken in Japan. Its writing system combines hiragana, katakana, and kanji.',
 'noun', 'N5', 'beginner', 82),

(5, '猫',       'ねこ',       'neko',      'con mèo',        'cat',
 'Thú nuôi phổ biến. Đảo Aoshima ở Nhật nổi tiếng là "đảo mèo" với mèo đông hơn người.',
 'A popular pet. Japan''s Aoshima is famous as a "cat island" where cats outnumber people.',
 'noun', 'N5', 'beginner', 83),

(5, '飲む',     'のむ',       'nomu',      'uống',           'to drink',
 'Động từ nhóm 1. "Mizu o nomimasu" nghĩa là "Uống nước". Cũng dùng cho việc uống thuốc.',
 'A Group 1 verb. "Mizu o nomimasu" means "to drink water". Also used for taking medicine.',
 'verb', 'N5', 'beginner', 84),

(5, '乗る',     'のる',       'noru',      'lên / đi (phương tiện)', 'to ride / to board',
 'Động từ nhóm 1. "Densha ni norimasu" nghĩa là "Đi tàu điện".',
 'A Group 1 verb. "Densha ni norimasu" means "to ride the train".',
 'verb', 'N5', 'beginner', 85),

(5, '父',       'ちち',       'chichi',    'bố (của mình)',  'one''s own father',
 'Cách khiêm tốn gọi bố khi nói với người khác. Dùng "otousan" khi gọi hoặc khi nói về bố người khác.',
 'The humble way to refer to your own father when speaking to others. Use "otousan" when addressing him directly.',
 'noun', 'N5', 'beginner', 86),

(5, '母',       'はは',       'haha',      'mẹ (của mình)',  'one''s own mother',
 'Cách khiêm tốn gọi mẹ khi nói với người khác. Dùng "okaasan" khi gọi hoặc khi nói về mẹ người khác.',
 'The humble way to refer to your own mother. Use "okaasan" when addressing her or speaking of someone else''s.',
 'noun', 'N5', 'beginner', 87),

(5, '兄',       'あに',       'ani',       'anh trai (của mình)', 'one''s own older brother',
 'Cách khiêm tốn chỉ anh trai khi nói với người ngoài. Gọi trực tiếp thì dùng "oniisan".',
 'The humble term for one''s own older brother when speaking to outsiders. "Oniisan" is used when speaking to him.',
 'noun', 'N5', 'beginner', 88),

(5, '姉',       'あね',       'ane',       'chị gái (của mình)', 'one''s own older sister',
 'Cách khiêm tốn chỉ chị gái khi nói với người ngoài. Gọi trực tiếp thì dùng "oneesan".',
 'The humble term for one''s own older sister when speaking to outsiders.',
 'noun', 'N5', 'beginner', 89),

(5, '買う',     'かう',       'kau',       'mua',            'to buy',
 'Động từ nhóm 1. "Nani o kaimashita ka?" nghĩa là "Bạn đã mua gì?".',
 'A Group 1 verb. "Nani o kaimashita ka?" means "What did you buy?"',
 'verb', 'N5', 'beginner', 90),

(5, '書く',     'かく',       'kaku',      'viết',           'to write',
 'Động từ nhóm 1. "Kanji o kakimasu" nghĩa là "Viết chữ kanji".',
 'A Group 1 verb. "Kanji o kakimasu" means "to write kanji".',
 'verb', 'N5', 'beginner', 91),

(5, '来年',     'らいねん',   'rainen',    'năm sau',        'next year',
 'Năm kế tiếp sau năm hiện tại. "Rainen mo yoroshiku onegaishimasu" là lời chào đầu năm.',
 'The year following the current one. "Rainen mo yoroshiku onegaishimasu" is a common New Year phrase.',
 'noun', 'N5', 'beginner', 92),

(5, '去年',     'きょねん',   'kyonen',    'năm ngoái',      'last year',
 'Năm liền trước năm hiện tại. "Kyonen Nihon ni ikimashita" nghĩa là "Năm ngoái tôi đã đến Nhật".',
 'The year immediately before the current one.',
 'noun', 'N5', 'beginner', 93),

(5, '毎日',     'まいにち',   'mainichi',  'mỗi ngày',       'every day',
 'Phó từ chỉ sự lặp lại hằng ngày. "Mainichi benkyou shimasu" nghĩa là "Tôi học mỗi ngày".',
 'An adverb expressing daily repetition. "Mainichi benkyou shimasu" means "I study every day".',
 'adverb', 'N5', 'beginner', 94),

(5, '電車',     'でんしゃ',   'densha',    'tàu điện',       'train (electric)',
 'Phương tiện công cộng chạy bằng điện. Tokyo có mạng lưới tàu điện dày đặc và đúng giờ nổi tiếng.',
 'Electrically powered rail transport. Tokyo''s train network is famous for its density and punctuality.',
 'noun', 'N5', 'beginner', 95),

(5, '電話',     'でんわ',     'denwa',     'điện thoại',     'telephone',
 '"Denwa suru" nghĩa là "gọi điện". Cụm từ phổ biến: "Denwa bangou wa nan desu ka?" (Số điện thoại là gì?).',
 '"Denwa suru" means "to make a phone call". Common phrase: "Denwa bangou wa nan desu ka?" (What''s your number?).',
 'noun', 'N5', 'beginner', 96),

(5, '新聞',     'しんぶん',   'shimbun',   'tờ báo',         'newspaper',
 'Ấn phẩm tin tức in hằng ngày. Nhật Bản có tỉ lệ đọc báo in thuộc hàng cao nhất thế giới.',
 'A daily printed news publication. Japan has one of the highest print newspaper readership rates in the world.',
 'noun', 'N5', 'beginner', 97),

(5, '病院',     'びょういん', 'byouin',    'bệnh viện',      'hospital',
 'Cơ sở y tế điều trị bệnh nhân. Chú ý đừng nhầm với "美容院" (biyouin) nghĩa là tiệm cắt tóc.',
 'A medical facility. Easy to confuse with "美容院" (biyouin), which means a beauty salon.',
 'noun', 'N5', 'beginner', 98),

(5, '勉強',     'べんきょう', 'benkyou',   'học bài / học tập', 'studying',
 'Hành động học hỏi kiến thức. "Nihongo o benkyou shiteimasu" nghĩa là "Tôi đang học tiếng Nhật".',
 'The act of studying or learning. "Nihongo o benkyou shiteimasu" means "I am studying Japanese".',
 'noun', 'N5', 'beginner', 99),

(5, '部屋',     'へや',       'heya',      'căn phòng',      'room',
 'Không gian trong nhà. "Heya ga chirakatte iru" nghĩa là "Phòng bừa bộn".',
 'A space inside a building. "Heya ga chirakatte iru" means "The room is messy".',
 'noun', 'N5', 'beginner', 100),

(5, '冬',       'ふゆ',       'fuyu',      'mùa đông',       'winter',
 'Mùa lạnh nhất trong năm. "Fuyu yasumi" là kỳ nghỉ đông, thường rơi vào tháng 12 và 1.',
 'The coldest season of the year. "Fuyu yasumi" is the winter break, usually falling in December and January.',
 'noun', 'N5', 'beginner', 101),

(5, '夏',       'なつ',       'natsu',     'mùa hè',         'summer',
 'Mùa nóng nhất trong năm. Lễ hội pháo hoa (hanabi taikai) là điểm nhấn của mùa hè Nhật Bản.',
 'The hottest season. Fireworks festivals (hanabi taikai) are a defining highlight of a Japanese summer.',
 'noun', 'N5', 'beginner', 102),

(5, '秋',       'あき',       'aki',       'mùa thu',        'autumn',
 'Mùa lá vàng đỏ. Ngắm lá thu (kouyou) là hoạt động phổ biến như ngắm hoa anh đào.',
 'The season of changing leaves. Autumn leaf viewing (kouyou) rivals cherry blossom season in popularity.',
 'noun', 'N5', 'beginner', 103),

(5, '数える',   'かぞえる',   'kazoeru',   'đếm',            'to count',
 'Động từ nhóm 2. "Hitotsu, futatsu, mittsu..." là cách đếm số lượng đồ vật theo kiểu thuần Nhật.',
 'A Group 2 verb. "Hitotsu, futatsu, mittsu…" is the native Japanese counting sequence for objects.',
 'verb', 'N5', 'beginner', 104),

(5, '分かる',   'わかる',     'wakaru',    'hiểu',           'to understand',
 'Động từ nhóm 1. "Wakatta" (quá khứ) nghĩa là "Hiểu rồi / Được rồi". Rất phổ biến trong hội thoại.',
 'A Group 1 verb. "Wakatta" (past form) means "I got it / Understood". Very common in everyday conversation.',
 'verb', 'N5', 'beginner', 105),

(5, '忘れる',   'わすれる',   'wasureru',  'quên',           'to forget',
 'Động từ nhóm 2. "Wasuremono" (đồ bỏ quên) là từ bạn thường nghe thông báo trên tàu Nhật.',
 'A Group 2 verb. "Wasuremono" (forgotten item) is a word you''ll often hear in Japanese train announcements.',
 'verb', 'N5', 'beginner', 106),

(5, '渡る',     'わたる',     'wataru',    'đi qua / vượt qua', 'to cross',
 'Động từ nhóm 1. "Michi o wataru" nghĩa là "Qua đường". Quan trọng khi hỏi đường.',
 'A Group 1 verb. "Michi o wataru" means "to cross the street". Essential vocabulary for giving directions.',
 'verb', 'N5', 'beginner', 107),

(5, '私',       'わたし',     'watashi',   'tôi',            'I / me',
 'Đại từ nhân xưng ngôi thứ nhất trung tính. Dùng trong cả văn nói lẫn văn viết ở mọi hoàn cảnh.',
 'A gender-neutral first-person pronoun. Suitable in both spoken and written Japanese across all contexts.',
 'noun', 'N5', 'beginner', 108),

(5, '店',       'みせ',       'mise',      'cửa hàng',       'shop / store',
 'Nơi bán hàng hóa hoặc dịch vụ. "Omise" (với tiền tố lịch sự "o") là cách dùng kính trọng hơn.',
 'A place selling goods or services. "Omise" — with the polite prefix "o" — is a more courteous form.',
 'noun', 'N5', 'beginner', 109),

(5, '道路',     'どうろ',     'douro',     'đường bộ',       'road',
 'Tuyến đường dành cho xe cộ. Phân biệt với "michi" (đường đi bộ / lối đi nhỏ).',
 'A route designed for vehicles. Distinguished from "michi", which covers footpaths and smaller lanes.',
 'noun', 'N5', 'beginner', 110);

-- Example sentences illustrating vocabulary in natural context.
INSERT INTO examples (vocabulary_id, jp_sentence_hiragana, jp_sentence_kanji, romaji_sentence, vi_meaning, en_meaning, grammar_note_vi, grammar_note_en, order_index) VALUES
(1,  'あかいりんごがすきです',   '赤いリンゴが好きです',    'Akai ringo ga suki desu',           'Tôi thích táo đỏ',                 'I like red apples',                'Tính từ + Danh từ + が + 好きです', 'Adjective + Noun + が + 好きです', 1),
(1,  'かおがあかくなりました',   '顔が赤くなりました',       'Kao ga akaku narimashita',          'Khuôn mặt tôi đỏ lên',             'My face turned red',               'Chỉ sự thay đổi trạng thái',       'Indicates a change of state',      2),
(2,  'あさごはんをたべます',     '朝ご飯を食べます',         'Asa gohan o tabemasu',              'Tôi ăn sáng',                      'I eat breakfast',                  'Danh từ thời gian + を + Động từ', 'Time noun + を + Verb',            3),
(9,  'このえいがはいいですね',   'この映画はいいですね',     'Kono eiga wa ii desu ne',           'Bộ phim này hay nhỉ',              'This movie is good, isn''t it?',   'Tính từ + ですね (đồng tình)',     'Adjective + ですね (seeking agreement)', 4),
(7,  'いぬがかわいいです',       '犬が可愛いです',           'Inu ga kawaii desu',                'Con chó thật dễ thương',           'The dog is cute',                  'Danh từ + が + Tính từ',           'Noun + が + Adjective',            5),
(10, 'うみがきれいです',         '海がきれいです',           'Umi ga kirei desu',                 'Biển đẹp quá',                     'The sea is beautiful',             'Mô tả cảnh thiên nhiên',           'Describing natural scenery',       6),
(12, 'えきでまっています',       '駅で待っています',         'Eki de matte imasu',                'Tôi đang chờ ở ga',                'I am waiting at the station',      'Địa điểm + で + Động từ tiếp diễn', 'Place + で + Continuous verb',   7),
(14, 'おおきいへやですね',       '大きい部屋ですね',         'Ookii heya desu ne',                'Phòng rộng nhỉ',                   'It''s a big room, isn''t it?',     'Tính từ + Danh từ + です',         'Adjective + Noun + です',          8);

-- ===========================================================================
-- FUNCTIONS & TRIGGERS
-- ===========================================================================

-- A simple fuzzy-match helper that checks SOUNDEX equivalence alongside
-- substring containment — handy for forgiving vocabulary searches.
DELIMITER //
CREATE FUNCTION fuzzy_match(search_term VARCHAR(255), target_term VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    RETURN SOUNDEX(search_term) = SOUNDEX(target_term)
        OR target_term  LIKE CONCAT('%', search_term, '%')
        OR search_term  LIKE CONCAT('%', target_term, '%');
END //
DELIMITER ;

-- Keeps each user's search history trim by automatically pruning
-- anything beyond the most recent 1000 entries after every insert.
DELIMITER //
CREATE TRIGGER cleanup_search_history
AFTER INSERT ON search_history
FOR EACH ROW
BEGIN
    DELETE FROM search_history
    WHERE  user_id = NEW.user_id
      AND  id NOT IN (
               SELECT id FROM (
                   SELECT id
                   FROM   search_history
                   WHERE  user_id = NEW.user_id
                   ORDER  BY searched_at DESC
                   LIMIT  1000
               ) AS recent_ids
           );
END //
DELIMITER ;