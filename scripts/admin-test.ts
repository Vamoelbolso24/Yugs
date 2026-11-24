// Tests the admin tools (card search, test duels) over HTTP against a running server.
// The admin account is made with the admin script first, so pass the same database:
//   node scripts/admin-test.ts [baseUrl]   (needs YUGS_DB to point at the server's database)
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

const other = await account('yugi');

// --- Admin tools
const admin = await account('kaiba');
check((await call('GET', '/api/cards?q=telephone', undefined, admin.cookie)).status === 403, 'card search is admin-only');
check((await call('POST', '/api/duel', { mode: 'test' }, admin.cookie)).status === 403, 'test duels are admin-only');
execFileSync(process.execPath, ['scripts/admin.ts', 'make-admin', admin.name], { stdio: 'ignore' });
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
check((await call('GET', `/api/duel/${test.data.id}`, undefined, other.cookie)).status === 403, "someone else can't open your test duel");
check((await call('POST', '/api/duel', {}, other.cookie)).status === 404, 'practice duels are gone');

// --- Static files
for (const f of ['/images.js', '/menus.js']) check((await fetch(BASE + f)).status === 200, `${f} is served`);
check((await fetch(BASE + '/custom-pics/NOPE.jpg')).status === 404, 'missing custom art = 404');

console.log(failures.length ? `\n${failures.length} FAILED` : '\nAll admin checks passed.');
process.exit(failures.length ? 1 : 0);
