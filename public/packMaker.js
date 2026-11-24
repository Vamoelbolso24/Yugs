// Pack Maker (admins only): build packs by dragging cards into rarity lists, give them artwork,
// and drag saved packs into next week's 3 shop places. Uses helpers from app.js and menus.js.
'use strict';

const PM_RARITIES = ['secret', 'ultra', 'super', 'rare', 'common'];
let pm = null;          // the pack being edited + search state
let pmData = null;      // { packs, shop, texts } from the server
let pmLoading = false;

function pmBlank(keep) {
  return {
    tab: (keep && keep.tab) || 'edit',
    packId: null, name: '', description: '',
    cards: { common: [], rare: [], super: [], ultra: [], secret: [] },
    target: 'common', dirty: false, message: '', error: '',
    // search (same shape the deck editor's search tools use)
    f: (keep && keep.f) || CardFilter.emptyFilter(),
    sortBy: (keep && keep.sortBy) || 'name', sortDesc: !!(keep && keep.sortDesc), showFilters: !!(keep && keep.showFilters),
    results: (keep && keep.results) || [], total: 0, query: keep ? keep.query : null,
    next: keep ? keep.next : null,
    // .ydk import: the right side shows either the card search or the imported cards
    source: (keep && keep.source) || 'search',
    imported: (keep && keep.imported) || [], importName: (keep && keep.importName) || '', hidePlaced: keep ? keep.hidePlaced !== false : true,
  };
}

async function pmLoad() {
  if (pmLoading) return;
  pmLoading = true;
  const { ok, data } = await api('GET', '/api/admin/packs');
  pmLoading = false;
  if (!ok) { menuMessage = data.error || 'Could not load the packs.'; screen = 'home'; render(); return; }
  pmTake(data);
  render();
}

function pmTake(data) {
  pmData = data;
  remember(data.texts);
  if (!pm) pm = pmBlank();
  if (pm.next === null) pm.next = (data.shop.next || data.shop.current || []).slice(0, data.shop.size);
  cache.packs = null; // the Packs screen reloads (art / lineup may have changed)
}

function pmOpen(pack) {
  const keep = pm;
  pm = pmBlank(keep);
  if (pack) {
    pm.packId = pack.id;
    pm.name = pack.name;
    pm.description = pack.description;
    for (const r of PM_RARITIES) pm.cards[r] = [...(pack.cards[r] || [])];
  }
}

function pmConfirmDiscard() {
  return !pm || !pm.dirty || confirm('This pack has unsaved changes. Discard them?');
}

function renderPackMaker(box) {
  if (!currentUser.isAdmin) { screen = 'home'; return renderHome(box); }
  if (!pmData) { box.appendChild(el('p', 'muted', 'Loading packs...')); pmLoad(); return; }
  if (!pm) pm = pmBlank();

  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Pack Maker'));
  const tabs = el('div', 'filters');
  tabs.append(
    button('Edit packs', () => { pm.tab = 'edit'; render(); }, pm.tab === 'edit' ? 'chip active' : 'chip'),
    button('Shop lineup', () => { pm.tab = 'shop'; render(); }, pm.tab === 'shop' ? 'chip active' : 'chip'),
  );
  top.append(tabs, button('Back', () => { if (pmConfirmDiscard()) { pm = null; pmData = null; screen = 'home'; render(); } }, 'secondary'));
  box.appendChild(top);
  if (pm.error) box.appendChild(el('div', 'error', pm.error));
  if (pm.message) box.appendChild(el('div', 'notice', pm.message));
  if (pm.tab === 'shop') return renderPmShop(box);
  return renderPmEditor(box);
}

// ------------------------------------------------------------------ edit a pack

