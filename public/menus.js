// Yugs menus outside of duels: home, starter deck choice, pack opening, deck editor.
// Shares helpers (el, $, api, cardEl, render...) with app.js.
'use strict';

/** 'home' | 'packs' | 'decks' */
let screen = 'home';
/** { starterChosen, freePacks, activeDeckId, coins } for the logged-in player. */
let profile = null;
let profileLoading = false;
const cache = { starters: null, packs: null, collection: null, decks: null, custom: null, banlist: null, news: null };
/** Card texts received outside of duels (collection, packs, starters). */
const cardCache = {};
let packResult = null;
let editor = null;
let menuMessage = '';
let expanded = new Set();

const RARITY_LABEL = { common: 'Common', rare: 'Rare', super: 'Super Rare', ultra: 'Ultra Rare', secret: 'Secret Rare' };

function remember(texts) {
  Object.assign(cardCache, texts || {});
}

function resetPlayerCache() {
  chatStop();
  profile = null;
  cache.starters = cache.packs = cache.collection = cache.decks = cache.custom = cache.banlist = cache.news = null;
  packResult = null;
  editor = null;
  screen = 'home';
  menuMessage = '';
}

async function loadProfile() {
  if (profileLoading) return;
  profileLoading = true;
  try {
    const { ok, data } = await api('GET', '/api/me');
    if (ok) {
      profile = data.profile;
      currentUser = data.user;
    } else {
      currentUser = null;
    }
  } finally {
    profileLoading = false;
    render();
  }
}

async function fetchData(what) {
  const urls = { starters: '/api/starters', packs: '/api/packs', collection: '/api/collection', decks: '/api/decks', custom: '/api/cards?custom=1', banlist: '/api/banlist', news: '/api/news' };
  const { ok, data } = await api('GET', urls[what]);
  if (!ok) {
    menuMessage = data.error || 'Could not load data.';
    return;
  }
  if (what === 'starters') { cache.starters = data.starters; remember(data.cards); }
  if (what === 'packs') { cache.packs = data.packs; remember(data.cards); }
  if (what === 'collection') { cache.collection = data.cards; remember(data.texts); }
  if (what === 'news') { cache.news = data; return; }
  if (what === 'banlist') { cache.banlist = { forbidden: data.forbidden, limited: data.limited, semiLimited: data.semiLimited }; remember(data.texts); }
  if (what === 'decks') { cache.decks = data.decks; remember(data.texts); }
  if (what === 'custom') { cache.custom = data.cards; remember(data.texts); }
}

/** Returns true when the data is ready; otherwise starts loading it and re-renders later. */
function need(...what) {
  const missing = what.filter((w) => cache[w] === null);
  if (!missing.length) return true;
  Promise.all(missing.map(fetchData)).then(render);
  return false;
}

function cardName(code) {
  return (cardCache[code] && cardCache[code].name) || `#${code}`;
}

function button(label, onClick, cls = '') {
  const b = el('button', cls, label);
  b.addEventListener('click', onClick);
  return b;
}

// ------------------------------------------------------------------ entry point (called by app.js)

function renderMenus(box) {
  const lobbyBox = $('lobby-box');
  lobbyBox.classList.toggle('wide', !!(profile && profile.starterChosen && ['packs', 'decks', 'test', 'packmaker', 'banlist', 'standings', 'tutorial', 'reports', 'players', 'maintenance', 'cpu'].includes(screen)));
  if (siteStatus.maintenance && !currentUser.isAdmin) return renderMaintenanceWait(box);
  if (screen === 'maintenance' && currentUser.isAdmin) return renderMaintenanceAdmin(box);
  if (!profile) {
    box.appendChild(el('p', 'muted', 'Loading your profile...'));
    loadProfile();
    return;
  }
  if (!profile.starterChosen) return renderStarterChoice(box);
  if (screen === 'packs') return renderPacks(box);
  if (screen === 'decks') return renderDeckEditor(box);
  if (screen === 'images') return renderImages(box);
  if (screen === 'standings') return renderStandings(box);
  if (screen === 'matching') return renderMatching(box);
  if (screen === 'tutorial') return renderTutorial(box);
  if (screen === 'reports' && currentUser.isAdmin) return renderReports(box);
  if (screen === 'players' && currentUser.isAdmin) return renderPlayers(box);
  if (screen === 'cpu' && cpuAvailable) return renderCpuSetup(box);
  if (screen === 'test' && currentUser.isAdmin) return renderTestSetup(box);
  if (screen === 'packmaker' && currentUser.isAdmin) return renderPackMaker(box);
  if (screen === 'banlist' && currentUser.isAdmin) return renderBanlistEditor(box);
  return renderHome(box);
}

// ------------------------------------------------------------------ home

function renderHome(box) {
  box.appendChild(userBarEl());
  if (menuMessage) box.appendChild(el('div', 'notice', menuMessage));
  box.appendChild(discordBox());
  if (profile.freePacks > 0) {
    const banner = el('div', 'banner');
    banner.append(el('b', '', `You have ${profile.freePacks} free pack${profile.freePacks === 1 ? '' : 's'} to open!`),
      button('Open packs', () => { screen = 'packs'; menuMessage = ''; render(); }));
    box.appendChild(banner);
  }
  if (need('decks')) {
    const active = cache.decks.find((d) => d.active);
    const line = el('p', 'muted');
    line.textContent = active ? `Active deck: ${active.name}${active.problems.length ? ' (not usable yet)' : ''}` : 'No active deck.';
    box.appendChild(line);
  }
  if (lobbyError) box.appendChild(el('div', 'error', lobbyError));
  const grid = el('div', 'menu-grid');
  grid.append(
    button('Find a duel (ranked)', () => { screen = 'matching'; matchState = null; menuMessage = ''; findDuel(); render(); }),
    button('Duel a friend (invite link)', createOnline, 'secondary'),
    ...(cpuAvailable ? [button('Duel vs CPU (this PC only)', () => { screen = 'cpu'; lobbyError = ''; render(); }, 'secondary')] : []),
    button('Deck editor', () => { screen = 'decks'; menuMessage = ''; render(); }, 'secondary'),
    button(profile.freePacks > 0 ? 'Open packs' : 'Packs', () => { screen = 'packs'; menuMessage = ''; render(); }, 'secondary'),
    button('Standings', () => { screen = 'standings'; standings = null; menuMessage = ''; render(); }, 'secondary'),
    button('Card images', () => { screen = 'images'; menuMessage = ''; render(); }, 'secondary'),
    button('How Yugs works', () => { screen = 'tutorial'; render(); }, 'secondary'),
    button('Report a bug', () => openBugReport(), 'secondary'),
    button('Rules & privacy', () => openRules(), 'secondary'),
  );
  if (currentUser.isAdmin) grid.append(
    button('Test duel (admin)', () => { screen = 'test'; lobbyError = ''; render(); }, 'secondary admin'),
    button('Pack Maker (admin)', () => { screen = 'packmaker'; menuMessage = ''; render(); }, 'secondary admin'),
    button('Banlist editor (admin)', () => { screen = 'banlist'; menuMessage = ''; render(); }, 'secondary admin'),
    button(siteStatus.maintenance ? 'Maintenance: ON (admin)' : 'Maintenance (admin)', () => { screen = 'maintenance'; menuMessage = ''; render(); }, 'secondary admin'),
    button('Players (admin)', () => { screen = 'players'; playersView.list = null; playersView.openId = null; menuMessage = ''; render(); }, 'secondary admin'),
    button('Bug reports (admin)', () => { screen = 'reports'; reportsView.data = null; menuMessage = ''; render(); }, 'secondary admin'),
  );
  box.appendChild(grid);
  box.appendChild(el('p', 'muted small beta-note', 'Yugs is in beta: expect some bugs and the odd maintenance day. If something looks wrong, press Report a bug.'));
  if (need('news') && cache.news.homeNote) box.appendChild(renderMarkdown(cache.news.homeNote)).classList.add('home-note');
  box.appendChild(chatSection());
  box.appendChild(newsSection());
}

// ------------------------------------------------------------------ maintenance

function renderMaintenanceWait(box) {
  box.appendChild(userBarEl());
  box.appendChild(el('p', '', 'New duels are paused for a moment. If you were in an online duel, open its link again to finish it.'));
  box.appendChild(button('Check again', () => loadSiteStatus(), 'secondary'));
}

