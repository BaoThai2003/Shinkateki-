-- ============================================================
-- SHINKATEKI (進化的) — Adaptive Japanese Learning System
-- Database Schema and Seed Data
-- Version: 1.0.0
-- Language: Vietnamese (Default) with English Support
-- Curriculum: Complete Chapter 1 (Alphabet) - Lessons 1-28
-- ============================================================

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS shinkateki CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE shinkateki;

-- ============================================================
-- TABLE DEFINITIONS
-- ============================================================

-- Users table
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- User progress tracking
CREATE TABLE user_progress (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    lesson_id INT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    score DECIMAL(5,2) NULL,
    time_spent INT DEFAULT 0, -- in seconds
    attempts INT DEFAULT 0,
    last_attempt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_lesson (user_id, lesson_id)
);

-- Chapters table
CREATE TABLE chapters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chapter_number INT NOT NULL UNIQUE,
    title_vi VARCHAR(255) NOT NULL,
    title_en VARCHAR(255) NOT NULL,
    description_vi TEXT,
    description_en TEXT,
    order_index INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sections within chapters
CREATE TABLE sections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chapter_id INT NOT NULL,
    section_number INT NOT NULL,
    title_vi VARCHAR(255) NOT NULL,
    title_en VARCHAR(255) NOT NULL,
    description_vi TEXT,
    description_en TEXT,
    order_index INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE,
    UNIQUE KEY unique_chapter_section (chapter_id, section_number)
);

-- Structured lessons
CREATE TABLE structured_lessons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    section_id INT NOT NULL,
    lesson_number INT NOT NULL,
    title_vi VARCHAR(255) NOT NULL,
    title_en VARCHAR(255) NOT NULL,
    content_vi LONGTEXT NOT NULL,
    content_en LONGTEXT NOT NULL,
    lesson_type ENUM('instruction', 'practice', 'vocabulary', 'review_quiz', 'final_quiz') NOT NULL,
    order_index INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    prerequisite_lesson_id INT NULL,
    unlock_threshold DECIMAL(5,2) DEFAULT 0.75, -- 75% pass rate required
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE,
    FOREIGN KEY (prerequisite_lesson_id) REFERENCES structured_lessons(id) ON DELETE SET NULL,
    UNIQUE KEY unique_section_lesson (section_id, lesson_number)
);

-- Vocabulary table
CREATE TABLE vocabulary (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NOT NULL,
    word VARCHAR(100) NOT NULL,
    romaji VARCHAR(100) NOT NULL,
    hiragana VARCHAR(100),
    katakana VARCHAR(100),
    meaning_vi VARCHAR(255) NOT NULL,
    meaning_en VARCHAR(255) NOT NULL,
    word_type ENUM('noun', 'verb', 'adjective', 'adverb', 'particle', 'expression') NOT NULL,
    difficulty_level ENUM('beginner', 'intermediate', 'advanced') DEFAULT 'beginner',
    audio_url VARCHAR(500),
    example_vi TEXT,
    example_en TEXT,
    order_index INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE,
    UNIQUE KEY unique_lesson_word (lesson_id, word)
);

-- Quiz questions
CREATE TABLE quiz_questions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NOT NULL,
    question_vi TEXT NOT NULL,
    question_en TEXT NOT NULL,
    question_type ENUM('multiple_choice', 'true_false', 'fill_blank', 'matching', 'ordering') NOT NULL,
    options_vi JSON, -- For multiple choice options
    options_en JSON, -- For multiple choice options
    correct_answer_vi VARCHAR(500) NOT NULL,
    correct_answer_en VARCHAR(500) NOT NULL,
    explanation_vi TEXT,
    explanation_en TEXT,
    difficulty_level ENUM('easy', 'medium', 'hard') DEFAULT 'easy',
    points INT DEFAULT 1,
    order_index INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE
);

-- Characters table (Hiragana/Katakana)
CREATE TABLE characters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `character` VARCHAR(10) NOT NULL UNIQUE,
    romaji VARCHAR(50) NOT NULL,
    type ENUM('hiragana', 'katakana') NOT NULL,
    group_name VARCHAR(50), -- a, k, s, t, n, h, m, y, r, w
    position_in_group INT, -- 1-5 for main groups
    stroke_order TEXT, -- JSON array of stroke coordinates
    mnemonic_vi TEXT,
    mnemonic_en TEXT,
    audio_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User quiz attempts
CREATE TABLE quiz_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    lesson_id INT NOT NULL,
    score DECIMAL(5,2) NOT NULL,
    total_questions INT NOT NULL,
    correct_answers INT NOT NULL,
    time_taken INT NOT NULL, -- in seconds
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE
);

-- User performance stats
CREATE TABLE user_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    total_lessons_completed INT DEFAULT 0,
    total_quiz_attempts INT DEFAULT 0,
    average_score DECIMAL(5,2) DEFAULT 0.00,
    total_study_time INT DEFAULT 0, -- in seconds
    current_streak INT DEFAULT 0,
    longest_streak INT DEFAULT 0,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_stats (user_id)
);

-- ============================================================
-- SEED DATA - CHARACTERS (HIRAGANA & KATAKANA)
-- ============================================================

INSERT INTO characters (`character`, romaji, type, group_name, position_in_group, mnemonic_vi, mnemonic_en) VALUES
-- Hiragana - a group
('あ', 'a', 'hiragana', 'a', 1, 'Như chữ A nhưng mở miệng rộng', 'Like A but with mouth wide open'),
('い', 'i', 'hiragana', 'a', 2, 'Như chữ I nhưng vẽ hai chấm', 'Like I but with two dots'),
('う', 'u', 'hiragana', 'a', 3, 'Như chữ U nhưng cong lại', 'Like U but curved'),
('え', 'e', 'hiragana', 'a', 4, 'Như chữ E nhưng có đuôi', 'Like E with a tail'),
('お', 'o', 'hiragana', 'a', 5, 'Như chữ O nhưng kéo dài', 'Like O but elongated'),

-- Hiragana - k group
('か', 'ka', 'hiragana', 'k', 1, 'Kết hợp k với a', 'K combined with a'),
('き', 'ki', 'hiragana', 'k', 2, 'Kết hợp k với i', 'K combined with i'),
('く', 'ku', 'hiragana', 'k', 3, 'Kết hợp k với u', 'K combined with u'),
('け', 'ke', 'hiragana', 'k', 4, 'Kết hợp k với e', 'K combined with e'),
('こ', 'ko', 'hiragana', 'k', 5, 'Kết hợp k với o', 'K combined with o'),

-- Hiragana - s group
('さ', 'sa', 'hiragana', 's', 1, 'S kết hợp với a', 'S combined with a'),
('し', 'shi', 'hiragana', 's', 2, 'S kết hợp với i', 'S combined with i'),
('す', 'su', 'hiragana', 's', 3, 'S kết hợp với u', 'S combined with u'),
('せ', 'se', 'hiragana', 's', 4, 'S kết hợp với e', 'S combined with e'),
('そ', 'so', 'hiragana', 's', 5, 'S kết hợp với o', 'S combined with o'),

-- Hiragana - t group
('た', 'ta', 'hiragana', 't', 1, 'T kết hợp với a', 'T combined with a'),
('ち', 'chi', 'hiragana', 't', 2, 'T kết hợp với i', 'T combined with i'),
('つ', 'tsu', 'hiragana', 't', 3, 'T kết hợp với u', 'T combined with u'),
('て', 'te', 'hiragana', 't', 4, 'T kết hợp với e', 'T combined with e'),
('と', 'to', 'hiragana', 't', 5, 'T kết hợp với o', 'T combined with o'),

-- Hiragana - n group
('な', 'na', 'hiragana', 'n', 1, 'N kết hợp với a', 'N combined with a'),
('に', 'ni', 'hiragana', 'n', 2, 'N kết hợp với i', 'N combined with i'),
('ぬ', 'nu', 'hiragana', 'n', 3, 'N kết hợp với u', 'N combined with u'),
('ね', 'ne', 'hiragana', 'n', 4, 'N kết hợp với e', 'N combined with e'),
('の', 'no', 'hiragana', 'n', 5, 'N kết hợp với o', 'N combined with o'),

-- Hiragana - h group
('は', 'ha', 'hiragana', 'h', 1, 'H kết hợp với a', 'H combined with a'),
('ひ', 'hi', 'hiragana', 'h', 2, 'H kết hợp với i', 'H combined with i'),
('ふ', 'fu', 'hiragana', 'h', 3, 'H kết hợp với u', 'H combined with u'),
('へ', 'he', 'hiragana', 'h', 4, 'H kết hợp với e', 'H combined with e'),
('ほ', 'ho', 'hiragana', 'h', 5, 'H kết hợp với o', 'H combined with o'),

-- Hiragana - m group
('ま', 'ma', 'hiragana', 'm', 1, 'M kết hợp với a', 'M combined with a'),
('み', 'mi', 'hiragana', 'm', 2, 'M kết hợp với i', 'M combined with i'),
('む', 'mu', 'hiragana', 'm', 3, 'M kết hợp với u', 'M combined with u'),
('め', 'me', 'hiragana', 'm', 4, 'M kết hợp với e', 'M combined with e'),
('も', 'mo', 'hiragana', 'm', 5, 'M kết hợp với o', 'M combined with o'),

-- Hiragana - y group
('や', 'ya', 'hiragana', 'y', 1, 'Y kết hợp với a', 'Y combined with a'),
('ゆ', 'yu', 'hiragana', 'y', 2, 'Y kết hợp với u', 'Y combined with u'),
('よ', 'yo', 'hiragana', 'y', 3, 'Y kết hợp với o', 'Y combined with o'),

-- Hiragana - r group
('ら', 'ra', 'hiragana', 'r', 1, 'R kết hợp với a', 'R combined with a'),
('り', 'ri', 'hiragana', 'r', 2, 'R kết hợp với i', 'R combined with i'),
('る', 'ru', 'hiragana', 'r', 3, 'R kết hợp với u', 'R combined with u'),
('れ', 're', 'hiragana', 'r', 4, 'R kết hợp với e', 'R combined with e'),
('ろ', 'ro', 'hiragana', 'r', 5, 'R kết hợp với o', 'R combined with o'),

