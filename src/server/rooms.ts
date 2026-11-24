// Online duel rooms: two seats, each with a secret token. The server pushes a fresh,
// player-specific view to each seat over Server-Sent Events whenever something changes.
import { randomBytes } from 'node:crypto';
import type { ServerResponse } from 'node:http';
import type { CardDatabase } from '../engine/cardDb.ts';
import type { DeckCodes } from '../decks/starters.ts';
import { DuelSession } from '../game/session.ts';
import type { ChainMode, GameView } from '../game/types.ts';
import type { User } from '../auth/accounts.ts';

export type SeatIndex = 0 | 1;

export interface SeatInfo {
  name: string;
  connected: boolean;
}

/** What one player's browser receives. */
export interface RoomState {
  roomId: string;
  seat: SeatIndex;
  status: 'waiting' | 'starting' | 'playing' | 'finished';
  seats: [SeatInfo | null, SeatInfo | null];
  /** The duel as this player sees it (null until both players have joined). */
  view: GameView | null;
  /** Ranked (from Find a duel): the result changes ELO. Invite-link duels are friendly. */
  ranked: boolean;
  /** Chess clock per duel player (EDOPro style): ms left, who is thinking, and the server's time when sent. */
  clock: { left: [number, number]; running: 0 | 1 | null; serverNow: number } | null;
  error?: string;
}

interface Seat {
  token: string;
  userId: number;
  name: string;
  deck: DeckCodes;
  clients: Set<ServerResponse>;
  lastSeen: number;
}

interface Room {
  id: string;
  seats: [Seat | null, Seat | null];
  session: DuelSession | null;
  starting: boolean;
  /** Which engine player (0 goes first) each seat controls. */
  duelPlayerOfSeat: [SeatIndex, SeatIndex];
  createdAt: number;
  ranked: boolean;
  /** Time left per duel player, who is thinking since when, and the timeout for them. */
  clock: { left: [number, number]; running: 0 | 1 | null; since: number; timer: ReturnType<typeof setTimeout> | null };
}

/** EDOPro's clock: 180 seconds per player for the whole duel, +3 seconds after every decision. */
export const CLOCK_START_MS = 180_000;
export const CLOCK_INCREMENT_MS = 3_000;
/** A player whose browser is gone this long during a duel loses it. */
export const DISCONNECT_LOSS_MS = 120_000;

const token = () => randomBytes(18).toString('base64url');
const roomCode = () => randomBytes(5).toString('base64url').replace(/[-_]/g, 'x');

export class RoomManager {
  private readonly rooms = new Map<string, Room>();
  private readonly cards: CardDatabase;

  /** Called once when an online duel ends: [user of duel player 0, user of duel player 1], winner, who surrendered. */
  onFinished: ((userIds: [number, number], winner: 0 | 1 | null, surrendered: 0 | 1 | null, ranked: boolean) => void) | null = null;
  private readonly recorded = new WeakSet<Room>();

  constructor(cards: CardDatabase) {
    this.cards = cards;
    // Keep the connections alive and clean up abandoned rooms.
    setInterval(() => this.housekeeping(), 20_000).unref();
  }

  create(user: User, deck: DeckCodes, ranked = false): { roomId: string; seat: SeatIndex; token: string } {
    const room: Room = {
      ranked,
      clock: { left: [CLOCK_START_MS, CLOCK_START_MS], running: null, since: 0, timer: null },
      id: roomCode(),
      seats: [{ token: token(), userId: user.id, name: user.username, deck, clients: new Set(), lastSeen: Date.now() }, null],
      session: null,
      starting: false,
      duelPlayerOfSeat: [0, 1],
      createdAt: Date.now(),
    };
    this.rooms.set(room.id, room);
    return { roomId: room.id, seat: 0, token: room.seats[0]!.token };
  }

  get(roomId: string): Room | undefined {
    return this.rooms.get(roomId);
  }

  /** Already a player in this room (another tab or device)? Returns that seat. */
  rejoin(room: Room, user: User): { seat: SeatIndex; token: string } | null {
    const mine = this.seatOfUser(room, user.id);
    return mine === null ? null : { seat: mine, token: room.seats[mine]!.token };
  }

