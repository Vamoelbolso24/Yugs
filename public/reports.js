// Bug reports: a "Report a bug" window players can open anywhere (menus or duels),
// and the admin list where reports are read and marked fixed or closed.
'use strict';

const SUPPORT_EMAIL = 'support@playgrounddueling.com';

/** What we attach automatically: where the player was and, in a duel, the last lines of the duel log. */
function bugContext() {
  const ctx = { screen: mode === null ? screen : `duel (${mode})`, url: location.pathname + location.search, browser: navigator.userAgent, at: new Date().toISOString() };
  if (view) {
    ctx.turn = view.turn;
    ctx.log = (view.log || []).slice(-40);
    if (online && online.roomId) ctx.room = online.roomId;
  }
  return ctx;
}

function openBugReport() {
  if (!currentUser) { alert(`Log in to send a report, or email ${SUPPORT_EMAIL}.`); return; }
  const ctx = bugContext(); // taken now, before the window covers anything
  const back = el('div', 'bug-backdrop');
  const box = el('div', 'bug-box');
  box.appendChild(el('h2', '', 'Report a bug'));
  box.appendChild(el('p', 'muted small', 'What happened, and what did you click just before? Which card was involved? We attach the screen you were on and, in a duel, the last lines of the duel log.'));
  const text = el('textarea', 'text-input bug-text');
  text.placeholder = 'Example: I activated Raigeki but my opponent\'s monsters were not destroyed.';
  text.maxLength = 3000;
  const msg = el('div', 'small');
  const send = el('button', '', 'Send report');
  const cancel = el('button', 'secondary', 'Cancel');
  const close = () => back.remove();
  cancel.addEventListener('click', close);
  back.addEventListener('click', (ev) => { if (ev.target === back) close(); });
  send.addEventListener('click', async () => {
    send.disabled = true;
    const { ok, data } = await api('POST', '/api/reports', { text: text.value, context: ctx });
    send.disabled = false;
    if (!ok) { msg.className = 'error small'; msg.textContent = data.error; return; }
    box.replaceChildren(el('h2', '', 'Thank you!'), el('p', '', 'Your report was sent. We read every one.'));
    const ok2 = el('button', '', 'Close');
    ok2.addEventListener('click', close);
    box.appendChild(ok2);
  });
  const row = el('div', 'button-row');
  row.append(send, cancel);
  box.append(text, msg, row, el('p', 'muted small', `Screenshots help a lot: you can also email ${SUPPORT_EMAIL}.`));
  back.appendChild(box);
  document.body.appendChild(back);
  text.focus();
}

// ------------------------------------------------------------------ admin: read the reports

let reportsView = { status: 'open', data: null, loading: false, open: new Set() };

async function loadReports() {
  reportsView.loading = true;
  const { ok, data } = await api('GET', `/api/admin/reports?status=${reportsView.status}`);
  reportsView.loading = false;
  if (ok) reportsView.data = data;
  else menuMessage = data.error;
  render();
}

function renderReports(box) {
  const top = el('div', 'screen-top');
  top.append(el('h2', '', 'Bug reports'), button('Back', () => { screen = 'home'; reportsView.data = null; render(); }, 'secondary'));
  box.appendChild(top);
  if (menuMessage) box.appendChild(el('div', 'error', menuMessage));
  const tabs = el('div', 'filters');
  const counts = (reportsView.data && reportsView.data.counts) || {};
  for (const [st, label] of [['open', 'Open'], ['fixed', 'Fixed'], ['closed', 'Closed'], ['all', 'All']]) {
    const n = st === 'all' ? Object.values(counts).reduce((a, b) => a + b, 0) : counts[st] || 0;
    tabs.appendChild(button(`${label} (${n})`, () => { reportsView.status = st; reportsView.data = null; render(); }, reportsView.status === st ? 'chip active' : 'chip'));
  }
  box.appendChild(tabs);
  if (!reportsView.data) { if (!reportsView.loading) loadReports(); box.appendChild(el('p', 'muted', 'Loading...')); return; }
  const list = reportsView.data.reports;
  if (!list.length) box.appendChild(el('p', 'muted', 'No reports here.'));
  for (const r of list) {
    const item = el('div', 'news-post');
    const when = new Date(r.createdAt).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
    item.appendChild(el('div', 'muted small', `#${r.id} · ${r.username} · ${when} · ${r.context.screen || ''} · ${r.status}`));
    item.appendChild(el('p', 'bug-report-text', r.text));
    const shown = reportsView.open.has(r.id);
    if (shown) item.appendChild(el('pre', 'bug-context', JSON.stringify(r.context, null, 2)));
    const row = el('div', 'button-row');
    row.appendChild(button(shown ? 'Hide details' : 'Details (screen, duel log)', () => { shown ? reportsView.open.delete(r.id) : reportsView.open.add(r.id); render(); }, 'ghost small'));
    for (const [st, label] of [['fixed', 'Mark fixed'], ['closed', 'Close (not a bug)'], ['open', 'Reopen']]) {
      if (r.status === st) continue;
      row.appendChild(button(label, async () => {
        const { ok, data } = await api('PUT', `/api/admin/reports/${r.id}`, { status: st });
        if (!ok) menuMessage = data.error;
        reportsView.data = null;
        render();
      }, 'ghost small'));
    }
    item.appendChild(row);
    box.appendChild(item);
  }
}
