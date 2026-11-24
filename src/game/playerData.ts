// Everything a player owns: their collection, decks, starter choice and free packs.
// All rules are checked here on the server; the browser is never trusted.
import type { Db } from '../db/database.ts';
import type { CardDatabase } from '../engine/cardDb.ts';
import { createRng } from '../engine/random.ts';
import { banlistLimit, rollPack, type GameContent, type Pack, type Rarity } from '../content/content.ts';
import type { DeckCodes } from '../decks/starters.ts';
import { ECONOMY } from '../config.ts';

export const MAX_COPIES = ECONOMY.maxCopies;
export const FREE_STARTER_PACKS = ECONOMY.freeStarterPacks;
const MAX_DECKS = 20;

export type Result<T> = { ok: true; value: T } | { ok: false; error: string };

export interface Profile {
  starterChosen: string | null;
  freePacks: number;
  activeDeckId: number | null;
  coins: number;
  /** Buying packs: */
  shop: {
    price: number;
    /** Finished duels since the last bought pack, and how many are needed. */
    duels: number;
    duelsNeeded: number;
    /** Packs you can still buy before the lock starts. */
    packsBeforeLock: number;
    /** While locked: when you can buy again (ms, 00:00 UTC). 0 = not locked. */
    lockedUntil: number;
    lockDays: number;
  };
}

/** 00:00 UTC, `days` days after the day `t` falls on. */
export function utcMidnightAfter(t: number, days: number): number {
  const d = new Date(t);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + days);
}

export interface OwnedCard {
  code: number;
  copies: number;
}

export interface DeckSummary {
  id: number;
  name: string;
  main: number[];
  extra: number[];
  active: boolean;
  /** Empty when the deck can be used in duels. */
  problems: string[];
  updatedAt: number;
}

export interface PackResultCard {
  code: number;
  rarity: Rarity;
  /** First copy you ever got. */
  isNew: boolean;
  /** You already had 3 copies, so this one adds nothing. */
  maxed: boolean;
}

interface DeckRow {
  id: number;
  user_id: number;
  name: string;
  main: string;
  extra: string;
  updated_at: number;
}

export class PlayerData {
  private readonly db: Db;
  private readonly cards: CardDatabase;
  private readonly content: GameContent;

  constructor(db: Db, cards: CardDatabase, content: GameContent) {
    this.db = db;
    this.cards = cards;
    this.content = content;
  }

  // ------------------------------------------------------------ profile + collection

  profile(userId: number): Profile {
    const r = this.db.prepare('SELECT starter_deck, free_packs, active_deck_id, coins, duels_since_pack, packs_before_lock, pack_lock_until FROM users WHERE id = ?').get(userId) as
      { starter_deck: string | null; free_packs: number; active_deck_id: number | null; coins: number; duels_since_pack: number; packs_before_lock: number; pack_lock_until: number } | undefined;
    if (!r) throw new Error(`No user ${userId}`);
    const locked = r.pack_lock_until > Date.now();
    return {
      starterChosen: r.starter_deck, freePacks: r.free_packs, activeDeckId: r.active_deck_id, coins: r.coins,
      shop: {
        price: ECONOMY.packPrice,
        duels: r.duels_since_pack,
        duelsNeeded: ECONOMY.duelsPerPack,
        packsBeforeLock: locked ? 0 : Math.max(0, ECONOMY.packsBeforeLock - r.packs_before_lock),
        lockedUntil: locked ? r.pack_lock_until : 0,
        lockDays: ECONOMY.packLockDays,
      },
    };
  }

  /**
   * A finished ranked duel (Find a duel): both players count it toward their next pack (unless they surrendered),
   * the winner gets coins, and ELO changes. Friendly invite-link duels give none of these.
   */
  recordDuel(userIds: [number, number], winner: 0 | 1 | null, surrendered: 0 | 1 | null, ranked = true): void {
    if (userIds[0] === userIds[1]) return; // playing yourself earns nothing
    if (!ranked) return; // friendly (invite-link) duels give nothing: rewards push players to Find a duel
    this.transaction(() => {
      ([0, 1] as const).forEach((i) => {
        if (surrendered !== i) this.db.prepare('UPDATE users SET duels_since_pack = duels_since_pack + 1 WHERE id = ?').run(userIds[i]);
      });
      if (winner !== null) this.db.prepare('UPDATE users SET coins = coins + ? WHERE id = ?').run(ECONOMY.coinsPerWin, userIds[winner]);
      this.updateElo(userIds, winner);
      return null;
    });
  }

