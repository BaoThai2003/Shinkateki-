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
 
CREATE TABLE characters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NOT NULL,
    romaji VARCHAR(50) NOT NULL,
    hiragana VARCHAR(10),
    katakana VARCHAR(10),
    kanji VARCHAR(10),
    stroke_order TEXT,
    mnemonic_vi TEXT,
    mnemonic_en TEXT,
    audio_url VARCHAR(500),
    group_name VARCHAR(50),
    position_in_group INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES structured_lessons(id) ON DELETE CASCADE,
    INDEX idx_romaji (romaji),
    INDEX idx_hiragana (hiragana),
    INDEX idx_katakana (katakana),
    INDEX idx_kanji (kanji)
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
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
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

-- ============================================================
-- SEED DATA
-- ============================================================
 
-- Seed data for modules
INSERT INTO modules (name_vi, name_en, description_vi, description_en, order_index) VALUES
('Bảng Chữ Cái', 'Alphabet', 'Học bảng chữ cái Hiragana và Katakana', 'Learn Hiragana and Katakana alphabets', 1);
 
-- Seed data for chapters
INSERT INTO chapters (module_id, chapter_number, title_vi, title_en, description_vi, description_en, order_index) VALUES
(1, 1, 'Chương 1: Nguyên Âm Cơ Bản', 'Chapter 1: Basic Vowels', 'Học 5 nguyên âm cơ bản: a, i, u, e, o', 'Learn the 5 basic vowels: a, i, u, e, o', 1),
(1, 2, 'Chương 2: K Góc', 'Chapter 2: K Row', 'Học hàng K: ka, ki, ku, ke, ko', 'Learn the K row: ka, ki, ku, ke, ko', 2),
(1, 3, 'Chương 3: S Góc', 'Chapter 3: S Row', 'Học hàng S: sa, shi, su, se, so', 'Learn the S row: sa, shi, su, se, so', 3),
(1, 4, 'Chương 4: T Góc', 'Chapter 4: T Row', 'Học hàng T: ta, chi, tsu, te, to', 'Learn the T row: ta, chi, tsu, te, to', 4);
 
-- Seed data for sections
INSERT INTO sections (chapter_id, section_number, title_vi, title_en, description_vi, description_en, order_index) VALUES
(1, 1, 'Nguyên Âm Cơ Bản', 'Basic Vowels', 'Giới thiệu 5 nguyên âm', 'Introduction to 5 vowels', 1),
(2, 1, 'Hàng K', 'K Row', 'Các chữ cái bắt đầu bằng K', 'Characters starting with K', 1),
(3, 1, 'Hàng S', 'S Row', 'Các chữ cái bắt đầu bằng S', 'Characters starting with S', 1),
(4, 1, 'Hàng T', 'T Row', 'Các chữ cái bắt đầu bằng T', 'Characters starting with T', 1);
 
-- Seed data for structured_lessons
INSERT INTO structured_lessons (section_id, lesson_number, title_vi, title_en, content_vi, content_en, lesson_type, order_index) VALUES
(1, 1, 'Nguyên Âm A I U E O', 'Vowels A I U E O', 'Học cách phát âm 5 nguyên âm cơ bản trong tiếng Nhật', 'Learn how to pronounce the 5 basic vowels in Japanese', 'character_learning', 1),
(2, 2, 'Hàng KA KI KU KE KO', 'KA KI KU KE KO Row', 'Học cách phát âm các chữ cái hàng K', 'Learn how to pronounce K-row characters', 'character_learning', 1),
(3, 3, 'Hàng SA SHI SU SE SO', 'SA SHI SU SE SO Row', 'Học cách phát âm các chữ cái hàng S', 'Learn how to pronounce S-row characters', 'character_learning', 1),
(4, 4, 'Hàng TA CHI TSU TE TO', 'TA CHI TSU TE TO Row', 'Học cách phát âm các chữ cái hàng T', 'Learn how to pronounce T-row characters', 'character_learning', 1),
(1, 5, 'Ôn Tập Nguyên Âm', 'Vowel Review Quiz', 'Kiểm tra kiến thức về nguyên âm', 'Test your knowledge of vowels', 'review', 2);
 
