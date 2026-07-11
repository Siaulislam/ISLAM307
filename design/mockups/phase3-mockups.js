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

screens.forEach((s, i) => {
  const b = document.createElement('button');
  b.textContent = s.label;
  b.dataset.id = s.id;
  if (i === 0) b.classList.add('active');
  b.onclick = () => {
    nav.querySelectorAll('button').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    els.forEach(el => el.classList.toggle('active', el.dataset.id === s.id));
  };
  nav.appendChild(b);
});

deviceToggle.querySelectorAll('button').forEach(btn => {
  btn.onclick = () => {
    deviceToggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    frame.className = 'device-' + btn.dataset.device;
  };
});
