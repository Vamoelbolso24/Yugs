// The Pack Maker's storage: pack files in content/packs, their artwork in content/packs/art, and the shop
// lineup (which packs players can get) in content/shop.json.
//
// shop.json: { "current": ["pack-id", ...], "next": ["pack-id", ...] | null, "nextFrom": "2026-11-30T00:00:00.000Z" }
// "next" is what an admin scheduled; it replaces "current" at the weekly reset (Monday 00:00 UTC).
import { existsSync, mkdirSync, readFileSync, readdirSync, unlinkSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import type { CardDatabase } from '../engine/cardDb.ts';
import { BANLIST_LISTS, CONTENT_DIR, DEFAULT_SLOTS, type Banlist, PACK_ART_DIR, PACKS_DIR, RARITIES, cardResolver, parsePack, type GameContent, type Pack, type Rarity } from './content.ts';

export const SHOP_SIZE = 3;
const LABEL: Record<string, string> = { common: 'Common', rare: 'Rare', super: 'Super Rare', ultra: 'Ultra Rare', secret: 'Secret Rare' };
const SHOP_FILE = path.join(CONTENT_DIR, 'shop.json');

interface ShopFile { current: string[]; next: string[] | null; nextFrom: string | null }

/** Next Monday 00:00 UTC after `now` (the weekly reset). */
export function nextWeeklyReset(now = Date.now()): Date {
  const d = new Date(now);
  const day = d.getUTCDay(); // 0 = Sunday
  const days = ((8 - day) % 7) || 7;
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + days));
}

export class PackStore {
  private readonly content: GameContent;
  private readonly cards: CardDatabase;

  constructor(content: GameContent, cards: CardDatabase) {
    this.content = content;
    this.cards = cards;
  }

  // ------------------------------------------------------------ shop lineup

  private readShop(): ShopFile {
    try {
      const s = JSON.parse(readFileSync(SHOP_FILE, 'utf-8')) as Partial<ShopFile>;
      return { current: Array.isArray(s.current) ? s.current.map(String) : [], next: Array.isArray(s.next) ? s.next.map(String) : null, nextFrom: s.nextFrom ?? null };
    } catch {
      // No shop.json yet: the shop is the packs marked "active" (how packs worked before the Pack Maker).
      return { current: this.content.packs.filter((p) => p.active && p.ready).slice(0, SHOP_SIZE).map((p) => p.id), next: null, nextFrom: null };
    }
  }

  private writeShop(s: ShopFile): void {
    writeFileSync(SHOP_FILE, JSON.stringify({ _help: 'Made by the Pack Maker. "current" = packs in the shop now; "next" replaces it at "nextFrom" (the weekly reset).', ...s }, null, 2) + '\n');
  }

  /** The shop as it is right now (applies a scheduled lineup once its week has started). */
  shop(): ShopFile {
    const s = this.readShop();
    if (s.next && s.nextFrom && Date.now() >= Date.parse(s.nextFrom)) {
      const promoted = { current: s.next, next: null, nextFrom: null };
      this.writeShop(promoted);
      return promoted;
    }
    return s;
  }

  /** Packs players can get this week. */
  shopPacks(): Pack[] {
    return this.shop().current.map((id) => this.content.packs.find((p) => p.id === id)).filter((p): p is Pack => !!p && p.ready);
  }

  /** Puts next week's scheduled lineup in the shop right now (instead of waiting for the weekly reset). */
  startNextNow(): { ok: true; shop: ShopFile } | { ok: false; error: string } {
    const s = this.shop();
    if (!s.next || !s.next.length) return { ok: false, error: 'Nothing is scheduled for next week yet.' };
    const now = { current: s.next, next: null, nextFrom: null };
    this.writeShop(now);
    return { ok: true, shop: now };
  }