  async join(room: Room, user: User, deck: DeckCodes): Promise<{ seat: SeatIndex; token: string } | { error: string }> {
    const back = this.rejoin(room, user);
    if (back) return back;
    if (room.seats[1]) return { error: 'This duel already has two players.' };
    const seat: Seat = { token: token(), userId: user.id, name: user.username, deck, clients: new Set(), lastSeen: Date.now() };
    room.seats[1] = seat;
    await this.startDuel(room);
    return { seat: 1, token: seat.token };
  }

  seatOfUser(room: Room, userId: number): SeatIndex | null {
    if (room.seats[0]?.userId === userId) return 0;
    if (room.seats[1]?.userId === userId) return 1;
    return null;
  }

  seatOf(room: Room, tok: unknown): SeatIndex | null {
    if (typeof tok !== 'string') return null;
    if (room.seats[0]?.token === tok) return 0;
    if (room.seats[1]?.token === tok) return 1;
    return null;
  }

  private async startDuel(room: Room): Promise<void> {
    room.starting = true;
    this.broadcast(room);
    // Coin toss: who goes first.
    const first: SeatIndex = Math.random() < 0.5 ? 0 : 1;
    room.duelPlayerOfSeat = first === 0 ? [0, 1] : [1, 0];
    const bySeat = (player: SeatIndex): SeatIndex => (room.duelPlayerOfSeat[0] === player ? 0 : 1);
    const names: [string, string] = [room.seats[bySeat(0)]!.name, room.seats[bySeat(1)]!.name];
    room.session = await DuelSession.start(this.cards, {
      decks: [room.seats[bySeat(0)]!.deck, room.seats[bySeat(1)]!.deck],
      names,
    });
    room.starting = false;
    this.runClock(room);
    this.broadcast(room);
  }

  // ------------------------------------------------------------ clock

  /** Charges the thinking player's time and starts the clock of whoever must answer now. */
  private runClock(room: Room, answeredBy: 0 | 1 | null = null): void {
    const c = room.clock;
    const now = Date.now();
    if (c.running !== null) c.left[c.running] = Math.max(0, c.left[c.running] - (now - c.since));
    if (answeredBy !== null) c.left[answeredBy] += CLOCK_INCREMENT_MS;
    if (c.timer) clearTimeout(c.timer);
    c.timer = null;
    const s = room.session;
    const next = s && s.winner === null ? s.waitingFor : null;
    c.running = next;
    c.since = now;
    if (next !== null) {
      c.timer = setTimeout(() => {
        if (room.session?.winner !== null || c.running !== next) return;
        c.left[next] = 0;
        c.running = null;
        room.session.forfeit(next, 'ran out of time');
        this.broadcast(room);
      }, c.left[next] + 50);
      c.timer.unref?.();
    }
  }

  private clockView(room: Room): RoomState['clock'] {
    if (!room.session) return null;
    const c = room.clock;
    const now = Date.now();
    const left: [number, number] = [c.left[0], c.left[1]];
    if (c.running !== null) left[c.running] = Math.max(0, left[c.running] - (now - c.since));
    return { left, running: c.running, serverNow: now };
  }

  state(room: Room, seat: SeatIndex): RoomState {
    const s = room.session;
    return {
      roomId: room.id,
      seat,
      status: room.starting ? 'starting' : !s ? 'waiting' : s.winner !== null ? 'finished' : 'playing',
      seats: room.seats.map((st) => (st ? { name: st.name, connected: st.clients.size > 0 } : null)) as RoomState['seats'],
      view: s ? s.view(room.duelPlayerOfSeat[seat]) : null,
      ranked: room.ranked,
      clock: this.clockView(room),
    };
  }

  subscribe(room: Room, seat: SeatIndex, res: ServerResponse): void {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.write('retry: 2000\n\n');
    const s = room.seats[seat]!;
    s.clients.add(res);
    s.lastSeen = Date.now();
    res.on('close', () => {
      s.clients.delete(res);
      s.lastSeen = Date.now();
      this.broadcast(room);
    });
    this.broadcast(room);
  }