function renderMaintenanceAdmin(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Maintenance mode'), button('Back', () => { screen = 'home'; menuMessage = ''; render(); }, 'secondary'));
  box.appendChild(top);
  box.appendChild(el('p', 'muted small', 'Turn this on a few minutes before you update the server. Players can\'t start new duels (ranked or with a friend) and see your message instead of the menus; duels already running can be finished. You can still do everything. It stays on after a restart until you turn it off.'));
  const msg = el('textarea', 'text-input');
  msg.rows = 3;
  msg.maxLength = 500;
  msg.placeholder = 'Message for players (optional), e.g. "Updating to add new cards, back in about 15 minutes."';
  msg.value = siteStatus.maintenance ? siteStatus.message : '';
  box.appendChild(msg);
  if (menuMessage) box.appendChild(el('div', 'error', menuMessage));
  const save = async (on) => {
    const { ok, data } = await api('POST', '/api/admin/status', { maintenance: on, message: msg.value });
    if (!ok) { menuMessage = data.error; render(); return; }
    siteStatus = data;
    menuMessage = '';
    render();
  };
  const row = el('div', 'button-row');
  if (siteStatus.maintenance) row.append(button('Update message', () => save(true), 'secondary'), button('Turn OFF', () => save(false)));
  else row.append(button('Turn ON', () => save(true), 'danger'));
  box.appendChild(el('p', '', siteStatus.maintenance ? 'Maintenance mode is ON.' : 'Maintenance mode is off.'));
  box.appendChild(row);
}

// ------------------------------------------------------------------ add an email (accounts made before email sign-up)

let addEmailState = { sentTo: '', error: '', busy: false };

function addEmailBox() {
  const box = el('div', 'add-email');
  box.appendChild(el('b', '', 'Add an email to your account'));
  box.appendChild(el('p', 'muted small', 'Without one you can\'t reset your password if you forget it. Other players never see it.'));
  const form = el('form', 'add-email-form');
  const field = el('input', 'text-input');
  const step2 = !!addEmailState.sentTo;
  if (step2) {
    field.placeholder = '6-digit code';
    field.inputMode = 'numeric';
    field.autocomplete = 'one-time-code';
    field.maxLength = 6;
    box.appendChild(el('p', 'notice small', `We sent a code to ${addEmailState.sentTo}.`));
  } else {
    field.type = 'email';
    field.placeholder = 'Email';
    field.autocomplete = 'email';
  }
  field.required = true;
  const go = el('button', '', addEmailState.busy ? 'Please wait...' : step2 ? 'Confirm' : 'Send code');
  go.type = 'submit';
  go.disabled = addEmailState.busy;
  form.append(field, go);
  if (step2) form.appendChild(button('Change email', () => { addEmailState = { sentTo: '', error: '', busy: false }; render(); }, 'link-button'));
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const value = field.value.trim();
    addEmailState.busy = true;
    addEmailState.error = '';
    render();
    const { ok, data } = await api('POST', step2 ? '/api/auth/email-code' : '/api/auth/email', step2 ? { code: value } : { email: value })
      .catch(() => ({ ok: false, data: { error: 'Cannot reach the server.' } }));
    addEmailState.busy = false;
    if (!ok) addEmailState.error = data.error;
    else if (step2) { needsEmail = false; addEmailState = { sentTo: '', error: '', busy: false }; menuMessage = 'Email added. Thanks!'; }
    else addEmailState.sentTo = value;
    render();
  });
  box.appendChild(form);
  if (addEmailState.error) box.appendChild(el('div', 'error', addEmailState.error));
  return box;
}

function userBarEl() {
  const bar = el('div', 'user-bar');
  bar.append(document.createTextNode('Logged in as '), el('b', '', currentUser.username),
    el('span', 'muted', ` · ELO ${currentUser.elo} · ${profile ? profile.coins : currentUser.coins} coins`));
  const out = el('button', 'link-button', 'Log out');
  out.addEventListener('click', logout);
  bar.appendChild(out);
  return bar;
}

// ------------------------------------------------------------------ starter choice

function renderStarterChoice(box) {
  box.appendChild(userBarEl());
  box.appendChild(el('h2', '', 'Choose your starter deck'));
  box.appendChild(el('p', 'muted', 'This is a one-time choice. You also get 3 free packs right after.'));
  if (menuMessage) box.appendChild(el('div', 'error', menuMessage));
  if (!need('starters')) {
    box.appendChild(el('p', 'muted', 'Loading...'));
    return;
  }
  const list = el('div', 'starter-list');
  for (const s of cache.starters) {
    const item = el('div', 'starter');
    item.appendChild(el('h3', '', s.name));
    item.appendChild(el('p', '', s.description));
    const unique = [...new Set(s.main)];
    const monsters = unique.filter((c) => cardCache[c] && cardCache[c].isMonster).sort((a, b) => (cardCache[b].atk || 0) - (cardCache[a].atk || 0));
    item.appendChild(el('p', 'muted small', `Key cards: ${monsters.slice(0, 4).map(cardName).join(', ')}`));
    const showAll = expanded.has(s.id);
    if (showAll) {
      const ul = el('ul', 'card-list');
      const counts = new Map();
      for (const c of [...s.main, ...s.extra]) counts.set(c, (counts.get(c) || 0) + 1);
      for (const [code, n] of counts) {
        const li = el('li', '', `${n}x ${cardName(code)}${s.extra.includes(code) ? ' (Extra Deck)' : ''}`);
        ul.appendChild(li);
      }
      item.appendChild(ul);
    }
    const row = el('div', 'button-row');
    row.append(
      button(showAll ? 'Hide card list' : 'See all cards', () => { showAll ? expanded.delete(s.id) : expanded.add(s.id); render(); }, 'secondary'),
      button(`Choose ${s.name}`, () => chooseStarter(s)),
    );
    item.appendChild(row);
    list.appendChild(item);
  }
  box.appendChild(list);
}

async function chooseStarter(s) {
  if (!confirm(`Choose ${s.name}? You can't change this later.`)) return;
  const { ok, data } = await api('POST', '/api/starters/choose', { starterId: s.id });
  if (!ok) {
    menuMessage = data.error;
  } else {
    profile = data.profile;
    cache.collection = cache.decks = null;
    menuMessage = '';
    screen = 'packs';
  }
  render();
}

// ------------------------------------------------------------------ packs

function chancesText(pack) {
  const special = pack.slots.find((sl) => Object.keys(sl.chances).length > 1) || pack.slots[pack.slots.length - 1];
  return Object.entries(special.chances).filter(([, v]) => v > 0).map(([r, v]) => `${RARITY_LABEL[r]} ${v}%`).join(' · ');
}

function renderPacks(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', packResult ? packResult.pack.name : 'Packs'),
    el('span', 'muted', `Free packs left: ${profile.freePacks} · ${profile.coins} coins`),
    button('Back', () => { packResult = null; screen = 'home'; render(); }, 'secondary'));
  box.appendChild(top);
  if (menuMessage) box.appendChild(el('div', 'error', menuMessage));
  if (packResult) return renderPackResult(box);
  if (!need('packs')) {
    box.appendChild(el('p', 'muted', 'Loading...'));
    return;
  }
  box.appendChild(el('p', canBuyPack() ? 'notice' : 'muted', shopStatusText()));
  const list = el('div', 'pack-list');
  for (const p of cache.packs) {
    const item = el('div', 'pack');
    if (p.art) {
      const img = el('img', 'pack-art');
      img.src = p.art;
      img.alt = p.name;
      item.appendChild(img);
    }
    item.appendChild(el('h3', '', p.name));
    item.appendChild(el('p', '', p.description));
    item.appendChild(el('p', 'muted small', `${p.size} cards per pack. Special card: ${chancesText(p)}`));
    const showAll = expanded.has(p.id);
    if (showAll) {
      for (const r of ['secret', 'ultra', 'super', 'rare', 'common']) {
        const codes = p.cards[r];
        if (!codes || !codes.length) continue;
        const line = el('p', 'small');
        line.append(el('b', `rarity-${r}`, `${RARITY_LABEL[r]}: `), document.createTextNode(codes.map(cardName).join(', ')));
        item.appendChild(line);
      }
    }
    const row = el('div', 'button-row');
    row.append(button(showAll ? 'Hide cards' : 'See cards in this pack', () => { showAll ? expanded.delete(p.id) : expanded.add(p.id); render(); }, 'secondary'));
    if (profile.freePacks > 0) row.append(button('Open (free)', () => openPack(p, false)));
    else {
      const buy = button(`Buy (${profile.shop.price} coins)`, () => openPack(p, true));
      buy.disabled = !canBuyPack();
      row.append(buy);
    }
    item.appendChild(row);
    list.appendChild(item);
  }
  box.appendChild(list);
}