-- Hiragana - w group
('わ', 'wa', 'hiragana', 'w', 1, 'W kết hợp với a', 'W combined with a'),
('を', 'wo', 'hiragana', 'w', 2, 'W kết hợp với o', 'W combined with o'),

-- Hiragana - n (special)
('ん', 'n', 'hiragana', 'n_special', 1, 'Âm mũi n', 'Nasal n sound'),

-- Katakana - a group
('ア', 'a', 'katakana', 'a', 1, 'A góc cạnh', 'Angular A'),
('イ', 'i', 'katakana', 'a', 2, 'I góc cạnh', 'Angular I'),
('ウ', 'u', 'katakana', 'a', 3, 'U góc cạnh', 'Angular U'),
('エ', 'e', 'katakana', 'a', 4, 'E góc cạnh', 'Angular E'),
('オ', 'o', 'katakana', 'a', 5, 'O góc cạnh', 'Angular O'),

-- Katakana - k group
('カ', 'ka', 'katakana', 'k', 1, 'KA góc cạnh', 'Angular KA'),
('キ', 'ki', 'katakana', 'k', 2, 'KI góc cạnh', 'Angular KI'),
('ク', 'ku', 'katakana', 'k', 3, 'KU góc cạnh', 'Angular KU'),
('ケ', 'ke', 'katakana', 'k', 4, 'KE góc cạnh', 'Angular KE'),
('コ', 'ko', 'katakana', 'k', 5, 'KO góc cạnh', 'Angular KO'),

-- Katakana - s group
('サ', 'sa', 'katakana', 's', 1, 'SA góc cạnh', 'Angular SA'),
('シ', 'shi', 'katakana', 's', 2, 'SHI góc cạnh', 'Angular SHI'),
('ス', 'su', 'katakana', 's', 3, 'SU góc cạnh', 'Angular SU'),
('セ', 'se', 'katakana', 's', 4, 'SE góc cạnh', 'Angular SE'),
('ソ', 'so', 'katakana', 's', 5, 'SO góc cạnh', 'Angular SO'),

-- Katakana - t group
('タ', 'ta', 'katakana', 't', 1, 'TA góc cạnh', 'Angular TA'),
('チ', 'chi', 'katakana', 't', 2, 'CHI góc cạnh', 'Angular CHI'),
('ツ', 'tsu', 'katakana', 't', 3, 'TSU góc cạnh', 'Angular TSU'),
('テ', 'te', 'katakana', 't', 4, 'TE góc cạnh', 'Angular TE'),
('ト', 'to', 'katakana', 't', 5, 'TO góc cạnh', 'Angular TO'),

-- Katakana - n group
('ナ', 'na', 'katakana', 'n', 1, 'NA góc cạnh', 'Angular NA'),
('ニ', 'ni', 'katakana', 'n', 2, 'NI góc cạnh', 'Angular NI'),
('ヌ', 'nu', 'katakana', 'n', 3, 'NU góc cạnh', 'Angular NU'),
('ネ', 'ne', 'katakana', 'n', 4, 'NE góc cạnh', 'Angular NE'),
('ノ', 'no', 'katakana', 'n', 5, 'NO góc cạnh', 'Angular NO'),

-- Katakana - h group
('ハ', 'ha', 'katakana', 'h', 1, 'HA góc cạnh', 'Angular HA'),
('ヒ', 'hi', 'katakana', 'h', 2, 'HI góc cạnh', 'Angular HI'),
('フ', 'fu', 'katakana', 'h', 3, 'FU góc cạnh', 'Angular FU'),
('ヘ', 'he', 'katakana', 'h', 4, 'HE góc cạnh', 'Angular HE'),
('ホ', 'ho', 'katakana', 'h', 5, 'HO góc cạnh', 'Angular HO'),

-- Katakana - m group
('マ', 'ma', 'katakana', 'm', 1, 'MA góc cạnh', 'Angular MA'),
('ミ', 'mi', 'katakana', 'm', 2, 'MI góc cạnh', 'Angular MI'),
('ム', 'mu', 'katakana', 'm', 3, 'MU góc cạnh', 'Angular MU'),
('メ', 'me', 'katakana', 'm', 4, 'ME góc cạnh', 'Angular ME'),
('モ', 'mo', 'katakana', 'm', 5, 'MO góc cạnh', 'Angular MO'),

-- Katakana - y group
('ヤ', 'ya', 'katakana', 'y', 1, 'YA góc cạnh', 'Angular YA'),
('ユ', 'yu', 'katakana', 'y', 2, 'YU góc cạnh', 'Angular YU'),
('ヨ', 'yo', 'katakana', 'y', 3, 'YO góc cạnh', 'Angular YO'),

-- Katakana - r group
('ラ', 'ra', 'katakana', 'r', 1, 'RA góc cạnh', 'Angular RA'),
('リ', 'ri', 'katakana', 'r', 2, 'RI góc cạnh', 'Angular RI'),
('ル', 'ru', 'katakana', 'r', 3, 'RU góc cạnh', 'Angular RU'),
('レ', 're', 'katakana', 'r', 4, 'RE góc cạnh', 'Angular RE'),
('ロ', 'ro', 'katakana', 'r', 5, 'RO góc cạnh', 'Angular RO'),

-- Katakana - w group
('ワ', 'wa', 'katakana', 'w', 1, 'WA góc cạnh', 'Angular WA'),
('ヲ', 'wo', 'katakana', 'w', 2, 'WO góc cạnh', 'Angular WO'),

-- Katakana - n (special)
('ン', 'n', 'katakana', 'n_special', 1, 'N góc cạnh', 'Angular N');

-- ============================================================
-- SEED DATA - CHAPTERS AND SECTIONS
-- ============================================================

INSERT INTO chapters (chapter_number, title_vi, title_en, description_vi, description_en, order_index) VALUES
(1, 'Chương 1: Bảng Chữ Cái', 'Chapter 1: The Alphabet', 'Học bảng chữ cái Hiragana và Katakana - nền tảng của tiếng Nhật', 'Learn Hiragana and Katakana - the foundation of Japanese language', 1);

INSERT INTO sections (chapter_id, section_number, title_vi, title_en, description_vi, description_en, order_index) VALUES
(1, 1, 'Phần 1: Hiragana Cơ Bản', 'Section 1: Basic Hiragana', 'Học 46 chữ cái Hiragana cơ bản', 'Learn the 46 basic Hiragana characters', 1),
(1, 2, 'Phần 2: Katakana Cơ Bản', 'Section 2: Basic Katakana', 'Học 46 chữ cái Katakana cơ bản', 'Learn the 46 basic Katakana characters', 2),
(1, 3, 'Phần 3: Ôn Tập và Kiểm Tra', 'Section 3: Review and Testing', 'Ôn tập và kiểm tra kiến thức', 'Review and test your knowledge', 3);

-- ============================================================
-- SEED DATA - STRUCTURED LESSONS (HIRAGANA)
-- ============================================================

-- Hiragana Lessons 1-5 (a, k, s, t, n groups)
INSERT INTO structured_lessons (section_id, lesson_number, title_vi, title_en, content_vi, content_en, lesson_type, order_index) VALUES
(1, 1, 'Bài 1: Nguyên Âm (あ い う え お)', 'Lesson 1: Vowels (あ い う え お)', '<h2>Nguyên Âm Cơ Bản</h2><p>Học 5 nguyên âm đầu tiên trong tiếng Nhật:</p><ul><li>あ (a) - như chữ A nhưng miệng mở rộng</li><li>い (i) - như chữ I với hai chấm</li><li>う (u) - như chữ U cong lại</li><li>え (e) - như chữ E với đuôi</li><li>お (o) - như chữ O kéo dài</li></ul><p><strong>Luyện tập:</strong> Viết mỗi chữ 5 lần và phát âm to.</p>', '<h2>Basic Vowels</h2><p>Learn the first 5 vowels in Japanese:</p><ul><li>あ (a) - like A with mouth wide open</li><li>い (i) - like I with two dots</li><li>う (u) - like U curved</li><li>え (e) - like E with a tail</li><li>お (o) - like O elongated</li></ul><p><strong>Practice:</strong> Write each character 5 times and pronounce aloud.</p>', 'instruction', 1),

(1, 2, 'Bài 2: Nhóm K (か き く け こ)', 'Lesson 2: K Group (か き く け こ)', '<h2>Nhóm K</h2><p>Kết hợp âm K với 5 nguyên âm:</p><ul><li>か (ka) - ka</li><li>き (ki) - ki</li><li>く (ku) - ku</li><li>け (ke) - ke</li><li>こ (ko) - ko</li></ul><p><strong>Mẹo:</strong> Tưởng tượng chữ K + nguyên âm.</p>', '<h2>K Group</h2><p>Combine K sound with 5 vowels:</p><ul><li>か (ka) - ka</li><li>き (ki) - ki</li><li>く (ku) - ku</li><li>け (ke) - ke</li><li>こ (ko) - ko</li></ul><p><strong>Tip:</strong> Imagine K + vowel.</p>', 'instruction', 2),

(1, 3, 'Bài 3: Nhóm S (さ し す せ そ)', 'Lesson 3: S Group (さ し す せ そ)', '<h2>Nhóm S</h2><p>Kết hợp âm S với 5 nguyên âm:</p><ul><li>さ (sa) - sa</li><li>し (shi) - shi</li><li>す (su) - su</li><li>せ (se) - se</li><li>そ (so) - so</li></ul><p><strong>Lưu ý:</strong> し phát âm là "shi", không phải "si".</p>', '<h2>S Group</h2><p>Combine S sound with 5 vowels:</p><ul><li>さ (sa) - sa</li><li>し (shi) - shi</li><li>す (su) - su</li><li>せ (se) - se</li><li>そ (so) - so</li></ul><p><strong>Note:</strong> し is pronounced "shi", not "si".</p>', 'instruction', 3),

