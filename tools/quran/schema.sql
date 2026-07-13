-- ISLAM 307 — quran.db schema (offline reading engine)
-- Text source: Tanzil Project Uthmani v1.1 (verified, not OCR)
-- Metadata: Quran.com API v4 (page, juz, hizb, ruku, sajdah, tajweed)

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS surahs (
  id INTEGER PRIMARY KEY,
  number INTEGER NOT NULL UNIQUE,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_transliteration TEXT,
  revelation_place TEXT,
  ayah_count INTEGER NOT NULL,
  bismillah_pre INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS ayahs (
  id INTEGER PRIMARY KEY,
  global_number INTEGER NOT NULL UNIQUE,
  surah_number INTEGER NOT NULL,
  ayah_number INTEGER NOT NULL,
  text_uthmani TEXT NOT NULL,
  text_tajweed TEXT,
  translation_en TEXT,
  translation_ur TEXT,
  page_madani INTEGER NOT NULL,
  page_13_line INTEGER,
  juz INTEGER NOT NULL,
  hizb INTEGER NOT NULL,
  rub_el_hizb INTEGER,
  ruku INTEGER NOT NULL,
  manzil INTEGER,
  sajda_number INTEGER,
  has_sajda INTEGER NOT NULL DEFAULT 0,
  has_rub_el_hizb INTEGER NOT NULL DEFAULT 0,
  verified INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (surah_number) REFERENCES surahs(number),
  UNIQUE (surah_number, ayah_number)
);

CREATE TABLE IF NOT EXISTS pages_madani (
  page_number INTEGER PRIMARY KEY,
  juz INTEGER,
  start_surah INTEGER,
  start_ayah INTEGER,
  end_surah INTEGER,
  end_ayah INTEGER
);

CREATE TABLE IF NOT EXISTS pages_13_line (
  page_number INTEGER PRIMARY KEY,
  juz INTEGER,
  start_surah INTEGER,
  start_ayah INTEGER,
  end_surah INTEGER,
  end_ayah INTEGER,
  source TEXT DEFAULT 'pdf_import'
);

CREATE TABLE IF NOT EXISTS juz (
  number INTEGER PRIMARY KEY,
  name_ar TEXT,
  start_surah INTEGER NOT NULL,
  start_ayah INTEGER NOT NULL,
  end_surah INTEGER NOT NULL,
  end_ayah INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS ruku (
  number INTEGER PRIMARY KEY,
  surah_number INTEGER NOT NULL,
  start_ayah INTEGER NOT NULL,
  end_ayah INTEGER,
  juz INTEGER
);

CREATE TABLE IF NOT EXISTS sajdah (
  id INTEGER PRIMARY KEY,
  surah_number INTEGER NOT NULL,
  ayah_number INTEGER NOT NULL,
  sajda_type TEXT,
  UNIQUE (surah_number, ayah_number)
);

CREATE VIRTUAL TABLE IF NOT EXISTS ayah_fts USING fts5(
  ayah_id UNINDEXED,
  surah_number UNINDEXED,
  ayah_number UNINDEXED,
  text_uthmani,
  translation_en,
  search_blob,
  tokenize = 'unicode61 remove_diacritics 0'
);

CREATE INDEX IF NOT EXISTS idx_ayahs_surah ON ayahs(surah_number, ayah_number);
CREATE INDEX IF NOT EXISTS idx_ayahs_page_madani ON ayahs(page_madani);
CREATE INDEX IF NOT EXISTS idx_ayahs_page_13 ON ayahs(page_13_line);
CREATE INDEX IF NOT EXISTS idx_ayahs_juz ON ayahs(juz);
CREATE INDEX IF NOT EXISTS idx_ayahs_ruku ON ayahs(ruku);