  /** Standard ELO: the expected result comes from the rating gap; surrender counts as a loss, no winner as a draw. */
  private updateElo(userIds: [number, number], winner: 0 | 1 | null): void {
    const get = (id: number) => (this.db.prepare('SELECT elo FROM users WHERE id = ?').get(id) as { elo: number }).elo;
    const ra = get(userIds[0]), rb = get(userIds[1]);
    const expectedA = 1 / (1 + 10 ** ((rb - ra) / 400));
    const scoreA = winner === null ? 0.5 : winner === 0 ? 1 : 0;
    const change = Math.round(ECONOMY.eloK * (scoreA - expectedA));
    const col = (score: number) => (score === 1 ? 'wins' : score === 0 ? 'losses' : 'draws');
    this.db.prepare(`UPDATE users SET elo = elo + ?, ${col(scoreA)} = ${col(scoreA)} + 1 WHERE id = ?`).run(change, userIds[0]);
    this.db.prepare(`UPDATE users SET elo = elo - ?, ${col(1 - scoreA)} = ${col(1 - scoreA)} + 1 WHERE id = ?`).run(change, userIds[1]);
  }

  /**
   * The Standings: the top `limit` ranked players, your own place, and (with a search) matching players.
   * Ranked = played at least one online duel. Equal ratings share a place.
   */
  standings(userId: number, search: string, limit = 100) {
    const RANKED = '(wins + losses + draws) > 0';
    const row = (r: { id: number; username: string; elo: number; wins: number; losses: number; draws: number }) => ({
      rank: (this.db.prepare(`SELECT COUNT(*) AS n FROM users WHERE ${RANKED} AND elo > ?`).get(r.elo) as { n: number }).n + 1,
      username: r.username, elo: r.elo, wins: r.wins, losses: r.losses, draws: r.draws, me: r.id === userId,
    });
    const cols = 'id, username, elo, wins, losses, draws';
    const top = (this.db.prepare(`SELECT ${cols} FROM users WHERE ${RANKED} ORDER BY elo DESC, username LIMIT ?`).all(limit) as any[]).map(row);
    const mine = this.db.prepare(`SELECT ${cols} FROM users WHERE id = ?`).get(userId) as any;
    const me = mine.wins + mine.losses + mine.draws > 0 ? row(mine) : { ...row(mine), rank: null };
    const q = search.trim();
    const found = q
      ? (this.db.prepare(`SELECT ${cols} FROM users WHERE ${RANKED} AND username LIKE ? ESCAPE '\\' ORDER BY elo DESC LIMIT 20`)
          .all(`%${q.replace(/[\\%_]/g, (m) => '\\' + m)}%`) as any[]).map(row)
      : [];
    const total = (this.db.prepare(`SELECT COUNT(*) AS n FROM users WHERE ${RANKED}`).get() as { n: number }).n;
    return { top, me, found, total };
  }

  collection(userId: number): OwnedCard[] {
    return this.db.prepare('SELECT code, copies FROM collection WHERE user_id = ? ORDER BY code').all(userId) as unknown as OwnedCard[];
  }

  private ownedMap(userId: number): Map<number, number> {
    return new Map(this.collection(userId).map((c) => [c.code, c.copies]));
  }

  /** Adds cards to the collection (max 3 copies each). Call inside a transaction. */
  private addCards(userId: number, codes: number[]): { isNew: boolean; maxed: boolean }[] {
    const get = this.db.prepare('SELECT copies FROM collection WHERE user_id = ? AND code = ?');
    const insert = this.db.prepare('INSERT INTO collection (user_id, code, copies, first_obtained_at) VALUES (?, ?, 1, ?)');
    const bump = this.db.prepare('UPDATE collection SET copies = copies + 1 WHERE user_id = ? AND code = ?');
    return codes.map((raw) => {
      const code = this.cards.baseCode(raw);
      const row = get.get(userId, code) as { copies: number } | undefined;
      if (!row) {
        insert.run(userId, code, Date.now());
        return { isNew: true, maxed: false };
      }
      if (row.copies >= MAX_COPIES) return { isNew: false, maxed: true };
      bump.run(userId, code);
      return { isNew: false, maxed: false };
    });
  }

  private transaction<T>(fn: () => T): T {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const result = fn();
      this.db.exec('COMMIT');
      return result;
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
  }