// Buying packs: coins, finished duels since the last bought pack, and the lock after a few packs.
function canBuyPack() {
  const s = profile.shop;
  return !s.lockedUntil && s.packsBeforeLock > 0 && s.duels >= s.duelsNeeded && profile.coins >= s.price;
}

function shopStatusText() {
  const s = profile.shop;
  if (s.lockedUntil) {
    const when = new Date(s.lockedUntil).toLocaleString(undefined, { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });
    return `You bought your packs for now. You can buy again on ${when} (your time).`;
  }
  const parts = [`A pack costs ${s.price} coins (you have ${profile.coins})`];
  parts.push(s.duels >= s.duelsNeeded ? 'duels: done' : `play ${s.duelsNeeded - s.duels} more duel${s.duelsNeeded - s.duels === 1 ? '' : 's'} first (${s.duels}/${s.duelsNeeded})`);
  parts.push(`${s.packsBeforeLock} more pack${s.packsBeforeLock === 1 ? '' : 's'} before the ${s.lockDays}-day wait`);
  return parts.join(' · ') + '.';
}

async function openPack(p, buy) {
  menuMessage = '';
  const { ok, data } = await api('POST', `/api/packs/${p.id}/${buy ? 'buy' : 'open-free'}`, {});
  if (!ok) {
    menuMessage = data.error;
  } else {
    remember(data.cardTexts);
    if (buy) {
      profile = { ...profile, ...data.profile };
      currentUser.coins = profile.coins;
    } else profile.freePacks = data.freePacksLeft;
    packResult = { pack: data.pack, cards: data.cards, revealed: new Set(), guaranteed: data.guaranteed };
    cache.collection = null;
    cache.decks = null;
  }
  render();
}

function renderPackResult(box) {
  const r = packResult;
  const grid = el('div', 'pack-reveal');
  r.cards.forEach((c, i) => {
    const tile = el('div', `reveal-tile rarity-${c.rarity}`);
    if (r.revealed.has(i)) {
      tile.appendChild(cardEl({ code: c.code, faceDown: false, defense: false }, { allowRotate: false }));
      const tags = el('div', 'tags');
      if (c.rarity !== 'common') tags.appendChild(el('span', `tag rarity-${c.rarity}`, RARITY_LABEL[c.rarity]));
      if (c.isNew) tags.appendChild(el('span', 'tag new', 'NEW'));
      if (c.maxed) tags.appendChild(el('span', 'tag maxed', 'Already 3'));
      tile.appendChild(tags);
      tile.addEventListener('mouseenter', () => showDetail(c.code));
    } else {
      tile.appendChild(cardEl({ code: 0, faceDown: true }));
      tile.classList.add('hidden-card');
      tile.title = 'Click to reveal';
      tile.addEventListener('click', () => { r.revealed.add(i); render(); });
    }
    grid.appendChild(tile);
  });
  box.appendChild(grid);
  const row = el('div', 'button-row');
  if (r.revealed.size < r.cards.length) {
    row.append(button('Reveal all', () => { r.cards.forEach((_, i) => r.revealed.add(i)); render(); }));
  } else {
    if (r.guaranteed) box.appendChild(el('p', 'notice', 'Your last pack was all Commons, so this pack\'s last card was guaranteed Rare or better.'));
    const newCount = r.cards.filter((c) => c.isNew).length;
    box.appendChild(el('p', 'muted', `${newCount} new card${newCount === 1 ? '' : 's'} added to your collection.`));
    if (profile.freePacks > 0) row.append(button(`Open another (${profile.freePacks} left)`, () => { packResult = null; render(); }));
    else if (canBuyPack()) row.append(button('Buy another', () => { packResult = null; render(); }));
    row.append(button('Go to deck editor', () => { packResult = null; screen = 'decks'; render(); }, 'secondary'));
  }
  box.appendChild(row);
  box.appendChild(detailPanel('side'));
}

/** Card text panel for menu screens. 'side' = picture on the left, text on the right. */
function detailPanel(layout) {
  const d = el('div', layout === 'side' ? 'menu-detail side' : 'menu-detail');
  d.id = 'menu-detail';
  d.appendChild(el('div', 'muted small', 'Hover over a card (or tap it on a phone) to read it.'));
  return d;
}

// ------------------------------------------------------------------ deck editor

const BAN_LABEL = { forbidden: 'Forbidden', limited: 'Limited', semiLimited: 'Semi-Limited' };
const BAN_MAX = { forbidden: 0, limited: 1, semiLimited: 2 };
/** Which banlist list a card is on ('' if none). Alternate artworks share the name, so match by name. */
function banStatus(code) {
  if (!cache.banlist) return '';
  const name = cardName(code);
  for (const list of ['forbidden', 'limited', 'semiLimited']) if (cache.banlist[list].some((c) => c === code || cardName(c) === name)) return list;
  return '';
}
function banBadge(code) {
  const st = banStatus(code);
  if (!st) return null;
  const b = el('span', `ban-badge ban-${st}`, String(BAN_MAX[st]));
  b.title = BAN_LABEL[st];
  return b;
}

function isExtraCard(code) {
  const t = cardCache[code];
  return !!t && t.isMonster && ['fusion', 'synchro', 'xyz', 'link'].includes(t.frame);
}

function sortCodes(codes) {
  const rank = (c) => {
    const t = cardCache[c];
    if (!t) return 9;
    if (t.isMonster) return isExtraCard(c) ? 3 : 0;
    return t.frame === 'spell' ? 1 : 2;
  };
  return [...codes].sort((a, b) => rank(a) - rank(b) || ((cardCache[b] || {}).level || 0) - ((cardCache[a] || {}).level || 0) || cardName(a).localeCompare(cardName(b)));
}

function openDeckInEditor(deck) {
  editor = {
    deckId: deck ? deck.id : null,
    name: deck ? deck.name : 'New deck',
    main: deck ? [...deck.main] : [],
    extra: deck ? [...deck.extra] : [],
    problems: deck ? deck.problems : [],
    testOnly: deck ? deck.testOnly || [] : [],
    dirty: false,
    // search filters and sort order stay when you switch decks
    f: (editor && editor.f) || CardFilter.emptyFilter(),
    sortBy: (editor && editor.sortBy) || 'default',
    sortDesc: !!(editor && editor.sortDesc),
    showFilters: !!(editor && editor.showFilters),
    message: '',
  };
}

function confirmDiscard() {
  return !editor || !editor.dirty || confirm('You have unsaved changes. Discard them?');
}

