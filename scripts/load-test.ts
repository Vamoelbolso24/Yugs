// Load test: many online duels at the same time against a running TEST server, to see what it can handle.
//   Start the server with  YUGS_TEST_CODES=1 YUGS_CONFIG=none  then:
//   node scripts/load-test.ts <duels at once> <think time ms> [baseUrl] [server process id] [seconds to run, default 60]
// Every player answers a random legal choice after "think time". With a process id it also reports the
// server's CPU time and memory (Linux only).
import { readFileSync } from 'node:fs';
import { testSignup } from './test-signup.ts';
import type { RoomState } from '../src/server/rooms.ts';

const COUNT = Number(process.argv[2] ?? 10);
const THINK = Number(process.argv[3] ?? 500);
const BASE = process.argv[4] ?? 'http://localhost:3000';
const PID = process.argv[5];
const SECONDS = Number(process.argv[6] ?? 60);
let deadline = 0;
let measureFrom = 0;
let cpuFrom = 0;
const TICK = 100; // Linux clock ticks per second

async function post(path: string, body: unknown, cookie = '') {
  const res = await fetch(BASE + path, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: cookie }, body: JSON.stringify(body) });
  return { status: res.status, data: (await res.json()) as any };
}
async function account(prefix: string): Promise<string> {
  const name = `${prefix}${Math.random().toString(36).slice(2, 8)}`;
  const r = await testSignup(BASE, name, 'testpassword');
  await fetch(BASE + '/api/starters/choose', { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: r.cookie }, body: JSON.stringify({ starterId: ['yugi', 'kaiba', 'joey'][Math.floor(Math.random() * 3)] }) });
  return r.cookie;
}
function listen(roomId: string, token: string, onState: (s: RoomState) => void, signal: AbortSignal): Promise<void> {
  return fetch(`${BASE}/api/room/${roomId}/events?token=${encodeURIComponent(token)}`, { signal }).then((res) => {
    const reader = res.body!.pipeThrough(new TextDecoderStream()).getReader();
    let buffer = '';
    (async () => {
      try {
        for (;;) {
          const { value, done } = await reader.read();
          if (done) return;
          buffer += value;
          let i;
          while ((i = buffer.indexOf('\n\n')) >= 0) {
            const line = buffer.slice(0, i).split('\n').find((l) => l.startsWith('data: '));
            buffer = buffer.slice(i + 2);
            if (line) onState(JSON.parse(line.slice(6)));
          }
        }
      } catch { /* aborted */ }
    })();
  });
}
const cpu = () => {
  if (!PID) return 0;
  const f = readFileSync(`/proc/${PID}/stat`, 'utf8').split(') ')[1]!.split(' ');
  return (Number(f[11]) + Number(f[12])) / TICK;
};
const rssMb = () => (PID ? Math.round(Number(/VmRSS:\s+(\d+)/.exec(readFileSync(`/proc/${PID}/status`, 'utf8'))![1]) / 1024) : 0);

const latencies: number[] = [];
let answers = 0;
let peakRss = 0;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function duel(a: string, b: string): Promise<void> {
  const host = (await post('/api/room', {}, a)).data;
  const guest = (await post(`/api/room/${host.roomId}/join`, {}, b)).data;
  const tokens = [host.token, guest.token];
  const latest: (RoomState | null)[] = [null, null];
  const abort = new AbortController();
  await Promise.all([0, 1].map((seat) => listen(host.roomId, tokens[seat]!, (s) => { latest[seat] = s; }, abort.signal)));
  const started = Date.now();
  for (;;) {
    await sleep(20);
    if (latest.some((s) => s?.status === 'finished') || Date.now() > deadline) break;
    for (const seat of [0, 1]) {
      const s = latest[seat];
      const d = s?.view?.decision;
      if (!s || !d) continue;
      latest[seat] = { ...s, view: { ...s.view!, decision: null } };
      if (s.view!.turn > 60) { await post(`/api/room/${host.roomId}/surrender`, { token: tokens[seat] }); break; }
      await sleep(THINK * (0.5 + Math.random()));
      const pool = d.choices.filter((c) => c.label !== 'End Turn');
      const from = pool.length && Math.random() < 0.8 ? pool : d.choices;
      const picks = d.mode === 'menu'
        ? [from[Math.floor(Math.random() * from.length)]!.id]
        : d.choices.map((c) => c.id).sort(() => Math.random() - 0.5).slice(0, d.min);
      const t0 = performance.now();
      await post(`/api/room/${host.roomId}/answer`, { token: tokens[seat], decisionId: d.id, picks });
      if (measureFrom) { latencies.push(performance.now() - t0); answers++; }
    }
  }
  abort.abort();
}

const timer = setInterval(() => { peakRss = Math.max(peakRss, rssMb()); }, 500);
// Measure once every duel has started (sign-ups are slow on purpose: password hashing).
let duelsPlayed = 0;
async function keepDueling(a: string, b: string): Promise<void> {
  while (Date.now() < deadline) {
    try { await duel(a, b); duelsPlayed++; } catch (e) { console.log('duel failed:', (e as Error).message); }
  }
}
const players: [string, string][] = [];
for (let i = 0; i < COUNT; i++) players.push([await account('la'), await account('lb')]);
console.log(`${COUNT * 2} test players signed up; dueling for ${SECONDS} s...`);
deadline = Date.now() + SECONDS * 1000;
const all = players.map(([a, b], i) => sleep(i * 100).then(() => keepDueling(a, b)));
setTimeout(() => { measureFrom = Date.now(); cpuFrom = cpu(); }, COUNT * 100 + 5000);
await Promise.all(all);
clearInterval(timer);
const secs = (Date.now() - measureFrom) / 1000;
const used = cpu() - cpuFrom;
latencies.sort((x, y) => x - y);
const pct = (p: number) => Math.round(latencies[Math.min(latencies.length - 1, Math.floor(latencies.length * p))] ?? 0);
console.log(`${COUNT} duels at once, think time ~${THINK} ms: ${answers} answers in ${secs.toFixed(0)} s (${(answers / secs).toFixed(1)} per second), ${duelsPlayed} duels finished`);
console.log(`answer time: median ${pct(0.5)} ms, 95% under ${pct(0.95)} ms, slowest ${pct(1)} ms`);
if (PID) console.log(`server CPU: ${used.toFixed(1)} s busy = ${Math.round((used / secs) * 100)}% of one core, ${((used * 1000) / Math.max(1, answers)).toFixed(1)} ms per answer; memory peak ${peakRss} MB`);
