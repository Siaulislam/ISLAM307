const screens = [
  { id: 'hadith-books', label: 'Hadith Books' },
  { id: 'hadith-chapters', label: 'Hadith Chapters' },
  { id: 'hadith-detail', label: 'Hadith Detail' },
  { id: 'tafsir-list', label: 'Tafsir Sources' },
  { id: 'tafsir-reader', label: 'Tafsir Reader' },
  { id: 'ai-assistant', label: 'AI Assistant' },
  { id: 'tablet-split', label: 'Tablet Split' },
];

const nav = document.getElementById('nav');
const els = document.querySelectorAll('.screen');
const frame = document.getElementById('deviceFrame');
const deviceToggle = document.getElementById('deviceToggle');

function goTo(id) {
  if (!id) return;
  const exists = Array.from(els).some((el) => el.dataset.id === id);
  if (!exists) return;
  nav.querySelectorAll('button').forEach((x) => x.classList.toggle('active', x.dataset.id === id));
  els.forEach((el) => el.classList.toggle('active', el.dataset.id === id));
  if (history.replaceState) history.replaceState(null, '', '#' + id);
}

screens.forEach((s, i) => {
  const b = document.createElement('button');
  b.textContent = s.label;
  b.dataset.id = s.id;
  if (i === 0) b.classList.add('active');
  b.onclick = () => goTo(s.id);
  nav.appendChild(b);
});

deviceToggle.querySelectorAll('button').forEach((btn) => {
  btn.onclick = () => {
    deviceToggle.querySelectorAll('button').forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    frame.className = 'device-' + btn.dataset.device;
  };
});

// Make list rows inside screens advance the flow
const flow = {
  'hadith-books': 'hadith-chapters',
  'hadith-chapters': 'hadith-detail',
  'tafsir-list': 'tafsir-reader',
};

document.querySelectorAll('.screen').forEach((screen) => {
  const next = flow[screen.dataset.id];
  if (!next) return;
  screen.querySelectorAll('.list-row').forEach((row) => {
    row.style.cursor = 'pointer';
    row.addEventListener('click', () => goTo(next));
  });
});

const hash = (location.hash || '').replace(/^#/, '');
if (hash) goTo(hash);
