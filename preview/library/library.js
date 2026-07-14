const RECITERS = [
  {
    id: 'sudais',
    name: 'Sheikh Abdurrahman As-Sudais',
    title: 'Imam Al-Haram · Makkah',
    url: (s, a) => `https://everyayah.com/data/Abdurrahmaan_As-Sudais_192kbps/${pad(s)}${pad(a)}.mp3`,
  },
  {
    id: 'shuraim',
    name: 'Sheikh Saud Ash-Shuraim',
    title: 'Imam Al-Haram · Makkah',
    url: (s, a) => `https://everyayah.com/data/Saood_ash-Shuraym_128kbps/${pad(s)}${pad(a)}.mp3`,
  },
  {
    id: 'muaiqly',
    name: 'Sheikh Maher Al-Muaiqly',
    title: 'Imam Al-Haram · Makkah',
    url: (s, a) => `https://everyayah.com/data/MaherAlMuaiqly128kbps/${pad(s)}${pad(a)}.mp3`,
  },
  {
    id: 'dosari',
    name: 'Sheikh Yasser Ad-Dossari',
    title: 'Imam Al-Haram · Makkah',
    url: (s, a) => `https://everyayah.com/data/Yasser_Ad-Dussary_128kbps/${pad(s)}${pad(a)}.mp3`,
  },
  {
    id: 'hudhaify',
    name: 'Sheikh Ali Al-Hudhaify',
    title: 'Imam An-Nabawi · Madinah',
    url: (s, a) => `https://everyayah.com/data/Hudhaify_128kbps/${pad(s)}${pad(a)}.mp3`,
  },
];

