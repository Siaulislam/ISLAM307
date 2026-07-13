"""Permanent NarratorID registry with duplicate detection."""

from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path

from .normalize import match_key, normalize_display_ar


@dataclass
class NarratorRecord:
    id: int
    display_name_ar: str
    normalized_key: str


class NarratorRegistry:
    """
    Assigns stable integer NarratorIDs.
    Duplicate spellings (عبد الله / عبدالله) share one ID via normalized_key.
    """

    def __init__(self) -> None:
        self._by_key: dict[str, NarratorRecord] = {}
        self._by_id: dict[int, NarratorRecord] = {}
        self._next_id = 1

    def get_or_create(self, display_name_ar: str) -> NarratorRecord:
        display = normalize_display_ar(display_name_ar)
        if not display:
            raise ValueError("empty narrator name")
        key = match_key(display)
        existing = self._by_key.get(key)
        if existing:
            # Prefer longer authenticated display form when new spelling is richer.
            if len(display) > len(existing.display_name_ar):
                updated = NarratorRecord(existing.id, display, key)
                self._by_key[key] = updated
                self._by_id[existing.id] = updated
                return updated
            return existing
        rec = NarratorRecord(self._next_id, display, key)
        self._next_id += 1
        self._by_key[key] = rec
        self._by_id[rec.id] = rec
        return rec

    def get(self, narrator_id: int) -> NarratorRecord | None:
        return self._by_id.get(narrator_id)

    def lookup_key(self, raw: str) -> NarratorRecord | None:
        return self._by_key.get(match_key(raw))

    def __len__(self) -> int:
        return len(self._by_id)

    def all_records(self) -> list[NarratorRecord]:
        return [self._by_id[i] for i in sorted(self._by_id)]

    def to_json(self) -> list[dict]:
        return [
            {
                "id": r.id,
                "display_name_ar": r.display_name_ar,
                "normalized_key": r.normalized_key,
            }
            for r in self.all_records()
        ]

    def save_json(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_json(), ensure_ascii=False, indent=2), encoding="utf-8")

    def load_json(self, path: Path) -> None:
        rows = json.loads(path.read_text(encoding="utf-8"))
        self._by_key.clear()
        self._by_id.clear()
        max_id = 0
        for row in rows:
            rec = NarratorRecord(int(row["id"]), row["display_name_ar"], row["normalized_key"])
            self._by_key[rec.normalized_key] = rec
            self._by_id[rec.id] = rec
            max_id = max(max_id, rec.id)
        self._next_id = max_id + 1

    def export_sqlite(self, conn: sqlite3.Connection) -> None:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS narrators (
              id INTEGER PRIMARY KEY,
              display_name_ar TEXT NOT NULL,
              normalized_key TEXT NOT NULL UNIQUE
            );
            """
        )
        conn.execute("DELETE FROM narrators")
        conn.executemany(
            "INSERT INTO narrators(id, display_name_ar, normalized_key) VALUES (?,?,?)",
            [(r.id, r.display_name_ar, r.normalized_key) for r in self.all_records()],
        )
        conn.commit()
