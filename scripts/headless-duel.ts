// Plays a full duel between two simple AIs and prints the duel log.
// Usage:  node scripts/headless-duel.ts [seed] [--quiet]
import { OcgMessageType, OcgProcessResult, type OcgMessage } from 'ocgcore-wasm';
import { CardDatabase } from '../src/engine/cardDb.ts';
import { LocalDuel } from '../src/engine/duel.ts';
import { describeMessage } from '../src/engine/describe.ts';
import { createRng } from '../src/engine/random.ts';
import { DECISION_TYPES, SimpleAi } from '../src/ai/simpleAi.ts';
import { KAIBA_DECK, YUGI_DECK, expandDeck } from '../src/decks/starters.ts';
import { CARD_DB_FILES, CARD_SCRIPTS_DIR } from '../src/paths.ts';

export interface HeadlessResult {
  seed: number;
  winner: number | null;
  turns: number;
  decisions: number;
  retries: number;
  errors: string[];
  lp: [number, number];
}

export async function runHeadlessDuel(cards: CardDatabase, seed: number, print: (line: string) => void): Promise<HeadlessResult> {
  const names: [string, string] = ['Yugi', 'Kaiba'];
  const duel = await LocalDuel.create(cards, CARD_SCRIPTS_DIR, { decks: [expandDeck(YUGI_DECK), expandDeck(KAIBA_DECK)], seed });
  const rng = createRng(seed ^ 0x5eed);
  const ais = [new SimpleAi(rng), new SimpleAi(rng)];
  const lp: [number, number] = [8000, 8000];
  let winner: number | null = null;
  let turns = 0;
  let decisions = 0;
  let retries = 0;
  let lastDecision: OcgMessage | null = null;

  for (let guard = 0; guard < 20000; guard++) {
    const { status, messages } = duel.advance();
    for (const msg of messages) {
      if (msg.type === OcgMessageType.NEW_TURN) {
        turns++;
        ais.forEach((ai) => ai.newTurn());
      }
      if (msg.type === OcgMessageType.LPUPDATE) lp[msg.player as 0 | 1] = msg.lp;
      if (msg.type === OcgMessageType.DAMAGE || msg.type === OcgMessageType.PAY_LPCOST) lp[msg.player as 0 | 1] -= msg.amount;
      if (msg.type === OcgMessageType.RECOVER) lp[msg.player as 0 | 1] += msg.amount;
      if (msg.type === OcgMessageType.WIN) winner = msg.player;
      const line = describeMessage(msg, cards, names);
      if (line) print(line);
      if (msg.type === OcgMessageType.DAMAGE || msg.type === OcgMessageType.RECOVER || msg.type === OcgMessageType.PAY_LPCOST) {
        print(`  LP  Yugi ${Math.max(0, lp[0])}  |  Kaiba ${Math.max(0, lp[1])}`);
      }
    }
    if (status === OcgProcessResult.END) break;

    let decision = [...messages].reverse().find((m) => DECISION_TYPES.has(m.type)) ?? null;
    if (messages.some((m) => m.type === OcgMessageType.RETRY)) {
      retries++;
      decision = lastDecision;
      if (retries > 200) throw new Error('Too many invalid answers; the AI is stuck.');
    }
    if (!decision) throw new Error(`Engine is waiting but sent no question. Last messages: ${messages.map((m) => m.type).join(', ')}`);
    lastDecision = decision;
    const player = 'player' in decision ? (decision.player as number) : 0;
    duel.respond(ais[player]!.choose(decision));
    decisions++;
    if (turns > 200) {
      print('\n(stopping: the duel went past 200 turns)');
      break;
    }
  }
  duel.destroy();
  return { seed, winner, turns, decisions, retries, errors: duel.errors, lp };
}

if (import.meta.main) {
  const args = process.argv.slice(2);
  const quiet = args.includes('--quiet');
  const seedArg = args.find((a) => /^\d+$/.test(a));
  const seed = seedArg ? Number(seedArg) : Math.floor(Math.random() * 2 ** 31);
  console.log('Loading card database...');
  const cards = new CardDatabase(CARD_DB_FILES);
  console.log(`Loaded ${cards.cards.size} cards. Duel seed: ${seed}`);
  const result = await runHeadlessDuel(cards, seed, quiet ? () => {} : (l) => console.log(l));
  console.log(`\nResult: ${result.winner === null ? 'no winner' : result.winner === 0 ? 'Yugi wins' : 'Kaiba wins'} after ${result.turns} turns, ${result.decisions} decisions (${result.retries} retried).`);
  if (result.errors.length) {
    console.log(`\nEngine/script warnings (${result.errors.length}):`);
    for (const e of [...new Set(result.errors)].slice(0, 20)) console.log('  ' + e);
  }
}
