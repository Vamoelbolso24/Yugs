// Yugs duel page. Talks to the local server; the server runs the rules engine.
'use strict';

const LOC = { DECK: 1, HAND: 2, MZONE: 4, SZONE: 8, GRAVE: 16, REMOVED: 32, EXTRA: 64, OVERLAY: 128 };
const LOC_NAME = { 1: 'Deck', 2: 'Hand', 4: 'Monster Zone', 8: 'Spell & Trap Zone', 16: 'Graveyard', 32: 'Banished', 64: 'Extra Deck', 128: 'Material' };
const PHASE_ACTIONS = new Set(['Battle Phase', 'End Turn', 'Main Phase 2', "Don't activate"]);
/** Questions answered by clicking on the board (no pop-up window). */
// Questions answered by clicking the board (glowing cards / zones) instead of a pop-up window.
// 'chain' = "Do you want to respond?": click a glowing card to activate it, or press Don't activate.
const BOARD_KINDS = new Set(['idle', 'battle', 'place', 'chain']);
const CHAIN_MODES = [
  ['smart', 'Ask me to respond: when something happens'],
  ['always', 'Ask me to respond: always'],
  ['never', 'Ask me to respond: never'],
];

let view = null;
let busy = false;
let requestError = '';
let multiSelected = new Set();
let multiDecisionId = null;

const $ = (id) => document.getElementById(id);
function el(tag, className, text) {
  const e = document.createElement(tag);
  if (className) e.className = className;
  if (text !== undefined) e.textContent = text;
  return e;
}
const keyOf = (controller, location, sequence) => `${controller}:${location}:${sequence}`;

// ------------------------------------------------------------------ server calls

/** null = start screen, 'practice' = an admin test duel (one person plays both sides), 'online' = two browsers. */
let mode = null;
/** Online duel: { roomId, token, seat, state, source, connected } */
let online = null;
let lobbyError = '';
let lanUrls = [];

async function api(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({ error: 'The server sent an unreadable reply.' }));
  return { ok: res.ok, data };
}

const seatKey = (roomId) => `yugs-room-${roomId}`;
function storedSeat(roomId) {
  try { return JSON.parse(sessionStorage.getItem(seatKey(roomId)) || 'null'); } catch { return null; }
}
/** The logged-in account, or null. */
let currentUser = null;
let authTab = 'login';
/** Sign-up and password-reset steps: null, {kind:'verify', username, password, email}, {kind:'forgot'} or {kind:'reset', email}. */
let authStep = null;
let authNotice = '';
let authBusy = false;
/** Older accounts without an email get asked to add one. */
let needsEmail = false;
/** Maintenance mode (from the server, checked every minute). */
let siteStatus = { maintenance: false, message: '' };

async function loadSiteStatus() {
  try {
    const { ok, data } = await api('GET', '/api/status');
    if (!ok) return;
    const changed = data.maintenance !== siteStatus.maintenance || data.message !== siteStatus.message;
    siteStatus = data;
    if (changed && mode === null) render();
  } catch { /* server restarting */ }
}

/** Community Discord: where players meet to set up duels while the ladder is small. */
const DISCORD_URL = 'https://discord.gg/29VUMB3BCY';
function discordBox() {
  const box = el('div', 'discord-box');
  const text = el('div', 'discord-text');
  text.append(el('b', '', 'Join the Yugs Discord'),
    el('span', '', 'Not many players online yet? Meet other duelists there, set up duels, share decks and tell us about bugs.'));
  const link = el('a', 'discord-button', 'Join the Discord');
  link.href = DISCORD_URL;
  link.target = '_blank';
  link.rel = 'noopener';
  box.append(text, link);
  return box;
}

/** The site logo (content/branding/logo.webp on the server); just the word "Yugs" if there is none. */
let logoMissing = false;
function siteLogo() {
  if (logoMissing) return el('h1', '', 'Yugs');
  const img = el('img', 'site-logo');
  img.src = '/branding/logo.webp';
  img.alt = 'Yugs: Playground Dueling';
  img.width = 900;
  img.height = 300;
  img.addEventListener('error', () => { logoMissing = true; img.replaceWith(el('h1', '', 'Yugs')); });
  return img;
}

function maintenanceBanner() {
  if (!siteStatus.maintenance) return null;
  const admin = currentUser && currentUser.isAdmin;
  const b = el('div', 'maintenance-banner');
  b.append(el('b', '', admin ? 'Maintenance mode is ON. ' : 'Maintenance: '),
    document.createTextNode(admin ? 'Players can\'t start new duels and only see this message: ' + siteStatus.message : siteStatus.message));
  return b;
}

async function loadUser() {
  try {
    const { ok, data } = await api('GET', '/api/auth/me');
    currentUser = ok ? data.user : null;
    needsEmail = ok && !!data.needsEmail;
  } catch {
    currentUser = null;
  }
}

/** Runs one auth request; on a logged-in reply it finishes logging in. */
async function authRequest(action, body, after) {
  if (authBusy) return;
  authBusy = true;
  lobbyError = '';
  authNotice = '';
  render();
  try {
    const { ok, data } = await api('POST', `/api/auth/${action}`, body);
    if (!ok) {
      if (data.verify && action === 'login') {
        authStep = { kind: 'verify', username: body.username, password: body.password, email: '' };
        authNotice = 'This account still needs its email code. Check your inbox (and the spam folder), or send a new code.';
        return;
      }
      throw new Error(data.error);
    }
    if (after) after(data);
    if (data.user) {
      currentUser = data.user;
      needsEmail = !!data.needsEmail;
      authStep = null;
      resetPlayerCache();
      // Came from an invite link? Join right away.
      const room = new URLSearchParams(location.search).get('room');
      if (room) { authBusy = false; return joinOnline(room); }
    }
  } catch (e) {
    lobbyError = e.message || 'Cannot reach the server.';
  } finally {
    authBusy = false;
    render();
  }
}

function submitAuth(action, username, password, email) {
  if (action === 'register') {
    return authRequest('register', { username, email, password }, (data) => {
      authStep = { kind: 'verify', username: data.username, password, email: data.email };
      authNotice = `We sent a 6-digit code to ${data.email}. It works for 15 minutes. Check the spam folder if you don't see it.`;
    });
  }
  return authRequest('login', { username, password });
}

async function logout() {
  await api('POST', '/api/auth/logout', {});
  currentUser = null;
  resetPlayerCache();
  render();
}

function goToMenu() {
  if (online && online.source) online.source.close();
  if (typeof cache !== 'undefined') cache.decks = null;
  if (mode === 'online' && typeof profile !== 'undefined') profile = null; // coins, ELO and duel count changed: reload them
  online = null;
  mode = null;
  view = null;
  requestError = '';
  history.replaceState(null, '', '/');
  render();
}


// ---- online

async function createOnline() {
  lobbyError = '';
  try {
    const { ok, data } = await api('POST', '/api/room', {});
    if (!ok) throw new Error(data.error);
    sessionStorage.setItem(seatKey(data.roomId), JSON.stringify({ token: data.token, seat: data.seat }));
    connectRoom(data.roomId);
  } catch (e) {
    lobbyError = e.message || 'Cannot reach the server.';
    render();
  }
}

async function joinOnline(roomId) {
  lobbyError = '';
  try {
    const { ok, data } = await api('POST', `/api/room/${roomId}/join`, {});
    if (!ok) throw new Error(data.error);
    sessionStorage.setItem(seatKey(roomId), JSON.stringify({ token: data.token, seat: data.seat }));
    connectRoom(roomId);
  } catch (e) {
    lobbyError = e.message || 'Cannot reach the server.';
    render();
  }
}