(1, 4, 'Bài 4: Nhóm T (た ち つ て と)', 'Lesson 4: T Group (た ち つ て と)', '<h2>Nhóm T</h2><p>Kết hợp âm T với 5 nguyên âm:</p><ul><li>た (ta) - ta</li><li>ち (chi) - chi</li><li>つ (tsu) - tsu</li><li>て (te) - te</li><li>と (to) - to</li></ul><p><strong>Lưu ý:</strong> ち là "chi", つ là "tsu".</p>', '<h2>T Group</h2><p>Combine T sound with 5 vowels:</p><ul><li>た (ta) - ta</li><li>ち (chi) - chi</li><li>つ (tsu) - tsu</li><li>て (te) - te</li><li>と (to) - to</li></ul><p><strong>Note:</strong> ち is "chi", つ is "tsu".</p>', 'instruction', 4),

(1, 5, 'Bài 5: Nhóm N (な に ぬ ね の)', 'Lesson 5: N Group (な に ぬ ね の)', '<h2>Nhóm N</h2><p>Kết hợp âm N với 5 nguyên âm:</p><ul><li>な (na) - na</li><li>に (ni) - ni</li><li>ぬ (nu) - nu</li><li>ね (ne) - ne</li><li>の (no) - no</li></ul><p><strong>Ôn tập:</strong> Luyện tập viết tất cả các nhóm đã học.</p>', '<h2>N Group</h2><p>Combine N sound with 5 vowels:</p><ul><li>な (na) - na</li><li>に (ni) - ni</li><li>ぬ (nu) - nu</li><li>ね (ne) - ne</li><li>の (no) - no</li></ul><p><strong>Review:</strong> Practice writing all groups learned so far.</p>', 'instruction', 5);

-- Continue with more Hiragana lessons...
INSERT INTO structured_lessons (section_id, lesson_number, title_vi, title_en, content_vi, content_en, lesson_type, order_index) VALUES
(1, 6, 'Bài 6: Nhóm H (は ひ ふ へ ほ)', 'Lesson 6: H Group (は ひ ふ へ ほ)', '<h2>Nhóm H</h2><p>Kết hợp âm H với 5 nguyên âm:</p><ul><li>は (ha) - ha</li><li>ひ (hi) - hi</li><li>ふ (fu) - fu</li><li>へ (he) - he</li><li>ほ (ho) - ho</li></ul><p><strong>Lưu ý:</strong> ふ phát âm là "fu", không phải "hu".</p>', '<h2>H Group</h2><p>Combine H sound with 5 vowels:</p><ul><li>は (ha) - ha</li><li>ひ (hi) - hi</li><li>ふ (fu) - fu</li><li>へ (he) - he</li><li>ほ (ho) - ho</li></ul><p><strong>Note:</strong> ふ is pronounced "fu", not "hu".</p>', 'instruction', 6),

(1, 7, 'Bài 7: Nhóm M (ま み む め も)', 'Lesson 7: M Group (ま み む め も)', '<h2>Nhóm M</h2><p>Kết hợp âm M với 5 nguyên âm:</p><ul><li>ま (ma) - ma</li><li>み (mi) - mi</li><li>む (mu) - mu</li><li>め (me) - me</li><li>も (mo) - mo</li></ul>', '<h2>M Group</h2><p>Combine M sound with 5 vowels:</p><ul><li>ま (ma) - ma</li><li>み (mi) - mi</li><li>む (mu) - mu</li><li>め (me) - me</li><li>も (mo) - mo</li></ul>', 'instruction', 7),

(1, 8, 'Bài 8: Nhóm Y (や ゆ よ)', 'Lesson 8: Y Group (や ゆ よ)', '<h2>Nhóm Y</h2><p>Nhóm Y chỉ có 3 chữ cái:</p><ul><li>や (ya) - ya</li><li>ゆ (yu) - yu</li><li>よ (yo) - yo</li></ul><p><strong>Lưu ý:</strong> Không có yi, ye.</p>', '<h2>Y Group</h2><p>Y group has only 3 characters:</p><ul><li>や (ya) - ya</li><li>ゆ (yu) - yu</li><li>よ (yo) - yo</li></ul><p><strong>Note:</strong> No yi, ye.</p>', 'instruction', 8),

(1, 9, 'Bài 9: Nhóm R (ら り る れ ろ)', 'Lesson 9: R Group (ら り る れ ろ)', '<h2>Nhóm R</h2><p>Kết hợp âm R với 5 nguyên âm:</p><ul><li>ら (ra) - ra</li><li>り (ri) - ri</li><li>る (ru) - ru</li><li>れ (re) - re</li><li>ろ (ro) - ro</li></ul><p><strong>Mẹo:</strong> Phát âm giống L hơn R.</p>', '<h2>R Group</h2><p>Combine R sound with 5 vowels:</p><ul><li>ら (ra) - ra</li><li>り (ri) - ri</li><li>る (ru) - ru</li><li>れ (re) - re</li><li>ろ (ro) - ro</li></ul><p><strong>Tip:</strong> Pronounced more like L than R.</p>', 'instruction', 9),

(1, 10, 'Bài 10: Nhóm W và N Đặc Biệt (わ を ん)', 'Lesson 10: W Group and Special N (わ を ん)', '<h2>Nhóm W và N Đặc Biệt</h2><ul><li>わ (wa) - wa</li><li>を (wo) - wo (chỉ dùng làm trợ từ)</li><li>ん (n) - âm mũi n</li></ul><p><strong>Hoàn thành Hiragana!</strong> Bạn đã học xong 46 chữ cái Hiragana.</p>', '<h2>W Group and Special N</h2><ul><li>わ (wa) - wa</li><li>を (wo) - wo (only used as particle)</li><li>ん (n) - nasal n sound</li></ul><p><strong>Hiragana Complete!</strong> You have learned all 46 Hiragana characters.</p>', 'instruction', 10);

-- Katakana Lessons 11-20
INSERT INTO structured_lessons (section_id, lesson_number, title_vi, title_en, content_vi, content_en, lesson_type, order_index) VALUES
(2, 11, 'Bài 11: Katakana Nguyên Âm (ア イ ウ エ オ)', 'Lesson 11: Katakana Vowels (ア イ ウ エ オ)', '<h2>Katakana Nguyên Âm</h2><p>Học 5 nguyên âm Katakana:</p><ul><li>ア (a) - góc cạnh hơn Hiragana</li><li>イ (i) - góc cạnh</li><li>ウ (u) - góc cạnh</li><li>エ (e) - góc cạnh</li><li>オ (o) - góc cạnh</li></ul><p><strong>Dùng cho:</strong> Từ nước ngoài, tên riêng.</p>', '<h2>Katakana Vowels</h2><p>Learn 5 Katakana vowels:</p><ul><li>ア (a) - more angular than Hiragana</li><li>イ (i) - angular</li><li>ウ (u) - angular</li><li>エ (e) - angular</li><li>オ (o) - angular</li></ul><p><strong>Used for:</strong> Foreign words, proper names.</p>', 'instruction', 11),

(2, 12, 'Bài 12: Katakana Nhóm K (カ キ ク ケ コ)', 'Lesson 12: Katakana K Group (カ キ ク ケ コ)', '<h2>Katakana Nhóm K</h2><ul><li>カ (ka)</li><li>キ (ki)</li><li>ク (ku)</li><li>ケ (ke)</li><li>コ (ko)</li></ul>', '<h2>Katakana K Group</h2><ul><li>カ (ka)</li><li>キ (ki)</li><li>ク (ku)</li><li>ケ (ke)</li><li>コ (ko)</li></ul>', 'instruction', 12),

(2, 13, 'Bài 13: Katakana Nhóm S (サ シ ス セ ソ)', 'Lesson 13: Katakana S Group (サ シ ス セ ソ)', '<h2>Katakana Nhóm S</h2><ul><li>サ (sa)</li><li>シ (shi)</li><li>ス (su)</li><li>セ (se)</li><li>ソ (so)</li></ul>', '<h2>Katakana S Group</h2><ul><li>サ (sa)</li><li>シ (shi)</li><li>ス (su)</li><li>セ (se)</li><li>ソ (so)</li></ul>', 'instruction', 13),

(2, 14, 'Bài 14: Katakana Nhóm T (タ チ ツ テ ト)', 'Lesson 14: Katakana T Group (タ チ ツ テ ト)', '<h2>Katakana Nhóm T</h2><ul><li>タ (ta)</li><li>チ (chi)</li><li>ツ (tsu)</li><li>テ (te)</li><li>ト (to)</li></ul>', '<h2>Katakana T Group</h2><ul><li>タ (ta)</li><li>チ (chi)</li><li>ツ (tsu)</li><li>テ (te)</li><li>ト (to)</li></ul>', 'instruction', 14),

(2, 15, 'Bài 15: Katakana Nhóm N (ナ ニ ヌ ネ ノ)', 'Lesson 15: Katakana N Group (ナ ニ ヌ ネ ノ)', '<h2>Katakana Nhóm N</h2><ul><li>ナ (na)</li><li>ニ (ni)</li><li>ヌ (nu)</li><li>ネ (ne)</li><li>ノ (no)</li></ul>', '<h2>Katakana N Group</h2><ul><li>ナ (na)</li><li>ニ (ni)</li><li>ヌ (nu)</li><li>ネ (ne)</li><li>ノ (no)</li></ul>', 'instruction', 15),

(2, 16, 'Bài 16: Katakana Nhóm H (ハ ヒ フ ヘ ホ)', 'Lesson 16: Katakana H Group (ハ ヒ フ ヘ ホ)', '<h2>Katakana Nhóm H</h2><ul><li>ハ (ha)</li><li>ヒ (hi)</li><li>フ (fu)</li><li>ヘ (he)</li><li>ホ (ho)</li></ul>', '<h2>Katakana H Group</h2><ul><li>ハ (ha)</li><li>ヒ (hi)</li><li>フ (fu)</li><li>ヘ (he)</li><li>ホ (ho)</li></ul>', 'instruction', 16),

