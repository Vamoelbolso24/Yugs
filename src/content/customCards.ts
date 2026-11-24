// Custom cards: read content/custom/cards.txt and register the cards in the card database.
// Every custom card has a number ID (like real cards' passcodes), starting at 1900000000.
//   effect script: content/custom/scripts/c<ID>.lua   (same naming as EDOPro)
//   artwork:       content/custom/pics/<ID>.jpg
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import type { CardDatabase } from '../engine/cardDb.ts';
import { ROOT } from '../paths.ts';

export const CUSTOM_DIR = path.join(ROOT, 'content', 'custom');
export const CUSTOM_SCRIPTS_DIR = path.join(CUSTOM_DIR, 'scripts');
export const CUSTOM_PICS_DIR = path.join(CUSTOM_DIR, 'pics');
/** Custom card IDs start here, far above every real card (real ones are below 1 billion). */
export const FIRST_CUSTOM_CODE = 1_900_000_000;
/** Hidden archetype of custom Spells/Traps that mention "Pokemon" in their text (SET_MENTIONS_POKEMON in custom_utility.lua). */
const MENTIONS_POKEMON = 0xf0a;
const LAST_CUSTOM_CODE = 4_294_967_295;
const ID_RE = /^\d{10}$/;

const TYPE: Record<string, number> = {
  MONSTER: 0x1, SPELL: 0x2, TRAP: 0x4, NORMAL: 0x10, EFFECT: 0x20, FUSION: 0x40, RITUAL: 0x80,
  SPIRIT: 0x200, UNION: 0x400, GEMINI: 0x800, TUNER: 0x1000, SYNCHRO: 0x2000, TOKEN: 0x4000,
  'QUICK-PLAY': 0x10000, QUICKPLAY: 0x10000, CONTINUOUS: 0x20000, EQUIP: 0x40000, FIELD: 0x80000,
  COUNTER: 0x100000, FLIP: 0x200000, TOON: 0x400000, XYZ: 0x800000, PENDULUM: 0x1000000, LINK: 0x4000000,
};
const ATTRIBUTES: Record<string, number> = { EARTH: 1, WATER: 2, FIRE: 4, WIND: 8, LIGHT: 16, DARK: 32, DIVINE: 64 };
const RACES = ['Warrior', 'Spellcaster', 'Fairy', 'Fiend', 'Zombie', 'Machine', 'Aqua', 'Pyro', 'Rock', 'Winged Beast',
  'Plant', 'Insect', 'Thunder', 'Dragon', 'Beast', 'Beast-Warrior', 'Dinosaur', 'Fish', 'Sea Serpent', 'Reptile',
  'Psychic', 'Divine-Beast', 'Creator God', 'Wyrm', 'Cyberse', 'Illusion'];
const ARROWS: Record<string, number> = {
  'BOTTOM-LEFT': 0x1, BOTTOM: 0x2, 'BOTTOM-RIGHT': 0x4, LEFT: 0x8, RIGHT: 0x20, 'TOP-LEFT': 0x40, TOP: 0x80, 'TOP-RIGHT': 0x100,
};

export interface CustomCard {
  id: string;
  code: number;
  name: string;
  hasScript: boolean;
}

const KNOWN_FIELDS = new Set(['name', 'card type', 'hidden', 'subtypes', 'attribute', 'type', 'level', 'rank', 'link rating', 'link arrows', 'scale', 'atk', 'def', 'text']);

/** "Prompt1", "prompt 1" -> "prompt 1"; other known fields lower-cased; anything else is not a field. */
function normalizeField(name: string): string | null {
  const key = name.trim().toLowerCase().replace(/\s+/g, ' ');
  const prompt = key.match(/^prompt ?(\d{1,2})$/);
  if (prompt) return `prompt ${Number(prompt[1])}`;
  return KNOWN_FIELDS.has(key) ? key : null;
}

/** Subtypes (like Pokemon) and their archetype numbers, from content/custom/subtypes.json. */
function loadSubtypes(problems: string[]): Map<string, number> {
  const file = path.join(CUSTOM_DIR, 'subtypes.json');
  const map = new Map<string, number>();
  if (!existsSync(file)) return map;
  try {
    for (const [name, value] of Object.entries(JSON.parse(readFileSync(file, 'utf-8')) as Record<string, string>)) {
      if (name.startsWith('_')) continue;
      const n = Number(value);
      if (!Number.isInteger(n) || n <= 0 || n > 0xffff) problems.push(`subtypes.json: "${name}" needs a number like "0xf01"`);
      else map.set(name.toLowerCase(), n);
    }
  } catch (e) {
    problems.push(`subtypes.json: could not read it (${(e as Error).message})`);
  }
  return map;
}

/**
 * Counter names: official ones from content/counter-names.json (e.g. 0x1 -> "Spell"), custom ones from
 * content/custom/counters.json (e.g. 0x1f01 -> "Harden"; these win if both name the same number).
 */
