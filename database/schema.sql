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

    level INT NOT NULL DEFAULT 1,
    total_score INT NOT NULL DEFAULT 0,
    streak_days INT NOT NULL DEFAULT 0,

    last_active DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4;

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