  // ------------------------------------------------------------ starter deck

  chooseStarter(userId: number, starterId: unknown): Result<Profile> {
    const starter = this.content.starters.find((s) => s.id === starterId);
    if (!starter) return { ok: false, error: 'That starter deck does not exist.' };
    return this.transaction(() => {
      const current = this.profile(userId);
      if (current.starterChosen) return { ok: false as const, error: 'You already chose your starter deck.' };
      this.addCards(userId, [...starter.main, ...starter.extra]);
      const now = Date.now();
      const info = this.db
        .prepare('INSERT INTO decks (user_id, name, main, extra, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)')
        .run(userId, starter.name, JSON.stringify(starter.main), JSON.stringify(starter.extra), now, now);
      this.db
        .prepare('UPDATE users SET starter_deck = ?, free_packs = ?, active_deck_id = ? WHERE id = ?')
        .run(starter.id, FREE_STARTER_PACKS, Number(info.lastInsertRowid), userId);
      return { ok: true as const, value: this.profile(userId) };
    });
  }

  // ------------------------------------------------------------ packs

  /** Where the shop lineup comes from (the Pack Maker's PackStore); without one, packs marked "active". */
  private shopSource: (() => Pack[]) | null = null;
  setShopSource(source: () => Pack[]): void {
    this.shopSource = source;
  }

  /** Packs players can get right now. */
  activePacks(): Pack[] {
    return this.shopSource ? this.shopSource() : this.content.packs.filter((p) => p.active && p.ready);
  }

  /**
   * Rolls a pack for this player and applies bad-luck protection: if their previous pack was
   * all Commons, this pack's last card is Rare or better. Call inside a transaction.
   */
  private rollFor(userId: number, pack: Pack): { pulled: ReturnType<typeof rollPack>; guaranteed: boolean } {
    const row = this.db.prepare('SELECT guaranteed_rare_next FROM users WHERE id = ?').get(userId) as { guaranteed_rare_next: number };
    const guaranteed = row.guaranteed_rare_next === 1;
    const pulled = rollPack(pack, createRng(Math.floor(Math.random() * 2 ** 31)), { guaranteeRareLast: guaranteed });
    const allCommon = pulled.every((c) => c.rarity === 'common');
    this.db.prepare('UPDATE users SET guaranteed_rare_next = ? WHERE id = ?').run(allCommon ? 1 : 0, userId);
    return { pulled, guaranteed };
  }

  /**
   * Buys and opens a pack: costs coins, needs enough finished duels since the last purchase, and after
   * `packsBeforeLock` purchases the shop locks until 00:00 UTC `packLockDays` days after the last one.
   */
  buyPack(userId: number, packId: unknown): Result<{ pack: Pack; cards: PackResultCard[]; guaranteed: boolean; profile: Profile }> {
    const pack = this.activePacks().find((p) => p.id === packId);
    if (!pack) return { ok: false, error: 'That pack is not available.' };
    return this.transaction(() => {
      const profile = this.profile(userId);
      const shop = profile.shop;
      if (!profile.starterChosen) return { ok: false as const, error: 'Choose your starter deck first.' };
      if (shop.lockedUntil) return { ok: false as const, error: `You can buy packs again on ${new Date(shop.lockedUntil).toUTCString().replace(':00 GMT', ' UTC')}.` };
      if (shop.duels < shop.duelsNeeded) return { ok: false as const, error: `Play ${shop.duelsNeeded - shop.duels} more duel${shop.duelsNeeded - shop.duels === 1 ? '' : 's'} to buy a pack.` };
      if (profile.coins < shop.price) return { ok: false as const, error: `A pack costs ${shop.price} coins; you have ${profile.coins}.` };
      const { pulled, guaranteed } = this.rollFor(userId, pack);
      const added = this.addCards(userId, pulled.map((p) => p.code));
      const cards = pulled.map((p, i) => ({ code: p.code, rarity: p.rarity, ...added[i]! }));
      const row = this.db.prepare('SELECT packs_before_lock FROM users WHERE id = ?').get(userId) as { packs_before_lock: number };
      // an old lock that already ended starts a fresh count
      const bought = (this.db.prepare('SELECT pack_lock_until FROM users WHERE id = ?').get(userId) as { pack_lock_until: number }).pack_lock_until ? 1 : row.packs_before_lock + 1;
      const now = Date.now();
      const lock = bought >= ECONOMY.packsBeforeLock ? utcMidnightAfter(now, ECONOMY.packLockDays) : 0;
      this.db
        .prepare('UPDATE users SET coins = coins - ?, duels_since_pack = 0, packs_before_lock = ?, pack_lock_until = ? WHERE id = ?')
        .run(shop.price, lock ? 0 : bought, lock, userId);
      this.db
        .prepare('INSERT INTO pack_openings (user_id, pack_id, cards, free, opened_at) VALUES (?, ?, ?, 0, ?)')
        .run(userId, pack.id, JSON.stringify(pulled), now);
      return { ok: true as const, value: { pack, cards, guaranteed, profile: this.profile(userId) } };
    });
  }

