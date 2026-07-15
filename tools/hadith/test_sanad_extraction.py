#!/usr/bin/env python3
"""Unit tests for Arabic sanad / rawi extraction.

Ensures transmission connectors (عن، قال، قالت، حدثنا, …) are never part of
extracted narrator names, and that the Prophet ﷺ cuts the chain.
"""

from __future__ import annotations

import gzip
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from hadith.hadith_meta import (  # noqa: E402
    _CONNECTOR_TOKENS,
    _clean_name_ar,
    _fold_ar,
    extract_ravi_chain,
)

CONNECTORS = set(_CONNECTOR_TOKENS)


def _assert_no_connectors(names: list[str], label: str = "") -> None:
    for name in names:
        folded = _fold_ar(name)
        bad = [t for t in folded.split() if t in CONNECTORS]
        if bad:
            raise AssertionError(
                f"{label}: connector(s) {bad} inside name {name!r} (chain={names})"
            )


class CleanNameTests(unittest.TestCase):
    def test_strip_leading_trailing_connectors(self) -> None:
        cases = {
            "أسماء عن": "أسماء",
            "قالت أسماء عن": "أسماء",
            "قَالَتْ أَسْمَاءُ عَنِ": "أسماء",
            "مالك عن": "مالك",
            "نافع عن": "نافع",
            "عن أبي هريرة": "أبي هريرة",
            "أبي هريرة قال": "أبي هريرة",
            "عائشة قالت": "عائشة",
            "حدثنا عبد الله بن يوسف": "عبد الله بن يوسف",
            "أخبرنا مالك": "مالك",
            "عبد الله بن يوسف": "عبد الله بن يوسف",
        }
        for raw, expected in cases.items():
            self.assertEqual(_clean_name_ar(raw), expected, msg=raw)


class UserExampleTests(unittest.TestCase):
    """Canonical examples from the bug report."""

    def test_example_1_bukhari_style(self) -> None:
        text = (
            "حدثنا عبد الله بن يوسف قال أخبرنا مالك عن نافع عن ابن عمر "
            "رضي الله عنهما أن رسول الله صلى الله عليه وسلم"
        )
        expected = ["عبد الله بن يوسف", "مالك", "نافع", "ابن عمر"]
        got = extract_ravi_chain(text)
        self.assertEqual(got, expected)
        _assert_no_connectors(got)

    def test_example_2_asma_aisha(self) -> None:
        text = "قالت أسماء عن عائشة رضي الله عنها قالت"
        expected = ["أسماء", "عائشة"]
        got = extract_ravi_chain(text)
        self.assertEqual(got, expected)
        _assert_no_connectors(got)

    def test_example_3_abu_hurayra(self) -> None:
        text = "عن أبي هريرة قال قال رسول الله صلى الله عليه وسلم"
        expected = ["أبي هريرة"]
        got = extract_ravi_chain(text)
        self.assertEqual(got, expected)
        _assert_no_connectors(got)

    def test_example_4_long_chain(self) -> None:
        text = (
            "حدثنا محمد بن المثنى قال حدثنا يحيى عن شعبة عن قتادة عن أنس "
            "رضي الله عنه قال"
        )
        expected = ["محمد بن المثنى", "يحيى", "شعبة", "قتادة", "أنس"]
        got = extract_ravi_chain(text)
        self.assertEqual(got, expected)
        _assert_no_connectors(got)

    def test_bukhari_7048_asma(self) -> None:
        text = (
            "حدثنا علي بن عبد الله، حدثنا بشر بن السري، حدثنا نافع بن عمر، "
            "عن ابن أبي مليكة، قال قالت أسماء عن النبي صلى الله عليه وسلم"
        )
        expected = [
            "علي بن عبد الله",
            "بشر بن السري",
            "نافع بن عمر",
            "ابن أبي مليكة",
            "أسماء",
        ]
        got = extract_ravi_chain(text)
        self.assertEqual(got, expected)
        _assert_no_connectors(got)
        self.assertNotIn("أسماء عن", got)
        self.assertFalse(any("عن" in n.split() for n in got))


