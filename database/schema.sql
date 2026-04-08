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
    question_text_vi TEXT         NOT NULL,
    question_text_en TEXT         NOT NULL,
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

-- ===========================================================================
-- CHAPTERS & SECTIONS — Curriculum structure aligned with structured_lessons
-- Chapter 1 covers the kana writing systems (Lessons 1–6).
-- Chapter 2 covers practical communication and kanji (Lesson 7 onward).
-- Sections provide finer-grained grouping within each chapter.
-- ===========================================================================

INSERT INTO chapters (title_en, title_vi, description_en, description_vi, order_index) VALUES
(
  'Chapter 1: The Kana Writing Systems',
  'Chương 1: Hệ Thống Chữ Kana',
  'Build a complete foundation in hiragana and katakana — the two phonetic scripts that underpin all Japanese reading and writing. By the end of this chapter you will be able to read and write all 46 basic hiragana, 25 voiced/semi-voiced (dakuon) hiragana, 33 combination (yōon) hiragana, and their katakana equivalents.',
  'Xây dựng nền tảng hoàn chỉnh về hiragana và katakana — hai bộ chữ biểu âm là cốt lõi của mọi hoạt động đọc và viết tiếng Nhật. Kết thúc chương này, bạn có thể đọc và viết đầy đủ 46 ký tự hiragana cơ bản, 25 hiragana dakuon (hữu thanh/bán hữu thanh) và 33 hiragana yōon (âm kết hợp), cùng các ký tự katakana tương đương.',
  1
),
(
  'Chapter 2: Communication and Kanji Foundations',
  'Chương 2: Giao Tiếp và Nền Tảng Kanji',
  'Move beyond the kana scripts into practical everyday Japanese. This chapter introduces essential conversational phrases, core N5 vocabulary, and the high-frequency kanji characters that appear most often on the JLPT N5 exam.',
  'Tiến xa hơn bộ chữ kana vào tiếng Nhật thực dụng hàng ngày. Chương này giới thiệu các cụm từ giao tiếp thiết yếu, từ vựng N5 cốt lõi và các ký tự kanji tần suất cao xuất hiện nhiều nhất trong kỳ thi JLPT N5.',
  2
);

-- Sections for Chapter 1 (kana writing systems)
INSERT INTO sections (chapter_id, title_en, title_vi, description_en, description_vi, order_index) VALUES
(
  1,
  'Section 1.1: Basic Hiragana (46 characters)',
  'Mục 1.1: Hiragana Cơ Bản (46 ký tự)',
  'Learn all 46 standard hiragana characters organised into the gojūon (50-sound) chart — the vowel row, and the K, S, T, N, H, M, Y, R, W rows plus the nasal ん. Covers correct stroke order, pronunciation, and beginner vocabulary for each character.',
  'Học đầy đủ 46 ký tự hiragana tiêu chuẩn được sắp xếp theo bảng gojūon (50 âm) — hàng nguyên âm và các hàng K, S, T, N, H, M, Y, R, W cùng phụ âm mũi ん. Bao gồm thứ tự nét bút đúng, cách phát âm và từ vựng cơ bản cho từng ký tự.',
  1
),
(
  1,
  'Section 1.2: Dakuon & Han-dakuon Hiragana (25 characters)',
  'Mục 1.2: Hiragana Dakuon & Han-dakuon (25 ký tự)',
  'Master the voiced and semi-voiced hiragana formed by adding nigori (゛) or maru (゜) diacritics — the G, Z, D, B, and P rows. Includes minimal pair drills to sharpen your ear for voiced vs. unvoiced contrasts.',
  'Nắm vững các hiragana hữu thanh và bán hữu thanh được tạo bằng cách thêm dấu nigori (゛) hoặc maru (゜) — các hàng G, Z, D, B và P. Bao gồm bài luyện cặp tối thiểu để rèn luyện khả năng phân biệt hữu thanh và vô thanh.',
  2
),
(
  1,
  'Section 1.3: Yōon Hiragana (33 combinations)',
  'Mục 1.3: Hiragana Yōon (33 âm kết hợp)',
  'Study the compound sounds formed when a ki/shi/chi/ni/hi/mi/ri/gi/ji/bi/pi kana is followed by a small や, ゆ, or よ — producing contracted syllables like きゃ (kya) and びょ (byo). Practice distinguishing single-mora from double-mora spellings.',
  'Học các âm ghép được tạo khi một kana ki/shi/chi/ni/hi/mi/ri/gi/ji/bi/pi đứng trước や, ゆ, hoặc よ nhỏ — tạo ra các âm tiết rút gọn như きゃ (kya) và びょ (byo). Luyện phân biệt cách đánh vần một mora và hai mora.',
  3
),
(
  1,
  'Section 1.4: Basic Katakana (46 characters)',
  'Mục 1.4: Katakana Cơ Bản (46 ký tự)',
  'Learn all 46 standard katakana characters, focusing on their visual differences from hiragana counterparts and their primary role in writing foreign loanwords (gairaigo), onomatopoeia, and emphasis.',
  'Học đầy đủ 46 ký tự katakana tiêu chuẩn, tập trung vào sự khác biệt hình dạng so với hiragana tương ứng và vai trò chính trong việc viết từ vay mượn nước ngoài (gairaigo), từ tượng thanh và nhấn mạnh.',
  4
),
(
  1,
  'Section 1.5: Dakuon & Yōon Katakana (58 characters)',
  'Mục 1.5: Katakana Dakuon & Yōon (58 ký tự)',
  'Complete your katakana knowledge with the voiced rows (G, Z, D, B, P) and combination sounds (kya, sha, chi, etc.), plus special extended-vowel and consonant clusters unique to katakana loanword spelling.',
  'Hoàn thiện kiến thức katakana với các hàng hữu thanh (G, Z, D, B, P) và âm kết hợp (kya, sha, chi, v.v.), cùng các nguyên âm kéo dài và tổ hợp phụ âm đặc biệt dành riêng cho chính tả katakana.',
  5
);

-- Sections for Chapter 2 (communication and kanji)
INSERT INTO sections (chapter_id, title_en, title_vi, description_en, description_vi, order_index) VALUES
(
  2,
  'Section 2.1: Everyday Communication Phrases',
  'Mục 2.1: Cụm Từ Giao Tiếp Hàng Ngày',
  'Build a working toolkit of greetings, farewells, polite requests, apologies, and common conversational expressions. Includes situational dialogues for shopping, travel, and introductions.',
  'Xây dựng bộ công cụ thực dụng gồm các lời chào hỏi, tạm biệt, yêu cầu lịch sự, xin lỗi và các mẫu câu hội thoại thông dụng. Bao gồm các đoạn hội thoại tình huống trong mua sắm, đi lại và giới thiệu bản thân.',
  1
),
(
  2,
  'Section 2.2: High-Frequency N5 Kanji (100 characters)',
  'Mục 2.2: Kanji N5 Tần Suất Cao (100 ký tự)',
  'Study the 100 kanji characters that appear most frequently on the JLPT N5 exam. Each entry covers the character, its on-yomi (Chinese reading), kun-yomi (Japanese reading), core meaning, visual mnemonic, and example vocabulary.',
  'Học 100 ký tự kanji xuất hiện thường xuyên nhất trong kỳ thi JLPT N5. Mỗi mục bao gồm ký tự, âm on-yomi (âm Hán-Nhật), âm kun-yomi (âm thuần Nhật), nghĩa cốt lõi, gợi nhớ hình ảnh và ví dụ từ vựng.',
  2
);

-- Link structured_lessons to the appropriate sections
-- Section IDs: 1=Basic Hiragana, 2=Dakuon Hiragana, 3=Yōon Hiragana,
--              4=Basic Katakana, 5=Dakuon+Yōon Katakana,
--              6=Communication Phrases, 7=N5 Kanji
UPDATE structured_lessons SET section_id = 1 WHERE lesson_number = 1;
UPDATE structured_lessons SET section_id = 2 WHERE lesson_number = 2;
UPDATE structured_lessons SET section_id = 3 WHERE lesson_number = 3;
UPDATE structured_lessons SET section_id = 4 WHERE lesson_number = 4;
UPDATE structured_lessons SET section_id = 5 WHERE lesson_number = 5 AND lesson_type = 'character_learning';
UPDATE structured_lessons SET section_id = 6 WHERE lesson_number = 6;
UPDATE structured_lessons SET section_id = 7 WHERE lesson_number = 7;

-- ===========================================================================
-- KANJI CHARACTERS — 100 high-frequency JLPT N5 kanji
-- Grouped thematically for easier memorisation.
-- on_reading / kun_reading are stored in the romaji field (primary reading).
-- Full readings are embedded in the mnemonic fields.
-- ===========================================================================
INSERT INTO characters (kana, romaji, hiragana, katakana, kanji, type, group_name, difficulty, mnemonic_vi, mnemonic_en, position_in_group) VALUES

-- ── Numbers & Counting ───────────────────────────────────────────────────
('一', 'ichi / hito(tsu)', NULL, NULL, '一', 'kanji', 'numbers', 'beginner',
 'Một nét nằm ngang duy nhất = số một. Đơn giản nhất trong tất cả kanji.',
 'A single horizontal stroke = one. The simplest of all kanji.', 1),

('二', 'ni / futa(tsu)', NULL, NULL, '二', 'kanji', 'numbers', 'beginner',
 'Hai nét nằm ngang = số hai. Nét dưới dài hơn nét trên.',
 'Two horizontal strokes = two. The lower stroke is longer than the upper.', 2),

('三', 'san / mit(tsu)', NULL, NULL, '三', 'kanji', 'numbers', 'beginner',
 'Ba nét nằm ngang = số ba. Nét giữa ngắn nhất.',
 'Three horizontal strokes = three. The middle stroke is the shortest.', 3),

('四', 'shi / yot(tsu)', NULL, NULL, '四', 'kanji', 'numbers', 'beginner',
 'Hình hộp với hai chân thò ra = số bốn. Hình dáng giống chiếc ghế bốn chân.',
 'A box with two legs dangling = four. The shape resembles a four-legged stool.', 4),

('五', 'go / itsu(tsu)', NULL, NULL, '五', 'kanji', 'numbers', 'beginner',
 'Hình chữ Z đặt nằm ngang với cây gậy đâm qua = số năm. Đếm năm ngón tay.',
 'A sideways Z with a rod through it = five. Picture counting five fingers.', 5),

('六', 'roku / mut(tsu)', NULL, NULL, '六', 'kanji', 'numbers', 'beginner',
 'Mái nhà với hai chân = số sáu. Hình dáng như ngôi nhà nhỏ.',
 'A roof with two legs = six. Picture a little house with a pointed roof.', 6),

('七', 'shichi / nana(tsu)', NULL, NULL, '七', 'kanji', 'numbers', 'beginner',
 'Số 7 bị cắt chéo = số bảy. Nét xiên từ phải sang trái là nét đặc trưng.',
 'A crossed 7 shape = seven. The diagonal slash from right to left is distinctive.', 7),

('八', 'hachi / yat(tsu)', NULL, NULL, '八', 'kanji', 'numbers', 'beginner',
 'Hai nét toé ra như chữ V ngược = số tám. Tượng trưng cho sự phồn thịnh vì toé ra rộng.',
 'Two strokes spreading apart like an upside-down V = eight. Considered lucky for its expanding shape.', 8),

('九', 'kyuu / kokono(tsu)', NULL, NULL, '九', 'kanji', 'numbers', 'beginner',
 'Dấu câu hỏi cong cong = số chín. Nét móc xuống như tay người đang kéo.',
 'A curved question-mark shape = nine. The hooking stroke looks like a reaching hand.', 9),

('十', 'juu / too', NULL, NULL, '十', 'kanji', 'numbers', 'beginner',
 'Hình chữ thập = mười. Nét dọc cắt qua nét ngang tạo thành dấu cộng.',
 'A cross shape = ten. A vertical stroke intersecting a horizontal one, like a plus sign.', 10),

('百', 'hyaku', NULL, NULL, '百', 'kanji', 'numbers', 'beginner',
 'Số một trên đầu hộp chữ nhật = một trăm. Tưởng tượng 100 hộp xếp thành hàng.',
 'One perched on top of a rectangular box = one hundred. Imagine 100 boxes stacked in a row.', 11),

('千', 'sen / chi', NULL, NULL, '千', 'kanji', 'numbers', 'beginner',
 'Dấu gạch xiên trên chữ thập = một nghìn. Chữ thập với mái che bên trên.',
 'A diagonal cap atop a cross = one thousand. A cross wearing a little slanted hat.', 12),