let counterNames: Map<number, string> | null = null;
export function counterName(type: number): string {
  if (!counterNames) {
    counterNames = new Map();
    for (const file of [path.join(ROOT, 'content', 'counter-names.json'), path.join(CUSTOM_DIR, 'counters.json')]) {
      try {
        if (!existsSync(file)) continue;
        for (const [k, v] of Object.entries(JSON.parse(readFileSync(file, 'utf-8')) as Record<string, string>)) {
          if (!k.startsWith('_')) counterNames.set(Number(k), v);
        }
      } catch { /* names are optional */ }
    }
  }
  return counterNames.get(type) ?? 'Counter';
}

/** Full name for menus: "Spell Counters", "C-Counters", or "Unnamed Counters" for a counter with no name. */
export function counterLabel(type: number): string {
  const n = counterName(type);
  if (n === 'Counter') return 'Unnamed Counters';
  return (n.length <= 2 ? n + '-Counters' : n + ' Counters');
}

/** Parses cards.txt into blocks of "Field: value" lines, one block per [ID]. */
function parseBlocks(text: string, problems: string[]): { id: string; line: number; fields: Map<string, string> }[] {
  const blocks: { id: string; line: number; fields: Map<string, string> }[] = [];
  let current: (typeof blocks)[number] | null = null;
  let lastKey = '';
  text.split(/\r?\n/).forEach((raw, i) => {
    const line = raw.trimEnd();
    if (!line.trim() || line.trim().startsWith('#')) return;
    const header = line.trim().match(/^\[(.+)\]$/);
    if (header) {
      const id = header[1]!.trim();
      const n = Number(id);
      if (!ID_RE.test(id) || n < FIRST_CUSTOM_CODE || n > LAST_CUSTOM_CODE) {
        problems.push(`cards.txt line ${i + 1}: "[${header[1]}]" - IDs are numbers from ${FIRST_CUSTOM_CODE} up (like [1900000000])`);
      }
      current = { id, line: i + 1, fields: new Map() };
      blocks.push(current);
      return;
    }
    if (!current) {
      problems.push(`cards.txt line ${i + 1}: text before the first [CARDID] line`);
      return;
    }
    const field = line.match(/^([A-Za-z][A-Za-z0-9 ]*?)\s*:\s*(.*)$/);
    const key = field ? normalizeField(field[1]!) : null;
    if (field && key && !/^\s/.test(raw)) {
      lastKey = key;
      current.fields.set(lastKey, field[2]!.trim());
    } else if (lastKey) {
      // Indented / continued lines belong to the previous field (for long effect texts).
      current.fields.set(lastKey, `${current.fields.get(lastKey)}\n${line.trim()}`);
    }
  });
  return blocks;
}

