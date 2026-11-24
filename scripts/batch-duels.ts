// Runs many AI-vs-AI duels to check that the engine never gets stuck.
// Usage:  node scripts/batch-duels.ts [count]
import { CardDatabase } from '../src/engine/cardDb.ts';
import { CARD_DB_FILES } from '../src/paths.ts';
import { runHeadlessDuel } from './headless-duel.ts';

const count = Number(process.argv[2] ?? 50);
const cards = new CardDatabase(CARD_DB_FILES);
const wins = [0, 0];
let unfinished = 0;
let failed = 0;
let totalTurns = 0;
const warnings = new Set<string>();
const started = Date.now();
for (let i = 1; i <= count; i++) {
  try {
    const r = await runHeadlessDuel(cards, i, () => {});
    if (r.winner === null) unfinished++;
    else wins[r.winner]!++;
    totalTurns += r.turns;
    r.errors.forEach((e) => warnings.add(e));
  } catch (e) {
    failed++;
    console.log(`Seed ${i} FAILED: ${(e as Error).message}`);
  }
}
const secs = (Date.now() - started) / 1000;
console.log(`${count} duels in ${secs.toFixed(1)}s (${((secs / count) * 1000).toFixed(0)} ms each)`);
console.log(`Yugi wins: ${wins[0]}  Kaiba wins: ${wins[1]}  unfinished: ${unfinished}  crashed: ${failed}`);
console.log(`Average length: ${(totalTurns / count).toFixed(1)} turns`);
if (warnings.size) {
  console.log(`Distinct engine/script warnings: ${warnings.size}`);
  [...warnings].slice(0, 15).forEach((w) => console.log('  ' + w.slice(0, 300)));
}
process.exit(failed ? 1 : 0);
