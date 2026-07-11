Place your **13-line Indo-Pak Quran PDF** here:

```
quran-13-line.pdf
```

Then rebuild:

```bash
pip install pymupdf
python tools/quran/build_quran_db.py
```

The PDF is used **only once** to map `page_13_line` numbers. The app reads **quran.db** only.