-- Seed data for characters
INSERT INTO characters (lesson_id, romaji, hiragana, katakana, kanji, group_name, position_in_group, mnemonic_vi, mnemonic_en) VALUES
(1, 'a', 'あ', 'ア', NULL, 'a', 1, 'A cơ bản', 'Basic A'),
(1, 'i', 'い', 'イ', NULL, 'i', 1, 'I như tiếng cười', 'I like laughing sound'),
(1, 'u', 'う', 'ウ', NULL, 'u', 1, 'U như oo', 'U like oo'),
(1, 'e', 'え', 'エ', NULL, 'e', 1, 'E như eh', 'E like eh'),
(1, 'o', 'お', 'オ', NULL, 'o', 1, 'O như oh', 'O like oh'),
(2, 'ka', 'か', 'カ', NULL, 'k', 1, 'K kết hợp với A', 'K combined with A'),
(2, 'ki', 'き', 'キ', NULL, 'k', 2, 'K kết hợp với I', 'K combined with I'),
(2, 'ku', 'く', 'ク', NULL, 'k', 3, 'K kết hợp với U', 'K combined with U'),
(2, 'ke', 'け', 'ケ', NULL, 'k', 4, 'K kết hợp với E', 'K combined with E'),
(2, 'ko', 'こ', 'コ', NULL, 'k', 5, 'K kết hợp với O', 'K combined with O'),
(3, 'sa', 'さ', 'サ', NULL, 's', 1, 'S kết hợp với A', 'S combined with A'),
(3, 'shi', 'し', 'シ', NULL, 's', 2, 'S kết hợp với I (phát âm shi)', 'S combined with I (pronounced shi)'),
(3, 'su', 'す', 'ス', NULL, 's', 3, 'S kết hợp với U', 'S combined with U'),
(3, 'se', 'せ', 'セ', NULL, 's', 4, 'S kết hợp với E', 'S combined with E'),
(3, 'so', 'そ', 'ソ', NULL, 's', 5, 'S kết hợp với O', 'S combined with O'),
(4, 'ta', 'た', 'タ', NULL, 't', 1, 'T kết hợp với A', 'T combined with A'),
(4, 'chi', 'ち', 'チ', NULL, 't', 2, 'T kết hợp với I (phát âm chi)', 'T combined with I (pronounced chi)'),
(4, 'tsu', 'つ', 'ツ', NULL, 't', 3, 'T kết hợp với U (phát âm tsu)', 'T combined with U (pronounced tsu)'),
(4, 'te', 'て', 'テ', NULL, 't', 4, 'T kết hợp với E', 'T combined with E'),
(4, 'to', 'と', 'ト', NULL, 't', 5, 'T kết hợp với O', 'T combined with O');
 
