// "Rules & privacy" window. Works logged out too. Link to it with  #rules  (for example playgrounddueling.com/#rules).
let rulesText = null;

async function openRules() {
  if (document.querySelector('.rules-backdrop')) return;
  const back = el('div', 'bug-backdrop rules-backdrop');
  const box = el('div', 'bug-box rules-box');
  const close = () => {
    back.remove();
    if (location.hash === '#rules') history.replaceState(null, '', location.pathname + location.search);
  };
  const closeBtn = el('button', 'secondary', 'Close');
  closeBtn.addEventListener('click', close);
  back.addEventListener('click', (ev) => { if (ev.target === back) close(); });
  document.addEventListener('keydown', function esc(ev) {
    if (ev.key === 'Escape') { close(); document.removeEventListener('keydown', esc); }
  });
  const body = el('div', 'rules-body');
  body.appendChild(el('p', 'muted', 'Loading...'));
  box.append(body, closeBtn);
  back.appendChild(box);
  document.body.appendChild(back);
  if (rulesText === null) {
    const { ok, data } = await api('GET', '/api/news').catch(() => ({ ok: false, data: {} }));
    rulesText = ok ? data.rules || '' : null;
  }
  body.replaceChildren(rulesText ? renderMarkdown(rulesText) : el('p', 'error', 'Could not load the rules. Try again in a moment.'));
}

function rulesLink(label = 'Rules & privacy') {
  const a = el('a', 'rules-link', label);
  a.href = '#rules';
  a.addEventListener('click', (ev) => { ev.preventDefault(); openRules(); });
  return a;
}

window.addEventListener('hashchange', () => { if (location.hash === '#rules') openRules(); });
window.addEventListener('DOMContentLoaded', () => {
  const foot = document.querySelector('.footer');
  if (foot) foot.append(' · ', rulesLink());
  if (location.hash === '#rules') openRules();
});