function renderPmEditor(box) {
  // pack picker + name + description + save / delete
  const bar = el('div', 'screen-top pm-bar');
  const pick = el('select', 'deck-select');
  for (const p of pmData.packs) {
    const o = el('option', '', `${p.name}${p.ready ? '' : ' (draft)'}`);
    o.value = p.id;
    if (p.id === pm.packId) o.selected = true;
    pick.appendChild(o);
  }
  const newOpt = el('option', '', '+ New pack');
  newOpt.value = '';
  if (!pm.packId) newOpt.selected = true;
  pick.appendChild(newOpt);
  pick.addEventListener('change', () => {
    if (pmConfirmDiscard()) pmOpen(pmData.packs.find((p) => p.id === pick.value) || null);
    render();
  });
  const name = el('input', 'text-input deck-name pm-name');
  name.placeholder = 'Pack name';
  name.maxLength = 60;
  name.value = pm.name;
  name.addEventListener('input', () => { pm.name = name.value; pm.dirty = true; });
  bar.append(pick, name, button(pm.dirty ? 'Save pack *' : 'Save pack', pmSave));
  if (pm.packId) bar.append(button('Copy', pmCopy, 'secondary'), button('Delete', pmDelete, 'ghost'));
  box.appendChild(bar);

  const layout = el('div', 'editor pm-editor');
  layout.appendChild(detailPanel());

  // middle: description, artwork, the 5 rarity lists
  const mid = el('div', 'editor-deck');
  mid.dataset.keepScroll = 'pm-lists';
  const desc = el('textarea', 'text-input pm-desc');
  desc.placeholder = 'Description shown in the shop';
  desc.maxLength = 300;
  desc.value = pm.description;
  desc.addEventListener('input', () => { pm.description = desc.value; pm.dirty = true; });
  mid.appendChild(desc);
  mid.appendChild(pmArtBox());
  const total = PM_RARITIES.reduce((n, r) => n + pm.cards[r].length, 0);
  mid.appendChild(el('div', 'muted small', `${total} cards. Drag cards here from the search (or click a search result to add it to the highlighted list). Drag between lists to move; hold Ctrl while dropping to copy. Click a card in a list to take it out. Every pack gives 9 cards: Common 75%, Rare 16%, Super 6%, Ultra 2.5%, Secret 0.5% each.`));
  for (const r of PM_RARITIES) mid.appendChild(pmRarityList(r));
  layout.appendChild(mid);

  // right: card search, or cards imported from a .ydk file
  const right = el('div', 'editor-collection');
  const srcTabs = el('div', 'filters');
  srcTabs.append(
    button('Search cards', () => { pm.source = 'search'; render(); }, pm.source === 'search' ? 'chip active' : 'chip'),
    button(pm.imported.length ? `From .ydk (${pm.imported.length})` : 'Import .ydk', () => { if (pm.imported.length) { pm.source = 'ydk'; render(); } else pmPickYdk(); }, pm.source === 'ydk' ? 'chip active' : 'chip'),
  );
  right.appendChild(srcTabs);
  // drop a .ydk anywhere on this side
  right.addEventListener('dragover', (ev) => { if (ev.dataTransfer.types.includes('Files')) { ev.preventDefault(); right.classList.add('drop-here'); } });
  right.addEventListener('dragleave', (ev) => { if (ev.target === right) right.classList.remove('drop-here'); });
  right.addEventListener('drop', (ev) => {
    if (!ev.dataTransfer.files.length) return;
    ev.preventDefault();
    right.classList.remove('drop-here');
    pmImportYdk(ev.dataTransfer.files[0]);
  });
  if (pm.source === 'ydk' && pm.imported.length) renderPmImported(right);
  else renderPmSearch(right);
  layout.appendChild(right);
  box.appendChild(layout);
}

function renderPmSearch(right) {
  right.appendChild(collectionTools(pm));
  const f = pm.f;
  const active = f.q.trim().length >= 2 || CardFilter.isActive({ ...f, q: '' });
  const key = JSON.stringify(f);
  if (active && pm.query !== key) {
    pm.query = key;
    adminSearch(f.q, (found, totalFound) => { pm.results = found; pm.total = totalFound; render(); }, { ...f, q: '' });
  }
  if (!active) {
    right.appendChild(el('div', 'muted small', 'Type 2+ letters (name or card text) or set a filter to search every card in the game, custom cards included. Or import a .ydk deck file (button above, or drop the file here).'));
    return;
  }
  const shown = CardFilter.sort(pm.results, (c) => cardCache[c], pm.sortBy, pm.sortDesc).filter((c) => cardCache[c] && CardFilter.matches(cardCache[c], f));
  right.appendChild(el('div', 'muted small', `${shown.length}${pm.total > shown.length ? ` of ${pm.total}` : ''} cards found.`));
  right.appendChild(pmSourceGrid(shown, 'pm-search'));
}