-- Vocabulary
INSERT INTO vocabulary (lesson_id, character_id, word_kanji, word_hiragana, word_katakana, romaji, meaning_vi, meaning_en, detailed_explanation_vi, detailed_explanation_en, part_of_speech, jlpt_level, difficulty_level, order_index) VALUES
(2, 1, NULL, 'あかい', NULL, 'akai', 'đỏ', 'red', 'Màu đỏ tươi, có thể dùng để miêu tả màu sắc của vật hoặc cảm xúc mạnh mẽ. Trong tiếng Nhật, từ này thường được dùng trong các cụm từ như "akai bara" (hoa hồng đỏ) hoặc "akai kao" (mặt đỏ vì xấu hổ).', 'Bright red color, can be used to describe object colors or strong emotions. In Japanese, this word is commonly used in phrases like "akai bara" (red rose) or "akai kao" (red face from embarrassment).', 'adjective', 'N5', 'beginner', 1),
(2, 1, NULL, 'あさ', NULL, 'asa', 'buổi sáng', 'morning', 'Thời điểm từ khi mặt trời mọc đến trưa. Trong văn hóa Nhật, "asa" thường đi kèm với các hoạt động hàng ngày như ăn sáng, đi làm.', 'Time from sunrise to noon. In Japanese culture, "asa" is often associated with daily activities like breakfast, going to work.', 'noun', 'N5', 'beginner', 2),
(2, 2, NULL, 'いい', NULL, 'ii', 'tốt', 'good', 'Có thể dùng để diễn tả sự hài lòng hoặc chất lượng tốt. "Ii" có thể là tính từ hoặc từ cảm thán.', 'Can express satisfaction or good quality. "Ii" can be an adjective or interjection.', 'adjective', 'N5', 'beginner', 3),
(2, 2, NULL, 'いぬ', NULL, 'inu', 'con chó', 'dog', 'Động vật nuôi phổ biến ở Nhật. Trong văn hóa Nhật, chó thường được nuôi làm thú cưng.', 'Common pet animal in Japan. In Japanese culture, dogs are often kept as pets.', 'noun', 'N5', 'beginner', 4),
(2, 3, NULL, 'うみ', NULL, 'umi', 'biển', 'sea', 'Thể nước mặn bao quanh đất liền. Nhật Bản là đảo quốc nên "umi" có ý nghĩa văn hóa sâu sắc.', 'Salty water body surrounding land. Japan is an island nation so "umi" has deep cultural significance.', 'noun', 'N5', 'beginner', 5),
(2, 4, NULL, 'えき', NULL, 'eki', 'nhà ga', 'station', 'Nơi tàu điện, xe buýt dừng đỗ. Các ga lớn như Tokyo Station là trung tâm giao thông quan trọng.', 'Place where trains, buses stop. Major stations like Tokyo Station are important transportation hubs.', 'noun', 'N5', 'beginner', 6),
(2, 5, NULL, 'おおきい', NULL, 'ookii', 'lớn', 'big', 'Miêu tả kích thước vật thể. "Ookii" là tính từ i-keiyoushi.', 'Describes object size. "Ookii" is an i-adjective.', 'adjective', 'N5', 'beginner', 7),
(3, 6, NULL, 'かさ', NULL, 'kasa', 'cái ô', 'umbrella', 'Dụng cụ dùng để che mưa hoặc nắng. Trong văn hóa Nhật, ô là vật dụng thiết yếu.', 'Tool used to shield from rain or sun. In Japanese culture, umbrellas are essential items.', 'noun', 'N5', 'beginner', 8),
(3, 7, NULL, 'きく', NULL, 'kiku', 'nghe', 'to listen', 'Hành động lắng nghe âm thanh. "Kiku" là động từ nhóm 1.', 'Action of listening to sound. "Kiku" is a group 1 verb.', 'verb', 'N5', 'beginner', 9),
(3, 8, NULL, 'くち', NULL, 'kuchi', 'miệng', 'mouth', 'Bộ phận cơ thể dùng để ăn uống và nói.', 'Body part used for eating and speaking.', 'noun', 'N5', 'beginner', 10),
(3, 9, NULL, 'けす', NULL, 'kesu', 'tắt', 'to turn off', 'Hành động làm tắt đèn, lửa, máy móc.', 'Action of turning off lights, fire, machines.', 'verb', 'N5', 'beginner', 11),
(3, 10, NULL, 'ここ', NULL, 'koko', 'ở đây', 'here', 'Chỉ vị trí gần người nói.', 'Indicates position near the speaker.', 'adverb', 'N5', 'beginner', 12),
(4, 11, NULL, 'さけ', NULL, 'sake', 'rượu', 'alcohol', 'Đồ uống có cồn truyền thống của Nhật.', 'Alcoholic beverage traditional to Japan.', 'noun', 'N5', 'beginner', 13),
(4, 12, NULL, 'しお', NULL, 'shio', 'muối', 'salt', 'Gia vị cơ bản trong ẩm thực Nhật.', 'Basic seasoning in Japanese cuisine.', 'noun', 'N5', 'beginner', 14),
(4, 13, NULL, 'すき', NULL, 'suki', 'thích', 'favorite', 'Tính từ chỉ sở thích.', 'Adjective indicating preference.', 'adjective', 'N5', 'beginner', 15),
(4, 14, NULL, 'せかい', NULL, 'sekai', 'thế giới', 'world', 'Toàn bộ hành tinh và nhân loại.', 'Entire planet and humanity.', 'noun', 'N5', 'beginner', 16),
(4, 15, NULL, 'そこ', NULL, 'soko', 'ở đó', 'there', 'Chỉ vị trí cách người nói một khoảng.', 'Indicates position at some distance from speaker.', 'adverb', 'N5', 'beginner', 17),
(5, 16, NULL, 'たこ', NULL, 'tako', 'bạch tuộc', 'octopus', 'Động vật biển có 8 xúc tu.', 'Sea creature with 8 tentacles.', 'noun', 'N5', 'beginner', 18),
(5, 17, NULL, 'ちかてつ', NULL, 'chikatetsu', 'tàu điện ngầm', 'subway', 'Phương tiện giao thông công cộng dưới lòng đất.', 'Underground public transportation.', 'noun', 'N5', 'beginner', 19),
(5, 18, NULL, 'つき', NULL, 'tsuki', 'mặt trăng', 'moon', 'Vật thể thiên thể.', 'Celestial body.', 'noun', 'N5', 'beginner', 20),
(5, 19, NULL, 'てがみ', NULL, 'tegami', 'lá thư', 'letter', 'Thư viết tay gửi qua bưu điện.', 'Handwritten letter sent by mail.', 'noun', 'N5', 'beginner', 21),
(5, 20, NULL, 'とけい', NULL, 'tokei', 'đồng hồ', 'clock/watch', 'Dụng cụ đo thời gian.', 'Time measuring device.', 'noun', 'N5', 'beginner', 22);
 
