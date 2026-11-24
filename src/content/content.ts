// Loads the owner-editable game content (starter decks and packs) from the content/ folder.
// Cards are written by name in those files; here they are turned into passcodes and checked.
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import type { CardDatabase } from '../engine/cardDb.ts';
import type { Rng } from '../engine/random.ts';
import { ROOT } from '../paths.ts';
import { loadCustomCards, type CustomCard } from './customCards.ts';

export const RARITIES = ['common', 'rare', 'super', 'ultra', 'secret'] as const;
export type Rarity = (typeof RARITIES)[number];

export interface StarterDeck {
  id: string;
  name: string;
  description: string;
  main: number[];
  extra: number[];
}

export interface PackSlot {
  count: number;
  /** Percent chance of each rarity for every card in this slot (adds up to 100). */
  chances: Partial<Record<Rarity, number>>;
}

export interface Pack {
  id: string;
  name: string;
  description: string;
  active: boolean;
  slots: PackSlot[];
  cards: Partial<Record<Rarity, number[]>>;
  /** Cards per pack (sum of slot counts). */
  size: number;
  /** Pack artwork file name inside content/packs/art (made with the Pack Maker), if any. */
  art?: string;
  /** False when some rarity the pack can give has no cards yet (a draft): it can't be put in the shop. */
  ready: boolean;
  /** Why it is not ready. */
  missing: string[];
}

export interface PulledCard {
  code: number;
  rarity: Rarity;
}

export const BANLIST_LISTS = ['forbidden', 'limited', 'semiLimited'] as const;
export type BanlistList = (typeof BANLIST_LISTS)[number];
/** Max copies in a deck for each banlist list. */
export const BANLIST_LIMIT: Record<BanlistList, number> = { forbidden: 0, limited: 1, semiLimited: 2 };
export type Banlist = Record<BanlistList, number[]>;

export interface GameContent {
  starters: StarterDeck[];
  packs: Pack[];
  custom: CustomCard[];
  /** Card passcodes (the original artwork's code) per list. */
  banlist: Banlist;
}

/** How many copies of a card a deck may have under the banlist (3 when it isn't on it). */
export function banlistLimit(banlist: Banlist, baseCode: number): number {
  for (const list of BANLIST_LISTS) if (banlist[list].includes(baseCode)) return BANLIST_LIMIT[list];
  return 3;
}

export const CONTENT_DIR = path.join(ROOT, 'content');
export const PACKS_DIR = path.join(CONTENT_DIR, 'packs');
export const PACK_ART_DIR = path.join(PACKS_DIR, 'art');

/** The normal pack: 9 cards, each one rolls its rarity with these odds. (The Pack Maker uses these for every pack.) */
export const DEFAULT_SLOTS: PackSlot[] = [{ count: 9, chances: { common: 75, rare: 16, super: 6, ultra: 2.5, secret: 0.5 } }];

/** Card name (or passcode) -> passcode. Adds a problem when the card doesn't exist. */
export function cardResolver(cards: CardDatabase, problems: string[]) {
  return (file: string, name: unknown): number | null => {
    if (typeof name === 'number' && cards.get(name)) return name;
    if (typeof name !== 'string') {
      problems.push(`${file}: expected a card name, got ${JSON.stringify(name)}`);
      return null;
    }
    const code = cards.findByName(name);
    if (code === null) problems.push(`${file}: no card named "${name}" (check the spelling)`);
    return code;
  };
}

/** Turns one pack file's JSON into a Pack. */
export function parsePack(fileName: string, p: any, resolve: (file: string, name: unknown) => number | null, problems: string[]): Pack {
  const file = `packs/${fileName}`;
  const pack: Pack = {
    id: String(p.id ?? fileName.replace(/\.json$/, '')), name: String(p.name ?? fileName), description: String(p.description ?? ''),
    active: p.active !== false, slots: [], cards: {}, size: 0, art: typeof p.art === 'string' && p.art ? p.art : undefined, ready: true, missing: [],
  };
  for (const rarity of RARITIES) {
    const list = p.cards?.[rarity];
    if (list === undefined) continue;
    const codes = (Array.isArray(list) ? list : []).map((n: unknown) => resolve(file, n)).filter((c): c is number => c !== null);
    pack.cards[rarity] = [...new Set(codes)];
  }
  for (const slot of Array.isArray(p.slots) ? p.slots : []) {
    const chances: Partial<Record<Rarity, number>> = {};
    let total = 0;
    for (const [rarity, value] of Object.entries(slot.chances ?? {})) {
      if (!RARITIES.includes(rarity as Rarity)) problems.push(`${file}: unknown rarity "${rarity}" (use ${RARITIES.join(', ')})`);
      else if (!pack.cards[rarity as Rarity]?.length && Number(value) > 0 && !pack.missing.includes(rarity)) pack.missing.push(rarity);
      chances[rarity as Rarity] = Number(value);
      total += Number(value);
    }
    if (Math.abs(total - 100) > 0.001) problems.push(`${file}: a slot's chances add up to ${total}, they must add up to 100`);
    const count = Number(slot.count);
    if (!Number.isInteger(count) || count < 1) problems.push(`${file}: each slot needs a "count" of at least 1`);
    pack.slots.push({ count, chances });
    pack.size += count;
  }
  if (pack.slots.length === 0) problems.push(`${file}: the pack has no slots`);
  pack.ready = pack.missing.length === 0 && pack.slots.length > 0;
  return pack;
}

export class ContentError extends Error {}

