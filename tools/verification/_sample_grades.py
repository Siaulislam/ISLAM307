import sqlite3
from collections import Counter
import re

c = sqlite3.connect(r"C:\ISLAM307\app\assets\databases\hadith.db")
rows = c.execute("SELECT grade FROM hadiths WHERE grade IS NOT NULL AND length(trim(grade))>0 LIMIT 20").fetchall()
for r in rows:
    print(repr(r[0][:150]))

scholars = Counter()
for (g,) in c.execute("SELECT grade FROM hadiths WHERE grade IS NOT NULL"):
    for part in str(g).split(";"):
        m = re.search(r"\(([^)]+)\)", part)
        if m:
            scholars[m.group(1).strip()] += 1
print("TOP", scholars.most_common(15))
