// Tests duels vs the bot and admin tools over HTTP against a running server.
// The admin account is made with the admin script first, so pass the same database:
//   node scripts/admin-bot-test.ts [baseUrl]   (needs YUGS_DB to point at the server's database)
import { execFileSync } from 'node:child_process';
import { testSignup } from './test-signup.ts';
const BASE = process.argv[2] ?? 'http://localhost:3000';
const failures: string[] = [];
const check = (ok: boolean, label: string) => { console.log(`${ok ? 'OK  ' : 'FAIL'} ${label}`); if (!ok) failures.push(label); };
async function call(method: string, path: string, body: unknown, cookie: string) {
  const res = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', Cookie: cookie }, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: res.status, data: await res.json() as any, setCookie: res.headers.get('set-cookie') ?? '' };
}
async function account(starter: string): Promise<{ cookie: string; name: string }> {
  const name = `t${Math.random().toString(36).slice(2, 9)}`;
  const r = await testSignup(BASE, name, 'testpassword');
  const cookie = r.setCookie.split(';')[0]!;
  await call('POST', '/api/starters/choose', { starterId: starter }, cookie);
  return { cookie, name };
}

// --- Duel vs bot
const p = await account('joey');
const decks = (await call('GET', '/api/decks', undefined, p.cookie)).data.decks;
check((await call('POST', '/api/duel', { mode: 'bot', botDeckId: decks[0].id }, '')).status === 401, 'bot duels need a login');
const start = await call('POST', '/api/duel', { mode: 'bot', botDeckId: decks[0].id }, p.cookie);
check(start.status === 200 && start.data.viewer !== null, 'a duel vs the bot starts');
let v = start.data;
const human = v.viewer;
check(v.players[1 - human].name === 'Bot' && v.players[human].name === p.name, 'you vs "Bot"');
let hiddenOk = true;
let steps = 0;
while (v.winner === null && steps < 3000) {
  steps++;
  if (v.players[1 - human].hand.some((c: any) => c.code !== 0)) hiddenOk = false;
  const d = v.decision;
  if (!d) throw new Error('no decision and no winner');
  if (v.turn > 80) { v = (await call('POST', `/api/duel/${v.id}/surrender`, {}, p.cookie)).data; break; }
  const picks = d.mode === 'menu'
    ? [d.choices[Math.floor(Math.random() * d.choices.length)].id]
    : d.choices.map((c: any) => c.id).slice(0, d.min);
  const r = await call('POST', `/api/duel/${v.id}/answer`, { decisionId: d.id, picks }, p.cookie);
  v = r.status === 200 ? r.data : r.data.view;
}
check(v.winner !== null, `the duel vs the bot finished (turn ${v.turn}, ${v.winner === human ? 'you won' : v.winner === 2 ? 'draw' : 'bot won'})`);
check(hiddenOk, "the bot's hand was always hidden from you");
const other = await account('yugi');
check((await call('GET', `/api/duel/${v.id}`, undefined, other.cookie)).status === 403, "someone else can't open your bot duel");

// --- Admin tools
const admin = await account('kaiba');
check((await call('GET', '/api/cards?q=telephone', undefined, admin.cookie)).status === 403, 'card search is admin-only');
check((await call('POST', '/api/duel', { mode: 'test' }, admin.cookie)).status === 403, 'test duels are admin-only');
execFileSync(process.execPath, ['--experimental-strip-types', 'scripts/admin.ts', 'make-admin', admin.name], { stdio: 'ignore' });
const search = await call('GET', '/api/cards?q=telephone', undefined, admin.cookie);
const tr = search.data.cards.find((c: number) => search.data.texts[c].name === 'Telephone Ring');
check(!!tr && search.data.texts[tr].customId === '1900000000' && tr === 1900000000, 'admin search finds custom cards');
const bewd = (await call('GET', '/api/cards?q=blue-eyes white dragon', undefined, admin.cookie)).data.cards[0];
const adminDecks = (await call('GET', '/api/decks', undefined, admin.cookie)).data.decks;
const base = adminDecks[0];
const unowned = await call('POST', '/api/decks', { name: 'Admin test', main: [...base.main.slice(0, 37), tr, tr, tr], extra: [] }, admin.cookie);
check(unowned.status === 200 && unowned.data.deck.problems.length === 0, 'admin decks can use any card');
const test = await call('POST', '/api/duel', { mode: 'test', deckA: unowned.data.deck.id, deckB: base.id, hand: [tr, bewd] }, admin.cookie);
check(test.status === 200, 'admin test duel starts');
const hand = test.data.players[0].hand.map((c: any) => c.code);
check(hand.includes(tr) && hand.includes(bewd) && hand.length === 5, 'chosen cards are in the starting hand (and it is filled to 5)');
check(test.data.viewer === null, 'test duel shows both sides');

// --- Static files
for (const f of ['/images.js', '/menus.js']) check((await fetch(BASE + f)).status === 200, `${f} is served`);
check((await fetch(BASE + '/custom-pics/NOPE.jpg')).status === 404, 'missing custom art = 404');

console.log(failures.length ? `\n${failures.length} FAILED` : '\nAll bot and admin checks passed.');
process.exit(failures.length ? 1 : 0);
