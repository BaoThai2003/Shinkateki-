-- ============================================================
-- SHINKATEKI (進化的) — Adaptive Japanese Learning System
-- Database Schema
-- ============================================================

CREATE DATABASE IF NOT EXISTS shinkateki
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE shinkateki;

-- ============================================================
-- USERS
-- ============================================================

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    language VARCHAR(10) NOT NULL DEFAULT 'en', -- 'en', 'vi'

    level INT NOT NULL DEFAULT 1,
    total_score INT NOT NULL DEFAULT 0,
    streak_days INT NOT NULL DEFAULT 0,

    last_active DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- STRUCTURED LESSONS
-- Pre-built lessons with chapters and sections
-- ============================================================

CREATE TABLE chapters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title_en VARCHAR(100) NOT NULL,
    title_vi VARCHAR(100) NOT NULL,
    description_en TEXT,
    description_vi TEXT,
    order_index INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chapter_id INT NOT NULL,
    title_en VARCHAR(100) NOT NULL,
    title_vi VARCHAR(100) NOT NULL,
    description_en TEXT,
    description_vi TEXT,
    order_index INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE structured_lessons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    section_id INT NOT NULL,
    lesson_number INT NOT NULL,
    title_en VARCHAR(200) NOT NULL,
    title_vi VARCHAR(200) NOT NULL,
    content_en TEXT NOT NULL,
    content_vi TEXT NOT NULL,
    type ENUM('reading', 'interactive', 'review') NOT NULL DEFAULT 'reading',
    script_type ENUM('hiragana', 'katakana', 'both') DEFAULT NULL,
    prerequisites TEXT, -- JSON array of required lesson IDs
    unlocks TEXT, -- JSON array of lesson IDs this unlocks
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE,
    UNIQUE KEY unique_lesson_number (section_id, lesson_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- VOCABULARY
-- Words taught in lessons
-- ============================================================

CREATE TABLE vocabulary (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NOT NULL,
    romaji VARCHAR(50) NOT NULL,
    hiragana VARCHAR(50),
    katakana VARCHAR(50),
    kanji VARCHAR(50),
    english_meaning VARCHAR(200) NOT NULL,
    vietnamese_meaning VARCHAR(200) NOT NULL,
    part_of_speech VARCHAR(50), -- noun, verb, adjective, etc.
    example_sentence_en TEXT,
    example_sentence_vi TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- QUIZ QUESTIONS
-- Pre-built questions for lessons
-- ============================================================

CREATE TABLE quiz_questions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NOT NULL,
    question_type ENUM('multiple_choice', 'translation', 'reading') NOT NULL,
    question_text_en TEXT NOT NULL,
    question_text_vi TEXT NOT NULL,
    romaji VARCHAR(100),
    correct_answer VARCHAR(100) NOT NULL,
    option_a VARCHAR(100),
    option_b VARCHAR(100),
    option_c VARCHAR(100),
    option_d VARCHAR(100),
    explanation_en TEXT,
    explanation_vi TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- USER LESSON PROGRESS
-- Track user progress through structured lessons
-- ============================================================

CREATE TABLE user_lesson_progress (
    user_id INT NOT NULL,
    lesson_id INT NOT NULL,
    is_completed TINYINT(1) NOT NULL DEFAULT 0,
    is_unlocked TINYINT(1) NOT NULL DEFAULT 0,
    completed_at DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, lesson_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- USER QUIZ ATTEMPTS
-- Track quiz attempts for structured lessons
-- ============================================================

CREATE TABLE user_quiz_attempts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    lesson_id INT NOT NULL,
    question_id INT NOT NULL,
    selected_answer VARCHAR(100),
    is_correct TINYINT(1) NOT NULL,
    response_time_ms INT,
    attempt_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES quiz_questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- LESSONS
-- User-created lesson/quiz content
-- ============================================================

CREATE TABLE IF NOT EXISTS lessons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(190) NOT NULL,
    content TEXT NOT NULL,
    is_public TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS lesson_questions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NOT NULL,
    question_text TEXT NOT NULL,
    option_a VARCHAR(255) NOT NULL,
    option_b VARCHAR(255) NOT NULL,
    option_c VARCHAR(255) NOT NULL,
    option_d VARCHAR(255) NOT NULL,
    correct_option ENUM('a','b','c','d') NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- CHARACTERS
-- Stores all hiragana and katakana characters
-- ============================================================

CREATE TABLE characters (

    id INT AUTO_INCREMENT PRIMARY KEY,

    kana VARCHAR(5) NOT NULL,        -- renamed from `character`
    romaji VARCHAR(10) NOT NULL,

    type ENUM('hiragana','katakana') NOT NULL,

    group_name VARCHAR(20),

    difficulty INT NOT NULL DEFAULT 1

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- ATTEMPTS
-- Every single answer recorded here for analytics
-- ============================================================

CREATE TABLE attempts (

    id BIGINT AUTO_INCREMENT PRIMARY KEY,

    user_id INT NOT NULL,
    character_id INT NOT NULL,

    is_correct TINYINT(1) NOT NULL,

    response_time INT NOT NULL,          -- milliseconds
    mistake_streak INT NOT NULL DEFAULT 0,

    hour_of_day TINYINT NOT NULL,        -- 0–23

    session_id VARCHAR(36),

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,

    INDEX idx_user_char (user_id, character_id),
    INDEX idx_user_time (user_id, created_at),
    INDEX idx_hour (user_id, hour_of_day)

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- PERFORMANCE_STATS
-- One row per user+character — updated after every attempt
-- ============================================================

CREATE TABLE performance_stats (

    user_id INT NOT NULL,
    character_id INT NOT NULL,

    weakness_score FLOAT NOT NULL DEFAULT 0,

    difficulty_class ENUM('strong','medium','weak')
    NOT NULL DEFAULT 'medium',

    correct_count INT NOT NULL DEFAULT 0,
    wrong_count INT NOT NULL DEFAULT 0,

    avg_response_ms INT NOT NULL DEFAULT 0,

    mistake_streak INT NOT NULL DEFAULT 0,

    last_reviewed DATETIME,
    next_review DATETIME,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, character_id),

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,

    INDEX idx_next_review (user_id, next_review),
    INDEX idx_weakness (user_id, weakness_score)

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- TIME_OF_DAY_STATS
-- Aggregated per-user per-hour-slot performance
-- ============================================================

CREATE TABLE time_of_day_stats (

    user_id INT NOT NULL,

    hour_slot TINYINT NOT NULL,

    total_attempts INT NOT NULL DEFAULT 0,
    correct_count INT NOT NULL DEFAULT 0,

    avg_response_ms INT NOT NULL DEFAULT 0,

    accuracy_rate FLOAT NOT NULL DEFAULT 0,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, hour_slot),

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- SEED — Hiragana
-- ============================================================

INSERT INTO characters (kana, romaji, type, group_name, difficulty) VALUES
('あ','a','hiragana','vowels',1),
('い','i','hiragana','vowels',1),
('う','u','hiragana','vowels',1),
('え','e','hiragana','vowels',1),
('お','o','hiragana','vowels',1),

('か','ka','hiragana','k-row',1),
('き','ki','hiragana','k-row',1),
('く','ku','hiragana','k-row',1),
('け','ke','hiragana','k-row',1),
('こ','ko','hiragana','k-row',1),

('さ','sa','hiragana','s-row',2),
('し','shi','hiragana','s-row',2),
('す','su','hiragana','s-row',2),
('せ','se','hiragana','s-row',2),
('そ','so','hiragana','s-row',2),

('た','ta','hiragana','t-row',2),
('ち','chi','hiragana','t-row',2),
('つ','tsu','hiragana','t-row',2),
('て','te','hiragana','t-row',2),
('と','to','hiragana','t-row',2),

('な','na','hiragana','n-row',2),
('に','ni','hiragana','n-row',2),
('ぬ','nu','hiragana','n-row',2),
('ね','ne','hiragana','n-row',2),
('の','no','hiragana','n-row',2),

('は','ha','hiragana','h-row',3),
('ひ','hi','hiragana','h-row',3),
('ふ','fu','hiragana','h-row',3),
('へ','he','hiragana','h-row',3),
('ほ','ho','hiragana','h-row',3),

('ま','ma','hiragana','m-row',3),
('み','mi','hiragana','m-row',3),
('む','mu','hiragana','m-row',3),
('め','me','hiragana','m-row',3),
('も','mo','hiragana','m-row',3),

('や','ya','hiragana','y-row',3),
('ゆ','yu','hiragana','y-row',3),
('よ','yo','hiragana','y-row',3),

('ら','ra','hiragana','r-row',4),
('り','ri','hiragana','r-row',4),
('る','ru','hiragana','r-row',4),
('れ','re','hiragana','r-row',4),
('ろ','ro','hiragana','r-row',4),

('わ','wa','hiragana','w-row',3),
('を','wo','hiragana','w-row',4),
('ん','n','hiragana','n-solo',3);

-- ============================================================
-- SEED — Katakana
-- ============================================================

INSERT INTO characters (kana, romaji, type, group_name, difficulty) VALUES
('ア','a','katakana','vowels',2),
('イ','i','katakana','vowels',2),
('ウ','u','katakana','vowels',2),
('エ','e','katakana','vowels',2),
('オ','o','katakana','vowels',2),

('カ','ka','katakana','k-row',2),
('キ','ki','katakana','k-row',2),
('ク','ku','katakana','k-row',2),
('ケ','ke','katakana','k-row',2),
('コ','ko','katakana','k-row',2),

('サ','sa','katakana','s-row',3),
('シ','shi','katakana','s-row',3),
('ス','su','katakana','s-row',3),
('セ','se','katakana','s-row',3),
('ソ','so','katakana','s-row',3),

('タ','ta','katakana','t-row',3),
('チ','chi','katakana','t-row',3),
('ツ','tsu','katakana','t-row',3),
('テ','te','katakana','t-row',3),
('ト','to','katakana','t-row',3),

('ナ','na','katakana','n-row',3),
('ニ','ni','katakana','n-row',3),
('ヌ','nu','katakana','n-row',3),
('ネ','ne','katakana','n-row',3),
('ノ','no','katakana','n-row',3),

('ハ','ha','katakana','h-row',3),
('ヒ','hi','katakana','h-row',3),
('フ','fu','katakana','h-row',3),
('ヘ','he','katakana','h-row',3),
('ホ','ho','katakana','h-row',3),

('マ','ma','katakana','m-row',4),
('ミ','mi','katakana','m-row',4),
('ム','mu','katakana','m-row',4),
('メ','me','katakana','m-row',4),
('モ','mo','katakana','m-row',4),

('ヤ','ya','katakana','y-row',3),
('ユ','yu','katakana','y-row',3),
('ヨ','yo','katakana','y-row',3),

('ラ','ra','katakana','r-row',4),
('リ','ri','katakana','r-row',4),
('ル','ru','katakana','r-row',4),
('レ','re','katakana','r-row',4),
('ロ','ro','katakana','r-row',4),

('ワ','wa','katakana','w-row',4),
('ヲ','wo','katakana','w-row',5),
('ン','n','katakana','n-solo',4);

-- ============================================================
-- SEED — Structured Lessons System
-- ============================================================

-- Chapters
INSERT INTO chapters (title_en, title_vi, description_en, description_vi, order_index) VALUES
('Learning Japanese', 'Học Tiếng Nhật', 'Master the fundamentals of Japanese language', 'Nắm vững nền tảng ngôn ngữ tiếng Nhật', 1);

-- Sections
INSERT INTO sections (chapter_id, title_en, title_vi, description_en, description_vi, order_index) VALUES
(1, 'Alphabet', 'Bảng Chữ Cái', 'Learn Hiragana, Katakana, and Kanji basics', 'Học Hiragana, Katakana và cơ bản về Kanji', 1);

-- Lesson 1: Introduction to Japanese Writing Systems
INSERT INTO structured_lessons (section_id, lesson_number, title_en, title_vi, content_en, content_vi, type, prerequisites, unlocks) VALUES
(1, 1, 'Introduction to Japanese Writing Systems', 'Giới Thiệu Về Các Hệ Thống Chữ Viết Tiếng Nhật',
'<h2>Japanese Writing Systems</h2>
<p>Japanese uses three main writing systems: Hiragana, Katakana, and Kanji. Each serves different purposes and together they form the foundation of written Japanese.</p>

<h3>Hiragana (ひらがな)</h3>
<p>Hiragana is the most basic Japanese script and is used for:</p>
<ul>
<li>Native Japanese words</li>
<li>Grammar particles</li>
<li>Inflection endings</li>
<li>Words where kanji is unknown or too complex</li>
</ul>
<p>Hiragana represents syllables and is essential for reading and writing Japanese.</p>

<h3>Katakana (カタカナ)</h3>
<p>Katakana is used primarily for:</p>
<ul>
<li>Foreign loanwords</li>
<li>Onomatopoeic words</li>
<li>Scientific terms</li>
<li>Emphasis</li>
<li>Foreign names</li>
</ul>
<p>Katakana characters are more angular and are often used for foreign words adapted into Japanese.</p>

<h3>Kanji (漢字)</h3>
<p>Kanji are Chinese characters adopted into Japanese and are used for:</p>
<ul>
<li>Most nouns</li>
<li>Verb and adjective stems</li>
<li>Names</li>
<li>Formal writing</li>
</ul>
<p>Kanji can have multiple readings and meanings, making them complex but powerful.</p>

<h3>Practical Applications</h3>
<p>In modern Japanese:</p>
<ul>
<li><strong>Hiragana</strong>: Used in children\'s books, informal writing, and particles</li>
<li><strong>Katakana</strong>: Used in manga for sound effects, menus, advertisements</li>
<li><strong>Kanji</strong>: Used in newspapers, formal documents, literature</li>
</ul>

<p>Most Japanese text combines all three systems. Learning Hiragana first is crucial as it\'s needed to read the other systems properly.</p>',
'<h2>Các Hệ Thống Chữ Viết Tiếng Nhật</h2>
<p>Tiếng Nhật sử dụng ba hệ thống chữ viết chính: Hiragana, Katakana và Kanji. Mỗi hệ thống phục vụ mục đích khác nhau và cùng nhau tạo thành nền tảng của văn bản tiếng Nhật.</p>

<h3>Hiragana (ひらがな)</h3>
<p>Hiragana là hệ thống chữ viết cơ bản nhất của tiếng Nhật và được sử dụng cho:</p>
<ul>
<li>Từ ngữ thuần Nhật</li>
<li>Các hạt ngữ pháp</li>
<li>Phần kết thúc của từ biến cách</li>
<li>Các từ mà kanji không biết hoặc quá phức tạp</li>
</ul>
<p>Hiragana biểu diễn âm tiết và rất cần thiết để đọc và viết tiếng Nhật.</p>

<h3>Katakana (カタカナ)</h3>
<p>Katakana chủ yếu được sử dụng cho:</p>
<ul>
<li>Từ mượn nước ngoài</li>
<li>Từ tượng thanh</li>
<li>Thuật ngữ khoa học</li>
<li>Nhấn mạnh</li>
<li>Tên nước ngoài</li>
</ul>
<p>Các ký tự Katakana có hình dạng góc cạnh hơn và thường được sử dụng cho các từ nước ngoài được chuyển thể sang tiếng Nhật.</p>

<h3>Kanji (漢字)</h3>
<p>Kanji là các ký tự Trung Quốc được tiếp nhận vào tiếng Nhật và được sử dụng cho:</p>
<ul>
<li>Hầu hết các danh từ</li>
<li>Thân của động từ và tính từ</li>
<li>Tên riêng</li>
<li>Văn viết trang trọng</li>
</ul>
<p>Kanji có thể có nhiều cách đọc và nghĩa, khiến chúng phức tạp nhưng mạnh mẽ.</p>

<h3>Ứng Dụng Thực Tế</h3>
<p>Trong tiếng Nhật hiện đại:</p>
<ul>
<li><strong>Hiragana</strong>: Được sử dụng trong sách thiếu nhi, văn viết thông tục và các hạt ngữ</li>
<li><strong>Katakana</strong>: Được sử dụng trong manga cho hiệu ứng âm thanh, thực đơn, quảng cáo</li>
<li><strong>Kanji</strong>: Được sử dụng trong báo chí, tài liệu trang trọng, văn học</li>
</ul>

<p>Hầu hết văn bản tiếng Nhật kết hợp cả ba hệ thống. Việc học Hiragana trước tiên là rất quan trọng vì nó cần thiết để đọc đúng các hệ thống khác.</p>',
'reading', '[]', '[2]');

-- Lesson 2-12: Alphabet Lessons
INSERT INTO structured_lessons (section_id, lesson_number, title_en, title_vi, content_en, content_vi, type, script_type, prerequisites, unlocks) VALUES
(1, 2, 'Vowel Row (あ-お)', 'Hàng Nguyên Âm (あ-お)', '<h2>The Vowel Row</h2><p>Learn the five basic vowels: あ (a), い (i), う (u), え (e), お (o)</p><p>These form the foundation of all Japanese syllables.</p>', '<h2>Hàng Nguyên Âm</h2><p>Học năm nguyên âm cơ bản: あ (a), い (i), う (u), え (e), お (o)</p><p>Những âm này tạo thành nền tảng của tất cả âm tiết tiếng Nhật.</p>', 'interactive', 'both', '[1]', '[3]'),
(1, 3, 'K-Row (か-こ)', 'Hàng K (か-こ)', '<h2>The K-Row</h2><p>Learn ka, ki, ku, ke, ko with the か character.</p>', '<h2>Hàng K</h2><p>Học ka, ki, ku, ke, ko với ký tự か.</p>', 'interactive', 'both', '[2]', '[4]'),
(1, 4, 'S-Row (さ-そ)', 'Hàng S (さ-そ)', '<h2>The S-Row</h2><p>Learn sa, shi, su, se, so with the さ character.</p>', '<h2>Hàng S</h2><p>Học sa, shi, su, se, so với ký tự さ.</p>', 'interactive', 'both', '[3]', '[5]'),
(1, 5, 'T-Row (た-と)', 'Hàng T (た-と)', '<h2>The T-Row</h2><p>Learn ta, chi, tsu, te, to with the た character.</p>', '<h2>Hàng T</h2><p>Học ta, chi, tsu, te, to với ký tự た.</p>', 'interactive', 'both', '[4]', '[6]'),
(1, 6, 'N-Row (な-の)', 'Hàng N (な-の)', '<h2>The N-Row</h2><p>Learn na, ni, nu, ne, no with the な character.</p>', '<h2>Hàng N</h2><p>Học na, ni, nu, ne, no với ký tự な.</p>', 'interactive', 'both', '[5]', '[7]'),
(1, 7, 'H-Row (は-ほ)', 'Hàng H (は-ほ)', '<h2>The H-Row</h2><p>Learn ha, hi, fu, he, ho with the は character.</p>', '<h2>Hàng H</h2><p>Học ha, hi, fu, he, ho với ký tự は.</p>', 'interactive', 'both', '[6]', '[8]'),
(1, 8, 'M-Row (ま-も)', 'Hàng M (ま-も)', '<h2>The M-Row</h2><p>Learn ma, mi, mu, me, mo with the ま character.</p>', '<h2>Hàng M</h2><p>Học ma, mi, mu, me, mo với ký tự ま.</p>', 'interactive', 'both', '[7]', '[9]'),
(1, 9, 'Y-Row (や-よ)', 'Hàng Y (や-よ)', '<h2>The Y-Row</h2><p>Learn ya, yu, yo with the や character.</p>', '<h2>Hàng Y</h2><p>Học ya, yu, yo với ký tự や.</p>', 'interactive', 'both', '[8]', '[10]'),
(1, 10, 'R-Row (ら-ろ)', 'Hàng R (ら-ろ)', '<h2>The R-Row</h2><p>Learn ra, ri, ru, re, ro with the ら character.</p>', '<h2>Hàng R</h2><p>Học ra, ri, ru, re, ro với ký tự ら.</p>', 'interactive', 'both', '[9]', '[11]'),
(1, 11, 'W-Row & N (わ-ん)', 'Hàng W & N (わ-ん)', '<h2>The W-Row and N</h2><p>Learn wa, wo, and n (ん).</p>', '<h2>Hàng W và N</h2><p>Học wa, wo và n (ん).</p>', 'interactive', 'both', '[10]', '[12]'),
(1, 12, 'Comprehensive Review', 'Ôn Tập Toàn Diện', '<h2>Comprehensive Review</h2><p>Review all characters learned in Lessons 2-11.</p>', '<h2>Ôn Tập Toàn Diện</h2><p>Ôn tập tất cả các ký tự đã học trong Bài 2-11.</p>', 'review', 'both', '[11]', '[]');

-- Vocabulary for Lesson 2 (Vowels)
INSERT INTO vocabulary (lesson_id, romaji, hiragana, english_meaning, vietnamese_meaning, part_of_speech, example_sentence_en, example_sentence_vi) VALUES
(2, 'a', 'あ', 'ah (as in father)', 'a (như trong từ cha)', 'syllable', 'Say "a" clearly.', 'Nói "a" rõ ràng.'),
(2, 'i', 'い', 'ee (as in machine)', 'i (như trong máy)', 'syllable', 'Say "i" clearly.', 'Nói "i" rõ ràng.'),
(2, 'u', 'う', 'oo (as in too)', 'u (như trong quá)', 'syllable', 'Say "u" clearly.', 'Nói "u" rõ ràng.'),
(2, 'e', 'え', 'eh (as in bed)', 'e (như trong giường)', 'syllable', 'Say "e" clearly.', 'Nói "e" rõ ràng.'),
(2, 'o', 'お', 'oh (as in go)', 'o (như trong đi)', 'syllable', 'Say "o" clearly.', 'Nói "o" rõ ràng.'),
(2, 'atsui', 'あつい', 'hot', 'nóng', 'adjective', 'The tea is hot.', 'Trà rất nóng.'),
(2, 'iie', 'いいえ', 'no', 'không', 'adverb', 'No, thank you.', 'Không, cảm ơn.'),
(2, 'umi', 'うみ', 'sea', 'biển', 'noun', 'I love the sea.', 'Tôi yêu biển.'),
(2, 'ebi', 'えび', 'shrimp', 'tôm', 'noun', 'Shrimp is delicious.', 'Tôm rất ngon.'),
(2, 'omocha', 'おもちゃ', 'toy', 'đồ chơi', 'noun', 'This is a toy.', 'Đây là đồ chơi.');

-- Vocabulary for Lesson 3 (K-Row)
INSERT INTO vocabulary (lesson_id, romaji, hiragana, english_meaning, vietnamese_meaning, part_of_speech, example_sentence_en, example_sentence_vi) VALUES
(3, 'ka', 'か', 'ka sound', 'âm ka', 'syllable', 'Say "ka" clearly.', 'Nói "ka" rõ ràng.'),
(3, 'ki', 'き', 'ki sound', 'âm ki', 'syllable', 'Say "ki" clearly.', 'Nói "ki" rõ ràng.'),
(3, 'ku', 'く', 'ku sound', 'âm ku', 'syllable', 'Say "ku" clearly.', 'Nói "ku" rõ ràng.'),
(3, 'ke', 'け', 'ke sound', 'âm ke', 'syllable', 'Say "ke" clearly.', 'Nói "ke" rõ ràng.'),
(3, 'ko', 'こ', 'ko sound', 'âm ko', 'syllable', 'Say "ko" clearly.', 'Nói "ko" rõ ràng.'),
(3, 'kawaii', 'かわいい', 'cute', 'dễ thương', 'adjective', 'The cat is cute.', 'Con mèo rất dễ thương.'),
(3, 'kiku', 'きく', 'to listen', 'nghe', 'verb', 'I listen to music.', 'Tôi nghe nhạc.'),
(3, 'kumo', 'くも', 'cloud', 'đám mây', 'noun', 'The sky has clouds.', 'Bầu trời có mây.'),
(3, 'kesa', 'けさ', 'this morning', 'sáng nay', 'noun', 'I woke up this morning.', 'Tôi thức dậy sáng nay.'),
(3, 'koko', 'ここ', 'here', 'ở đây', 'noun', 'I am here.', 'Tôi ở đây.');

-- Sample Quiz Questions for Lesson 2 Review
INSERT INTO quiz_questions (lesson_id, question_type, question_text_en, question_text_vi, romaji, correct_answer, option_a, option_b, option_c, option_d, explanation_en, explanation_vi) VALUES
(2, 'multiple_choice', 'What is the hiragana for "a"?', 'Hiragana cho "a" là gì?', 'a', 'あ', 'あ', 'い', 'う', 'え', 'あ represents the "a" sound.', 'あ biểu diễn âm "a".'),
(2, 'multiple_choice', 'What is the hiragana for "i"?', 'Hiragana cho "i" là gì?', 'i', 'い', 'あ', 'い', 'う', 'え', 'い represents the "i" sound.', 'い biểu diễn âm "i".'),
(2, 'multiple_choice', 'What is the hiragana for "u"?', 'Hiragana cho "u" là gì?', 'u', 'う', 'あ', 'い', 'う', 'え', 'う represents the "u" sound.', 'う biểu diễn âm "u".'),
(2, 'multiple_choice', 'What is the hiragana for "e"?', 'Hiragana cho "e" là gì?', 'e', 'え', 'あ', 'い', 'う', 'え', 'え represents the "e" sound.', 'え biểu diễn âm "e".'),
(2, 'multiple_choice', 'What is the hiragana for "o"?', 'Hiragana cho "o" là gì?', 'o', 'お', 'あ', 'い', 'う', 'え', 'お represents the "o" sound.', 'お biểu diễn âm "o".');