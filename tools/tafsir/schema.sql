-- ISLAM 307 — tafsir.db (multi-source, extensible)
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sources (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  name_ar TEXT,
  author TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS entries (
  id INTEGER PRIMARY KEY,
  source_id INTEGER NOT NULL,
  surah_number INTEGER NOT NULL,
  ayah_number INTEGER NOT NULL,
  text TEXT NOT NULL,
  FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE,
  UNIQUE (source_id, surah_number, ayah_number)
);

CREATE VIRTUAL TABLE IF NOT EXISTS tafsir_fts USING fts5(
  entry_id UNINDEXED,
  source_slug UNINDEXED,
  surah_number UNINDEXED,
  ayah_number UNINDEXED,
  text,
  search_blob,
  tokenize = 'unicode61 remove_diacritics 0'
);

CREATE INDEX IF NOT EXISTS idx_entries_surah ON entries(source_id, surah_number, ayah_number);