  /** Schedules the lineup for next week (or clears the schedule with an empty list). */
  scheduleNext(ids: string[]): { ok: true; shop: ShopFile } | { ok: false; error: string } {
    const unique = [...new Set(ids.map(String))];
    if (unique.length > SHOP_SIZE) return { ok: false, error: `The shop has ${SHOP_SIZE} places.` };
    for (const id of unique) {
      const p = this.content.packs.find((x) => x.id === id);
      if (!p) return { ok: false, error: `There is no pack "${id}".` };
      if (!p.ready) return { ok: false, error: `"${p.name}" has no ${p.missing.map((r) => LABEL[r] ?? r).join(', ')} cards yet, so it can't be in the shop.` };
    }
    const s = this.shop();
    const next = unique.length ? { ...s, next: unique, nextFrom: nextWeeklyReset().toISOString() } : { ...s, next: null, nextFrom: null };
    this.writeShop(next);
    return { ok: true, shop: next };
  }

  // ------------------------------------------------------------ packs

  all(): Pack[] {
    return this.content.packs;
  }

  /** A file-safe id from a pack name. */
  static idFor(name: string): string {
    return name.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'pack';
  }

  /** Creates or replaces a pack. `cards` are passcodes per rarity. */
  save(input: { id?: string; name: string; description: string; cards: Partial<Record<Rarity, number[]>> }): { ok: true; pack: Pack } | { ok: false; error: string } {
    const name = input.name.trim();
    if (!name) return { ok: false, error: 'Give the pack a name.' };
    if (name.length > 60) return { ok: false, error: 'The name is too long (60 letters max).' };
    let id = input.id && this.content.packs.some((p) => p.id === input.id) ? input.id : null;
    if (!id) {
      if (this.content.packs.some((p) => p.name.toLowerCase() === name.toLowerCase())) return { ok: false, error: `There is already a pack called "${name}".` };
      const base = PackStore.idFor(name);
      id = base;
      for (let i = 2; this.content.packs.some((p) => p.id === id) || existsSync(path.join(PACKS_DIR, `${id}.json`)); i++) id = `${base}-${i}`;
    }
    const old = this.content.packs.find((p) => p.id === id);
    const cards: Record<string, string[]> = {};
    for (const r of [...RARITIES].reverse()) {
      const codes = [...new Set((input.cards[r] ?? []).map(Number))].filter((c) => this.cards.get(c));
      // names keep the file readable; a passcode is used when the name would find a different card
      cards[r] = codes.map((c) => (this.cards.findByName(this.cards.name(c)) === c ? this.cards.name(c) : c) as string);
    }
    const missing = RARITIES.filter((r) => !cards[r]!.length && (DEFAULT_SLOTS[0]!.chances[r] ?? 0) > 0);
    const json = {
      _help: 'Made with the Pack Maker (admin screen in the game). You can still edit it by hand; restart the server after editing.',
      id, name, description: input.description.trim().slice(0, 300),
      ...(old?.art ? { art: old.art } : {}),
      draft: missing.length > 0,
      slots: DEFAULT_SLOTS,
      cards,
    };
    mkdirSync(PACKS_DIR, { recursive: true });
    writeFileSync(path.join(PACKS_DIR, `${id}.json`), JSON.stringify(json, null, 2) + '\n');
    const problems: string[] = [];
    const pack = parsePack(`${id}.json`, json, cardResolver(this.cards, problems), problems);
    if (old) pack.active = old.active;
    const i = this.content.packs.findIndex((p) => p.id === id);
    if (i >= 0) this.content.packs[i] = pack;
    else this.content.packs.push(pack);
    return { ok: true, pack };
  }

