#!/usr/bin/env python3
"""Permanent regression tests for major Arabic Isnad patterns.

Covers Matn terminators, story characters, parallel chains, relatives,
and nested transmission verbs across Bukhari / Muslim / Sunan corpora.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "hadith"))

from isnad_engine.engine import parse_hadith_isnad  # noqa: E402
from isnad_engine.matn_guards import is_story_character  # noqa: E402
from isnad_engine.normalize import is_relative_token  # noqa: E402
from isnad_engine.split import cut_isnad_ar, split_parallel_isnads  # noqa: E402


def _names(ar: str, book: str = "bukhari") -> list[str]:
    return parse_hadith_isnad(ar, book_slug=book, hadith_number=1).primary_names


def _joined(names: list[str]) -> str:
    return " | ".join(names)


class MatnTerminatorEdgeCases(unittest.TestCase):
    """Patterns 1–20: these must always terminate the Sanad."""

    CASES = [
        (
            "قال رسول الله",
            "حدثنا قتيبة قال حدثنا الليث عن ابن شهاب عن أبي هريرة قال رسول الله صلى الله عليه وسلم إنما الأعمال",
            ["قتيبة", "الليث", "شهاب", "هريرة"],
            True,
        ),
        (
            "قام رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال قام رسول الله صلى الله عليه وسلم",
            ["بشار", "يحيى", "شعبة", "قتادة", "أنس"],
            True,
        ),
        (
            "خرج رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال خرج رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "دخل رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال دخل رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "كان رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال كان رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "بينما رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال بينما رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "بعث رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال بعث رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "أتى رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال أتى رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "جاء رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال جاء رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "خطب رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال خطب رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "صلى رسول الله",
            "حدثنا محمد بن بشار قال حدثنا يحيى قال حدثنا شعبة عن قتادة عن أنس قال صلى رسول الله صلى الله عليه وسلم",
            ["بشار", "شعبة", "أنس"],
            True,
        ),
        (
            "نهى رسول الله",
            "حدثنا قتيبة قال حدثنا الليث عن نافع عن ابن عمر قال نهى رسول الله صلى الله عليه وسلم",
            ["قتيبة", "الليث", "نافع", "عمر"],
            True,
        ),
        (
            "أمر رسول الله",
            "حدثنا قتيبة قال حدثنا الليث عن نافع عن ابن عمر قال أمر رسول الله صلى الله عليه وسلم",
            ["قتيبة", "الليث", "نافع", "عمر"],
            True,
        ),
        (
            "قال النبي",
            "حدثنا قتيبة قال حدثنا الليث عن أبي هريرة قال النبي صلى الله عليه وسلم",
            ["قتيبة", "الليث", "هريرة"],
            True,
        ),
        (
            "قال رسول الله ثم",
            "حدثنا قتيبة قال حدثنا الليث عن أبي هريرة قال رسول الله صلى الله عليه وسلم ثم قام",
            ["قتيبة", "الليث", "هريرة"],
            True,
        ),
        (
            "قال فقام",
            "حدثنا قتيبة قال حدثنا الليث عن أبي هريرة قال: فقام رسول الله صلى الله عليه وسلم",
            ["قتيبة", "الليث", "هريرة"],
            True,
        ),
        (
            "قالت خرج",
            "حدثتنا عائشة قالت: خرج رسول الله صلى الله عليه وسلم",
            ["عائشة"],
            True,
        ),
        (
            "بينما نحن",
            "حدثنا قتيبة قال حدثنا الليث عن أبي هريرة قال: بينما نحن عند رسول الله",
            ["قتيبة", "الليث", "هريرة"],
            False,
        ),
        (
            "قال إذا",
            "حدثنا قتيبة قال حدثنا الليث عن أبي هريرة قال: إذا مات الإنسان انقطع عمله",
            ["قتيبة", "الليث", "هريرة"],
            False,
        ),
        (
            "قال إن",
            "حدثنا قتيبة قال حدثنا الليث عن أبي هريرة قال: إن الله لا يظلم مثقال ذرة",
            ["قتيبة", "الليث", "هريرة"],
            False,
        ),
    ]

    FORBIDDEN_LEAKS = (
        "قام",
        "خرج",
        "دخل",
        "كان",
        "بينما",
        "بعث",
        "أتى",
        "اتي",
        "جاء",
        "خطب",
        "صلى",
        "صلي",
        "نهى",
        "نهي",
        "أمر",
        "امر",
        "فقام",
        "نحن",
        "إذا",
        "ان الله",
        "إن الله",
    )

    def test_all_terminators_cut_and_extract(self):
        for label, ar, need, want_prophet in self.CASES:
            with self.subTest(label=label):
                cut = cut_isnad_ar(ar)
                self.assertNotIn("قال رسول الله", cut, msg=cut)
                self.assertFalse(
                    any(
                        f"قال {v}" in cut or f"قال: {v}" in cut or f"قالت: {v}" in cut
                        for v in (
                            "قام",
                            "خرج",
                            "دخل",
                            "كان",
                            "بينما",
                            "بعث",
                            "أتى",
                            "جاء",
                            "خطب",
                            "صلى",
                            "نهى",
                            "أمر",
                            "فقام",
                            "إذا",
                            "إن",
                        )
                    ),
                    msg=f"matn leaked into cut: {cut}",
                )
                names = _names(ar)
                joined = _joined(names)
                for tok in need:
                    self.assertIn(tok, joined, msg=f"{label}: missing {tok} in {names}")
                for leak in self.FORBIDDEN_LEAKS:
                    self.assertFalse(
                        any(
                            n == leak
                            or n.startswith(leak + " ")
                            or n.startswith("قام ")
                            for n in names
                            if "رسول الله" not in n
                        ),
                        msg=f"{label}: leaked {leak} in {names}",
                    )
                # Bare الله from إن الله must never be a narrator
                self.assertFalse(any(n.strip() in ("الله", "إن الله", "ان الله") for n in names))
                if want_prophet:
                    self.assertTrue(
                        any("رسول الله" in n for n in names),
                        msg=f"{label}: expected Prophet node in {names}",
                    )


class StoryCharacterNeverNarrators(unittest.TestCase):
    STORY = [
        "هرقل",
        "كسرى",
        "النجاشي",
        "المقوقس",
        "أبو جهل",
        "أبو لهب",
        "أمية بن خلف",
        "عتبة بن ربيعة",
        "شيطان",
        "إبليس",
        "امرأة",
        "رجل",
        "قوم",
        "ناس",
    ]

    def test_blocklist_helper(self):
        for s in self.STORY:
            self.assertTrue(is_story_character(s), msg=s)

    def test_story_inside_matn_not_extracted(self):
        ar = (
            "حدثنا أبو اليمان قال أخبرنا شعيب عن الزهري قال أخبرني عبيد الله "
            "أن ابن عباس أخبره أن أبا سفيان أخبره أن هرقل أرسل إليه وأن كسرى كتب "
            "وأن النجاشي دعا وأن المقوقس أرسل وأن أبا جهل قال وأن أبا لهب قال "
            "وأن أمية بن خلف وأن عتبة بن ربيعة وأن شيطان وأن إبليس وأن امرأة قالت "
            "وأن رجل قال وأن قوم قالوا وأن ناس ذكروا"
        )
        names = _names(ar)
        joined = _joined(names)
        for s in (
            "هرقل",
            "كسرى",
            "النجاشي",
            "المقوقس",
            "جهل",
            "لهب",
            "أمية",
            "عتبة",
            "شيطان",
            "إبليس",
        ):
            self.assertNotIn(s, joined, msg=names)
        self.assertFalse(any(n in ("رجل", "امرأة", "قوم", "ناس") for n in names))


class ParallelChainTests(unittest.TestCase):
    def test_ha(self):
        text = (
            "حدثنا عبدان قال أخبرنا عبد الله قال أخبرنا يونس عن الزهري "
            "ح وحدثنا بشر بن محمد قال أخبرنا عبد الله قال أخبرنا يونس عن الزهري"
        )
        parts = split_parallel_isnads(cut_isnad_ar(text))
        self.assertGreaterEqual(len(parts), 2)
        self.assertTrue(any("عبدان" in p for p in parts))
        self.assertTrue(any("بشر" in p for p in parts))

    def test_ha_wahaddathana(self):
        text = (
            "حدثنا قتيبة حدثنا الليث عن نافع عن ابن عمر "
            "ح وحدثنا أحمد بن حنبل حدثنا يحيى عن عبيد الله عن نافع عن ابن عمر"
        )
        parts = split_parallel_isnads(text)
        self.assertGreaterEqual(len(parts), 2)

    def test_thumma_haddathana(self):
        text = (
            "حدثنا يحيى حدثنا شعبة عن قتادة عن أنس "
            "ثم حدثنا محمد حدثنا غندر عن شعبة عن قتادة عن أنس"
        )
        parts = split_parallel_isnads(text)
        self.assertGreaterEqual(len(parts), 2)
        self.assertTrue(any("يحيى" in p for p in parts))
        self.assertTrue(any("محمد" in p or "غندر" in p for p in parts))

    def test_wahaddathana_independent(self):
        text = (
            "حدثنا يحيى حدثنا شعبة عن قتادة عن أنس "
            "وحدثنا محمد حدثنا غندر عن شعبة عن قتادة عن أنس"
        )
        parts = split_parallel_isnads(text)
        self.assertGreaterEqual(len(parts), 2)
        result = parse_hadith_isnad(text + " قال رسول الله صلى الله عليه وسلم", book_slug="muslim")
        self.assertGreaterEqual(len(result.chains), 2)

    def test_waakhbarani_not_false_parallel(self):
        # وأخبرني mid-isnad is continuation, not a parallel marker
        text = "قال ابن شهاب وأخبرني أبو سلمة بن عبد الرحمن أن جابر بن عبد الله الأنصاري"
        parts = split_parallel_isnads(text)
        self.assertEqual(len(parts), 1)


class RelativeNarratorTests(unittest.TestCase):
    RELATIVES = ["أبيه", "أمه", "جده", "أخيه", "عمه", "خاله", "مولاه"]

    def test_relative_tokens_recognized(self):
        for r in self.RELATIVES:
            self.assertTrue(is_relative_token(r), msg=r)

    def test_relatives_not_stored_as_names(self):
        ar = (
            "حدثنا عبد الله بن يوسف قال أخبرنا مالك عن هشام بن عروة عن أبيه "
            "عن أمه عن جده عن أخيه عن عمه عن خاله عن مولاه عن عائشة "
            "قالت خرج رسول الله صلى الله عليه وسلم"
        )
        names = _names(ar)
        for r in self.RELATIVES:
            self.assertFalse(any(is_relative_token(n) for n in names), msg=names)
            self.assertFalse(any(n == r for n in names), msg=names)
        self.assertTrue(any("هشام" in n for n in names))
        self.assertTrue(any("عروة" in n for n in names))  # أبيه resolved


class NestedChainOrderTests(unittest.TestCase):
    def test_nested_qala_haddathana_an_samitu(self):
        ar = (
            "حدثنا الحميدي عبد الله بن الزبير قال حدثنا سفيان قال حدثنا يحيى بن سعيد "
            "الأنصاري قال أخبرني محمد بن إبراهيم التيمي أنه سمع علقمة بن وقاص الليثي "
            "يقول سمعت عمر بن الخطاب رضي الله عنه على المنبر قال سمعت رسول الله "
            "صلى الله عليه وسلم يقول إنما الأعمال بالنيات"
        )
        names = _names(ar)
        self.assertGreaterEqual(len(names), 5)
        # Order: early transmitters before Companion
        idx_omar = next(i for i, n in enumerate(names) if "عمر" in n)
        idx_hamidi = next(i for i, n in enumerate(names) if "حميدي" in n or "الزبير" in n)
        self.assertLess(idx_hamidi, idx_omar)
        self.assertFalse(any("إنما" in n for n in names))
        self.assertTrue(any("رسول الله" in n for n in names))


if __name__ == "__main__":
    unittest.main()