('万', 'man / yorozu', NULL, NULL, '万', 'kanji', 'numbers', 'beginner',
 'Hình bướm hoặc cờ bay = mười nghìn. Nét ngang trên đầu biểu tượng cho số lượng rất lớn.',
 'A butterfly or waving flag shape = ten thousand. The horizontal cap suggests an enormous quantity.', 13),

-- ── Time ─────────────────────────────────────────────────────────────────
('日', 'nichi / hi / ka', NULL, NULL, '日', 'kanji', 'time', 'beginner',
 'Hình tròn có đường kẻ giữa = mặt trời / ngày. Người Nhật cổ đại vẽ mặt trời là hình tròn sáng rực.',
 'A circle with a centre line = sun / day. Ancient Japanese depicted the sun as a bright, bounded circle.', 14),

('月', 'getsu / tsuki', NULL, NULL, '月', 'kanji', 'time', 'beginner',
 'Cửa sổ lưỡi liềm với hai dấu chấm bên trong = mặt trăng / tháng. Hai nét trong là ánh trăng rọi qua.',
 'A crescent window with two interior marks = moon / month. The two inner strokes are moonbeams shining through.', 15),

('年', 'nen / toshi', NULL, NULL, '年', 'kanji', 'time', 'beginner',
 'Bông lúa cúi xuống trên cọc = năm. Thu hoạch lúa mỗi năm một lần là nhịp đời của người Nhật xưa.',
 'A bent grain stalk above a stake = year. The annual rice harvest marked the rhythm of traditional Japanese life.', 16),

('時', 'ji / toki', NULL, NULL, '時', 'kanji', 'time', 'beginner',
 'Chữ Nhật (mặt trời) + bộ thổ + tấc đất = thời gian. Mặt trời đi qua bầu trời đo thời gian.',
 'Sun radical + earth + measuring unit = time. The sun traversing the sky is how ancient people measured hours.', 17),

('間', 'kan / ma / aida', NULL, NULL, '間', 'kanji', 'time', 'beginner',
 'Mặt trăng nhìn qua khe cửa = khoảng thời gian / khoảng không gian. Ánh sáng lọt qua khe hở.',
 'Moonlight visible through a gate gap = interval / space between. Light filtering through an opening.', 18),

('今', 'kon / ima', NULL, NULL, '今', 'kanji', 'time', 'beginner',
 'Mái nhà che một người đang ngồi xuống = bây giờ. Hành động ngồi xuống diễn ra ngay lúc này.',
 'A roof sheltering a person bending down = now. The act of sitting down is happening at this very moment.', 19),

('前', 'zen / mae', NULL, NULL, '前', 'kanji', 'time', 'beginner',
 'Thuyền + dao = phía trước / trước đây. Con thuyền cắt qua sóng tiến về phía trước.',
 'A boat + knife = front / before. A boat cutting forward through the waves with a blade at its prow.', 20),

('後', 'go / kou / ato / nochi', NULL, NULL, '後', 'kanji', 'time', 'beginner',
 'Người đi nhỏ + sợi chỉ nhỏ = phía sau / sau này. Sợi chỉ kéo người đi chậm lại phía sau.',
 'Small-step radical + tiny thread = behind / after. A little thread slowing the walking figure from behind.', 21),

-- ── People & Family ───────────────────────────────────────────────────────
('人', 'jin / nin / hito', NULL, NULL, '人', 'kanji', 'people', 'beginner',
 'Hai nét như người đứng dạng chân = người. Hình bóng con người nhìn từ bên cạnh.',
 'Two strokes like a person standing with legs apart = person. A silhouette of a human viewed from the side.', 22),

('子', 'shi / ko', NULL, NULL, '子', 'kanji', 'people', 'beginner',
 'Hình trẻ em ngồi với tay giơ lên và chân bó = con / đứa trẻ. Tư thế của em bé bị quấn tã.',
 'A child sitting with arms raised and legs wrapped = child. The posture of a baby bundled in swaddling.', 23),

('女', 'jo / onna', NULL, NULL, '女', 'kanji', 'people', 'beginner',
 'Người phụ nữ quỳ gối chắp tay = phụ nữ. Phản ánh vai trò truyền thống trong xã hội Nhật cổ.',
 'A kneeling figure with hands folded = woman. Reflects the demure posture in classical Japanese depictions.', 24),

('男', 'dan / nan / otoko', NULL, NULL, '男', 'kanji', 'people', 'beginner',
 'Đồng ruộng (田) + sức mạnh (力) = đàn ông. Người làm việc ngoài đồng bằng sức lực.',
 'Field (田) + strength (力) = man. A person who works the fields using physical power.', 25),

('父', 'fu / chichi', NULL, NULL, '父', 'kanji', 'people', 'beginner',
 'Tay cầm gậy = cha. Người đàn ông cầm gậy quyền uy trong gia đình.',
 'A hand gripping a rod = father. The figure of authority in the household holding a staff.', 26),

('母', 'bo / haha', NULL, NULL, '母', 'kanji', 'people', 'beginner',
 'Phụ nữ với hai dấu chấm = mẹ. Hai dấu chấm tượng trưng cho bộ ngực nuôi con.',
 'Woman shape with two dots added = mother. The two dots symbolise a nursing mother.', 27),

('友', 'yuu / tomo', NULL, NULL, '友', 'kanji', 'people', 'beginner',
 'Tay phải + tay phải = bạn bè. Hai bàn tay phải bắt chặt nhau = tình bạn.',
 'Right hand + right hand = friend. Two right hands clasped together in friendship.', 28),

('先', 'sen / saki', NULL, NULL, '先', 'kanji', 'people', 'beginner',
 'Người đang bước đi với đất bên dưới = trước / người đi trước. Tiên sinh = người sinh ra trước.',
 'A walking person with ground beneath = ahead / one who came before. Sensei literally means "born before".', 29),

('生', 'sei / shou / i(kiru) / u(mareru)', NULL, NULL, '生', 'kanji', 'people', 'beginner',
 'Cây mầm mọc từ đất = sống / sinh ra. Hình ảnh sự sống nảy nở từ lòng đất.',
 'A seedling sprouting from the ground = life / to be born. The image of life pushing up through the soil.', 30),

-- ── Body & Health ─────────────────────────────────────────────────────────
('口', 'kou / kuchi', NULL, NULL, '口', 'kanji', 'body', 'beginner',
 'Hình vuông mở = miệng. Dạng đơn giản nhất của cái miệng đang mở.',
 'An open square = mouth. The most elemental depiction of an open mouth.', 31),

('目', 'moku / me', NULL, NULL, '目', 'kanji', 'body', 'beginner',
 'Hình con mắt dựng đứng với lòng trắng và lòng đen = mắt. Người Nhật cổ vẽ mắt đứng.',
 'An upright eye shape with two horizontal pupils = eye. Classical Japanese art depicted eyes vertically.', 32),

('耳', 'ji / mimi', NULL, NULL, '耳', 'kanji', 'body', 'beginner',
 'Hình bộ phận tai với nhiều ngăn = tai. Các đường kẻ bên trong giống cấu trúc tai trong.',
 'An ear shape with inner chambers = ear. The horizontal lines suggest the inner ear structure.', 33),

('手', 'shu / te', NULL, NULL, '手', 'kanji', 'body', 'beginner',
 'Bàn tay xòe với ngón cái ngang = bàn tay. Ba nét trên là các ngón, nét cong là lòng bàn tay.',
 'A spread hand with a horizontal thumb = hand. The three upper strokes are fingers; the curve is the palm.', 34),

('足', 'soku / ashi', NULL, NULL, '足', 'kanji', 'body', 'beginner',
 'Miệng trên + chân đi bộ dưới = chân / đủ. Chân là thứ đủ để giúp ta di chuyển.',
 'Mouth shape above a walking-leg stroke = leg / sufficient. Feet are enough to carry you anywhere.', 35),

-- ── Nature ────────────────────────────────────────────────────────────────
('山', 'san / yama', NULL, NULL, '山', 'kanji', 'nature', 'beginner',
 'Ba đỉnh núi nhọn = núi. Đỉnh giữa cao nhất, biểu trưng cho núi Phú Sĩ.',
 'Three mountain peaks = mountain. The tallest centre peak evokes Mount Fuji.', 36),

('川', 'sen / kawa', NULL, NULL, '川', 'kanji', 'nature', 'beginner',
 'Ba đường chảy song song xuống = sông. Dòng nước chảy từ trên xuống dưới.',
 'Three parallel downward flowing lines = river. Water streaming downward.', 37),

('木', 'moku / ki', NULL, NULL, '木', 'kanji', 'nature', 'beginner',
 'Thân cây với cành trên và rễ dưới = cây / gỗ. Hình cây hoàn chỉnh với cành và rễ.',
 'A trunk with branches above and roots below = tree / wood. A complete tree with canopy and roots.', 38),

('林', 'rin / hayashi', NULL, NULL, '林', 'kanji', 'nature', 'beginner',
 'Cây + cây = rừng nhỏ. Hai cây đứng cạnh nhau tạo nên một khu rừng nhỏ.',
 'Tree + tree = grove. Two trees side by side make a small woodland.', 39),

('森', 'shin / mori', NULL, NULL, '森', 'kanji', 'nature', 'beginner',
 'Ba cây = rừng lớn. Nhiều hơn hai cây tạo nên một cánh rừng rậm rạp.',
 'Three trees = forest. More than two trees together create a dense forest.', 40),

('火', 'ka / hi', NULL, NULL, '火', 'kanji', 'nature', 'beginner',
 'Hình ngọn lửa bùng lên với tia lửa tứ phía = lửa. Nét giữa là ngọn, các nét bên là tia lửa.',
 'Flames rising with sparks flying to either side = fire. The centre stroke is the main flame; side strokes are sparks.', 41),

('水', 'sui / mizu', NULL, NULL, '水', 'kanji', 'nature', 'beginner',
 'Nét trung tâm có ba nét nhỏ toé ra = nước. Các tia nhỏ tượng trưng cho nước chảy tứ phía.',
 'A central stroke with three small splashing lines = water. The splashes suggest water flowing in all directions.', 42),

('土', 'do / to / tsuchi', NULL, NULL, '土', 'kanji', 'nature', 'beginner',
 'Cây gậy cắm vào mặt đất = đất. Chữ thập dưới là mặt đất, nét trên là mầm cây.',
 'A rod planted in the ground = earth / soil. The lower cross is the ground; the top stroke is a sprouting plant.', 43),

('金', 'kin / kon / kane', NULL, NULL, '金', 'kanji', 'nature', 'beginner',
 'Mái nhà + đất + hai hạt khoáng sản = vàng / tiền. Khoáng sản quý chôn vùi trong lòng đất.',
 'Roof + earth + two mineral nuggets = gold / money. Precious ore hidden underground.', 44),

('空', 'kuu / sora / a(ku)', NULL, NULL, '空', 'kanji', 'nature', 'beginner',
 'Mái nhà + công cụ đào = bầu trời / trống rỗng. Đào rỗng bên trong để thấy bầu trời trên đầu.',
 'Roof + digging tool = sky / empty. Hollowing out beneath a roof reveals the open sky above.', 45),

('雨', 'u / ame', NULL, NULL, '雨', 'kanji', 'nature', 'beginner',
 'Mây ngang với bốn giọt mưa rơi xuống = mưa. Rèm mây và các giọt nước tượng trưng cho cơn mưa.',
 'A horizontal cloud with four raindrops falling = rain. The cloud canopy with falling drops captures a rainfall.', 46),

('花', 'ka / hana', NULL, NULL, '花', 'kanji', 'nature', 'beginner',
 'Bộ cỏ trên đầu + biến đổi = hoa. Cây cỏ trải qua biến đổi để nở ra hoa rực rỡ.',
 'Grass radical above + transformation = flower. Plants undergo transformation (化) to bloom into flowers.', 47),

('石', 'seki / ishi', NULL, NULL, '石', 'kanji', 'nature', 'beginner',
 'Vách núi với hòn đá dưới chân = đá. Đá lăn từ vách núi xuống.',
 'A cliff face with a stone at its foot = rock / stone. Rocks fall from cliffs to the ground below.', 48),

('気', 'ki / ke', NULL, NULL, '気', 'kanji', 'nature', 'beginner',
 'Hơi nước bốc lên từ cơm trong nồi = khí / tinh thần / thời tiết. Hơi nóng bốc lên là "khí".',
 'Steam rising from rice in a pot = spirit / energy / weather. Rising vapour captures the concept of life-energy.', 49),

-- ── Location & Direction ──────────────────────────────────────────────────
('上', 'jou / ue / a(garu)', NULL, NULL, '上', 'kanji', 'location', 'beginner',
 'Điểm trên đường thẳng = phía trên. Điểm nhấn nằm bên trên đường nền.',
 'A mark above a baseline = above / up. A reference point sitting above the ground line.', 50),