function connectRoom(roomId) {
  const seatInfo = storedSeat(roomId);
  if (!seatInfo) return;
  if (online && online.source) online.source.close();
  mode = 'online';
  online = { roomId, token: seatInfo.token, seat: seatInfo.seat, state: null, source: null, connected: false, connectSince: Date.now() };
  setTimeout(() => { if (online && online.roomId === roomId && !online.state) render(); }, 8500);
  history.replaceState(null, '', `/?room=${encodeURIComponent(roomId)}`);
  const source = new EventSource(`/api/room/${encodeURIComponent(roomId)}/events?token=${encodeURIComponent(seatInfo.token)}`);
  online.source = source;
  const apply = (state) => {
    online.state = state;
    online.stateAt = Date.now(); // the clock counts down from here
    online.lastHeard = Date.now();
    view = online.state.view;
    render();
  };
  source.onmessage = (ev) => {
    online.connected = true;
    apply(JSON.parse(ev.data));
  };
  source.onerror = () => {
    online.connected = false;
    render();
  };
  // Backup for phones and picky networks: if the live connection goes quiet, ask for the duel directly.
  const mine = online;
  const poll = setInterval(async () => {
    if (online !== mine) { clearInterval(poll); return; }
    const quiet = Date.now() - (mine.lastHeard || 0);
    // Live connection working: only a safety check every 30 s. Not working: every 2 s.
    if (mine.connected ? quiet < 30_000 : quiet < 3000) return;
    try {
      const { ok, data } = await api('GET', `/api/room/${encodeURIComponent(roomId)}/state?token=${encodeURIComponent(seatInfo.token)}`);
      if (ok && online === mine) {
        const changed = JSON.stringify(data) !== JSON.stringify(mine.state);
        mine.lastHeard = Date.now();
        if (changed) apply(data);
      }
    } catch { /* offline for a moment */ }
  }, 2000);
  document.addEventListener('visibilitychange', () => {
    // Back from another app or a locked screen: catch up right away.
    if (!document.hidden && online === mine) { mine.lastHeard = 0; mine.connected = false; }
  });
  render();
}

// ---- actions (both modes)

/** The hand card the player just used, so its animation starts from that exact copy (not another one with the same name). */
let lastHandPick = null;

async function answer(picks) {
  if (busy || !view || !view.decision) return;
  busy = true;
  requestError = '';
  closePopup();
  const picked = picks && picks.length === 1 ? view.decision.choices.find((c) => c.id === picks[0]) : null;
  if (picked && picked.card && picked.card.location === LOC.HAND) {
    lastHandPick = { player: picked.card.controller, sequence: picked.card.sequence, code: picked.card.code, at: Date.now() };
  }
  try {
    if (mode === 'online') {
      const { ok, data } = await api('POST', `/api/room/${online.roomId}/answer`, { token: online.token, decisionId: view.decision.id, picks });
      if (!ok) requestError = data.error || 'That did not work.';
      // The new board arrives through the live-update stream.
    } else {
      const { ok, data } = await api('POST', `/api/duel/${view.id}/answer`, { decisionId: view.decision.id, picks });
      if (ok) view = data;
      else {
        requestError = data.error || 'That did not work.';
        if (data.view) view = data.view;
      }
    }
  } catch {
    requestError = 'Cannot reach the server. Is the Yugs window still open?';
  }
  busy = false;
  render();
}

async function setChainMode(player, chainMode) {
  if (mode === 'online') {
    await api('POST', `/api/room/${online.roomId}/settings`, { token: online.token, chainMode });
    return;
  }
  const { ok, data } = await api('POST', `/api/duel/${view.id}/settings`, { player, chainMode });
  if (ok) view = data;
  else requestError = data.error;
  render();
}

async function surrender() {
  if (!view || view.winner !== null) return;
  if (mode === 'online') {
    if (!confirm('Surrender this duel?')) return;
    await api('POST', `/api/room/${online.roomId}/surrender`, { token: online.token });
    return;
  }
  const player = view.decision ? view.decision.player : view.turnPlayer;
  if (!confirm(`Surrender the duel for ${view.players[player].name}?`)) return;
  const { ok, data } = await api('POST', `/api/duel/${view.id}/surrender`, { player });
  if (ok) view = data;
  render();
}

/** The player shown at the bottom of the screen (you, in online duels). */
function me() {
  return view && view.viewer !== null && view.viewer !== undefined ? view.viewer : 0;
}
/** Colour class: blue for the bottom player, red for the top player. */
function colorOf(p) {
  return p === me() ? 'p0' : 'p1';
}

// ------------------------------------------------------------------ cards

function cardInfo(code) {
  return (view && view.cards[code]) || cardCache[code] || null;
}

function cardEl(card, opts = {}) {
  const info = card.code ? cardInfo(card.code) : null;
  const e = el('div', 'card');
  if (card.code && !card.faceDown) e.dataset.code = String(card.code);
  if (card.faceDown || !info) {
    e.classList.add('back');
    e.appendChild(el('div', 'swirl'));
    if (info && opts.peek !== false) e.appendChild(el('div', 'peek', info.name));
  } else if (info.image || hasCardImage(card.code)) {
    // Real artwork: custom card art from the server, or the player's own EDOPro images.
    e.classList.add('has-img');
    const img = el('img', 'art-img');
    img.alt = info.name;
    img.draggable = false;
    if (info.image) img.src = info.image;
    else cardImageUrl(card.code).then((url) => { if (url) img.src = url; });
    e.appendChild(img);
    if (info.isMonster && card.atk !== undefined) {
      const second = info.frame === 'link' ? `L${info.level}` : fmtStat(card.def ?? info.def);
      e.appendChild(el('div', 'stat-overlay', `${fmtStat(card.atk)} / ${second}`));
    }
  } else {
    e.classList.add(`frame-${info.frame}`);
    e.appendChild(el('div', 'name', info.name));
    if (info.isMonster && info.level && info.frame !== 'link') {
      e.appendChild(el('div', info.frame === 'xyz' ? 'stars rank' : 'stars', '★'.repeat(Math.min(info.level, 12))));
    }
    e.appendChild(el('div', 'art'));
    if (info.isMonster) {
      const atk = card.atk ?? info.atk;
      const def = card.def ?? info.def;
      const second = info.frame === 'link' ? `L${info.level}` : fmtStat(def);
      e.appendChild(el('div', 'atkdef', `${fmtStat(atk)} / ${second}`));
    } else {
      e.appendChild(el('div', 'kind', info.typeLine.replace(/ (Spell|Trap)$/, '')));
    }
  }
  if (card.defense && opts.allowRotate !== false) e.classList.add('def');
  if (card.overlays) e.appendChild(el('div', 'mats', `${card.overlays}`));
  if (card.counters && card.counters.length) {
    const badge = el('div', 'counters', card.counters.map((x) => `${x.name} ${x.count}`).join(' \u00b7 '));
    badge.title = 'Counters on this card';
    e.appendChild(badge);
  }
  if (card.code) {
    e.addEventListener('mouseenter', () => showDetail(card.code, card));
  }
  return e;
}

const ARROWS = [[1, 'Bottom-Left'], [2, 'Bottom'], [4, 'Bottom-Right'], [8, 'Left'], [32, 'Right'], [64, 'Top-Left'], [128, 'Top'], [256, 'Top-Right']];
function linkArrows(mask) {
  return ARROWS.filter(([bit]) => mask & bit).map(([, name]) => name).join(', ') || 'none';
}

function fmtStat(n) {
  return n === undefined || n === null || n < 0 || n > 100000 ? '?' : String(n);
}

/** Phones: no hover, so tapping a card opens its text in a panel at the bottom of the screen. */
const isPhone = () => window.matchMedia('(max-width: 760px)').matches;
/** On a phone the first tap on a card only shows its text; the action happens on the next tap. */
const sheetFor = { code: null, at: 0 };
function phoneFirstTap(code) {
  return isPhone() && sheetFor.code === code && Date.now() - sheetFor.at < 600;
}