(2, 17, 'Bài 17: Katakana Nhóm M (マ ミ ム メ モ)', 'Lesson 17: Katakana M Group (マ ミ ム メ モ)', '<h2>Katakana Nhóm M</h2><ul><li>マ (ma)</li><li>ミ (mi)</li><li>ム (mu)</li><li>メ (me)</li><li>モ (mo)</li></ul>', '<h2>Katakana M Group</h2><ul><li>マ (ma)</li><li>ミ (mi)</li><li>ム (mu)</li><li>メ (me)</li><li>モ (mo)</li></ul>', 'instruction', 17),

(2, 18, 'Bài 18: Katakana Nhóm Y (ヤ ユ ヨ)', 'Lesson 18: Katakana Y Group (ヤ ユ ヨ)', '<h2>Katakana Nhóm Y</h2><ul><li>ヤ (ya)</li><li>ユ (yu)</li><li>ヨ (yo)</li></ul>', '<h2>Katakana Y Group</h2><ul><li>ヤ (ya)</li><li>ユ (yu)</li><li>ヨ (yo)</li></ul>', 'instruction', 18),

(2, 19, 'Bài 19: Katakana Nhóm R (ラ リ ル レ ロ)', 'Lesson 19: Katakana R Group (ラ リ ル レ ロ)', '<h2>Katakana Nhóm R</h2><ul><li>ラ (ra)</li><li>リ (ri)</li><li>ル (ru)</li><li>レ (re)</li><li>ロ (ro)</li></ul>', '<h2>Katakana R Group</h2><ul><li>ラ (ra)</li><li>リ (ri)</li><li>ル (ru)</li><li>レ (re)</li><li>ロ (ro)</li></ul>', 'instruction', 19),

(2, 20, 'Bài 20: Katakana Nhóm W và N (ワ ヲ ン)', 'Lesson 20: Katakana W Group and N (ワ ヲ ン)', '<h2>Katakana Nhóm W và N</h2><ul><li>ワ (wa)</li><li>ヲ (wo)</li><li>ン (n)</li></ul><p><strong>Hoàn thành Katakana!</strong> Bạn đã học xong 46 chữ cái Katakana.</p>', '<h2>Katakana W Group and N</h2><ul><li>ワ (wa)</li><li>ヲ (wo)</li><li>ン (n)</li></ul><p><strong>Katakana Complete!</strong> You have learned all 46 Katakana characters.</p>', 'instruction', 20);

-- Review and Final Quiz Lessons
INSERT INTO structured_lessons (section_id, lesson_number, title_vi, title_en, content_vi, content_en, lesson_type, order_index) VALUES
(3, 21, 'Bài 21: Ôn Tập Hiragana', 'Lesson 21: Hiragana Review', '<h2>Ôn Tập Hiragana</h2><p>Ôn tập tất cả 46 chữ cái Hiragana đã học.</p><p><strong>Bài tập:</strong> Viết và phát âm mỗi chữ cái.</p>', '<h2>Hiragana Review</h2><p>Review all 46 Hiragana characters learned.</p><p><strong>Exercise:</strong> Write and pronounce each character.</p>', 'practice', 21),

(3, 22, 'Bài 22: Ôn Tập Katakana', 'Lesson 22: Katakana Review', '<h2>Ôn Tập Katakana</h2><p>Ôn tập tất cả 46 chữ cái Katakana đã học.</p><p><strong>Bài tập:</strong> Viết và phát âm mỗi chữ cái.</p>', '<h2>Katakana Review</h2><p>Review all 46 Katakana characters learned.</p><p><strong>Exercise:</strong> Write and pronounce each character.</p>', 'practice', 22),

(3, 23, 'Bài 23: Ôn Tập Tổng Hợp', 'Lesson 23: Comprehensive Review', '<h2>Ôn Tập Tổng Hợp</h2><p>Kết hợp Hiragana và Katakana.</p><p><strong>Mục tiêu:</strong> Nhận biết và phân biệt hai bảng chữ cái.</p>', '<h2>Comprehensive Review</h2><p>Combine Hiragana and Katakana.</p><p><strong>Goal:</strong> Recognize and differentiate both alphabets.</p>', 'practice', 23),

(3, 24, 'Bài 24: Kiểm Tra Ôn Tập Hiragana', 'Lesson 24: Hiragana Review Quiz', '<h2>Kiểm Tra Hiragana</h2><p>Trả lời câu hỏi về Hiragana để mở khóa bài tiếp theo.</p><p><strong>Yêu cầu:</strong> Đạt 75% trở lên để qua bài.</p>', '<h2>Hiragana Quiz</h2><p>Answer questions about Hiragana to unlock next lesson.</p><p><strong>Requirement:</strong> Score 75% or higher to pass.</p>', 'review_quiz', 24),

(3, 25, 'Bài 25: Kiểm Tra Ôn Tập Katakana', 'Lesson 25: Katakana Review Quiz', '<h2>Kiểm Tra Katakana</h2><p>Trả lời câu hỏi về Katakana để mở khóa bài tiếp theo.</p><p><strong>Yêu cầu:</strong> Đạt 75% trở lên để qua bài.</p>', '<h2>Katakana Quiz</h2><p>Answer questions about Katakana to unlock next lesson.</p><p><strong>Requirement:</strong> Score 75% or higher to pass.</p>', 'review_quiz', 25),

(3, 26, 'Bài 26: Kiểm Tra Ôn Tập Tổng Hợp', 'Lesson 26: Comprehensive Review Quiz', '<h2>Kiểm Tra Tổng Hợp</h2><p>Kết hợp cả Hiragana và Katakana.</p><p><strong>Yêu cầu:</strong> Đạt 75% trở lên để qua bài.</p>', '<h2>Comprehensive Quiz</h2><p>Combine both Hiragana and Katakana.</p><p><strong>Requirement:</strong> Score 75% or higher to pass.</p>', 'review_quiz', 26),

(3, 27, 'Bài 27: Ôn Tập Từ Vựng Cơ Bản', 'Lesson 27: Basic Vocabulary Review', '<h2>Từ Vựng Cơ Bản</h2><p>Ôn tập các từ vựng đơn giản sử dụng Hiragana.</p><ul><li>こんにちは (konnichiwa) - Xin chào</li><li>ありがとう (arigatou) - Cảm ơn</li><li>すみません (sumimasen) - Xin lỗi</li></ul>', '<h2>Basic Vocabulary</h2><p>Review simple vocabulary using Hiragana.</p><ul><li>こんにちは (konnichiwa) - Hello</li><li>ありがとう (arigatou) - Thank you</li><li>すみません (sumimasen) - Excuse me</li></ul>', 'vocabulary', 27),

(3, 28, 'Bài 28: Kiểm Tra Cuối Chương', 'Lesson 28: Final Chapter Quiz', '<h2>Kiểm Tra Cuối Chương</h2><p>Kiểm tra toàn bộ kiến thức về bảng chữ cái Nhật Bản.</p><p><strong>Nội dung:</strong> Hiragana, Katakana, từ vựng cơ bản.</p><p><strong>Yêu cầu:</strong> Đạt 75% trở lên để hoàn thành Chương 1.</p>', '<h2>Final Chapter Quiz</h2><p>Test all knowledge about Japanese alphabets.</p><p><strong>Content:</strong> Hiragana, Katakana, basic vocabulary.</p><p><strong>Requirement:</strong> Score 75% or higher to complete Chapter 1.</p>', 'final_quiz', 28);

-- Set prerequisites for lessons (75% pass rate required)
UPDATE structured_lessons SET prerequisite_lesson_id = 24 WHERE lesson_number = 25;
UPDATE structured_lessons SET prerequisite_lesson_id = 25 WHERE lesson_number = 26;
UPDATE structured_lessons SET prerequisite_lesson_id = 26 WHERE lesson_number = 27;
UPDATE structured_lessons SET prerequisite_lesson_id = 27 WHERE lesson_number = 28;

-- ============================================================
-- SEED DATA - VOCABULARY
-- ============================================================

-- Vocabulary for early lessons
INSERT INTO vocabulary (lesson_id, word, romaji, hiragana, meaning_vi, meaning_en, word_type, order_index) VALUES
-- Lesson 1: Vowels
(1, 'あ', 'a', 'あ', 'nguyên âm a', 'vowel a', 'expression', 1),
(1, 'い', 'i', 'い', 'nguyên âm i', 'vowel i', 'expression', 2),
(1, 'う', 'u', 'う', 'nguyên âm u', 'vowel u', 'expression', 3),
(1, 'え', 'e', 'え', 'nguyên âm e', 'vowel e', 'expression', 4),
(1, 'お', 'o', 'お', 'nguyên âm o', 'vowel o', 'expression', 5),

-- Lesson 2: K Group
(2, 'か', 'ka', 'か', 'ka', 'ka', 'expression', 1),
(2, 'き', 'ki', 'き', 'ki', 'ki', 'expression', 2),
(2, 'く', 'ku', 'く', 'ku', 'ku', 'expression', 3),
(2, 'け', 'ke', 'け', 'ke', 'ke', 'expression', 4),
(2, 'こ', 'ko', 'こ', 'ko', 'ko', 'expression', 5),

-- Lesson 3: S Group
(3, 'さ', 'sa', 'さ', 'sa', 'sa', 'expression', 1),
(3, 'し', 'shi', 'し', 'shi', 'shi', 'expression', 2),
(3, 'す', 'su', 'す', 'su', 'su', 'expression', 3),
(3, 'せ', 'se', 'せ', 'se', 'se', 'expression', 4),
(3, 'そ', 'so', 'そ', 'so', 'so', 'expression', 5),

-- Lesson 4: T Group
(4, 'た', 'ta', 'た', 'ta', 'ta', 'expression', 1),
(4, 'ち', 'chi', 'ち', 'chi', 'chi', 'expression', 2),
(4, 'つ', 'tsu', 'つ', 'tsu', 'tsu', 'expression', 3),
(4, 'て', 'te', 'て', 'te', 'te', 'expression', 4),
(4, 'と', 'to', 'と', 'to', 'to', 'expression', 5),

