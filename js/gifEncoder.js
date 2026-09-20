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

// Draws `img` into `ctx` as a "contain" fit: the full photo, uncropped and
// undistorted, at its native size (never upscaled), centered on the canvas
// with solid-color padding if it's smaller than the shared canvas. Every
// frame in a GIF must share one canvas size, so when photos differ in size
// this is the least-invasive way to reconcile that — nothing is ever cropped
// out and nothing is ever scaled up.
function drawContainFit(ctx, img, targetWidth, targetHeight) {
  const { width: srcWidth, height: srcHeight } = dims(img);
  const scale = Math.min(targetWidth / srcWidth, targetHeight / srcHeight, 1);
  const dw = Math.round(srcWidth * scale);
  const dh = Math.round(srcHeight * scale);
  const dx = Math.round((targetWidth - dw) / 2);
  const dy = Math.round((targetHeight - dh) / 2);

  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, targetWidth, targetHeight);
  ctx.drawImage(img, 0, 0, srcWidth, srcHeight, dx, dy, dw, dh);
}

/**
 * @param {{files: File[], frameDelayMs: number, maxDimension?: number}} options
 * @returns {Promise<Blob>} the encoded GIF
 */
export async function encodeGif({ files, frameDelayMs, maxDimension = 1200 }) {
  if (!files || files.length < 2) {
    throw new Error('At least 2 photos are required to build a GIF.');
  }

  const images = [];
  for (const file of files) {
    images.push(await loadImage(file));
  }

  // The shared canvas is sized to whichever selected photo has the largest
  // area, at that photo's own native resolution and aspect ratio — only
  // downscaled (preserving aspect ratio) if it exceeds maxDimension, a
  // safety cap so a full-resolution multi-frame GIF can't exhaust a phone
  // browser's memory or balloon into an unshareable file size. If every
  // photo is already the same size and under that cap, this results in zero
  // resizing at all.
  const largest = images.reduce((a, b) => {
    const areaA = dims(a).width * dims(a).height;
    const areaB = dims(b).width * dims(b).height;
    return areaB > areaA ? b : a;
  });
  const { width: refWidth, height: refHeight } = dims(largest);
  const refLongEdge = Math.max(refWidth, refHeight);
  const scale = refLongEdge > maxDimension ? maxDimension / refLongEdge : 1;
  const targetWidth = Math.max(1, Math.round(refWidth * scale));
  const targetHeight = Math.max(1, Math.round(refHeight * scale));

  const canvas = document.createElement('canvas');
  canvas.width = targetWidth;
  canvas.height = targetHeight;
  const ctx = canvas.getContext('2d');

  return new Promise((resolve, reject) => {
    const gif = new window.GIF({
      workers: 2,
      quality: 1,
      width: targetWidth,
      height: targetHeight,
      workerScript: 'js/vendor/gif.worker.js',
    });

    gif.on('finished', (blob) => resolve(blob));
    gif.on('abort', () => reject(new Error('GIF encoding was aborted.')));

    try {
      for (const img of images) {
        drawContainFit(ctx, img, targetWidth, targetHeight);
        gif.addFrame(ctx, { copy: true, delay: frameDelayMs });
      }
      gif.render();
    } catch (err) {
      reject(err);
    }
  });
}
