// "Find a duel": a queue that pairs players of similar ELO (like Pokemon Showdown's ladder).
// The allowed rating gap starts small and widens the longer you wait, so nobody waits forever.
// Browsers poll their status every couple of seconds; a player who stops polling leaves the queue.
import type { User } from '../auth/accounts.ts';
import type { DeckCodes } from '../decks/starters.ts';
import type { RoomManager, SeatIndex } from './rooms.ts';

/** Rating gap allowed right away, how much it grows, how often, and when anyone will do. */
const START_GAP = 100;
const GAP_STEP = 50;
const STEP_MS = 5_000;
const ANYONE_AFTER_MS = 60_000;
/** No status check for this long = gone (closed the tab). */
const STALE_MS = 15_000;

interface Entry {
  user: User;
  elo: number;
  deck: DeckCodes;
  since: number;
  lastPoll: number;
  match: { roomId: string; seat: SeatIndex; token: string } | null;
}

export type MatchStatus =
  | { status: 'idle' }
  | { status: 'searching'; seconds: number; gap: number | null; inQueue: number }
  | { status: 'matched'; roomId: string; seat: SeatIndex; token: string };

export class Matchmaker {
  private readonly queue = new Map<number, Entry>();
  private readonly rooms: RoomManager;
  private pairing = false;

  constructor(rooms: RoomManager) {
    this.rooms = rooms;
    setInterval(() => void this.pair(), 1_000).unref();
  }

  static gapFor(waitedMs: number): number | null {
    if (waitedMs >= ANYONE_AFTER_MS) return null; // anyone
    return START_GAP + GAP_STEP * Math.floor(waitedMs / STEP_MS);
  }

  join(user: User, elo: number, deck: DeckCodes): MatchStatus {
    const now = Date.now();
    const old = this.queue.get(user.id);
    if (old?.match) return this.status(user.id);
    this.queue.set(user.id, { user, elo, deck, since: old?.since ?? now, lastPoll: now, match: null });
    void this.pair();
    return this.status(user.id);
  }

  leave(userId: number): void {
    const e = this.queue.get(userId);
    if (e && !e.match) this.queue.delete(userId);
  }

  status(userId: number): MatchStatus {
    const e = this.queue.get(userId);
    if (!e) return { status: 'idle' };
    e.lastPoll = Date.now();
    if (e.match) {
      this.queue.delete(userId); // handed over: the browser now goes to the duel
      return { status: 'matched', ...e.match };
    }
    const waited = Date.now() - e.since;
    return { status: 'searching', seconds: Math.floor(waited / 1000), gap: Matchmaker.gapFor(waited), inQueue: [...this.queue.values()].filter((x) => !x.match).length };
  }

  /** Pairs the longest-waiting players first with the closest rating both of them accept. */
  private async pair(): Promise<void> {
    if (this.pairing) return;
    this.pairing = true;
    try {
      const now = Date.now();
      for (const [id, e] of this.queue) if (!e.match && now - e.lastPoll > STALE_MS) this.queue.delete(id);
      const waiting = [...this.queue.values()].filter((e) => !e.match).sort((a, b) => a.since - b.since);
      const used = new Set<number>();
      for (const a of waiting) {
        if (used.has(a.user.id)) continue;
        let best: Entry | null = null;
        for (const b of waiting) {
          if (b === a || used.has(b.user.id)) continue;
          const gap = Math.abs(a.elo - b.elo);
          const ga = Matchmaker.gapFor(now - a.since), gb = Matchmaker.gapFor(now - b.since);
          if ((ga !== null && gap > ga) || (gb !== null && gap > gb)) continue;
          if (!best || gap < Math.abs(a.elo - best.elo)) best = b;
        }
        if (!best) continue;
        used.add(a.user.id);
        used.add(best.user.id);
        const created = this.rooms.create(a.user, a.deck, true);
        const room = this.rooms.get(created.roomId)!;
        const joined = await this.rooms.join(room, best.user, best.deck);
        if ('error' in joined) continue;
        a.match = { roomId: created.roomId, seat: created.seat, token: created.token };
        best.match = { roomId: created.roomId, seat: joined.seat, token: joined.token };
      }
    } catch (e) {
      console.error('Matchmaking failed:', e);
    } finally {
      this.pairing = false;
    }
  }
}