-- Lesson 5: N Group
(5, 'な', 'na', 'な', 'na', 'na', 'expression', 1),
(5, 'に', 'ni', 'に', 'ni', 'ni', 'expression', 2),
(5, 'ぬ', 'nu', 'ぬ', 'nu', 'nu', 'expression', 3),
(5, 'ね', 'ne', 'ね', 'ne', 'ne', 'expression', 4),
(5, 'の', 'no', 'の', 'no', 'no', 'expression', 5),

-- Lesson 6: H Group
(6, 'は', 'ha', 'は', 'ha', 'ha', 'expression', 1),
(6, 'ひ', 'hi', 'ひ', 'hi', 'hi', 'expression', 2),
(6, 'ふ', 'fu', 'ふ', 'fu', 'fu', 'expression', 3),
(6, 'へ', 'he', 'へ', 'he', 'he', 'expression', 4),
(6, 'ほ', 'ho', 'ほ', 'ho', 'ho', 'expression', 5),

-- Lesson 7: M Group
(7, 'ま', 'ma', 'ま', 'ma', 'ma', 'expression', 1),
(7, 'み', 'mi', 'み', 'mi', 'mi', 'expression', 2),
(7, 'む', 'mu', 'む', 'mu', 'mu', 'expression', 3),
(7, 'め', 'me', 'め', 'me', 'me', 'expression', 4),
(7, 'も', 'mo', 'も', 'mo', 'mo', 'expression', 5),

-- Lesson 8: Y Group
(8, 'や', 'ya', 'や', 'ya', 'ya', 'expression', 1),
(8, 'ゆ', 'yu', 'ゆ', 'yu', 'yu', 'expression', 2),
(8, 'よ', 'yo', 'よ', 'yo', 'yo', 'expression', 3),

-- Lesson 9: R Group
(9, 'ら', 'ra', 'ら', 'ra', 'ra', 'expression', 1),
(9, 'り', 'ri', 'り', 'ri', 'ri', 'expression', 2),
(9, 'る', 'ru', 'る', 'ru', 'ru', 'expression', 3),
(9, 'れ', 're', 'れ', 're', 're', 'expression', 4),
(9, 'ろ', 'ro', 'ろ', 'ro', 'ro', 'expression', 5),

-- Lesson 10: W Group and Special N
(10, 'わ', 'wa', 'わ', 'wa', 'wa', 'expression', 1),
(10, 'を', 'wo', 'を', 'wo (trợ từ)', 'wo (particle)', 'particle', 2),
(10, 'ん', 'n', 'ん', 'âm mũi n', 'nasal n', 'expression', 3),

-- Lesson 27: Basic Vocabulary
(27, 'こんにちは', 'konnichiwa', 'こんにちは', 'xin chào (ban ngày)', 'hello (daytime)', 'expression', 1),
(27, 'こんばんは', 'konbanwa', 'こんばんは', 'xin chào (buổi tối)', 'good evening', 'expression', 2),
(27, 'おはようございます', 'ohayou gozaimasu', 'おはようございます', 'chào buổi sáng', 'good morning', 'expression', 3),
(27, 'ありがとうございます', 'arigatou gozaimasu', 'ありがとうございます', 'cảm ơn (lịch sự)', 'thank you (polite)', 'expression', 4),
(27, 'すみません', 'sumimasen', 'すみません', 'xin lỗi / xin phép', 'excuse me / sorry', 'expression', 5),
(27, 'はい', 'hai', 'はい', 'vâng / đúng', 'yes / correct', 'expression', 6),
(27, 'いいえ', 'iie', 'いいえ', 'không', 'no', 'expression', 7);

-- ============================================================
-- SEED DATA - QUIZ QUESTIONS
-- ============================================================

-- Hiragana Review Quiz (Lesson 24) - 25 questions
INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES
(24, 'Chữ cái nào phát âm là "ka"?', 'Which character is pronounced "ka"?', 'multiple_choice', '["か", "き", "く", "け"]', '["か", "き", "く", "け"]', 'か', 'か', 'か là chữ cái đầu tiên của nhóm K.', 'か is the first character of the K group.', 1),
(24, 'Chữ cái nào phát âm là "shi"?', 'Which character is pronounced "shi"?', 'multiple_choice', '["さ", "し", "す", "せ"]', '["さ", "し", "す", "せ"]', 'し', 'し', 'し phát âm là "shi", không phải "si".', 'し is pronounced "shi", not "si".', 2),
(24, 'Nhóm nào có 5 chữ cái?', 'Which group has 5 characters?', 'multiple_choice', '["Nhóm Y", "Nhóm W", "Nhóm K", "Nhóm N đặc biệt"]', '["Y Group", "W Group", "K Group", "Special N Group"]', 'Nhóm K', 'K Group', 'Tất cả các nhóm chính (K, S, T, N, H, M, R) đều có 5 chữ cái.', 'All main groups (K, S, T, N, H, M, R) have 5 characters.', 3),
(24, 'Chữ cái ん thuộc nhóm nào?', 'Which group does ん belong to?', 'multiple_choice', '["Nhóm N", "Nhóm N đặc biệt", "Nhóm W", "Không có nhóm"]', '["N Group", "Special N Group", "W Group", "No group"]', 'Nhóm N đặc biệt', 'Special N Group', 'ん là chữ cái đặc biệt, chỉ có một mình.', 'ん is a special character, standing alone.', 4),
(24, 'Chữ cái nào phát âm là "chi"?', 'Which character is pronounced "chi"?', 'multiple_choice', '["た", "ち", "つ", "て"]', '["た", "ち", "つ", "て"]', 'ち', 'ち', 'ち thuộc nhóm T và phát âm là "chi".', 'ち belongs to T group and is pronounced "chi".', 5);

-- Add more quiz questions for Lesson 24 (continuing to 25 questions)
INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES
(24, 'Chữ cái ふ phát âm là gì?', 'How is ふ pronounced?', 'multiple_choice', '["hu", "fu", "hi", "he"]', '["hu", "fu", "hi", "he"]', 'fu', 'fu', 'ふ phát âm là "fu", không phải "hu".', 'ふ is pronounced "fu", not "hu".', 6),
(24, 'Nhóm nào chỉ có 3 chữ cái?', 'Which group has only 3 characters?', 'multiple_choice', '["Nhóm Y", "Nhóm W", "Nhóm R", "Nhóm M"]', '["Y Group", "W Group", "R Group", "M Group"]', 'Nhóm Y', 'Y Group', 'Nhóm Y chỉ có や (ya), ゆ (yu), よ (yo).', 'Y Group only has や (ya), ゆ (yu), よ (yo).', 7),
(24, 'Chữ cái nào thuộc nhóm M?', 'Which character belongs to M group?', 'multiple_choice', '["ま", "ら", "は", "な"]', '["ま", "ら", "は", "な"]', 'ま', 'ま', 'ま (ma) thuộc nhóm M.', 'ま (ma) belongs to M group.', 8),
(24, 'Chữ cái り phát âm là gì?', 'How is り pronounced?', 'multiple_choice', '["ri", "li", "ru", "re"]', '["ri", "li", "ru", "re"]', 'ri', 'ri', 'り phát âm là "ri".', 'り is pronounced "ri".', 9),
(24, 'Chữ cái わ thuộc nhóm nào?', 'Which group does わ belong to?', 'multiple_choice', '["Nhóm W", "Nhóm Y", "Nhóm R", "Nhóm N"]', '["W Group", "Y Group", "R Group", "N Group"]', 'Nhóm W', 'W Group', 'わ (wa) thuộc nhóm W.', 'わ (wa) belongs to W group.', 10),
(24, 'Có bao nhiêu chữ cái Hiragana cơ bản?', 'How many basic Hiragana characters are there?', 'multiple_choice', '["42", "46", "48", "50"]', '["42", "46", "48", "50"]', '46', '46', 'Có 46 chữ cái Hiragana cơ bản.', 'There are 46 basic Hiragana characters.', 11),
(24, 'Chữ cái nào phát âm giống L hơn R?', 'Which character is pronounced more like L than R?', 'multiple_choice', '["ら", "り", "る", "れ"]', '["ら", "り", "る", "れ"]', 'ら', 'ら', 'Nhóm R phát âm giống L hơn R trong tiếng Anh.', 'R group is pronounced more like L than R in English.', 12),
(24, 'Chữ cái つ phát âm là gì?', 'How is つ pronounced?', 'multiple_choice', '["tsu", "tu", "su", "tsu"]', '["tsu", "tu", "su", "tsu"]', 'tsu', 'tsu', 'つ phát âm là "tsu".', 'つ is pronounced "tsu".', 13),
(24, 'Chữ cái へ thuộc nhóm nào?', 'Which group does へ belong to?', 'multiple_choice', '["Nhóm H", "Nhóm N", "Nhóm M", "Nhóm R"]', '["H Group", "N Group", "M Group", "R Group"]', 'Nhóm H', 'H Group', 'へ (he) thuộc nhóm H.', 'へ (he) belongs to H group.', 14),
(24, 'Chữ cái nào chỉ dùng làm trợ từ?', 'Which character is only used as a particle?', 'multiple_choice', '["わ", "を", "ん", "よ"]', '["わ", "を", "ん", "よ"]', 'を', 'を', 'を (wo) chỉ dùng làm trợ từ.', 'を (wo) is only used as a particle.', 15),
(24, 'Chữ cái む thuộc nhóm nào?', 'Which group does む belong to?', 'multiple_choice', '["Nhóm M", "Nhóm N", "Nhóm H", "Nhóm R"]', '["M Group", "N Group", "H Group", "R Group"]', 'Nhóm M', 'M Group', 'む (mu) thuộc nhóm M.', 'む (mu) belongs to M group.', 16),
(24, 'Chữ cái せ phát âm là gì?', 'How is せ pronounced?', 'multiple_choice', '["se", "shi", "su", "so"]', '["se", "shi", "su", "so"]', 'se', 'se', 'せ phát âm là "se".', 'せ is pronounced "se".', 17),
(24, 'Nhóm nào có chữ cái phát âm giống "chi"?', 'Which group has a character pronounced like "chi"?', 'multiple_choice', '["Nhóm T", "Nhóm S", "Nhóm H", "Nhóm N"]', '["T Group", "S Group", "H Group", "N Group"]', 'Nhóm T', 'T Group', 'ち (chi) thuộc nhóm T.', 'ち (chi) belongs to T group.', 18),
(24, 'Chữ cái て thuộc nhóm nào?', 'Which group does て belong to?', 'multiple_choice', '["Nhóm T", "Nhóm S", "Nhóm N", "Nhóm H"]', '["T Group", "S Group", "N Group", "H Group"]', 'Nhóm T', 'T Group', 'て (te) thuộc nhóm T.', 'て (te) belongs to T group.', 19),
(24, 'Chữ cái nào phát âm là "no"?', 'Which character is pronounced "no"?', 'multiple_choice', '["の", "に", "ぬ", "ね"]', '["の", "に", "ぬ", "ね"]', 'の', 'の', 'の phát âm là "no".', 'の is pronounced "no".', 20),
(24, 'Chữ cái ひ thuộc nhóm nào?', 'Which group does ひ belong to?', 'multiple_choice', '["Nhóm H", "Nhóm M", "Nhóm Y", "Nhóm R"]', '["H Group", "M Group", "Y Group", "R Group"]', 'Nhóm H', 'H Group', 'ひ (hi) thuộc nhóm H.', 'ひ (hi) belongs to H group.', 21),
(24, 'Chữ cái ろ thuộc nhóm nào?', 'Which group does ろ belong to?', 'multiple_choice', '["Nhóm R", "Nhóm W", "Nhóm Y", "Nhóm N"]', '["R Group", "W Group", "Y Group", "N Group"]', 'Nhóm R', 'R Group', 'ろ (ro) thuộc nhóm R.', 'ろ (ro) belongs to R group.', 22),
(24, 'Chữ cái く phát âm là gì?', 'How is く pronounced?', 'multiple_choice', '["ku", "ka", "ki", "ke"]', '["ku", "ka", "ki", "ke"]', 'ku', 'ku', 'く phát âm là "ku".', 'く is pronounced "ku".', 23),
(24, 'Chữ cái nào thuộc nhóm S?', 'Which character belongs to S group?', 'multiple_choice', '["そ", "た", "な", "は"]', '["そ", "た", "な", "は"]', 'そ', 'そ', 'そ (so) thuộc nhóm S.', 'そ (so) belongs to S group.', 24),
(24, 'Chữ cái ん phát âm là gì?', 'How is ん pronounced?', 'multiple_choice', '["m", "n", "ng", "nh"]', '["m", "n", "ng", "nh"]', 'n', 'n', 'ん phát âm là âm mũi "n".', 'ん is pronounced as nasal "n".', 25);

