// Admin screen: look up players, see what they own, ban / unban, mute in chat.
const playersView = { q: '', list: null, total: 0, loading: false, openId: null, detail: null, message: '' };

async function loadPlayers() {
  playersView.loading = true;
  const { ok, data } = await api('GET', `/api/admin/players?q=${encodeURIComponent(playersView.q)}`).catch(() => ({ ok: false, data: { error: 'Cannot reach the server.' } }));
  playersView.loading = false;
  if (ok) { playersView.list = data.players; playersView.total = data.total; } else { playersView.list = []; playersView.message = data.error; }
  render();
}

async function loadPlayerDetail(id) {
  const { ok, data } = await api('GET', `/api/admin/players/${id}`);
  if (ok) playersView.detail = data; else playersView.message = data.error;
  render();
}

const fmtDate = (t) => (t ? new Date(t).toLocaleString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'never');
const BAN_FOREVER_MS = 8_640_000_000_000_000;

function playerStatus(p) {
  const now = Date.now();
  if (p.bannedUntil > now) return p.bannedUntil >= BAN_FOREVER_MS ? 'Banned forever' : `Banned until ${fmtDate(p.bannedUntil)}`;
  if (!p.emailVerified) return 'Never confirmed their email';
  if (p.mutedUntil > now) return `Muted until ${fmtDate(p.mutedUntil)}`;
  return '';
}

async function playerAction(url, body, done) {
  playersView.message = '';
  const { ok, data } = await api('POST', url, body).catch(() => ({ ok: false, data: { error: 'Cannot reach the server.' } }));
  if (!ok) playersView.message = data.error;
  else playersView.message = done;
  playersView.list = null;
  if (playersView.openId) await loadPlayerDetail(playersView.openId);
  render();
}

function renderPlayerDetail(box, d) {
  const p = d.player;
  const card = el('div', 'player-detail');
  card.appendChild(el('h3', '', `${p.username}${p.isAdmin ? ' (admin)' : ''}`));
  const status = playerStatus(p);
  if (status) card.appendChild(el('div', p.bannedUntil > Date.now() ? 'error' : 'notice small', status + (p.banReason && p.bannedUntil > Date.now() ? ` · Reason: ${p.banReason}` : '')));
  const facts = [
    ['Email', p.email ? `${p.email}${p.emailVerified ? '' : ' (not confirmed)'}` : 'none (older account)'],
    ['ELO', `${p.elo}  (${p.wins} W / ${p.losses} L / ${p.draws} D)`],
    ['Coins', p.coins],
    ['Cards', `${p.cards} (${p.distinctCards} different)`],
    ['Packs', `${p.packsOpened} opened, ${p.packsBought} bought, ${p.freePacks} free left`],
    ['Starter', p.starter || 'not chosen yet'],
    ['Decks', d.decks.length ? d.decks.map((x) => x.name).join(', ') : 'none'],
    ['Joined', fmtDate(p.createdAt)],
    ['Last login', fmtDate(p.lastLoginAt)],
  ];
  const table = el('div', 'facts');
  for (const [k, v] of facts) table.append(el('span', 'muted', k), el('span', '', String(v)));
  card.appendChild(table);

  if (d.packs.length) {
    card.appendChild(el('div', 'muted small', 'Last packs opened:'));
    const ul = el('ul', 'small');
    for (const pk of d.packs) ul.appendChild(el('li', '', `${fmtDate(pk.openedAt)} · ${pk.pack}${pk.free ? ' (free)' : ''} · ${pk.cards} cards`));
    card.appendChild(ul);
  }

  if (!p.isAdmin) {
    const banned = p.bannedUntil > Date.now();
    const row = el('div', 'button-row');
    if (banned) {
      row.appendChild(button('Unban', () => playerAction(`/api/admin/players/${p.id}/unban`, {}, `${p.username} is unbanned.`), 'secondary'));
    } else {
      const reason = el('input', 'text-input');
      reason.placeholder = 'Reason (the player sees it)';
      reason.maxLength = 300;
      const length = el('select', 'text-input');
      for (const [v, label] of [['1', '1 day'], ['3', '3 days'], ['7', '7 days'], ['30', '30 days'], ['forever', 'Forever']]) {
        const o = el('option', '', label); o.value = v; length.appendChild(o);
      }
      const go = button('Ban', () => {
        const forever = length.value === 'forever';
        if (!confirmInline(go, `Really ban ${p.username}${forever ? ' forever' : ` for ${length.selectedOptions[0].textContent}`}?`)) return;
        playerAction(`/api/admin/players/${p.id}/ban`, { days: forever ? null : Number(length.value), reason: reason.value }, `${p.username} is banned. Any duel they were in counts as a loss.`);
      }, 'danger');
      card.appendChild(el('div', 'muted small', 'Ban: logs them out, they lose any duel in progress and they can\'t log in until it ends.'));
      row.append(reason, length, go);
    }
    const muted = p.mutedUntil > Date.now();
    row.appendChild(muted
      ? button('Unmute', () => playerAction('/api/admin/chat/mute', { username: p.username, minutes: 0 }, `${p.username} can chat again.`), 'secondary')
      : button('Mute in chat 24 h', () => playerAction('/api/admin/chat/mute', { username: p.username, minutes: 1440 }, `${p.username} is muted for 24 hours.`), 'secondary'));
    card.appendChild(row);
  }
  box.appendChild(card);
}