function showDetail(code, card) {
  const info = cardInfo(code);
  // On the menu screens the card text goes to the menu's own panel.
  const menuPanel = !$('lobby').classList.contains('hidden') && $('menu-detail');
  const box = menuPanel || $('detail');
  box.replaceChildren();
  if (!info) return;
  if (isPhone()) {
    if (sheetFor.code !== code || !box.classList.contains('sheet-open')) { sheetFor.code = code; sheetFor.at = Date.now(); }
    box.classList.add('sheet-open');
    const close = el('button', 'sheet-close', '✕ Close');
    close.addEventListener('click', (ev) => { ev.stopPropagation(); box.classList.remove('sheet-open'); });
    box.appendChild(close);
  }
  const preview = cardEl({ code, faceDown: false, defense: false }, { allowRotate: false });
  preview.classList.add('big');
  box.appendChild(preview);
  box.appendChild(el('h2', '', info.name));
  const meta = [info.typeLine];
  const levelWord = info.frame === 'xyz' ? 'Rank' : info.frame === 'link' ? 'Link' : 'Level';
  if (info.isMonster) meta.unshift([info.attribute, info.race, info.level ? `${levelWord} ${info.level}` : ''].filter(Boolean).join(' · '));
  if (info.lscale || info.rscale) meta.push(`Pendulum Scale ${info.lscale} / ${info.rscale}`);
  if (info.frame === 'link') meta.push(`Link Arrows: ${linkArrows(info.linkMarkers)}`);
  box.appendChild(el('div', 'meta', meta.join('\n')));
  if (info.isMonster) {
    const atk = card && card.atk !== undefined ? card.atk : info.atk;
    const def = card && card.def !== undefined ? card.def : info.def;
    box.appendChild(el('div', 'stats', info.frame === 'link' ? `ATK ${fmtStat(atk)}  /  LINK-${info.level}` : `ATK ${fmtStat(atk)}  /  DEF ${fmtStat(def)}`));
  }
  box.appendChild(el('div', 'text', info.desc));
  box.appendChild(el('div', 'card-id muted small', `Card ID: ${code}`));
}

// ------------------------------------------------------------------ board

/** Map of board position -> choices of the current menu question that use that card. */
function actionMap() {
  const map = new Map();
  const d = view && view.decision;
  if (!d || d.mode !== 'menu' || !BOARD_KINDS.has(d.kind)) return map;
  for (const c of d.choices) {
    if (!c.card) continue;
    const k = keyOf(c.card.controller, c.card.location, c.card.sequence);
    if (!map.has(k)) map.set(k, []);
    map.get(k).push(c);
  }
  return map;
}

function placeCard(card, controller, location, sequence, actions) {
  // Only monsters turn sideways for Defense Position; set Spells/Traps stay upright.
  const e = cardEl(location === LOC.MZONE ? card : { ...card, defense: false });
  const choices = actions.get(keyOf(controller, location, sequence));
  if (choices) {
    e.classList.add('actionable');
    e.addEventListener('click', (ev) => {
      ev.stopPropagation();
      openPopup(e, choices);
    });
  }
  return e;
}

function zone(card, controller, location, sequence, actions, label, altKeys = []) {
  const z = el('div', 'zone');
  z.dataset.zone = `${controller}-${location}-${sequence}`;
  if (card) {
    z.appendChild(placeCard(card, controller, location, sequence, actions));
    return z;
  }
  if (label) z.appendChild(el('div', 'label', label));
  const keys = [keyOf(controller, location, sequence), ...altKeys];
  const choices = keys.map((k) => actions.get(k)).find(Boolean);
  if (choices) {
    z.classList.add('pick');
    z.title = choices[0].label;
    z.addEventListener('click', (ev) => {
      ev.stopPropagation();
      answer([choices[0].id]);
    });
  }
  return z;
}

function pile(cards, controller, location, label, actions, faceDownCount) {
  const z = el('div', 'zone pile');
  z.dataset.zone = `${controller}-${location}`;
  if (faceDownCount !== undefined) {
    if (faceDownCount > 0) z.appendChild(cardEl({ code: 0, faceDown: true }));
    else z.appendChild(el('div', 'label', label));
    z.appendChild(el('div', 'count', String(faceDownCount)));
    z.title = `${label}: ${faceDownCount} cards`;
    return z;
  }
  if (cards.length) {
    const top = cards[cards.length - 1];
    z.appendChild(placeCard({ ...top, defense: false }, controller, location, cards.length - 1, actions));
    z.appendChild(el('div', 'count', String(cards.length)));
    z.style.cursor = 'pointer';
    z.addEventListener('click', () => showPileList(label, cards, controller, location));
  } else z.appendChild(el('div', 'label', label));
  return z;
}

// Choices for cards inside a face-down pile (Extra Deck, Deck): the pile glows and clicking it lists them.
function pileChoices(p, location) {
  const d = view.decision;
  return d && d.mode === 'menu' && BOARD_KINDS.has(d.kind)
    ? d.choices.filter((c) => c.card && c.card.location === location && c.card.controller === p)
    : [];
}

function deckPile(pl, p) {
  const z = pile([], p, LOC.DECK, 'Deck', new Map(), pl.deckCount);
  const choices = pileChoices(p, LOC.DECK);   // e.g. Vaporeon's "Special Summon from your Deck"
  const top = z.querySelector('.card');
  if (choices.length && top) {
    top.classList.add('actionable');
    top.addEventListener('click', (ev) => {
      ev.stopPropagation();
      openPopup(top, choices, true);
    });
  }
  return z;
}

function extraPile(pl, p) {
  const z = pile([], p, LOC.EXTRA, 'Extra Deck', new Map(), pl.extraCount);
  const extraChoices = pileChoices(p, LOC.EXTRA);
  const top = z.querySelector('.card');
  if (extraChoices.length && top) {
    top.classList.add('actionable');
    top.addEventListener('click', (ev) => {
      ev.stopPropagation();
      openPopup(top, extraChoices, true);
    });
  } else if (pl.extra.length) {
    z.style.cursor = 'pointer';
    z.addEventListener('click', () => showPileList('Extra Deck', pl.extra, p));
  }
  return z;
}