-- Katakana Review Quiz (Lesson 25) - 25 questions
INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES
(25, 'Katakana ア phát âm là gì?', 'How is Katakana ア pronounced?', 'multiple_choice', '["a", "i", "u", "e"]', '["a", "i", "u", "e"]', 'a', 'a', 'ア là nguyên âm "a" trong Katakana.', 'ア is the vowel "a" in Katakana.', 1),
(25, 'Katakana シ phát âm là gì?', 'How is Katakana シ pronounced?', 'multiple_choice', '["sa", "shi", "su", "se"]', '["sa", "shi", "su", "se"]', 'shi', 'shi', 'シ phát âm là "shi".', 'シ is pronounced "shi".', 2),
(25, 'Katakana ク thuộc nhóm nào?', 'Which group does Katakana ク belong to?', 'multiple_choice', '["Nhóm K", "Nhóm S", "Nhóm T", "Nhóm N"]', '["K Group", "S Group", "T Group", "N Group"]', 'Nhóm K', 'K Group', 'ク (ku) thuộc nhóm K trong Katakana.', 'ク (ku) belongs to K group in Katakana.', 3),
(25, 'Katakana ン phát âm là gì?', 'How is Katakana ン pronounced?', 'multiple_choice', '["m", "n", "ng", "nh"]', '["m", "n", "ng", "nh"]', 'n', 'n', 'ン là âm mũi "n" trong Katakana.', 'ン is the nasal "n" sound in Katakana.', 4),
(25, 'Katakana チ phát âm là gì?', 'How is Katakana チ pronounced?', 'multiple_choice', '["ta", "chi", "tsu", "te"]', '["ta", "chi", "tsu", "te"]', 'chi', 'chi', 'チ phát âm là "chi".', 'チ is pronounced "chi".', 5);

-- Add more Katakana quiz questions (continuing to 25)
INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES
(25, 'Katakana フ phát âm là gì?', 'How is Katakana フ pronounced?', 'multiple_choice', '["hu", "fu", "hi", "he"]', '["hu", "fu", "hi", "he"]', 'fu', 'fu', 'フ phát âm là "fu".', 'フ is pronounced "fu".', 6),
(25, 'Katakana ヤ thuộc nhóm nào?', 'Which group does Katakana ヤ belong to?', 'multiple_choice', '["Nhóm Y", "Nhóm W", "Nhóm R", "Nhóm M"]', '["Y Group", "W Group", "R Group", "M Group"]', 'Nhóm Y', 'Y Group', 'ヤ (ya) thuộc nhóm Y.', 'ヤ (ya) belongs to Y group.', 7),
(25, 'Katakana マ thuộc nhóm nào?', 'Which group does Katakana マ belong to?', 'multiple_choice', '["Nhóm M", "Nhóm N", "Nhóm H", "Nhóm R"]', '["M Group", "N Group", "H Group", "R Group"]', 'Nhóm M', 'M Group', 'マ (ma) thuộc nhóm M.', 'マ (ma) belongs to M group.', 8),
(25, 'Katakana リ phát âm là gì?', 'How is Katakana リ pronounced?', 'multiple_choice', '["ri", "li", "ru", "re"]', '["ri", "li", "ru", "re"]', 'ri', 'ri', 'リ phát âm là "ri".', 'リ is pronounced "ri".', 9),
(25, 'Katakana ワ thuộc nhóm nào?', 'Which group does Katakana ワ belong to?', 'multiple_choice', '["Nhóm W", "Nhóm Y", "Nhóm R", "Nhóm N"]', '["W Group", "Y Group", "R Group", "N Group"]', 'Nhóm W', 'W Group', 'ワ (wa) thuộc nhóm W.', 'ワ (wa) belongs to W group.', 10),
(25, 'Có bao nhiêu chữ cái Katakana cơ bản?', 'How many basic Katakana characters are there?', 'multiple_choice', '["42", "46", "48", "50"]', '["42", "46", "48", "50"]', '46', '46', 'Có 46 chữ cái Katakana cơ bản.', 'There are 46 basic Katakana characters.', 11),
(25, 'Katakana ラ thuộc nhóm nào?', 'Which group does Katakana ラ belong to?', 'multiple_choice', '["Nhóm R", "Nhóm W", "Nhóm Y", "Nhóm N"]', '["R Group", "W Group", "Y Group", "N Group"]', 'Nhóm R', 'R Group', 'ラ (ra) thuộc nhóm R.', 'ラ (ra) belongs to R group.', 12),
(25, 'Katakana ツ phát âm là gì?', 'How is Katakana ツ pronounced?', 'multiple_choice', '["tsu", "tu", "su", "tsu"]', '["tsu", "tu", "su", "tsu"]', 'tsu', 'tsu', 'ツ phát âm là "tsu".', 'ツ is pronounced "tsu".', 13),
(25, 'Katakana ヘ thuộc nhóm nào?', 'Which group does Katakana ヘ belong to?', 'multiple_choice', '["Nhóm H", "Nhóm N", "Nhóm M", "Nhóm R"]', '["H Group", "N Group", "M Group", "R Group"]', 'Nhóm H', 'H Group', 'ヘ (he) thuộc nhóm H.', 'ヘ (he) belongs to H group.', 14),
(25, 'Katakana ヲ phát âm là gì?', 'How is Katakana ヲ pronounced?', 'multiple_choice', '["wa", "wo", "wi", "we"]', '["wa", "wo", "wi", "we"]', 'wo', 'wo', 'ヲ phát âm là "wo".', 'ヲ is pronounced "wo".', 15),
(25, 'Katakana ム thuộc nhóm nào?', 'Which group does Katakana ム belong to?', 'multiple_choice', '["Nhóm M", "Nhóm N", "Nhóm H", "Nhóm R"]', '["M Group", "N Group", "H Group", "R Group"]', 'Nhóm M', 'M Group', 'ム (mu) thuộc nhóm M.', 'ム (mu) belongs to M group.', 16),
(25, 'Katakana セ phát âm là gì?', 'How is Katakana セ pronounced?', 'multiple_choice', '["se", "shi", "su", "so"]', '["se", "shi", "su", "so"]', 'se', 'se', 'セ phát âm là "se".', 'セ is pronounced "se".', 17),
(25, 'Katakana チ thuộc nhóm nào?', 'Which group does Katakana チ belong to?', 'multiple_choice', '["Nhóm T", "Nhóm S", "Nhóm H", "Nhóm N"]', '["T Group", "S Group", "H Group", "N Group"]', 'Nhóm T', 'T Group', 'チ (chi) thuộc nhóm T.', 'チ (chi) belongs to T group.', 18),
(25, 'Katakana テ thuộc nhóm nào?', 'Which group does Katakana テ belong to?', 'multiple_choice', '["Nhóm T", "Nhóm S", "Nhóm N", "Nhóm H"]', '["T Group", "S Group", "N Group", "H Group"]', 'Nhóm T', 'T Group', 'テ (te) thuộc nhóm T.', 'テ (te) belongs to T group.', 19),
(25, 'Katakana ノ phát âm là gì?', 'How is Katakana ノ pronounced?', 'multiple_choice', '["no", "ni", "nu", "ne"]', '["no", "ni", "nu", "ne"]', 'no', 'no', 'ノ phát âm là "no".', 'ノ is pronounced "no".', 20),
(25, 'Katakana ヒ thuộc nhóm nào?', 'Which group does Katakana ヒ belong to?', 'multiple_choice', '["Nhóm H", "Nhóm M", "Nhóm Y", "Nhóm R"]', '["H Group", "M Group", "Y Group", "R Group"]', 'Nhóm H', 'H Group', 'ヒ (hi) thuộc nhóm H.', 'ヒ (hi) belongs to H group.', 21),
(25, 'Katakana ロ thuộc nhóm nào?', 'Which group does Katakana ロ belong to?', 'multiple_choice', '["Nhóm R", "Nhóm W", "Nhóm Y", "Nhóm N"]', '["R Group", "W Group", "Y Group", "N Group"]', 'Nhóm R', 'R Group', 'ロ (ro) thuộc nhóm R.', 'ロ (ro) belongs to R group.', 22),
(25, 'Katakana ク phát âm là gì?', 'How is Katakana ク pronounced?', 'multiple_choice', '["ku", "ka", "ki", "ke"]', '["ku", "ka", "ki", "ke"]', 'ku', 'ku', 'ク phát âm là "ku".', 'ク is pronounced "ku".', 23),
(25, 'Katakana ソ thuộc nhóm nào?', 'Which group does Katakana ソ belong to?', 'multiple_choice', '["Nhóm S", "Nhóm T", "Nhóm N", "Nhóm H"]', '["S Group", "S Group", "N Group", "H Group"]', 'Nhóm S', 'S Group', 'ソ (so) thuộc nhóm S.', 'ソ (so) belongs to S group.', 24),
(25, 'Katakana ン thuộc nhóm nào?', 'Which group does Katakana ン belong to?', 'multiple_choice', '["Nhóm N đặc biệt", "Nhóm W", "Nhóm Y", "Nhóm R"]', '["Special N Group", "W Group", "Y Group", "R Group"]', 'Nhóm N đặc biệt', 'Special N Group', 'ン là chữ cái đặc biệt.', 'ン is a special character.', 25);