/** Asks for a second click on the same button instead of a browser pop-up. */
function confirmInline(btn, question) {
  if (btn.dataset.armed === '1') return true;
  btn.dataset.armed = '1';
  btn.textContent = question + ' Click again';
  setTimeout(() => { btn.dataset.armed = ''; btn.textContent = 'Ban'; }, 4000);
  return false;
}

function renderPlayers(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Players'), button('Back', () => { screen = 'home'; playersView.openId = null; playersView.detail = null; playersView.message = ''; render(); }, 'secondary'));
  box.appendChild(top);
  if (playersView.message) box.appendChild(el('div', 'notice small', playersView.message));

  if (playersView.openId) {
    box.appendChild(button('← All players', () => { playersView.openId = null; playersView.detail = null; playersView.message = ''; render(); }, 'link-button'));
    if (!playersView.detail) { box.appendChild(el('p', 'muted', 'Loading...')); return; }
    return renderPlayerDetail(box, playersView.detail);
  }

  const search = el('input', 'text-input');
  search.placeholder = 'Search by username or email';
  search.value = playersView.q;
  let timer = null;
  search.addEventListener('input', () => {
    playersView.q = search.value;
    clearTimeout(timer);
    timer = setTimeout(() => { playersView.list = null; render(); }, 300);
  });
  box.appendChild(search);
  if (!playersView.list) { if (!playersView.loading) loadPlayers(); box.appendChild(el('p', 'muted', 'Loading...')); return; }
  box.appendChild(el('p', 'muted small', playersView.q ? `${playersView.list.length} found` : `Newest ${playersView.list.length} of ${playersView.total} accounts`));
  const list = el('div', 'player-list');
  for (const p of playersView.list) {
    const row = el('button', 'player-row');
    row.type = 'button';
    row.append(el('b', '', p.username), el('span', 'muted', `ELO ${p.elo} · ${p.coins} coins · ${p.cards} cards · ${p.packsOpened} packs`));
    const status = playerStatus(p);
    if (status) row.appendChild(el('span', p.bannedUntil > Date.now() ? 'tag bad' : 'tag', status));
    row.addEventListener('click', () => { playersView.openId = p.id; playersView.detail = null; playersView.message = ''; loadPlayerDetail(p.id); render(); });
    list.appendChild(row);
  }
  box.appendChild(list);
}