('下', 'ka / ge / shita / sa(garu)', NULL, NULL, '下', 'kanji', 'location', 'beginner',
 'Điểm dưới đường thẳng = phía dưới. Đối lập trực tiếp với chữ 上.',
 'A mark below a baseline = below / down. The direct mirror of 上.', 51),

('中', 'chuu / naka', NULL, NULL, '中', 'kanji', 'location', 'beginner',
 'Hình hộp chữ nhật bị mũi tên xuyên qua giữa = ở giữa / trong. Mũi tên trúng đúng tâm.',
 'A rectangle pierced through its centre = middle / inside. An arrow hitting the exact centre of a target.', 52),

('右', 'u / migi', NULL, NULL, '右', 'kanji', 'location', 'beginner',
 'Tay phải + miệng = phải. Tay phải dùng để ăn = hướng phải.',
 'Right hand + mouth = right (direction). The right hand is used for eating, hence "right" direction.', 53),

('左', 'sa / hidari', NULL, NULL, '左', 'kanji', 'location', 'beginner',
 'Tay trái + công cụ = trái. Tay trái cầm công cụ hỗ trợ tay phải.',
 'Left hand + tool = left (direction). The left hand holds the tool to assist the dominant right hand.', 54),

('東', 'tou / higashi', NULL, NULL, '東', 'kanji', 'location', 'beginner',
 'Mặt trời mọc sau cây = phía đông. Mặt trời buổi sáng lấp ló sau lưng cây.', 
 'The sun rising behind a tree = east. The morning sun peeks from behind a tree trunk.', 55),

('西', 'sei / nishi', NULL, NULL, '西', 'kanji', 'location', 'beginner',
 'Chim đậu trên tổ lúc chiều tối = phía tây. Chim bay về phía tây về tổ khi hoàng hôn.',
 'A bird settling into its nest at dusk = west. Birds fly westward home at sunset.', 56),

('南', 'nan / minami', NULL, NULL, '南', 'kanji', 'location', 'beginner',
 'Thảo mộc đang mọc = phía nam. Cây trưởng thành hướng về phía mặt trời chiếu nhiều nhất (nam).',
 'A thriving plant growing tall = south. Plants lean toward the most sunlit direction — the south.', 57),

('北', 'hoku / kita', NULL, NULL, '北', 'kanji', 'location', 'beginner',
 'Hai người quay lưng vào nhau = phía bắc. Khi lạnh người ta quay lưng về hướng bắc lạnh giá.',
 'Two people sitting back-to-back = north. When cold, people turn their backs to the icy north wind.', 58),

('外', 'gai / soto / hoka', NULL, NULL, '外', 'kanji', 'location', 'beginner',
 'Chiều tối + bói toán = bên ngoài. Người xưa bói bên ngoài vào lúc chiều tối.',
 'Evening + divination = outside. Ancients performed divination rituals outside at dusk.', 59),

('内', 'nai / uchi / nai', NULL, NULL, '内', 'kanji', 'location', 'beginner',
 'Người bên trong mái nhà = bên trong / ở trong nhà. Người đứng dưới mái che.',
 'A person sheltered under a roof = inside / one''s own home. The figure is safely beneath a covering.', 60),

-- ── Things & Objects ─────────────────────────────────────────────────────
('車', 'sha / kuruma', NULL, NULL, '車', 'kanji', 'objects', 'beginner',
 'Bánh xe nhìn từ trên xuống với trục ở giữa = xe. Hình dạng bánh xe và nan hoa.',
 'A wheel viewed from above with a central axle = vehicle. The wheel with spokes and hub.', 61),

('電', 'den', NULL, NULL, '電', 'kanji', 'objects', 'beginner',
 'Mưa + sét đánh xuống = điện. Tia sét trong cơn mưa là nguồn gốc của điện trong tự nhiên.',
 'Rain + lightning striking down = electricity. Lightning in a rainstorm — the natural origin of electricity.', 62),

('本', 'hon / moto', NULL, NULL, '本', 'kanji', 'objects', 'beginner',
 'Cây (木) với dấu gạch ở gốc = gốc rễ / quyển sách. Dấu gạch chỉ nơi quan trọng nhất của cây.',
 'Tree (木) with a mark at the base = origin / book. The mark highlights the most important part of a tree — its root.', 63),

('門', 'mon / kado', NULL, NULL, '門', 'kanji', 'objects', 'beginner',
 'Hai cánh cổng mở ra = cổng / cửa lớn. Hình ảnh trực quan của một cánh cổng gỗ truyền thống.',
 'Two gate panels swung open = gate / large door. A vivid picture of a traditional wooden gate.', 64),

('国', 'koku / kuni', NULL, NULL, '国', 'kanji', 'objects', 'beginner',
 'Đất đai được bao quanh bởi biên giới = quốc gia. Phần trong là viên ngọc / tài nguyên của đất nước.',
 'Bordered land surrounding a jewel = country. The interior jewel represents a nation''s treasured resources.', 65),

('語', 'go / kata(ru)', NULL, NULL, '語', 'kanji', 'objects', 'beginner',
 'Lời nói + ngã + miệng = ngôn ngữ / kể chuyện. Tôi dùng miệng để nói ngôn ngữ.',
 'Words + I + mouth = language / to speak. I use my mouth to speak a language.', 66),

('字', 'ji / aza', NULL, NULL, '字', 'kanji', 'objects', 'beginner',
 'Mái nhà + con = chữ. Đứa trẻ học chữ dưới mái trường.',
 'Roof + child = character / letter. A child learning characters under a school roof.', 67),

('名', 'mei / myou / na', NULL, NULL, '名', 'kanji', 'objects', 'beginner',
 'Chiều tối + miệng = tên. Lúc tối không thấy nhau nên phải gọi tên bằng miệng.',
 'Evening + mouth = name. When it''s dark and you cannot see someone, you call out their name.', 68),

('食', 'shoku / ta(beru)', NULL, NULL, '食', 'kanji', 'objects', 'beginner',
 'Cái nắp + cơm trong bát = ăn. Nhấc nắp lên để ăn thức ăn bên trong.',
 'A lid + rice in a bowl = to eat. Lift the lid to eat what is inside the bowl.', 69),

('飲', 'in / no(mu)', NULL, NULL, '飲', 'kanji', 'objects', 'beginner',
 'Thức ăn (食) + ngáp / há miệng = uống. Ngẩng đầu há miệng để uống từ bình.',
 'Food radical (食) + yawning / open mouth = to drink. Tilting the head back and opening wide to drink from a vessel.', 70),

-- ── School & Learning ─────────────────────────────────────────────────────
('学', 'gaku / mana(bu)', NULL, NULL, '学', 'kanji', 'school', 'beginner',
 'Mái nhà + bàn tay + đứa trẻ = học. Đứa trẻ được bàn tay dẫn dắt vào học dưới mái trường.',
 'Roof + guiding hands + child = to study / learning. A child guided by hands to learn beneath a schoolhouse roof.', 71),

('校', 'kou', NULL, NULL, '校', 'kanji', 'school', 'beginner',
 'Cây (木) + giao nhau = trường học. Nhiều học sinh giao nhau dưới tán cây.',
 'Tree (木) + crossing paths = school. Many students crossing paths under the shade of trees.', 72),

('先', 'sen / saki', NULL, NULL, '先', 'kanji', 'school', 'beginner',
 'Người tiên phong bước về phía trước = trước / thầy cô. Thầy là người đi trước học trò.',
 'A pioneer stepping forward = ahead / teacher. The teacher goes ahead of the student.', 73),

('読', 'doku / yomi / yo(mu)', NULL, NULL, '読', 'kanji', 'school', 'beginner',
 'Lời nói + bán = đọc. Đọc sách là "bán" ý tưởng từ người viết sang người đọc.',
 'Words + to sell = to read. Reading is "selling" ideas from the writer to the reader.', 74),

('書', 'sho / ka(ku)', NULL, NULL, '書', 'kanji', 'school', 'beginner',
 'Lông vũ / bút + mặt trời / ngày = viết. Cầm bút ghi lại những gì diễn ra mỗi ngày.',
 'Brush / feather + sun / day = to write. Holding a brush to record what happens each day.', 75),

('聞', 'bun / mon / ki(ku)', NULL, NULL, '聞', 'kanji', 'school', 'beginner',
 'Cổng (門) + tai (耳) = nghe / hỏi. Đặt tai vào cổng để nghe những gì bên trong.',
 'Gate (門) + ear (耳) = to listen / to ask. Press your ear to the gate to hear what is inside.', 76),

('話', 'wa / hana(su)', NULL, NULL, '話', 'kanji', 'school', 'beginner',
 'Lời nói + lưỡi = nói chuyện. Lưỡi là công cụ tạo ra lời nói.',
 'Words + tongue = to talk. The tongue is the instrument that produces speech.', 77),

('見', 'ken / mi(ru)', NULL, NULL, '見', 'kanji', 'school', 'beginner',
 'Mắt (目) đứng trên chân người = nhìn / xem. Người đứng nhìn bằng đôi mắt.',
 'An eye (目) atop a walking figure = to see / to look. A person standing and seeing with their eyes.', 78),

('言', 'gen / gon / i(u)', NULL, NULL, '言', 'kanji', 'school', 'beginner',
 'Miệng phát ra nhiều lời = nói. Miệng ở dưới, nhiều nét sóng phía trên là âm thanh phát ra.',
 'A mouth emitting multiple sound waves = to say / words. The mouth below with wavy lines above represents speech.', 79),

-- ── Verbs & Actions ───────────────────────────────────────────────────────
('行', 'kou / gyou / i(ku) / yu(ku)', NULL, NULL, '行', 'kanji', 'verbs', 'beginner',
 'Ngã tư đường = đi / hành. Nơi ngã tư là nơi người ta đi lại.',
 'A crossroads = to go / to travel. Crossroads are where people are always going somewhere.', 80),

('来', 'rai / ku(ru) / ki(taru)', NULL, NULL, '来', 'kanji', 'verbs', 'beginner',
 'Cây lúa mì chín trên đồng = đến / đến nơi. Lúa mì chín thì người ta đến gặt.',
 'A ripe wheat plant on a field = to come / to arrive. When the wheat is ripe, people come to harvest it.', 81),

('出', 'shutsu / de(ru) / da(su)', NULL, NULL, '出', 'kanji', 'verbs', 'beginner',
 'Cây mầm mọc ra khỏi mặt đất, cao hơn = ra / xuất. Nảy mầm vươn ra ngoài.',
 'A sprout pushing out of the ground, growing taller = to exit / to put out. Life pushing outward and upward.', 82),

('入', 'nyuu / i(ru) / hai(ru)', NULL, NULL, '入', 'kanji', 'verbs', 'beginner',
 'Nét chỉ hướng vào trong = vào. Mũi tên đi vào trong.',
 'A stroke pointing inward = to enter. An arrow directed inward.', 83),

('見', 'ken / mi(ru)', NULL, NULL, '見', 'kanji', 'verbs', 'beginner',
 'Mắt trên chân người = nhìn. Người dùng mắt để nhìn xung quanh.',
 'Eye above a person = to see. A person using their eyes to look around.', 84),

('買', 'bai / ka(u)', NULL, NULL, '買', 'kanji', 'verbs', 'beginner',
 'Lưới + bối (vỏ sò dùng làm tiền) = mua. Dùng tiền (vỏ sò) để mua hàng trong lưới.',
 'Net + shell-money = to buy. Using shell currency (ancient money) to purchase goods in a net bag.', 85),

('帰', 'ki / kae(ru)', NULL, NULL, '帰', 'kanji', 'verbs', 'beginner',
 'Quét sạch + mái nhà = về nhà. Quét dọn nhà cửa trước khi về.',
 'Broom + home = to return home. Sweeping up before you go home.', 86),

('起', 'ki / o(kiru) / o(kosu)', NULL, NULL, '起', 'kanji', 'verbs', 'beginner',
 'Chạy + bản thân = thức dậy / xảy ra. Bản thân mình đứng dậy và bắt đầu chạy.',
 'Running + self = to wake up / to happen. You yourself rising and starting to move.', 87),

('立', 'ritsu / ta(tsu)', NULL, NULL, '立', 'kanji', 'verbs', 'beginner',
 'Người đứng trên mặt đất = đứng. Người thẳng đứng trên nền đất.',
 'A person standing on the ground = to stand. A figure erect upon the ground.', 88),

('待', 'tai / ma(tsu)', NULL, NULL, '待', 'kanji', 'verbs', 'beginner',
 'Đi nhỏ + chùa = chờ đợi. Đứng nán lại trước cửa chùa chờ.',
 'Small steps + temple = to wait. Standing still before a temple, waiting patiently.', 89),