function renderDeckEditor(box) {
  const wanted = currentUser && currentUser.isAdmin ? ['decks', 'collection', 'custom', 'banlist'] : ['decks', 'collection', 'banlist'];
  if (!need(...wanted)) {
    box.appendChild(el('p', 'muted', 'Loading your cards...'));
    return;
  }
  if (!editor) openDeckInEditor(cache.decks.find((d) => d.active) || cache.decks[0] || null);
  const ed = editor;
  const owned = new Map(cache.collection.map((c) => [c.code, c.copies]));
  const used = new Map();
  for (const c of [...ed.main, ...ed.extra]) used.set(c, (used.get(c) || 0) + 1);
  const current = cache.decks.find((d) => d.id === ed.deckId);

  // Top bar: pick deck, name, save, activate, delete, back
  const top = el('div', 'screen-top');
  const select = el('select', 'deck-select');
  for (const d of cache.decks) {
    const o = el('option', '', `${d.name}${d.active ? ' (active)' : ''}${d.problems.length ? ' - unfinished' : d.testOnly && d.testOnly.length ? ' - test only' : ''}`);
    o.value = String(d.id);
    if (d.id === ed.deckId) o.selected = true;
    select.appendChild(o);
  }
  const newOpt = el('option', '', '+ New deck');
  newOpt.value = 'new';
  if (ed.deckId === null) newOpt.selected = true;
  select.appendChild(newOpt);
  select.addEventListener('change', () => {
    if (confirmDiscard()) openDeckInEditor(select.value === 'new' ? null : cache.decks.find((d) => String(d.id) === select.value));
    render();
  });
  const nameInput = el('input', 'text-input deck-name');
  nameInput.value = ed.name;
  nameInput.maxLength = 40;
  nameInput.addEventListener('input', () => { ed.name = nameInput.value; ed.dirty = true; });
  top.append(select, nameInput, button(ed.dirty ? 'Save *' : 'Save', saveDeck));
  if (!(current && current.active)) top.append(button('Make active', activateDeck, 'secondary'));
  if (current && !current.active) top.append(button('Delete', deleteDeck, 'ghost'));
  top.append(button('Back', () => { if (confirmDiscard()) { editor = null; screen = 'home'; render(); } }, 'secondary'));
  box.appendChild(top);

  // Status line + problems
  const status = el('div', 'deck-status');
  status.append(
    el('span', ed.main.length >= 40 && ed.main.length <= 60 ? 'good' : 'bad', `Main ${ed.main.length} (40-60)`),
    el('span', ed.extra.length <= 15 ? 'good' : 'bad', `Extra ${ed.extra.length} (max 15)`),
  );
  if (current && current.active) status.appendChild(el('span', 'tag new', 'Active deck'));
  if (ed.dirty) status.appendChild(el('span', 'muted', 'Unsaved changes'));
  if (ed.message) status.appendChild(el('span', 'muted', ed.message));
  box.appendChild(status);
  if (!ed.dirty && ed.problems.length) {
    const ul = el('ul', 'problems');
    for (const p of ed.problems.slice(0, 6)) ul.appendChild(el('li', '', p));
    box.appendChild(ul);
  }
  if (!ed.dirty && !ed.problems.length && ed.testOnly && ed.testOnly.length) {
    box.appendChild(el('p', 'notice small', `Test duels only (admin): this deck breaks the banlist or the 3-copy rule (${ed.testOnly.slice(0, 3).join(' ')}). It can't be used against players.`));
  }

  const layout = el('div', 'editor');
  layout.appendChild(detailPanel());

  const deckCol = el('div', 'editor-deck');
  deckCol.dataset.keepScroll = 'deck';
  deckCol.appendChild(el('h3', '', `Main Deck (${ed.main.length})`));
  deckCol.appendChild(tileGrid(sortCodes(ed.main), (code) => removeCard(code, 'main')));
  deckCol.appendChild(el('h3', '', `Extra Deck (${ed.extra.length})`));
  deckCol.appendChild(tileGrid(sortCodes(ed.extra), (code) => removeCard(code, 'extra')));
  deckCol.appendChild(el('div', 'muted small', 'Click a card in your deck to take it out.'));
  layout.appendChild(deckCol);

  const colCol = el('div', 'editor-collection');
  colCol.appendChild(collectionTools(ed));
  const f = ed.f;
  const filtering = CardFilter.isActive(f);
  // Admins browse every card in the game (server search) instead of a collection.
  const admin = currentUser && currentUser.isAdmin;
  const serverSearch = admin && (f.q.trim().length >= 2 || CardFilter.isActive({ ...f, q: '' }));
  if (admin) {
    for (const code of ed.adminResults || []) if (!owned.has(code)) owned.set(code, 3);
    const key = JSON.stringify(f);
    if (serverSearch && ed.adminQuery !== key) {
      ed.adminQuery = key;
      adminSearch(f.q, (found, total) => { ed.adminResults = found; ed.adminTotal = total; render(); }, { ...f, q: '' });
    }
  }
  // Admins with no search: their collection plus every custom card.
  const adminDefault = admin ? [...new Set([...cache.custom, ...cache.collection.map((c) => c.code)])] : [];
  const pool = admin ? (serverSearch ? ed.adminResults || [] : adminDefault) : cache.collection.map((c) => c.code);
  const shown = CardFilter.sort(pool, (code) => cardCache[code], ed.sortBy, ed.sortDesc)
    .filter((code) => cardCache[code] && (!filtering || CardFilter.matches(cardCache[code], f)));
  colCol.appendChild(el('div', 'muted small', admin
    ? (serverSearch
      ? `Admin: ${shown.length}${ed.adminTotal > shown.length ? ` of ${ed.adminTotal}` : ''} cards from the whole game match. Click to add.`
      : 'Admin: showing your collection + all custom cards. Search (2+ letters) or a filter looks through every card in the game. Click to add.')
    : `Your collection: ${shown.length} of ${cache.collection.length} cards shown. Click to add. (in deck / owned)`));
  const grid = el('div', 'tile-grid');
  grid.dataset.keepScroll = 'collection';
  for (const code of shown) {
    const have = admin ? 3 : owned.get(code) || 0;
    const inDeck = used.get(code) || 0;
    const tile = el('div', 'tile mini');
    const banSt = banStatus(code);
    if (inDeck >= Math.min(have, 3, banSt ? BAN_MAX[banSt] : 3)) tile.classList.add('used-up');
    tile.appendChild(cardEl({ code, faceDown: false, defense: false }, { allowRotate: false }));
    const badge = banBadge(code);
    if (badge) tile.appendChild(badge);
    tile.appendChild(el('div', 'where', `${inDeck} / ${have}`));
    tile.addEventListener('mouseenter', () => showDetail(code));
    tile.addEventListener('click', () => { if (!phoneFirstTap(code)) addCard(code, have, inDeck); });
    grid.appendChild(tile);
  }
  colCol.appendChild(grid);
  layout.appendChild(colCol);
  box.appendChild(layout);
}

// Search box, sort order and the filter panel above the collection.
const RANGE_OPS = [['any', 'Any'], ['eq', '='], ['ge', '≥'], ['le', '≤'], ['between', 'Between']];

function collectionTools(ed) {
  const f = ed.f;
  const tools = el('div', 'collection-tools');
  const search = el('input', 'text-input collection-search');
  search.placeholder = 'Search your cards (name or text)...';
  search.value = f.q;
  search.addEventListener('input', () => { f.q = search.value; keepFocus('.collection-search', render); });
  tools.appendChild(search);

  const row = el('div', 'filters');
  const sortSel = select(CardFilter.SORTS, ed.sortBy, (v) => { ed.sortBy = v; render(); });
  sortSel.title = 'Sort by';
  row.append(el('span', 'muted small', 'Sort'), sortSel);
  const dir = button(ed.sortDesc ? '↓ High-Low / Z-A' : '↑ Low-High / A-Z', () => { ed.sortDesc = !ed.sortDesc; render(); }, 'chip');
  if (ed.sortBy === 'default') dir.disabled = true;
  row.appendChild(dir);
  const active = ['frame', 'icon', 'attribute', 'race', 'genre'].filter((k) => f[k]).length
    + ['level', 'rank', 'atk', 'def'].filter((k) => f[k].op !== 'any').length;
  row.appendChild(button(`Filters${active ? ` (${active})` : ''} ${ed.showFilters ? '▴' : '▾'}`, () => { ed.showFilters = !ed.showFilters; render(); }, active ? 'chip active' : 'chip'));
  if (active || f.q) row.appendChild(button('Clear all', () => { ed.f = CardFilter.emptyFilter(); render(); }, 'chip'));
  tools.appendChild(row);
  if (!ed.showFilters) return tools;

  const panel = el('div', 'filter-panel');
  const pick = (label, key, options) => {
    const wrap = el('label', 'filter-field');
    wrap.append(el('span', '', label), select([['', 'Any'], ...options.map((o) => (Array.isArray(o) ? o.slice(0, 2) : [o, o]))], f[key], (v) => { f[key] = v; render(); }));
    panel.appendChild(wrap);
  };
  pick('Frame', 'frame', CardFilter.FRAMES);
  pick('Icon (Spell/Trap)', 'icon', CardFilter.ICONS);
  pick('Attribute', 'attribute', CardFilter.ATTRIBUTES);
  pick('Type', 'race', CardFilter.RACES);
  pick('Genre', 'genre', CardFilter.GENRES);
  const range = (label, key, values, step) => {
    const r = f[key];
    const wrap = el('label', 'filter-field range');
    wrap.appendChild(el('span', '', label));
    wrap.appendChild(select(RANGE_OPS, r.op, (v) => {
      r.op = v;
      if (v !== 'any' && r.a === '') r.a = values ? values[0] : 0;
      if (v === 'between' && r.b === '') r.b = values ? values[values.length - 1] : 3000;
      render();
    }));
    if (r.op !== 'any') {
      const input = (which) => {
        if (values) return select(values.map((n) => [String(n), String(n)]), String(r[which]), (v) => { r[which] = Number(v); render(); });
        // ATK / DEF: hundreds only
        const box = el('input', 'text-input num');
        box.type = 'number'; box.min = '0'; box.max = '10000'; box.step = String(step);
        box.value = String(r[which]);
        box.addEventListener('change', () => { r[which] = Math.max(0, Math.round(Number(box.value || 0) / step) * step); render(); });
        return box;
      };
      wrap.appendChild(input('a'));
      if (r.op === 'between') { wrap.appendChild(el('span', 'muted', 'and')); wrap.appendChild(input('b')); }
    }
    panel.appendChild(wrap);
  };
  const nums = (from, to) => Array.from({ length: to - from + 1 }, (_, i) => from + i);
  range('Level', 'level', nums(1, 12));
  range('Rank', 'rank', nums(0, 13));
  range('ATK', 'atk', null, 100);
  range('DEF', 'def', null, 100);
  tools.appendChild(panel);
  return tools;
}

