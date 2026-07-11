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
  const res = await fetch(url);
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
};

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
  return `
    <div class="reader-tools">
      <button type="button" data-action="font-down">Aa −</button>
      <button type="button" data-action="font-up">Aa +</button>
      <button type="button" data-action="theme">${state.dark ? 'Light' : 'Dark'}</button>
      <span class="user-pill">Personal file · ${userId()}</span>
    </div>
    <p class="status">${surah.en} · ${surah.ar} · ${surah.ayahs} ayahs</p>
  `;
}

function ayahCardHtml(a, lib) {
  const key = ayahKey(a.s, a.a);
  const bookmarked = lib.bookmarks.includes(key);
  const highlighted = !!lib.highlights[key];
  const note = lib.notes[key] || '';
  return `
    <div class="ayah ${highlighted ? 'is-highlighted' : ''}" data-s="${a.s}" data-a="${a.a}">
      <div class="meta-row">
        <span>${a.s}:${a.a}${bookmarked ? ' ★' : ''}</span>
        <span>Page ${a.p} · Juz ${a.j}</span>
      </div>
      <p class="ar">${a.ar}</p>
      ${a.ur ? `<p class="en ur">${a.ur}</p>` : ''}
      ${a.en ? `<p class="en">${a.en}</p>` : ''}
      ${note ? `<div class="note-box">Note: ${escapeHtml(note)}</div>` : ''}
      <div class="ayah-tools">
        <button type="button" data-act="bookmark">${bookmarked ? 'Bookmarked' : 'Bookmark'}</button>
        <button type="button" data-act="highlight">${highlighted ? 'Unhighlight' : 'Highlight'}</button>
        <button type="button" data-act="note">Notes</button>
        <button type="button" data-act="copy">Copy</button>
        <button type="button" data-act="share">Share</button>
        <button type="button" data-act="recite" class="primary">Recite</button>
      </div>
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

async function openSurah(n, button) {
  await ensureAyahs();
  $('surah-list').querySelectorAll('button').forEach((b) => b.classList.remove('active'));
  if (button) button.classList.add('active');
  const surah = state.surahs.find((s) => s.n === n);
  const ayahs = state.ayahsBySurah.get(n) || [];
  if (!surah) {
    $('ayah-view').innerHTML = `<p class="empty">Surah ${n} not found.</p>`;
    return;
  }
  state.currentSurah = n;
  const lib = ensureUserLibrary();
  $('ayah-view').innerHTML = readerToolbarHtml(surah) + ayahs.map((a) => ayahCardHtml(a, lib)).join('');
  wireReaderEvents();
  if (history.replaceState) {
    const url = new URL(location.href);
    url.searchParams.set('surah', String(n));
    url.hash = 'quran';
    history.replaceState(null, '', url.toString());
  }
  $('ayah-view').scrollTop = 0;
}

function wireReaderEvents() {
  const view = $('ayah-view');
  view.querySelectorAll('[data-action]').forEach((btn) => {
    btn.onclick = () => {
      const act = btn.dataset.action;
      if (act === 'font-up') state.fontScale = Math.min(1.6, state.fontScale + 0.1);
      if (act === 'font-down') state.fontScale = Math.max(0.85, state.fontScale - 0.1);
      if (act === 'theme') state.dark = !state.dark;
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
    const key = ayahKey(s, a);
    card.querySelectorAll('[data-act]').forEach((btn) => {
      btn.onclick = async () => {
        const act = btn.dataset.act;
        const lib = ensureUserLibrary();
        const ar = card.querySelector('.ar')?.textContent || '';
        const ur = card.querySelector('.ur')?.textContent || '';
        const en = [...card.querySelectorAll('.en')].map((x) => x.textContent).filter((t) => t && t !== ur).join('\n');
        if (act === 'bookmark') {
          const i = lib.bookmarks.indexOf(key);
          if (i >= 0) lib.bookmarks.splice(i, 1);
          else lib.bookmarks.push(key);
          saveUserLibrary(lib);
          toast(i >= 0 ? 'Bookmark removed' : 'Saved to your personal bookmark file');
          const active = $('surah-list').querySelector('button.active');
          openSurah(s, active);
        }
        if (act === 'highlight') {
          if (lib.highlights[key]) delete lib.highlights[key];
          else lib.highlights[key] = 'gold';
          saveUserLibrary(lib);
          toast(lib.highlights[key] ? 'Highlighted' : 'Highlight cleared');
          const active = $('surah-list').querySelector('button.active');
          openSurah(s, active);
        }
        if (act === 'note') {
          const next = prompt(`Note for ${key}`, lib.notes[key] || '');
          if (next === null) return;
          if (!next.trim()) delete lib.notes[key];
          else lib.notes[key] = next.trim();
          saveUserLibrary(lib);
          toast('Note saved to your personal file');
          const active = $('surah-list').querySelector('button.active');
          openSurah(s, active);
        }
        if (act === 'copy') {
          const text = `${key}\n${ar}\n${ur}\n${en}`.trim();
          await navigator.clipboard.writeText(text);
          toast('Copied');
        }
        if (act === 'share') {
          const text = `ISLAM 307 · Quran ${key}\n${ar}\n${ur}\n${en}`.trim();
          if (navigator.share) {
            try {
              await navigator.share({ title: `Quran ${key}`, text });
            } catch {}
          } else {
            await navigator.clipboard.writeText(text);
            toast('Share text copied');
          }
        }
        if (act === 'recite') openReciterPicker(s, a);
      };
    });
  });
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
      <p class="lead">Authentic recitation audio · ${surah}:${ayah}</p>
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
      playReciter(reciter, surah, ayah);
    };
  });
}

function playReciter(reciter, surah, ayah) {
  if (!reciter) return;
  if (state.audio) {
    state.audio.pause();
    state.audio = null;
  }
  const url = reciter.url(surah, ayah);
  const audio = new Audio(url);
  state.audio = audio;
  toast(`Playing · ${reciter.name}`);
  audio.play().catch(() => toast('Audio unavailable right now. Try another qari.'));
}

function renderHadithBooks() {
  const list = $('hadith-books');
  list.innerHTML = '';
  state.hadithBooks.forEach((book) => {
    const b = document.createElement('button');
    b.innerHTML = `<strong>${book.en}</strong><small>${book.ar} · ${book.count.toLocaleString()} hadith</small>`;
    b.onclick = () => openHadithBook(book, b);
    list.appendChild(b);
  });
}

async function openHadithBook(book, button) {
  $('hadith-books').querySelectorAll('button').forEach((b) => b.classList.remove('active'));
  if (button) button.classList.add('active');
  state.hadithSlug = book.slug;
  state.hadithFilter = $('hadith-search').value || '';
  $('hadith-view').innerHTML = `<p class="status">Loading ${book.en}…</p>`;
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

/** Kitab/book chapter name for list rows — Urdu first, then Arabic, never English grade/status. */
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
  return hadith.kitab || pack?.book?.en || '';
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

function openRaviDetail(hadith) {
  const lang = state.hadithLang || 'ur';
  const t = raviCopy(lang);
  const byLang = hadith.ravi_by_lang || {};
  const chain = (Array.isArray(byLang[lang]) && byLang[lang].length
    ? byLang[lang]
    : (hadith.ravi_chain || [])).filter(Boolean);
  const isnads = hadith.isnad_by_lang || {};
  const isnadText = (isnads[lang] || (lang === 'ur' ? hadith.isnad_ur : hadith.isnad) || '').trim();
  const rtl = lang === 'ur' || lang === 'ar';
  let body = '';
  if (chain.length) {
    body += `
      <ol class="ravi-chain" dir="auto">
        ${chain.map((name, i) => {
          const isLast = i === chain.length - 1;
          const heard = i === 0 ? t.first : (isLast ? t.last : t.mid);
          return `<li class="${isLast ? 'is-last-rawi' : ''}">
            <span class="ravi-step">${i + 1}</span>
            <div>
              <strong>${escapeHtml(name)}</strong>
              <small>${escapeHtml(heard)}</small>
            </div>
          </li>`;
        }).join('')}
      </ol>`;
  } else {
    body += `<p class="empty" dir="${rtl ? 'rtl' : 'ltr'}">${escapeHtml(t.empty)}</p>`;
  }
  if (isnadText) {
    body += `<div class="isnad-box"><span>${escapeHtml(t.isnad)}</span><p class="${lang === 'en' ? 'en' : (lang === 'ar' ? 'ar' : 'ur isnad-highlight')}" dir="${rtl ? 'rtl' : 'ltr'}">${escapeHtml(isnadText)}</p></div>`;
  }
  openHadithModal(`${t.title} · Hadith ${hadith.n}`, body);
}

function openReferenceDetail(hadith, book) {
  const lang = state.hadithLang || 'ur';
  const d = hadith.reference_detail || {};
  const localized = (d.by_lang && d.by_lang[lang]) || null;
  const rows = localized && Array.isArray(localized.rows)
    ? localized.rows
    : [
        ['Kitab', d.kitab || hadith.kitab || ''],
        ['Baab', d.baab || hadith.kitab || ''],
        ['Volume', d.volume || ''],
        ['English Kitab', d.english_kitab || hadith.kitab || ''],
        ['English Name', d.english_name || book.en || ''],
        ['Takhreej', d.takhreej || ''],
        ['Status', d.status || hadith.grade || ''],
        ['Wazahat', d.wazahat || ''],
      ];
  const title = { en: 'Reference', ur: 'حوالہ', ar: 'المرجع' }[lang] || 'Reference';
  const body = `
    <table class="ref-table ref-table-shot">
      <tbody>
        ${rows.map(([label, value]) => `
          <tr>
            <th>${escapeHtml(label)}</th>
            <td dir="auto">${escapeHtml(value)}</td>
          </tr>`).join('')}
      </tbody>
    </table>
  `;
  openHadithModal(`${title} · Hadith ${hadith.n}`, body, { darkTable: true });
}

function translationFor(hadith, lang) {
  if (lang === 'en') return hadith.en || '';
  if (lang === 'ar') return hadith.ar || '';
  return hadith.ur || '';
}

function openHadithDetail(slug, hadithNumber) {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  const hadith = pack.hadiths.find((h) => Number(h.n) === Number(hadithNumber));
  if (!hadith) {
    $('hadith-view').innerHTML = `<p class="empty">Hadith ${hadithNumber} not found in authenticated source.</p>`;
    return;
  }
  const lang = state.hadithLang;
  const translation = translationFor(hadith, lang);
  const rtl = lang === 'ur' || lang === 'ar';
  const raviLabel = { en: 'Ravi', ur: 'راوی', ar: 'الرواة' }[lang] || 'Ravi';
  const refLabel = { en: 'Reference', ur: 'حوالہ', ar: 'المرجع' }[lang] || 'Reference';
  $('hadith-view').innerHTML = `
    <div class="hadith-detail">
      <div class="hadith-detail-top">
        <button type="button" class="ghost back-hadith" data-back>&larr; ${escapeHtml(pack.book.en)} list</button>
        <div class="meta-row"><span>Hadith ${hadith.n}</span><span>${hadith.grade ? escapeHtml(hadith.grade) : (hadith.reference_detail?.status || 'Grade not verified.')}</span></div>
      </div>
      <div class="hadith-actions">
        <button type="button" class="hadith-action" data-act="ravi">${escapeHtml(raviLabel)}</button>
        <button type="button" class="hadith-action" data-act="reference">${escapeHtml(refLabel)}</button>
      </div>
      <label class="lang-dropdown">
        <span>Language</span>
        <select id="hadith-lang-select" aria-label="Hadith language">
          <option value="ur" ${lang === 'ur' ? 'selected' : ''}>Urdu</option>
          <option value="en" ${lang === 'en' ? 'selected' : ''}>English</option>
          <option value="ar" ${lang === 'ar' ? 'selected' : ''}>Arabic</option>
        </select>
      </label>
      ${hadith.ar ? `<p class="ar hadith-arabic" dir="rtl">${escapeHtml(hadith.ar)}</p>` : '<p class="empty">Arabic text unavailable in authenticated source.</p>'}
      <div class="hadith-translation ${rtl ? 'rtl' : ''}" dir="${rtl ? 'rtl' : 'ltr'}">
        ${translation
          ? `<p class="${lang === 'ar' ? 'ar' : (lang === 'ur' ? 'ur' : 'en')}">${escapeHtml(translation)}</p>`
          : `<p class="empty">${lang.toUpperCase()} translation unavailable in authenticated source.</p>`}
      </div>
    </div>
  `;
  $('hadith-view').querySelector('[data-back]').onclick = () => renderHadithList(slug, state.hadithFilter);
  const langSelect = $('hadith-view').querySelector('#hadith-lang-select');
  langSelect.onchange = () => {
    state.hadithLang = langSelect.value;
    localStorage.setItem('i307_hadith_lang', state.hadithLang);
    openHadithDetail(slug, hadithNumber);
  };
  $('hadith-view').querySelector('[data-act="ravi"]').onclick = () => openRaviDetail(hadith);
  $('hadith-view').querySelector('[data-act="reference"]').onclick = () => openReferenceDetail(hadith, pack.book);
}

function renderHadithList(slug, filter = '') {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  state.hadithSlug = slug;
  state.hadithFilter = filter;
  const q = filter.trim().toLowerCase();
  const rows = pack.hadiths.filter((h) => {
    if (!q) return true;
    const chain = Array.isArray(h.ravi_chain) ? h.ravi_chain.join(' ') : '';
    const byLang = h.ravi_by_lang || {};
    const urChain = Array.isArray(byLang.ur) ? byLang.ur.join(' ') : '';
    return (
      String(h.n) === q ||
      (h.en || '').toLowerCase().includes(q) ||
      (h.ar || '').includes(filter) ||
      (h.ur || '').includes(filter) ||
      (h.ravi || h.narrator || '').toLowerCase().includes(q) ||
      chain.toLowerCase().includes(q) ||
      urChain.includes(filter) ||
      (h.reference || '').toLowerCase().includes(q) ||
      (h.kitab || '').toLowerCase().includes(q) ||
      (h.grade || '').toLowerCase().includes(q)
    );
  });
  state.hadithListRows = rows;
  // Always paint the complete book/filter set (chunked) — never stop at 120.
  state.hadithListShown = Math.min(state.hadithListPage, rows.length);
  paintHadithListPage(slug, pack, true);
  scheduleFillAllHadith(slug);
}

function scheduleFillAllHadith(slug) {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  const rows = state.hadithListRows || [];
  if (state.hadithListShown >= rows.length) return;
  requestAnimationFrame(() => {
    if (state.hadithSlug !== slug) return;
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
  const status = q
    ? `${pack.book.en} · ${rows.length.toLocaleString()} matches · ${done ? 'all shown' : `loading ${visible.length.toLocaleString()}…`}`
    : `${pack.book.en} · full collection ${totalAll.toLocaleString()} hadith · ${done ? 'all numbers listed' : `loading ${visible.length.toLocaleString()}…`}`;

  if (reset) {
    const maxN = totalAll ? Math.max(...pack.hadiths.map((h) => h.n)) : 0;
    $('hadith-view').innerHTML = `
      <p class="status" id="hadith-list-status">${escapeHtml(status)}</p>
      <p class="hadith-list-hint">Same on every number: Language (Urdu / English / Arabic) · Ravi · Reference. Type a number (1–${maxN}) in search to jump.</p>
      <div class="hadith-number-list" id="hadith-number-list"></div>
      <div class="hadith-list-more" id="hadith-list-more"></div>
    `;
    const scroller = $('hadith-view');
    scroller.onscroll = () => maybeLoadMoreHadith(slug);
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
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'hadith-number-row';
    btn.dataset.n = String(h.n);
    // Left: Hadith N · Right: large Urdu kitab name only (no grade/status).
    const kitabName = localizedKitabName(h, pack);
    btn.innerHTML = `
      <span class="hadith-n">Hadith ${h.n}</span>
      <p class="hadith-kitab" dir="rtl">${escapeHtml(kitabName)}</p>
    `;
    btn.onclick = () => openHadithDetail(slug, h.n);
    frag.appendChild(btn);
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
    more.innerHTML = `<p class="status">All ${rows.length.toLocaleString()} hadith loaded · Language / Ravi / Reference work on every number (Bukhari, Muslim, Abu Dawood, Tirmidhi)</p>`;
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
  $('tafsir-view').innerHTML = `<p class="status">Loading ${source.en}…</p>`;
  if (!state.tafsirCache[source.slug]) {
    state.tafsirCache[source.slug] = await fetchJsonGz(`data/tafsir/${source.slug}.json.gz`);
  }
  const pack = state.tafsirCache[source.slug];
  const entry = pack.entries.find((e) => e.s === surah && e.a === ayah);
  $('tafsir-view').innerHTML = entry
    ? `<div class="tafsir-card">
        <div class="meta-row"><span>${source.en}</span><span>${surah}:${ayah}</span></div>
        <p class="en" style="color:var(--text);white-space:pre-wrap">${entry.text}</p>
      </div>`
    : `<p class="empty">No authentic tafsir entry for ${surah}:${ayah} in ${source.en}. ISLAM 307 never generates tafsir with AI.</p>`;
}

$('quran-search').addEventListener('input', (e) => renderSurahList(e.target.value));
$('hadith-search').addEventListener('input', (e) => {
  const active = $('hadith-books').querySelector('button.active');
  if (!active) return;
  const idx = Array.from($('hadith-books').children).indexOf(active);
  const book = state.hadithBooks[idx];
  if (book) renderHadithList(book.slug, e.target.value);
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
    const [surahPack, hadithPack, tafsirPack] = await Promise.all([
      fetchJson('data/quran/surahs.json'),
      fetchJson('data/hadith/books.json'),
      fetchJson('data/tafsir/sources.json'),
    ]);
    state.surahs = surahPack.surahs;
    state.hadithBooks = hadithPack.books;
    state.tafsirSources = tafsirPack.sources;
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