('使', 'shi / tsuka(u)', NULL, NULL, '使', 'kanji', 'verbs', 'beginner',
 'Người + quan lại = sử dụng / đại sứ. Người được giao việc phải dùng các phương tiện sẵn có.',
 'Person + official = to use / envoy. A person tasked with an official mission, using all available means.', 90),

-- ── Adjectives & Qualities ────────────────────────────────────────────────
('大', 'dai / tai / oo(kii)', NULL, NULL, '大', 'kanji', 'adjectives', 'beginner',
 'Người dang rộng tay = to lớn. Cánh tay giang rộng hết mức biểu thị sự lớn lao.',
 'A person with arms spread wide = big / large. Arms stretched as far as possible to show great size.', 91),

('小', 'shou / chii(sai) / ko', NULL, NULL, '小', 'kanji', 'adjectives', 'beginner',
 'Nét trung tâm với hai nét nhỏ ở hai bên = nhỏ. Hai nét nhỏ bị đẩy ra xa nét trung tâm.',
 'A central stroke with two tiny side marks pushed apart = small. The small marks are squeezed away from the centre.', 92),

('高', 'kou / taka(i)', NULL, NULL, '高', 'kanji', 'adjectives', 'beginner',
 'Tòa tháp cao với cổng vào = cao / đắt. Tháp cổng của kinh thành ngày xưa rất cao và quý giá.',
 'A tall tower with an entrance gate = tall / expensive. Ancient gatehouse towers were both towering and costly.', 93),

('長', 'chou / naga(i)', NULL, NULL, '長', 'kanji', 'adjectives', 'beginner',
 'Người già với mái tóc dài = dài / lâu. Tóc người già mọc dài theo năm tháng.',
 'An elder with long flowing hair = long. An old person''s hair grows long over many years.', 94),

('新', 'shin / atara(shii) / ara(ta)', NULL, NULL, '新', 'kanji', 'adjectives', 'beginner',
 'Đứng cạnh cây + rìu = mới. Đốn cây bằng rìu để tạo ra vật liệu mới tinh.',
 'Stand beside a tree + axe = new. Felling a tree with an axe to produce fresh new timber.', 95),

('古', 'ko / furu(i)', NULL, NULL, '古', 'kanji', 'adjectives', 'beginner',
 'Mười (十) + miệng (口) = cũ. Truyền miệng qua mười thế hệ là thứ đã cũ.',
 'Ten (十) + mouth (口) = old / ancient. Passed by word of mouth through ten generations = old.', 96),

('白', 'haku / shiro(i)', NULL, NULL, '白', 'kanji', 'adjectives', 'beginner',
 'Mặt trời với tia sáng = trắng. Ánh sáng mặt trời chiếu vào là màu trắng thuần túy.',
 'Sun with a ray of light = white. Pure sunlight streaming down is the purest white.', 97),

('赤', 'seki / aka(i)', NULL, NULL, '赤', 'kanji', 'adjectives', 'beginner',
 'Đất + lửa = đỏ. Đất nung nóng bởi lửa chuyển thành màu đỏ.',
 'Earth + fire = red. Earth heated by fire turns a deep, glowing red.', 98),

('青', 'sei / ao(i)', NULL, NULL, '青', 'kanji', 'adjectives', 'beginner',
 'Cây mọc + mặt trăng = xanh lam / xanh lá. Cây cỏ và bầu trời đêm đều xanh theo cách riêng.',
 'Growing plant + moon = blue / green. Plants and the moonlit sky are each "ao" in their own way.', 99),

('黒', 'koku / kuro(i)', NULL, NULL, '黒', 'kanji', 'adjectives', 'beginner',
 'Cửa sổ bị muội than phủ đen = đen. Muội than bám vào cửa sổ phía trên lò sưởi.',
 'A window blackened with soot = black. Soot from a fire coating the window above a hearth.', 100);

-- (section_id assignments are handled in the chapters/sections block above)

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
('か', 'ka',  'か', 'カ', NULL, 'hiragana', 'k', 'beginner', 'K kết hợp với A', 'K combined with A'),
('き', 'ki',  'き', 'キ', NULL, 'hiragana', 'k', 'beginner', 'K kết hợp với I', 'K combined with I'),
('く', 'ku',  'く', 'ク', NULL, 'hiragana', 'k', 'beginner', 'K kết hợp với U — trông như mỏ chim', 'K combined with U — looks like a bird beak'),
('け', 'ke',  'け', 'ケ', NULL, 'hiragana', 'k', 'beginner', 'K kết hợp với E', 'K combined with E'),
('こ', 'ko',  'こ', 'コ', NULL, 'hiragana', 'k', 'beginner', 'K kết hợp với O — hai nét nằm ngang', 'K combined with O — two horizontal strokes'),
-- Hiragana S row
('さ', 'sa',  'さ', 'サ', NULL, 'hiragana', 's', 'beginner', 'S kết hợp với A', 'S combined with A'),
('し', 'shi', 'し', 'シ', NULL, 'hiragana', 's', 'beginner', 'S kết hợp với I — như cái móc câu', 'S combined with I — like a fishing hook'),
('す', 'su',  'す', 'ス', NULL, 'hiragana', 's', 'beginner', 'S kết hợp với U', 'S combined with U'),
('せ', 'se',  'せ', 'セ', NULL, 'hiragana', 's', 'beginner', 'S kết hợp với E', 'S combined with E'),
('そ', 'so',  'そ', 'ソ', NULL, 'hiragana', 's', 'beginner', 'S kết hợp với O — như sóng nước', 'S combined with O — like a ripple'),
-- Hiragana T row
('た', 'ta',  'た', 'タ', NULL, 'hiragana', 't', 'beginner', 'T kết hợp với A', 'T combined with A'),
('ち', 'chi', 'ち', 'チ', NULL, 'hiragana', 't', 'beginner', 'T kết hợp với I — đọc là "chi"', 'T combined with I — read as "chi"'),
('つ', 'tsu', 'つ', 'ツ', NULL, 'hiragana', 't', 'beginner', 'T kết hợp với U — đọc là "tsu"', 'T combined with U — read as "tsu"'),
('て', 'te',  'て', 'テ', NULL, 'hiragana', 't', 'beginner', 'T kết hợp với E', 'T combined with E'),
('と', 'to',  'と', 'ト', NULL, 'hiragana', 't', 'beginner', 'T kết hợp với O — như cái cây', 'T combined with O — looks like a small tree'),
-- Katakana vowels
('ア', 'a',   'あ', 'ア', NULL, 'katakana', 'a', 'beginner', 'Katakana A — nét thẳng góc', 'Katakana A — angular strokes'),
('イ', 'i',   'い', 'イ', NULL, 'katakana', 'i', 'beginner', 'Katakana I — hai gạch chéo', 'Katakana I — two diagonal strokes'),
('ウ', 'u',   'う', 'ウ', NULL, 'katakana', 'u', 'beginner', 'Katakana U — hình chén úp', 'Katakana U — like an upside-down cup'),
('エ', 'e',   'え', 'エ', NULL, 'katakana', 'e', 'beginner', 'Katakana E — chữ H nằm ngang', 'Katakana E — like a sideways H'),
('オ', 'o',   'お', 'オ', NULL, 'katakana', 'o', 'beginner', 'Katakana O — chữ thập có móc', 'Katakana O — a cross with a hook'),
-- Katakana K row
('カ', 'ka',  'か', 'カ', NULL, 'katakana', 'k', 'beginner', 'Katakana KA', 'Katakana KA'),
('キ', 'ki',  'き', 'キ', NULL, 'katakana', 'k', 'beginner', 'Katakana KI — như cây thước', 'Katakana KI — like a ruler'),
('ク', 'ku',  'く', 'ク', NULL, 'katakana', 'k', 'beginner', 'Katakana KU — như mỏ chim sắc hơn', 'Katakana KU — a sharper bird beak'),
('ケ', 'ke',  'け', 'ケ', NULL, 'katakana', 'k', 'beginner', 'Katakana KE', 'Katakana KE'),
('コ', 'ko',  'こ', 'コ', NULL, 'katakana', 'k', 'beginner', 'Katakana KO — hai vạch ngang ngắn', 'Katakana KO — two short horizontal lines');

-- ===========================================================================
-- STRUCTURED LESSONS — Textbook-quality bilingual lesson content
-- ===========================================================================
INSERT INTO structured_lessons (lesson_number, title_vi, title_en, content_vi, content_en, lesson_type, script_type, order_index, is_active) VALUES

(1,
 'Bài 1: Hiragana Cơ Bản (46 ký tự)',
 'Lesson 1: Basic Hiragana (46 Characters)',
 '## Hiragana là gì?\n\nHiragana (平仮名) là một trong hai bộ ký tự biểu âm của tiếng Nhật. Bộ chữ này gồm **46 ký tự cơ bản**, mỗi ký tự đại diện cho một âm tiết (mora) duy nhất. Hiragana là hệ thống chữ viết bạn cần học **đầu tiên và quan trọng nhất** vì nó xuất hiện trong hầu hết mọi văn bản tiếng Nhật.\n\n## Lịch sử ngắn gọn\n\nHiragana được phát triển vào khoảng thế kỷ 9 từ chữ Hán (kanji) được đơn giản hóa. Ban đầu chủ yếu do phụ nữ quý tộc Heian sử dụng để viết thơ và nhật ký. Ngày nay nó được dùng cho:\n- **Từ ngữ thuần Nhật** không có kanji (ví dụ: ここ, ある)\n- **Furigana**: phiên âm nhỏ trên kanji để hướng dẫn cách đọc\n- **Okurigana**: phần biến đổi ngữ pháp của động từ và tính từ (ví dụ: 食べ**る**)\n- **Trợ từ ngữ pháp**: は、が、を、に、で、も…\n\n## Bảng Gojūon (五十音)\n\nHiragana được sắp xếp theo bảng **Gojūon** (50 âm) gồm 5 hàng nguyên âm (a, i, u, e, o) và 10 cột phụ âm:\n\n| | a | i | u | e | o |\n|---|---|---|---|---|---|\n| ∅ | **あ** | **い** | **う** | **え** | **お** |\n| k | **か** | **き** | **く** | **け** | **こ** |\n| s | **さ** | **し** | **す** | **せ** | **そ** |\n| t | **た** | **ち** | **つ** | **て** | **と** |\n| n | **な** | **に** | **ぬ** | **ね** | **の** |\n| h | **は** | **ひ** | **ふ** | **へ** | **ほ** |\n| m | **ま** | **み** | **む** | **め** | **も** |\n| y | **や** | — | **ゆ** | — | **よ** |\n| r | **ら** | **り** | **る** | **れ** | **ろ** |\n| w | **わ** | — | — | — | **を** |\n| n | **ん** | | | | |\n\n## Các đặc điểm phát âm quan trọng\n\n**し (shi)** — Không phải "si"; lưỡi không chạm vòm miệng.\n**ち (chi)** — Không phải "ti"; âm "ch" như trong "cheese".\n**つ (tsu)** — Không phải "tu"; âm "ts" như trong "tsunami".\n**ふ (fu)** — Không phải "hu" hay "fu" tiếng Anh; môi hơi khép lại thổi nhẹ.\n**ん (n)** — Âm mũi độc lập; phát âm thay đổi theo phụ âm đứng sau.\n\n## Luyện tập thứ tự nét bút\n\nViết đúng thứ tự nét bút giúp bạn viết nhanh và đẹp hơn. Quy tắc chung:\n1. Từ trên xuống dưới\n2. Từ trái sang phải\n3. Nét ngang trước nét dọc (với một số ngoại lệ)\n\n**Ví dụ — あ (a):** Nét 1 nằm ngang (trên), Nét 2 vòng cong (giữa), Nét 3 xoáy tròn (dưới phải).\n\n## Mẹo ghi nhớ nhanh\n\n- **あ** trông như người đang há miệng to nói "A"\n- **い** là hai nét thẳng đứng như chữ số 1 và 1 — hai âm tiết "i-i"\n- **く** trông như mỏ chim đang há\n- **し** như cây câu cong xuống\n- **の** là vòng tròn chữ O với cái đuôi — "no"\n\n## Bài tập đề xuất\n\n1. Viết mỗi ký tự 10 lần theo đúng thứ tự nét bút.\n2. Đọc to từng ký tự khi viết.\n3. Dùng thẻ flash (flashcard) để ôn mỗi ngày 10 phút.\n4. Sau 3 ngày, thử nhận diện ký tự không cần nhìn bảng.',
 '## What is Hiragana?\n\nHiragana (平仮名) is one of two Japanese phonetic scripts. It consists of **46 base characters**, each representing a single syllable (mora). Hiragana is the **first and most essential** writing system to learn, as it appears in virtually every piece of Japanese text.\n\n## Brief History\n\nHiragana evolved around the 9th century from simplified Chinese characters (kanji). It was initially used primarily by Heian court women to write poetry and diaries. Today it is used for:\n- **Native Japanese words** without kanji (e.g., ここ, ある)\n- **Furigana**: small phonetic guides printed above kanji\n- **Okurigana**: the inflectional endings of verbs and adjectives (e.g., 食べ**る**)\n- **Grammatical particles**: は、が、を、に、で、も…\n\n## The Gojūon Chart (五十音)\n\nHiragana is arranged in the **Gojūon** ("fifty-sound") chart with 5 vowel rows (a, i, u, e, o) across 10 consonant columns:\n\n| | a | i | u | e | o |\n|---|---|---|---|---|---|\n| ∅ | **あ** | **い** | **う** | **え** | **お** |\n| k | **か** | **き** | **く** | **け** | **こ** |\n| s | **さ** | **し** | **す** | **せ** | **そ** |\n| t | **た** | **ち** | **つ** | **て** | **と** |\n| n | **な** | **に** | **ぬ** | **ね** | **の** |\n| h | **は** | **ひ** | **ふ** | **へ** | **ほ** |\n| m | **ま** | **み** | **む** | **め** | **も** |\n| y | **や** | — | **ゆ** | — | **よ** |\n| r | **ら** | **り** | **る** | **れ** | **ろ** |\n| w | **わ** | — | — | — | **を** |\n| n | **ん** | | | | |\n\n## Key Pronunciation Points\n\n**し (shi)** — Not "si"; the tongue does not touch the palate.\n**ち (chi)** — Not "ti"; the "ch" sound as in "cheese".\n**つ (tsu)** — Not "tu"; the "ts" cluster as in "tsunami".\n**ふ (fu)** — Neither English "hu" nor "fu"; lips slightly parted with a soft breath.\n**ん (n)** — A standalone nasal; its exact sound shifts depending on the following consonant.\n\n## Stroke Order\n\nCorrect stroke order helps you write quickly and legibly. General rules:\n1. Top to bottom\n2. Left to right\n3. Horizontal strokes before vertical (with some exceptions)\n\n**Example — あ (a):** Stroke 1 horizontal (top), Stroke 2 curved loop (middle), Stroke 3 spiral (lower-right).\n\n## Quick Memory Tips\n\n- **あ** looks like someone opening their mouth wide to say "Ah"\n- **い** is two upright strokes — like two "1"s standing side by side\n- **く** looks like a bird''s open beak\n- **し** is a fishing hook curving down\n- **の** is a circular O with a trailing tail — "no"\n\n## Suggested Practice\n\n1. Write each character 10 times in correct stroke order.\n2. Say the sound aloud as you write.\n3. Use flashcards for 10-minute daily review sessions.\n4. After 3 days, try recognising characters without the chart.',
 'character_learning', 'hiragana', 1, 1),