-- Examples
INSERT INTO examples (vocabulary_id, jp_sentence_hiragana, jp_sentence_kanji, jp_sentence_katakana, romaji_sentence, vi_meaning, en_meaning, grammar_note_vi, grammar_note_en, order_index) VALUES
(1, 'あかいりんごがすきです', '赤いリンゴが好きです', NULL, 'Akai ringo ga suki desu', 'Tôi thích táo đỏ', 'I like red apples', 'Cấu trúc: Tính từ + Danh từ + が + 好きです', 'Structure: Adjective + Noun + が + 好きです', 1),
(1, 'かおがあかくなりました', '顔が赤くなりました', NULL, 'Kao ga aka ni narimashita', 'Mặt tôi đỏ lên', 'My face turned red', 'Biểu thị sự thay đổi trạng thái', 'Indicates change of state', 2),
(2, 'あさごはんをたべます', '朝ご飯を食べます', NULL, 'Asa gohan o tabemasu', 'Tôi ăn sáng', 'I eat breakfast', 'Thời gian + を + Động từ', 'Time + を + Verb', 3),
(3, 'いいえいがですね', 'いい映画ですね', NULL, 'Ii eiga desu ne', 'Đó là bộ phim hay nhỉ', 'That is a good movie, isn\'t it?', 'Câu cảm thán + ですね', 'Exclamation + ですね', 4),
(4, 'いぬがかわいいです', '犬が可愛いです', NULL, 'Inu ga kawaii desu', 'Con chó dễ thương', 'The dog is cute', 'Danh từ + が + Tính từ', 'Noun + が + Adjective', 5),
(5, 'うみがきれいです', '海がきれいです', NULL, 'Umi ga kirei desu', 'Biển rất đẹp', 'The sea is beautiful', 'Miêu tả cảnh quan tự nhiên', 'Describes natural scenery', 6),
(6, 'えきでまっています', '駅で待っています', NULL, 'Eki de matte imasu', 'Tôi đang đợi ở ga', 'I am waiting at the station', 'Nơi chốn + で + Động từ tiếp diễn', 'Place + で + Continuous verb', 7),
(7, 'おおきいへやです', '大きい部屋です', NULL, 'Ookii heya desu', 'Đó là phòng lớn', 'That is a big room', 'Tính từ + Danh từ + です', 'Adjective + Noun + です', 8);
 
-- Quiz questions
INSERT INTO quiz_questions (lesson_id, question_type, question_vi, question_en, romaji, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, difficulty_level, points, order_index) VALUES
(2, 'multiple_choice', 'あ phát âm là gì?', 'How is あ pronounced?', 'a', '["a", "i", "u", "e"]', '["a", "i", "u", "e"]', 'a', 'a', 'あ là nguyên âm a cơ bản', 'あ is the basic vowel a', 'easy', 1, 1),
(3, 'romaji_to_kana', 'ka là hiragana nào?', 'What hiragana is ka?', 'ka', '["か", "き", "く", "け"]', '["か", "き", "く", "け"]', 'か', 'か', 'か là sự kết hợp của k và a', 'か is the combination of k and a', 'easy', 1, 2),
(4, 'kana_to_meaning', 'し nghĩa là gì?', 'What does し mean?', 'shi', '["sa", "shi", "su", "se"]', '["sa", "shi", "su", "se"]', 'shi', 'shi', 'し phát âm là shi, không phải si', 'し is pronounced shi, not si', 'easy', 1, 3),
(5, 'multiple_choice', 'つ phát âm là gì?', 'How is つ pronounced?', 'tsu', '["ta", "chi", "tsu", "te"]', '["ta", "chi", "tsu", "te"]', 'tsu', 'tsu', 'つ là âm tsu đặc trưng của tiếng Nhật', 'つ is the distinctive tsu sound in Japanese', 'easy', 1, 4);
 
-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Fuzzy search function
DELIMITER //
CREATE FUNCTION fuzzy_match(search_term VARCHAR(255), target_term VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    RETURN SOUNDEX(search_term) = SOUNDEX(target_term)
           OR target_term LIKE CONCAT('%', search_term, '%')
           OR search_term LIKE CONCAT('%', target_term, '%');
END //
DELIMITER ;
 
-- Trigger cleanup search history
DELIMITER //
CREATE TRIGGER cleanup_search_history
AFTER INSERT ON search_history
FOR EACH ROW
BEGIN
    DELETE FROM search_history
    WHERE user_id = NEW.user_id
    AND id NOT IN (
        SELECT id FROM (
            SELECT id FROM search_history
            WHERE user_id = NEW.user_id
            ORDER BY searched_at DESC
            LIMIT 1000
        ) AS temp
    );
END //
DELIMITER ;