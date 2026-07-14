# Narrator Research & Citation Policy

Updated: `2026-07-12T14:43:54.057502+00:00`

## Mandatory rule

Every classical narrator field must cite an approved Ahl al-Sunnah reference with Book Name, Author, Volume, and Page (Edition/Publisher when available). Never invent with AI. Never use Wikipedia, blogs, forums, or non-Sunni sources. If unverified, leave the field empty.

## Approved primary references

1. **Tahdhib al-Kamal fi Asma' al-Rijal** — Imam al-Mizzi (`tahdhib-al-kamal`)
2. **Tahdhib al-Tahdhib** — Hafiz Ibn Hajar al-Asqalani (`tahdhib-al-tahdhib`)
3. **Taqrib al-Tahdhib** — Hafiz Ibn Hajar al-Asqalani (`taqrib-al-tahdhib`)
4. **Al-Jarh wa al-Ta'dil** — Imam Ibn Abi Hatim al-Razi (`al-jarh-wa-al-tadil`)
5. **Siyar A'lam al-Nubala'** — Imam al-Dhahabi (`siyar-alam-al-nubala`)
6. **Tarikh al-Kabir** — Imam al-Bukhari (`tarikh-al-kabir`)
7. **Al-Isabah fi Tamyiz al-Sahabah** — Hafiz Ibn Hajar (`al-isabah`)
8. **Al-Isti'ab fi Ma'rifat al-Ashab** — Imam Ibn Abd al-Barr (`al-istiab`)
9. **Usd al-Ghabah fi Ma'rifat al-Sahabah** — Ibn al-Athir (`usd-al-ghabah`)
10. **Fath al-Bari** — Hafiz Ibn Hajar (`fath-al-bari`)
11. **Tabaqat Ibn Sa'd** — Ibn Sa'd (`tabaqat-ibn-sad`)
12. **Al-Kashif** — Imam al-Dhahabi (`al-kashif`)

## Citation storage

- `field_citations` table: per-field Book / Author / Volume / Page / Edition / Publisher
- `teachers`, `students`, `reliability`, `references_cite`, `books_mentioned`: each row cites a source with volume/page
- Empty fields remain empty when unverified — accuracy over completeness

Current `field_citations` rows: **0** (classical page-level imports pending).

## Forbidden

- Wikipedia, blogs, forums, AI-generated text
- Unauthenticated websites
- Shia, Ahmadi/Qadiani, or other non-Sunni sources
- Guessing missing information