(2,
 'Bài 2: Hiragana Dakuon — Âm Hữu Thanh (25 ký tự)',
 'Lesson 2: Dakuon Hiragana — Voiced Sounds (25 Characters)',
 '## Dakuon là gì?\n\n**Dakuon** (濁音, âm hữu thanh) là các ký tự hiragana được tạo ra bằng cách thêm dấu **nigori** (゛) — hai chấm nhỏ ở góc trên bên phải — vào một số ký tự hiragana cơ bản. Dấu này chỉ ra rằng phụ âm ban đầu đã được "hữu thanh hóa" (dây thanh rung khi phát âm).\n\nNgoài ra, hàng **H** khi thêm dấu **maru** (゜) — một vòng tròn nhỏ — sẽ tạo ra âm **bán hữu thanh** (han-dakuon) là hàng P.\n\n## Bảng Dakuon đầy đủ\n\n| Gốc | → Dakuon | Gốc | → Dakuon |\n|---|---|---|---|\n| か ka → | **が ga** | き ki → | **ぎ gi** |\n| く ku → | **ぐ gu** | け ke → | **げ ge** |\n| こ ko → | **ご go** | さ sa → | **ざ za** |\n| し shi → | **じ ji** | す su → | **ず zu** |\n| せ se → | **ぜ ze** | そ so → | **ぞ zo** |\n| た ta → | **だ da** | ち chi → | **ぢ ji*** |\n| つ tsu → | **づ zu*** | て te → | **で de** |\n| と to → | **ど do** | は ha → | **ば ba** |\n| ひ hi → | **び bi** | ふ fu → | **ぶ bu** |\n| へ he → | **べ be** | ほ ho → | **ぼ bo** |\n\n*Lưu ý: ぢ và づ ngày nay đọc giống じ (ji) và ず (zu). Chúng ít dùng hơn nhưng vẫn xuất hiện trong một số từ nhất định.*\n\n## Bảng Han-dakuon (P)\n\n| は ha → | **ぱ pa** | ひ hi → | **ぴ pi** |\n|---|---|---|---|\n| ふ fu → | **ぷ pu** | へ he → | **ぺ pe** |\n| ほ ho → | **ぽ po** | | |\n\n## Luyện nghe phân biệt\n\nNhiều học viên nhầm lẫn giữa âm vô thanh và hữu thanh. Hãy luyện tập theo cặp:\n\n| Vô thanh | Hữu thanh | Ví dụ |\n|---|---|---|\n| か ka | が ga | **か**ど (góc đường) vs **が**っこう (trường học) |\n| さ sa | ざ za | **さ**けび (tiếng la) vs **ざ**っし (tạp chí) |\n| た ta | だ da | **た**べる (ăn) vs **だ**れ (ai) |\n| は ha | ば ba | **は**な (hoa/mũi) vs **ば**な (chuối) |\n\n## Mẹo phân biệt\n\n- Đặt tay lên cổ họng. Với âm **hữu thanh** bạn sẽ cảm thấy dây thanh rung.\n- Âm **ka** → **ga**: giống như "ka" nhưng miệng hơi mở hơn và có độ rung.\n- Âm **sa** → **za**: giống âm "za" trong "pizza".\n- Hàng **P** rất ít gặp trong từ thuần Nhật — chủ yếu trong từ vay mượn và từ tượng thanh như **ぴかぴか** (pikapika = sáng lấp lánh).',
 '## What is Dakuon?\n\n**Dakuon** (濁音, "voiced sounds") are hiragana characters created by adding a **nigori** diacritic (゛) — two small diagonal marks in the upper-right corner — to certain base characters. This mark signals that the original consonant has been "voiced" (the vocal cords vibrate during pronunciation).\n\nAdditionally, the **H row** gains a **maru** diacritic (゜) — a small circle — to produce the **semi-voiced** (han-dakuon) **P row**.\n\n## Complete Dakuon Table\n\n| Base | → Dakuon | Base | → Dakuon |\n|---|---|---|---|\n| か ka → | **が ga** | き ki → | **ぎ gi** |\n| く ku → | **ぐ gu** | け ke → | **げ ge** |\n| こ ko → | **ご go** | さ sa → | **ざ za** |\n| し shi → | **じ ji** | す su → | **ず zu** |\n| せ se → | **ぜ ze** | そ so → | **ぞ zo** |\n| た ta → | **だ da** | ち chi → | **ぢ ji*** |\n| つ tsu → | **づ zu*** | て te → | **で de** |\n| と to → | **ど do** | は ha → | **ば ba** |\n| ひ hi → | **び bi** | ふ fu → | **ぶ bu** |\n| へ he → | **べ be** | ほ ho → | **ぼ bo** |\n\n*Note: ぢ and づ are today pronounced identically to じ (ji) and ず (zu). They appear in a specific set of words but are rarely written.*\n\n## Han-dakuon Table (P Row)\n\n| は ha → | **ぱ pa** | ひ hi → | **ぴ pi** |\n|---|---|---|---|\n| ふ fu → | **ぷ pu** | へ he → | **ぺ pe** |\n| ほ ho → | **ぽ po** | | |\n\n## Ear Training: Voiced vs. Unvoiced\n\nMany learners confuse unvoiced and voiced pairs. Practise these minimal pairs:\n\n| Unvoiced | Voiced | Example |\n|---|---|---|\n| か ka | が ga | **か**ど (street corner) vs **が**っこう (school) |\n| さ sa | ざ za | **さ**けび (shout) vs **ざ**っし (magazine) |\n| た ta | だ da | **た**べる (to eat) vs **だ**れ (who) |\n| は ha | ば ba | **は**な (flower/nose) vs **ば**な (banana) |\n\n## Tips for Distinction\n\n- Place a hand on your throat. With **voiced** sounds you will feel the vocal cords vibrating.\n- **ka** → **ga**: like "ka" but with the throat open and buzzing.\n- **sa** → **za**: similar to the "za" in "pizza".\n- The **P row** is rare in native Japanese — mostly found in loanwords and mimetic words like **ぴかぴか** (pikapika = sparkling bright).',
 'character_learning', 'hiragana', 2, 1),

(3,
 'Bài 3: Hiragana Yōon — Âm Kết Hợp (36 tổ hợp)',
 'Lesson 3: Yōon Hiragana — Combination Sounds (36 Combinations)',
 '## Yōon là gì?\n\n**Yōon** (拗音, âm kết hợp) là các âm được tạo ra khi một ký tự hàng "i" (き、し、ち、に、ひ、み、り — và các dakuon tương ứng ぎ、じ、ぢ、び、ぴ) được ghép với **や、ゆ、hoặc よ viết nhỏ** (ゃ ゅ ょ). Hai ký tự này đọc thành **một âm tiết duy nhất**, ngắn hơn và nhanh hơn.\n\n## Bảng Yōon cơ bản\n\n| | + ゃ ya | + ゅ yu | + ょ yo |\n|---|---|---|---|\n| き ki | **きゃ kya** | **きゅ kyu** | **きょ kyo** |\n| し shi | **しゃ sha** | **しゅ shu** | **しょ sho** |\n| ち chi | **ちゃ cha** | **ちゅ chu** | **ちょ cho** |\n| に ni | **にゃ nya** | **にゅ nyu** | **にょ nyo** |\n| ひ hi | **ひゃ hya** | **ひゅ hyu** | **ひょ hyo** |\n| み mi | **みゃ mya** | **みゅ myu** | **みょ myo** |\n| り ri | **りゃ rya** | **りゅ ryu** | **りょ ryo** |\n\n## Bảng Yōon dakuon\n\n| | + ゃ ya | + ゅ yu | + ょ yo |\n|---|---|---|---|\n| ぎ gi | **ぎゃ gya** | **ぎゅ gyu** | **ぎょ gyo** |\n| じ ji | **じゃ ja** | **じゅ ju** | **じょ jo** |\n| び bi | **びゃ bya** | **びゅ byu** | **びょ byo** |\n| ぴ pi | **ぴゃ pya** | **ぴゅ pyu** | **ぴょ pyo** |\n\n## Điểm quan trọng: Ya/yu/yo phải viết NHỎ\n\nKích thước rất quan trọng! So sánh:\n- **きや** = ki + ya (HAI âm tiết riêng biệt: "ki-ya")\n- **きゃ** = kya (MỘT âm tiết: "kya")\n\nNếu viết ゃゅょ to, người đọc sẽ hiểu nhầm thành hai âm!\n\n## Từ vựng thực tế sử dụng Yōon\n\n| Yōon | Từ ví dụ | Nghĩa |\n|---|---|---|\n| しゃ sha | しゃしん (写真) | ảnh chụp |\n| しょ sho | しょくじ (食事) | bữa ăn |\n| ちゃ cha | おちゃ (お茶) | trà |\n| りょ ryo | りょこう (旅行) | du lịch |\n| じゅ ju | じゅぎょう (授業) | giờ học |\n| にゅ nyu | にゅうがく (入学) | nhập học |\n\n## Mẹo phát âm\n\n- **ちゃ (cha)** nghe giống "cha" trong "chai tea"\n- **しゃ (sha)** nghe giống "sha" trong "shall"\n- **じゃ (ja)** nghe giống "ja" trong "jar"\n- **りょ (ryo)** — lưỡi chạm lợi trên, miệng tròn lại thành "o"',
 '## What is Yōon?\n\n**Yōon** (拗音, "contracted sounds") are sounds formed when an "i-row" character (き、し、ち、に、ひ、み、り — and their dakuon counterparts ぎ、じ、ぢ、び、ぴ) is combined with a **small** や、ゆ、or よ (written as ゃ ゅ ょ). The two characters merge into **a single syllable** — shorter and faster than reading them separately.\n\n## Basic Yōon Chart\n\n| | + ゃ ya | + ゅ yu | + ょ yo |\n|---|---|---|---|\n| き ki | **きゃ kya** | **きゅ kyu** | **きょ kyo** |\n| し shi | **しゃ sha** | **しゅ shu** | **しょ sho** |\n| ち chi | **ちゃ cha** | **ちゅ chu** | **ちょ cho** |\n| に ni | **にゃ nya** | **にゅ nyu** | **にょ nyo** |\n| ひ hi | **ひゃ hya** | **ひゅ hyu** | **ひょ hyo** |\n| み mi | **みゃ mya** | **みゅ myu** | **みょ myo** |\n| り ri | **りゃ rya** | **りゅ ryu** | **りょ ryo** |\n\n## Voiced Yōon Chart\n\n| | + ゃ ya | + ゅ yu | + ょ yo |\n|---|---|---|---|\n| ぎ gi | **ぎゃ gya** | **ぎゅ gyu** | **ぎょ gyo** |\n| じ ji | **じゃ ja** | **じゅ ju** | **じょ jo** |\n| び bi | **びゃ bya** | **びゅ byu** | **びょ byo** |\n| ぴ pi | **ぴゃ pya** | **ぴゅ pyu** | **ぴょ pyo** |\n\n## Critical Point: ya/yu/yo MUST be written small\n\nSize matters enormously! Compare:\n- **きや** = ki + ya (TWO separate syllables: "ki-ya")\n- **きゃ** = kya (ONE syllable: "kya")\n\nWriting ゃゅょ at full size tells the reader to pronounce two separate morae!\n\n## Real Vocabulary Using Yōon\n\n| Yōon | Example word | Meaning |\n|---|---|---|\n| しゃ sha | しゃしん (写真) | photograph |\n| しょ sho | しょくじ (食事) | meal |\n| ちゃ cha | おちゃ (お茶) | tea |\n| りょ ryo | りょこう (旅行) | travel |\n| じゅ ju | じゅぎょう (授業) | class / lesson |\n| にゅ nyu | にゅうがく (入学) | school enrolment |\n\n## Pronunciation Tips\n\n- **ちゃ (cha)** sounds like "cha" in "chai tea"\n- **しゃ (sha)** sounds like "sha" in "shall"\n- **じゃ (ja)** sounds like "ja" in "jar"\n- **りょ (ryo)** — tip the tongue behind the upper teeth, round the lips to "o"',
 'character_learning', 'hiragana', 3, 1),