function pad(n) {
  return String(n).padStart(3, '0');
}

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to load ${url}`);
  return res.json();
}

async function fetchJsonGz(url) {
  const bust = url.includes('?') ? '&v=hadith-reader-73' : '?v=hadith-reader-73';
  const res = await fetch(`${url}${bust}`);
  if (!res.ok) throw new Error(`Failed to load ${url}`);
  const buf = await res.arrayBuffer();
  if (typeof DecompressionStream === 'undefined') {
    throw new Error('This browser cannot decompress .gz files. Use Chrome/Edge/Firefox.');
  }
  const stream = new Response(buf).body.pipeThrough(new DecompressionStream('gzip'));
  const text = await new Response(stream).text();
  return JSON.parse(text);
}

const state = {
  surahs: [],
  ayahsBySurah: null,
  hadithBooks: [],
  hadithCache: {},
  hadithSlug: null,
  hadithFilter: '',
  hadithLang: localStorage.getItem('i307_hadith_lang') || 'ur',
  hadithAudioMode: localStorage.getItem('i307_hadith_audio_mode') || 'ibarat', // ibarat | translation
  /** topics | topic | numbers */
  hadithBrowseMode: localStorage.getItem('i307_hadith_browse') || 'topics',
  hadithTopicKey: null,
  hadithTopicTitle: '',
  hadithTopicEn: '',
  hadithReaderRows: [],
  hadithReaderIndex: 0,
  hadithSpeechRate: Number(localStorage.getItem('i307_hadith_rate') || 1),
  hadithSpeechPaused: false,
  hadithSpeechWatch: null,
  hadithListRows: [],
  hadithListShown: 0,
  // Paint in chunks so the full book (Bukhari/Muslim 7563, etc.) appears without a fake 120 cap.
  hadithListPage: 400,
  tafsirSources: [],
  tafsirCache: {},
  currentSurah: null,
  fontScale: Number(localStorage.getItem('i307_font') || 1),
  dark: localStorage.getItem('i307_dark') === '1',
  audio: null,
  recite: null, // { reciterId, name, surah, ayah }
  ttsUtterance: null,
  /** '' = hide translation under ayah */
  quranTranslationLang: localStorage.getItem('i307_quran_tr_lang') || '',
  /** '' = no inline tafsir panel */
  quranTafsirSlug: localStorage.getItem('i307_quran_tafsir') || '',
  openMenu: null, // 'translation' | 'tafsir' | null
  openMenuAyah: null, // 's:a' for which card shows the dropdown
  wordsBySurah: {}, // surah -> words[]
  wordCacheLoading: {},
};

const NO_AUTH = 'No authentic reference found.';


/** Languages for Muslim-majority / large Muslim communities. Text only from authenticated ayah fields. */
const QURAN_TRANSLATION_LANGS = [
  { id: 'ur', label: 'Urdu', region: 'Pakistan', field: 'ur', rtl: true },
  { id: 'en', label: 'English', region: 'International', field: 'en', rtl: false },
  { id: 'hi', label: 'Hindi', region: 'India', field: 'hi', rtl: false },
  { id: 'fil', label: 'Filipino', region: 'Philippines', field: 'fil', rtl: false },
  { id: 'bn', label: 'Bengali', region: 'Bangladesh', field: 'bn', rtl: false },
  { id: 'id', label: 'Indonesian', region: 'Indonesia', field: 'id', rtl: false },
  { id: 'ms', label: 'Malay', region: 'Malaysia', field: 'ms', rtl: false },
  { id: 'tr', label: 'Turkish', region: 'Türkiye', field: 'tr', rtl: false },
  { id: 'fa', label: 'Persian', region: 'Iran / Afghanistan', field: 'fa', rtl: true },
  { id: 'fr', label: 'French', region: 'North & West Africa', field: 'fr', rtl: false },
  { id: 'ha', label: 'Hausa', region: 'Nigeria', field: 'ha', rtl: false },
  { id: 'so', label: 'Somali', region: 'Somalia', field: 'so', rtl: false },
  { id: 'ps', label: 'Pashto', region: 'Afghanistan / Pakistan', field: 'ps', rtl: true },
  { id: 'sw', label: 'Swahili', region: 'East Africa', field: 'sw', rtl: false },
];

/** Authenticated + future tafsir sources (future ones open as “coming soon”). */
const QURAN_TAFSIR_OPTIONS = [
  { id: 'ibn-kathir', label: 'Tafsir Ibn Kathir', author: 'Hafiz Ibn Kathir', ready: false },
  { id: 'al-tabari', label: 'Tafsir al-Tabari', author: 'Imam al-Tabari', ready: false },
  { id: 'al-qurtubi', label: 'Tafsir al-Qurtubi', author: 'Imam al-Qurtubi', ready: false },
  { id: 'al-baghawi', label: 'Tafsir al-Baghawi', author: 'Imam al-Baghawi', ready: false },
  { id: 'al-jalalayn', label: 'Tafsir al-Jalalayn', author: 'Al-Mahalli & As-Suyuti', ready: false },
  { id: 'as-sadi', label: 'Tafsir as-Sa‘di', author: 'Abd al-Rahman al-Sa‘di', ready: false },
  { id: 'tafhim-ul-quran', label: 'Tafhim-ul-Quran', author: 'Syed Abul A‘la Maududi', ready: false },
  { id: 'maariful-quran', label: 'Ma‘ariful Quran', author: 'Mufti Muhammad Shafi', ready: false },
];

const $ = (id) => document.getElementById(id);

function userId() {
  let id = localStorage.getItem('islam307_user_id');
  if (!id) {
    id = `user_${Date.now()}`;
    localStorage.setItem('islam307_user_id', id);
  }
  return id;
}

function userKey() {
  return `islam307_user_${userId()}_library`;
}

function loadUserLibrary() {
  try {
    return JSON.parse(localStorage.getItem(userKey()) || '{}');
  } catch {
    return {};
  }
}

function saveUserLibrary(data) {
  data.user_id = userId();
  data.updated_at = new Date().toISOString();
  localStorage.setItem(userKey(), JSON.stringify(data));
}

function ensureUserLibrary() {
  const data = loadUserLibrary();
  if (!Array.isArray(data.bookmarks)) data.bookmarks = [];
  if (!data.highlights || typeof data.highlights !== 'object') data.highlights = {};
  if (!data.notes || typeof data.notes !== 'object') data.notes = {};
  saveUserLibrary(data);
  return data;
}

function ayahKey(s, a) {
  return `${s}:${a}`;
}

function toast(msg) {
  let el = document.getElementById('toast');
  if (!el) {
    el = document.createElement('div');
    el.id = 'toast';
    el.className = 'toast';
    document.body.appendChild(el);
  }
  el.textContent = msg;
  el.classList.add('show');
  clearTimeout(el._t);
  el._t = setTimeout(() => el.classList.remove('show'), 1800);
}

function applyTheme() {
  document.body.classList.toggle('dark', state.dark);
  localStorage.setItem('i307_dark', state.dark ? '1' : '0');
  document.documentElement.style.setProperty('--reader-scale', String(state.fontScale));
  localStorage.setItem('i307_font', String(state.fontScale));
}

function setTab(tab) {
  document.querySelectorAll('.tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('active', p.id === `panel-${tab}`));
  if (history.replaceState) {
    const url = new URL(location.href);
    url.hash = tab;
    history.replaceState(null, '', url.toString());
  }
}

document.querySelectorAll('.tabs button').forEach((btn) => {
  btn.addEventListener('click', () => setTab(btn.dataset.tab));
});

function renderSurahList(filter = '') {
  const q = filter.trim().toLowerCase();
  const list = $('surah-list');
  list.innerHTML = '';
  state.surahs
    .filter((s) => !q || s.en.toLowerCase().includes(q) || s.ar.includes(filter) || String(s.n) === q)
    .forEach((s) => {
      const b = document.createElement('button');
      b.innerHTML = `<strong>${s.n}. ${s.en}</strong><small>${s.ar} · ${s.ayahs} ayahs</small>`;
      b.onclick = () => openSurah(s.n, b);
      list.appendChild(b);
    });
}

async function ensureAyahs() {
  if (state.ayahsBySurah) return;
  $('ayah-view').innerHTML = '<p class="status">Loading full Quran…</p>';
  const data = await fetchJsonGz('data/quran/ayahs.json.gz');
  const map = new Map();
  for (const a of data.ayahs) {
    if (!map.has(a.s)) map.set(a.s, []);
    map.get(a.s).push(a);
  }
  state.ayahsBySurah = map;
}

function readerToolbarHtml(surah) {
  const reciteBar = state.recite
    ? `<div class="recite-bar" role="status">
         <span>▶ ${escapeHtml(state.recite.name)} · ${state.recite.surah}:${state.recite.ayah}</span>
         <button type="button" data-action="stop-recite" class="stop">Stop</button>
       </div>`
    : '';
  return `
    <div class="reader-tools">
      <button type="button" data-action="font-down">Aa −</button>
      <button type="button" data-action="font-up">Aa +</button>
      <button type="button" data-action="theme">${state.dark ? 'Light' : 'Dark'}</button>
      <span class="user-pill">Personal file · ${userId()}</span>
    </div>
    ${reciteBar}
    <p class="status">${surah.en} · ${surah.ar} · ${surah.ayahs} ayahs</p>
  `;
}

function translationLangMeta(id) {
  return QURAN_TRANSLATION_LANGS.find((l) => l.id === id) || null;
}

function ayahTranslationText(a, langId) {
  const meta = translationLangMeta(langId);
  if (!meta) return '';
  return String(a[meta.field] || '').trim();
}

function translationBlockHtml(a) {
  const langId = state.quranTranslationLang;
  if (!langId) return '';
  const meta = translationLangMeta(langId);
  if (!meta) return '';
  const text = ayahTranslationText(a, langId);
  if (!text) {
    return `<div class="ayah-translation is-empty" data-lang="${escapeHtml(langId)}">
      <span class="ayah-translation-label">${escapeHtml(meta.label)}</span>
      <p>Authentic ${escapeHtml(meta.label)} translation is not in the library yet. ISLAM 307 never invents Quran translations.</p>
    </div>`;
  }
  return `<div class="ayah-translation ${meta.rtl ? 'rtl' : ''}" data-lang="${escapeHtml(langId)}" dir="${meta.rtl ? 'rtl' : 'ltr'}">
    <span class="ayah-translation-label">${escapeHtml(meta.label)} · ${escapeHtml(meta.region)}</span>
    <p class="${meta.rtl ? 'ur' : 'en'}">${escapeHtml(text)}</p>
  </div>`;
}

function tafsirBlockHtml(a) {
  const slug = state.quranTafsirSlug;
  if (!slug) return '';
  const opt = QURAN_TAFSIR_OPTIONS.find((t) => t.id === slug);
  const label = opt?.label || slug;
  if (!opt?.ready) {
    return `<div class="ayah-tafsir is-soon" data-slug="${escapeHtml(slug)}">
      <span class="ayah-tafsir-label">${escapeHtml(label)}</span>
      <p>Unavailable in the static preview. The app queries an authorized Quran Foundation API at runtime; no local Tafseer file or generated substitute is used.</p>
    </div>`;
  }
  const pack = state.tafsirCache[slug];
  if (!pack) {
    return `<div class="ayah-tafsir is-loading" data-slug="${escapeHtml(slug)}">
      <span class="ayah-tafsir-label">${escapeHtml(label)}</span>
      <p>Loading authenticated tafsir…</p>
    </div>`;
  }
  const entry = (pack.entries || pack.ayahs || []).find((e) => Number(e.s || e.surah) === a.s && Number(e.a || e.ayah) === a.a)
    || (pack.byKey && pack.byKey[`${a.s}:${a.a}`])
    || null;
  const text = entry ? String(entry.text || entry.t || entry.en || '').trim() : '';
  if (!text) {
    return `<div class="ayah-tafsir is-empty" data-slug="${escapeHtml(slug)}">
      <span class="ayah-tafsir-label">${escapeHtml(label)}</span>
      <p>No authentic tafsir entry for ${a.s}:${a.a} in ${escapeHtml(label)}.</p>
    </div>`;
  }
  return `<div class="ayah-tafsir" data-slug="${escapeHtml(slug)}">
    <span class="ayah-tafsir-label">${escapeHtml(label)}</span>
    <p>${escapeHtml(text)}</p>
  </div>`;
}

function ayahHeaderMenusHtml(a) {
  const ayahKeyStr = `${a.s}:${a.a}`;
  const isActiveCard = state.openMenuAyah === ayahKeyStr;
  const trOpen = isActiveCard && state.openMenu === 'translation';
  const tfOpen = isActiveCard && state.openMenu === 'tafsir';
  const trMeta = translationLangMeta(state.quranTranslationLang);
  const trLabel = trMeta ? trMeta.label : 'Translation';
  const tfLabel = state.quranTafsirSlug ? 'Tafseer' : 'Tafseer';

  const trItems = [
    `<button type="button" class="ayah-menu-item ${!state.quranTranslationLang ? 'is-active' : ''}" data-tr-lang="">Hide translation</button>`,
    ...QURAN_TRANSLATION_LANGS.map((l) => `<button type="button" class="ayah-menu-item ${state.quranTranslationLang === l.id ? 'is-active' : ''}" data-tr-lang="${l.id}">
        <strong>${escapeHtml(l.label)}</strong>
        <small>${escapeHtml(l.region)}</small>
      </button>`),
  ].join('');

  const tfItems = [
    `<button type="button" class="ayah-menu-item ${!state.quranTafsirSlug ? 'is-active' : ''}" data-tf-slug="">Hide tafseer</button>`,
    ...QURAN_TAFSIR_OPTIONS.map((t) => `<button type="button" class="ayah-menu-item ${state.quranTafsirSlug === t.id ? 'is-active' : ''}" data-tf-slug="${t.id}">
      <strong>${escapeHtml(t.label)}</strong>
      <small>${t.ready ? 'Available' : 'Official API app only'}</small>
    </button>`).join(''),
  ].join('');

  return `
    <div class="ayah-header-actions">
      <div class="ayah-dd ${trOpen ? 'is-open' : ''}">
        <button type="button" class="ayah-dd-btn ${state.quranTranslationLang ? 'is-on' : ''}" data-menu="translation" aria-expanded="${trOpen}">
          <span>${escapeHtml(trLabel)}</span>
        </button>
        ${trOpen ? `<div class="ayah-dd-panel" role="menu">${trItems}</div>` : ''}
      </div>
      <div class="ayah-dd ${tfOpen ? 'is-open' : ''}">
        <button type="button" class="ayah-dd-btn ${state.quranTafsirSlug ? 'is-on' : ''}" data-menu="tafsir" aria-expanded="${tfOpen}">
          <span>${escapeHtml(tfLabel)}</span>
        </button>
        ${tfOpen ? `<div class="ayah-dd-panel" role="menu">${tfItems}</div>` : ''}
      </div>
    </div>
  `;
}


async function ensureSurahWords(surah) {
  if (state.wordsBySurah[surah]) return state.wordsBySurah[surah];
  if (state.wordCacheLoading[surah]) return state.wordCacheLoading[surah];
  state.wordCacheLoading[surah] = fetchJsonGz(`data/quran/words/${surah}.json.gz`)
    .then((data) => {
      state.wordsBySurah[surah] = data.words || [];
      delete state.wordCacheLoading[surah];
      return state.wordsBySurah[surah];
    })
    .catch(() => {
      state.wordsBySurah[surah] = [];
      delete state.wordCacheLoading[surah];
      return [];
    });
  return state.wordCacheLoading[surah];
}

function wordsForAyah(surah, ayah) {
  const all = state.wordsBySurah[surah] || [];
  return all.filter((w) => w.a === ayah);
}

function ayahWordsHtml(a) {
  const words = wordsForAyah(a.s, a.a);
  if (!words.length) {
    return `<span class="ayah-word-fallback">${escapeHtml(a.ar || '')}</span>`;
  }
  return words
    .map(
      (w) =>
        `<button type="button" class="qword" data-word-id="${w.id}" data-s="${a.s}" data-a="${a.a}" data-n="${w.n}">${escapeHtml(w.ar)}</button>`
    )
    .join(' ');
}

function fieldOrMissing(v) {
  const t = String(v || '').trim();
  return t || NO_AUTH;
}

function wordMeaningForLang(word, lang) {
  const map = {
    ur: word.ur,
    en: word.en,
    hi: word.hi,
    bn: word.bn,
    id: word.idn || word.id_meaning,
    tr: word.trm,
    fa: word.fa,
  };
  // note: word.tr is transliteration — Indonesian uses idn
  if (lang === 'id') return word.idn || '';
  if (lang === 'tr') return word.trm || '';
  return (map[lang] || '').trim ? (map[lang] || '') : (map[lang] || '');
}

function activeWordLang() {
  return state.quranTranslationLang || 'ur';
}

function openWordQuick(word) {
  const lang = activeWordLang();
  const selected = wordMeaningForLang(word, lang);
  const selectedBlock =
    lang && lang !== 'ur'
      ? `<p class="lang-label">${escapeHtml(lang.toUpperCase())}</p>
         <p class="${lang === 'fa' || lang === 'ur' ? 'ur' : 'en'}" dir="${lang === 'fa' ? 'rtl' : 'ltr'}">${escapeHtml(fieldOrMissing(selected))}</p>`
      : '';
  const body = `
    <div class="word-quick no-blue-hl">
      <p class="ar" dir="rtl">${escapeHtml(word.ar)}</p>
      ${word.tr ? `<p class="muted">${escapeHtml(word.tr)}</p>` : ''}
      <p class="ur" dir="rtl">${escapeHtml(fieldOrMissing(word.ur))}</p>
      ${selectedBlock}
      ${word.en && lang !== 'en' ? `<p class="en muted">${escapeHtml(word.en)}</p>` : ''}
      ${word.root ? `<p class="root" dir="rtl">جذر · ${escapeHtml(word.root)}</p>` : ''}
      <button type="button" class="primary" data-word-more="${word.id}">مزید · مکمل لفظی تجزیہ</button>
    </div>`;
  openHadithModal(`لفظ کا مطلب · ${state.currentSurah}:${word.a}:${word.n}`, body);
  const modal = document.getElementById('hadith-detail-modal');
  modal?.querySelector('[data-word-more]')?.addEventListener('click', () => {
    closeHadithModal();
    openWordFull(word);
  });
}

function openWordFull(word) {
  const lang = activeWordLang();
  const selected = wordMeaningForLang(word, lang);
  const occS = word.occ_s || 0;
  const occL = word.occ_l || 0;
  const occR = word.occ_r || word.occ || 0;
  const selectedRow =
    lang && lang !== 'ur'
      ? `<tr><th>${escapeHtml(lang.toUpperCase())} معنی</th><td dir="${lang === 'fa' ? 'rtl' : 'ltr'}">${escapeHtml(fieldOrMissing(selected))}</td></tr>`
      : '';
  const body = `
    <div class="word-full no-blue-hl">
      <p class="ar" dir="rtl">${escapeHtml(word.ar)}</p>
      <table class="ref-table">
        <tbody>
          <tr><th>عربی لفظ</th><td dir="rtl">${escapeHtml(word.ar)}</td></tr>
          <tr><th>اردو معنی</th><td dir="rtl">${escapeHtml(fieldOrMissing(word.ur))}</td></tr>
          ${selectedRow}
          ${lang !== 'en' ? `<tr><th>English</th><td>${escapeHtml(fieldOrMissing(word.en))}</td></tr>` : ''}
          <tr><th>تلفظ</th><td>${escapeHtml(fieldOrMissing(word.tr))}</td></tr>
          <tr><th>جذر حروف</th><td dir="rtl">${escapeHtml(fieldOrMissing(word.root))}${
            word.root
              ? ` · <button type="button" class="linkish" data-open-root="${escapeHtml(word.root)}">جذر کھولیں</button>`
              : ''
          }</td></tr>
          <tr><th>صرف</th><td>${escapeHtml(fieldOrMissing(word.morph))}</td></tr>
          <tr><th>گرامر</th><td>${escapeHtml(fieldOrMissing(word.gram))}</td></tr>
          <tr><th>قسم کلمہ</th><td>${escapeHtml(fieldOrMissing(word.pos))}</td></tr>
          <tr><th>نحو</th><td>${escapeHtml(fieldOrMissing(word.syn))}</td></tr>
          <tr><th>اسی لفظ کی تعداد</th><td>${escapeHtml(String(occS))}</td></tr>
          <tr><th>اسی lemma کی تعداد</th><td>${escapeHtml(String(occL))}</td></tr>
          <tr><th>اسی جذر کی کل تعداد</th><td>${escapeHtml(String(occR))}</td></tr>
          <tr><th>Lemma</th><td dir="rtl">${escapeHtml(fieldOrMissing(word.lemma))}</td></tr>
        </tbody>
      </table>
    </div>`;
  openHadithModal(`تفصیل لفظ · ${state.currentSurah}:${word.a}:${word.n}`, body);
  const modal = document.getElementById('hadith-detail-modal');
  modal?.querySelector('[data-open-root]')?.addEventListener('click', () => {
    closeHadithModal();
    openRootPage(word.root);
  });
}

function openRootPage(root) {
  if (!root) {
    openHadithModal('جذر', `<p class="muted">${NO_AUTH}</p>`);
    return;
  }
  const meanings = [];
  const seen = new Set();
  const ayahRows = [];
  const ayahSeen = new Set();
  let total = 0;
  for (const [surah, words] of Object.entries(state.wordsBySurah)) {
    for (const w of words) {
      if (w.root !== root) continue;
      total += 1;
      const key = `${w.en}|${w.ur}`;
      if ((w.en || w.ur) && !seen.has(key) && meanings.length < 12) {
        seen.add(key);
        meanings.push(w);
      }
      const akey = `${surah}:${w.a}`;
      if (!ayahSeen.has(akey) && ayahRows.length < 80) {
        ayahSeen.add(akey);
        ayahRows.push({ s: Number(surah), a: w.a, ar: w.ar, ur: w.ur, en: w.en });
      }
    }
  }
  const meanHtml = meanings.length
    ? meanings
        .map(
          (w) =>
            `<li><span dir="rtl">${escapeHtml(fieldOrMissing(w.ur))}</span><br/><span class="muted">${escapeHtml(fieldOrMissing(w.en))}</span></li>`
        )
        .join('')
    : `<li class="muted">${NO_AUTH}</li>`;
  const ayahHtml = ayahRows.length
    ? ayahRows
        .map(
          (r) =>
            `<li><strong>${r.s}:${r.a}</strong> <span dir="rtl">${escapeHtml(r.ar)}</span> — <span dir="rtl">${escapeHtml(
              fieldOrMissing(r.ur || r.en)
            )}</span></li>`
        )
        .join('')
    : `<li class="muted">${NO_AUTH}</li>`;
  const body = `
    <div class="root-page no-blue-hl">
      <p class="ar" dir="rtl">${escapeHtml(root)}</p>
      <h4>معانی</h4>
      <ul>${meanHtml}</ul>
      <h4>کل وقوعات (لوڈ شدہ)</h4>
      <p>${total}</p>
      <h4>متعلقہ جذور</h4>
      <p class="muted">${NO_AUTH}</p>
      <h4>آیات</h4>
      <ul class="root-ayahs">${ayahHtml}</ul>
    </div>`;
  openHadithModal(`جذر · ${root}`, body);
}

function ayahCardHtml(a, lib) {
  const key = ayahKey(a.s, a.a);
  const bookmarked = lib.bookmarks.includes(key);
  const highlighted = !!lib.highlights[key];
  const note = lib.notes[key] || '';
  const playing = state.recite && state.recite.surah === a.s && state.recite.ayah === a.a;
  return `
    <div class="ayah is-tappable ${highlighted ? 'is-highlighted' : ''} ${playing ? 'is-playing' : ''}" data-s="${a.s}" data-a="${a.a}" role="button" tabindex="0" title="Tap verse for actions">
      <div class="meta-row">
        <span class="ayah-ref">${a.s}:${a.a}${bookmarked ? ' ★' : ''}</span>
        ${ayahHeaderMenusHtml(a)}
        <span class="ayah-page">Page ${a.p} · Juz ${a.j}</span>
      </div>
      <div class="ar ayah-words" dir="rtl" data-s="${a.s}" data-a="${a.a}">${ayahWordsHtml(a)}</div>
      ${translationBlockHtml(a)}
      ${tafsirBlockHtml(a)}
      ${note ? `<div class="note-box">Note: ${escapeHtml(note)}</div>` : ''}
      ${playing ? `<div class="recite-now">Playing · ${escapeHtml(state.recite.name)} · continues to next ayah · tap verse to Stop</div>` : ''}
    </div>
  `;
}

function escapeHtml(s) {
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

async function openSurah(n, button, { preserveScroll = false } = {}) {
  await ensureAyahs();
  await ensureSurahWords(n);
  $('surah-list').querySelectorAll('button').forEach((b) => b.classList.remove('active'));
  if (button) button.classList.add('active');
  const surah = state.surahs.find((s) => s.n === n);
  const ayahs = state.ayahsBySurah.get(n) || [];
  if (!surah) {
    $('ayah-view').innerHTML = `<p class="empty">Surah ${n} not found.</p>`;
    return;
  }
  const view = $('ayah-view');
  const top = preserveScroll ? view.scrollTop : 0;
  state.currentSurah = n;
  const lib = ensureUserLibrary();
  view.innerHTML = readerToolbarHtml(surah) + ayahs.map((a) => ayahCardHtml(a, lib)).join('');
  wireReaderEvents();
  wireWordEvents();
  if (history.replaceState) {
    const url = new URL(location.href);
    url.searchParams.set('surah', String(n));
    url.hash = 'quran';
    history.replaceState(null, '', url.toString());
  }
  view.scrollTop = preserveScroll ? top : 0;
}

function refreshCurrentSurah(preserveScroll = true) {
  const active = $('surah-list').querySelector('button.active');
  if (state.currentSurah) {
    openSurah(state.currentSurah, active, { preserveScroll });
  }
}

async function ensureTafsirPack(slug) {
  // Protected Tafseer APIs require backend-held OAuth credentials. GitHub
  // Pages never loads a local corpus or embeds a client secret.
  return null;
}

function openVerseActions(surah, ayah) {
  const existing = document.getElementById('verse-actions-modal');
  if (existing) existing.remove();
  const key = ayahKey(surah, ayah);
  const lib = ensureUserLibrary();
  const bookmarked = lib.bookmarks.includes(key);
  const highlighted = !!lib.highlights[key];
  const playing = state.recite && state.recite.surah === surah && state.recite.ayah === ayah;
  const row = (state.ayahsBySurah.get(surah) || []).find((x) => x.a === ayah);
  const ar = row?.ar || '';
  const tr = state.quranTranslationLang ? ayahTranslationText(row || {}, state.quranTranslationLang) : '';

  const modal = document.createElement('div');
  modal.id = 'verse-actions-modal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal verse-actions-modal">
      <h3>Ayah ${surah}:${ayah}</h3>
      <p class="lead">Choose an action for this verse</p>
      <div class="verse-actions-list">
        <button type="button" data-act="bookmark"><strong>${bookmarked ? 'Remove bookmark' : 'Bookmark'}</strong><small>Save to your personal file</small></button>
        <button type="button" data-act="highlight"><strong>${highlighted ? 'Remove highlight' : 'Highlight'}</strong><small>Mark this ayah</small></button>
        <button type="button" data-act="note"><strong>Notes</strong><small>${lib.notes[key] ? 'Edit your note' : 'Write a personal note'}</small></button>
        <button type="button" data-act="copy"><strong>Copy</strong><small>Copy Arabic${tr ? ' + translation' : ''}</small></button>
        <button type="button" data-act="share"><strong>Share</strong><small>Share this ayah</small></button>
        ${playing
          ? `<button type="button" data-act="stop" class="danger"><strong>Stop</strong><small>Stop recitation</small></button>`
          : `<button type="button" data-act="recite" class="primary"><strong>Recite</strong><small>Choose Qari · continues automatically</small></button>`}
      </div>
      <button type="button" class="ghost" data-close>Close</button>
    </div>
  `;
  document.body.appendChild(modal);
  const close = () => modal.remove();
  modal.querySelector('[data-close]').onclick = close;
  modal.addEventListener('click', (e) => {
    if (e.target === modal) close();
  });

  modal.querySelectorAll('[data-act]').forEach((btn) => {
    btn.onclick = async () => {
      const act = btn.dataset.act;
      const library = ensureUserLibrary();
      if (act === 'bookmark') {
        const i = library.bookmarks.indexOf(key);
        if (i >= 0) library.bookmarks.splice(i, 1);
        else library.bookmarks.push(key);
        saveUserLibrary(library);
        toast(i >= 0 ? 'Bookmark removed' : 'Saved to your personal bookmark file');
        close();
        refreshCurrentSurah(true);
        return;
      }
      if (act === 'highlight') {
        if (library.highlights[key]) delete library.highlights[key];
        else library.highlights[key] = 'gold';
        saveUserLibrary(library);
        toast(library.highlights[key] ? 'Highlighted' : 'Highlight cleared');
        close();
        refreshCurrentSurah(true);
        return;
      }
      if (act === 'note') {
        const next = prompt(`Note for ${key}`, library.notes[key] || '');
        if (next === null) return;
        if (!next.trim()) delete library.notes[key];
        else library.notes[key] = next.trim();
        saveUserLibrary(library);
        toast('Note saved to your personal file');
        close();
        refreshCurrentSurah(true);
        return;
      }
      if (act === 'copy') {
        await navigator.clipboard.writeText(`${key}\n${ar}\n${tr}`.trim());
        toast('Copied');
        close();
        return;
      }
      if (act === 'share') {
        const text = `ISLAM 307 · Quran ${key}\n${ar}\n${tr}`.trim();
        if (navigator.share) {
          try {
            await navigator.share({ title: `Quran ${key}`, text });
          } catch {}
        } else {
          await navigator.clipboard.writeText(text);
          toast('Share text copied');
        }
        close();
        return;
      }
      if (act === 'recite') {
        close();
        openReciterPicker(surah, ayah);
        return;
      }
      if (act === 'stop') {
        close();
        stopRecitation('Recitation stopped');
      }
    };
  });
}


