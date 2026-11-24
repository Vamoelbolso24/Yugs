// Shows a real card's effect script, so you can copy its pattern for a custom card.
// Usage (PowerShell, in the Yugs folder):
//   npm run find-card -- "Negate Attack"        (exact or partial name)
//   npm run find-card -- "Negate Attack" --all  (list every match without printing scripts)
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { CardDatabase } from '../src/engine/cardDb.ts';
import { CARD_DB_FILES, CARD_SCRIPTS_DIR } from '../src/paths.ts';

const query = process.argv.slice(2).filter((a) => !a.startsWith('--')).join(' ').trim().toLowerCase();
if (!query) {
  console.log('Usage: npm run find-card -- "card name"');
  process.exit(1);
}
const cards = new CardDatabase(CARD_DB_FILES);
const matches = [...cards.cards.entries()]
  .filter(([, c]) => c.data.alias === 0 && c.name.toLowerCase().includes(query))
  .sort((a, b) => (a[1].name.toLowerCase() === query ? -1 : 0) - (b[1].name.toLowerCase() === query ? -1 : 0) || a[1].name.localeCompare(b[1].name));
if (!matches.length) {
  console.log(`No card name contains "${query}".`);
  process.exit(1);
}
if (process.argv.includes('--all') || (matches.length > 1 && matches[0]![1].name.toLowerCase() !== query)) {
  console.log(`${matches.length} cards match. Use the exact name to see one script:`);
  for (const [code, c] of matches.slice(0, 40)) console.log(`  ${c.name}  (${code})`);
  process.exit(0);
}
const [code, card] = matches[0]!;
const file = ['official', 'pre-release', 'pre-errata', 'unofficial'].map((d) => path.join(CARD_SCRIPTS_DIR, d, `c${code}.lua`)).find(existsSync);
console.log(`${card.name}  (passcode ${code})\n\n${card.desc}\n`);
if (!file) {
  console.log('This card has no script (Normal Monsters don\'t need one).');
} else {
  console.log(`Script file: ${file}\n${'-'.repeat(70)}\n${readFileSync(file, 'utf-8')}`);
}