function select(options, value, onChange) {
  const s = el('select', 'filter-select');
  for (const [v, label] of options) {
    const o = el('option', '', label);
    o.value = v;
    if (String(v) === String(value)) o.selected = true;
    s.appendChild(o);
  }
  s.addEventListener('change', () => onChange(s.value));
  return s;
}

function tileGrid(codes, onClick) {
  const grid = el('div', 'tile-grid');
  for (const code of codes) {
    const tile = el('div', 'tile mini');
    tile.appendChild(cardEl({ code, faceDown: false, defense: false }, { allowRotate: false }));
    const badge = banBadge(code);
    if (badge) tile.appendChild(badge);
    tile.addEventListener('mouseenter', () => showDetail(code));
    tile.addEventListener('click', () => { if (!phoneFirstTap(code)) onClick(code); });
    grid.appendChild(tile);
  }
  if (!codes.length) grid.appendChild(el('div', 'muted small', 'Empty'));
  return grid;
}

function addCard(code, have, inDeck) {
  const ed = editor;
  ed.message = '';
  const ban = banStatus(code);
  const admin = currentUser && currentUser.isAdmin; // admins may ignore the banlist and the 3-copy rule (Test duels only)
  if (admin && isExtraCard(code) && ed.extra.length >= 15) ed.message = 'The Extra Deck is full (15).';
  else if (admin && !isExtraCard(code) && ed.main.length >= 60) ed.message = 'The Main Deck is full (60).';
  else if (admin) {
    (isExtraCard(code) ? ed.extra : ed.main).push(code);
    ed.dirty = true;
    if (ban || inDeck >= 3) ed.message = 'Over the banlist / 3-copy limit: this deck will be for Test duels only.';
  } else if (ban && inDeck >= BAN_MAX[ban]) ed.message = ban === 'forbidden' ? `${cardName(code)} is Forbidden.` : `${cardName(code)} is ${BAN_LABEL[ban]}: max ${BAN_MAX[ban]}.`;
  else if (inDeck >= 3) ed.message = 'Max 3 copies of a card.';
  else if (inDeck >= have) ed.message = `You only own ${have}.`;
  else if (isExtraCard(code) && ed.extra.length >= 15) ed.message = 'The Extra Deck is full (15).';
  else if (!isExtraCard(code) && ed.main.length >= 60) ed.message = 'The Main Deck is full (60).';
  else {
    (isExtraCard(code) ? ed.extra : ed.main).push(code);
    ed.dirty = true;
  }
  render();
}

function removeCard(code, where) {
  const list = editor[where];
  const i = list.indexOf(code);
  if (i >= 0) list.splice(i, 1);
  editor.dirty = true;
  editor.message = '';
  render();
}

async function saveDeck() {
  const ed = editor;
  const body = { name: ed.name, main: ed.main, extra: ed.extra };
  const { ok, data } = ed.deckId === null ? await api('POST', '/api/decks', body) : await api('PUT', `/api/decks/${ed.deckId}`, body);
  if (!ok) {
    ed.message = data.error;
  } else {
    ed.deckId = data.deck.id;
    ed.problems = data.deck.problems;
    ed.testOnly = data.deck.testOnly || [];
    ed.dirty = false;
    ed.message = data.deck.problems.length ? 'Saved, but this deck is not ready to duel yet:'
      : ed.testOnly.length ? 'Saved. This deck works in Test duels only.' : 'Saved. This deck is ready to duel.';
    await fetchData('decks');
  }
  render();
}

async function activateDeck() {
  if (editor.dirty) await saveDeck();
  if (editor.deckId === null) return;
  const { ok, data } = await api('POST', `/api/decks/${editor.deckId}/activate`, {});
  editor.message = ok ? 'This is now your active deck: you will duel with it.' : data.error;
  if (ok) {
    profile.activeDeckId = editor.deckId;
    await fetchData('decks');
  }
  render();
}

async function deleteDeck() {
  if (editor.deckId === null || !confirm(`Delete the deck "${editor.name}"?`)) return;
  const { ok, data } = await api('DELETE', `/api/decks/${editor.deckId}`);
  if (!ok) {
    editor.message = data.error;
  } else {
    await fetchData('decks');
    openDeckInEditor(cache.decks.find((d) => d.active) || cache.decks[0] || null);
    editor.message = 'Deck deleted.';
  }
  render();
}

// ------------------------------------------------------------------ card images (EDOPro pics)

let imageImport = null; // { done, total } while saving

function renderImages(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Card images'), button('Back', () => { screen = 'home'; render(); }, 'secondary'));
  box.appendChild(top);
  box.appendChild(el('p', '', `Card images saved in this browser: ${cardImages.keys.size}`));
  const steps = el('ol', 'steps');
  for (const t of [
    'Find your EDOPro folder (often called ProjectIgnis). Inside it there is a folder named "pics".',
    'Click "Choose pics folder" below and select that "pics" folder. Your browser may ask to confirm "upload": nothing leaves your computer, the images are only saved in this browser.',
    'Cards with an image now show their real artwork everywhere: duels, packs and the deck editor.',
  ]) steps.appendChild(el('li', '', t));
  box.appendChild(steps);
  box.appendChild(el('p', 'muted small', 'EDOPro only downloads an image the first time a card is shown, so cards you never looked at in EDOPro may still show the plain frame. Browsing cards in EDOPro\'s deck editor downloads more images; then choose the folder here again.'));
  if (imageImport) {
    box.appendChild(el('p', 'notice', imageImport.total ? `Saving images... ${imageImport.done} / ${imageImport.total}` : 'Reading the folder...'));
    return;
  }
  if (menuMessage) box.appendChild(el('p', 'notice', menuMessage));
  const input = el('input');
  input.type = 'file';
  input.webkitdirectory = true;
  input.multiple = true;
  input.className = 'hidden';
  input.addEventListener('change', async () => {
    imageImport = { done: 0, total: 0 };
    render();
    try {
      const n = await importCardImages(input.files, (done, total) => { imageImport = { done, total }; render(); });
      menuMessage = n ? `Saved ${n} card images.` : 'No card images found there. Make sure you picked the "pics" folder (files named like 46986414.jpg).';
    } catch (e) {
      menuMessage = e.message;
    }
    imageImport = null;
    render();
  });
  // Single pictures (phones, or pictures found online): files named after the card ID, e.g. 46986414.jpg
  const single = el('input');
  single.type = 'file';
  single.accept = 'image/jpeg,image/png';
  single.multiple = true;
  single.className = 'hidden';
  single.addEventListener('change', async () => {
    try {
      const n = await importCardImages(single.files, () => {});
      menuMessage = n ? `Saved ${n} card picture${n === 1 ? '' : 's'}.` : 'No pictures saved: name each file after the card ID, like 46986414.jpg (the ID is shown in the card details).';
    } catch (e) {
      menuMessage = e.message;
    }
    render();
  });
  box.appendChild(single);
  box.appendChild(el('p', 'muted small', 'No EDOPro, or on a phone? Save a picture of a card named after its card ID (shown at the bottom of the card details), for example 46986414.jpg, then press "Choose single pictures".'));
  const row = el('div', 'button-row');
  row.append(button('Choose pics folder', () => input.click()), button('Choose single pictures', () => single.click(), 'secondary'));
  if (cardImages.keys.size) row.append(button('Remove all images', async () => { if (confirm('Remove all saved card images from this browser?')) { await clearCardImages(); menuMessage = 'Images removed.'; render(); } }, 'secondary'));
  box.append(input, row);
}

