// Banlist editor (admins only): drag cards into Forbidden / Limited / Semi-Limited, then save.
// Uses helpers from app.js, menus.js and packMaker.js (pmTile).
'use strict';

const BAN_LISTS = ['forbidden', 'limited', 'semiLimited'];
let bl = null; // { lists, dirty, message, error, target, search state... }

function renderBanlistEditor(box) {
  if (!currentUser.isAdmin) { screen = 'home'; return renderHome(box); }
  if (!need('banlist')) { box.appendChild(el('p', 'muted', 'Loading the banlist...')); return; }
  if (!bl) {
    bl = {
      lists: { forbidden: [...cache.banlist.forbidden], limited: [...cache.banlist.limited], semiLimited: [...cache.banlist.semiLimited] },
      dirty: false, message: '', error: '', target: 'limited',
      f: CardFilter.emptyFilter(), sortBy: 'name', sortDesc: false, showFilters: false, results: [], total: 0, query: null,
    };
  }
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Banlist editor'), button(bl.dirty ? 'Save banlist *' : 'Save banlist', blSave),
    button('Back', () => { if (!bl.dirty || confirm('The banlist has unsaved changes. Discard them?')) { bl = null; screen = 'home'; render(); } }, 'secondary'));
  box.appendChild(top);
  if (bl.error) box.appendChild(el('div', 'error', bl.error));
  if (bl.message) box.appendChild(el('div', 'notice', bl.message));

  const layout = el('div', 'editor pm-editor');
  layout.appendChild(detailPanel());
  const mid = el('div', 'editor-deck');
  mid.dataset.keepScroll = 'bl-lists';
  mid.appendChild(el('div', 'muted small', 'Drag cards from the search into a list (or click a search result to add it to the highlighted list). Drag between lists to move a card. Click a card in a list to take it off the banlist. Decks that break the banlist can\'t be used in duels until they are fixed.'));
  for (const list of BAN_LISTS) mid.appendChild(blList(list));
  layout.appendChild(mid);

  const right = el('div', 'editor-collection');
  right.appendChild(collectionTools(bl));
  const f = bl.f;
  const active = f.q.trim().length >= 2 || CardFilter.isActive({ ...f, q: '' });
  const key = JSON.stringify(f);
  if (active && bl.query !== key) {
    bl.query = key;
    adminSearch(f.q, (found, total) => { bl.results = found; bl.total = total; render(); }, { ...f, q: '' });
  }
  if (!active) right.appendChild(el('div', 'muted small', 'Type 2+ letters or set a filter to search every card in the game.'));
  else {
    const shown = CardFilter.sort(bl.results, (c) => cardCache[c], bl.sortBy, bl.sortDesc).filter((c) => cardCache[c] && CardFilter.matches(cardCache[c], f));
    right.appendChild(el('div', 'muted small', `${shown.length}${bl.total > shown.length ? ` of ${bl.total}` : ''} cards found.`));
    const grid = el('div', 'tile-grid');
    grid.dataset.keepScroll = 'bl-search';
    for (const code of shown) {
      const tile = pmTile(code, null);
      const on = blListOf(code);
      tile.appendChild(el('div', 'where', on ? BAN_LABEL[on] : ''));
      if (on) tile.classList.add('used-up');
      tile.addEventListener('click', () => blPut(code, bl.target));
      grid.appendChild(tile);
    }
    right.appendChild(grid);
  }
  layout.appendChild(right);
  box.appendChild(layout);
}

function blListOf(code) {
  const name = cardName(code);
  return BAN_LISTS.find((l) => bl.lists[l].some((c) => c === code || cardName(c) === name)) || '';
}

/** A card is on at most one list: putting it somewhere takes it off the others. */
function blPut(code, list) {
  const name = cardName(code);
  for (const l of BAN_LISTS) bl.lists[l] = bl.lists[l].filter((c) => c !== code && cardName(c) !== name);
  if (list) bl.lists[list].push(code);
  bl.dirty = true;
  bl.message = '';
  render();
}

function blList(list) {
  const zone = el('div', `pm-list${bl.target === list ? ' target' : ''}`);
  const head = el('div', 'pm-list-head');
  head.append(el('b', `ban-title ban-${list}`, `${BAN_LABEL[list]} (${bl.lists[list].length}) · max ${BAN_MAX[list]} in a deck`));
  head.addEventListener('click', () => { bl.target = list; render(); });
  head.title = 'Click to make this the list that clicking a search result adds to';
  zone.appendChild(head);
  const grid = el('div', 'tile-grid');
  for (const code of [...bl.lists[list]].sort((a, b) => cardName(a).localeCompare(cardName(b)))) {
    const tile = pmTile(code, list);
    tile.addEventListener('click', () => blPut(code, ''));
    grid.appendChild(tile);
  }
  if (!bl.lists[list].length) grid.appendChild(el('div', 'muted small', 'Drop cards here'));
  zone.appendChild(grid);
  zone.addEventListener('dragover', (ev) => {
    if (!ev.dataTransfer.types.includes('application/x-yugs-card')) return;
    ev.preventDefault();
    zone.classList.add('drop-here');
  });
  zone.addEventListener('dragleave', () => zone.classList.remove('drop-here'));
  zone.addEventListener('drop', (ev) => {
    ev.preventDefault();
    zone.classList.remove('drop-here');
    let d;
    try { d = JSON.parse(ev.dataTransfer.getData('application/x-yugs-card')); } catch { return; }
    if (d && d.from !== list) blPut(d.code, list);
  });
  return zone;
}

async function blSave() {
  const { ok, data } = await api('PUT', '/api/admin/banlist', bl.lists);
  if (!ok) { bl.error = data.error; bl.message = ''; render(); return; }
  remember(data.texts);
  cache.banlist = { forbidden: data.forbidden, limited: data.limited, semiLimited: data.semiLimited };
  cache.decks = null; // deck problems change with the banlist
  bl.lists = { forbidden: [...data.forbidden], limited: [...data.limited], semiLimited: [...data.semiLimited] };
  bl.dirty = false;
  bl.error = '';
  bl.message = 'Banlist saved. It applies right away.';
  render();
}