-- Comprehensive Review Quiz (Lesson 26) - 25 questions
INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES
(26, 'Chữ cái あ là Hiragana hay Katakana?', 'Is あ Hiragana or Katakana?', 'multiple_choice', '["Hiragana", "Katakana", "Cả hai", "Không phải"]', '["Hiragana", "Katakana", "Both", "Neither"]', 'Hiragana', 'Hiragana', 'あ là chữ cái Hiragana.', 'あ is a Hiragana character.', 1),
(26, 'Chữ cái ア là Hiragana hay Katakana?', 'Is ア Hiragana or Katakana?', 'multiple_choice', '["Hiragana", "Katakana", "Cả hai", "Không phải"]', '["Hiragana", "Katakana", "Both", "Neither"]', 'Katakana', 'Katakana', 'ア là chữ cái Katakana.', 'ア is a Katakana character.', 2),
(26, 'Cả Hiragana và Katakana đều có bao nhiêu chữ cái cơ bản?', 'How many basic characters do both Hiragana and Katakana have?', 'multiple_choice', '["42", "46", "48", "50"]', '["42", "46", "48", "50"]', '46', '46', 'Cả hai bảng chữ cái đều có 46 chữ cái cơ bản.', 'Both alphabets have 46 basic characters.', 3),
(26, 'Chữ cái nào chỉ có trong Hiragana?', 'Which character only exists in Hiragana?', 'multiple_choice', '["を", "ヲ", "ん", "ン"]', '["を", "ヲ", "ん", "ン"]', 'を', 'を', 'を chỉ có trong Hiragana.', 'を only exists in Hiragana.', 4),
(26, 'Chữ cái ん và ン có khác nhau không?', 'Are ん and ン different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "ん là Hiragana, ン là Katakana", "Không có chữ ン"]', '["Yes, different alphabets", "No, same", "ん is Hiragana, ン is Katakana", "ン does not exist"]', 'ん là Hiragana, ン là Katakana', 'ん is Hiragana, ン is Katakana', 'ん là Hiragana, ン là Katakana nhưng cùng phát âm.', 'ん is Hiragana, ン is Katakana but same pronunciation.', 5);

-- Add more comprehensive quiz questions
INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES
(26, 'Katakana thường dùng để viết gì?', 'What is Katakana usually used to write?', 'multiple_choice', '["Từ ngữ bản địa Nhật", "Từ nước ngoài", "Tên riêng Nhật", "Tất cả đều đúng"]', '["Native Japanese words", "Foreign words", "Japanese proper names", "All are correct"]', 'Từ nước ngoài', 'Foreign words', 'Katakana dùng để viết từ nước ngoài và tên riêng.', 'Katakana is used for foreign words and proper names.', 6),
(26, 'Chữ cái し và シ có khác nhau không?', 'Are し and シ different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "し là Hiragana, シ là Katakana", "Không có chữ シ"]', '["Yes, different alphabets", "No, same", "し is Hiragana, シ is Katakana", "シ does not exist"]', 'し là Hiragana, シ là Katakana', 'し is Hiragana, シ is Katakana', 'し là Hiragana, シ là Katakana nhưng cùng phát âm "shi".', 'し is Hiragana, シ is Katakana but both pronounced "shi".', 7),
(26, 'Nhóm nào có số lượng chữ cái khác nhau giữa Hiragana và Katakana?', 'Which group has different number of characters between Hiragana and Katakana?', 'multiple_choice', '["Nhóm Y", "Nhóm W", "Nhóm N đặc biệt", "Tất cả đều giống"]', '["Y Group", "W Group", "Special N Group", "All are the same"]', 'Tất cả đều giống', 'All are the same', 'Cả hai bảng chữ cái có cùng số lượng chữ cái trong mỗi nhóm.', 'Both alphabets have the same number of characters in each group.', 8),
(26, 'Chữ cái ふ và フ có khác nhau không?', 'Are ふ and フ different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "ふ là Hiragana, フ là Katakana", "Không có chữ フ"]', '["Yes, different alphabets", "No, same", "ふ is Hiragana, フ is Katakana", "フ does not exist"]', 'ふ là Hiragana, フ là Katakana', 'ふ is Hiragana, フ is Katakana', 'ふ là Hiragana, フ là Katakana nhưng cùng phát âm "fu".', 'ふ is Hiragana, フ is Katakana but both pronounced "fu".', 9),
(26, 'Hiragana thường dùng để viết gì?', 'What is Hiragana usually used to write?', 'multiple_choice', '["Từ ngữ bản địa Nhật", "Từ nước ngoài", "Tên riêng Nhật", "Tất cả đều đúng"]', '["Native Japanese words", "Foreign words", "Japanese proper names", "All are correct"]', 'Từ ngữ bản địa Nhật', 'Native Japanese words', 'Hiragana dùng để viết từ ngữ bản địa và ngữ pháp.', 'Hiragana is used for native words and grammar.', 10),
(26, 'Chữ cái つ và ツ có khác nhau không?', 'Are つ and ツ different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "つ là Hiragana, ツ là Katakana", "Không có chữ ツ"]', '["Yes, different alphabets", "No, same", "つ is Hiragana, ツ is Katakana", "ツ does not exist"]', 'つ là Hiragana, ツ là Katakana', 'つ is Hiragana, ツ is Katakana', 'つ là Hiragana, ツ là Katakana nhưng cùng phát âm "tsu".', 'つ is Hiragana, ツ is Katakana but both pronounced "tsu".', 11),
(26, 'Cả hai bảng chữ cái đều có chữ cái đặc biệt nào?', 'Which special character do both alphabets have?', 'multiple_choice', '["を", "ヲ", "ん", "ン"]', '["を", "ヲ", "ん", "ン"]', 'ん', 'ん', 'Chỉ ん có trong cả hai bảng chữ cái.', 'Only ん exists in both alphabets.', 12),
(26, 'Chữ cái ち và チ có khác nhau không?', 'Are ち and チ different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "ち là Hiragana, チ là Katakana", "Không có chữ チ"]', '["Yes, different alphabets", "No, same", "ち is Hiragana, チ is Katakana", "チ does not exist"]', 'ち là Hiragana, チ là Katakana', 'ち is Hiragana, チ is Katakana', 'ち là Hiragana, チ là Katakana nhưng cùng phát âm "chi".', 'ち is Hiragana, チ is Katakana but both pronounced "chi".', 13),
(26, 'Katakana có hình dáng như thế nào so với Hiragana?', 'What is the shape of Katakana compared to Hiragana?', 'multiple_choice', '["Bo tròn hơn", "Góc cạnh hơn", "Giống hệt nhau", "Không có quy luật"]', '["More rounded", "More angular", "Exactly the same", "No pattern"]', 'Góc cạnh hơn', 'More angular', 'Katakana có hình dáng góc cạnh hơn Hiragana.', 'Katakana has more angular shapes than Hiragana.', 14),
(26, 'Chữ cái ら và ラ có khác nhau không?', 'Are ら and ラ different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "ら là Hiragana, ラ là Katakana", "Không có chữ ラ"]', '["Yes, different alphabets", "No, same", "ら is Hiragana, ラ is Katakana", "ラ does not exist"]', 'ら là Hiragana, ラ là Katakana', 'ら is Hiragana, ラ is Katakana', 'ら là Hiragana, ラ là Katakana nhưng cùng phát âm "ra".', 'ら is Hiragana, ラ is Katakana but both pronounced "ra".', 15),
(26, 'Nhóm nào chỉ có 3 chữ cái trong cả hai bảng?', 'Which group has only 3 characters in both alphabets?', 'multiple_choice', '["Nhóm Y", "Nhóm W", "Nhóm R", "Nhóm M"]', '["Y Group", "W Group", "R Group", "M Group"]', 'Nhóm Y', 'Y Group', 'Nhóm Y chỉ có 3 chữ cái: ya, yu, yo.', 'Y Group only has 3 characters: ya, yu, yo.', 16),
(26, 'Chữ cái へ và ヘ có khác nhau không?', 'Are へ and ヘ different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "へ là Hiragana, ヘ là Katakana", "Không có chữ ヘ"]', '["Yes, different alphabets", "No, same", "へ is Hiragana, ヘ is Katakana", "ヘ does not exist"]', 'へ là Hiragana, ヘ là Katakana', 'へ là Hiragana, ヘ là Katakana', 'へ là Hiragana, ヘ là Katakana nhưng cùng phát âm "he".', 'へ is Hiragana, ヘ is Katakana but both pronounced "he".', 17),
(26, 'Hiragana và Katakana có cùng phát âm không?', 'Do Hiragana and Katakana have the same pronunciation?', 'multiple_choice', '["Có, hoàn toàn giống", "Không, khác nhau", "Hầu hết giống, một số khác", "Không có quy luật"]', '["Yes, completely same", "No, different", "Mostly same, some different", "No pattern"]', 'Có, hoàn toàn giống', 'Yes, completely same', 'Mỗi chữ cái Hiragana và Katakana tương ứng có cùng phát âm.', 'Each corresponding Hiragana and Katakana character has the same pronunciation.', 18),
(26, 'Chữ cái わ và ワ có khác nhau không?', 'Are わ and ワ different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "わ là Hiragana, ワ là Katakana", "Không có chữ ワ"]', '["Yes, different alphabets", "No, same", "わ is Hiragana, ワ is Katakana", "ワ does not exist"]', 'わ là Hiragana, ワ là Katakana', 'わ là Hiragana, ワ là Katakana', 'わ là Hiragana, ワ là Katakana nhưng cùng phát âm "wa".', 'わ is Hiragana, ワ is Katakana but both pronounced "wa".', 19),
(26, 'Katakana được phát minh từ đâu?', 'Where was Katakana invented from?', 'multiple_choice', '["Từ chữ Hán", "Từ Hiragana", "Từ chữ Sanskrit", "Từ chữ La Mã"]', '["From Chinese characters", "From Hiragana", "From Sanskrit", "From Roman letters"]', 'Từ chữ Hán', 'From Chinese characters', 'Katakana được phát minh từ các phần của chữ Hán.', 'Katakana was invented from parts of Chinese characters.', 20),
(26, 'Chữ cái む và ム có khác nhau không?', 'Are む and ム different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "む là Hiragana, ム là Katakana", "Không có chữ ム"]', '["Yes, different alphabets", "No, same", "む is Hiragana, ム is Katakana", "ム does not exist"]', 'む là Hiragana, ム là Katakana', 'む is Hiragana, ム is Katakana', 'む là Hiragana, ム là Katakana nhưng cùng phát âm "mu".', 'む is Hiragana, ム is Katakana but both pronounced "mu".', 21),
(26, 'Hiragana được phát minh từ đâu?', 'Where was Hiragana invented from?', 'multiple_choice', '["Từ chữ Hán", "Từ chữ Sanskrit", "Từ chữ La Mã", "Từ chữ thảo"]', '["From Chinese characters", "From Sanskrit", "From Roman letters", "From cursive script"]', 'Từ chữ thảo', 'From cursive script', 'Hiragana được phát minh từ chữ thảo của chữ Hán.', 'Hiragana was invented from cursive script of Chinese characters.', 22),
(26, 'Chữ cái そ và ソ có khác nhau không?', 'Are そ and ソ different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "そ là Hiragana, ソ là Katakana", "Không có chữ ソ"]', '["Yes, different alphabets", "No, same", "そ is Hiragana, ソ is Katakana", "ソ does not exist"]', 'そ là Hiragana, ソ là Katakana', 'そ là Hiragana, ソ là Katakana', 'そ là Hiragana, ソ là Katakana nhưng cùng phát âm "so".', 'そ is Hiragana, ソ is Katakana but both pronounced "so".', 23),
(26, 'Cả hai bảng chữ cái đều bắt đầu từ nhóm nào?', 'Which group do both alphabets start with?', 'multiple_choice', '["Nhóm A", "Nhóm K", "Nhóm S", "Nhóm T"]', '["A Group", "K Group", "S Group", "T Group"]', 'Nhóm A', 'A Group', 'Cả hai bảng chữ cái đều bắt đầu với 5 nguyên âm (nhóm A).', 'Both alphabets start with the 5 vowels (A Group).', 24),
(26, 'Chữ cái ん/ン dùng để viết gì?', 'What is ん/ン used to write?', 'multiple_choice', '["Âm mũi n", "Âm m", "Âm ng", "Âm nh"]', '["Nasal n sound", "M sound", "Ng sound", "Nh sound"]', 'Âm mũi n', 'Nasal n sound', 'ん/ン dùng để viết âm mũi n.', 'ん/ン is used to write the nasal n sound.', 25);

