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
};

const $ = (id) => document.getElementById(id);

function setTab(tab) {
  document.querySelectorAll('.tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('active', p.id === `panel-${tab}`));
  if (history.replaceState) history.replaceState(null, '', `#${tab}`);
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
  $('ayah-view').innerHTML = `
    <p class="status">${surah.en} · ${surah.ar} · ${ayahs.length} ayahs</p>
    ${ayahs.map((a) => `
      <div class="ayah">
        <div class="meta-row"><span>${a.s}:${a.a}</span><span>Page ${a.p} · Juz ${a.j}</span></div>
        <p class="ar">${a.ar}</p>
        ${a.ur ? `<p class="en" style="direction:rtl;text-align:right;font-size:17px;color:#334155">${a.ur}</p>` : ''}
        ${a.en ? `<p class="en">${a.en}</p>` : ''}
      </div>
    `).join('')}
  `;
  if (history.replaceState) {
    const url = new URL(location.href);
    url.searchParams.set('surah', String(n));
    url.hash = 'quran';
    history.replaceState(null, '', url.toString());
  }
  $('ayah-view').scrollTop = 0;
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
      (h.narrator || '').toLowerCase().includes(q) ||
      (h.grade || '').toLowerCase().includes(q)
    );
  }).slice(0, q ? 200 : 100);
  $('hadith-view').innerHTML = `
    <p class="status">${pack.book.en} · showing ${rows.length}${q ? ' matches' : ' (first 100 — search to find more)'}</p>
    ${rows.map((h) => `
      <div class="hadith-card">
        <div class="meta-row"><span>Hadith ${h.n}</span><span>${h.narrator || ''}</span></div>
        ${h.ar ? `<p class="ar">${h.ar}</p>` : ''}
        ${h.ur ? `<p class="en" style="direction:rtl;text-align:right">${h.ur}</p>` : ''}
        <p class="en">${h.en || ''}</p>
        <span class="badge">${h.grade ? h.grade : 'Grade not verified.'}</span>
      </div>
    `).join('') || '<p class="empty">No matches.</p>'}
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
    : `<p class="empty">No tafsir entry for ${surah}:${ayah} in ${source.en}.</p>`;
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
    document.querySelector('main').innerHTML = `<p class="empty">Library data missing. Run <code>python tools/design/export_preview_library.py</code> then refresh.</p><pre>${err.message}</pre>`;
  }
}

boot();