(4,
 'Bài 4: Katakana Cơ Bản (46 ký tự)',
 'Lesson 4: Basic Katakana (46 Characters)',
 '## Katakana là gì?\n\n**Katakana** (片仮名) là bộ ký tự thứ hai trong hệ thống kana của tiếng Nhật. Giống như hiragana, katakana cũng có **46 ký tự cơ bản** đại diện cho các âm tiết giống hệt nhau. Sự khác biệt nằm ở **hình dạng góc cạnh** và **chức năng sử dụng**.\n\n## Katakana được dùng để viết gì?\n\n1. **Gairaigo** (外来語) — Từ vay mượn từ nước ngoài:\n - アイスクリーム (*aisu kuriimu* = ice cream)\n - コーヒー (*koohii* = coffee)\n - テレビ (*terebi* = television)\n\n2. **Tên nước ngoài và tên người nước ngoài:**\n - アメリカ (*Amerika* = America)\n - フランス (*Furansu* = France)\n - マイケル (*Maikeru* = Michael)\n\n3. **Tên khoa học và kỹ thuật:**\n - タンパク質 (*tanpaku shitsu* = protein)\n - ウイルス (*uirusu* = virus)\n\n4. **Nhấn mạnh** — tương tự chữ in đậm/in nghiêng trong tiếng Việt:\n - ここが**ポイント**だ (ĐÂY là điểm quan trọng)\n\n5. **Từ tượng thanh:**\n - ワンワン (*wan wan* = tiếng chó sủa)\n - ニャーニャー (*nyaa nyaa* = tiếng mèo kêu)\n\n## So sánh Hiragana ↔ Katakana\n\n| Hiragana | Katakana | Romaji | | Hiragana | Katakana | Romaji |\n|---|---|---|---|---|---|---|\n| あ | **ア** | a | | か | **カ** | ka |\n| い | **イ** | i | | き | **キ** | ki |\n| う | **ウ** | u | | く | **ク** | ku |\n| え | **エ** | e | | け | **ケ** | ke |\n| お | **オ** | o | | こ | **コ** | ko |\n\n## Các ký tự dễ nhầm lẫn\n\n| Cặp hay nhầm | Gợi nhớ |\n|---|---|\n| ソ (so) và ン (n) | ソ nghiêng nhiều hơn như chữ "S"; ン ngắn hơn trông như "N" |\n| シ (shi) và ツ (tsu) | シ có hai nét nhỏ hơi nằm ngang; ツ có hai nét dựng đứng hơn |\n| ア (a) và マ (ma) | ア có nét đầu từ phải sang; マ có nét đầu từ trái sang |\n| ウ (u) và ヲ (wo) | ウ nhỏ gọn; ヲ (hiếm dùng) có thêm nét cong phía trên |\n\n## Nguyên âm kéo dài trong Katakana\n\nKatakana dùng dấu **ー** (dấu gạch dài, gọi là chōon-pu) để kéo dài nguyên âm:\n- コーヒー = ko-o-hi-i = coffee\n- ケーキ = ke-e-ki = cake\n- ノート = no-o-to = notebook\n\nDấu ー KHÔNG dùng trong hiragana — hiragana dùng ký tự kép (おおきい).',
 '## What is Katakana?\n\n**Katakana** (片仮名) is the second Japanese phonetic script. Like hiragana, it has **46 base characters** representing the same set of syllables. The key differences are its **angular, sharp appearance** and its **distinct range of uses**.\n\n## When is Katakana Used?\n\n1. **Gairaigo** (外来語) — Foreign loanwords:\n - アイスクリーム (*aisu kuriimu* = ice cream)\n - コーヒー (*koohii* = coffee)\n - テレビ (*terebi* = television)\n\n2. **Foreign names and place names:**\n - アメリカ (*Amerika* = America)\n - フランス (*Furansu* = France)\n - マイケル (*Maikeru* = Michael)\n\n3. **Scientific and technical terms:**\n - タンパク質 (*tanpaku shitsu* = protein)\n - ウイルス (*uirusu* = virus)\n\n4. **Emphasis** — similar to bold or italics in English:\n - ここが**ポイント**だ (THIS is the important point)\n\n5. **Onomatopoeia and sound effects:**\n - ワンワン (*wan wan* = dog barking)\n - ニャーニャー (*nyaa nyaa* = cat meowing)\n\n## Hiragana ↔ Katakana Comparison\n\n| Hiragana | Katakana | Romaji | | Hiragana | Katakana | Romaji |\n|---|---|---|---|---|---|---|\n| あ | **ア** | a | | か | **カ** | ka |\n| い | **イ** | i | | き | **キ** | ki |\n| う | **ウ** | u | | く | **ク** | ku |\n| え | **エ** | e | | け | **ケ** | ke |\n| お | **オ** | o | | こ | **コ** | ko |\n\n## Frequently Confused Pairs\n\n| Confusing pair | Memory tip |\n|---|---|\n| ソ (so) vs ン (n) | ソ slants more steeply like an S; ン is more compact like an N |\n| シ (shi) vs ツ (tsu) | シ has two small near-horizontal strokes; ツ has two more vertical strokes |\n| ア (a) vs マ (ma) | ア''s first stroke goes from right; マ''s first stroke goes from left |\n| ウ (u) vs ヲ (wo) | ウ is compact; ヲ (rare) has an extra curved top stroke |\n\n## Long Vowels in Katakana\n\nKatakana uses a **ー** mark (chōon-pu, "long vowel mark") to extend vowel sounds:\n- コーヒー = ko-o-hi-i = coffee\n- ケーキ = ke-e-ki = cake\n- ノート = no-o-to = notebook\n\nThe ー mark is NOT used in hiragana — hiragana doubles the vowel letter instead (おおきい).',
 'character_learning', 'katakana', 4, 1),

(5,
 'Bài 5: Katakana Dakuon & Yōon (58 tổ hợp)',
 'Lesson 5: Dakuon & Yōon Katakana (58 Combinations)',
 '## Tổng quan\n\nBài này hoàn thiện bộ katakana của bạn với các âm hữu thanh (dakuon), bán hữu thanh (han-dakuon), và âm kết hợp (yōon). Cấu tạo hoàn toàn giống với hiragana — chỉ khác về hình dạng ký tự.\n\n## Katakana Dakuon\n\n| Gốc | Dakuon | | Gốc | Dakuon |\n|---|---|---|---|---|\n| カ ka | **ガ ga** | | キ ki | **ギ gi** |\n| ク ku | **グ gu** | | ケ ke | **ゲ ge** |\n| コ ko | **ゴ go** | | サ sa | **ザ za** |\n| シ shi | **ジ ji** | | ス su | **ズ zu** |\n| セ se | **ゼ ze** | | ソ so | **ゾ zo** |\n| タ ta | **ダ da** | | チ chi | **ヂ ji** |\n| ツ tsu | **ヅ zu** | | テ te | **デ de** |\n| ト to | **ド do** | | ハ ha | **バ ba** |\n| ヒ hi | **ビ bi** | | フ fu | **ブ bu** |\n| ヘ he | **ベ be** | | ホ ho | **ボ bo** |\n\n**Han-dakuon (P):** パ ピ プ ペ ポ\n\n## Katakana Yōon — Âm kết hợp gốc Nhật\n\nGiống hiragana: ký tự hàng "i" + ャ ュ ョ nhỏ\n- **キャ kya** / **キュ kyu** / **キョ kyo**\n- **シャ sha** / **シュ shu** / **ショ sho**\n- **チャ cha** / **チュ chu** / **チョ cho**\n- **ニャ nya** / **ニュ nyu** / **ニョ nyo**\n\n## Âm đặc biệt trong Katakana (dành cho từ vay mượn)\n\nKatakana có thêm các tổ hợp đặc biệt **không có trong hiragana** để biểu diễn các âm nước ngoài:\n\n| Tổ hợp | Âm | Ví dụ |\n|---|---|---|\n| **ファ** | fa | ファン (fan hâm mộ) |\n| **フィ** | fi | フィリピン (Philippines) |\n| **フェ** | fe | フェリー (phà/ferry) |\n| **フォ** | fo | フォーク (fork/nhạc folk) |\n| **ウィ** | wi | ウィーン (Vienna) |\n| **ウェ** | we | ウェールズ (Wales) |\n| **ヴァ** | va | ヴァイオリン (violin) |\n| **ティ** | ti | パーティー (party) |\n| **ディ** | di | ディズニー (Disney) |\n\n## Luyện đọc từ vay mượn\n\nThử đọc các từ katakana sau — bạn có nhận ra không?\n\n1. アイスクリーム = ?\n2. ピザ = ?\n3. スマートフォン = ?\n4. チョコレート = ?\n5. インターネット = ?\n\n*(Đáp án: ice cream, pizza, smartphone, chocolate, internet)*',
 '## Overview\n\nThis lesson completes your katakana repertoire with voiced sounds (dakuon), semi-voiced sounds (han-dakuon), and combination sounds (yōon). The mechanics are identical to hiragana — only the character shapes differ.\n\n## Katakana Dakuon\n\n| Base | Dakuon | | Base | Dakuon |\n|---|---|---|---|---|\n| カ ka | **ガ ga** | | キ ki | **ギ gi** |\n| ク ku | **グ gu** | | ケ ke | **ゲ ge** |\n| コ ko | **ゴ go** | | サ sa | **ザ za** |\n| シ shi | **ジ ji** | | ス su | **ズ zu** |\n| セ se | **ゼ ze** | | ソ so | **ゾ zo** |\n| タ ta | **ダ da** | | チ chi | **ヂ ji** |\n| ツ tsu | **ヅ zu** | | テ te | **デ de** |\n| ト to | **ド do** | | ハ ha | **バ ba** |\n| ヒ hi | **ビ bi** | | フ fu | **ブ bu** |\n| ヘ he | **ベ be** | | ホ ho | **ボ bo** |\n\n**Han-dakuon (P):** パ ピ プ ペ ポ\n\n## Katakana Yōon — Native-pattern combinations\n\nSame as hiragana: i-row character + small ャ ュ ョ\n- **キャ kya** / **キュ kyu** / **キョ kyo**\n- **シャ sha** / **シュ shu** / **ショ sho**\n- **チャ cha** / **チュ chu** / **チョ cho**\n- **ニャ nya** / **ニュ nyu** / **ニョ nyo**\n\n## Special Katakana Sounds (for loanwords)\n\nKatakana has additional combinations **not found in hiragana** to represent foreign sounds:\n\n| Combination | Sound | Example |\n|---|---|---|\n| **ファ** | fa | ファン (fan) |\n| **フィ** | fi | フィリピン (Philippines) |\n| **フェ** | fe | フェリー (ferry) |\n| **フォ** | fo | フォーク (fork / folk) |\n| **ウィ** | wi | ウィーン (Vienna) |\n| **ウェ** | we | ウェールズ (Wales) |\n| **ヴァ** | va | ヴァイオリン (violin) |\n| **ティ** | ti | パーティー (party) |\n| **ディ** | di | ディズニー (Disney) |\n\n## Loanword Reading Practice\n\nTry reading these katakana words — can you guess them?\n\n1. アイスクリーム = ?\n2. ピザ = ?\n3. スマートフォン = ?\n4. チョコレート = ?\n5. インターネット = ?\n\n*(Answers: ice cream, pizza, smartphone, chocolate, internet)*',
 'character_learning', 'katakana', 5, 1),