// The duel clock (online): each player's time left, ticking for whoever must answer.
function clockLeft(p) {
  const c = online && online.state && online.state.clock;
  if (!c) return null;
  let ms = c.left[p];
  if (c.running === p && view && view.winner === null) ms -= Date.now() - (online.stateAt || Date.now());
  return Math.max(0, ms);
}
function updateClocks() {
  for (const node of document.querySelectorAll('.clock[data-player]')) {
    const p = Number(node.dataset.player);
    const ms = clockLeft(p);
    if (ms === null) continue;
    const s = Math.ceil(ms / 1000);
    node.textContent = `⏱ ${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
    const c = online.state.clock;
    node.classList.toggle('running', c.running === p);
    node.classList.toggle('low', s <= 30);
  }
}
setInterval(updateClocks, 250);

function renderSide(p, elementId, actions) {
  const side = $(elementId);
  side.replaceChildren();
  const pl = view.players[p];
  side.classList.toggle('deciding', view.waitingFor === p && view.winner === null);

  const bar = el('div', 'playerbar');
  bar.appendChild(el('span', `name ${colorOf(p)}`, pl.name));
  if (mode === 'online' && online && online.state && p !== me()) {
    const seatInfo = online.state.seats[1 - online.seat];
    if (seatInfo && !seatInfo.connected) bar.appendChild(el('span', 'offline', 'disconnected'));
  }
  const lp = el('span', 'lp', `LP ${lpShown.duel === view.id && lpShown.lp[p] !== null ? lpShown.lp[p] : pl.lp}`);
  lp.dataset.player = String(p);
  if (pl.lp <= 2000) lp.classList.add('low');
  bar.appendChild(lp);
  if (mode === 'online' && online && online.state && online.state.clock) {
    const clock = el('span', 'clock');
    clock.dataset.player = String(p);
    bar.appendChild(clock);
    updateClocks();
  }
  bar.appendChild(el('span', 'muted', `Hand ${pl.hand.length} · Deck ${pl.deckCount} · Extra ${pl.extraCount}`));
  const modeSel = el('select', 'chainmode');
  modeSel.title = 'When should the game stop and ask this player if they want to activate a card in response?';
  for (const [value, label] of CHAIN_MODES) {
    const o = el('option', '', label);
    o.value = value;
    if (pl.chainMode === value) o.selected = true;
    modeSel.appendChild(o);
  }
  modeSel.addEventListener('change', () => setChainMode(p, modeSel.value));
  if (view.viewer === null || view.viewer === undefined || p === me()) bar.appendChild(modeSel);

  const monsters = el('div', 'row field');
  monsters.appendChild(zone(pl.spells[5], p, LOC.SZONE, 5, actions, 'Field'));
  for (let i = 0; i < 5; i++) monsters.appendChild(zone(pl.monsters[i], p, LOC.MZONE, i, actions, ''));
  monsters.appendChild(pile(pl.grave, p, LOC.GRAVE, 'Graveyard', actions));
  monsters.appendChild(pile(pl.banished, p, LOC.REMOVED, 'Banished', actions));

  const spells = el('div', 'row field');
  spells.appendChild(extraPile(pl, p));
  for (let i = 0; i < 5; i++) spells.appendChild(zone(pl.spells[i], p, LOC.SZONE, i, actions, ''));
  spells.appendChild(deckPile(pl, p));
  spells.appendChild(el('div', 'zone empty-slot'));

  const hand = el('div', 'hand');
  hand.dataset.zone = `${p}-${LOC.HAND}`;
  pl.hand.forEach((c, i) => {
    const h = placeCard({ ...c, faceDown: false, defense: false }, p, LOC.HAND, i, actions);
    h.dataset.zone = `${p}-${LOC.HAND}-${i}`;
    hand.appendChild(h);
  });

  side.append(monsters, spells, hand, bar);
}

function renderEmz(actions) {
  const row = $('emz-row');
  row.replaceChildren();
  const a = me();
  const b = 1 - a;
  const mine = view.players[a];
  const theirs = view.players[b];
  // From the bottom player's point of view: left slot = my zone 5 / their zone 6, right = my 6 / their 5.
  const left = mine.monsters[5] ? [mine.monsters[5], a, 5] : theirs.monsters[6] ? [theirs.monsters[6], b, 6] : null;
  const right = mine.monsters[6] ? [mine.monsters[6], a, 6] : theirs.monsters[5] ? [theirs.monsters[5], b, 5] : null;
  for (let col = 0; col < 8; col++) {
    if (col === 2 || col === 4) {
      const slot = col === 2 ? left : right;
      const [ownSeq, theirSeq] = col === 2 ? [5, 6] : [6, 5];
      row.appendChild(slot
        ? zone(slot[0], slot[1], LOC.MZONE, slot[2], actions)
        : zone(null, a, LOC.MZONE, ownSeq, actions, 'Extra Monster Zone', [keyOf(b, LOC.MZONE, theirSeq)]));
    } else row.appendChild(el('div', 'zone empty-slot'));
  }
}

// ------------------------------------------------------------------ question UI

function whoLabel(p) {
  return el('span', `who ${colorOf(p)}`, view.players[p].name);
}

function choiceText(c) {
  const name = c.card ? (c.card.code ? (cardInfo(c.card.code) || {}).name || 'a card' : 'a face-down card') : '';
  return { main: name ? `${c.label}: ${name}` : c.label, sub: c.detail || '' };
}

function renderPrompt() {
  const box = $('prompt');
  box.replaceChildren();
  const d = view.decision;
  if (view.winner !== null) {
    box.appendChild(el('div', '', 'The duel is over.'));
  } else if (d) {
    const line = el('div');
    line.append(whoLabel(d.player), document.createTextNode(` — ${d.prompt.split('\n')[0]}`));
    box.appendChild(line);
    if (d.kind === 'idle' || d.kind === 'battle') {
      box.appendChild(el('div', 'muted', 'Click a glowing card, or pick an action below.'));
    } else if (d.kind === 'place') {
      box.appendChild(el('div', 'muted', 'Click a glowing zone on the field.'));
    } else if (d.kind === 'chain') {
      box.appendChild(el('div', 'muted', d.choices.some((c) => !c.card)
        ? "Click a glowing card to activate it, or press Don't activate."
        : 'Click a glowing card to activate it.'));
    }
  } else if (view.waitingFor !== null && view.waitingFor !== undefined) {
    const line = el('div', 'waiting');
    line.append(document.createTextNode('Waiting for '), whoLabel(view.waitingFor), document.createTextNode('...'));
    box.appendChild(line);
  } else box.appendChild(el('div', '', busy ? 'Thinking...' : ''));
  if (mode === 'online' && online && !online.connected) box.appendChild(el('div', 'error', 'Connection lost. Reconnecting...'));
  const err = requestError || (d && d.error);
  if (err) box.appendChild(el('div', 'error', err));
}

function renderActions() {
  const box = $('actions');
  box.replaceChildren();
  const d = view.decision;
  if (!d || d.mode !== 'menu' || !BOARD_KINDS.has(d.kind)) {
    box.classList.add('hidden');
    return;
  }
  box.classList.remove('hidden');
  const phaseRow = el('div', 'phase-buttons');
  for (const c of d.choices) {
    if (!c.card && PHASE_ACTIONS.has(c.label)) {
      const b = el('button', c.label === 'End Turn' ? 'secondary' : '', c.label);
      b.addEventListener('click', () => answer([c.id]));
      phaseRow.appendChild(b);
      continue;
    }
    if (d.kind === 'place') {
      const owner = c.card.controller === d.player ? 'Your' : "Opponent's";
      const b = el('button', 'action', `${owner} ${c.label}`);
      b.addEventListener('click', () => answer([c.id]));
      box.appendChild(b);
      continue;
    }
    const t = choiceText(c);
    const b = el('button', 'action');
    b.appendChild(el('b', '', c.label));
    b.appendChild(document.createTextNode(` ${t.main.slice(c.label.length + 1)}`));
    if (t.sub) b.title = t.sub;
    if (c.card && c.card.code) b.addEventListener('mouseenter', () => showDetail(c.card.code));
    // A click from this list only asks first; the engine can't take a summon back once it has started.
    const confirming = actionConfirm && actionConfirm.decision === d.id && actionConfirm.choice === c.id;
    if (confirming) {
      const row = el('div', 'action-confirm');
      row.appendChild(el('div', 'action-confirm-text', `${t.main}?`));
      const yes = el('button', '', 'Confirm');
      yes.addEventListener('click', () => { actionConfirm = null; answer([c.id]); });
      const no = el('button', 'secondary', 'Cancel');
      no.addEventListener('click', () => { actionConfirm = null; renderActions(); });
      const buttons = el('div', 'button-row');
      buttons.append(yes, no);
      row.appendChild(buttons);
      box.appendChild(row);
      continue;
    }
    b.addEventListener('click', () => { actionConfirm = { decision: d.id, choice: c.id }; renderActions(); });
    box.appendChild(b);
  }
  box.appendChild(phaseRow);
}
/** The action picked from the list that waits for Confirm / Cancel. */
let actionConfirm = null;

function renderModal() {
  const modal = $('modal');
  const d = view.decision;
  if (!d || view.winner !== null || fx.playing || (d.mode === 'menu' && BOARD_KINDS.has(d.kind))) {
    if (!modal.dataset.info) modal.classList.add('hidden');
    return;
  }
  delete modal.dataset.info;
  modal.classList.remove('hidden');
  if (d.mode === 'declare') return renderDeclare(d);
  const title = $('modal-title');
  const body = $('modal-body');
  const footer = $('modal-footer');
  title.replaceChildren(whoLabel(d.player), document.createTextNode(`: ${d.prompt}`));
  if (d.error || requestError) title.appendChild(el('div', 'error', d.error || requestError));
  body.replaceChildren();
  footer.replaceChildren();

  if (d.mode === 'menu') {
    body.className = 'modal-body buttons';
    for (const c of d.choices) {
      const t = choiceText(c);
      const b = el('button', 'choice-btn', t.main);
      if (t.sub) b.appendChild(el('span', 'sub', t.sub));
      if (c.card && c.card.code) b.addEventListener('mouseenter', () => showDetail(c.card.code));
      b.addEventListener('click', () => answer([c.id]));
      body.appendChild(b);
    }
    if (d.canCancel) {
      const cancel = el('button', 'secondary', 'Cancel');
      cancel.addEventListener('click', () => answer(null));
      footer.appendChild(cancel);
    }
    return;
  }

  // multi-select
  if (multiDecisionId !== d.id) {
    multiDecisionId = d.id;
    multiSelected = new Set();
  }
  body.className = 'modal-body';
  const counter = el('span', 'counter');
  const confirmBtn = el('button', '', 'Confirm');
  const refresh = () => {
    counter.textContent = d.min === d.max ? `Selected ${multiSelected.size} of ${d.min}` : `Selected ${multiSelected.size} (choose ${d.min}-${d.max})`;
    confirmBtn.disabled = multiSelected.size < d.min || multiSelected.size > d.max;
  };
  for (const c of d.choices) {
    const tile = el('div', 'tile');
    const card = c.card ? { code: c.card.code, faceDown: !c.card.code, defense: false } : { code: 0, faceDown: true };
    const ce = cardEl(card, { allowRotate: false });
    if (multiSelected.has(c.id)) ce.classList.add('selected');
    tile.appendChild(ce);
    const where = c.card ? `${c.card.controller === d.player ? 'Your' : "Opponent's"} ${LOC_NAME[c.card.location] || ''}` : '';
    tile.appendChild(el('div', 'where', [where, c.detail].filter(Boolean).join(' · ')));
    tile.addEventListener('mouseenter', () => c.card && c.card.code && showDetail(c.card.code));
    tile.addEventListener('click', () => {
      if (multiSelected.has(c.id)) multiSelected.delete(c.id);
      else {
        if (d.max === 1) multiSelected.clear();
        if (multiSelected.size < d.max) multiSelected.add(c.id);
      }
      ce.classList.toggle('selected', multiSelected.has(c.id));
      body.querySelectorAll('.tile').forEach((t, i) => t.firstChild.classList.toggle('selected', multiSelected.has(d.choices[i].id)));
      refresh();
    });
    body.appendChild(tile);
  }
  footer.appendChild(counter);
  if (d.canCancel) {
    const cancel = el('button', 'secondary', 'Cancel');
    cancel.addEventListener('click', () => answer(null));
    footer.appendChild(cancel);
  }
  confirmBtn.addEventListener('click', () => answer([...multiSelected]));
  footer.appendChild(confirmBtn);
  refresh();
}

// "Declare a card name": type part of a name, pick it from the list.
let declareState = { id: null, query: '', results: [] };
function renderDeclare(d) {
  if (declareState.id !== d.id) declareState = { id: d.id, query: '', results: [] };
  $('modal-title').replaceChildren(whoLabel(d.player), document.createTextNode(`: ${d.prompt}`));
  if (d.error || requestError) $('modal-title').appendChild(el('div', 'error', d.error || requestError));
  const body = $('modal-body');
  body.className = 'modal-body declare';
  const input = el('input');
  input.placeholder = 'Type part of a card name...';
  input.value = declareState.query;
  const list = el('div', 'declare-list');
  const showResults = () => {
    list.replaceChildren(...declareState.results.map((c) => {
      const b = el('button', 'choice-btn', c.name);
      b.addEventListener('click', () => answer([c.code]));
      return b;
    }));
    if (declareState.query.length >= 2 && !declareState.results.length) list.appendChild(el('div', 'muted', 'No card found.'));
  };
  let timer = null;
  input.addEventListener('input', () => {
    declareState.query = input.value;
    clearTimeout(timer);
    timer = setTimeout(async () => {
      const q = declareState.query.trim();
      if (q.length < 2) { declareState.results = []; showResults(); return; }
      try {
        const r = await api('GET', `/api/card-names?q=${encodeURIComponent(q)}`);
        if (declareState.id === d.id && declareState.query.trim() === q) { declareState.results = (r.data && r.data.cards) || []; showResults(); }
      } catch { /* network error: keep the old list */ }
    }, 200);
  });
  body.replaceChildren(input, list);
  showResults();
  $('modal-footer').replaceChildren();
  setTimeout(() => { input.focus(); input.setSelectionRange(input.value.length, input.value.length); }, 0);
}

function showPileList(label, cards, controller) {
  const modal = $('modal');
  if (view.decision && !BOARD_KINDS.has(view.decision.kind)) return; // don't hide a question
  modal.dataset.info = '1';
  modal.classList.remove('hidden');
  $('modal-title').replaceChildren(document.createTextNode(`${view.players[controller].name}'s ${label} (${cards.length})`));
  const body = $('modal-body');
  body.className = 'modal-body';
  body.replaceChildren(...[...cards].reverse().map((c) => {
    const tile = el('div', 'tile');
    tile.appendChild(cardEl({ ...c, faceDown: false, defense: false }, { allowRotate: false }));
    tile.addEventListener('mouseenter', () => c.code && showDetail(c.code, c));
    return tile;
  }));
  const close = el('button', 'secondary', 'Close');
  close.addEventListener('click', () => {
    delete modal.dataset.info;
    modal.classList.add('hidden');
  });
  $('modal-footer').replaceChildren(close);
}

function openPopup(anchor, choices, withNames = false) {
  const pop = $('popup');
  pop.replaceChildren();
  for (const c of choices) {
    const b = el('button', '', withNames ? choiceText(c).main : c.label);
    if (c.card && c.card.code) b.addEventListener('mouseenter', () => showDetail(c.card.code));
    b.addEventListener('click', (ev) => {
      ev.stopPropagation();
      answer([c.id]);
    });
    pop.appendChild(b);
    if (c.detail) pop.appendChild(el('div', 'detail-line', c.detail));
  }
  pop.classList.remove('hidden');
  const r = anchor.getBoundingClientRect();
  const w = pop.offsetWidth;
  const h = pop.offsetHeight;
  pop.style.left = `${Math.min(window.innerWidth - w - 8, Math.max(8, r.left + r.width / 2 - w / 2))}px`;
  pop.style.top = `${r.top - h - 8 > 8 ? r.top - h - 8 : r.bottom + 8}px`;
}

function closePopup() {
  $('popup').classList.add('hidden');
}

// ------------------------------------------------------------------ log + header

function renderLog() {
  const box = $('log');
  const atBottom = box.scrollHeight - box.scrollTop - box.clientHeight < 40;
  box.replaceChildren();
  for (const raw of view.log) {
    const line = raw.trim();
    if (!line) continue;
    let cls = '';
    if (line.startsWith('===')) cls = 'turn';
    else if (line.startsWith('--')) cls = 'phase';
    else if (line.startsWith('***')) cls = 'win';
    box.appendChild(el('div', cls, line.replace(/^=== | ===$/g, '').replace(/^\*\*\* | \*\*\*$/g, '')));
  }
  if (atBottom) box.scrollTop = box.scrollHeight;
}

// Cards shown by effects (Clefairy's excavate, Fearow looking at the Deck, revealed searches...).
// Shows the ones not seen yet; closing the panel marks them as seen.
let revealSeen = { duel: null, id: 0 };
function renderReveal() {
  const box = $('reveal');
  const list = (view && view.reveals) || [];
  if (revealSeen.duel !== view.id) revealSeen = { duel: view.id, id: 0 };
  const unseen = list.filter((r) => r.id > revealSeen.id);
  if (!unseen.length) { box.classList.add('hidden'); return; }
  box.classList.remove('hidden');
  box.replaceChildren();
  for (const r of unseen) {
    box.appendChild(el('div', 'reveal-title', r.title));
    const row = el('div', 'reveal-cards');
    for (const code of r.codes) {
      const ce = cardEl({ code, faceDown: false, defense: false }, { allowRotate: false });
      ce.addEventListener('mouseenter', () => showDetail(code));
      row.appendChild(ce);
    }
    box.appendChild(row);
  }
  const footer = el('div', 'reveal-footer');
  const ok = el('button', '', 'OK');
  ok.addEventListener('click', (ev) => {
    ev.stopPropagation();
    revealSeen.id = Math.max(...unseen.map((r) => r.id));
    box.classList.add('hidden');
  });
  footer.appendChild(ok);
  box.appendChild(footer);
}

function renderHeader() {
  const t = $('turninfo');
  t.replaceChildren();
  if (!view.turn) return;
  const b = el('b', '', view.players[view.turnPlayer].name);
  t.append(document.createTextNode(`Turn ${view.turn} · `), b, document.createTextNode(`'s turn · ${view.phase}`));
}

// ------------------------------------------------------------------ animations (like EDOPro: on the board itself)
// Activated cards light up where they are (and show in the card panel); cards that move fly from their
// old place to their new one; the LP counters tick up or down.

let fx = { duel: null, lastId: 0, queue: [], playing: false };
let boardRects = new Map();   // where every zone was on screen just before the board was redrawn
let lpShown = { duel: null, lp: [null, null] };

const zoneKey = (pos) => `${pos.controller}-${pos.location}-${pos.sequence}`;
const pileKey = (pos) => `${pos.controller}-${pos.location}`;

/** Remember where everything is before the board is redrawn (cards that leave must fly from there). */
function snapshotBoard() {
  boardRects = new Map();
  for (const node of document.querySelectorAll('[data-zone]')) {
    const r = node.getBoundingClientRect();
    if (r.width) boardRects.set(node.dataset.zone, r);
  }
}
function rectNow(pos) {
  const node = document.querySelector(`[data-zone="${zoneKey(pos)}"]`) || document.querySelector(`[data-zone="${pileKey(pos)}"]`);
  return node ? node.getBoundingClientRect() : null;
}
const rectBefore = (pos) => boardRects.get(zoneKey(pos)) || boardRects.get(pileKey(pos)) || rectNow(pos);

/** Queues the board events that are new since the last update (on a duel's first update, just remembers them). */
function queueEvents() {
  const events = (view && view.events) || [];
  if (fx.duel !== view.id) {
    fx = { duel: view.id, lastId: events.length ? events[events.length - 1].id : 0, queue: [], playing: false };
    return;
  }
  const fresh = events.filter((e) => e.id > fx.lastId && e.kind !== 'damage' && e.kind !== 'recover');
  if (events.length) fx.lastId = Math.max(fx.lastId, events[events.length - 1].id);
  if (!fresh.length) return;
  // Each activation is its own step; cards moving one after another (Raigeki, a resolving chain) fly together.
  for (const e of fresh) {
    const last = fx.queue[fx.queue.length - 1];
    if (e.kind !== 'activate' && last && last.kind === 'move' && last.items[0].kind === e.kind && !last.started) last.items.push(e);
    else fx.queue.push({ kind: e.kind === 'activate' ? 'activate' : 'move', items: [e], started: false, from: new Map() });
    // Where the card was, measured now (before the board is redrawn).
    const step = fx.queue[fx.queue.length - 1];
    step.from.set(e.id, rectBefore(e.kind === 'activate' ? e.at : e.from));
  }
  fx.playing = true;
}

/** Starts the queued animations once the new board is on screen. */
function runFx() {
  if (!fx.playing || fx.running) return;
  fx.running = true;
  playNextFx();
}

/** A card played from the hand: hide it there (yours by its name; the opponent's hidden hand, one card back). */
function hideHandCard(player, code) {
  const hand = document.querySelector(`[data-zone="${player}-${LOC.HAND}"]`);
  if (!hand) return;
  // The copy you clicked (if it was you, a moment ago); otherwise the first card with that name.
  const pick = lastHandPick;
  if (pick && pick.player === player && pick.code === code && Date.now() - pick.at < 30000) {
    lastHandPick = null;
    const exact = document.querySelector(`[data-zone="${player}-${LOC.HAND}-${pick.sequence}"]`);
    if (exact) { exact.style.visibility = 'hidden'; return; }
  }
  const cards = [...hand.querySelectorAll('.card')].filter((c) => c.style.visibility !== 'hidden');
  const match = cards.find((c) => c.dataset.code === String(code)) || cards.filter((c) => c.classList.contains('back')).pop();
  if (match) match.style.visibility = 'hidden';
}

/** The card element shown at a place on the board right now (a zone's card, or that card in the hand). */
function cardAt(pos) {
  const node = document.querySelector(`[data-zone="${zoneKey(pos)}"]`);
  if (!node) return null;
  return node.classList.contains('card') ? node : node.querySelector('.card');
}

function ghost(code, rect) {
  const g = cardEl({ code, faceDown: !code, defense: false }, { allowRotate: false, peek: false });
  g.classList.add('fx-ghost');
  Object.assign(g.style, { left: `${rect.left}px`, top: `${rect.top}px`, width: `${rect.width}px`, height: `${rect.height}px` });
  document.body.appendChild(g);
  return g;
}

function playNextFx() {
  const step = fx.queue.shift();
  if (!step || !view) {
    fx.playing = false;
    fx.running = false;
    render(); // questions and the result waited for the animations
    return;
  }
  step.started = true;
  const fast = fx.queue.length >= 3; // long chains play faster, so nobody's clock suffers
  if (step.kind === 'activate') {
    const e = step.items[0];
    if (e.code) showDetail(e.code);
    // Like EDOPro, the card sits in its zone, face-up, until its effect has played out and it moves on:
    // a Set card turns face-up in place, a card played from the hand appears in its zone (and leaves the hand).
    let still = null;
    if (e.at.location !== LOC.HAND) {
      const zoneNode = document.querySelector(`[data-zone="${zoneKey(e.at)}"]`);
      still = zoneNode ? zoneNode.querySelector('.card') : null;
      if (zoneNode && (!still || still.classList.contains('back')) && e.code) {
        const faceUp = cardEl({ code: e.code, faceDown: false, defense: false }, { allowRotate: false });
        if (still) still.replaceWith(faceUp);
        else {
          const label = zoneNode.querySelector('.label');
          if (label) label.remove();
          zoneNode.appendChild(faceUp);
          hideHandCard(e.player, e.code);
        }
        still = faceUp;
      }
    }
    if (still) still.classList.add('fx-activating');
    const time = still ? (fast ? 500 : 1000) : (fast ? 200 : 500); // a hand effect: just a short pause on the card panel
    setTimeout(() => {
      if (still) still.classList.remove('fx-activating'); // it stays in its zone; a later step moves it
      playNextFx();
    }, time);
    return;
  }
  // Cards moving: each flies from where it was to its new pile / zone / hand.
  const ghosts = [];
  for (const e of step.items) {
    const from = step.from.get(e.id);
    const to = rectNow(e.to);
    if (!from || !to) continue;
    const g = ghost(e.code, from);
    if (e.kind === 'destroyed') g.classList.add('fx-destroyed');
    // The card leaves its old place (a pile keeps showing its count until the board updates).
    const src = e.from.location === LOC.DECK || e.from.location === LOC.GRAVE || e.from.location === LOC.REMOVED || e.from.location === LOC.EXTRA ? null : cardAt(e.from);
    if (src) src.style.visibility = 'hidden';
    ghosts.push([g, from, to]);
  }
  if (!ghosts.length) { playNextFx(); return; }
  const delay = step.items.some((e) => e.kind === 'destroyed') ? (fast ? 150 : 300) : 0;
  setTimeout(() => {
    for (const [g, from, to] of ghosts) {
      const dx = to.left + to.width / 2 - (from.left + from.width / 2);
      const dy = to.top + to.height / 2 - (from.top + from.height / 2);
      const scale = Math.min(1.2, Math.max(0.5, to.height / from.height));
      g.style.transition = `transform ${fast ? 300 : 450}ms ease-in-out, opacity ${fast ? 300 : 450}ms ease-in`;
      g.style.transform = `translate(${dx}px, ${dy}px) scale(${scale})`;
      g.style.opacity = '0.35';
    }
    setTimeout(() => { for (const [g] of ghosts) g.remove(); playNextFx(); }, fast ? 320 : 480);
  }, delay);
}

/** LP counters tick to their new value; a small red/green number floats up next to them. */
function animateLp() {
  if (lpShown.duel !== view.id) { lpShown = { duel: view.id, lp: view.players.map((pl) => pl.lp) }; return; }
  view.players.forEach((pl, p) => {
    const before = lpShown.lp[p];
    const after = pl.lp;
    lpShown.lp[p] = after;
    if (before === null || before === after) return;
    const node = document.querySelector(`.lp[data-player="${p}"]`);
    if (!node) return;
    const diff = after - before;
    const pop = el('span', `lp-pop ${diff < 0 ? 'down' : 'up'}`, `${diff > 0 ? '+' : ''}${diff}`);
    node.parentNode.insertBefore(pop, node.nextSibling);
    node.classList.add(diff < 0 ? 'lp-hit' : 'lp-heal');
    const start = performance.now();
    const tick = (now) => {
      const t = Math.min(1, (now - start) / 700);
      node.textContent = `LP ${Math.round(before + diff * t)}`;
      if (t < 1 && node.isConnected) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
    setTimeout(() => { pop.remove(); node.classList.remove('lp-hit', 'lp-heal'); }, 1400);
  });
}

function renderWinner() {
  const box = $('winner');
  if (view.winner === null || fx.playing) {
    box.classList.add('hidden');
    return;
  }
  box.classList.remove('hidden');
  let text = view.winner === 2 ? 'The duel is a draw!' : `${view.players[view.winner].name} wins!`;
  if (mode === 'online' && view.winner !== 2) text = view.winner === me() ? 'You win!' : `You lose. ${view.players[view.winner].name} wins.`;
  $('winner-text').textContent = text;
  $('winner-reason').textContent = view.endReason ? `${view.endReason}.` : '';
  $('btn-again').textContent = 'Back to menu';
}

// ------------------------------------------------------------------ start screen / lobby

function renderLobby() {
  const lobby = $('lobby');
  const box = $('lobby-box');
  const params = new URLSearchParams(location.search);
  const inviteRoom = params.get('room');
  const status = online && online.state ? online.state.status : null;
  const showLobby = mode === null || (mode === 'online' && (!online.state || status === 'waiting' || status === 'starting'));
  lobby.classList.toggle('hidden', !showLobby);
  if (!showLobby) return;
  // Keep scroll positions (deck editor lists) across re-renders.
  const scrolls = {};
  for (const node of box.querySelectorAll('[data-keep-scroll]')) scrolls[node.dataset.keepScroll] = node.scrollTop;
  const boxScroll = box.scrollTop;
  // Keep typing focus too: search results arrive while you type and redraw the screen, so the text box
  // you were typing in gets its focus and cursor back (found again by its class + placeholder).
  const focusKey = (n) => `${n.tagName}|${n.className}|${n.placeholder || ''}|${n.type || ''}`;
  const active = document.activeElement;
  const focused = active && box.contains(active) && ['INPUT', 'TEXTAREA'].includes(active.tagName) && active.type !== 'file'
    ? { key: focusKey(active), start: active.selectionStart, end: active.selectionEnd } : null;
  const restoreFocus = () => {
    if (!focused) return;
    const now = document.activeElement;
    if (now && box.contains(now) && focusKey(now) === focused.key) return; // already back (typing path)
    const again = [...box.querySelectorAll('input, textarea')].find((n) => focusKey(n) === focused.key);
    if (!again) return;
    again.focus();
    try { if (focused.start !== null) again.setSelectionRange(focused.start, focused.end); } catch { /* number inputs */ }
  };
  box.replaceChildren();
  box.classList.remove('wide');
  box.appendChild(siteLogo());
  const banner = maintenanceBanner();
  if (banner) box.appendChild(banner);
  if (mode === null && currentUser && !inviteRoom) {
    renderMenus(box);
    for (const node of box.querySelectorAll('[data-keep-scroll]')) node.scrollTop = scrolls[node.dataset.keepScroll] || 0;
    box.scrollTop = boxScroll;
    restoreFocus();
    return;
  }

  const authForm = (intro) => {
    const form = el('form', 'auth-form');
    const input = (placeholder, type, autocomplete, max) => {
      const i = el('input', 'text-input');
      i.placeholder = placeholder;
      if (type) i.type = type;
      if (autocomplete) i.autocomplete = autocomplete;
      if (max) i.maxLength = max;
      i.required = true;
      return i;
    };
    const linkButton = (label, onClick) => {
      const b = el('button', 'link-button', label);
      b.type = 'button';
      b.addEventListener('click', () => { lobbyError = ''; authNotice = ''; onClick(); render(); });
      return b;
    };
    const finish = (first, submitLabel, onSubmit, links) => {
      if (authNotice) form.appendChild(el('p', 'notice small', authNotice));
      if (lobbyError) form.appendChild(el('div', 'error', lobbyError));
      const submit = el('button', '', authBusy ? 'Please wait...' : submitLabel);
      submit.type = 'submit';
      submit.disabled = authBusy;
      form.appendChild(submit);
      if (links.length) {
        const row = el('div', 'auth-links');
        row.append(...links);
        form.appendChild(row);
      }
      form.addEventListener('submit', (ev) => { ev.preventDefault(); onSubmit(); });
      setTimeout(() => { if (!form.contains(document.activeElement)) first.focus(); }, 0);
      return form;
    };
    const codeInput = () => {
      const c = input('6-digit code', 'text', 'one-time-code', 6);
      c.inputMode = 'numeric';
      c.pattern = '[0-9 ]*';
      return c;
    };

    if (authStep && authStep.kind === 'verify') {
      form.appendChild(el('h3', '', 'Check your email'));
      if (!authNotice) form.appendChild(el('p', 'muted small', `Enter the code we emailed${authStep.email ? ` to ${authStep.email}` : ''}.`));
      const code = codeInput();
      form.appendChild(code);
      const step = authStep;
      return finish(code, 'Confirm', () => authRequest('verify', { username: step.username, code: code.value }), [
        linkButton('Send a new code', () => authRequest('resend', { username: step.username, password: step.password }, () => {
          authNotice = 'A new code is on its way.';
        })),
        linkButton('Back', () => { authStep = null; }),
      ]);
    }
    if (authStep && authStep.kind === 'forgot') {
      form.appendChild(el('h3', '', 'Forgot password'));
      form.appendChild(el('p', 'muted small', 'Enter the email of your account and we\'ll send you a code to choose a new password.'));
      const email = input('Email', 'email', 'email', 200);
      form.appendChild(email);
      return finish(email, 'Send code', () => {
        const address = email.value.trim();
        authRequest('forgot', { email: address }, () => {
          authStep = { kind: 'reset', email: address };
          authNotice = `If ${address} belongs to an account, a code is on its way. Check the spam folder too.`;
        });
      }, [linkButton('Back to log in', () => { authStep = null; authTab = 'login'; })]);
    }
    if (authStep && authStep.kind === 'reset') {
      form.appendChild(el('h3', '', 'Choose a new password'));
      const code = codeInput();
      const pass = input('New password (at least 8 characters)', 'password', 'new-password', 200);
      form.append(code, pass);
      const step = authStep;
      return finish(code, 'Save password and log in', () => authRequest('reset', { email: step.email, code: code.value, password: pass.value }), [
        linkButton('Send a new code', () => authRequest('forgot', { email: step.email }, () => { authNotice = 'A new code is on its way.'; })),
        linkButton('Back to log in', () => { authStep = null; authTab = 'login'; }),
      ]);
    }

    if (intro) form.appendChild(el('p', 'muted', intro));
    const tabs = el('div', 'tabs');
    for (const [key, label] of [['login', 'Log in'], ['register', 'Create account']]) {
      const t = el('button', authTab === key ? 'tab active' : 'tab', label);
      t.type = 'button';
      t.addEventListener('click', () => { authTab = key; lobbyError = ''; authNotice = ''; render(); });
      tabs.appendChild(t);
    }
    form.appendChild(tabs);
    const user = input('Username', 'text', 'username', 20);
    form.appendChild(user);
    let email = null;
    if (authTab === 'register') {
      email = input('Email (for your code)', 'email', 'email', 200);
      form.appendChild(email);
    }
    const pass = input(authTab === 'register' ? 'Password (at least 8 characters)' : 'Password', 'password', authTab === 'register' ? 'new-password' : 'current-password', 200);
    form.appendChild(pass);
    if (authTab === 'register') {
      form.appendChild(el('p', 'muted small', 'Usernames: 3-20 letters, numbers, _ or -. Your email is only used for codes and password resets; other players never see it.'));
      const agree = el('p', 'muted small');
      agree.append('By creating an account you agree to the ', rulesLink('rules and privacy notice'), '.');
      form.appendChild(agree);
    }
    return finish(user, authTab === 'register' ? 'Create account' : 'Log in',
      () => submitAuth(authTab, user.value.trim(), pass.value, email ? email.value.trim() : ''),
      authTab === 'login' ? [linkButton('Forgot password?', () => { authStep = { kind: 'forgot' }; })] : []);
  };
  const userBar = () => {
    const bar = el('div', 'user-bar');
    bar.append(document.createTextNode('Logged in as '), el('b', '', currentUser.username), el('span', 'muted', ` \u00b7 ELO ${currentUser.elo}`));
    const out = el('button', 'link-button', 'Log out');
    out.addEventListener('click', logout);
    bar.appendChild(out);
    return bar;
  };
  const errorLine = () => (lobbyError ? el('div', 'error', lobbyError) : null);

  if (mode === 'online') {
    if (status === 'starting') {
      box.appendChild(el('p', '', 'Your opponent joined. Shuffling decks...'));
      return;
    }
    // Not connected yet, or a ranked duel (both players are already in it): never show the invite links.
    if (!online.state || online.state.ranked || (online.state.seats && online.state.seats[1])) {
      box.appendChild(el('p', '', online.connected || !online.state ? 'Connecting to the duel...' : 'Reconnecting...'));
      if (online.state === null && online.connectSince && Date.now() - online.connectSince > 8000) {
        box.appendChild(el('p', 'muted small', 'This is taking long. Check your internet connection; the game keeps trying.'));
      }
      const leave = el('button', 'secondary', 'Back to menu');
      leave.addEventListener('click', goToMenu);
      box.appendChild(leave);
      return;
    }
    box.appendChild(el('h2', '', 'Waiting for your opponent'));
    box.appendChild(el('p', 'muted', 'Send this link to the person you want to duel. The duel starts as soon as they open it.'));
    const link = `${location.origin}/?room=${online.roomId}`;
    box.appendChild(copyRow(link));
    const lan = lanUrls.map((u) => `${u}/?room=${online.roomId}`);
    if (lan.length) {
      box.appendChild(el('p', 'muted small', 'Playing with someone on another computer on the same Wi-Fi? Send them this link instead:'));
      for (const l of lan) box.appendChild(copyRow(l));
    }
    box.appendChild(el('p', 'muted small', 'Testing alone? Open the link in a private/incognito window and log in with a second account.'));
    const cancel = el('button', 'secondary', 'Cancel');
    cancel.addEventListener('click', goToMenu);
    box.appendChild(cancel);
    return;
  }

  const backToMenu = () => {
    const back = el('button', 'secondary', 'Back to menu');
    back.addEventListener('click', () => { lobbyError = ''; history.replaceState(null, '', '/'); render(); });
    return back;
  };

  if (inviteRoom) {
    box.appendChild(el('h2', '', "You've been invited to a duel"));
    if (!currentUser) {
      box.appendChild(authForm('Log in or create an account to join.'));
      box.appendChild(backToMenu());
      return;
    }
    box.appendChild(userBar());
    const join = el('button', '', 'Join duel');
    join.addEventListener('click', () => joinOnline(inviteRoom));
    const err = errorLine();
    if (err) box.appendChild(err);
    const row = el('div', 'button-row');
    row.append(join, backToMenu());
    box.appendChild(row);
    return;
  }

  box.appendChild(el('p', 'muted', 'Yugs: Playground Dueling is in beta: a free Yu-Gi-Oh! ladder with packs, your own decks and some custom cards.'));
  if (!currentUser) {
    box.appendChild(authForm('Log in or create an account to start dueling.'));
    box.appendChild(discordBox());
    return;
  }
  box.appendChild(userBar());
  const create = el('button', '', 'Create online duel');
  create.addEventListener('click', createOnline);
  const row = el('div', 'button-row');
  row.append(create);
  const err = errorLine();
  if (err) box.appendChild(err);
  box.appendChild(row);
}

function copyRow(text) {
  const row = el('div', 'copy-row');
  const input = el('input', 'text-input');
  input.readOnly = true;
  input.value = text;
  input.addEventListener('focus', () => input.select());
  const btn = el('button', 'secondary', 'Copy');
  btn.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      input.select();
      document.execCommand('copy');
    }
    btn.textContent = 'Copied!';
    setTimeout(() => (btn.textContent = 'Copy'), 1500);
  });
  row.append(input, btn);
  return row;
}