function renderPmImported(right) {
  const placed = (c) => PM_RARITIES.some((r) => pm.cards[r].includes(c));
  const left = pm.imported.filter((c) => !placed(c));
  const shown = CardFilter.sort(pm.hidePlaced ? left : pm.imported, (c) => cardCache[c], pm.sortBy === 'default' ? 'default' : pm.sortBy, pm.sortDesc);
  right.appendChild(el('div', 'muted small', `${pm.importName}: ${pm.imported.length} different cards, ${left.length} not in a list yet. Drag them into the rarity lists, or click to add to the highlighted list.`));
  const row = el('div', 'filters');
  row.append(
    button(pm.hidePlaced ? 'Show placed cards too' : 'Hide placed cards', () => { pm.hidePlaced = !pm.hidePlaced; render(); }, 'chip'),
    button(`Add the rest to ${RARITY_LABEL[pm.target]}`, () => { for (const c of left) pmAdd(c, pm.target, true); render(); }, 'chip'),
    button('Import another .ydk', pmPickYdk, 'chip'),
    button('Clear import', () => { pm.imported = []; pm.importName = ''; pm.source = 'search'; render(); }, 'chip'),
  );
  right.appendChild(row);
  right.appendChild(pmSourceGrid(shown, 'pm-ydk'));
}

/** Tiles you can drag into a rarity list (or click to add to the highlighted one). */
function pmSourceGrid(codes, scrollKey) {
  const grid = el('div', 'tile-grid');
  grid.dataset.keepScroll = scrollKey;
  for (const code of codes) {
    const tile = pmTile(code, null);
    const where = PM_RARITIES.filter((r) => pm.cards[r].includes(code));
    tile.appendChild(el('div', 'where', where.length ? where.map((r) => RARITY_LABEL[r].split(' ')[0]).join(', ') : ''));
    if (where.includes(pm.target)) tile.classList.add('used-up');
    tile.addEventListener('click', () => pmAdd(code, pm.target));
    grid.appendChild(tile);
  }
  if (!codes.length) grid.appendChild(el('div', 'muted small', 'All of these cards are in a list.'));
  return grid;
}

function pmPickYdk() {
  const input = el('input');
  input.type = 'file';
  input.accept = '.ydk';
  input.addEventListener('change', () => input.files[0] && pmImportYdk(input.files[0]));
  input.click();
}

/** Reads a .ydk (EDOPro deck file): every card in Main, Extra and Side, once each, in file order. */
function pmImportYdk(file) {
  if (!/\.ydk$/i.test(file.name)) { pm.error = 'That is not a .ydk file.'; render(); return; }
  const reader = new FileReader();
  reader.onload = async () => {
    const codes = [...new Set(String(reader.result).split(/\r?\n/).map((l) => l.trim()).filter((l) => /^\d+$/.test(l)).map(Number))];
    if (!codes.length) { pm.error = 'No cards found in that file.'; render(); return; }
    const { ok, data } = await api('POST', '/api/admin/card-texts', { codes });
    if (!ok) { pm.error = data.error; render(); return; }
    remember(data.texts);
    pm.imported = [...new Set([...pm.imported, ...data.codes])];
    pm.importName = pm.importName && pm.importName !== file.name ? `${pm.importName} + ${file.name}` : file.name;
    pm.source = 'ydk';
    pm.error = data.unknown.length ? `${data.unknown.length} card${data.unknown.length === 1 ? '' : 's'} in the file are not in the game: ${data.unknown.slice(0, 8).join(', ')}${data.unknown.length > 8 ? '...' : ''}` : '';
    pm.message = '';
    render();
  };
  reader.readAsText(file);
}

