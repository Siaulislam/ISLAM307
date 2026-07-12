# Bukhari — کتاب علم کے بیان میں — Snapshots

Full hadith-reader style snapshots for Sahih Bukhari **Knowledge** chapter.

- Absolute Bukhari numbers: **59–134**
- Local numbers: **Hadith 1–76 of 76**
- Each item has matching HTML + PNG (full Arabic text)

## Local path (on this machine / repo)

```
preview/snapshots/bukhari-ilm/
  index.html
  manifest.json
  html/hadith-01.html … hadith-76.html
  png/hadith-01.png  … hadith-76.png
```

Open locally:

```bash
open preview/snapshots/bukhari-ilm/index.html
# or
xdg-open preview/snapshots/bukhari-ilm/index.html
```

## Regenerate

```bash
python3 tools/snapshots/generate_bukhari_ilm_html.py
node tools/snapshots/render_bukhari_ilm_pngs.js
```
