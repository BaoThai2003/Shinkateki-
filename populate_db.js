// populate_db.js - Populate database with essential data
const mysql = require("mysql2/promise");
require("dotenv").config();

async function populateDatabase() {
  let connection;

  try {
    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      charset: "utf8mb4",
    });

    console.log("Connected to database");

    // Clear existing data
    await connection.execute("SET FOREIGN_KEY_CHECKS = 0");
    await connection.execute("TRUNCATE TABLE quiz_questions");
    await connection.execute("TRUNCATE TABLE vocabulary");
    await connection.execute("TRUNCATE TABLE structured_lessons");
    await connection.execute("TRUNCATE TABLE sections");
    await connection.execute("TRUNCATE TABLE chapters");
    await connection.execute("TRUNCATE TABLE characters");
    await connection.execute("SET FOREIGN_KEY_CHECKS = 1");

    console.log("Cleared existing data");

    // Insert chapter
    await connection.execute(
      "INSERT INTO chapters (chapter_number, title_vi, title_en, description_vi, description_en, order_index) VALUES (?, ?, ?, ?, ?, ?)",
      [
        1,
        "Chương 1: Bảng Chữ Cái",
        "Chapter 1: The Alphabet",
        "Học bảng chữ cái Hiragana và Katakana",
        "Learn Hiragana and Katakana alphabets",
        1,
      ]
    );
    console.log("Chapter inserted");

    // Insert sections
    await connection.execute(
      "INSERT INTO sections (chapter_id, section_number, title_vi, title_en, description_vi, description_en, order_index, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      [
        1,
        1,
        "Phần 1: Hiragana Cơ Bản",
        "Section 1: Basic Hiragana",
        "Học 46 chữ cái Hiragana cơ bản",
        "Learn the 46 basic Hiragana characters",
        1,
        true,
      ]
    );

    await connection.execute(
      "INSERT INTO sections (chapter_id, section_number, title_vi, title_en, description_vi, description_en, order_index, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      [
        1,
        2,
        "Phần 2: Katakana Cơ Bản",
        "Section 2: Basic Katakana",
        "Học 46 chữ cái Katakana cơ bản",
        "Learn the 46 basic Katakana characters",
        2,
        true,
      ]
    );

    await connection.execute(
      "INSERT INTO sections (chapter_id, section_number, title_vi, title_en, description_vi, description_en, order_index, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      [
        1,
        3,
        "Phần 3: Ôn Tập và Kiểm Tra",
        "Section 3: Review and Testing",
        "Ôn tập và kiểm tra kiến thức",
        "Review and test your knowledge",
        3,
        true,
      ]
    );
    console.log("Sections inserted");

    // Insert some basic lessons
    const lessons = [
      [
        1,
        1,
        "Bài 1: Nguyên Âm (あ い う え お)",
        "Lesson 1: Vowels (あ い う え お)",
        "<h2>Nguyên Âm Cơ Bản</h2><p>Học 5 nguyên âm đầu tiên trong tiếng Nhật:</p><ul><li>あ (a)</li><li>い (i)</li><li>う (u)</li><li>え (e)</li><li>お (o)</li></ul>",
        "<h2>Basic Vowels</h2><p>Learn the first 5 vowels in Japanese:</p><ul><li>あ (a)</li><li>い (i)</li><li>う (u)</li><li>え (e)</li><li>お (o)</li></ul>",
        "instruction",
        1,
        true,
        null,
        0.75,
      ],
      [
        1,
        2,
        "Bài 2: Nhóm K (か き く け こ)",
        "Lesson 2: K Group (か き く け こ)",
        "<h2>Nhóm K</h2><p>Kết hợp âm K với 5 nguyên âm:</p><ul><li>か (ka)</li><li>き (ki)</li><li>く (ku)</li><li>け (ke)</li><li>こ (ko)</li></ul>",
        "<h2>K Group</h2><p>Combine K sound with 5 vowels:</p><ul><li>か (ka)</li><li>き (ki)</li><li>く (ku)</li><li>け (ke)</li><li>こ (ko)</li></ul>",
        "instruction",
        2,
        true,
        null,
        0.75,
      ],
      [
        1,
        3,
        "Bài 3: Nhóm S (さ し す せ そ)",
        "Lesson 3: S Group (さ し す せ そ)",
        "<h2>Nhóm S</h2><p>Kết hợp âm S với 5 nguyên âm:</p><ul><li>さ (sa)</li><li>し (shi)</li><li>す (su)</li><li>せ (se)</li><li>そ (so)</li></ul>",
        "<h2>S Group</h2><p>Combine S sound with 5 vowels:</p><ul><li>さ (sa)</li><li>し (shi)</li><li>す (su)</li><li>せ (se)</li><li>そ (so)</li></ul>",
        "instruction",
        3,
        true,
        null,
        0.75,
      ],
      [
        1,
        4,
        "Bài 4: Nhóm T (た ち つ て と)",
        "Lesson 4: T Group (た ち つ て と)",
        "<h2>Nhóm T</h2><p>Kết hợp âm T với 5 nguyên âm:</p><ul><li>た (ta)</li><li>ち (chi)</li><li>つ (tsu)</li><li>て (te)</li><li>と (to)</li></ul>",
        "<h2>T Group</h2><p>Combine T sound with 5 vowels:</p><ul><li>た (ta)</li><li>ち (chi)</li><li>つ (tsu)</li><li>て (te)</li><li>と (to)</li></ul>",
        "instruction",
        4,
        true,
        null,
        0.75,
      ],
      [
        1,
        5,
        "Bài 5: Nhóm N (な に ぬ ね の)",
        "Lesson 5: N Group (な に ぬ ね の)",
        "<h2>Nhóm N</h2><p>Kết hợp âm N với 5 nguyên âm:</p><ul><li>な (na)</li><li>に (ni)</li><li>ぬ (nu)</li><li>ね (ne)</li><li>の (no)</li></ul>",
        "<h2>N Group</h2><p>Combine N sound with 5 vowels:</p><ul><li>な (na)</li><li>に (ni)</li><li>ぬ (nu)</li><li>ね (ne)</li><li>の (no)</li></ul>",
        "instruction",
        5,
        true,
        null,
        0.75,
      ],
      [
        1,
        6,
        "Bài 6: Nhóm H (は ひ ふ へ ほ)",
        "Lesson 6: H Group (は ひ ふ へ ほ)",
        "<h2>Nhóm H</h2><p>Kết hợp âm H với 5 nguyên âm:</p><ul><li>は (ha)</li><li>ひ (hi)</li><li>ふ (fu)</li><li>へ (he)</li><li>ほ (ho)</li></ul>",
        "<h2>H Group</h2><p>Combine H sound with 5 vowels:</p><ul><li>は (ha)</li><li>ひ (hi)</li><li>ふ (fu)</li><li>へ (he)</li><li>ほ (ho)</li></ul>",
        "instruction",
        6,
        true,
        null,
        0.75,
      ],
      [
        1,
        7,
        "Bài 7: Nhóm M (ま み む め も)",
        "Lesson 7: M Group (ま み む め も)",
        "<h2>Nhóm M</h2><p>Kết hợp âm M với 5 nguyên âm:</p><ul><li>ま (ma)</li><li>み (mi)</li><li>む (mu)</li><li>め (me)</li><li>も (mo)</li></ul>",
        "<h2>M Group</h2><p>Combine M sound with 5 vowels:</p><ul><li>ま (ma)</li><li>み (mi)</li><li>む (mu)</li><li>め (me)</li><li>も (mo)</li></ul>",
        "instruction",
        7,
        true,
        null,
        0.75,
      ],
      [
        1,
        8,
        "Bài 8: Nhóm Y (や ゆ よ)",
        "Lesson 8: Y Group (や ゆ よ)",
        "<h2>Nhóm Y</h2><p>Nhóm Y chỉ có 3 chữ cái:</p><ul><li>や (ya)</li><li>ゆ (yu)</li><li>よ (yo)</li></ul>",
        "<h2>Y Group</h2><p>Y group has only 3 characters:</p><ul><li>や (ya)</li><li>ゆ (yu)</li><li>よ (yo)</li></ul>",
        "instruction",
        8,
        true,
        null,
        0.75,
      ],
      [
        1,
        9,
        "Bài 9: Nhóm R (ら り る れ ろ)",
        "Lesson 9: R Group (ら り る れ ろ)",
        "<h2>Nhóm R</h2><p>Kết hợp âm R với 5 nguyên âm:</p><ul><li>ら (ra)</li><li>り (ri)</li><li>る (ru)</li><li>れ (re)</li><li>ろ (ro)</li></ul>",
        "<h2>R Group</h2><p>Combine R sound with 5 vowels:</p><ul><li>ら (ra)</li><li>り (ri)</li><li>る (ru)</li><li>れ (re)</li><li>ろ (ro)</li></ul>",
        "instruction",
        9,
        true,
        null,
        0.75,
      ],
      [
        1,
        10,
        "Bài 10: Nhóm W và N Đặc Biệt (わ を ん)",
        "Lesson 10: W Group and Special N (わ を ん)",
        "<h2>Nhóm W và N Đặc Biệt</h2><ul><li>わ (wa)</li><li>を (wo)</li><li>ん (n)</li></ul><p><strong>Hoàn thành Hiragana!</strong></p>",
        "<h2>W Group and Special N</h2><ul><li>わ (wa)</li><li>を (wo)</li><li>ん (n)</li></ul><p><strong>Hiragana Complete!</strong></p>",
        "instruction",
        10,
        true,
        null,
        0.75,
      ],
      [
        2,
        11,
        "Bài 11: Katakana Nguyên Âm (ア イ ウ エ オ)",
        "Lesson 11: Katakana Vowels (ア イ ウ エ オ)",
        "<h2>Katakana Nguyên Âm</h2><p>Học 5 nguyên âm Katakana:</p><ul><li>ア (a)</li><li>イ (i)</li><li>ウ (u)</li><li>エ (e)</li><li>オ (o)</li></ul>",
        "<h2>Katakana Vowels</h2><p>Learn 5 Katakana vowels:</p><ul><li>ア (a)</li><li>イ (i)</li><li>ウ (u)</li><li>エ (e)</li><li>オ (o)</li></ul>",
        "instruction",
        11,
        true,
        null,
        0.75,
      ],
      [
        2,
        12,
        "Bài 12: Katakana Nhóm K (カ キ ク ケ コ)",
        "Lesson 12: Katakana K Group (カ キ ク ケ コ)",
        "<h2>Katakana Nhóm K</h2><ul><li>カ (ka)</li><li>キ (ki)</li><li>ク (ku)</li><li>ケ (ke)</li><li>コ (ko)</li></ul>",
        "<h2>Katakana K Group</h2><ul><li>カ (ka)</li><li>キ (ki)</li><li>ク (ku)</li><li>ケ (ke)</li><li>コ (ko)</li></ul>",
        "instruction",
        12,
        true,
        null,
        0.75,
      ],
      [
        3,
        21,
        "Bài 21: Ôn Tập Hiragana",
        "Lesson 21: Hiragana Review",
        "<h2>Ôn Tập Hiragana</h2><p>Ôn tập tất cả 46 chữ cái Hiragana đã học.</p>",
        "<h2>Hiragana Review</h2><p>Review all 46 Hiragana characters learned.</p>",
        "practice",
        21,
        true,
        null,
        0.75,
      ],
      [
        3,
        24,
        "Bài 24: Kiểm Tra Ôn Tập Hiragana",
        "Lesson 24: Hiragana Review Quiz",
        "<h2>Kiểm Tra Hiragana</h2><p>Trả lời câu hỏi về Hiragana để mở khóa bài tiếp theo.</p>",
        "<h2>Hiragana Quiz</h2><p>Answer questions about Hiragana to unlock next lesson.</p>",
        "review_quiz",
        24,
        true,
        null,
        0.75,
      ],
      [
        3,
        28,
        "Bài 28: Kiểm Tra Cuối Chương",
        "Lesson 28: Final Chapter Quiz",
        "<h2>Kiểm Tra Cuối Chương</h2><p>Kiểm tra toàn bộ kiến thức về bảng chữ cái Nhật Bản.</p>",
        "<h2>Final Chapter Quiz</h2><p>Test all knowledge about Japanese alphabets.</p>",
        "final_quiz",
        28,
        true,
        null,
        0.75,
      ],
    ];

    for (const lesson of lessons) {
      await connection.execute(
        "INSERT INTO structured_lessons (section_id, lesson_number, title_vi, title_en, content_vi, content_en, lesson_type, order_index, is_active, prerequisite_lesson_id, unlock_threshold) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        lesson
      );
    }

    // Update prerequisites after all lessons are inserted
    await connection.execute(
      "UPDATE structured_lessons SET prerequisite_lesson_id = (SELECT id FROM (SELECT id FROM structured_lessons WHERE lesson_number = 24) AS temp) WHERE lesson_number = 28"
    );
    console.log("Lessons inserted");

    // Insert some basic vocabulary
    const vocab = [
      [1, "あ", "a", "あ", "nguyên âm a", "vowel a", "expression", 1],
      [1, "い", "i", "い", "nguyên âm i", "vowel i", "expression", 2],
      [1, "う", "u", "う", "nguyên âm u", "vowel u", "expression", 3],
      [1, "え", "e", "え", "nguyên âm e", "vowel e", "expression", 4],
      [1, "お", "o", "お", "nguyên âm o", "vowel o", "expression", 5],
      [
        13,
        "こんにちは",
        "konnichiwa",
        "こんにちは",
        "xin chào (ban ngày)",
        "hello (daytime)",
        "expression",
        1,
      ],
      [
        13,
        "ありがとう",
        "arigatou",
        "ありがとう",
        "cảm ơn",
        "thank you",
        "expression",
        2,
      ],
      [
        13,
        "すみません",
        "sumimasen",
        "すみません",
        "xin lỗi",
        "excuse me",
        "expression",
        3,
      ],
    ];

    for (const item of vocab) {
      await connection.execute(
        "INSERT INTO vocabulary (lesson_id, word, romaji, hiragana, meaning_vi, meaning_en, word_type, order_index) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        item
      );
    }
    console.log("Vocabulary inserted");

    // Insert some basic quiz questions
    const questions = [
      [
        14,
        "Chữ cái あ phát âm là gì?",
        "How is あ pronounced?",
        "multiple_choice",
        '["a", "i", "u", "e"]',
        '["a", "i", "u", "e"]',
        "a",
        "a",
        "あ là nguyên âm a",
        "あ is vowel a",
        1,
      ],
      [
        14,
        "Chữ cái か thuộc nhóm nào?",
        "Which group does か belong to?",
        "multiple_choice",
        '["K", "S", "T", "N"]',
        '["K", "S", "T", "N"]',
        "K",
        "K",
        "か thuộc nhóm K",
        "か belongs to K group",
        2,
      ],
      [
        14,
        "し phát âm là gì?",
        "How is し pronounced?",
        "multiple_choice",
        '["si", "shi", "su", "se"]',
        '["si", "shi", "su", "se"]',
        "shi",
        "shi",
        'し phát âm là "shi"',
        'し is pronounced "shi"',
        3,
      ],
      [
        15,
        "こんにちは nghĩa là gì?",
        "What does こんにちは mean?",
        "multiple_choice",
        '["Tạm biệt", "Xin chào", "Cảm ơn", "Xin lỗi"]',
        '["Goodbye", "Hello", "Thank you", "Sorry"]',
        "Xin chào",
        "Hello",
        'こんにちは nghĩa là "xin chào"',
        'こんにちは means "hello"',
        1,
      ],
    ];

    for (const question of questions) {
      await connection.execute(
        "INSERT INTO quiz_questions (lesson_id, question_vi, question_en, question_type, options_vi, options_en, correct_answer_vi, correct_answer_en, explanation_vi, explanation_en, order_index) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        question
      );
    }
    console.log("Quiz questions inserted");

    console.log("Database populated successfully!");
  } catch (error) {
    console.error("Error populating database:", error);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

populateDatabase();