function pmTile(code, from) {
  const tile = el('div', 'tile mini');
  tile.draggable = true;
  tile.appendChild(cardEl({ code, faceDown: false, defense: false }, { allowRotate: false }));
  tile.addEventListener('mouseenter', () => showDetail(code));
  tile.addEventListener('dragstart', (ev) => {
    ev.dataTransfer.setData('application/x-yugs-card', JSON.stringify({ code, from }));
    ev.dataTransfer.effectAllowed = 'copyMove';
  });
  return tile;
}

function pmRarityList(r) {
  const zone = el('div', `pm-list${pm.target === r ? ' target' : ''}`);
  const head = el('div', 'pm-list-head');
  head.append(el('b', `rarity-${r}`, `${RARITY_LABEL[r]} (${pm.cards[r].length})`));
  if (!pm.cards[r].length) head.append(el('span', 'bad small', 'needs at least 1 card'));
  head.addEventListener('click', () => { pm.target = r; render(); });
  head.title = 'Click to make this the list that clicking a search result adds to';
  zone.appendChild(head);
  const grid = el('div', 'tile-grid');
  for (const code of pm.cards[r]) {
    const tile = pmTile(code, r);
    tile.addEventListener('click', () => { pm.cards[r] = pm.cards[r].filter((c) => c !== code); pm.dirty = true; render(); });
    grid.appendChild(tile);
  }
  if (!pm.cards[r].length) grid.appendChild(el('div', 'muted small', 'Drop cards here'));
  zone.appendChild(grid);
  zone.addEventListener('dragover', (ev) => {
    if (!ev.dataTransfer.types.includes('application/x-yugs-card')) return;
    ev.preventDefault();
    ev.dataTransfer.dropEffect = ev.ctrlKey ? 'copy' : 'move';
    zone.classList.add('drop-here');
  });
  zone.addEventListener('dragleave', () => zone.classList.remove('drop-here'));
  zone.addEventListener('drop', (ev) => {
    ev.preventDefault();
    zone.classList.remove('drop-here');
    let d;
    try { d = JSON.parse(ev.dataTransfer.getData('application/x-yugs-card')); } catch { return; }
    if (!d || d.from === r) return;
    if (d.from && !ev.ctrlKey) pm.cards[d.from] = pm.cards[d.from].filter((c) => c !== d.code); // move
    pmAdd(d.code, r);
  });
  return zone;
}

function pmAdd(code, r, noRender) {
  if (!pm.cards[r].includes(code)) pm.cards[r].push(code);
  pm.dirty = true;
  pm.message = '';
  if (!noRender) render();
}

function pmArtBox() {
  const wrap = el('div', 'pm-art');
  const pack = pmData.packs.find((p) => p.id === pm.packId);
  const frame = el('div', 'pm-art-frame');
  if (pack && pack.art) {
    const img = el('img');
    img.src = `${pack.art}?v=${Date.now() % 100000}`;
    img.alt = pack.name;
    frame.appendChild(img);
  } else frame.appendChild(el('span', 'muted small', pm.packId ? 'No artwork yet. Drop an image here' : 'Save the pack, then add artwork'));
  const input = el('input');
  input.type = 'file';
  input.accept = 'image/png,image/jpeg,image/webp,image/gif';
  input.style.display = 'none';
  input.addEventListener('change', () => input.files[0] && pmUploadArt(input.files[0]));
  wrap.append(frame, input);
  if (pm.packId) {
    wrap.appendChild(button(pack && pack.art ? 'Change artwork' : 'Upload artwork', () => input.click(), 'secondary'));
    frame.addEventListener('dragover', (ev) => { if (ev.dataTransfer.types.includes('Files')) { ev.preventDefault(); frame.classList.add('drop-here'); } });
    frame.addEventListener('dragleave', () => frame.classList.remove('drop-here'));
    frame.addEventListener('drop', (ev) => {
      ev.preventDefault();
      frame.classList.remove('drop-here');
      const file = ev.dataTransfer.files[0];
      if (file) pmUploadArt(file);
    });
  }
  return wrap;
}

