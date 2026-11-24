import { testSignup } from './test-signup.ts';
import { ECONOMY } from '../src/config.ts';
const FREE = ECONOMY.freeStarterPacks;
// Tests the new-player journey over HTTP against a running server (npm start):
// starter deck -> free packs -> collection -> deck editing rules -> online duel with own decks.
// Usage:  node scripts/collection-test.ts [baseUrl]
const BASE = process.argv[2] ?? 'http://localhost:3000';
const failures: string[] = [];
const check = (ok: boolean, label: string) => { console.log(`${ok ? 'OK  ' : 'FAIL'} ${label}`); if (!ok) failures.push(label); };

async function call(method: string, path: string, body: unknown, cookie: string) {
  const res = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', Cookie: cookie }, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: res.status, data: await res.json() as any, setCookie: res.headers.get('set-cookie') ?? '' };
}
async function newAccount(): Promise<string> {
  const r = await testSignup(BASE, `p${Math.random().toString(36).slice(2, 9)}`, 'testpassword');
  return r.setCookie.split(';')[0]!;
}

const me = await newAccount();
check((await call('GET', '/api/me', undefined, '')).status === 401, 'player data needs a login');
let profile = (await call('GET', '/api/me', undefined, me)).data.profile;
check(profile.starterChosen === null && profile.freePacks === 0, 'new account: no starter, no free packs yet');
check((await call('POST', '/api/room', {}, me)).status === 409, "can't create an online duel before choosing a starter");
check((await call('POST', '/api/packs/legend-pack/open-free', {}, me)).status === 409, "can't open packs before choosing a starter");

const starters = (await call('GET', '/api/starters', undefined, me)).data;
check(starters.starters.length === 3, '3 starter decks offered');
const joey = starters.starters.find((s: any) => s.id === 'joey');
check((await call('POST', '/api/starters/choose', { starterId: 'nope' }, me)).status === 409, 'unknown starter refused');
const chose = await call('POST', '/api/starters/choose', { starterId: 'joey' }, me);
check(chose.status === 200 && chose.data.profile.freePacks === FREE, `choosing Joey gives ${FREE} free packs`);
check((await call('POST', '/api/starters/choose', { starterId: 'yugi' }, me)).status === 409, "can't choose a second starter");

let collection = (await call('GET', '/api/collection', undefined, me)).data.cards as { code: number; copies: number }[];
const total = () => collection.reduce((t, c) => t + c.copies, 0);
check(total() === joey.main.length + joey.extra.length, `collection holds the starter deck (${total()} cards)`);
let decks = (await call('GET', '/api/decks', undefined, me)).data.decks;
check(decks.length === 1 && decks[0].active && decks[0].problems.length === 0, 'starter deck is saved, valid and active');

const packs = (await call('GET', '/api/packs', undefined, me)).data.packs;
check(packs.length === 3 && packs.every((p: any) => p.size === 9), '3 packs of 9 cards in the shop');
let pulledTotal = 0;
let maxedTotal = 0;
for (let i = 0; i < FREE; i++) {
  const r = await call('POST', `/api/packs/${packs[i % packs.length].id}/open-free`, {}, me);
  check(r.status === 200 && r.data.cards.length === 9 && r.data.freePacksLeft === FREE - 1 - i, `free pack ${i + 1} gives 9 cards`);
  pulledTotal += r.data.cards.length;
  maxedTotal += r.data.cards.filter((c: any) => c.maxed).length;
  console.log('      ' + r.data.cards.map((c: any) => `${r.data.cardTexts[c.code].name}${c.rarity !== 'common' ? ` (${c.rarity})` : ''}${c.isNew ? ' NEW' : ''}${c.maxed ? ' (already 3)' : ''}`).join(', '));
}
check((await call('POST', `/api/packs/${packs[0].id}/open-free`, {}, me)).status === 409, 'one more free pack is refused');
collection = (await call('GET', '/api/collection', undefined, me)).data.cards;
check(total() === joey.main.length + joey.extra.length + pulledTotal - maxedTotal, 'every pulled card was added (except copies past 3)');
check(collection.every((c) => c.copies >= 1 && c.copies <= 3), 'no card above 3 copies');

// Deck rules
const starterDeck = decks[0];
const short = await call('POST', '/api/decks', { name: 'Too small', main: starterDeck.main.slice(0, 39), extra: [] }, me);
check(short.status === 200 && short.data.deck.problems.some((p: string) => /at least 40/.test(p)), 'a 39-card deck is saved as unfinished');
check((await call('POST', `/api/decks/${short.data.deck.id}/activate`, {}, me)).status === 409, "an unfinished deck can't be made active");
const notOwned = 89631139; // Blue-Eyes White Dragon (Joey doesn't start with it)
const owned = collection.find((c) => c.code === notOwned)?.copies ?? 0;
const cheat = await call('POST', '/api/decks', { name: 'Cheater', main: [...starterDeck.main.slice(0, 37), notOwned, notOwned, notOwned], extra: [] }, me);
check(cheat.data.deck.problems.some((p: string) => /you own/.test(p)) === owned < 3, 'using cards you do not own is flagged');
const four = await call('POST', '/api/decks', { name: 'Four', main: [...starterDeck.main.slice(0, 36), ...Array(4).fill(starterDeck.main[0])], extra: [] }, me);
check(four.data.deck.problems.some((p: string) => /max 3/.test(p)), 'more than 3 copies is flagged');
const wrongZone = await call('POST', '/api/decks', { name: 'Wrong zone', main: [...starterDeck.main.slice(0, 39), starterDeck.extra[0]], extra: [] }, me);
check(wrongZone.data.deck.problems.some((p: string) => /Extra Deck/.test(p)), 'Extra Deck monsters in the Main Deck are flagged');
const fixed = await call('PUT', `/api/decks/${short.data.deck.id}`, { name: 'My Joey', main: starterDeck.main, extra: starterDeck.extra }, me);
check(fixed.status === 200 && fixed.data.deck.problems.length === 0, 'fixing a deck makes it valid');
check((await call('POST', `/api/decks/${short.data.deck.id}/activate`, {}, me)).status === 200, 'a valid deck can be made active');
check((await call('DELETE', `/api/decks/${short.data.deck.id}`, undefined, me)).status === 409, "the active deck can't be deleted");
check((await call('DELETE', `/api/decks/${cheat.data.deck.id}`, undefined, me)).status === 200, 'other decks can be deleted');
const other = await newAccount();
check((await call('PUT', `/api/decks/${short.data.deck.id}`, { name: 'Stolen', main: [], extra: [] }, other)).status === 400, "you can't edit someone else's deck");

// Online duel with own decks
await call('POST', '/api/starters/choose', { starterId: 'kaiba' }, other);
const room = await call('POST', '/api/room', {}, me);
const join = await call('POST', `/api/room/${room.data.roomId}/join`, {}, other);
check(room.status === 200 && join.status === 200, 'two players with their own decks can start an online duel');
await new Promise((r) => setTimeout(r, 500));
const state = (await fetch(`${BASE}/api/room/${room.data.roomId}/state?token=${room.data.token}`).then((r) => r.json())) as any;
const mine = state.view.players[state.view.viewer];
check(mine.deckCount + mine.hand.length >= 40 && mine.extraCount === joey.extra.length, `the duel uses the player's own deck (Joey: ${joey.extra.length} Extra Deck cards)`);

console.log(failures.length ? `\n${failures.length} FAILED` : '\nAll collection and deck checks passed.');
process.exit(failures.length ? 1 : 0);