  /** Makes a copy of a saved pack (cards, description and artwork) named "<name> (copy)". */
  copy(id: string): { ok: true; pack: Pack } | { ok: false; error: string } {
    const src = this.content.packs.find((p) => p.id === id);
    if (!src) return { ok: false, error: 'No such pack.' };
    const taken = (n: string) => this.content.packs.some((p) => p.name.toLowerCase() === n.toLowerCase());
    const stem = src.name.replace(/ \(copy( \d+)?\)$/, '').slice(0, 45);
    let name = `${stem} (copy)`;
    for (let i = 2; taken(name); i++) name = `${stem} (copy ${i})`;
    const made = this.save({ name, description: src.description, cards: src.cards });
    if (!made.ok) return made;
    if (src.art && existsSync(path.join(PACK_ART_DIR, src.art))) {
      const data = readFileSync(path.join(PACK_ART_DIR, src.art));
      const mime = ({ png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp', gif: 'image/gif' } as Record<string, string>)[src.art.split('.').pop()!.toLowerCase()];
      if (mime) this.setArt(made.pack.id, data, mime);
    }
    return { ok: true, pack: this.content.packs.find((p) => p.id === made.pack.id)! };
  }

  /** Deletes a pack that is not in the shop (now or next week). */
  remove(id: string): { ok: true } | { ok: false; error: string } {
    const s = this.shop();
    if (s.current.includes(id) || (s.next ?? []).includes(id)) return { ok: false, error: 'Take the pack out of the shop first.' };
    const i = this.content.packs.findIndex((p) => p.id === id);
    if (i < 0) return { ok: false, error: 'No such pack.' };
    const pack = this.content.packs[i]!;
    const file = path.join(PACKS_DIR, `${id}.json`);
    if (existsSync(file)) unlinkSync(file);
    if (pack.art) { try { unlinkSync(path.join(PACK_ART_DIR, pack.art)); } catch { /* already gone */ } }
    this.content.packs.splice(i, 1);
    return { ok: true };
  }

  /** Saves the pack's artwork (PNG, JPEG, WEBP or GIF). */
  setArt(id: string, data: Buffer, mime: string): { ok: true; art: string } | { ok: false; error: string } {
    const pack = this.content.packs.find((p) => p.id === id);
    if (!pack) return { ok: false, error: 'Save the pack first.' };
    const ext = ({ 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/gif': 'gif' } as Record<string, string>)[mime];
    if (!ext) return { ok: false, error: 'Use a PNG, JPG, WEBP or GIF image.' };
    if (data.length > 4 * 1024 * 1024) return { ok: false, error: 'The image is too big (4 MB max).' };
    mkdirSync(PACK_ART_DIR, { recursive: true });
    for (const f of readdirSync(PACK_ART_DIR)) if (f.startsWith(`${id}.`)) unlinkSync(path.join(PACK_ART_DIR, f));
    const art = `${id}.${ext}`;
    writeFileSync(path.join(PACK_ART_DIR, art), data);
    pack.art = art;
    // remember it in the pack file
    const file = path.join(PACKS_DIR, `${id}.json`);
    try {
      const json = JSON.parse(readFileSync(file, 'utf-8'));
      json.art = art;
      writeFileSync(file, JSON.stringify(json, null, 2) + '\n');
    } catch { /* the pack keeps its art for this run */ }
    return { ok: true, art };
  }
}

/** Saves the banlist (admins, Banlist editor): content/banlist.json by card name, and the running game. */
export function saveBanlist(content: GameContent, cards: CardDatabase, input: Partial<Record<string, unknown>>): { ok: true; banlist: Banlist } | { ok: false; error: string } {
  const next: Banlist = { forbidden: [], limited: [], semiLimited: [] };
  const seen = new Set<number>();
  for (const list of BANLIST_LISTS) {
    const raw = Array.isArray(input[list]) ? (input[list] as unknown[]) : [];
    for (const v of raw) {
      const code = Number(v);
      if (!cards.get(code)) return { ok: false, error: `Unknown card ${String(v)}.` };
      const base = cards.baseCode(code);
      if (seen.has(base)) return { ok: false, error: `${cards.name(base)} is in more than one list.` };
      seen.add(base);
      next[list].push(base);
    }
  }
  const byName = (codes: number[]) => codes.map((c) => (cards.findByName(cards.name(c)) === c ? cards.name(c) : c)).sort((a, b) => String(a).localeCompare(String(b)));
  const json = {
    _help: 'The banlist. Forbidden = 0 copies in a deck, Limited = 1, Semi-Limited = 2. Edit it in the game (Banlist editor, admins) or here by exact English card name, then restart the server.',
    updated: new Date().toISOString().slice(0, 10),
    forbidden: byName(next.forbidden), limited: byName(next.limited), semiLimited: byName(next.semiLimited),
  };
  writeFileSync(path.join(CONTENT_DIR, 'banlist.json'), JSON.stringify(json, null, 2) + '\n');
  for (const list of BANLIST_LISTS) content.banlist[list] = next[list];
  return { ok: true, banlist: content.banlist };
}