function pmUploadArt(file) {
  if (file.size > 4 * 1024 * 1024) { pm.error = 'The image is too big (4 MB max).'; render(); return; }
  const reader = new FileReader();
  reader.onload = async () => {
    const { ok, data } = await api('POST', `/api/admin/packs/${encodeURIComponent(pm.packId)}/art`, { image: reader.result });
    pm.error = ok ? '' : data.error;
    pm.message = ok ? 'Artwork saved.' : '';
    if (ok) pmTake(data);
    render();
  };
  reader.readAsDataURL(file);
}

async function pmSave() {
  const { ok, data } = await api('POST', '/api/admin/packs', { id: pm.packId, name: pm.name, description: pm.description, cards: pm.cards });
  if (!ok) { pm.error = data.error; pm.message = ''; render(); return; }
  pmTake(data);
  const saved = data.packs.find((p) => p.id === data.saved);
  pm.packId = data.saved;
  pm.dirty = false;
  pm.error = '';
  pm.message = saved && !saved.ready
    ? `Saved as a draft: it still needs ${saved.missing.map((r) => RARITY_LABEL[r]).join(', ')} cards before it can go in the shop.`
    : 'Pack saved.';
  render();
}

async function pmCopy() {
  if (pm.dirty) { pm.error = 'Save this pack first (or pick it again to drop the changes), then copy it.'; pm.message = ''; render(); return; }
  const { ok, data } = await api('POST', `/api/admin/packs/${encodeURIComponent(pm.packId)}/copy`, {});
  if (!ok) { pm.error = data.error; pm.message = ''; render(); return; }
  pmTake(data);
  const copy = data.packs.find((p) => p.id === data.saved);
  pmOpen(copy);
  pm.error = '';
  pm.message = `Copied. You're now editing "${copy.name}": rename it, change what you like, then press Save pack.`;
  render();
}

async function pmDelete() {
  if (!confirm(`Delete the pack "${pm.name}"? Players keep the cards they already pulled from it.`)) return;
  const { ok, data } = await api('DELETE', `/api/admin/packs/${encodeURIComponent(pm.packId)}`);
  if (!ok) { pm.error = data.error; render(); return; }
  pmTake(data);
  pmOpen(null);
  pm.message = 'Pack deleted.';
  render();
}

// ------------------------------------------------------------------ shop lineup

function renderPmShop(box) {
  const shop = pmData.shop;
  const byId = (id) => pmData.packs.find((p) => p.id === id);
  const reset = new Date(shop.nextReset);
  const when = reset.toLocaleString(undefined, { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });

  const now = el('div', 'pm-shop-row');
  now.appendChild(el('h3', '', 'In the shop this week'));
  const nowRow = el('div', 'pm-slots');
  for (const id of shop.current) nowRow.appendChild(pmPackCard(byId(id), { id }));
  if (!shop.current.length) nowRow.appendChild(el('span', 'muted', 'Nothing.'));
  now.appendChild(nowRow);
  box.appendChild(now);

  const next = el('div', 'pm-shop-row');
  next.appendChild(el('h3', '', `Next week (from ${when}, your time)`));
  next.appendChild(el('p', 'muted small', shop.next
    ? 'Scheduled. Players see it when the week resets. You can change it until then.'
    : 'Nothing scheduled, so the shop keeps this week\'s packs. To change them, drag packs from the list below into the places and press "Schedule for next week".'));
  next.appendChild(el('p', 'muted small', 'The shop switches by itself at the weekly reset. "Start it now" switches right away instead (for example after a mistake, or to launch new packs early).'));
  const slots = el('div', 'pm-slots');
  for (let i = 0; i < shop.size; i++) {
    const id = pm.next[i];
    const slot = el('div', `pm-slot${id ? '' : ' empty'}`);
    if (id) {
      slot.appendChild(pmPackCard(byId(id), { id, from: i }));
      const x = button('Remove', () => { pm.next[i] = undefined; render(); }, 'ghost small');
      slot.appendChild(x);
    } else slot.appendChild(el('span', 'muted', `Place ${i + 1}: drop a pack here`));
    slot.addEventListener('dragover', (ev) => { if (ev.dataTransfer.types.includes('application/x-yugs-pack')) { ev.preventDefault(); slot.classList.add('drop-here'); } });
    slot.addEventListener('dragleave', () => slot.classList.remove('drop-here'));
    slot.addEventListener('drop', (ev) => {
      ev.preventDefault();
      let d;
      try { d = JSON.parse(ev.dataTransfer.getData('application/x-yugs-pack')); } catch { return; }
      const pack = byId(d.id);
      if (!pack || !pack.ready) { pm.error = pack ? `"${pack.name}" is a draft: it still needs ${pack.missing.map((r) => RARITY_LABEL[r]).join(', ')} cards.` : ''; render(); return; }
      const already = pm.next.indexOf(d.id);
      if (d.from !== undefined) pm.next[d.from] = pm.next[i];      // swap two places
      else if (already >= 0) pm.next[already] = undefined;         // a pack is only in one place
      pm.next[i] = d.id;
      pm.error = '';
      render();
    });
    slots.appendChild(slot);
  }
  next.appendChild(slots);
  const row = el('div', 'button-row');
  row.append(button('Schedule for next week', () => {
    const ids = pm.next.filter(Boolean);
    if (ids.length && ids.length < shop.size) { pm.error = `Fill all ${shop.size} places, or leave them all empty to keep this week's packs.`; pm.message = ''; render(); return; }
    pmSchedule(ids);
  }));
  if (shop.next) {
    row.append(button('Start it now', pmStartNow, 'secondary'));
    row.append(button('Cancel the schedule', () => { pm.next = shop.current.slice(); pmSchedule([]); }, 'ghost'));
  }
  next.appendChild(row);
  box.appendChild(next);

  const all = el('div', 'pm-shop-row');
  all.appendChild(el('h3', '', 'Your packs'));
  const list = el('div', 'pm-slots wrap');
  for (const p of pmData.packs) list.appendChild(pmPackCard(p, { id: p.id, draggable: p.ready }));
  all.appendChild(list);
  box.appendChild(all);
}

