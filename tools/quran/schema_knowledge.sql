-- ISLAM 307 — Quran Knowledge System tables (Phase 4)
-- Morphology: Quranic Arabic Corpus v0.4 (GPL + attribution → http://corpus.quran.com)
-- Word glosses: Quran.com API word translations (EN/UR) with attribution
-- Arabic ayah text remains Tanzil Uthmani (BY-ND) — never modified

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS quran_words (
  id INTEGER PRIMARY KEY,
  surah INTEGER NOT NULL,
  ayah INTEGER NOT NULL,
  word_number INTEGER NOT NULL,
  text_ar TEXT NOT NULL,
  text_imlaei TEXT,
  transliteration TEXT,
  meaning_en TEXT,
  meaning_ur TEXT,
  root TEXT,
  lemma TEXT,
  pos TEXT,
  morphology TEXT,
  grammar_summary TEXT,
  syntax_summary TEXT,
  occurrence_count INTEGER NOT NULL DEFAULT 0,
  -- occurrence_surface / occurrence_lemma / occurrence_root added by
  -- tools/quran/import_wbw_gloss_languages.py (exact form / lemma / root counts).
  -- meaning_hi, meaning_bn, meaning_id, meaning_tr, meaning_fa added the same way
  -- from Quran.com authenticated word-by-word glosses (never English fallback).
  source TEXT NOT NULL DEFAULT 'qac+qurancom',
  UNIQUE (surah, ayah, word_number)
);

CREATE TABLE IF NOT EXISTS quran_word_parts (
  id INTEGER PRIMARY KEY,
  word_id INTEGER NOT NULL,
  part_index INTEGER NOT NULL,
  form_bw TEXT,
  tag TEXT,
  features TEXT NOT NULL,
  FOREIGN KEY (word_id) REFERENCES quran_words(id) ON DELETE CASCADE,
  UNIQUE (word_id, part_index)
);

CREATE INDEX IF NOT EXISTS idx_quran_words_ayah ON quran_words(surah, ayah);
CREATE INDEX IF NOT EXISTS idx_quran_words_root ON quran_words(root);
CREATE INDEX IF NOT EXISTS idx_quran_words_lemma ON quran_words(lemma);
CREATE INDEX IF NOT EXISTS idx_quran_words_pos ON quran_words(pos);
CREATE INDEX IF NOT EXISTS idx_quran_words_text ON quran_words(text_ar);

CREATE VIRTUAL TABLE IF NOT EXISTS quran_words_fts USING fts5(
  text_ar,
  meaning_en,
  meaning_ur,
  transliteration,
  root,
  lemma,
  pos,
  morphology,
  content='quran_words',
  content_rowid='id'
);
