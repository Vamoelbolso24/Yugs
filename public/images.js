// "My card images": a player picks their EDOPro "pics" folder and the images are saved in
// THIS browser only (IndexedDB). They are never uploaded to the Yugs server.
'use strict';

const cardImages = { db: null, keys: new Set(), urls: new Map() };

function idbRequest(r) {
  return new Promise((resolve, reject) => {
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  });
}

function imageStore(mode) {
  return cardImages.db.transaction('pics', mode).objectStore('pics');
}

async function initCardImages() {
  try {
    const open = indexedDB.open('yugs-images', 1);
    open.onupgradeneeded = () => open.result.createObjectStore('pics');
    cardImages.db = await idbRequest(open);
    for (const k of await idbRequest(imageStore('readonly').getAllKeys())) cardImages.keys.add(k);
  } catch {
    cardImages.db = null; // private mode or storage blocked: the game just uses frames
  }
}

function hasCardImage(code) {
  return cardImages.keys.has(code);
}

/** URL for a stored image (created once, then reused). */
async function cardImageUrl(code) {
  if (cardImages.urls.has(code)) return cardImages.urls.get(code);
  if (!cardImages.db || !cardImages.keys.has(code)) return null;
  const blob = await idbRequest(imageStore('readonly').get(code));
  if (!blob) return null;
  const url = URL.createObjectURL(blob);
  cardImages.urls.set(code, url);
  return url;
}

/** Saves card images from a picked folder. Only files named like 46986414.jpg directly inside it. */
async function importCardImages(fileList, onProgress) {
  if (!cardImages.db) throw new Error('This browser does not allow saving images (private window?).');
  const files = [...fileList].filter((f) => {
    const depth = (f.webkitRelativePath || f.name).split('/').length;
    return /^\d+\.(jpe?g|png)$/i.test(f.name) && depth <= 2;
  });
  let done = 0;
  for (let i = 0; i < files.length; i += 200) {
    const batch = files.slice(i, i + 200);
    const tx = cardImages.db.transaction('pics', 'readwrite');
    const store = tx.objectStore('pics');
    for (const f of batch) {
      const code = Number(f.name.split('.')[0]);
      store.put(f, code);
      cardImages.keys.add(code);
      cardImages.urls.delete(code);
    }
    await new Promise((resolve, reject) => { tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); });
    done += batch.length;
    onProgress(done, files.length);
  }
  return files.length;
}

async function clearCardImages() {
  if (!cardImages.db) return;
  await idbRequest(imageStore('readwrite').clear());
  for (const url of cardImages.urls.values()) URL.revokeObjectURL(url);
  cardImages.urls.clear();
  cardImages.keys.clear();
}