function pmPackCard(p, opts) {
  const card = el('div', `pm-pack${p && !p.ready ? ' draft' : ''}`);
  if (!p) { card.appendChild(el('span', 'bad small', `Missing pack "${opts.id}"`)); return card; }
  const art = el('div', 'pm-pack-art');
  if (p.art) { const img = el('img'); img.src = p.art; img.alt = ''; art.appendChild(img); } else art.appendChild(el('span', 'muted small', 'no art'));
  card.append(art, el('b', '', p.name));
  const count = PM_RARITIES.reduce((n, r) => n + (p.cards[r] || []).length, 0);
  card.appendChild(el('span', 'muted small', p.ready ? `${count} cards` : `Draft: needs ${p.missing.map((r) => RARITY_LABEL[r]).join(', ')}`));
  if (opts.draggable !== false || opts.from !== undefined) {
    card.draggable = true;
    card.addEventListener('dragstart', (ev) => {
      ev.dataTransfer.setData('application/x-yugs-pack', JSON.stringify({ id: p.id, from: opts.from }));
      ev.dataTransfer.effectAllowed = 'move';
    });
  }
  card.addEventListener('dblclick', () => { if (pmConfirmDiscard()) { pmOpen(p); pm.tab = 'edit'; render(); } });
  card.title = 'Drag into a shop place. Double-click to edit.';
  return card;
}

async function pmStartNow() {
  if (!confirm('Put next week\'s packs in the shop right now? Players see them immediately.')) return;
  const { ok, data } = await api('POST', '/api/admin/shop/start-now', {});
  if (!ok) { pm.error = data.error; render(); return; }
  pmTake(data);
  pm.next = (data.shop.current || []).slice(0, data.shop.size);
  pm.error = '';
  pm.message = 'Done: the new packs are in the shop now. Schedule the following week whenever you like.';
  render();
}

async function pmSchedule(ids) {
  const { ok, data } = await api('PUT', '/api/admin/shop', { next: ids });
  if (!ok) { pm.error = data.error; render(); return; }
  pmTake(data);
  pm.next = (data.shop.next || data.shop.current).slice(0, data.shop.size);
  pm.error = '';
  pm.message = ids.length ? 'Next week\'s shop is scheduled.' : 'Schedule cancelled: next week keeps this week\'s packs.';
  render();
}
