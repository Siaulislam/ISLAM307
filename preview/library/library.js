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
  $('hadith-view').innerHTML = `<p class="status">Loading ${book.en}…</p>`;
  if (!state.hadithCache[book.slug]) {
    state.hadithCache[book.slug] = await fetchJsonGz(`data/hadith/${book.slug}.json.gz`);
  }
  renderHadithList(book.slug);
}

function renderHadithList(slug, filter = '') {
  const pack = state.hadithCache[slug];
  if (!pack) return;
  const q = filter.trim().toLowerCase();
  const rows = pack.hadiths.filter((h) => {
    if (!q) return true;
    return (
      String(h.n) === q ||
      (h.en || '').toLowerCase().includes(q) ||
      (h.ar || '').includes(filter) ||
      (h.ur || '').includes(filter) ||
      (h.ravi || h.narrator || '').toLowerCase().includes(q) ||
      (h.reference || '').toLowerCase().includes(q) ||
      (h.kitab || '').toLowerCase().includes(q) ||
      (h.grade || '').toLowerCase().includes(q)
    );
  }).slice(0, q ? 200 : 100);
  $('hadith-view').innerHTML = `
    <p class="status">${pack.book.en} · showing ${rows.length}${q ? ' matches' : ' (first 100 — search to find more)'}</p>
    ${rows.map((h) => {
      const ravi = (h.ravi || h.narrator || '').trim();
      const reference = h.reference || `${pack.book.en} · Hadith ${h.n}`;
      return `
      <div class="hadith-card">
        <div class="meta-row"><span>Hadith ${h.n}</span><span>${h.grade ? h.grade : 'Grade not verified.'}</span></div>
        <div class="hadith-meta">
          <div class="hadith-meta-row"><span>RAVI</span><strong>${ravi || 'Ravi not available in authenticated source'}</strong></div>
          <div class="hadith-meta-row"><span>Reference</span><strong>${reference}</strong></div>
          ${h.kitab ? `<div class="hadith-meta-row"><span>Kitab / Baab</span><strong>${h.kitab}</strong></div>` : ''}
          <div class="hadith-meta-row"><span>English Name</span><strong>${pack.book.en}</strong></div>
        </div>
        ${h.ar ? `<p class="ar">${h.ar}</p>` : ''}
        ${h.ur ? `<p class="en ur">${h.ur}</p>` : ''}
        <p class="en">${h.en || ''}</p>
        ${h.source_url ? `<a class="ref-link" href="${h.source_url}" target="_blank" rel="noopener">Open reference</a>` : ''}
      </div>`;
    }).join('') || '<p class="empty">No matches.</p>'}
  `;
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