/** Starts an admin test duel and shows the board. */
async function startLocalDuel(body) {
  lobbyError = '';
  const { ok, data } = await api('POST', '/api/duel', body);
  if (!ok) {
    lobbyError = data.error;
    render();
    return;
  }
  mode = 'practice';
  view = data;
  localStorage.setItem('yugs-duel', view.id);
  render();
  waitForCpu();
}

// ------------------------------------------------------------------ duel vs CPU (only on your own PC, with play-vs-cpu.bat)

let cpuSetup = { deckId: null, cpuDeckId: null, style: 'normal', ydks: null, folder: '', note: '' };

async function loadCpuDecks() {
  const { ok, data } = await api('GET', '/api/cpu/decks');
  cpuSetup.ydks = ok ? data.decks : [];
  cpuSetup.folder = ok ? data.folder : '';
  render();
}

/** Upload .ydk files: they are saved in local-ai/decks for the CPU to use. */
function uploadCpuYdks(files) {
  const list = [...files].filter((f) => /\.ydk$/i.test(f.name));
  if (!list.length) { cpuSetup.note = 'Pick .ydk files.'; render(); return; }
  let done = 0;
  const notes = [];
  for (const file of list) {
    const reader = new FileReader();
    reader.onload = async () => {
      const { ok, data } = await api('POST', '/api/cpu/decks', { name: file.name, ydk: String(reader.result) });
      if (!ok) notes.push(`${file.name}: ${data.error}`);
      else {
        notes.push(`${data.saved} added${data.unknown ? ` (${data.unknown} card${data.unknown === 1 ? '' : 's'} not in the game were skipped)` : ''}.`);
        cpuSetup.ydks = data.decks;
        cpuSetup.cpuDeckId = `ydk:${data.saved}`;
      }
      if (++done === list.length) { cpuSetup.note = notes.join(' '); render(); }
    };
    reader.readAsText(file);
  }
}
const CPU_STYLES = [
  ['normal', 'Normal', 'Balanced: life points, cards and board all matter.'],
  ['defensive', 'Defensive', 'Protects its life points: sets monsters, holds traps, trades only when clearly ahead.'],
  ['aggro', 'Aggro', 'Goes for damage: attacks whenever it pays off and clears the way for direct attacks.'],
];

function renderCpuSetup(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Duel vs CPU'), button('Back', () => { screen = 'home'; lobbyError = ''; render(); }, 'secondary'));
  box.appendChild(top);
  box.appendChild(el('p', 'muted small', 'Only on your PC: this CPU never runs on the public server. Duels against it give no coins or ELO.'));
  if (!need('decks')) { box.appendChild(el('p', 'muted', 'Loading decks...')); return; }
  const usable = cache.decks.filter((d) => !d.problems.length);
  if (!usable.length) { box.appendChild(el('p', 'error', 'You need at least one finished deck.')); return; }
  if (cpuSetup.ydks === null) { loadCpuDecks(); box.appendChild(el('p', 'muted', 'Loading decks...')); return; }
  const ydkIds = cpuSetup.ydks.map((d) => `ydk:${d.id}`);
  if (!usable.some((d) => d.id === cpuSetup.deckId)) cpuSetup.deckId = (usable.find((d) => d.active) || usable[0]).id;
  if (!usable.some((d) => d.id === cpuSetup.cpuDeckId) && !ydkIds.includes(cpuSetup.cpuDeckId)) cpuSetup.cpuDeckId = usable[0].id;
  const pick = (label, key, withYdk) => {
    const wrap = el('label', 'field-label', label);
    const sel = el('select', 'text-input');
    const group = withYdk ? el('optgroup') : sel;
    if (withYdk) { group.label = 'Your saved decks'; sel.appendChild(group); }
    for (const d of usable) {
      const o = el('option', '', `${d.name}${d.testOnly && d.testOnly.length ? ' (test only)' : ''}`);
      o.value = String(d.id);
      if (d.id === cpuSetup[key]) o.selected = true;
      group.appendChild(o);
    }
    if (withYdk && cpuSetup.ydks.length) {
      const g2 = el('optgroup');
      g2.label = 'CPU decks (.ydk files)';
      for (const d of cpuSetup.ydks) {
        const o = el('option', '', `${d.name} (${d.main}${d.extra ? ` + ${d.extra} Extra` : ''})`);
        o.value = `ydk:${d.id}`;
        if (o.value === cpuSetup[key]) o.selected = true;
        g2.appendChild(o);
      }
      sel.appendChild(g2);
    }
    sel.addEventListener('change', () => { cpuSetup[key] = sel.value.startsWith('ydk:') ? sel.value : Number(sel.value); });
    wrap.appendChild(sel);
    return wrap;
  };
  box.append(pick('Your deck', 'deckId', false), pick("The CPU's deck", 'cpuDeckId', true));

  // .ydk decks for the CPU: upload, or drop files in the folder
  const ydkBox = el('div', 'cpu-ydks');
  const file = el('input');
  file.type = 'file';
  file.accept = '.ydk';
  file.multiple = true;
  file.style.display = 'none';
  file.addEventListener('change', () => { uploadCpuYdks(file.files); file.value = ''; });
  ydkBox.append(file, button('Upload .ydk decks for the CPU', () => file.click(), 'secondary'));
  ydkBox.appendChild(el('p', 'muted small', `They are saved in ${cpuSetup.folder || 'local-ai\\decks'} (you can also copy .ydk files there yourself, then come back to this screen). The CPU may use any card in them: no collection or banlist limits.`));
  if (cpuSetup.note) ydkBox.appendChild(el('p', 'notice small', cpuSetup.note));
  if (cpuSetup.ydks.length) {
    const ul = el('ul', 'cpu-ydk-list small');
    for (const d of cpuSetup.ydks) {
      const li = el('li', '', `${d.name}: ${d.main} Main${d.extra ? `, ${d.extra} Extra` : ''}${d.unknown ? ` (${d.unknown} unknown skipped)` : ''} `);
      li.appendChild(button('Remove', async () => {
        if (!confirm(`Delete ${d.id} from the CPU decks folder?`)) return;
        const { ok, data } = await api('DELETE', `/api/cpu/decks/${encodeURIComponent(d.id)}`);
        if (ok) { cpuSetup.ydks = data.decks; cpuSetup.note = `${d.id} removed.`; }
        render();
      }, 'link-button'));
      ul.appendChild(li);
    }
    ydkBox.appendChild(ul);
  }
  box.appendChild(ydkBox);
  box.appendChild(el('div', 'field-label', 'CPU style'));
  const styles = el('div', 'cpu-styles');
  for (const [value, label, text] of CPU_STYLES) {
    const b = el('button', cpuSetup.style === value ? 'cpu-style active' : 'cpu-style');
    b.append(el('b', '', label), el('span', 'muted small', text));
    b.addEventListener('click', () => { cpuSetup.style = value; render(); });
    styles.appendChild(b);
  }
  box.appendChild(styles);
  if (lobbyError) box.appendChild(el('div', 'error', lobbyError));
  box.appendChild(button('Start duel', () => startLocalDuel({ mode: 'cpu', deckId: cpuSetup.deckId, cpuDeckId: cpuSetup.cpuDeckId, style: cpuSetup.style })));
}

// ------------------------------------------------------------------ admin: test duel + all cards

let testSetup = { deckA: null, deckB: null, hand: [], q: '', results: [] };
let searchTimer = null;

/** Admin card search (every card in the game, including custom cards). */
function adminSearch(q, onDone, filter) {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(async () => {
    const f = filter ? `&f=${encodeURIComponent(JSON.stringify(filter))}` : '';
    const { ok, data } = await api('GET', `/api/cards?q=${encodeURIComponent(q.trim().length >= 2 ? q : '')}${f}`);
    if (ok) {
      remember(data.texts);
      onDone(data.cards, data.total);
    }
  }, 250);
}

