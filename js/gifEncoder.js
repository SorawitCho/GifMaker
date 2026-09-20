// Pure encoding logic: turns an ordered list of image Files into a single
// animated GIF Blob. No DOM state beyond a throwaway canvas — safe to reason
// about and test in isolation from app.js's UI wiring.

function loadImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Could not load one of the selected photos.'));
    };
    img.src = url;
  });
}

// Draws `img` into `ctx` as a "cover" fit: center-cropped to the target
// aspect ratio, then scaled to fill it exactly. Every frame in a GIF must
// share the same canvas size, so every frame — including the first — goes
// through this, avoiding stretching for mixed-aspect-ratio photos.
function drawCoverFit(ctx, img, targetWidth, targetHeight) {
  const targetAspect = targetWidth / targetHeight;
  const srcAspect = img.naturalWidth / img.naturalHeight;

  let sx = 0;
  let sy = 0;
  let sw = img.naturalWidth;
  let sh = img.naturalHeight;

  if (srcAspect > targetAspect) {
    sw = Math.round(img.naturalHeight * targetAspect);
    sx = Math.round((img.naturalWidth - sw) / 2);
  } else if (srcAspect < targetAspect) {
    sh = Math.round(img.naturalWidth / targetAspect);
    sy = Math.round((img.naturalHeight - sh) / 2);
  }

  ctx.drawImage(img, sx, sy, sw, sh, 0, 0, targetWidth, targetHeight);
}

/**
 * @param {{files: File[], frameDelayMs: number, maxDimension?: number}} options
 * @returns {Promise<Blob>} the encoded GIF
 */
export async function encodeGif({ files, frameDelayMs, maxDimension = 720 }) {
  if (!files || files.length < 2) {
    throw new Error('At least 2 photos are required to build a GIF.');
  }

  const images = [];
  for (const file of files) {
    images.push(await loadImage(file));
  }

  // The target canvas size is based on the LARGEST selected photo, not just
  // the first one — otherwise a small photo picked first would needlessly
  // crush the quality of bigger photos later in the sequence. Framing
  // (aspect ratio) still comes from the first photo, since every frame has
  // to be cropped to one consistent shape.
  const largestLongEdge = Math.max(...images.map((img) => Math.max(img.naturalWidth, img.naturalHeight)));
  const targetLongEdge = Math.min(largestLongEdge, maxDimension);
  const first = images[0];
  const aspect = first.naturalWidth / first.naturalHeight;
  const targetWidth = aspect >= 1 ? targetLongEdge : Math.max(1, Math.round(targetLongEdge * aspect));
  const targetHeight = aspect >= 1 ? Math.max(1, Math.round(targetLongEdge / aspect)) : targetLongEdge;

  const canvas = document.createElement('canvas');
  canvas.width = targetWidth;
  canvas.height = targetHeight;
  const ctx = canvas.getContext('2d');

  return new Promise((resolve, reject) => {
    const gif = new window.GIF({
      workers: 2,
      quality: 5,
      width: targetWidth,
      height: targetHeight,
      workerScript: 'js/vendor/gif.worker.js',
    });

    gif.on('finished', (blob) => resolve(blob));
    gif.on('abort', () => reject(new Error('GIF encoding was aborted.')));

    try {
      for (const img of images) {
        ctx.clearRect(0, 0, targetWidth, targetHeight);
        drawCoverFit(ctx, img, targetWidth, targetHeight);
        gif.addFrame(ctx, { copy: true, delay: frameDelayMs });
      }
      gif.render();
    } catch (err) {
      reject(err);
    }
  });
}