(6,
 'Bài 6: Katakana Yōon Mở Rộng (36 ký tự)',
 'Lesson 6: Extended Yōon Katakana (36 Characters)',
 '## Ôn lại và Nâng cao\n\nBài này củng cố toàn bộ yōon katakana từ bài 5 và bổ sung các tổ hợp nâng cao dành riêng cho katakana.\n\n## Bảng Yōon Dakuon Katakana đầy đủ\n\n| | + ャ ya | + ュ yu | + ョ yo |\n|---|---|---|---|\n| ギ gi | **ギャ gya** | **ギュ gyu** | **ギョ gyo** |\n| ジ ji | **ジャ ja** | **ジュ ju** | **ジョ jo** |\n| ビ bi | **ビャ bya** | **ビュ byu** | **ビョ byo** |\n| ピ pi | **ピャ pya** | **ピュ pyu** | **ピョ pyo** |\n\n## Từ vay mượn nâng cao\n\n| Katakana | Phiên âm | Nghĩa |\n|---|---|---|\n| ジュース | juusu | juice (nước ép) |\n| ショッピング | shoppingu | shopping |\n| ギャラリー | gyararii | gallery (phòng triển lãm) |\n| ジョギング | jogingu | jogging |\n| ビュッフェ | byuffe | buffet |\n\n## Kiểm tra tổng kết Katakana\n\nSau bài học này, bạn đã hoàn thành toàn bộ bộ katakana. Hãy tự kiểm tra bằng cách:\n1. Đọc menu nhà hàng Nhật Bản (phần katakana)\n2. Nhận diện tên nước ngoài trong văn bản tiếng Nhật\n3. Viết tên của bạn bằng katakana',
 '## Review and Advancement\n\nThis lesson reinforces all yōon katakana from Lesson 5 and adds advanced combinations unique to katakana.\n\n## Complete Voiced Yōon Katakana Table\n\n| | + ャ ya | + ュ yu | + ョ yo |\n|---|---|---|---|\n| ギ gi | **ギャ gya** | **ギュ gyu** | **ギョ gyo** |\n| ジ ji | **ジャ ja** | **ジュ ju** | **ジョ jo** |\n| ビ bi | **ビャ bya** | **ビュ byu** | **ビョ byo** |\n| ピ pi | **ピャ pya** | **ピュ pyu** | **ピョ pyo** |\n\n## Advanced Loanwords\n\n| Katakana | Romanisation | Meaning |\n|---|---|---|\n| ジュース | juusu | juice |\n| ショッピング | shoppingu | shopping |\n| ギャラリー | gyararii | gallery |\n| ジョギング | jogingu | jogging |\n| ビュッフェ | byuffe | buffet |\n\n## Katakana Completion Check\n\nAfter this lesson you have covered the entire katakana system. Test yourself by:\n1. Reading the katakana sections of a Japanese restaurant menu\n2. Identifying foreign names in Japanese text\n3. Writing your own name in katakana',
 'character_learning', 'katakana', 6, 1),

(7,
 'Bài 7: Giao Tiếp Cơ Bản — Những Câu Nói Đầu Tiên',
 'Lesson 7: Basic Communication — Your First Conversations',
 '## Mục tiêu bài học\n\nSau bài học này, bạn có thể:\n- Chào hỏi và từ biệt đúng thời điểm trong ngày\n- Tự giới thiệu bản thân\n- Thể hiện sự cảm ơn và xin lỗi lịch sự\n- Hỏi và trả lời các câu hỏi cơ bản\n\n## Lời chào theo thời điểm\n\n| Tiếng Nhật | Romaji | Nghĩa | Thời điểm sử dụng |\n|---|---|---|---|\n| おはようございます | *ohayou gozaimasu* | Chào buổi sáng (lịch sự) | 5:00 – 10:00 |\n| おはよう | *ohayou* | Chào buổi sáng (thân mật) | Với bạn bè/gia đình |\n| こんにちは | *konnichiwa* | Xin chào | 10:00 – 18:00 |\n| こんばんは | *konbanwa* | Chào buổi tối | Sau 18:00 |\n| おやすみなさい | *oyasumi nasai* | Chúc ngủ ngon | Khi đi ngủ |\n\n## Lời từ biệt\n\n| Tiếng Nhật | Romaji | Sắc thái |\n|---|---|---|\n| さようなら | *sayounara* | Tạm biệt (chia tay lâu) |\n| じゃあね | *jaa ne* | Tạm biệt (thân mật, gặp lại sớm) |\n| またね | *mata ne* | Hẹn gặp lại nhé |\n| またあした | *mata ashita* | Hẹn gặp ngày mai |\n| いってきます | *ittekimasu* | Con/anh/chị đi đây (ra khỏi nhà) |\n| いってらっしゃい | *itterasshai* | Đi cẩn thận nhé (người ở nhà nói) |\n\n## Tự giới thiệu\n\n**Mẫu câu giới thiệu cơ bản:**\n\n> はじめまして。わたしは [tên] です。\n> *Hajimemashite. Watashi wa [name] desu.*\n> Rất vui được gặp bạn. Tôi là [tên].\n\n> [quê hương] から きました。\n> *[country] kara kimashita.*\n> Tôi đến từ [quê hương].\n\n> どうぞ よろしく おねがいします。\n> *Douzo yoroshiku onegaishimasu.*\n> Rất mong được quan tâm giúp đỡ. (Lời kết khi giới thiệu)\n\n## Lời cảm ơn và xin lỗi\n\n| Tiếng Nhật | Romaji | Mức độ lịch sự |\n|---|---|---|\n| ありがとう | *arigatou* | Thường (với bạn bè) |\n| ありがとうございます | *arigatou gozaimasu* | Lịch sự |\n| どうもありがとうございます | *doumo arigatou gozaimasu* | Rất lịch sự |\n| すみません | *sumimasen* | Xin lỗi / Xin phép (đa năng) |\n| ごめんなさい | *gomennasai* | Xin lỗi (thành thật) |\n| もうしわけありません | *moushiwake arimasen* | Xin lỗi (rất trang trọng) |\n\n## Câu hỏi và trả lời thiết yếu\n\n**Hỏi tên:**\n> お名前は なんですか？\n> *Onamae wa nan desu ka?*\n> Tên bạn là gì?\n\n**Trả lời:**\n> [tên] と もうします。\n> *[name] to moushimasu.*\n> Tôi tên là [tên]. (Trang trọng)\n\n**Hỏi nguồn gốc:**\n> どちら から いらっしゃいましたか？\n> *Dochira kara irasshaimashita ka?*\n> Bạn đến từ đâu? (Lịch sự)\n\n**Không hiểu:**\n> もういちど おねがいします。\n> *Mou ichido onegaishimasu.*\n> Xin nói lại một lần nữa.\n\n> ゆっくり はなして ください。\n> *Yukkuri hanashite kudasai.*\n> Xin nói chậm hơn.\n\n## Văn hóa: Cúi chào (お辞儀 — Ojigi)\n\nĐi kèm với lời chào là cử chỉ cúi đầu:\n- **15°** — Chào thông thường hằng ngày\n- **30°** — Cảm ơn thành thật, gặp người lớn tuổi\n- **45°** — Xin lỗi sâu sắc, gặp khách hàng/cấp trên\n\nKhách nước ngoài không bắt buộc phải cúi chào, nhưng một cái gật đầu nhẹ luôn được đánh giá cao.',
 '## Lesson Objectives\n\nBy the end of this lesson you will be able to:\n- Greet and farewell people at the correct time of day\n- Introduce yourself\n- Express thanks and apologies politely\n- Ask and answer basic questions\n\n## Time-of-Day Greetings\n\n| Japanese | Romaji | Meaning | When to use |\n|---|---|---|---|\n| おはようございます | *ohayou gozaimasu* | Good morning (polite) | 5:00 – 10:00 |\n| おはよう | *ohayou* | Good morning (casual) | With friends / family |\n| こんにちは | *konnichiwa* | Hello / Good afternoon | 10:00 – 18:00 |\n| こんばんは | *konbanwa* | Good evening | After 18:00 |\n| おやすみなさい | *oyasumi nasai* | Good night | When going to sleep |\n\n## Farewells\n\n| Japanese | Romaji | Register |\n|---|---|---|\n| さようなら | *sayounara* | Goodbye (implies longer separation) |\n| じゃあね | *jaa ne* | See you (casual, soon) |\n| またね | *mata ne* | See you again |\n| またあした | *mata ashita* | See you tomorrow |\n| いってきます | *ittekimasu* | I''m heading out (leaving home) |\n| いってらっしゃい | *itterasshai* | Take care (said by those staying behind) |\n\n## Self-Introduction\n\n**Standard introduction pattern:**\n\n> はじめまして。わたしは [name] です。\n> *Hajimemashite. Watashi wa [name] desu.*\n> Nice to meet you. I am [name].\n\n> [country] から きました。\n> *[country] kara kimashita.*\n> I came from [country].\n\n> どうぞ よろしく おねがいします。\n> *Douzo yoroshiku onegaishimasu.*\n> Please treat me well. (Standard closing phrase for introductions)\n\n## Thanks and Apologies\n\n| Japanese | Romaji | Politeness level |\n|---|---|---|\n| ありがとう | *arigatou* | Casual (friends) |\n| ありがとうございます | *arigatou gozaimasu* | Polite |\n| どうもありがとうございます | *doumo arigatou gozaimasu* | Very polite |\n| すみません | *sumimasen* | Excuse me / Sorry (versatile) |\n| ごめんなさい | *gomennasai* | I''m sorry (sincere) |\n| もうしわけありません | *moushiwake arimasen* | I am truly sorry (formal) |\n\n## Essential Questions and Answers\n\n**Asking someone''s name:**\n> お名前は なんですか？\n> *Onamae wa nan desu ka?*\n> What is your name?\n\n**Answering:**\n> [name] と もうします。\n> *[name] to moushimasu.*\n> My name is [name]. (Formal)\n\n**Asking origin:**\n> どちら から いらっしゃいましたか？\n> *Dochira kara irasshaimashita ka?*\n> Where are you from? (Polite)\n\n**When you don''t understand:**\n> もういちど おねがいします。\n> *Mou ichido onegaishimasu.*\n> Please say that one more time.\n\n> ゆっくり はなして ください。\n> *Yukkuri hanashite kudasai.*\n> Please speak more slowly.\n\n## Culture Note: Bowing (お辞儀 — Ojigi)\n\nJapanese greetings are accompanied by bowing:\n- **15°** — Everyday casual greeting\n- **30°** — Sincere thanks, meeting elders\n- **45°** — Deep apology, meeting clients or superiors\n\nForeigners are not expected to bow, but a small nod is always appreciated.',
 'practice', 'both', 7, 1);

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
INSERT INTO quiz_questions (lesson_id, question_type, question_text_vi, question_text_en, romaji, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, difficulty_level, points, order_index) VALUES
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

-- ===========================================================================
-- EXAMPLE SENTENCES — 30 bilingual sentences with grammar notes
-- Covers vocabulary from lessons 1–5; ordered by vocabulary_id.
-- ===========================================================================
INSERT INTO examples (vocabulary_id, jp_sentence_hiragana, jp_sentence_kanji, romaji_sentence, vi_meaning, en_meaning, grammar_note_vi, grammar_note_en, order_index) VALUES

-- vocab 1 (赤い / akai — red)
(1, 'あのりんごはあかいです',
    'あのリンゴは赤いです',
    'Ano ringo wa akai desu',
    'Quả táo kia có màu đỏ',
    'That apple is red',
    'あの + Danh từ + は + Tính từ-i + です: Mô tả màu sắc của vật ở xa',
    'あの + Noun + は + i-adjective + です: Describing the colour of a distant object', 1),

(1, 'かおがあかくなりました',
    '顔が赤くなりました',
    'Kao ga akaku narimashita',
    'Khuôn mặt tôi ửng đỏ lên (vì xấu hổ)',
    'My face turned red (from embarrassment)',
    'Tính từ-i ở dạng く + なる = "trở nên [trạng thái]". Chỉ sự thay đổi trạng thái.',
    'i-adjective in く form + なる = "to become [state]". Indicates a change of state.', 2),

