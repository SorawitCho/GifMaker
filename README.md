# GifMaker

A minimal, Apple-style web app that combines your photos into an animated GIF — entirely on your device, no account, no cloud upload.

## Using it

Open the app's URL in Chrome (or Safari) on your iPhone:

1. **Choose Photos** — picks from your Photos library via the browser's native picker.
2. Selected photos appear in a grid with numbered badges showing their order in the GIF. **Drag to reorder**, tap **×** to remove one.
3. Use the **Speed** slider to set how long each frame stays on screen.
4. Tap **Create GIF**.
5. On the preview screen, tap **Save** to open the share sheet and choose "Save Image" to add it to Photos. (If your browser doesn't support sharing files, press and hold the preview image instead — every browser supports that.)

## How it works

Everything runs client-side in the browser — there's no server or backend at all:

- `js/gifEncoder.js` — pure encoding logic. Normalizes every selected photo to one shared canvas size (center-cropped to a common aspect ratio, so mixed portrait/landscape photos aren't stretched), then encodes them into a GIF using [gif.js](https://github.com/jnordberg/gif.js) (runs in a Web Worker so the UI stays responsive).
- `js/app.js` — UI state: picking/merging photos, drag-reorder (via [SortableJS](https://sortablejs.github.io/Sortable/)), the speed control, and the save/share flow.
- `service-worker.js` — caches the app shell on first visit so it keeps working with no network afterward.

No photo, and no generated GIF, ever leaves your device.

## Project history

This started as a native iOS app built with Flutter, but getting a Flutter/Swift build onto an iPhone requires Xcode (macOS-only) plus a paid Apple Developer account for any kind of reliable, non-expiring install. This web version sidesteps all of that — just open a URL.