function wireWordEvents() {
  const view = $('ayah-view');
  if (!view) return;
  view.querySelectorAll('button.qword').forEach((btn) => {
    btn.onclick = (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      const id = Number(btn.dataset.wordId);
      const surah = Number(btn.dataset.s);
      const word = (state.wordsBySurah[surah] || []).find((w) => w.id === id);
      if (!word) {
        toast(NO_AUTH);
        return;
      }
      openWordQuick(word);
    };
  });
}

function wireReaderEvents() {
  const view = $('ayah-view');
  view.querySelectorAll('[data-action]').forEach((btn) => {
    btn.onclick = () => {
      const act = btn.dataset.action;
      if (act === 'font-up') state.fontScale = Math.min(1.6, state.fontScale + 0.1);
      if (act === 'font-down') state.fontScale = Math.max(0.85, state.fontScale - 0.1);
      if (act === 'theme') state.dark = !state.dark;
      if (act === 'stop-recite') {
        stopRecitation('Recitation stopped');
        return;
      }
      applyTheme();
      const surah = state.surahs.find((s) => s.n === state.currentSurah);
      if (surah) {
        const active = $('surah-list').querySelector('button.active');
        openSurah(state.currentSurah, active);
      }
    };
  });

  view.querySelectorAll('.ayah').forEach((card) => {
    const s = Number(card.dataset.s);
    const a = Number(card.dataset.a);
    const ayahKeyStr = `${s}:${a}`;

    card.addEventListener('click', (ev) => {
      if (ev.target.closest('[data-menu], [data-tr-lang], [data-tf-slug], .ayah-dd-panel, a, button')) return;
      openVerseActions(s, a);
    });
    card.addEventListener('keydown', (ev) => {
      if (ev.key !== 'Enter' && ev.key !== ' ') return;
      if (ev.target !== card) return;
      ev.preventDefault();
      openVerseActions(s, a);
    });

    card.querySelectorAll('[data-menu]').forEach((btn) => {
      btn.onclick = (ev) => {
        ev.stopPropagation();
        const menu = btn.dataset.menu;
        if (state.openMenu === menu && state.openMenuAyah === ayahKeyStr) {
          state.openMenu = null;
          state.openMenuAyah = null;
        } else {
          state.openMenu = menu;
          state.openMenuAyah = ayahKeyStr;
        }
        refreshCurrentSurah(true);
      };
    });

    card.querySelectorAll('[data-tr-lang]').forEach((btn) => {
      btn.onclick = (ev) => {
        ev.stopPropagation();
        state.quranTranslationLang = btn.dataset.trLang || '';
        localStorage.setItem('i307_quran_tr_lang', state.quranTranslationLang);
        state.openMenu = null;
        state.openMenuAyah = null;
        refreshCurrentSurah(true);
        const meta = translationLangMeta(state.quranTranslationLang);
        toast(meta ? `Translation · ${meta.label}` : 'Translation hidden');
      };
    });

    card.querySelectorAll('[data-tf-slug]').forEach((btn) => {
      btn.onclick = async (ev) => {
        ev.stopPropagation();
        const slug = btn.dataset.tfSlug || '';
        state.quranTafsirSlug = slug;
        localStorage.setItem('i307_quran_tafsir', slug);
        state.openMenu = null;
        state.openMenuAyah = null;
        if (slug) {
          const opt = QURAN_TAFSIR_OPTIONS.find((t) => t.id === slug);
          if (opt?.ready) {
            try {
              await ensureTafsirPack(slug);
            } catch (err) {
              toast(`Could not load ${opt.label}`);
            }
          }
        }
        refreshCurrentSurah(true);
        const opt = QURAN_TAFSIR_OPTIONS.find((t) => t.id === slug);
        toast(opt ? (opt.ready ? `Tafseer · ${opt.label}` : `${opt.label} · official API app only`) : 'Tafseer hidden');
      };
    });
  });
}

function refreshAyahViewKeepingScroll() {
  const view = $('ayah-view');
  const top = view ? view.scrollTop : 0;
  const surah = state.surahs.find((s) => s.n === state.currentSurah);
  if (!surah) return;
  const active = $('surah-list').querySelector('button.active');
  const ayahs = state.ayahsBySurah.get(state.currentSurah) || [];
  const lib = ensureUserLibrary();
  view.innerHTML = readerToolbarHtml(surah) + ayahs.map((a) => ayahCardHtml(a, lib)).join('');
  wireReaderEvents();
  view.scrollTop = top;
  if (active) active.classList.add('active');
}

function stopRecitation(message) {
  if (state.audio) {
    state.audio.onended = null;
    state.audio.pause();
    state.audio = null;
  }
  state.recite = null;
  if (message) toast(message);
  if (state.currentSurah) refreshAyahViewKeepingScroll();
}

