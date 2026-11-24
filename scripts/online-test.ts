// End-to-end test of online duels against a running server (npm start).
// Two simulated players create/join a room, listen to live updates, and answer randomly.
// It also checks that no player ever receives the other player's hidden cards.
// Usage:  node scripts/online-test.ts [duels] [baseUrl]
import { createRng } from '../src/engine/random.ts';
import type { RoomState } from '../src/server/rooms.ts';
import type { GameView } from '../src/game/types.ts';
import { testSignup } from './test-signup.ts';

const duels = Number(process.argv[2] ?? 3);
const BASE = process.argv[3] ?? 'http://localhost:3000';

async function post(path: string, body: unknown, cookie = ''): Promise<{ status: number; data: any; cookie: string }> {
  const res = await fetch(BASE + path, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: cookie }, body: JSON.stringify(body) });
  const set = res.headers.get('set-cookie') ?? '';
  return { status: res.status, data: await res.json(), cookie: set.split(';')[0] ?? '' };
}

/** Creates a fresh test account and returns its login cookie. */
async function account(prefix: string): Promise<string> {
  const name = `${prefix}${Math.random().toString(36).slice(2, 8)}`;
  const r = await testSignup(BASE, name, 'testpassword');
  if (r.status !== 200) throw new Error('register failed: ' + JSON.stringify(r.data));
  const starter = ['yugi', 'kaiba', 'joey'][Math.floor(Math.random() * 3)];
  const chosen = await post('/api/starters/choose', { starterId: starter }, r.cookie);
  if (chosen.status !== 200) throw new Error('choosing a starter failed: ' + JSON.stringify(chosen.data));
  return r.cookie;
}

/** Opens the live-update stream and calls onState for every update. */
async function listen(roomId: string, token: string, onState: (s: RoomState) => void, signal: AbortSignal): Promise<void> {
  const res = await fetch(`${BASE}/api/room/${roomId}/events?token=${encodeURIComponent(token)}`, { signal });
  const reader = res.body!.pipeThrough(new TextDecoderStream()).getReader();
  let buffer = '';
  (async () => {
    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (done) return;
        buffer += value;
        let idx;
        while ((idx = buffer.indexOf('\n\n')) >= 0) {
          const chunk = buffer.slice(0, idx);
          buffer = buffer.slice(idx + 2);
          const line = chunk.split('\n').find((l) => l.startsWith('data: '));
          if (line) onState(JSON.parse(line.slice(6)));
        }
      }
    } catch { /* aborted */ }
  })();
}

const problems: string[] = [];
function checkHidden(state: RoomState, label: string): void {
  const v = state.view as GameView | null;
  if (!v || v.viewer === null) return;
  const opp = v.players[1 - v.viewer]!;
  if (opp.hand.some((c) => c.code !== 0 && c.faceDown)) problems.push(`${label}: opponent hand leaked`);
  for (const c of [...opp.monsters, ...opp.spells]) if (c && c.faceDown && c.code !== 0) problems.push(`${label}: opponent face-down card leaked`);
  if (opp.extra.length) problems.push(`${label}: opponent Extra Deck leaked`);
  if (v.decision && v.decision.player !== v.viewer) problems.push(`${label}: received the opponent's question`);
}

async function playOne(n: number): Promise<string> {
  const rng = createRng(n * 104729);
  const [alice, bob, eve] = [await account('alice'), await account('bob'), await account('eve')];
  if ((await post('/api/room', {})).status !== 401) problems.push('created a room without logging in');
  const host = (await post('/api/room', {}, alice)).data;
  const guestJoin = await post(`/api/room/${host.roomId}/join`, {}, bob);
  if (guestJoin.status !== 200) throw new Error('join failed: ' + JSON.stringify(guestJoin.data));
  const third = await post(`/api/room/${host.roomId}/join`, {}, eve);
  if (third.status !== 409) problems.push('a third player could join');
  const again = await post(`/api/room/${host.roomId}/join`, {}, alice);
  if (again.data.token !== host.token) problems.push('the room creator did not get their seat back');
  const tokens = [host.token, guestJoin.data.token];
  const latest: (RoomState | null)[] = [null, null];
  let updates = 0;
  const abort = new AbortController();
  await Promise.all([0, 1].map((seat) => listen(host.roomId, tokens[seat], (s) => {
    updates++;
    checkHidden(s, `duel ${n} seat ${seat}`);
    latest[seat] = s;
  }, abort.signal)));

  const wrong = await post(`/api/room/${host.roomId}/answer`, { token: 'nope', decisionId: 1, picks: [0] });
  if (wrong.status !== 403) problems.push('answer with a bad token was accepted');

  const started = Date.now();
  let answered = 0;
  for (;;) {
    await new Promise((r) => setTimeout(r, 2));
    if (Date.now() - started > 120_000) throw new Error('timed out');
    const states = latest;
    if (states.some((s) => s?.status === 'finished')) break;
    for (const seat of [0, 1]) {
      const s = states[seat];
      const d = s?.view?.decision;
      if (!s || !d) continue;
      if (s.view!.turn > 120) {
        await post(`/api/room/${host.roomId}/surrender`, { token: tokens[seat] });
        break;
      }
      let picks: number[];
      if (d.mode === 'menu') {
        const pool = d.choices.filter((c) => c.label !== 'End Turn' || rng() < 0.15);
        picks = [(pool.length ? pool : d.choices)[Math.floor(rng() * (pool.length || d.choices.length))]!.id];
      } else {
        const k = d.min + Math.floor(rng() * (d.max - d.min + 1));
        picks = d.choices.map((c) => c.id).sort(() => rng() - 0.5).slice(0, k);
      }
      latest[seat] = { ...s, view: { ...s.view!, decision: null } }; // wait for the next update
      const r = await post(`/api/room/${host.roomId}/answer`, { token: tokens[seat], decisionId: d.id, picks });
      if (r.status !== 200 && !/already answered/.test(r.data.error)) problems.push(`answer refused: ${r.data.error}`);
      answered++;
    }
  }
  abort.abort();
  const final = latest[0]!;
  const v = final.view!;
  return `duel ${n}: ${v.winner === 2 ? 'draw' : `${v.players[v.winner!]!.name} won`} on turn ${v.turn}, ${answered} answers, ${updates} live updates`;
}

for (let i = 1; i <= duels; i++) {
  try {
    console.log(await playOne(i));
  } catch (e) {
    problems.push(`duel ${i} failed: ${(e as Error).message}`);
  }
}
console.log(problems.length ? `\nPROBLEMS (${problems.length}):\n` + [...new Set(problems)].slice(0, 20).join('\n') : '\nAll checks passed: no hidden cards leaked, bad tokens refused, third player refused.');
process.exit(problems.length ? 1 : 0);