export function loadCustomCards(cards: CardDatabase, problems: string[]): CustomCard[] {
  const file = path.join(CUSTOM_DIR, 'cards.txt');
  if (!existsSync(file)) return [];
  const out: CustomCard[] = [];
  const seen = new Set<string>();
  const subtypeCodes = loadSubtypes(problems);

  for (const block of parseBlocks(readFileSync(file, 'utf-8'), problems)) {
    const where = `cards.txt [${block.id}] (line ${block.line})`;
    const f = (k: string) => block.fields.get(k);
    if (seen.has(block.id)) problems.push(`${where}: this ID is used twice`);
    seen.add(block.id);

    const code = Number(block.id);
    const existing = cards.get(code);
    if (existing && existing.customId === undefined) problems.push(`${where}: ${code} is already a real card's number`);

    const name = f('name');
    if (!name) problems.push(`${where}: missing "Name:"`);
    const kind = (f('card type') ?? '').toUpperCase().replace(/,/g, ' ');
    let type = 0;
    for (const word of kind.split(/\s+/).filter(Boolean)) {
      if (TYPE[word] === undefined) problems.push(`${where}: unknown word "${word}" in Card type`);
      else type |= TYPE[word]!;
    }
    if (!(type & (TYPE.MONSTER! | TYPE.SPELL! | TYPE.TRAP!))) problems.push(`${where}: "Card type:" must say Monster, Spell or Trap (for example "Effect Monster" or "Quick-Play Spell")`);
    const isMonster = (type & TYPE.MONSTER!) !== 0;
    if (isMonster && !(type & (TYPE.EFFECT! | TYPE.NORMAL!))) type |= TYPE.EFFECT!;
    if (isMonster && type & TYPE.NORMAL! && type & TYPE.EFFECT!) type &= ~TYPE.NORMAL!;

    let attribute = 0;
    let race = 0n;
    let level = 0;
    let atk = 0;
    let def = 0;
    let scale = 0;
    let linkMarkers = 0;
    const num = (k: string, label: string) => {
      const v = f(k);
      if (v === undefined) return 0;
      if (v === '?') return -2;
      const n = Number(v);
      if (!Number.isInteger(n) || n < 0) problems.push(`${where}: "${label}: ${v}" is not a whole number`);
      return Number.isInteger(n) ? n : 0;
    };
    if (isMonster) {
      const attr = (f('attribute') ?? '').toUpperCase();
      attribute = ATTRIBUTES[attr] ?? 0;
      if (!attribute) problems.push(`${where}: "Attribute:" must be one of ${Object.keys(ATTRIBUTES).join(', ')}`);
      const r = RACES.findIndex((x) => x.toLowerCase() === (f('type') ?? '').toLowerCase());
      if (r < 0) problems.push(`${where}: "Type:" must be one of ${RACES.join(', ')}`);
      else race = 1n << BigInt(r);
      atk = num('atk', 'ATK');
      if (type & TYPE.LINK!) {
        level = num('link rating', 'Link Rating');
        for (const a of (f('link arrows') ?? '').toUpperCase().split(/[,\s]+/).filter(Boolean)) {
          if (ARROWS[a] === undefined) problems.push(`${where}: unknown Link Arrow "${a}" (use ${Object.keys(ARROWS).join(', ')})`);
          else linkMarkers |= ARROWS[a]!;
        }
        if (!level) problems.push(`${where}: Link Monsters need "Link Rating:"`);
      } else {
        level = type & TYPE.XYZ! ? num('rank', 'Rank') : num('level', 'Level');
        def = num('def', 'DEF');
        if (!level) problems.push(`${where}: missing "${type & TYPE.XYZ! ? 'Rank' : 'Level'}:"`);
      }
      if (type & TYPE.PENDULUM!) scale = num('scale', 'Scale');
    }

    const subtypes: string[] = [];
    const setcodes: number[] = [];
    const REAL_TYPES: Record<string, number> = { gemini: TYPE.GEMINI!, tuner: TYPE.TUNER!, toon: TYPE.TOON!, spirit: TYPE.SPIRIT!, union: TYPE.UNION!, flip: TYPE.FLIP! };
    for (const sub of (f('subtypes') ?? '').split(/[,/]/).map((x) => x.trim()).filter(Boolean)) {
      if (REAL_TYPES[sub.toLowerCase()] !== undefined) {
        type |= REAL_TYPES[sub.toLowerCase()]!;   // real card types written in Subtypes: just add them to the card type
        continue;
      }
      const sc = subtypeCodes.get(sub.toLowerCase());
      if (sc === undefined) problems.push(`${where}: unknown subtype "${sub}" (add it to content/custom/subtypes.json)`);
      else {
        setcodes.push(sc);
        subtypes.push(sub);
      }
    }
    // Spells/Traps whose text says "Pokemon" get a hidden archetype number, so scripts can find
    // "a Spell that states Pokemon in its text" (Lua can't read card text): IsSetCard(SET_MENTIONS_POKEMON).
    if (!isMonster && /pok[eé]mon/i.test(f('text') ?? '') && setcodes.length < 4) setcodes.push(MENTIONS_POKEMON);
    const strings = Array.from({ length: 16 }, (_, i) => f(`prompt ${i + 1}`) ?? '');
    const scriptFile = path.join(CUSTOM_SCRIPTS_DIR, `c${code}.lua`);
    const hasScript = existsSync(scriptFile);
    const needsScript = !(isMonster && type & TYPE.NORMAL!) && !/^(yes|true)$/i.test(f('hidden') ?? '');
    if (needsScript && !hasScript) console.warn(`  Note: ${block.id} (${name}) has no script yet (content/custom/scripts/c${code}.lua), so its effect does nothing.`);
    const pic = ['jpg', 'jpeg', 'png', 'webp'].map((ext) => `${block.id}.${ext}`).find((n) => existsSync(path.join(CUSTOM_PICS_DIR, n)));

    if (name && cards.findByName(name) !== null && cards.get(cards.findByName(name)!)?.customId !== block.id) {
      problems.push(`${where}: a card named "${name}" already exists`);
    }
    cards.addCard(code, {
      name: name ?? block.id,
      desc: f('text') ?? '',
      strings,
      customId: block.id,
      subtypes,
      // "Hidden: yes" = only used by scripts (like a name a card turns into): not in collections or Decks.
      hidden: /^(yes|true)$/i.test(f('hidden') ?? '') || undefined,
      image: pic ? `/custom-pics/${encodeURIComponent(pic)}` : undefined,
      data: {
        code, alias: 0, setcodes, type, level, attribute, race, attack: atk, defense: def,
        lscale: scale, rscale: scale, link_marker: linkMarkers,
      },
    });
    out.push({ id: block.id, code, name: name ?? block.id, hasScript });
  }

  return out;
}

/**
 * Gives the engine a custom card's script: c1900000000.lua -> content/custom/scripts/c1900000000.lua.
 * The file is read fresh every time a duel starts, so script edits apply to the next duel
 * without restarting the server.
 */
export function customScriptReader(): (name: string) => string | null {
  return (name: string) => {
    if (path.basename(name) === 'custom_utility.lua') {
      const util = path.join(CUSTOM_SCRIPTS_DIR, 'custom_utility.lua');
      return existsSync(util) ? readFileSync(util, 'utf-8') : null;
    }
    const m = path.basename(name).match(/^c(\d+)\.lua$/);
    if (!m || Number(m[1]) < FIRST_CUSTOM_CODE) return null;
    const file = path.join(CUSTOM_SCRIPTS_DIR, `c${m[1]}.lua`);
    return existsSync(file) ? readFileSync(file, 'utf-8') : null;
  };
}