function keepFocus(selector, fn) {
  const node = document.querySelector(selector);
  const pos = node ? node.selectionStart : null;
  fn();
  const again = document.querySelector(selector);
  if (again && pos !== null) { again.focus(); again.setSelectionRange(pos, pos); }
}

function renderTestSetup(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Test duel (admin)'), button('Back', () => { screen = 'home'; render(); }, 'secondary'));
  box.appendChild(top);
  box.appendChild(el('p', 'muted', 'You control both sides and see everything. Pick two of your decks and the cards Deck A starts with in hand (it draws the rest up to 5). Tip: make test decks in the deck editor, admins can use any card.'));
  if (!need('decks')) return;
  const decks = cache.decks;
  if (!decks.length) return;
  const pick = (key, labelText) => {
    if (!decks.some((d) => d.id === testSetup[key])) testSetup[key] = decks[0].id;
    const label = el('label', 'field-label', labelText);
    const select = el('select', 'text-input');
    for (const d of decks) {
      const o = el('option', '', `${d.name}${d.problems.length ? ' (unfinished)' : ''}`);
      o.value = String(d.id);
      if (d.id === testSetup[key]) o.selected = true;
      select.appendChild(o);
    }
    select.addEventListener('change', () => { testSetup[key] = Number(select.value); });
    label.appendChild(select);
    return label;
  };
  const row = el('div', 'two-cols');
  row.append(pick('deckA', 'Deck A (bottom, goes first)'), pick('deckB', 'Deck B (top)'));
  box.appendChild(row);

  box.appendChild(el('h3', '', `Deck A's starting hand (${testSetup.hand.length}/5)`));
  const hand = el('div', 'tile-grid');
  testSetup.hand.forEach((code, i) => {
    const tile = el('div', 'tile mini');
    tile.title = 'Click to remove';
    tile.appendChild(cardEl({ code, faceDown: false, defense: false }, { allowRotate: false }));
    tile.addEventListener('mouseenter', () => showDetail(code));
    tile.addEventListener('click', () => { testSetup.hand.splice(i, 1); render(); });
    hand.appendChild(tile);
  });
  if (!testSetup.hand.length) hand.appendChild(el('div', 'muted small', 'Empty: Deck A draws a normal hand.'));
  box.appendChild(hand);

  const search = el('input', 'text-input test-search');
  search.placeholder = 'Search any card to put in the hand (at least 2 letters)...';
  search.value = testSetup.q;
  search.addEventListener('input', () => {
    testSetup.q = search.value;
    adminSearch(search.value, (found) => { testSetup.results = found; keepFocus('.test-search', render); });
  });
  box.appendChild(search);
  const results = el('div', 'tile-grid');
  for (const code of testSetup.results.slice(0, 40)) {
    const tile = el('div', 'tile mini');
    tile.appendChild(cardEl({ code, faceDown: false, defense: false }, { allowRotate: false }));
    tile.addEventListener('mouseenter', () => showDetail(code));
    tile.addEventListener('click', () => { if (testSetup.hand.length < 5) { testSetup.hand.push(code); render(); } });
    results.appendChild(tile);
  }
  box.appendChild(results);
  if (lobbyError) box.appendChild(el('div', 'error', lobbyError));
  box.appendChild(button('Start test duel', () => startLocalDuel({ mode: 'test', deckA: testSetup.deckA, deckB: testSetup.deckB, hand: testSetup.hand })));
  box.appendChild(detailPanel('side'));
}

// ------------------------------------------------------------------ standings (ELO)

let standings = null;        // { top, me, found, total } from the server
let standingsQuery = '';
let standingsTimer = null;

function loadStandings() {
  clearTimeout(standingsTimer);
  standingsTimer = setTimeout(async () => {
    const { ok, data } = await api('GET', `/api/standings?q=${encodeURIComponent(standingsQuery)}`);
    if (ok) standings = data;
    else menuMessage = data.error;
    render();
  }, standings ? 250 : 0);
}

function renderStandings(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Standings'), button('Back', () => { screen = 'home'; render(); }, 'secondary'));
  box.appendChild(top);
  if (menuMessage) box.appendChild(el('div', 'error', menuMessage));
  if (!standings) { box.appendChild(el('p', 'muted', 'Loading...')); loadStandings(); return; }
  const me = standings.me;
  box.appendChild(el('p', 'muted', me.rank
    ? `You are #${me.rank} of ${standings.total} with ${me.elo} ELO (${me.wins} wins, ${me.losses} losses).`
    : `You are not ranked yet: play an online duel against another player. Everyone starts at 1000 ELO. ${standings.total} players are ranked.`));
  const search = el('input', 'text-input standings-search');
  search.placeholder = 'Search a player by name...';
  search.value = standingsQuery;
  search.maxLength = 30;
  search.addEventListener('input', () => { standingsQuery = search.value; loadStandings(); });
  box.appendChild(search);
  if (standingsQuery.trim()) {
    box.appendChild(el('h3', '', standings.found.length ? 'Search results' : 'No ranked player with that name.'));
    if (standings.found.length) box.appendChild(standingsTable(standings.found));
  }
  box.appendChild(el('h3', '', 'Top 100'));
  const rows = [...standings.top];
  const meShown = rows.some((r) => r.me);
  box.appendChild(standings.top.length ? standingsTable(rows, me.rank && !meShown ? me : null) : el('p', 'muted', 'Nobody is ranked yet.'));
}

function standingsTable(rows, extraMe) {
  const t = el('table', 'standings');
  const head = el('tr');
  for (const h of ['#', 'Player', 'ELO', 'Wins', 'Losses']) head.appendChild(el('th', '', h));
  t.appendChild(head);
  const add = (r) => {
    const tr = el('tr', r.me ? 'me' : '');
    for (const v of [r.rank, r.username, r.elo, r.wins, r.losses]) tr.appendChild(el('td', '', String(v)));
    t.appendChild(tr);
  };
  rows.forEach(add);
  if (extraMe) {
    const gap = el('tr', 'gap');
    gap.appendChild(el('td', '', '...'));
    t.appendChild(gap);
    add(extraMe);
  }
  return t;
}

// ------------------------------------------------------------------ find a duel (ranked matchmaking)

let matchState = null;   // { status, seconds, gap, inQueue } from the server
let matchTimer = null;

async function findDuel() {
  const { ok, data } = await api('POST', '/api/match', {});
  if (!ok) { menuMessage = data.error; screen = 'home'; render(); return; }
  onMatchStatus(data);
}

function onMatchStatus(data) {
  if (screen !== 'matching') return;
  matchState = data;
  if (data.status === 'matched') {
    clearTimeout(matchTimer);
    screen = 'home';
    sessionStorage.setItem(seatKey(data.roomId), JSON.stringify({ token: data.token, seat: data.seat }));
    connectRoom(data.roomId);
    return;
  }
  if (data.status === 'idle') { findDuel(); return; } // dropped from the queue (e.g. the server restarted): join again
  render();
  clearTimeout(matchTimer);
  matchTimer = setTimeout(async () => {
    if (screen !== 'matching') return;
    const { ok, data: next } = await api('GET', '/api/match');
    if (ok) onMatchStatus(next);
  }, 2000);
}

async function cancelFindDuel() {
  clearTimeout(matchTimer);
  screen = 'home';
  matchState = null;
  render();
  await api('DELETE', '/api/match');
}

function renderMatching(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Finding a duel...'), button('Cancel', cancelFindDuel, 'secondary'));
  box.appendChild(top);
  const s = matchState;
  box.appendChild(el('p', '', `Looking for a player near your rating (${currentUser.elo} ELO).`));
  if (s && s.status === 'searching') {
    box.appendChild(el('p', 'muted', `Waiting ${s.seconds}s · ${s.gap === null ? 'any rating now' : `within ${s.gap} ELO`} · ${s.inQueue} player${s.inQueue === 1 ? '' : 's'} searching`));
  }
  box.appendChild(el('p', 'muted small', 'The rating range widens the longer you wait; after a minute anyone can be your opponent. Only ranked duels give coins, count toward your next pack and change ELO. Each player has 3 minutes for the whole duel plus 3 seconds after every decision; run out of time, or leave for 2 minutes, and you lose.'));
}

// ------------------------------------------------------------------ main page: news + tutorial

