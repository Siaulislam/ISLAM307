# Tafseer sources, API access, and licensing

Last reviewed: 2026-07-14

ISLAM 307 does not bundle, scrape, machine-translate, summarize, or fabricate
Tafseer. Verse-specific Tafseer is displayed only when an authorized official
API returns the requested work.

This document records the project's technical policy and source review. It is
not legal advice.

## Integrated provider

### Quran Foundation Content API

- Provider: Quran Foundation / Quran.com
- API documentation: <https://api-docs.quran.foundation/>
- Developer terms:
  <https://api-docs.quran.foundation/legal/developer-terms/>
- Authentication: OAuth2 client credentials with `content` scope
- Production API: `https://apis.quran.foundation`
- Resource discovery:
  `GET /content/api/v4/resources/tafsirs`
- Verse Tafseer:
  `GET /content/api/v4/quran/tafsirs/{resource_id}?verse_key={surah}:{ayah}`

The Developer Terms allow QF content to be displayed as an integral part of an
approved application's end-user experience. They prohibit scraping, resale,
sublicensing, and raw-data redistribution. Ordinary API content may not be
stored for more than one week unless QF expressly permits it.

ISLAM 307 uses a stricter implementation:

- no Tafseer content is stored on disk;
- a fetched verse may be retained in memory for at most ten minutes;
- the resource registry is queried at runtime;
- resource IDs are never hard-coded;
- every response displays Tafseer name, author, provider, language, Quran
  reference, resource citation, and reference URL;
- API failures never fall back to generated or bundled text.

The OAuth `client_secret` must never be embedded in Flutter or JavaScript.
Quran Foundation's quickstart requires it to remain on a backend. The app can
receive short-lived credentials from a secure token broker and then calls the
official API directly.

Runtime configuration:

```text
--dart-define=QF_TOKEN_BROKER_URL=https://your-secure-backend.example/qf-token
```

The broker must authenticate/attest the application, keep the QF client secret
server-side, and return:

```json
{
  "access_token": "short-lived-token",
  "client_id": "approved-client-id",
  "expires_in": 3600
}
```

For controlled development only, a pre-issued short-lived token can be passed
without committing it:

```text
--dart-define=QF_CLIENT_ID=...
--dart-define=QF_ACCESS_TOKEN=...
```

## Requested Tafseer works

“Direct API” below means display inside the approved application under Quran
Foundation's terms. It does **not** mean that the text may be bundled or
redistributed as a corpus.

| Work | Current policy | Restrictions / findings |
|---|---|---|
| Tafsir Ibn Kathir | Direct API when returned by the authenticated QF registry | QF documents an English resource. Modern English editions may have separate publisher rights; never bundle. |
| Tafsir Al-Tabari | Direct API when returned by the authenticated QF registry | Classical work, but digital edition/database provenance still matters. Resolve the live registry ID; documentation and historical IDs conflict. |
| Tafsir Al-Qurtubi | Direct API only if present in the authenticated QF registry | No permanent corpus permission verified. |
| Tafsir Al-Baghawi | Direct API only if present in the authenticated QF registry | No permanent corpus permission verified. |
| Tafsir Al-Jalalayn | Unavailable unless an exact authorized QF resource appears | No separate official licensed public API was verified. Modern translations have separate rights. |
| Tafsir As-Sa'di | Direct API only if authorized by the QF registry | Modern work. The IIPH English translation requires written digital-use permission; never bundle it. |
| Tafhim-ul-Quran | Unavailable | No official licensed API was verified. Permission is required from Idara Tarjuman-ul-Quran and the applicable translator/publisher. |
| Ma'ariful Quran | Direct API only if authorized by the QF registry | Modern work/translation. No redistribution license was verified; never bundle. |

## Sources reviewed but not integrated

| Provider | Reason not integrated |
|---|---|
| QUL / Tarteel downloadable resources | Download availability is not a resource-specific redistribution license. |
| King Saud University Ayat | No current public API and redistribution terms were verified. |
| Third-party GitHub or community Tafseer APIs | A code license does not establish rights to the embedded Tafseer editions. |
| Copyrighted Tafseer websites | Scraping and copying are prohibited by project policy. |

## Required response metadata

Every successful Tafseer result must include:

1. Tafseer name
2. Author
3. Provider/source
4. Language
5. Quran verse citation
6. API resource citation
7. Reference URL when supplied

If any requested work or verse is not available through the authorized API,
the application states that it is unavailable. It must not substitute another
Tafseer without the user's choice.