class BookSampleTests(unittest.TestCase):
    """Real sanad samples from every supported collection in hadith.db."""

    # (book_slug, hadith_number, expected_names_subset_in_order)
    # expected is a prefix or exact chain of cleaned names that must appear.
    SAMPLES: list[tuple[str, int, list[str]]] = [
        # Sahih Bukhari
        (
            "bukhari",
            1,
            ["الحميدي عبد الله بن الزبير", "سفيان", "يحيى بن سعيد الأنصاري", "محمد بن إبراهيم التيمي", "علقمة بن وقاص الليثي"],
        ),
        (
            "bukhari",
            7048,
            ["علي بن عبد الله", "بشر بن السري", "نافع بن عمر", "ابن أبي مليكة", "أسماء"],
        ),
        # Sahih Muslim — typical حدثنا … عن …
        (
            "muslim",
            1,
            [],  # filled dynamically: just no-connector check
        ),
        # Abu Dawud / Tirmidhi / Nasa'i / Ibn Majah / Malik — connector hygiene
    ]

    @classmethod
    def setUpClass(cls) -> None:
        db_gz = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
        if not db_gz.exists():
            raise unittest.SkipTest("hadith.db.gz missing")
        tmp = tempfile.mkdtemp()
        db_path = Path(tmp) / "hadith.db"
        with gzip.open(db_gz, "rb") as f:
            db_path.write_bytes(f.read())
        cls.conn = sqlite3.connect(db_path)
        cls.conn.row_factory = sqlite3.Row
        cls.books = {
            r["slug"]: r["id"]
            for r in cls.conn.execute("SELECT id, slug FROM books")
        }

    def _text(self, slug: str, number: int) -> str:
        book_id = self.books[slug]
        row = self.conn.execute(
            "SELECT text_ar FROM hadiths WHERE book_id=? AND hadith_number=?",
            (book_id, number),
        ).fetchone()
        self.assertIsNotNone(row, f"{slug}#{number} missing")
        return row["text_ar"] or ""

    def test_bukhari_7048_from_db(self) -> None:
        if "bukhari" not in self.books:
            self.skipTest("bukhari not in DB")
        text = self._text("bukhari", 7048)
        got = extract_ravi_chain(text)
        _assert_no_connectors(got, "bukhari#7048")
        self.assertEqual(got[-1], "أسماء")
        self.assertIn("علي بن عبد الله", got)
        self.assertIn("ابن أبي مليكة", got)
        for n in got:
            self.assertNotRegex(n, r"(?:^|\s)(?:عن|قال|قالت)(?:\s|$)")

    def test_no_connectors_across_all_books(self) -> None:
        """Scan every hadith in every supported book for connector leakage."""
        leaks: list[str] = []
        totals: dict[str, tuple[int, int]] = {}
        for slug, book_id in sorted(self.books.items()):
            checked = 0
            bad = 0
            rows = self.conn.execute(
                "SELECT hadith_number, text_ar FROM hadiths WHERE book_id=? "
                "ORDER BY hadith_number",
                (book_id,),
            )
            for row in rows:
                ar = row["text_ar"] or ""
                if not ar.strip():
                    continue
                names = extract_ravi_chain(ar)
                checked += 1
                for name in names:
                    folded = _fold_ar(name)
                    bad_toks = [t for t in folded.split() if t in CONNECTORS]
                    if bad_toks:
                        bad += 1
                        if len(leaks) < 30:
                            leaks.append(
                                f"{slug}#{row['hadith_number']}: {name!r} has {bad_toks}"
                            )
                        break
            totals[slug] = (checked, bad)
        summary = ", ".join(f"{s}={c}/{b}" for s, (c, b) in totals.items())
        self.assertFalse(
            leaks,
            f"connector leakage (checked/leaks per book: {summary}):\n"
            + "\n".join(leaks),
        )
        # Ensure we actually scanned the expected collections.
        for expected in (
            "bukhari",
            "muslim",
            "abudawud",
            "tirmidhi",
            "nasai",
            "ibnmajah",
            "malik",
        ):
            if expected in self.books:
                self.assertGreater(totals[expected][0], 0, expected)

    def test_book_sample_chains(self) -> None:
        """Spot-check known chains from each available book (no connectors)."""
        # Pick first hadith with a non-empty Arabic text per book and verify hygiene.
        for slug, book_id in sorted(self.books.items()):
            row = self.conn.execute(
                "SELECT hadith_number, text_ar FROM hadiths "
                "WHERE book_id=? AND length(trim(text_ar))>20 "
                "ORDER BY hadith_number LIMIT 5",
                (book_id,),
            ).fetchall()
            self.assertTrue(row, slug)
            for r in row:
                names = extract_ravi_chain(r["text_ar"])
                _assert_no_connectors(names, f"{slug}#{r['hadith_number']}")
                # Prophet must never appear as a narrator.
                for n in names:
                    folded = _fold_ar(n)
                    self.assertNotRegex(
                        folded,
                        r"^(?:النبي|رسول\s*الله|محمد\s*صلى)",
                        msg=f"{slug}#{r['hadith_number']}: {n}",
                    )


class ProphetCutoffTests(unittest.TestCase):
    def test_stops_before_prophet(self) -> None:
        text = "حدثنا فلان عن النبي صلى الله عليه وسلم قال كذا وكذا عن عمر"
        got = extract_ravi_chain(text)
        self.assertEqual(got, ["فلان"])
        self.assertNotIn("عمر", got)

    def test_bare_muhammad_is_narrator(self) -> None:
        text = (
            "حدثنا عبد الله بن عبد الوهاب حدثنا حماد بن زيد عن أيوب عن محمد "
            "عن ابن أبي بكرة عن أبي بكرة رضي الله عنه عن النبي صلى الله عليه وسلم"
        )
        got = extract_ravi_chain(text)
        self.assertIn("محمد", got)
        self.assertIn("أبي بكرة", got)
        _assert_no_connectors(got)


if __name__ == "__main__":
    unittest.main()