/** A small, safe Markdown subset: "## " headings, "**Bold line**", "- " bullets, paragraphs, **bold**, `code`. */
function renderMarkdown(text) {
  const root = el('div', 'md');
  const inline = (line, into) => {
    for (const part of line.split(/(\*\*[^*]+\*\*|`[^`]+`)/)) {
      if (!part) continue;
      if (part.startsWith('**') && part.endsWith('**')) into.appendChild(el('b', '', part.slice(2, -2)));
      else if (part.startsWith('`') && part.endsWith('`')) into.appendChild(el('code', '', part.slice(1, -1)));
      else into.appendChild(document.createTextNode(part));
    }
    return into;
  };
  let list = null;
  for (const raw of String(text).split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) { list = null; continue; }
    if (line.startsWith('## ')) { list = null; root.appendChild(inline(line.slice(3), el('h3'))); continue; }
    if (line.startsWith('- ')) {
      if (!list) { list = el('ul'); root.appendChild(list); }
      list.appendChild(inline(line.slice(2), el('li')));
      continue;
    }
    list = null;
    root.appendChild(inline(line, el('p')));
  }
  return root;
}

let newsEditing = null; // { id|null, title, body } while an admin writes a post
let newsShowAll = false;

function newsSection() {
  const sec = el('div', 'news');
  const head = el('div', 'news-head');
  head.appendChild(el('h2', '', 'News'));
  if (currentUser.isAdmin && !newsEditing) head.appendChild(button('+ Post news', () => { newsEditing = { id: null, title: '', body: '' }; render(); }, 'secondary admin'));
  sec.appendChild(head);
  if (!need('news')) { sec.appendChild(el('p', 'muted', 'Loading...')); return sec; }
  if (newsEditing) sec.appendChild(newsEditor());
  const posts = cache.news.news;
  if (!posts.length && !newsEditing) sec.appendChild(el('p', 'muted', 'No news yet.'));
  for (const p of newsShowAll ? posts : posts.slice(0, 3)) {
    const item = el('article', 'news-post');
    const when = new Date(p.createdAt).toLocaleDateString(undefined, { day: 'numeric', month: 'long', year: 'numeric' });
    item.append(el('h3', '', p.title), el('div', 'muted small', `${when} · ${p.author}`), renderMarkdown(p.body));
    if (currentUser.isAdmin) {
      const row = el('div', 'button-row');
      row.append(
        button('Edit', () => { newsEditing = { id: p.id, title: p.title, body: p.body }; render(); }, 'ghost small'),
        button('Delete', async () => { if (confirm(`Delete the post "${p.title}"?`)) await newsSave('DELETE', p.id); }, 'ghost small'),
      );
      item.appendChild(row);
    }
    sec.appendChild(item);
  }
  if (posts.length > 3) sec.appendChild(button(newsShowAll ? 'Show fewer' : `Show older news (${posts.length - 3})`, () => { newsShowAll = !newsShowAll; render(); }, 'link-button'));
  return sec;
}

function newsEditor() {
  const ed = el('div', 'news-editor');
  const title = el('input', 'text-input news-title');
  title.placeholder = 'Title';
  title.maxLength = 120;
  title.value = newsEditing.title;
  title.addEventListener('input', () => { newsEditing.title = title.value; });
  const body = el('textarea', 'text-input news-body');
  body.placeholder = 'Text. Empty line = new paragraph, "- " = bullet, **bold**.';
  body.value = newsEditing.body;
  body.addEventListener('input', () => { newsEditing.body = body.value; });
  const row = el('div', 'button-row');
  row.append(
    button(newsEditing.id ? 'Save changes' : 'Post', () => newsSave(newsEditing.id ? 'PUT' : 'POST', newsEditing.id)),
    button('Cancel', () => { newsEditing = null; render(); }, 'secondary'),
  );
  ed.append(title, body, row);
  return ed;
}

async function newsSave(method, id) {
  const url = id ? `/api/admin/news/${id}` : '/api/admin/news';
  const { ok, data } = await api(method, url, method === 'DELETE' ? {} : { title: newsEditing.title, body: newsEditing.body });
  if (!ok) { menuMessage = data.error; render(); return; }
  cache.news = data;
  newsEditing = null;
  menuMessage = '';
  render();
}

function renderTutorial(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'How Yugs works'), button('Back', () => { screen = 'home'; render(); }, 'secondary'));
  box.appendChild(top);
  if (!need('news')) { box.appendChild(el('p', 'muted', 'Loading...')); return; }
  box.appendChild(renderMarkdown(cache.news.tutorial || 'The tutorial is not written yet.'));
}

// ------------------------------------------------------------------ main menu chat

const chat = { source: null, messages: [], online: 0, draft: '', error: '', connected: false, stick: true };

function chatStart() {
  if (chat.source) return;
  const source = new EventSource('/api/chat/events');
  chat.source = source;
  source.onopen = () => { chat.connected = true; };
  source.onmessage = (ev) => {
    const e = JSON.parse(ev.data);
    if (e.type === 'history') { chat.messages = e.messages; chat.online = e.online; }
    else if (e.type === 'message') { chat.messages.push(e.message); if (chat.messages.length > 200) chat.messages.shift(); }
    else if (e.type === 'delete') chat.messages = chat.messages.filter((m) => m.id !== e.id);
    else if (e.type === 'online') chat.online = e.online;
    chat.connected = true;
    if (mode === null && screen === 'home') render();
  };
  source.onerror = () => { chat.connected = false; };
}

function chatStop() {
  if (chat.source) chat.source.close();
  chat.source = null;
  chat.messages = [];
  chat.connected = false;
}

function chatSection() {
  chatStart();
  const sec = el('div', 'chat');
  const head = el('div', 'news-head');
  head.append(el('h2', '', 'Chat'), el('span', 'muted small', `${chat.online} online`));
  sec.appendChild(head);
  const list = el('div', 'chat-list');
  list.dataset.keepScroll = 'chat';
  for (const m of chat.messages) {
    const line = el('div', 'chat-line');
    const time = new Date(m.createdAt).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
    line.append(el('span', 'chat-time', time), el('b', m.username === currentUser.username ? 'chat-name me' : 'chat-name', `${m.username}: `), document.createTextNode(m.text));
    if (currentUser.isAdmin) {
      const del = el('button', 'chat-admin', '✕');
      del.title = 'Delete this message';
      del.addEventListener('click', () => chatAdmin('DELETE', `/api/admin/chat/${m.id}`));
      const mute = el('button', 'chat-admin', 'mute');
      mute.title = `Mute ${m.username}`;
      mute.addEventListener('click', () => {
        const minutes = prompt(`Mute ${m.username} for how many minutes? (0 = unmute, 1440 = a day)`, '60');
        if (minutes !== null) chatAdmin('POST', '/api/admin/chat/mute', { username: m.username, minutes: Number(minutes) });
      });
      line.append(mute, del);
    }
    list.appendChild(line);
  }
  if (!chat.messages.length) list.appendChild(el('div', 'muted small', chat.connected ? 'No messages yet. Say hi!' : 'Connecting...'));
  list.addEventListener('scroll', () => { chat.stick = list.scrollTop + list.clientHeight >= list.scrollHeight - 10; });
  sec.appendChild(list);
  // stay at the newest message unless the player scrolled up to read
  requestAnimationFrame(() => { if (chat.stick) list.scrollTop = list.scrollHeight; });
  const form = el('form', 'chat-form');
  const input = el('input', 'text-input chat-input');
  input.placeholder = 'Write a message...';
  input.maxLength = 300;
  input.value = chat.draft;
  input.addEventListener('input', () => { chat.draft = input.value; });
  const send = el('button', '', 'Send');
  send.type = 'submit';
  form.append(input, send);
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const text = chat.draft.trim();
    if (!text) return;
    const { ok, data } = await api('POST', '/api/chat', { text });
    chat.error = ok ? '' : data.error;
    if (ok) { chat.draft = ''; chat.stick = true; }
    render();
  });
  sec.appendChild(form);
  if (chat.error) sec.appendChild(el('div', 'error small', chat.error));
  return sec;
}

async function chatAdmin(method, url, body) {
  const { ok, data } = await api(method, url, body || {});
  chat.error = ok ? (body && 'minutes' in body ? (body.minutes ? `${body.username} is muted.` : `${body.username} can chat again.`) : '') : data.error;
  render();
}