function render() {
  snapshotBoard();
  renderLobby();
  $('btn-surrender').classList.toggle('hidden', !view || view.winner !== null);
  $('btn-new').textContent = 'Menu';
  if (view && view.players && view.players.some((pl) => !Array.isArray(pl.extra))) {
    // The page is newer than the server that is running.
    $('prompt').replaceChildren(el('div', 'error', 'The game server is out of date. Close the black Yugs window and double-click start.bat again.'));
    return;
  }
  if (!view) {
    $('reveal').classList.add('hidden');
    if (mode !== null) $('prompt').replaceChildren(el('div', 'error', requestError || 'Starting duel...'));
    return;
  }
  queueEvents(); // first: it measures where cards were
  // Like EDOPro: while animations play, the board keeps showing how it was; it updates when they finish.
  if (fx.playing) { runFx(); return; }
  const actions = actionMap();
  renderHeader();
  renderSide(me(), 'side-0', actions);
  renderSide(1 - me(), 'side-1', actions);
  renderEmz(actions);
  renderPrompt();
  renderActions();
  renderModal();
  renderLog();
  renderReveal();
  renderWinner();
  animateLp();
  runFx();
}

// ------------------------------------------------------------------ start

document.addEventListener('click', closePopup);
$('btn-new').addEventListener('click', () => {
  const inDuel = view && view.winner === null;
  const question = mode === 'practice'
    ? 'Leave this test duel and go back to the menu?'
    : 'Leave this duel and go back to the menu? You can come back with the same link in this tab.';
  if (!inDuel || confirm(question)) goToMenu();
});
$('btn-again').addEventListener('click', () => goToMenu());
$('btn-surrender').addEventListener('click', surrender);
$('btn-report').addEventListener('click', () => openBugReport());

(async function init() {
  await initCardImages();
  api('GET', '/api/info').then(({ ok, data }) => { if (ok) lanUrls = data.lanUrls || []; }).catch(() => {});
  await Promise.all([loadUser(), loadSiteStatus()]);
  setInterval(loadSiteStatus, 60_000);
  const room = new URLSearchParams(location.search).get('room');
  if (room && storedSeat(room)) connectRoom(room);
  else if (room && currentUser) joinOnline(room); // gives your seat back if you were already in this duel
  else render();
})();