  /** Opens a free starter pack (no coins, no duels, doesn't count toward the lock). */
  openFreePack(userId: number, packId: unknown): Result<{ pack: Pack; cards: PackResultCard[]; freePacksLeft: number; guaranteed: boolean }> {
    const pack = this.activePacks().find((p) => p.id === packId);
    if (!pack) return { ok: false, error: 'That pack is not available.' };
    return this.transaction(() => {
      const profile = this.profile(userId);
      if (!profile.starterChosen) return { ok: false as const, error: 'Choose your starter deck first.' };
      if (profile.freePacks <= 0) return { ok: false as const, error: 'You have no free packs left.' };
      const { pulled, guaranteed } = this.rollFor(userId, pack);
      const added = this.addCards(userId, pulled.map((p) => p.code));
      const cards = pulled.map((p, i) => ({ code: p.code, rarity: p.rarity, ...added[i]! }));
      this.db.prepare('UPDATE users SET free_packs = free_packs - 1 WHERE id = ?').run(userId);
      this.db
        .prepare('INSERT INTO pack_openings (user_id, pack_id, cards, free, opened_at) VALUES (?, ?, ?, 1, ?)')
        .run(userId, pack.id, JSON.stringify(pulled), Date.now());
      return { ok: true as const, value: { pack, cards, freePacksLeft: profile.freePacks - 1, guaranteed } };
    });
  }

  // ------------------------------------------------------------ decks

  private isAdmin(userId: number): boolean {
    const r = this.db.prepare('SELECT is_admin FROM users WHERE id = ?').get(userId) as { is_admin: number } | undefined;
    return r?.is_admin === 1;
  }

  /** Everything that stops a deck from being used in a duel (empty list = valid). owned = null: admin, owns everything. */
  deckProblems(main: number[], extra: number[], owned: Map<number, number> | null): string[] {
    const problems: string[] = [];
    if (main.length < 40) problems.push(`Main Deck has ${main.length} cards (needs at least 40).`);
    if (main.length > 60) problems.push(`Main Deck has ${main.length} cards (max 60).`);
    if (extra.length > 15) problems.push(`Extra Deck has ${extra.length} cards (max 15).`);
    const used = new Map<number, number>();
    for (const code of [...main, ...extra]) used.set(this.cards.baseCode(code), (used.get(this.cards.baseCode(code)) ?? 0) + 1);
    for (const [code, n] of used) {
      const name = this.cards.name(code);
      const limit = banlistLimit(this.content.banlist, code);
      if (limit === 0) problems.push(`${name} is Forbidden by the banlist.`);
      else if (n > limit && limit < MAX_COPIES) problems.push(`${name} is ${limit === 1 ? 'Limited' : 'Semi-Limited'}: max ${limit} ${limit === 1 ? 'copy' : 'copies'} (you have ${n}).`);
      else if (n > MAX_COPIES) problems.push(`${name}: ${n} copies (max ${MAX_COPIES}).`);
      const have = owned === null ? MAX_COPIES : owned.get(code) ?? 0;
      if (n > have) problems.push(`${name}: uses ${n} but you own ${have}.`);
    }
    for (const code of [...main, ...extra]) if (Number(this.cards.get(code)?.data.type ?? 0) & 0x4000) problems.push(`${this.cards.name(code)} is a Token and can't be put in a Deck.`);
    for (const code of [...main, ...extra]) if (this.cards.get(code)?.hidden) problems.push(`${this.cards.name(code)} can't be put in a Deck.`);
    for (const code of main) if (this.cards.isExtraDeckCard(code)) problems.push(`${this.cards.name(code)} must go in the Extra Deck.`);
    for (const code of extra) if (!this.cards.isExtraDeckCard(code)) problems.push(`${this.cards.name(code)} can't go in the Extra Deck.`);
    return [...new Set(problems)];
  }

