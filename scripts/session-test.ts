// Plays duels through DuelSession exactly like the browser does (reading menus, sending choice ids),
// picking randomly. Checks that every question the page will show can be answered.
// Usage:  node scripts/session-test.ts [count]
import { CardDatabase } from '../src/engine/cardDb.ts';
import { DuelSession } from '../src/game/session.ts';
import { createRng } from '../src/engine/random.ts';
import { KAIBA_DECK, YUGI_DECK, expandDeck } from '../src/decks/starters.ts';
import { CARD_DB_FILES } from '../src/paths.ts';
import type { DecisionView } from '../src/game/types.ts';

const count = Number(process.argv[2] ?? 20);
const cards = new CardDatabase(CARD_DB_FILES);
const kinds = new Map<string, number>();
const prompts = new Set<string>();
let finished = 0;
let errors = 0;
let rejected = 0;
const extraSummons = new Map<string, number>();
const EXTRA_NAMES = ['Gaia the Dragon Champion', 'Dark Paladin', 'Blue-Eyes Ultimate Dragon', 'Number 39: Utopia', 'Link Spider'];
const started = Date.now();

function pickFor(d: DecisionView, rng: () => number): number[] | null {
  if (d.mode === 'menu') {
    // Prefer doing things over ending the turn, like a real player.
    const actions = d.choices.filter((c) => c.label !== 'End Turn' || rng() < 0.15);
    const pool = actions.length ? actions : d.choices;
    return [pool[Math.floor(rng() * pool.length)]!.id];
  }
  const n = d.min + Math.floor(rng() * (d.max - d.min + 1));
  const ids = d.choices.map((c) => c.id).sort(() => rng() - 0.5);
  return ids.slice(0, n);
}

for (let i = 1; i <= count; i++) {
  const rng = createRng(i * 7919);
  try {
    const s = await DuelSession.start(cards, { decks: [expandDeck(YUGI_DECK), expandDeck(KAIBA_DECK)], names: ['Yugi', 'Kaiba'], seed: i });
    let steps = 0;
    for (;;) {
      const v = s.view();
      JSON.stringify(v); // must be plain JSON for the browser
      if (v.winner !== null) {
        finished++;
        for (const line of v.log) for (const n of EXTRA_NAMES) if (line.includes(`Special Summons ${n}`)) extraSummons.set(n, (extraSummons.get(n) ?? 0) + 1);
        break;
      }
      if (!v.decision) throw new Error('No winner and no question.');
      if (v.turn > 150 || steps++ > 6000) { s.surrender(v.turnPlayer); continue; }
      kinds.set(v.decision.kind, (kinds.get(v.decision.kind) ?? 0) + 1);
      prompts.add(v.decision.prompt.split('\n')[0]!);
      if (v.decision.error) rejected++;
      const result = s.answer(v.decision.id, pickFor(v.decision, rng));
      if (!result.ok) throw new Error(`Answer refused: ${result.error}`);
    }
  } catch (e) {
    errors++;
    console.log(`Duel ${i} FAILED: ${(e as Error).stack}`);
  }
}
console.log(`${count} duels in ${((Date.now() - started) / 1000).toFixed(1)}s: ${finished} finished, ${errors} failed, ${rejected} answers re-asked by the engine`);
console.log('Questions seen:', Object.fromEntries(kinds));
console.log('Extra Deck summons:', Object.fromEntries(extraSummons));
console.log('Prompts:', [...prompts].slice(0, 40).join(' | '));
process.exit(errors ? 1 : 0);
