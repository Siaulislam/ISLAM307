-- ISLAM 307 — hadith.db (offline, FTS5, authenticated sources only)
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS source_providers (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  website TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS books (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  hadith_count INTEGER NOT NULL DEFAULT 0,
  chapter_count INTEGER NOT NULL DEFAULT 0,
  source_provider TEXT NOT NULL,
  source_collection TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS chapters (
  id INTEGER PRIMARY KEY,
  book_id INTEGER NOT NULL,
  kitab_number TEXT,
  kitab_title_en TEXT,
  kitab_title_ar TEXT,
  number INTEGER NOT NULL,
  title_en TEXT NOT NULL,
  title_ar TEXT,
  hadith_start INTEGER,
  hadith_end INTEGER,
  FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
  UNIQUE (book_id, kitab_number, number)
);

CREATE TABLE IF NOT EXISTS hadiths (
  id INTEGER PRIMARY KEY,
  book_id INTEGER NOT NULL,
  chapter_id INTEGER,
  hadith_number INTEGER NOT NULL,
  kitab_number TEXT,
  kitab_title_en TEXT,
  bab_number TEXT,
  bab_title_en TEXT,
  bab_title_ar TEXT,
  text_ar TEXT NOT NULL,
  text_en TEXT,
  text_ur TEXT,
  narrator TEXT,
  reference_url TEXT NOT NULL,
  source_provider TEXT NOT NULL,
  arabic_urn INTEGER,
  english_urn INTEGER,
  FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
  FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE SET NULL,
  UNIQUE (book_id, hadith_number)
);

CREATE TABLE IF NOT EXISTS hadith_grades (
  id INTEGER PRIMARY KEY,
  hadith_id INTEGER NOT NULL,
  grade TEXT NOT NULL,
  graded_by TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  sort_order INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (hadith_id) REFERENCES hadiths(id) ON DELETE CASCADE
);

CREATE VIRTUAL TABLE IF NOT EXISTS hadith_fts USING fts5(
  hadith_id UNINDEXED,
  book_slug UNINDEXED,
  hadith_number UNINDEXED,
  text_ar,
  text_en,
  text_ur,
  narrator,
  grades_blob,
  search_blob,
  tokenize = 'unicode61 remove_diacritics 0'
);

CREATE INDEX IF NOT EXISTS idx_hadiths_book ON hadiths(book_id, hadith_number);
CREATE INDEX IF NOT EXISTS idx_hadiths_chapter ON hadiths(chapter_id);
CREATE INDEX IF NOT EXISTS idx_chapters_book ON chapters(book_id, number);
CREATE INDEX IF NOT EXISTS idx_grades_hadith ON hadith_grades(hadith_id, sort_order);