  private summary(row: DeckRow, activeId: number | null, owned: Map<number, number> | null): DeckSummary {
    const main = JSON.parse(row.main) as number[];
    const extra = JSON.parse(row.extra) as number[];
    return { id: row.id, name: row.name, main, extra, active: row.id === activeId, problems: this.deckProblems(main, extra, owned), updatedAt: row.updated_at };
  }

  decks(userId: number): DeckSummary[] {
    const owned = this.isAdmin(userId) ? null : this.ownedMap(userId);
    const activeId = this.profile(userId).activeDeckId;
    return (this.db.prepare('SELECT * FROM decks WHERE user_id = ? ORDER BY id').all(userId) as unknown as DeckRow[]).map((r) => this.summary(r, activeId, owned));
  }

  private cleanDeckInput(name: unknown, main: unknown, extra: unknown): Result<{ name: string; main: number[]; extra: number[] }> {
    const n = typeof name === 'string' ? name.trim().slice(0, 40) : '';
    if (!n) return { ok: false, error: 'Give the deck a name.' };
    const list = (v: unknown, max: number): number[] | null => {
      if (!Array.isArray(v) || v.length > max) return null;
      return v.every((c) => Number.isInteger(c) && this.cards.get(c as number)) ? (v as number[]) : null;
    };
    const m = list(main, 60);
    const e = list(extra, 15);
    if (!m || !e) return { ok: false, error: 'The deck contains unknown cards or too many cards.' };
    return { ok: true, value: { name: n, main: m, extra: e } };
  }

  /** Saves a deck (new when id is null). Decks may be saved unfinished; problems are reported. */
  saveDeck(userId: number, id: number | null, name: unknown, main: unknown, extra: unknown): Result<DeckSummary> {
    const input = this.cleanDeckInput(name, main, extra);
    if (!input.ok) return input;
    const { name: n, main: m, extra: e } = input.value;
    const now = Date.now();
    let deckId = id;
    if (deckId === null) {
      const count = (this.db.prepare('SELECT COUNT(*) AS n FROM decks WHERE user_id = ?').get(userId) as { n: number }).n;
      if (count >= MAX_DECKS) return { ok: false, error: `You can have at most ${MAX_DECKS} decks.` };
      deckId = Number(this.db.prepare('INSERT INTO decks (user_id, name, main, extra, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)')
        .run(userId, n, JSON.stringify(m), JSON.stringify(e), now, now).lastInsertRowid);
    } else {
      const changed = this.db.prepare('UPDATE decks SET name = ?, main = ?, extra = ?, updated_at = ? WHERE id = ? AND user_id = ?')
        .run(n, JSON.stringify(m), JSON.stringify(e), now, deckId, userId).changes;
      if (!changed) return { ok: false, error: 'Deck not found.' };
    }
    return { ok: true, value: this.decks(userId).find((d) => d.id === deckId)! };
  }

  deleteDeck(userId: number, id: number): Result<null> {
    const profile = this.profile(userId);
    if (profile.activeDeckId === id) return { ok: false, error: "You can't delete your active deck. Make another deck active first." };
    const changed = this.db.prepare('DELETE FROM decks WHERE id = ? AND user_id = ?').run(id, userId).changes;
    return changed ? { ok: true, value: null } : { ok: false, error: 'Deck not found.' };
  }

  setActiveDeck(userId: number, id: number): Result<null> {
    const deck = this.decks(userId).find((d) => d.id === id);
    if (!deck) return { ok: false, error: 'Deck not found.' };
    if (deck.problems.length) return { ok: false, error: `This deck can't be used yet: ${deck.problems[0]}` };
    this.db.prepare('UPDATE users SET active_deck_id = ? WHERE id = ?').run(id, userId);
    return { ok: true, value: null };
  }

  /** The deck this player duels with, or the reason they can't duel yet. */
  duelDeck(userId: number): Result<DeckCodes> {
    const profile = this.profile(userId);
    if (!profile.starterChosen) return { ok: false, error: 'Choose your starter deck first.' };
    const deck = this.decks(userId).find((d) => d.id === profile.activeDeckId);
    if (!deck) return { ok: false, error: 'Pick an active deck in the deck editor first.' };
    if (deck.problems.length) return { ok: false, error: `Your active deck "${deck.name}" can't be used: ${deck.problems[0]}` };
    return { ok: true, value: { main: deck.main, extra: deck.extra } };
  }
}