export function loadContent(cards: CardDatabase, dir = CONTENT_DIR): GameContent {
  const problems: string[] = [];
  // Custom cards first, so starter decks and packs can use them by name.
  const custom = loadCustomCards(cards, problems);
  const resolve = cardResolver(cards, problems);
  const readJson = (file: string): any => {
    try {
      return JSON.parse(readFileSync(path.join(dir, file), 'utf-8'));
    } catch (e) {
      problems.push(`${file}: could not read it (${(e as Error).message})`);
      return null;
    }
  };

  // Starter decks
  const starters: StarterDeck[] = [];
  const startersJson = readJson('starters.json');
  for (const d of startersJson?.decks ?? []) {
    const file = `starters.json (${d.name ?? d.id})`;
    const expand = (list: unknown, where: string) => {
      const out: number[] = [];
      for (const entry of Array.isArray(list) ? list : []) {
        const [name, copies] = entry as [unknown, unknown];
        const code = resolve(file, name);
        if (code === null) continue;
        if (!Number.isInteger(copies) || (copies as number) < 1 || (copies as number) > 3) problems.push(`${file}: "${name}" needs 1-3 copies`);
        if (cards.isExtraDeckCard(code) !== (where === 'extra')) problems.push(`${file}: "${name}" belongs in the ${cards.isExtraDeckCard(code) ? 'extra' : 'main'} list`);
        for (let i = 0; i < Number(copies); i++) out.push(code);
      }
      return out;
    };
    const deck: StarterDeck = { id: String(d.id), name: String(d.name), description: String(d.description ?? ''), main: expand(d.main, 'main'), extra: expand(d.extra, 'extra') };
    if (deck.main.length < 40 || deck.main.length > 60) problems.push(`${file}: the main deck has ${deck.main.length} cards (needs 40-60)`);
    if (deck.extra.length > 15) problems.push(`${file}: the extra deck has ${deck.extra.length} cards (max 15)`);
    starters.push(deck);
  }
  if (starters.length === 0) problems.push('starters.json: no starter decks found');

  // Packs
  const packs: Pack[] = [];
  let packFiles: string[] = [];
  try {
    packFiles = readdirSync(path.join(dir, 'packs')).filter((f) => f.endsWith('.json')).sort();
  } catch {
    problems.push('content/packs folder is missing');
  }
  for (const f of packFiles) {
    const p = readJson(`packs/${f}`);
    if (!p) continue;
    const pack = parsePack(f, p, resolve, problems);
    // A pack that is missing a rarity can't be opened; hand-made shop packs must be complete.
    if (!pack.ready && pack.active && p.draft !== true) problems.push(`packs/${f}: the pack has no ${pack.missing.join(', ')} cards`);
    packs.push(pack);
  }

  // Banlist (optional file)
  const banlist: Banlist = { forbidden: [], limited: [], semiLimited: [] };
  let banJson: any = null;
  try { banJson = JSON.parse(readFileSync(path.join(dir, 'banlist.json'), 'utf-8')); } catch { /* no banlist yet */ }
  if (banJson) {
    const seen = new Set<number>();
    for (const list of BANLIST_LISTS) {
      for (const name of Array.isArray(banJson[list]) ? banJson[list] : []) {
        const code = resolve('banlist.json', name);
        if (code === null) continue;
        const base = cards.baseCode(code);
        if (seen.has(base)) problems.push(`banlist.json: "${name}" is in more than one list`);
        seen.add(base);
        banlist[list].push(base);
      }
    }
  }

  if (problems.length) throw new ContentError(`Problems in the content folder:\n  - ${problems.join('\n  - ')}`);
  return { starters, packs, custom, banlist };
}

export interface RollOptions {
  /** Bad-luck protection: the last card of the pack is Rare or better. */
  guaranteeRareLast?: boolean;
}

/** Rolls a rarity from a chance table (percentages). */
function rollRarity(chances: Partial<Record<Rarity, number>>, rng: Rng): Rarity {
  const total = RARITIES.reduce((t, r) => t + Math.max(0, chances[r] ?? 0), 0);
  let roll = rng() * total;
  let rarity: Rarity = 'common';
  for (const r of RARITIES) {
    const chance = Math.max(0, chances[r] ?? 0);
    if (chance <= 0) continue;
    rarity = r;
    if (roll < chance) break;
    roll -= chance;
  }
  return rarity;
}

/**
 * Opens one pack. Every card makes two rolls: first its rarity (using the slot's chances),
 * then a random card of that rarity from the pack's list.
 */
export function rollPack(pack: Pack, rng: Rng, options: RollOptions = {}): PulledCard[] {
  const pulled: PulledCard[] = [];
  const inThisPack = new Set<number>();
  const lastIndex = pack.size - 1;
  for (const slot of pack.slots) {
    for (let i = 0; i < slot.count; i++) {
      let chances = slot.chances;
      if (options.guaranteeRareLast && pulled.length === lastIndex) {
        // Same chances as normal, just without Common (so Rare stays the most likely).
        const better = { ...slot.chances, common: 0 };
        if (RARITIES.some((r) => r !== 'common' && (better[r] ?? 0) > 0)) chances = better;
      }
      const rarity = rollRarity(chances, rng);
      // No repeats inside one pack (unless the rarity has too few cards to avoid it).
      const list = pack.cards[rarity]!;
      const fresh = list.filter((c) => !inThisPack.has(c));
      const pool = fresh.length ? fresh : list;
      const code = pool[Math.floor(rng() * pool.length)]!;
      inThisPack.add(code);
      pulled.push({ code, rarity });
    }
  }
  return pulled;
}
