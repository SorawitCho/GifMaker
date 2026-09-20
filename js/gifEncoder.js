// Pure encoding logic: turns an ordered list of image Files into a single
// animated GIF Blob. No DOM state beyond a throwaway canvas — safe to reason
// about and test in isolation from app.js's UI wiring.

// Prefer createImageBitmap with an explicit sRGB colorSpaceConversion: it has
// more consistent, spec-defined color-space handling than the <img> + canvas
// path, which is what mis-renders some camera JPEGs (e.g. ones shot in
// AdobeRGB) as washed-out — the AdobeRGB pixel values get drawn as if they
// were already sRGB. Falls back to <img> if createImageBitmap is unavailable.
async function loadImage(file) {
  if (window.createImageBitmap) {
    try {
      return await createImageBitmap(file, { colorSpaceConversion: 'default' });
    } catch (_err) {
      // fall through to the <img> fallback below
    }
  }
  return loadImageElement(file);
}

function loadImageElement(file) {
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

// Normalizes intrinsic size across HTMLImageElement (naturalWidth/Height)
// and ImageBitmap (width/height).
function dims(img) {
  if (typeof HTMLImageElement !== 'undefined' && img instanceof HTMLImageElement) {
    return { width: img.naturalWidth, height: img.naturalHeight };
  }
  return { width: img.width, height: img.height };
}

// Draws `img` into `ctx` as a "cover" fit: center-cropped to the target
// aspect ratio, then scaled to fill it exactly. Every frame in a GIF must
// share the same canvas size, so every frame — including the first — goes
// through this, avoiding stretching for mixed-aspect-ratio photos.
function drawCoverFit(ctx, img, targetWidth, targetHeight) {
  const { width: srcWidth, height: srcHeight } = dims(img);
  const targetAspect = targetWidth / targetHeight;
  const srcAspect = srcWidth / srcHeight;

  let sx = 0;
  let sy = 0;
  let sw = srcWidth;
  let sh = srcHeight;

  if (srcAspect > targetAspect) {
    sw = Math.round(srcHeight * targetAspect);
    sx = Math.round((srcWidth - sw) / 2);
  } else if (srcAspect < targetAspect) {
    sh = Math.round(srcWidth / targetAspect);
    sy = Math.round((srcHeight - sh) / 2);
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
  const largestLongEdge = Math.max(...images.map((img) => Math.max(dims(img).width, dims(img).height)));
  const targetLongEdge = Math.min(largestLongEdge, maxDimension);
  const first = dims(images[0]);
  const aspect = first.width / first.height;
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