function openReciterPicker(surah, ayah) {
  const existing = document.getElementById('reciter-modal');
  if (existing) existing.remove();
  const modal = document.createElement('div');
  modal.id = 'reciter-modal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal">
      <h3>Choose Qari (KSA / Imam Al-Haram)</h3>
      <p class="lead">Authentic recitation · ${surah}:${ayah}<br/>Continues to the next ayah automatically. Press Stop anytime.</p>
      <div class="reciter-list">
        ${RECITERS.map((r) => `
          <button type="button" data-reciter="${r.id}">
            <strong>${r.name}</strong>
            <small>${r.title}</small>
          </button>
        `).join('')}
      </div>
      <button type="button" class="ghost" data-close>Close</button>
    </div>
  `;
  document.body.appendChild(modal);
  modal.querySelector('[data-close]').onclick = () => modal.remove();
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
  modal.querySelectorAll('[data-reciter]').forEach((btn) => {
    btn.onclick = () => {
      const reciter = RECITERS.find((r) => r.id === btn.dataset.reciter);
      modal.remove();
      playReciterContinuous(reciter, surah, ayah);
    };
  });
}

function playReciterContinuous(reciter, surah, ayah) {
  if (!reciter) return;
  if (state.audio) {
    state.audio.onended = null;
    state.audio.pause();
    state.audio = null;
  }

  const ayahs = state.ayahsBySurah.get(surah) || [];
  const exists = ayahs.some((row) => row.a === ayah);
  if (!exists) {
    stopRecitation('End of surah');
    return;
  }

  const url = reciter.url(surah, ayah);
  const audio = new Audio(url);
  state.audio = audio;
  state.recite = { reciterId: reciter.id, name: reciter.name, surah, ayah };
  refreshAyahViewKeepingScroll();
  toast(`Playing · ${reciter.name} · ${surah}:${ayah}`);

  audio.onended = () => {
    if (!state.recite || state.recite.surah !== surah) return;
    const next = ayah + 1;
    const hasNext = ayahs.some((row) => row.a === next);
    if (!hasNext) {
      stopRecitation('Surah complete');
      return;
    }
    playReciterContinuous(reciter, surah, next);
  };
  audio.play().catch(() => {
    toast('Audio unavailable right now. Try another qari.');
    stopRecitation();
  });
}

function bookIconUrl(slug) {
  const known = {
    bukhari: '../branding/books/bukhari_sm.png',
    muslim: '../branding/books/muslim_sm.png',
    abudawud: '../branding/books/abudawud_sm.png',
    tirmidhi: '../branding/books/tirmidhi_sm.png',
    quran: '../branding/books/quran_sm.png',
  };
  return known[slug] || null;
}

function renderHadithBooks() {
  const list = $('hadith-books');
  list.innerHTML = '';
  state.hadithBooks.forEach((book) => {
    const b = document.createElement('button');
    const icon = bookIconUrl(book.slug);
    b.className = 'book-row';
    b.innerHTML = `
      ${icon ? `<img class="book-icon" src="${icon}" alt="" width="44" height="44" loading="lazy" />` : '<span class="book-icon-fallback">📖</span>'}
      <span class="book-meta">
        <strong>${book.en}</strong>
        <small>${book.ar} · ${book.count.toLocaleString()} hadith</small>
      </span>
    `;
    b.onclick = () => openHadithBook(book, b);
    list.appendChild(b);
  });
}

async function openHadithBook(book, button) {
  $('hadith-books').querySelectorAll('button').forEach((b) => b.classList.remove('active'));
  if (button) button.classList.add('active');
  state.hadithSlug = book.slug;
  state.hadithFilter = $('hadith-search').value || '';
  state.hadithTopicKey = null;
  state.hadithTopicTitle = '';
  if (state.hadithBrowseMode === 'topic') setHadithBrowseMode('topics');
  $('hadith-view').innerHTML = `<p class="status">Loading ${book.en}…</p>`;
  loadNarratorCatalog(); // warm narrator detail catalog (authenticated identities)
  if (!state.hadithCache[book.slug]) {
    state.hadithCache[book.slug] = await fetchJsonGz(`data/hadith/${book.slug}.json.gz`);
  }
  renderHadithList(book.slug, state.hadithFilter);
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Kitab/book chapter name for list rows — Urdu first, then Arabic.
 * Never fall back to the collection name (e.g. "Sahih Bukhari") — that created
 * a fake topic card with a huge min–max range for uncategorized hadiths.
 */
function localizedKitabName(hadith, pack) {
  const by = hadith.reference_detail?.by_lang || {};
  const ur = by.ur?.values?.kitab || '';
  const ar = by.ar?.values?.kitab || '';
  const en = by.en?.values?.kitab || '';
  // Prefer authentic Urdu; if Urdu still mirrors English, use Arabic kitab title.
  if (ur && ur !== en) return ur;
  if (ar) return ar;
  if (ur) return ur;
  if (hadith.reference_detail?.kitab) return hadith.reference_detail.kitab;
  if (hadith.kitab && String(hadith.kitab).trim()) return hadith.kitab;
  return '';
}

function kitabTopicKey(hadith) {
  if (hadith.kitab_number != null && hadith.kitab_number !== '') return `n:${hadith.kitab_number}`;
  const name = (hadith.kitab || '').trim();
  if (name) return `t:${name}`;
  // Source section 0 / missing chapter — keep a single honest bucket.
  return 'unassigned';
}

function isCountedHadithRow(h) {
  // MOQDEMA / preface (n <= 0) is never part of automatic Hadith 1..N navigation.
  if (!(Number(h?.n) > 0)) return false;
  return String(h.ar || '').trim().length > 0 || String(h.en || '').trim().length > 0;
}

function countedHadithRows(rows) {
  return (rows || []).filter(isCountedHadithRow).sort((a, b) => Number(a.n) - Number(b.n));
}

function prefaceHadithRows(rows) {
  return (rows || []).filter((h) => Number(h?.n) <= 0).sort((a, b) => Number(a.n) - Number(b.n));
}

/** Honest range label: never imply a continuous block when count << span. */
function topicRangeLabel(topic) {
  const nums = (Array.isArray(topic.countedNums) && topic.countedNums.length
    ? topic.countedNums
    : (Array.isArray(topic.nums) ? topic.nums : [])
  ).filter((n) => Number(n) > 0);
  const first = topic.countedFirst != null ? topic.countedFirst : (nums.length ? nums[0] : topic.first);
  const last = topic.countedLast != null ? topic.countedLast : (nums.length ? nums[nums.length - 1] : topic.last);
  const count = topic.countedCount != null ? Number(topic.countedCount) : (nums.length || Number(topic.count || 0));
  if (count <= 0) return '';
  if (count === 1 || first === last) return `Hadith ${first}`;
  const span = Number(last) - Number(first) + 1;
  const dense = span > 0 && count / span >= 0.5;
  if (dense) return `Hadith ${first} to ${last}`;
  if (nums.length > 0 && nums.length <= 8) return `Hadith ${nums.join(', ')}`;
  if (nums.length > 8) {
    return `Hadith ${nums.slice(0, 4).join(', ')}… (+${nums.length - 4} more)`;
  }
  return `${count} hadith · from ${first} to ${last}`;
}

function buildKitabTopics(pack) {
  const map = new Map();
  const bookName = (pack?.book?.en || '').trim().toLowerCase();
  for (const h of pack.hadiths || []) {
    let title = localizedKitabName(h, pack);
    let key = kitabTopicKey(h);
    // Uncategorized in authenticated source (empty chapter / section 0).
    if (!title || !String(title).trim() || (bookName && String(title).trim().toLowerCase() === bookName)) {
      title = 'Unassigned';
      key = 'unassigned';
    }
    if (!map.has(key)) {
      map.set(key, {
        key,
        kitab_number: key === 'unassigned' ? null : h.kitab_number,
        en: key === 'unassigned' ? '' : (h.kitab || ''),
        title,
        count: 0,
        first: h.n,
        last: h.n,
        nums: [],
        countedNums: [],
        countedFirst: null,
        countedLast: null,
        countedCount: 0,
      });
    }
    const row = map.get(key);
    row.count += 1;
    if (h.n < row.first) row.first = h.n;
    if (h.n > row.last) row.last = h.n;
    row.nums.push(h.n);
    if (isCountedHadithRow(h)) {
      row.countedNums.push(h.n);
      row.countedCount += 1;
      if (row.countedFirst == null || h.n < row.countedFirst) row.countedFirst = h.n;
      if (row.countedLast == null || h.n > row.countedLast) row.countedLast = h.n;
    }
  }
  for (const row of map.values()) {
    row.nums.sort((a, b) => a - b);
    row.countedNums.sort((a, b) => a - b);
    // Topic card uses counted hadiths only (MOQDEMA not counted).
    if (row.countedCount > 0) {
      row.count = row.countedCount;
      row.first = row.countedFirst;
      row.last = row.countedLast;
    }
  }
  return [...map.values()].sort((a, b) => {
    if (a.key === 'unassigned') return 1;
    if (b.key === 'unassigned') return -1;
    const an = a.kitab_number == null ? 9999 : Number(a.kitab_number);
    const bn = b.kitab_number == null ? 9999 : Number(b.kitab_number);
    return an - bn || Number(a.first) - Number(b.first);
  });
}

function setHadithBrowseMode(mode) {
  state.hadithBrowseMode = mode;
  localStorage.setItem('i307_hadith_browse', mode === 'numbers' ? 'numbers' : 'topics');
}

function openHadithTopic(slug, topic) {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  state.hadithTopicKey = topic.key;
  state.hadithTopicTitle = topic.title || '';
  state.hadithTopicEn = topic.en || '';
  setHadithBrowseMode('topics');
  const all = (pack.hadiths || []).filter((h) => kitabTopicKey(h) === topic.key);
  // Automatic Next/Previous uses counted hadiths only (1..N). MOQDEMA is not in this chain.
  const rows = countedHadithRows(all);
  openHadithReader(slug, rows.length ? rows : all, 0);
}

function openHadithPreface(slug) {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  const all = pack.hadiths || [];
  const preface = prefaceHadithRows(all);
  if (!preface.length) return;
  const introKey = kitabTopicKey(preface[0]);
  const numbered = countedHadithRows(all.filter((h) => kitabTopicKey(h) === introKey));
  state.hadithTopicKey = introKey;
  state.hadithTopicTitle = 'المقدمة';
  state.hadithTopicEn = 'MOQDEMA';
  setHadithBrowseMode('topics');
  // A deliberate MOQDEMA open starts with both preface rows, then Hadith 1..N.
  openHadithReader(slug, preface.concat(numbered), 0);
}

function clearHadithTopic(slug) {
  stopHadithSpeech();
  state.hadithTopicKey = null;
  state.hadithTopicTitle = '';
  state.hadithTopicEn = '';
  state.hadithReaderRows = [];
  state.hadithReaderIndex = 0;
  setHadithBrowseMode('topics');
  renderHadithList(slug, state.hadithFilter);
}

function openHadithBookReader(slug) {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  state.hadithTopicKey = null;
  state.hadithTopicTitle = '';
  state.hadithTopicEn = '';
  openHadithReader(slug, pack.hadiths || [], 0);
}

function closeHadithModal() {
  const existing = document.getElementById('hadith-detail-modal');
  if (existing) existing.remove();
}

function openHadithModal(title, bodyHtml, { darkTable = false } = {}) {
  closeHadithModal();
  const modal = document.createElement('div');
  modal.id = 'hadith-detail-modal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal hadith-detail-modal${darkTable ? ' ref-modal-dark' : ''}">
      <div class="modal-head">
        <h3>${escapeHtml(title)}</h3>
        <button type="button" class="ghost" data-close aria-label="Close">Close</button>
      </div>
      <div class="modal-body">${bodyHtml}</div>
    </div>
  `;
  document.body.appendChild(modal);
  modal.querySelector('[data-close]').onclick = () => modal.remove();
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

function raviCopy(lang) {
  const copy = {
    en: {
      first: 'First narrator',
      mid: 'Narrated from previous',
      last: 'Last narrator · from the Prophet ﷺ',
      empty: 'Full ravi chain is not available in the authenticated isnad for this hadith.',
      isnad: 'Isnad (authenticated)',
      title: 'Ravi',
    },
    ur: {
      first: 'پہلا راوی',
      mid: 'پچھلے سے روایت',
      last: 'آخری راوی · نبی ﷺ سے',
      empty: 'اس حدیث کی مکمل سند ماخذ میں دستیاب نہیں۔',
      isnad: 'سند (مستند)',
      title: 'راوی',
    },
    ar: {
      first: 'أول راوٍ',
      mid: 'روى عن السابق',
      last: 'آخر راوٍ · عن النبي ﷺ',
      empty: 'سلسلة الرواة الكاملة غير متوفرة في الإسناد الموثق لهذا الحديث.',
      isnad: 'الإسناد (موثق)',
      title: 'الرواة',
    },
  };
  return copy[lang] || copy.en;
}

/** Primary narrator exactly as provided by the authenticated pack (e.g. Sunnah.com). */
function authenticatedNarratorName(hadith) {
  const primary = String(hadith.ravi || hadith.narrator || '').trim();
  if (primary) return primary;
  const chain = hadith.ravi_chain || [];
  return chain.length ? String(chain[0]).trim() : '';
}

/**
 * Narrator (Rijāl) Knowledge seam.
 * Profiles use the standard راوی معلومات table template.
 * Values stay empty until authenticated datasets are imported.
 * Never invent. Never assume classical data is "unavailable".
 */
const NARRATOR_PROFILE = {
  notImportedMessage: 'This narrator profile has not been imported into the local database yet.',
  policy: 'ISLAM 307 never generates narrator biographies with AI. Profiles appear only after authenticated narrator datasets are imported.',
  fieldLabels: [
    'راوی آئی ڈی',
    'پورا نام (عربی)',
    'پورا نام (اردو)',
    'کنیت',
    'لقب',
    'نسب / نسبت',
    'قبیلہ',
    'ولادت (ہجری)',
    'وفات (ہجری)',
    'ولادت کا مقام',
    'وفات کا مقام',
    'حالت',
    'طبقہ (دور)',
    'شغل',
    'وثاقت',
    'مشہور کیوں ہیں',
    'اہم اساتذہ',
    'اہم شاگرد',
    'اہم کتب',
    'اضافی نوٹس',
  ],
};

function narratorCardHtml(name) {
  return `
    <div class="narrator-card">
      <button type="button" class="narrator-name-link" data-narrator="${escapeHtml(name)}">${escapeHtml(name)}</button>
    </div>`;
}

const narratorPackCache = {};
let narratorCatalogPromise = null;
let narratorCatalog = null;

function normalizeNarratorKey(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[ʼ'`´]/g, "'")
    .replace(/[^\w\u0600-\u06ff\s-]/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

async function loadNarratorCatalog() {
  if (narratorCatalog) return narratorCatalog;
  if (narratorCatalogPromise) return narratorCatalogPromise;
  narratorCatalogPromise = (async () => {
    try {
      narratorCatalog = await fetchJsonGz(`data/narrators/catalog.json.gz?v=hadith-reader-73`);
      return narratorCatalog;
    } catch (_) {
      narratorCatalog = null;
      return null;
    }
  })();
  return narratorCatalogPromise;
}

function catalogEntryByName(name) {
  if (!narratorCatalog || !name) return null;
  const key = normalizeNarratorKey(name);
  const id = narratorCatalog.aliases?.[key];
  if (!id) return null;
  const row = narratorCatalog.narrators?.[String(id)];
  if (!row) return null;
  return { ...row, narrator_id: row.id, order: null, role: null };
}

async function loadNarratorSanadPack(bookSlug, hadithNumber) {
  const key = `${bookSlug}:${hadithNumber}`;
  if (narratorPackCache[key] !== undefined) return narratorPackCache[key];
  // Rich per-hadith packs (e.g. Bukhari 1 classical import) take priority.
  const path = `data/narrators/${bookSlug}-${hadithNumber}.json`;
  try {
    const res = await fetch(`${path}?v=hadith-reader-66`);
    if (!res.ok) {
      narratorPackCache[key] = null;
      return null;
    }
    const data = await res.json();
    narratorPackCache[key] = data;
    return data;
  } catch (_) {
    narratorPackCache[key] = null;
    return null;
  }
}

function findImportedNarrator(pack, name) {
  if (!pack || !Array.isArray(pack.chain)) return null;
  const needle = String(name || '').trim().toLowerCase();
  if (!needle) return null;
  return pack.chain.find((n) => {
    const keys = [n.name_ar, n.name_en, n.name_ur, n.full_name, n.kunyah, n.laqab, n.slug]
      .filter(Boolean)
      .map((s) => String(s).toLowerCase());
    return keys.some((k) => k === needle || k.includes(needle) || needle.includes(k));
  }) || null;
}

function formatNarratorCitation(row) {
  if (!row) return '';
  const book = String(row.source_name || '').trim();
  const author = String(row.source_author || row.author_en || '').trim();
  const volume = String(row.volume || '').trim();
  const page = String(row.page || '').trim();
  const edition = String(row.edition || row.source_edition || '').trim();
  const publisher = String(row.publisher || row.source_publisher || '').trim();
  const lines = [];
  if (book) lines.push(book);
  if (author) lines.push(author);
  if (volume) lines.push(`Vol. ${volume}`);
  if (page) lines.push(`Page ${page}`);
  if (edition) lines.push(`Edition: ${edition}`);
  if (publisher) lines.push(`Publisher: ${publisher}`);
  if (!lines.length) return '';
  return `Reference:\n${lines.join('\n')}`;
}

/** Build the standard راوی معلومات table values from an imported entry (or empty). */
function narratorDetailValues(entry) {
  if (!entry) {
    return NARRATOR_PROFILE.fieldLabels.map(() => '');
  }
  const hasAr = (s) => /[\u0600-\u06FF]/.test(String(s || ''));
  const nameAr = entry.name_ar || (hasAr(entry.full_name) ? entry.full_name : '');
  const nameUr = entry.name_ur || (hasAr(entry.full_name) ? entry.full_name : '') || entry.name_en || '';
  const status = entry.is_companion
    ? 'صحابی'
    : (entry.role === 'prophet'
      ? 'رسول اللہ ﷺ'
      : (entry.role === 'compiler' ? 'امام' : ''));

  const appendCite = (value, fieldKey) => {
    const cites = Array.isArray(entry.field_citations) ? entry.field_citations : [];
    const blocks = cites
      .filter((c) => String(c.field_key || '') === fieldKey)
      .map(formatNarratorCitation)
      .filter(Boolean);
    const v = String(value || '').trim();
    if (!v && !blocks.length) return '';
    if (!blocks.length) return v;
    if (!v) return blocks.join('\n\n');
    return `${v}\n\n${blocks.join('\n\n')}`;
  };

  return [
    entry.narrator_id != null ? String(entry.narrator_id) : (entry.id != null ? String(entry.id) : ''),
    nameAr || '',
    nameUr || '',
    appendCite(entry.kunyah || '', 'kunyah'),
    appendCite(entry.laqab || '', 'laqab'),
    appendCite(entry.nasab || '', 'nasab'),
    appendCite('', 'tribe'),
    appendCite(entry.birth_hijri || entry.birth_text || '', 'birth_hijri'),
    appendCite(entry.death_hijri || entry.death_text || '', 'death_hijri'),
    appendCite(entry.city || '', 'birth_place'),
    appendCite('', 'death_place'),
    appendCite(status, 'status'),
    appendCite(entry.generation || '', 'generation'),
    appendCite('', 'occupation'),
    appendCite('', 'reliability'),
    appendCite('', 'known_for'),
    appendCite('', 'teachers'),
    appendCite('', 'students'),
    appendCite('', 'books'),
    appendCite(entry.timeline_notes || '', 'notes'),
  ];
}

function narratorDetailTableHtml(values) {
  const rows = NARRATOR_PROFILE.fieldLabels.map((label, i) => `
    <tr>
      <th scope="row">${escapeHtml(label)}</th>
      <td dir="auto">${escapeHtml(values[i] || '')}</td>
    </tr>`).join('');
  return `
    <table class="rawi-info-table" dir="rtl">
      <thead>
        <tr><th colspan="2">راوی معلومات</th></tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`;
}

function openNarratorDetailPage(name, hadith, entry) {
  const clean = String(name || '').trim() || 'Narrator';
  const values = narratorDetailValues(entry || null);
  const slug = state.hadithSlug || '';
  const rows = state.hadithReaderRows || [];
  const index = state.hadithReaderIndex || 0;

  $('hadith-view').innerHTML = `
    <article class="narrator-detail-page" id="narrator-detail-page">
      <header class="hadith-reader-top">
        <button type="button" class="ghost back-hadith" data-back-narrator>← Back</button>
      </header>
      <div class="narrator-detail-wrap">
        ${narratorDetailTableHtml(values)}
      </div>
    </article>`;

  const root = $('narrator-detail-page');
  root.querySelector('[data-back-narrator]').onclick = () => {
    if (rows.length) openHadithReader(slug, rows, index);
    else if (hadith && slug) {
      // Fallback: reopen reader for current hadith if chain available.
      openHadithReader(slug, [hadith], 0);
    }
  };
}

async function openNarratorMore(name, hadith) {
  const clean = String(name || '').trim();
  if (!clean) return;
  const slug = state.hadithSlug || '';
  await loadNarratorCatalog();
  const pack = await loadNarratorSanadPack(slug, hadith?.n);
  const entry = findImportedNarrator(pack, clean)
    || (pack?.chain || []).find((n) => Number(n.order) && String(n.name_en).toLowerCase() === clean.toLowerCase())
    || (pack?.chain || []).find((n) => Number(n.narrator_id) && String(n.narrator_id) === clean)
    || catalogEntryByName(clean);
  openNarratorDetailPage(clean, hadith, entry || null);
}

async function openRaviDetail(hadith, book) {
  const lang = state.hadithLang || 'ur';
  const t = raviCopy(lang);
  const slug = state.hadithSlug || book?.slug || '';
  const pack = await loadNarratorSanadPack(slug, hadith.n);
  const byLang = hadith.ravi_by_lang || {};
  let chain = (Array.isArray(byLang[lang]) && byLang[lang].length
    ? byLang[lang]
    : (hadith.ravi_chain || [])).filter(Boolean);
  let chainMeta = null;
  if (pack && Array.isArray(pack.chain) && pack.chain.length) {
    chainMeta = pack.chain;
    chain = pack.chain.map((n) => (lang === 'ar' ? n.name_ar : (lang === 'en' ? n.name_en : n.name_ur)) || n.name_ar || n.name_en);
  }
  const isnads = hadith.isnad_by_lang || {};
  const isnadText = (isnads[lang] || (lang === 'ur' ? hadith.isnad_ur : hadith.isnad) || '').trim();
  const rtl = lang === 'ur' || lang === 'ar';
  const primary = authenticatedNarratorName(hadith);
  let body = '';
  if (chain.length) {
    body += `
      <ol class="ravi-chain" dir="auto">
        ${chain.map((name, i) => {
          const meta = chainMeta ? chainMeta[i] : null;
          const isLast = i === chain.length - 1;
          const heard = meta
            ? `Order ${meta.order} · ${meta.role}${meta.kunyah ? ` · ${meta.kunyah}` : ''}`
            : (i === 0 ? t.first : (isLast ? t.last : t.mid));
          const key = meta ? (meta.name_en || meta.name_ar || name) : name;
          return `<li class="${isLast ? 'is-last-rawi' : ''}">
            <span class="ravi-step">${meta ? meta.order : (i + 1)}</span>
            <div>
              <button type="button" class="narrator-name-link" data-narrator="${escapeHtml(key)}">${escapeHtml(name)}</button>
              <small>${escapeHtml(heard)}</small>
            </div>
          </li>`;
        }).join('')}
      </ol>`;
  } else if (primary) {
    body += narratorCardHtml(primary);
  } else {
    body += `<p class="empty" dir="${rtl ? 'rtl' : 'ltr'}">${escapeHtml(t.empty)}</p>`;
  }
  if (isnadText) {
    body += `<div class="isnad-box"><span>${escapeHtml(t.isnad)}</span><p class="${lang === 'en' ? 'en' : (lang === 'ar' ? 'ar' : 'ur isnad-highlight')}" dir="${rtl ? 'rtl' : 'ltr'}">${escapeHtml(isnadText)}</p></div>`;
  }
  openHadithModal(`${t.title} · Hadith ${hadith.n}`, body);
  const modal = document.getElementById('hadith-detail-modal');
  modal?.querySelectorAll('[data-narrator]').forEach((btn) => {
    btn.onclick = () => {
      closeHadithModal();
      openNarratorMore(btn.getAttribute('data-narrator') || '', hadith);
    };
  });
}

function openReferenceDetail(hadith, book) {
  const grade = hadith.grade || hadith.reference_detail?.status || 'Grade not verified.';
  const chapter = hadith.kitab || state.hadithTopicTitle || '';
  // Do not show external Reference URL / Source Provider (sunnah.com, fawazahmed0, etc.).
  const rows = [
    ['Book', book?.en || ''],
    ['Chapter', chapter],
    ['Hadith Number', String(hadith.n)],
    ['Grade', grade],
  ];
  const body = `
    <table class="ref-table ref-table-shot">
      <tbody>
        ${rows.map(([label, value]) => `
          <tr>
            <th>${escapeHtml(label)}</th>
            <td dir="auto">${escapeHtml(value || '—')}</td>
          </tr>`).join('')}
      </tbody>
    </table>
  `;
  openHadithModal(`Reference · Hadith ${hadith.n}`, body, { darkTable: true });
}

function hasAuthenticatedArabic(text) {
  const t = String(text || '').trim();
  if (!t) return false;
  return /[\u0600-\u06FF]/.test(t);
}

function translationFor(hadith, lang) {
  if (lang === 'en') return hadith.en || '';
  if (lang === 'ar') return hadith.ar || '';
  if (lang === 'hi') return hadith.hi || hadith.hindi || '';
  return hadith.ur || '';
}

function ttsLocaleCandidates(lang) {
  if (lang === 'ur') return ['ur-PK', 'ur'];
  if (lang === 'ar') return ['ar-SA', 'ar-EG', 'ar'];
  if (lang === 'hi') return ['hi-IN', 'hi'];
  /* English: prefer South-Asian male clarity over fast British/US female voices. */
  return ['en-IN', 'en-PK', 'en-GB', 'en-US', 'en'];
}

function ttsLocaleFor(lang) {
  return ttsLocaleCandidates(lang)[0];
}

function ensureVoicesLoaded() {
  return new Promise((resolve) => {
    if (!window.speechSynthesis) {
      resolve([]);
      return;
    }
    const existing = window.speechSynthesis.getVoices() || [];
    if (existing.length) {
      resolve(existing);
      return;
    }
    const done = () => {
      window.speechSynthesis.removeEventListener('voiceschanged', done);
      resolve(window.speechSynthesis.getVoices() || []);
    };
    window.speechSynthesis.addEventListener('voiceschanged', done);
    setTimeout(done, 400);
  });
}

function voiceGenderScore(name) {
  const s = String(name || '').toLowerCase();
  if (/(female|woman|girl|zira|susan|samantha|karen|moira|tessa|fiona|veena|lekha|nicky|helena|linda|hazel|serena|allison|ava|kathy|victoria|salli)/.test(s)) {
    return 80;
  }
  if (/(male|man|boy|maged|naayf|najib|khaled|khalid|omar|ahmed|mohamed|mohammed|hassan|hussain|ravi|asif|farhan|daniel|david|mark|george|thomas|james|ryan|alex|google uk english male|google us english)/.test(s)) {
    return 0;
  }
  /* Unknown gender — slight penalty vs known male. */
  return 25;
}

function pickVoice(lang) {
  if (!window.speechSynthesis) return null;
  const voices = window.speechSynthesis.getVoices() || [];
  if (!voices.length) return null;
  const locales = ttsLocaleCandidates(lang).map((l) => l.toLowerCase());
  const primary = locales[0].slice(0, 2);

  const scored = voices
    .map((v) => {
      const code = (v.lang || '').toLowerCase();
      const label = `${v.name || ''} ${v.voiceURI || ''}`.toLowerCase();
      let score = 1000;
      const exact = locales.findIndex((l) => code === l || code.replace('_', '-') === l);
      if (exact >= 0) score = exact * 10;
      else if (code.startsWith(primary)) score = 40 + locales.length;
      else return null;

      score += voiceGenderScore(label);
      if (/(enhanced|premium|neural|natural|offline|compact|quality)/.test(label)) score -= 5;
      if (lang === 'ar' && /(saudi|egypt|egyptian|ksa|maged|naayf)/.test(label + code)) score -= 8;
      if (lang === 'ur' && /(pakistan|urdu)/.test(label + code)) score -= 8;
      if (lang === 'en' && /(india|pakistan|hindi)/.test(label + code)) score -= 6;
      if (lang === 'en' && /(british|uk english female|zira|samantha)/.test(label)) score += 30;
      return { v, score };
    })
    .filter(Boolean)
    .sort((a, b) => a.score - b.score);

  return scored.length ? scored[0].v : null;
}

function clearHadithSpeechWatch() {
  if (state.hadithSpeechWatch) {
    clearInterval(state.hadithSpeechWatch);
    state.hadithSpeechWatch = null;
  }
}

function stopHadithSpeech() {
  clearHadithSpeechWatch();
  if (window.speechSynthesis) window.speechSynthesis.cancel();
  state.ttsUtterance = null;
  state.hadithSpeechPaused = false;
}

function pauseHadithSpeech() {
  if (!window.speechSynthesis) return;
  if (window.speechSynthesis.speaking && !window.speechSynthesis.paused) {
    window.speechSynthesis.pause();
    state.hadithSpeechPaused = true;
  }
}

function resumeHadithSpeech() {
  if (!window.speechSynthesis) return;
  if (window.speechSynthesis.paused) {
    window.speechSynthesis.resume();
    state.hadithSpeechPaused = false;
  }
}

async function speakHadithText(text, lang) {
  const clean = String(text || '').trim();
  if (!clean) {
    toast('No authentic reference found.');
    return;
  }
  if (!window.speechSynthesis) {
    toast('Speech audio is not supported in this browser.');
    return;
  }
  stopHadithSpeech();
  await ensureVoicesLoaded();
  /* Chrome cancels if speak() is called in the same tick as cancel(). */
  await new Promise((r) => setTimeout(r, 60));

  const utter = new SpeechSynthesisUtterance(clean);
  const voice = pickVoice(lang);
  if (voice) {
    utter.voice = voice;
    utter.lang = voice.lang || ttsLocaleFor(lang);
  } else {
    utter.lang = ttsLocaleFor(lang);
  }
  const speed = Number(state.hadithSpeechRate) || 1;
  /* Calm scholarly pace — English especially kept slower for clarity. */
  const base = lang === 'ar' ? 0.72 : (lang === 'en' ? 0.82 : 0.88);
  utter.rate = Math.max(0.55, Math.min(1.35, base * speed));
  utter.pitch = 0.92;
  utter.onend = () => {
    clearHadithSpeechWatch();
    state.hadithSpeechPaused = false;
    state.ttsUtterance = null;
  };
  utter.onerror = () => {
    clearHadithSpeechWatch();
    state.hadithSpeechPaused = false;
    state.ttsUtterance = null;
  };
  state.ttsUtterance = utter;
  window.speechSynthesis.speak(utter);

  /* Keep speech continuous: resume if Chrome auto-pauses; nudge if it stalls. */
  clearHadithSpeechWatch();
  let ticks = 0;
  state.hadithSpeechWatch = setInterval(() => {
    if (!window.speechSynthesis) return;
    if (!window.speechSynthesis.speaking && !window.speechSynthesis.pending) {
      clearHadithSpeechWatch();
      return;
    }
    if (state.hadithSpeechPaused) return;
    if (window.speechSynthesis.paused) {
      window.speechSynthesis.resume();
      return;
    }
    ticks += 1;
    if (ticks % 24 === 0) {
      try {
        window.speechSynthesis.pause();
        window.speechSynthesis.resume();
      } catch (_) { /* ignore */ }
    }
  }, 500);
}

function chapterRangeForHadith(pack, hadith) {
  if (!pack || !hadith) return null;
  const key = kitabTopicKey(hadith);
  const peers = (pack.hadiths || []).filter((h) => kitabTopicKey(h) === key);
  if (!peers.length) {
    return { first: hadith.n, last: hadith.n, count: 1 };
  }
  // Numbered range excludes preface (n<=0) and empty slots. MOQDEMA is never counted.
  const numbered = countedHadithRows(peers);
  const use = numbered.length ? numbered : peers;
  let first = use[0].n;
  let last = use[0].n;
  for (const h of use) {
    if (h.n < first) first = h.n;
    if (h.n > last) last = h.n;
  }
  return { first, last, count: use.length };
}

function hadithDisplayN(hadith) {
  const disp = hadith?.display_n || hadith?.reference_detail?.hadith_number;
  if (disp != null && String(disp).trim() && String(disp) !== 'preface') return String(disp).trim();
  return String(hadith?.n ?? '');
}

function openHadithReader(slug, rows, index) {
  const pack = state.hadithCache[slug];
  if (!pack || !rows.length) {
    $('hadith-view').innerHTML = '<p class="empty">No authentic reference found.</p>';
    return;
  }
  const safeIndex = Math.max(0, Math.min(index, rows.length - 1));
  state.hadithSlug = slug;
  state.hadithReaderRows = rows;
  state.hadithReaderIndex = safeIndex;
  const hadith = rows[safeIndex];
  if (!['ur', 'en', 'hi'].includes(state.hadithLang)) state.hadithLang = 'ur';
  const translationLang = state.hadithLang;
  const translation = translationFor(hadith, translationLang);
  const rtl = translationLang === 'ur' || translationLang === 'hi';
  const total = rows.length;
  const pos = safeIndex + 1;
  const topicTitle = state.hadithTopicTitle || localizedKitabName(hadith, pack);
  const subjectBadge =
    (hadith.reference_detail?.baab ||
      hadith.reference_detail?.by_lang?.ur?.values?.baab ||
      hadith.reference_detail?.by_lang?.ar?.values?.baab ||
      topicTitle ||
      '').trim() || topicTitle;
  const ref = hadith.reference || `${pack.book.en} · Hadith ${hadithDisplayN(hadith)}`;
  const progress = Math.round((pos / total) * 100);
  // Always show authentic کتاب span on the right (e.g. Hadith 135 to 247).
  const span = chapterRangeForHadith(pack, hadith);
  const isPreface = Number(hadith.n) <= 0;
  const dispN = hadithDisplayN(hadith);
  // Current number must change on Next/Previous. Range is secondary context only.
  const countLabel = isPreface
    ? (span && span.first != null ? `المقدمة · before Hadith ${span.first} to ${span.last}` : 'المقدمة')
    : (span && span.first != null && span.last != null && Number(span.first) !== Number(span.last)
      ? `Hadith ${dispN} · ${span.first} to ${span.last}`
      : `Hadith ${dispN}`);

  $('hadith-view').innerHTML = `
    <article class="hadith-reader" id="hadith-reader">
      <header class="hadith-reader-top">
        <button type="button" class="ghost back-hadith" data-back>← Back</button>
        <div class="hadith-reader-actions">
          <button type="button" class="icon-btn" data-act="bookmark" title="Bookmark">Bookmark</button>
          <button type="button" class="icon-btn" data-act="share" title="Share">Share</button>
          <button type="button" class="icon-btn" data-act="search" title="Search">Search</button>
        </div>
      </header>
      <div class="hadith-reader-heading">
        <div class="hadith-reader-heading-row">
          <p class="hadith-reader-book">${escapeHtml(pack.book.en)}</p>
          <span class="hadith-subject-badge" dir="rtl">${escapeHtml(subjectBadge)}</span>
        </div>
        <p class="hadith-reader-count">${escapeHtml(countLabel)}</p>
        <div class="hadith-progress" aria-hidden="true"><span style="width:${progress}%"></span></div>
      </div>

      <section class="hadith-reader-arabic">
        <p class="ar hadith-arabic" dir="rtl">${hasAuthenticatedArabic(hadith.ar) ? escapeHtml(hadith.ar) : 'Arabic text unavailable in authenticated source.'}</p>
      </section>

      <section class="hadith-reader-translation">
        <label class="lang-dropdown">
          <span>Translation</span>
          <select id="hadith-lang-select" aria-label="Translation language">
            <option value="ur" ${translationLang === 'ur' ? 'selected' : ''}>Urdu</option>
            <option value="en" ${translationLang === 'en' ? 'selected' : ''}>English</option>
            <option value="hi" ${translationLang === 'hi' ? 'selected' : ''}>Hindi</option>
          </select>
        </label>
        <div class="hadith-translation ${rtl ? 'rtl' : ''}" dir="${rtl ? 'rtl' : 'ltr'}">
          ${translation
            ? `<p class="${translationLang === 'ur' ? 'ur' : 'en'}">${escapeHtml(translation)}</p>`
            : '<p class="empty">No authentic reference found.</p>'}
        </div>
      </section>

      <section class="hadith-audio-box hadith-reader-audio" aria-label="Hadith audio">
        <div class="hadith-audio-head">
          <strong>Audio</strong>
        </div>
        <div class="hadith-audio-actions hadith-audio-controls">
          <button type="button" class="hadith-audio-play" data-audio="play">▶ Play</button>
          <button type="button" class="hadith-audio-stop" data-audio="pause">Pause</button>
          <button type="button" class="hadith-audio-stop" data-audio="stop">Stop</button>
          <button type="button" class="hadith-audio-play" data-audio="replay">Replay</button>
        </div>
      </section>

      <div class="hadith-reader-tools">
        <button type="button" class="hadith-action" data-act="ravi">Ravi</button>
        <button type="button" class="hadith-action" data-act="reference">Reference</button>
        <button type="button" class="hadith-action" data-act="copy">Copy</button>
        <button type="button" class="hadith-action" data-act="share">Share</button>
        <button type="button" class="hadith-action" data-act="bookmark">Bookmark</button>
        <button type="button" class="hadith-action" data-act="notes">Notes</button>
      </div>

      <nav class="hadith-nav">
        <button type="button" class="hadith-nav-btn" data-nav="prev" ${safeIndex <= 0 ? 'disabled' : ''}>◀ Previous Hadith</button>
        <button type="button" class="hadith-nav-btn primary" data-nav="next" ${safeIndex >= total - 1 ? 'disabled' : ''}>Next Hadith ▶</button>
      </nav>
    </article>
  `;

  const root = $('hadith-reader');
  const rerender = (nextIndex) => openHadithReader(slug, rows, nextIndex);
  root.querySelector('[data-back]').onclick = () => clearHadithTopic(slug);

  root.querySelector('#hadith-lang-select').onchange = (e) => {
    state.hadithLang = e.target.value;
    localStorage.setItem('i307_hadith_lang', state.hadithLang);
    stopHadithSpeech();
    rerender(safeIndex);
  };

  const playCurrent = () => {
    speakHadithText(hadith.ar || '', 'ar');
  };
  root.querySelector('[data-audio="play"]').onclick = () => {
    if (state.hadithSpeechPaused) resumeHadithSpeech();
    else playCurrent();
  };
  root.querySelector('[data-audio="pause"]').onclick = () => pauseHadithSpeech();
  root.querySelector('[data-audio="stop"]').onclick = () => stopHadithSpeech();
  root.querySelector('[data-audio="replay"]').onclick = () => playCurrent();

  root.querySelector('[data-nav="prev"]').onclick = () => {
    if (safeIndex > 0) { stopHadithSpeech(); rerender(safeIndex - 1); $('hadith-view').scrollTop = 0; }
  };
  root.querySelector('[data-nav="next"]').onclick = () => {
    if (safeIndex < total - 1) { stopHadithSpeech(); rerender(safeIndex + 1); $('hadith-view').scrollTop = 0; }
  };

  root.querySelector('[data-act="ravi"]').onclick = () => openRaviDetail(hadith, pack.book);
  root.querySelector('[data-act="reference"]').onclick = () => openReferenceDetail(hadith, pack.book);

  const copyShareText = () => [
    `${pack.book.en} · Hadith ${hadith.n}`,
    topicTitle,
    hadith.ar || '',
    translation || '',
    ref,
  ].filter(Boolean).join('\n\n');

  root.querySelectorAll('[data-act="copy"]').forEach((btn) => {
    btn.onclick = async () => { await navigator.clipboard.writeText(copyShareText()); toast('Copied'); };
  });
  root.querySelectorAll('[data-act="share"]').forEach((btn) => {
    btn.onclick = async () => {
      const text = copyShareText();
      if (navigator.share) { try { await navigator.share({ title: `${pack.book.en} ${hadith.n}`, text }); } catch {} }
      else { await navigator.clipboard.writeText(text); toast('Share text copied'); }
    };
  });
  root.querySelectorAll('[data-act="bookmark"]').forEach((btn) => {
    btn.onclick = () => {
      const lib = ensureUserLibrary();
      const key = `hadith:${slug}:${hadith.n}`;
      const i = lib.bookmarks.indexOf(key);
      if (i >= 0) lib.bookmarks.splice(i, 1); else lib.bookmarks.push(key);
      saveUserLibrary(lib);
      toast(i >= 0 ? 'Bookmark removed' : 'Bookmarked');
    };
  });
  root.querySelector('[data-act="notes"]').onclick = () => {
    const lib = ensureUserLibrary();
    const key = `hadith:${slug}:${hadith.n}`;
    const next = prompt(`Note for ${pack.book.en} ${hadith.n}`, lib.notes[key] || '');
    if (next === null) return;
    if (!next.trim()) delete lib.notes[key]; else lib.notes[key] = next.trim();
    saveUserLibrary(lib);
    toast('Note saved');
  };
  root.querySelector('[data-act="search"]').onclick = () => { const input = $('hadith-search'); if (input) input.focus(); };

  let touchX = null;
  root.ontouchstart = (e) => { touchX = e.changedTouches[0].screenX; };
  root.ontouchend = (e) => {
    if (touchX == null) return;
    const dx = e.changedTouches[0].screenX - touchX;
    touchX = null;
    if (Math.abs(dx) < 60) return;
    if (dx < 0 && safeIndex < total - 1) { stopHadithSpeech(); rerender(safeIndex + 1); $('hadith-view').scrollTop = 0; }
    else if (dx > 0 && safeIndex > 0) { stopHadithSpeech(); rerender(safeIndex - 1); $('hadith-view').scrollTop = 0; }
  };
}

function openHadithDetail(slug, hadithNumber) {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  const n = Number(hadithNumber);
  const allTopic = state.hadithTopicKey
    ? (pack.hadiths || []).filter((h) => kitabTopicKey(h) === state.hadithTopicKey)
    : (state.hadithReaderRows && state.hadithReaderRows.length
      ? state.hadithReaderRows
      : (pack.hadiths || []));
  const numbered = countedHadithRows(allTopic);
  const preface = prefaceHadithRows(allTopic);

  // Automatic Next/Previous for "Hadith 1 to N" never includes MOQDEMA (n <= 0).
  // Opening a preface row can still Next into Hadith 1, then 2…N.
  let scope;
  if (Number.isFinite(n) && n <= 0 && (preface.length || numbered.length)) {
    scope = preface.concat(numbered);
  } else if (numbered.length) {
    scope = numbered;
  } else {
    scope = allTopic;
  }
  const idx = scope.findIndex((h) => Number(h.n) === n);
  openHadithReader(slug, scope.length ? scope : pack.hadiths, idx >= 0 ? idx : 0);
}

function isHadithNumberQuery(filter) {
  return /^\d+$/.test(String(filter || '').trim());
}

async function ensureHadithPack(slug) {
  if (!state.hadithCache[slug]) {
    state.hadithCache[slug] = await fetchJsonGz(`data/hadith/${slug}.json.gz`);
  }
  return state.hadithCache[slug];
}

/** Exact hadith-number search — works with or without a selected collection. */
async function searchHadithByNumber(rawQuery) {
  const q = String(rawQuery || '').trim();
  const n = Number(q);
  if (!Number.isFinite(n) || n < 1) {
    $('hadith-view').innerHTML = '<p class="empty">Enter a valid hadith number (e.g. 1 or 7048).</p>';
    return;
  }

  state.hadithFilter = q;
  const active = $('hadith-books')?.querySelector('button.active');
  let books = state.hadithBooks || [];
  if (active) {
    const idx = Array.from($('hadith-books').children).indexOf(active);
    if (idx >= 0 && state.hadithBooks[idx]) books = [state.hadithBooks[idx]];
  }

  $('hadith-view').innerHTML = `<p class="status">Searching Hadith ${n}…</p>`;
  const results = [];
  await Promise.all(
    books.map(async (book) => {
      try {
        const pack = await ensureHadithPack(book.slug);
        const hit = (pack.hadiths || []).find((h) => Number(h.n) === n);
        if (hit) results.push({ book, pack, hadith: hit });
      } catch (err) {
        console.warn('Hadith pack load failed', book.slug, err);
      }
    }),
  );
  results.sort((a, b) => String(a.book.en).localeCompare(String(b.book.en)));
  paintHadithNumberSearchResults(n, results, !active);
}

function paintHadithNumberSearchResults(n, results, crossBook) {
  const scope = crossBook ? 'all collections' : (results[0]?.book?.en || 'this collection');
  $('hadith-view').innerHTML = `
    <div class="hadith-browse-head">
      <div>
        <p class="hadith-browse-kicker">Hadith number search</p>
        <h2 class="hadith-browse-title">Hadith ${n}</h2>
        <p class="hadith-browse-sub">${results.length.toLocaleString()} match${results.length === 1 ? '' : 'es'} in ${escapeHtml(scope)}</p>
      </div>
    </div>
    <p class="hadith-list-hint">Tap a result to open Language · Ravi · Reference · Audio.</p>
    <div class="hadith-number-list" id="hadith-search-results"></div>
  `;
  const list = $('hadith-search-results');
  if (!results.length) {
    list.innerHTML = `<p class="empty">No Hadith ${n} found${crossBook ? ' in the offline collections' : ' in this collection'}.</p>`;
    return;
  }
  const frag = document.createDocumentFragment();
  results.forEach(({ book, pack, hadith }) => {
    const row = document.createElement('div');
    row.className = 'hadith-number-row';
    row.dataset.n = String(hadith.n);
    const kitabName = localizedKitabName(hadith, pack);
    row.innerHTML = `
      <button type="button" class="hadith-n-btn" data-act="open-hadith" aria-label="Open ${escapeHtml(book.en)} Hadith ${hadith.n}">
        <span class="hadith-n">${escapeHtml(book.en)} · Hadith ${hadith.n}</span>
      </button>
      <button type="button" class="hadith-kitab-btn" data-act="open-topic" title="Open all hadith in this topic">
        <p class="hadith-kitab" dir="rtl">${escapeHtml(kitabName)}</p>
        <span class="hadith-kitab-hint">Open topic →</span>
      </button>
    `;
    row.querySelector('[data-act="open-hadith"]').onclick = () => {
      // Mark the matching book active so back-navigation stays coherent.
      const btn = Array.from($('hadith-books').children).find((el, i) => state.hadithBooks[i]?.slug === book.slug);
      if (btn) {
        $('hadith-books').querySelectorAll('button').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
      }
      state.hadithSlug = book.slug;
      state.hadithTopicKey = null;
      state.hadithTopicTitle = '';
      state.hadithReaderRows = [];
      openHadithDetail(book.slug, hadith.n);
    };
    row.querySelector('[data-act="open-topic"]').onclick = () => {
      const btn = Array.from($('hadith-books').children).find((el, i) => state.hadithBooks[i]?.slug === book.slug);
      if (btn) {
        $('hadith-books').querySelectorAll('button').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
      }
      state.hadithSlug = book.slug;
      openHadithTopic(book.slug, {
        key: kitabTopicKey(hadith),
        title: kitabName,
        kitab_number: hadith.kitab_number,
        en: hadith.kitab || '',
      });
    };
    frag.appendChild(row);
  });
  list.appendChild(frag);
}

function renderHadithList(slug, filter = '') {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  state.hadithSlug = slug;
  state.hadithFilter = filter;
  const raw = filter.trim();

  // Number query → show matching hadith(s), not topics.
  if (isHadithNumberQuery(raw)) {
    searchHadithByNumber(raw);
    return;
  }

  const q = raw.toLowerCase();

  // Always show Topics hub. Selecting a topic opens the full Hadith Reader directly.
  let topics = buildKitabTopics(pack);
  if (q) {
    topics = topics.filter((t) =>
      String(t.kitab_number || '').includes(q) ||
      (t.title || '').toLowerCase().includes(q) ||
      (t.title || '').includes(filter) ||
      (t.en || '').toLowerCase().includes(q)
    );
  }
  paintHadithTopics(slug, pack, topics);
}

function paintHadithTopics(slug, pack, topics) {
  const q = (state.hadithFilter || '').trim();
  const preface = prefaceHadithRows(pack.hadiths || []);
  const showPreface = preface.length > 0 && (!q || 'moqdema muqaddimah introduction المقدمة'.includes(q.toLowerCase()));
  $('hadith-view').innerHTML = `
    <div class="hadith-browse-head hadith-topic-head">
      <p class="hadith-browse-kicker">${escapeHtml(pack.book.en)}</p>
      <h2 class="hadith-browse-title" dir="rtl">موضوعات · کتب</h2>
      <button type="button" class="hadith-action" data-act="read-all">Read all ▶</button>
    </div>
    <div class="hadith-topic-grid" id="hadith-topic-grid"></div>
  `;
  $('hadith-view').onscroll = null;
  $('hadith-view').querySelector('[data-act="read-all"]').onclick = () => openHadithBookReader(slug);

  const grid = $('hadith-topic-grid');
  if (!topics.length && !showPreface) {
    grid.innerHTML = '<p class="empty">No topics match this search.</p>';
    return;
  }
  const frag = document.createDocumentFragment();
  if (showPreface) {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'hadith-topic-card';
    card.innerHTML = `
      <div class="hadith-topic-index">00</div>
      <div class="hadith-topic-main">
        <p class="hadith-topic-title" dir="rtl">المقدمة</p>
      </div>
      <div class="hadith-topic-side">
        <span class="hadith-topic-range">Before Hadith 1</span>
        <span class="hadith-topic-count-label">${preface.length.toLocaleString()} entries</span>
      </div>
    `;
    card.onclick = () => openHadithPreface(slug);
    frag.appendChild(card);
  }
  topics.forEach((t, idx) => {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'hadith-topic-card';
    const indexLabel = t.key === 'unassigned'
      ? '—'
      : String(t.kitab_number || idx + 1).padStart(2, '0');
    card.innerHTML = `
      <div class="hadith-topic-index">${indexLabel}</div>
      <div class="hadith-topic-main">
        <p class="hadith-topic-title" dir="rtl">${escapeHtml(t.title || t.en || '—')}</p>
      </div>
      <div class="hadith-topic-side">
        <span class="hadith-topic-range">${escapeHtml(topicRangeLabel(t))}</span>
        <span class="hadith-topic-count-label">${t.count.toLocaleString()} Hadith</span>
      </div>
    `;
    card.onclick = () => openHadithTopic(slug, t);
    frag.appendChild(card);
  });
  grid.appendChild(frag);
}

function scheduleFillAllHadith(slug) {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  const rows = state.hadithListRows || [];
  if (state.hadithListShown >= rows.length) return;
  requestAnimationFrame(() => {
    if (state.hadithSlug !== slug) return;
    if (state.hadithBrowseMode === 'topics' && !state.hadithTopicKey) return;
    state.hadithListShown = Math.min(rows.length, state.hadithListShown + state.hadithListPage);
    paintHadithListPage(slug, pack, false);
    scheduleFillAllHadith(slug);
  });
}

function paintHadithListPage(slug, pack, reset = false) {
  const rows = state.hadithListRows || [];
  const shown = state.hadithListShown || 0;
  const visible = rows.slice(0, shown);
  const totalAll = (pack.hadiths || []).length;
  const q = (state.hadithFilter || '').trim();
  const done = shown >= rows.length;
  const inTopic = !!state.hadithTopicKey;
  const status = inTopic
    ? `${state.hadithTopicTitle} · ${rows.length.toLocaleString()} related hadith · ${done ? 'all shown' : `loading ${visible.length.toLocaleString()}…`}`
    : q
      ? `${pack.book.en} · ${rows.length.toLocaleString()} matches · ${done ? 'all shown' : `loading ${visible.length.toLocaleString()}…`}`
      : `${pack.book.en} · full collection ${totalAll.toLocaleString()} hadith · ${done ? 'all numbers listed' : `loading ${visible.length.toLocaleString()}…`}`;

  if (reset) {
    const maxN = totalAll ? Math.max(...pack.hadiths.map((h) => h.n)) : 0;
    $('hadith-view').innerHTML = `
      <div class="hadith-browse-head compact">
        <div>
          ${inTopic ? `<button type="button" class="ghost back-hadith" data-act="back-topics">← All topics</button>` : ''}
          <p class="status" id="hadith-list-status">${escapeHtml(status)}</p>
          ${inTopic ? `<p class="hadith-topic-banner" dir="rtl">${escapeHtml(state.hadithTopicTitle)}</p>` : ''}
        </div>
        <div class="hadith-mode-toggle" role="tablist" aria-label="Browse mode">
          <button type="button" class="${state.hadithBrowseMode !== 'numbers' ? 'active' : ''}" data-hadith-mode="topics" aria-selected="${state.hadithBrowseMode !== 'numbers'}">Topics</button>
          <button type="button" class="${state.hadithBrowseMode === 'numbers' ? 'active' : ''}" data-hadith-mode="numbers" aria-selected="${state.hadithBrowseMode === 'numbers'}">All numbers</button>
        </div>
      </div>
      <p class="hadith-list-hint">${inTopic
        ? 'These are all authenticated hadith in this کتاب/topic. Tap a number to open Language · Ravi · Reference · Audio.'
        : `Tap the topic name to open that کتاب, or tap Hadith N to open the hadith. Type a number (1–${maxN}) in search to jump.`}</p>
      <div class="hadith-number-list" id="hadith-number-list"></div>
      <div class="hadith-list-more" id="hadith-list-more"></div>
    `;
    const scroller = $('hadith-view');
    scroller.onscroll = () => maybeLoadMoreHadith(slug);
    const back = $('hadith-view').querySelector('[data-act="back-topics"]');
    if (back) back.onclick = () => clearHadithTopic(slug);
    $('hadith-view').querySelectorAll('[data-hadith-mode]').forEach((btn) => {
      btn.onclick = () => {
        const mode = btn.getAttribute('data-hadith-mode');
        state.hadithTopicKey = null;
        state.hadithTopicTitle = '';
        setHadithBrowseMode(mode === 'numbers' ? 'numbers' : 'topics');
        renderHadithList(slug, state.hadithFilter);
      };
    });
  } else {
    const statusEl = $('hadith-list-status');
    if (statusEl) statusEl.textContent = status;
  }

  const list = $('hadith-number-list');
  if (!list) return;
  if (reset) list.innerHTML = '';

  const start = reset ? 0 : list.querySelectorAll('[data-n]').length;
  const frag = document.createDocumentFragment();
  for (let i = start; i < visible.length; i += 1) {
    const h = visible[i];
    const row = document.createElement('div');
    row.className = 'hadith-number-row';
    row.dataset.n = String(h.n);
    const kitabName = localizedKitabName(h, pack);
    const disp = hadithDisplayN(h);
    row.innerHTML = `
      <button type="button" class="hadith-n-btn" data-act="open-hadith" aria-label="Open Hadith ${escapeHtml(disp)}">
        <span class="hadith-n">Hadith ${escapeHtml(disp)}</span>
      </button>
      <button type="button" class="hadith-kitab-btn" data-act="open-topic" title="Open all hadith in this topic">
        <p class="hadith-kitab" dir="rtl">${escapeHtml(kitabName)}</p>
        <span class="hadith-kitab-hint">Open topic →</span>
      </button>
    `;
    row.querySelector('[data-act="open-hadith"]').onclick = () => openHadithDetail(slug, h.n);
    row.querySelector('[data-act="open-topic"]').onclick = () => {
      openHadithTopic(slug, {
        key: kitabTopicKey(h),
        title: kitabName,
        kitab_number: h.kitab_number,
        en: h.kitab || '',
      });
    };
    frag.appendChild(row);
  }
  list.appendChild(frag);

  const more = $('hadith-list-more');
  if (!more) return;
  if (!done && rows.length > 0) {
    more.innerHTML = `<button type="button" class="hadith-action" id="hadith-load-more">Show remaining ${(rows.length - shown).toLocaleString()} now</button>`;
    const btn = $('hadith-load-more');
    if (btn) {
      btn.onclick = () => {
        state.hadithListShown = rows.length;
        paintHadithListPage(slug, pack, false);
      };
    }
  } else if (rows.length === 0) {
    more.innerHTML = '<p class="empty">No matches.</p>';
  } else {
    more.innerHTML = `<p class="status">${inTopic ? 'All related hadith in this topic loaded' : `All ${rows.length.toLocaleString()} hadith loaded`} · Language / Ravi / Reference / Audio on every number</p>`;
  }
}

function loadMoreHadith(slug) {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  const rows = state.hadithListRows || [];
  if (state.hadithListShown >= rows.length) return;
  state.hadithListShown = Math.min(rows.length, state.hadithListShown + state.hadithListPage);
  paintHadithListPage(slug, pack, false);
}

function maybeLoadMoreHadith(slug) {
  const view = $('hadith-view');
  if (!view) return;
  if (view.scrollTop + view.clientHeight < view.scrollHeight - 200) return;
  const rows = state.hadithListRows || [];
  if (state.hadithListShown >= rows.length) return;
  loadMoreHadith(slug);
}

function renderTafsirSources() {
  const list = $('tafsir-sources');
  list.innerHTML = '';
  state.tafsirSources.forEach((source) => {
    const b = document.createElement('button');
    b.innerHTML = `<strong>${source.en}</strong><small>${source.ar || source.author || ''}</small>`;
    b.onclick = () => openTafsir(source, b);
    list.appendChild(b);
  });
}

async function openTafsir(source, button) {
  $('tafsir-sources').querySelectorAll('button').forEach((b) => b.classList.remove('active'));
  if (button) button.classList.add('active');
  const surah = Number($('tafsir-surah').value) || 1;
  const ayah = Number($('tafsir-ayah').value) || 1;
  $('tafsir-view').innerHTML = `<div class="tafsir-card">
    <div class="meta-row"><span>${escapeHtml(source.en)}</span><span>${surah}:${ayah}</span></div>
    <p class="empty">Unavailable in this static preview. The installed app retrieves verse-specific Tafseer from the authorized Quran Foundation Content API using short-lived credentials. No local Tafseer corpus or generated substitute is used.</p>
    <p class="status">Author: ${escapeHtml(source.author || '—')}<br>Source: Quran Foundation Content API<br>Reference: Quran ${surah}:${ayah}</p>
  </div>`;
}

$('quran-search').addEventListener('input', (e) => renderSurahList(e.target.value));
$('hadith-search').addEventListener('input', (e) => {
  const q = e.target.value || '';
  state.hadithFilter = q;
  const active = $('hadith-books').querySelector('button.active');

  // Number search works even before selecting a collection.
  if (isHadithNumberQuery(q)) {
    searchHadithByNumber(q);
    return;
  }

  if (!active) {
    if (!q.trim()) {
      $('hadith-view').innerHTML =
        '<p class="empty">Select a collection, or type a hadith number (e.g. <strong>1</strong> or <strong>7048</strong>) to search.</p>';
    } else {
      $('hadith-view').innerHTML =
        '<p class="empty">Select a collection to search topics, or type a hadith number to search all books.</p>';
    }
    return;
  }

  const idx = Array.from($('hadith-books').children).indexOf(active);
  const book = state.hadithBooks[idx];
  if (book) renderHadithList(book.slug, q);
});
$('tafsir-go').addEventListener('click', () => {
  const active = $('tafsir-sources').querySelector('button.active');
  if (!active) {
    const first = state.tafsirSources[0];
    if (first) openTafsir(first, $('tafsir-sources').querySelector('button'));
    return;
  }
  const idx = Array.from($('tafsir-sources').children).indexOf(active);
  openTafsir(state.tafsirSources[idx], active);
});

async function boot() {
  try {
    ensureUserLibrary();
    applyTheme();
    if (window.speechSynthesis) {
      window.speechSynthesis.getVoices();
      window.speechSynthesis.onvoiceschanged = () => window.speechSynthesis.getVoices();
    }
    const [surahPack, hadithPack] = await Promise.all([
      fetchJson('data/quran/surahs.json'),
      fetchJson('data/hadith/books.json'),
    ]);
    state.surahs = surahPack.surahs;
    state.hadithBooks = hadithPack.books;
    state.tafsirSources = QURAN_TAFSIR_OPTIONS.map((source, index) => ({
      id: index + 1,
      slug: source.id,
      en: source.label,
      ar: '',
      author: source.author,
      lang: '',
    }));
    renderSurahList();
    renderHadithBooks();
    renderTafsirSources();
    const params = new URLSearchParams(location.search);
    const surahParam = Number(params.get('surah') || 0);
    const tab = (location.hash || '#quran').replace(/^#/, '');
    setTab(['quran', 'hadith', 'tafsir'].includes(tab) ? tab : 'quran');
    if (surahParam >= 1 && surahParam <= 114) {
      const btn = Array.from($('surah-list').children).find((el) => el.textContent.startsWith(`${surahParam}.`));
      await openSurah(surahParam, btn || null);
    }
  } catch (err) {
    document.querySelector('main').innerHTML = `<p class="empty">Library data missing.</p><pre>${err.message}</pre>`;
  }
}

boot();