  /** Send every connected browser its own fresh view. */
  broadcast(room: Room): void {
    this.checkFinished(room);
    ([0, 1] as const).forEach((seat) => {
      const st = room.seats[seat];
      if (!st || st.clients.size === 0) return;
      const data = `data: ${JSON.stringify(this.state(room, seat))}\n\n`;
      for (const client of st.clients) client.write(data);
    });
  }

  answer(room: Room, seat: SeatIndex, decisionId: unknown, picks: unknown): { ok: true } | { ok: false; error: string } {
    if (!room.session) return { ok: false, error: 'The duel has not started yet.' };
    const p = picks === null ? null : Array.isArray(picks) ? (picks as number[]) : undefined;
    if (p === undefined || typeof decisionId !== 'number') return { ok: false, error: 'Bad answer format.' };
    const result = room.session.answer(decisionId, p, room.duelPlayerOfSeat[seat]);
    if (result.ok) {
      this.runClock(room, room.duelPlayerOfSeat[seat]);
      this.broadcast(room);
    }
    return result;
  }

  setChainMode(room: Room, seat: SeatIndex, mode: ChainMode): void {
    room.session?.setChainMode(room.duelPlayerOfSeat[seat], mode);
    this.broadcast(room);
  }

  /** A banned player loses every duel they are in right now. */
  forfeitUser(userId: number, reason: string): void {
    for (const room of this.rooms.values()) {
      const seat = this.seatOfUser(room, userId);
      if (seat === null || !room.session || room.session.winner !== null) continue;
      room.session.forfeit(room.duelPlayerOfSeat[seat], reason);
      this.runClock(room);
      this.broadcast(room);
    }
  }

  surrender(room: Room, seat: SeatIndex): void {
    room.session?.surrender(room.duelPlayerOfSeat[seat]);
    this.runClock(room);
    this.broadcast(room);
  }

  private checkFinished(room: Room): void {
    const s = room.session;
    if (!s || s.winner === null || this.recorded.has(room) || !room.seats[0] || !room.seats[1]) return;
    this.recorded.add(room);
    // duel players are seats reordered by the coin toss
    const userOf = (player: 0 | 1) => room.seats[room.duelPlayerOfSeat[0] === player ? 0 : 1]!.userId;
    const winner = s.winner === 0 || s.winner === 1 ? (s.winner as 0 | 1) : null;
    try {
      if (room.clock.timer) clearTimeout(room.clock.timer);
      this.onFinished?.([userOf(0), userOf(1)], winner, s.surrendered, room.ranked);
    } catch (e) {
      console.error('Could not record the duel result:', e);
    }
  }

  private housekeeping(): void {
    const now = Date.now();
    for (const [id, room] of this.rooms) {
      for (const st of room.seats) for (const client of st?.clients ?? []) client.write(': ping\n\n');
      // Left mid-duel: a player whose browser has been gone too long loses.
      if (room.session && room.session.winner === null) {
        ([0, 1] as const).forEach((seat) => {
          const st = room.seats[seat];
          if (st && st.clients.size === 0 && now - st.lastSeen > DISCONNECT_LOSS_MS && room.session!.winner === null) {
            room.session!.forfeit(room.duelPlayerOfSeat[seat], 'left the duel');
            this.runClock(room);
            this.broadcast(room);
          }
        });
      }
      const anyoneHere = room.seats.some((st) => st && st.clients.size > 0);
      const lastSeen = Math.max(...room.seats.map((st) => st?.lastSeen ?? 0));
      // Nobody here: drop finished duels after 30 minutes, unfinished ones (or never started) after 6 hours.
      const finished = !!room.session && room.session.winner !== null;
      if (!anyoneHere && now - lastSeen > (finished ? 30 * 60 * 1000 : 6 * 60 * 60 * 1000)) {
        if (room.clock.timer) clearTimeout(room.clock.timer);
        room.session?.dispose();
        this.rooms.delete(id);
      }
    }
  }
}
