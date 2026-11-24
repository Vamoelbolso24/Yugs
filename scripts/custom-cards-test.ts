// Tests every custom card: bots play many duels with decks made of them, then we report which cards'
// effects were activated (and Evolution Summons), and every script error the engine reported.
// Usage:  node scripts/custom-cards-test.ts [duels]
import { CardDatabase } from '../src/engine/cardDb.ts';
import { loadContent } from '../src/content/content.ts';
import { customScriptReader } from '../src/content/customCards.ts';
import { setCustomScriptReader } from '../src/engine/scriptReader.ts';
import { DuelSession } from '../src/game/session.ts';
import { CARD_DB_FILES } from '../src/paths.ts';

const cards = new CardDatabase(CARD_DB_FILES);
const content = loadContent(cards);
setCustomScriptReader(customScriptReader());
const custom = content.custom.filter((c) => !cards.isExtraDeckCard(c.code) && !(Number(cards.get(c.code)?.data.type ?? 0) & 0x4000) && !cards.get(c.code)?.hidden);
console.log(`${content.custom.length} custom cards loaded.`);

// Two decks that together contain every custom card (2 copies each, or 1 if there are too many; filled up to 40 with Pot of Greed-free fillers).
const half = Math.ceil(custom.length / 2);
const filler = [cards.findByName('Celtic Guardian')!, cards.findByName('Mystical Elf')!];
const makeDeck = (list: typeof custom) => {
  const main = list.flatMap((c) => (list.length * 2 > 60 ? [c.code] : [c.code, c.code]));
  while (main.length < 40) main.push(filler[main.length % 2]!);
  return { main: main.slice(0, 60), extra: [] as number[] };
};
const decks = [makeDeck(custom.slice(0, half)), makeDeck(custom.slice(half))];

const count = Number(process.argv[2] ?? 40);
const activated = new Map<string, number>();
const evolved = new Map<string, number>();
const errors = new Map<string, number>();
for (let i = 1; i <= count; i++) {
  const pair: [typeof decks[0], typeof decks[0]] = i % 2 ? [decks[0]!, decks[1]!] : [decks[1]!, decks[0]!];
  const s = await DuelSession.start(cards, { decks: pair, names: ['A', 'B'], seed: i, bots: [0, 1] });
  for (const e of (s as any).duel.errors as string[]) errors.set(e, (errors.get(e) ?? 0) + 1);
  for (const line of s.view().log) {
    let m = line.match(/activates (.+?)( \(Chain|$)/);
    if (m) activated.set(m[1]!, (activated.get(m[1]!) ?? 0) + 1);
    m = line.match(/Special Summons (.+)$/);
    if (m) evolved.set(m[1]!, (evolved.get(m[1]!) ?? 0) + 1);
  }
}
const quiet: string[] = [];
for (const c of content.custom) {
  const info = cards.get(c.code)!;
  const isNormal = (Number(info.data.type) & 0x10) !== 0;
  const a = activated.get(c.name) ?? 0;
  const sp = evolved.get(c.name) ?? 0;
  if (!isNormal && a === 0) quiet.push(c.name);
  console.log(`${String(c.code)}  ${c.name.padEnd(16)} activated ${String(a).padStart(4)}   special summoned ${String(sp).padStart(3)}${isNormal ? '   (Normal Monster)' : ''}`);
}
console.log(quiet.length ? `\nNever activated: ${quiet.join(', ')} (may just need specific situations)` : '\nEvery effect card activated at least once.');
console.log(errors.size ? `\nSCRIPT ERRORS:\n${[...errors].map(([e, n]) => `  (${n}x) ${e}`).join('\n')}` : '\nNo script errors.');
