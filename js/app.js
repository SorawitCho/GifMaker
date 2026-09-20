import { encodeGif } from './gifEncoder.js';

const fileInput = document.getElementById('file-input');
const emptyState = document.getElementById('empty-state');
const grid = document.getElementById('grid');
const addMoreRow = document.getElementById('add-more-row');
const controls = document.getElementById('controls');
const speedSlider = document.getElementById('speed-slider');
const speedLabel = document.getElementById('speed-label');
const createBtn = document.getElementById('create-btn');
const overlay = document.getElementById('overlay');
const mainSection = document.getElementById('main-section');
const previewSection = document.getElementById('preview-section');
const previewImg = document.getElementById('preview-img');
const saveBtn = document.getElementById('save-btn');
const saveHint = document.getElementById('save-hint');
const downloadLink = document.getElementById('download-link');
const backBtn = document.getElementById('back-btn');

let photos = []; // { id, file, url }
let frameDelayMs = Number(speedSlider.value);
let sortable = null;
let resultBlob = null;
let resultUrl = null;

function makeId(file) {
  return `${file.name}-${file.size}-${file.lastModified}`;
}

function updateSpeedLabel() {
  const fps = (1000 / frameDelayMs).toFixed(1);
  speedLabel.textContent = `Speed — ${frameDelayMs}ms/frame (~${fps} fps)`;
}

function renderGrid() {
  grid.innerHTML = '';
  photos.forEach((photo, index) => {
    const tile = document.createElement('div');
    tile.className = 'tile';
    tile.dataset.id = photo.id;

    const img = document.createElement('img');
    img.src = photo.url;
    img.alt = '';
    tile.appendChild(img);

    const badge = document.createElement('span');
    badge.className = 'badge';
    badge.textContent = String(index + 1);
    tile.appendChild(badge);

    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'remove-btn';
    removeBtn.setAttribute('aria-label', 'Remove photo');
    removeBtn.textContent = '×';
    removeBtn.addEventListener('click', () => removePhoto(photo.id));
    tile.appendChild(removeBtn);

    grid.appendChild(tile);
  });
}

function syncBadges() {
  [...grid.children].forEach((tile, index) => {
    const badge = tile.querySelector('.badge');
    if (badge) badge.textContent = String(index + 1);
  });
}

function setupSortable() {
  if (sortable) {
    sortable.destroy();
    sortable = null;
  }
  if (photos.length === 0) return;
  sortable = new window.Sortable(grid, {
    animation: 150,
    onEnd: () => {
      const orderedIds = [...grid.children].map((tile) => tile.dataset.id);
      photos.sort((a, b) => orderedIds.indexOf(a.id) - orderedIds.indexOf(b.id));
      syncBadges();
    },
  });
}

function render() {
  const hasPhotos = photos.length > 0;
  emptyState.hidden = hasPhotos;
  grid.hidden = !hasPhotos;
  addMoreRow.hidden = !hasPhotos;
  controls.hidden = !hasPhotos;
  createBtn.hidden = !hasPhotos;
  createBtn.disabled = photos.length < 2;
  renderGrid();
  setupSortable();
}

function addFiles(fileList) {
  const existingIds = new Set(photos.map((p) => p.id));
  const incoming = Array.from(fileList).filter((f) => f.type.startsWith('image/'));
  for (const file of incoming) {
    const id = makeId(file);
    if (existingIds.has(id)) continue;
    existingIds.add(id);
    photos.push({ id, file, url: URL.createObjectURL(file) });
  }
  render();
}

function removePhoto(id) {
  const photo = photos.find((p) => p.id === id);
  if (photo) URL.revokeObjectURL(photo.url);
  photos = photos.filter((p) => p.id !== id);
  render();
}

fileInput.addEventListener('change', (event) => {
  if (event.target.files && event.target.files.length > 0) {
    addFiles(event.target.files);
  }
  fileInput.value = '';
});

speedSlider.addEventListener('input', () => {
  frameDelayMs = Number(speedSlider.value);
  updateSpeedLabel();
});

createBtn.addEventListener('click', async () => {
  overlay.hidden = false;
  createBtn.disabled = true;
  try {
    const blob = await encodeGif({ files: photos.map((p) => p.file), frameDelayMs });
    showPreview(blob);
  } catch (err) {
    window.alert(err.message || 'Something went wrong while creating the GIF. Please try again.');
  } finally {
    overlay.hidden = true;
    createBtn.disabled = photos.length < 2;
  }
});

function showPreview(blob) {
  resultBlob = blob;
  if (resultUrl) URL.revokeObjectURL(resultUrl);
  resultUrl = URL.createObjectURL(blob);
  previewImg.src = resultUrl;

  let canUseShare = false;
  try {
    const file = new File([blob], 'gifmaker.gif', { type: 'image/gif' });
    canUseShare = !!(navigator.canShare && navigator.canShare({ files: [file] }));
  } catch (_err) {
    canUseShare = false;
  }

  saveBtn.hidden = !canUseShare;
  saveHint.hidden = canUseShare;
  downloadLink.hidden = canUseShare;
  if (!canUseShare) {
    downloadLink.href = resultUrl;
  }

  mainSection.hidden = true;
  previewSection.hidden = false;
}

saveBtn.addEventListener('click', async () => {
  if (!resultBlob) return;
  try {
    const file = new File([resultBlob], 'gifmaker.gif', { type: 'image/gif' });
    await navigator.share({ files: [file], title: 'GifMaker' });
  } catch (err) {
    if (err && err.name !== 'AbortError') {
      window.alert('Could not open the share sheet. Long-press the image above and tap "Add to Photos" instead.');
    }
  }
});

backBtn.addEventListener('click', () => {
  previewSection.hidden = true;
  mainSection.hidden = false;
});

updateSpeedLabel();
render();