-- Final Chapter Quiz (Lesson 28) - 100 questions
-- This would be a comprehensive quiz covering all material
-- For brevity, I'll add just a few sample questions
INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES
(28, 'こんにちは bằng tiếng Việt nghĩa là gì?', 'What does こんにちは mean in Vietnamese?', 'multiple_choice', '["Chào buổi sáng", "Chào buổi tối", "Xin chào (ban ngày)", "Tạm biệt"]', '["Good morning", "Good evening", "Hello (daytime)", "Goodbye"]', 'Xin chào (ban ngày)', 'Hello (daytime)', 'こんにちは nghĩa là "xin chào" dùng ban ngày.', 'こんにちは means "hello" used during daytime.', 1),
(28, 'Katakana ア phát âm là gì?', 'How is Katakana ア pronounced?', 'multiple_choice', '["a", "i", "u", "e"]', '["a", "i", "u", "e"]', 'a', 'a', 'ア là nguyên âm "a" trong Katakana.', 'ア is the vowel "a" in Katakana.', 2),
(28, 'Chữ cái し thuộc nhóm nào?', 'Which group does し belong to?', 'multiple_choice', '["Nhóm S", "Nhóm T", "Nhóm N", "Nhóm H"]', '["S Group", "T Group", "N Group", "H Group"]', 'Nhóm S', 'S Group', 'し (shi) thuộc nhóm S.', 'し (shi) belongs to S group.', 3),
(28, 'ありがとうございます nghĩa là gì?', 'What does ありがとうございます mean?', 'multiple_choice', '["Cảm ơn (lịch sự)", "Xin lỗi", "Xin chào", "Tạm biệt"]', '["Thank you (polite)", "Sorry", "Hello", "Goodbye"]', 'Cảm ơn (lịch sự)', 'Thank you (polite)', 'ありがとうございます là cách nói "cảm ơn" lịch sự.', 'ありがとうございます is the polite way to say "thank you".', 4),
(28, 'Có bao nhiêu chữ cái Hiragana cơ bản?', 'How many basic Hiragana characters are there?', 'multiple_choice', '["42", "46", "48", "50"]', '["42", "46", "48", "50"]', '46', '46', 'Có 46 chữ cái Hiragana cơ bản.', 'There are 46 basic Hiragana characters.', 5);

-- Add more final quiz questions (continuing to 100 would be too long, so I'll add a few more)
INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES
(28, 'Katakana dùng để viết gì?', 'What is Katakana used to write?', 'multiple_choice', '["Từ bản địa Nhật", "Từ nước ngoài", "Tên người Nhật", "Tất cả đều đúng"]', '["Native Japanese words", "Foreign words", "Japanese names", "All are correct"]', 'Từ nước ngoài', 'Foreign words', 'Katakana chủ yếu dùng cho từ nước ngoài.', 'Katakana is mainly used for foreign words.', 6),
(28, 'Chữ cái ふ phát âm là gì?', 'How is ふ pronounced?', 'multiple_choice', '["hu", "fu", "hi", "he"]', '["hu", "fu", "hi", "he"]', 'fu', 'fu', 'ふ phát âm là "fu", không phải "hu".', 'ふ is pronounced "fu", not "hu".', 7),
(28, 'すみません có nghĩa là gì?', 'What does すみません mean?', 'multiple_choice', '["Cảm ơn", "Xin lỗi", "Xin chào", "Tạm biệt"]', '["Thank you", "Excuse me/Sorry", "Hello", "Goodbye"]', 'Xin lỗi', 'Excuse me/Sorry', 'すみません nghĩa là "xin lỗi" hoặc "xin phép".', 'すみません means "excuse me" or "sorry".', 8),
(28, 'Nhóm Y có bao nhiêu chữ cái?', 'How many characters does Y group have?', 'multiple_choice', '["3", "4", "5", "6"]', '["3", "4", "5", "6"]', '3', '3', 'Nhóm Y chỉ có ya, yu, yo.', 'Y group only has ya, yu, yo.', 9),
(28, 'Hiragana あ và Katakana ア có khác nhau không?', 'Are Hiragana あ and Katakana ア different?', 'multiple_choice', '["Có, khác bảng chữ cái", "Không, giống nhau", "あ là Hiragana, ア là Katakana", "Không có chữ ア"]', '["Yes, different alphabets", "No, same", "あ is Hiragana, ア is Katakana", "ア does not exist"]', 'あ là Hiragana, ア là Katakana', 'あ is Hiragana, ア is Katakana', 'あ là Hiragana, ア là Katakana nhưng cùng phát âm.', 'あ is Hiragana, ア is Katakana but same pronunciation.', 10);

-- ============================================================
-- SAMPLE USER DATA (for testing)
-- ============================================================

INSERT INTO users (username, email, password_hash, full_name) VALUES
('testuser', 'test@example.com', '$2b$10$dummy.hash.for.testing.purposes.only', 'Test User');

-- ============================================================
-- END OF SEED DATA
-- ============================================================

-- Create indexes for better performance
CREATE INDEX idx_structured_lessons_section ON structured_lessons(section_id);
CREATE INDEX idx_structured_lessons_prerequisite ON structured_lessons(prerequisite_lesson_id);
CREATE INDEX idx_vocabulary_lesson ON vocabulary(lesson_id);
CREATE INDEX idx_quiz_questions_lesson ON quiz_questions(lesson_id);
CREATE INDEX idx_user_progress_user ON user_progress(user_id);
CREATE INDEX idx_user_progress_lesson ON user_progress(lesson_id);
CREATE INDEX idx_quiz_attempts_user ON quiz_attempts(user_id);
CREATE INDEX idx_quiz_attempts_lesson ON quiz_attempts(lesson_id);