-- vocab 2 (朝 / asa — morning)
(2, 'まいあさにほんごをべんきょうします',
    '毎朝日本語を勉強します',
    'Maiasa Nihongo o benkyou shimasu',
    'Mỗi buổi sáng tôi học tiếng Nhật',
    'I study Japanese every morning',
    'まい + Danh từ thời gian = "mỗi [khoảng thời gian]". を + する = làm hành động gì đó.',
    'まい + time noun = "every [time period]". を + する = to do something.', 3),

(2, 'あさはやくおきます',
    '朝早く起きます',
    'Asa hayaku okimasu',
    'Tôi thức dậy sớm vào buổi sáng',
    'I wake up early in the morning',
    'あさ là trạng ngữ thời gian đặt trước động từ. はやく là dạng trạng từ của tính từ はやい.',
    'あさ functions as a time adverb before the verb. はやく is the adverbial form of the adjective はやい.', 4),

-- vocab 7 (犬 / inu — dog)
(7, 'いぬがにわでまっています',
    '犬が庭で待っています',
    'Inu ga niwa de matte imasu',
    'Con chó đang chờ ngoài sân',
    'The dog is waiting in the garden',
    'Danh từ + が + Địa điểm + で + Động từ-ている: Hành động tiếp diễn tại một địa điểm.',
    'Noun + が + Place + で + Verb-ている: An action in progress at a location.', 5),

(7, 'わたしはいぬがすきです',
    '私は犬が好きです',
    'Watashi wa inu ga suki desu',
    'Tôi thích chó',
    'I like dogs',
    'は chỉ chủ đề; が đánh dấu đối tượng của 好き (sở thích/ghét dùng が không dùng を).',
    'は marks the topic; が marks the object of 好き (verbs of preference take が not を).', 6),

-- vocab 8 (今 / ima — now)
(8, 'いまなんじですか',
    '今何時ですか',
    'Ima nanji desu ka',
    'Bây giờ là mấy giờ?',
    'What time is it now?',
    'いま + なんじ + ですか: Hỏi giờ. なん là "bao nhiêu/cái gì" trước các từ đếm.',
    'いま + なんじ + ですか: Asking the time. なん = "what/how many" before counters.', 7),

(8, 'いまはいそがしいです',
    '今は忙しいです',
    'Ima wa isogashii desu',
    'Bây giờ tôi đang bận',
    'I am busy right now',
    'いまは nhấn mạnh thời điểm "ngay lúc này" bằng trợ từ chủ đề は.',
    'いまは uses the topic particle は to stress the contrast "right now (but not always)".', 8),

-- vocab 10 (海 / umi — sea)
(10, 'なつはうみでおよぎます',
    '夏は海で泳ぎます',
    'Natsu wa umi de oyogimasu',
    'Vào mùa hè tôi bơi ở biển',
    'In summer I swim in the sea',
    'Season + は = "as for summer". で = nơi diễn ra hành động.',
    'Season + は = "as for summer". で marks where the action takes place.', 9),

(10, 'うみがとてもきれいでした',
    '海がとても綺麗でした',
    'Umi ga totemo kirei deshita',
    'Biển hôm đó đẹp lắm',
    'The sea was very beautiful',
    'とても + Tính từ: tăng cường mức độ. でした là quá khứ của です.',
    'とても + adjective: intensifier. でした is the past tense of です.', 10),

-- vocab 12 (駅 / eki — station)
(12, 'えきはここからとおいですか',
    '駅はここから遠いですか',
    'Eki wa koko kara tooi desu ka',
    'Ga tàu có xa từ đây không?',
    'Is the station far from here?',
    'から = từ (điểm xuất phát). とおい = xa (tính từ-i). か cuối câu = câu hỏi có/không.',
    'から = from (starting point). とおい = far (i-adjective). か at sentence-end marks a yes/no question.', 11),

(12, 'えきでともだちをまちます',
    '駅で友達を待ちます',
    'Eki de tomodachi o machimasu',
    'Tôi đợi bạn bè ở ga tàu',
    'I wait for my friend at the station',
    'で chỉ địa điểm diễn ra hành động. を chỉ đối tượng tác động trực tiếp.',
    'で marks where the action happens. を marks the direct object of the verb.', 12),

-- vocab 14 (大きい / ookii — big)
(14, 'あのびょういんはとてもおおきいです',
    'あの病院はとても大きいです',
    'Ano byouin wa totemo ookii desu',
    'Bệnh viện kia rất lớn',
    'That hospital over there is very big',
    'あの + Danh từ = "cái [vật] ở xa kia". とても + Tính từ = mô tả mức độ cao.',
    'あの + Noun = "that [thing] over there". とても + adjective = describes a high degree.', 13),

-- vocab 21 (聞く / kiku — to listen/ask)
(21, 'おんがくをきいています',
    '音楽を聴いています',
    'Ongaku o kiite imasu',
    'Tôi đang nghe nhạc',
    'I am listening to music',
    'を + 聞く = nghe [nội dung cụ thể]. ています = đang làm (tiếp diễn hiện tại).',
    'を + 聞く = to listen to [specific content]. ています = currently doing (present progressive).', 14),

(21, 'せんせいにしつもんをきいてもいいですか',
    '先生に質問を聞いてもいいですか',
    'Sensei ni shitsumon o kiite mo ii desu ka',
    'Tôi có thể hỏi thầy/cô một câu hỏi không?',
    'May I ask the teacher a question?',
    'に chỉ người nhận hành động. ～てもいいですか = "có được phép làm … không?"',
    'に marks the recipient of the action. ～てもいいですか = "may I / is it okay to …?"', 15),

-- vocab 27 (来る / kuru — to come)
(27, 'ともだちがきました',
    '友達が来ました',
    'Tomodachi ga kimashita',
    'Bạn tôi đã đến rồi',
    'My friend has arrived',
    'が đánh dấu chủ ngữ của câu khai báo thông tin mới. ました = quá khứ lịch sự.',
    'が marks the subject in an informational/new-information sentence. ました = polite past tense.', 16),

(27, 'あしたなんじにきますか',
    '明日何時に来ますか',
    'Ashita nanji ni kimasu ka',
    'Ngày mai bạn đến lúc mấy giờ?',
    'What time will you come tomorrow?',
    'に sau giờ cụ thể chỉ thời điểm. なんじ = "mấy giờ" (câu hỏi về giờ).',
    'に after a specific time indicates when. なんじ = "what time" (time question).', 17),

-- vocab 33 (好き / suki — to like)
(33, 'すしとさしみとどちらがすきですか',
    '寿司と刺身とどちらが好きですか',
    'Sushi to sashimi to dochira ga suki desu ka',
    'Bạn thích sushi hay sashimi hơn?',
    'Which do you prefer, sushi or sashimi?',
    'AとBとどちらが好きですか = Hỏi sở thích giữa hai lựa chọn.',
    'AとBとどちらが好きですか = Asking which of two options is preferred.', 18),

-- vocab 37 (少し / sukoshi — a little)
(37, 'すこしまってください',
    '少し待ってください',
    'Sukoshi matte kudasai',
    'Xin chờ một chút',
    'Please wait a moment',
    'すこし = phó từ chỉ lượng nhỏ. ～てください = yêu cầu lịch sự.',
    'すこし = adverb of small quantity. ～てください = polite request form.', 19),

-- vocab 44 (高い / takai — tall/expensive)
(44, 'このレストランはたかいですね',
    'このレストランは高いですね',
    'Kono resutoran wa takai desu ne',
    'Nhà hàng này đắt nhỉ',
    'This restaurant is expensive, isn''t it?',
    'ね cuối câu = tìm kiếm sự đồng ý của người nghe (giống "nhỉ" trong tiếng Việt).',
    'ね at sentence-end seeks the listener''s agreement — similar to "isn''t it?" in English.', 20),

-- vocab 45 (食べる / taberu — to eat)
(45, 'なにをたべたいですか',
    '何を食べたいですか',
    'Nani o tabetai desu ka',
    'Bạn muốn ăn gì?',
    'What do you want to eat?',
    '～たい = muốn làm gì (nguyện vọng ngôi thứ nhất/hỏi ngôi thứ hai). を chỉ tân ngữ.',
    '～たい = want to do (first-person desire or second-person question). を marks the object.', 21),

(45, 'もうすこしたべませんか',
    'もう少し食べませんか',
    'Mou sukoshi tabemasen ka',
    'Bạn ăn thêm một chút nữa đi?',
    'Won''t you eat a little more?',
    '～ませんか = lời mời thân thiện ("sao không …?"). もうすこし = thêm một chút nữa.',
    '～ませんか = friendly invitation ("why don''t you …?"). もうすこし = a little more.', 22),

-- vocab 68 (読む / yomu — to read)
(68, 'まいばんほんをよみます',
    '毎晩本を読みます',
    'Maiban hon o yomimasu',
    'Mỗi buổi tối tôi đọc sách',
    'I read a book every evening',
    'まい + 晩 = mỗi buổi tối. Trạng ngữ thời gian đặt trước động từ trong tiếng Nhật.',
    'まい + 晩 = every evening. Time adverbs typically precede the verb in Japanese.', 23),

-- vocab 71 (料理 / ryouri — cooking)
(71, 'かあさんのりょうりはおいしいです',
    'お母さんの料理は美味しいです',
    'Okaasan no ryouri wa oishii desu',
    'Món ăn của mẹ rất ngon',
    'Mom''s cooking is delicious',
    'の nối hai danh từ biểu thị sở hữu ("của"). おいしい là tính từ-i chỉ vị ngon.',
    'の links two nouns to show possession ("''s"). おいしい is an i-adjective meaning delicious.', 24),

-- vocab 79 (ありがとう / arigatou — thank you)
(79, 'てつだってくれてありがとうございます',
    '手伝ってくれてありがとうございます',
    'Tetsudatte kurete arigatou gozaimasu',
    'Cảm ơn bạn đã giúp tôi',
    'Thank you for helping me',
    '～てくれて + ありがとう = cảm ơn ai vì đã làm gì cho mình. Cấu trúc biểu đạt lòng biết ơn cụ thể.',
    '～てくれて + ありがとう = thank someone specifically for doing something for you.', 25),

-- vocab 84 (飲む / nomu — to drink)
(84, 'まいあさコーヒーをのみます',
    '毎朝コーヒーを飲みます',
    'Maiasa koohii o nomimasu',
    'Mỗi sáng tôi uống cà phê',
    'I drink coffee every morning',
    'カタカナ コーヒー là từ vay mượn (coffee). を chỉ đối tượng uống.',
    'Katakana コーヒー is a loanword. を marks the thing being drunk.', 26),

-- vocab 90 (買う / kau — to buy)
(90, 'デパートでふくをかいました',
    'デパートで服を買いました',
    'Depaato de fuku o kaimashita',
    'Tôi đã mua quần áo ở trung tâm thương mại',
    'I bought clothes at the department store',
    'で chỉ địa điểm mua. を chỉ thứ được mua. ました = quá khứ lịch sự.',
    'で marks where the buying happened. を marks what was bought. ました = polite past.', 27),

-- vocab 91 (書く / kaku — to write)
(91, 'にほんごでてがみをかきます',
    '日本語で手紙を書きます',
    'Nihongo de tegami o kakimasu',
    'Tôi viết thư bằng tiếng Nhật',
    'I write letters in Japanese',
    'で sau ngôn ngữ/công cụ = "bằng [ngôn ngữ/phương tiện]". を chỉ tân ngữ.',
    'で after language/tool = "in / by means of [language or instrument]". を marks the object.', 28),

-- vocab 82 (日本語 / nihongo — Japanese language)
(82, 'にほんごをはなすのはむずかしいです',
    '日本語を話すのは難しいです',
    'Nihongo o hanasu no wa muzukashii desu',
    'Nói tiếng Nhật thì khó',
    'Speaking Japanese is difficult',
    '動詞 + の = danh từ hóa động từ ("việc làm gì"). の + は = chủ đề câu.',
    'Verb + の = nominalisation ("the act of doing"). の + は = this act becomes the sentence topic.', 29),

-- vocab 86 (先生 / sensei — teacher)
(86, 'せんせいはまいにちくるまでがっこうにきます',
    '先生は毎日車で学校に来ます',
    'Sensei wa mainichi kuruma de gakkou ni kimasu',
    'Thầy/cô giáo đi xe đến trường mỗi ngày',
    'The teacher comes to school by car every day',
    'で sau phương tiện di chuyển = "bằng [phương tiện]". に chỉ điểm đến.',
    'で after transport = "by [vehicle]". に marks the destination.', 30);

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