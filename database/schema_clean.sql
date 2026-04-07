-- ============================================================
-- SHINKATEKI (進化的) — Adaptive Japanese Learning System
-- Database Schema and Seed Data
-- Version: 2.0.0
-- Language: Vietnamese (Default) with English Support
-- Curriculum: Chapter 1 (Alphabet) - Lessons 1-5 (seed mẫu)
-- Database: MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS shinkateki CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE shinkateki;

-- ============================================================
-- TABLE DEFINITIONS
-- ============================================================

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    language ENUM('vi', 'en') DEFAULT 'vi',
    level INT DEFAULT 1,
    total_score INT DEFAULT 0,
    streak_days INT DEFAULT 0,
    last_active TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE modules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name_vi VARCHAR(255) NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    description_vi TEXT,
    description_en TEXT,
    order_index INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE chapters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    module_id INT NOT NULL,
    chapter_number INT NOT NULL,
    title_vi VARCHAR(255) NOT NULL,
    title_en VARCHAR(255) NOT NULL,
    description_vi TEXT,
    description_en TEXT,
    order_index INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (module_id) REFERENCES modules(id) ON DELETE CASCADE,
    UNIQUE KEY unique_module_chapter (module_id, chapter_number)
);

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

CREATE TABLE structured_lessons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    section_id INT NOT NULL,
    lesson_number INT NOT NULL,
    title_vi VARCHAR(255) NOT NULL,
    title_en VARCHAR(255) NOT NULL,
    content_vi LONGTEXT NOT NULL,
    content_en LONGTEXT NOT NULL,
    lesson_type ENUM('introduction', 'character_learning', 'practice', 'review', 'final_quiz') NOT NULL,
    script_type ENUM('hiragana', 'katakana', 'kanji', 'both') DEFAULT 'both',
    order_index INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    prerequisite_lesson_id INT NULL,
    unlock_threshold DECIMAL(5,2) DEFAULT 0.75,
    unlocks JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE,
    FOREIGN KEY (prerequisite_lesson_id) REFERENCES structured_lessons(id) ON DELETE SET NULL,
    UNIQUE KEY unique_section_lesson (section_id, lesson_number)
);

CREATE TABLE performance_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    character_id INT NOT NULL,
    weakness_score INT DEFAULT 0,
    difficulty_class ENUM('strong', 'medium', 'weak') DEFAULT 'medium',
    mistake_streak INT DEFAULT 0,
    correct_count INT DEFAULT 0,
    incorrect_count INT DEFAULT 0,
    total_attempts INT DEFAULT 0,
    average_response_time_ms INT DEFAULT 0,
    last_attempt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    next_review TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    -- FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_character (user_id, character_id),
    INDEX idx_user_weakness (user_id, weakness_score),
    INDEX idx_next_review (next_review)
);

CREATE TABLE vocabulary (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NULL,
    character_id INT NULL,
    word_kanji VARCHAR(100),
    word_hiragana VARCHAR(100),
    word_katakana VARCHAR(100),
    romaji VARCHAR(100) NOT NULL,
    meaning_vi VARCHAR(255) NOT NULL,
    meaning_en VARCHAR(255) NOT NULL,
    detailed_explanation_vi LONGTEXT,
    detailed_explanation_en LONGTEXT,
    part_of_speech ENUM('noun', 'verb', 'adjective', 'adverb', 'particle', 'expression', 'conjunction') NOT NULL,
    jlpt_level ENUM('N5', 'N4', 'N3', 'N2', 'N1') DEFAULT 'N5',
    difficulty_level ENUM('beginner', 'intermediate', 'advanced') DEFAULT 'beginner',
    audio_url VARCHAR(500),
    order_index INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    -- FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE SET NULL,
    FULLTEXT INDEX ft_word_search (word_hiragana, word_katakana, romaji, word_kanji, meaning_vi, meaning_en),
    INDEX idx_romaji_vocab (romaji),
    INDEX idx_hiragana_vocab (word_hiragana),
    INDEX idx_katakana_vocab (word_katakana),
    INDEX idx_kanji_vocab (word_kanji)
);

CREATE TABLE examples (
    id INT AUTO_INCREMENT PRIMARY KEY,
    vocabulary_id INT NOT NULL,
    jp_sentence_hiragana TEXT NOT NULL,
    jp_sentence_kanji TEXT,
    jp_sentence_katakana TEXT,
    romaji_sentence TEXT NOT NULL,
    vi_meaning TEXT NOT NULL,
    en_meaning TEXT NOT NULL,
    grammar_note_vi TEXT,
    grammar_note_en TEXT,
    order_index INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vocabulary_id) REFERENCES vocabulary(id) ON DELETE CASCADE
);

CREATE TABLE quiz_questions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NOT NULL,
    question_type ENUM('multiple_choice', 'romaji_to_kana', 'kana_to_meaning', 'sentence_completion') NOT NULL,
    question_vi TEXT NOT NULL,
    question_en TEXT NOT NULL,
    romaji VARCHAR(100),
    options_vi JSON NOT NULL,
    options_en JSON NOT NULL,
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

CREATE TABLE user_progress (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    lesson_id INT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    score DECIMAL(5,2) NULL,
    time_spent INT DEFAULT 0,
    attempts INT DEFAULT 0,
    last_attempt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_unlocked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    -- FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_lesson (user_id, lesson_id)
);

CREATE TABLE search_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    search_term VARCHAR(255) NOT NULL,
    search_type ENUM('hiragana', 'katakana', 'kanji', 'romaji', 'meaning') NOT NULL,
    result_count INT DEFAULT 0,
    searched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_search_term (search_term),
    INDEX idx_user_search (user_id, searched_at)
);
