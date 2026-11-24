// One duel in progress: drives the engine, keeps the log, and turns engine questions
// into simple menus for the browser. The server owns this object; the browser only
// sees GameView snapshots and sends back the ids of the choices the player picked.
import { randomUUID } from 'node:crypto';
import {
  OcgHintType,
  OcgLocation,
  OcgMessageType,
  OcgPhase,
  OcgPosition,
  OcgProcessResult,
  OcgQueryFlags,
  OcgResponseType,
  SelectBattleCMDAction,
  SelectIdleCMDAction,
  cardMatchesOpcode,
  type OcgCardQueryInfo,
  type OcgMessage,
  type OcgResponse,
} from 'ocgcore-wasm';
import type { CardDatabase } from '../engine/cardDb.ts';
import { LocalDuel } from '../engine/duel.ts';
import { WIN_REASONS, describeMessage } from '../engine/describe.ts';
import { createRng } from '../engine/random.ts';
import { SELECT_HINTS, attributeName, effectText, raceName } from '../engine/strings.ts';
import { cardText } from '../engine/cardText.ts';
import { counterName } from '../content/customCards.ts';
import { DECISION_TYPES, SimpleAi, attributeBits, freePlaces, raceBits } from '../ai/simpleAi.ts';
import { CARD_SCRIPTS_DIR } from '../paths.ts';
import type { DeckCodes } from '../decks/starters.ts';
import type { CardRef, CardText, CardView, ChainMode, ChoiceView, DecisionView, GameEvent, GameView, PlayerView } from './types.ts';

type Picks = number[] | null;

interface Pending {
  view: DecisionView;
  msg: OcgMessage;
  toResponse: (picks: Picks) => OcgResponse;
  /** Extra check of the answer (used by "declare a card name"). Returns an error message, or null. */
  check?: (picks: number[]) => string | null;
}

/** Why a card moved (ocgcore REASON_* flags). */
const REASON_DESTROY = 0x1;
const REASON_DRAW = 0x2000000;

const PHASES: Record<number, string> = {
  [OcgPhase.DRAW]: 'Draw Phase',
  [OcgPhase.STANDBY]: 'Standby Phase',
  [OcgPhase.MAIN1]: 'Main Phase 1',
  [OcgPhase.BATTLE_START]: 'Battle Phase',
  [OcgPhase.BATTLE_STEP]: 'Battle Phase',
  [OcgPhase.DAMAGE]: 'Battle Phase',
  [OcgPhase.DAMAGE_CAL]: 'Battle Phase',
  [OcgPhase.BATTLE]: 'Battle Phase',
  [OcgPhase.MAIN2]: 'Main Phase 2',
  [OcgPhase.END]: 'End Phase',
};

const LOCATION_LABEL: Record<number, string> = {
  [OcgLocation.DECK]: 'Deck',
  [OcgLocation.HAND]: 'Hand',
  [OcgLocation.MZONE]: 'Field',
  [OcgLocation.SZONE]: 'Field',
  [OcgLocation.GRAVE]: 'Graveyard',
  [OcgLocation.REMOVED]: 'Banished',
  [OcgLocation.EXTRA]: 'Extra Deck',
  [OcgLocation.OVERLAY]: 'Material',
};

const QUERY_FLAGS =
  OcgQueryFlags.CODE | OcgQueryFlags.POSITION | OcgQueryFlags.ATTACK | OcgQueryFlags.DEFENSE |
  OcgQueryFlags.IS_PUBLIC | OcgQueryFlags.OVERLAY_CARD | OcgQueryFlags.COUNTERS | OcgQueryFlags.ALIAS;

export interface SessionOptions {
  decks: [DeckCodes, DeckCodes];
  names: [string, string];
  seed?: number;
  /** Players controlled by the simple AI bot. */
  bots?: (0 | 1)[];
  /** Cards to start in each player's hand instead of drawing (admin test duels). */
  openingHands?: [number[], number[]];
}

export class DuelSession {
  readonly id = randomUUID();
  private readonly duel: LocalDuel;
  private readonly cards: CardDatabase;
  private readonly names: [string, string];
  private readonly autoAi: SimpleAi;
  /** Log lines. `to` = only that player may read it (e.g. a card only they were shown). */
  private readonly log: { text: string; to?: 0 | 1 }[] = [];
  /** Cards shown to players (excavated, revealed, looked at). Each viewer sees the ones meant for them. */
  private readonly reveals: { id: number; to?: 0 | 1; title: string; codes: number[] }[] = [];
  private nextRevealId = 1;
  private readonly lp: [number, number] = [8000, 8000];
  private turn = 0;
  private turnPlayer: 0 | 1 = 0;
  private phase = '';
  private pending: Pending | null = null;
  private lastDecisionMsg: OcgMessage | null = null;
  private lastPresented: Pending | null = null;
  private lastWasAuto = false;
  private nextDecisionId = 1;
  private selectHint: [string, string] = ['', ''];
  private readonly chainModes: [ChainMode, ChainMode] = ['smart', 'smart'];
  /** Number of chain links currently waiting to resolve. */
  private chainDepth = 0;
  /** True after a summon/attack/activation, until the next normal (idle/battle) move. */
  private responseWindow = false;
  /** Each player gets one "respond?" question per phase, even if nothing happened. */
  private phaseFresh: [boolean, boolean] = [false, false];
  /** Every card code in both Decks (the bot declares one of these when it must "declare a card name"). */
  private deckCodes: number[] = [];
  winner: number | null = null;
  /** The player who conceded, if the duel ended that way. */
  surrendered: 0 | 1 | null = null;
  private readonly bots = new Map<number, SimpleAi>();
  private disposed = false;
  /** Recent board events for the animations (all public), and how the duel ended. */
  private events: GameEvent[] = [];
  private nextEventId = 1;
  endReason: string | null = null;

  /** Frees the duel engine's memory. Only call it once nobody can reach this duel any more. */
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    try {
      this.duel.destroy();
    } catch (e) {
      console.error('Could not free a duel:', e);
    }
  }

  private constructor(duel: LocalDuel, cards: CardDatabase, names: [string, string], seed: number) {
    this.duel = duel;
    this.cards = cards;
    this.names = names;
    this.autoAi = new SimpleAi(createRng(seed ^ 0xa11));
  }

  static async start(cards: CardDatabase, options: SessionOptions): Promise<DuelSession> {
    const duel = await LocalDuel.create(cards, CARD_SCRIPTS_DIR, { decks: options.decks, seed: options.seed, openingHands: options.openingHands });
    const session = new DuelSession(duel, cards, options.names, duel.seed);
    for (const p of options.bots ?? []) session.bots.set(p, new SimpleAi(createRng(duel.seed ^ (0xb07 + p))));
    session.deckCodes = [...new Set(options.decks.flatMap((d) => [...d.main, ...d.extra]))];
    session.run();
    return session;
  }

  /** Apply the player's answer to the current question. */
  answer(decisionId: number, picks: Picks, asPlayer?: 0 | 1): { ok: true } | { ok: false; error: string } {
    const pending = this.pending;
    if (!pending) return { ok: false, error: 'There is no question to answer right now.' };
    if (asPlayer !== undefined && pending.view.player !== asPlayer) return { ok: false, error: "It's not your decision." };
    if (decisionId !== pending.view.id) return { ok: false, error: 'That question was already answered.' };
    const problem = validatePicks(pending.view, picks) ?? (picks && pending.check ? pending.check(picks) : null);
    if (problem) return { ok: false, error: problem };
    const response = pending.toResponse(picks);
    this.pending = null;
    this.lastWasAuto = false;
    this.duel.respond(response);
    this.run();
    return { ok: true };
  }

  setChainMode(player: 0 | 1, mode: ChainMode): void {
    this.chainModes[player] = mode;
  }

  /** Concede the duel for one player. */
  surrender(player: 0 | 1): void {
    if (this.winner !== null) return;
    this.winner = 1 - player;
    this.surrendered = player;
    this.pending = null;
    this.endReason = `${this.names[player]} surrendered`;
    this.log.push({ text: `\n*** ${this.names[player]} surrendered. ${this.names[1 - player]} wins! ***` });
  }

  /** A player loses without surrendering (ran out of time, left the duel). */
  forfeit(player: 0 | 1, reason: string): void {
    if (this.winner !== null) return;
    this.winner = 1 - player;
    this.pending = null;
    this.endReason = `${this.names[player]} ${reason}`;
    this.log.push({ text: `\n*** ${this.names[player]} ${reason}. ${this.names[1 - player]} wins! ***` });
  }

  // ---------------------------------------------------------------- engine loop

  private run(): void {
    for (let guard = 0; guard < 10000; guard++) {
      if (this.winner !== null) return;
      const { status, messages } = this.duel.advance();
      let retry = false;
      for (const msg of messages) {
        this.track(msg);
        if (msg.type === OcgMessageType.RETRY) retry = true;
      }
      if (status === OcgProcessResult.END || this.duel.winner !== null) {
        this.winner = this.duel.winner ?? this.winner;
        this.pending = null;
        return;
      }

      if (retry && this.lastDecisionMsg) {
        if (this.lastWasAuto || !this.lastPresented) {
          this.duel.respond(this.autoAi.choose(this.lastDecisionMsg));
          continue;
        }
        // The player's answer was not allowed: ask the same question again.
        this.pending = { ...this.lastPresented, view: { ...this.lastPresented.view, id: this.nextDecisionId++, error: "That choice isn't allowed. Please try again." } };
        return;
      }

      const msg = [...messages].reverse().find((m) => DECISION_TYPES.has(m.type));
      if (!msg) throw new Error('The engine is waiting for an answer but did not ask a question.');
      this.lastDecisionMsg = msg;

      const auto = this.autoAnswer(msg);
      if (auto) {
        this.lastWasAuto = true;
        this.duel.respond(auto);
        continue;
      }
      const asking = 'player' in msg ? (msg.player as number) : 0;
      const bot = this.bots.get(asking);
      if (bot) {
        // The bot decides instantly; nothing is shown to anyone.
        this.lastWasAuto = true;
        this.duel.respond(msg.type === OcgMessageType.ANNOUNCE_CARD ? this.botDeclare(msg) : bot.choose(msg));
        continue;
      }
      this.lastWasAuto = false;
      this.pending = this.buildDecision(msg);
      // A "Select ..." hint belongs to the one question right after it; don't reuse it for later ones.
      this.selectHint = ['', ''];
      this.lastPresented = this.pending;
      return;
    }
    throw new Error('The duel engine did not settle (too many automatic steps).');
  }

  private track(msg: OcgMessage): void {
    switch (msg.type) {
      case OcgMessageType.NEW_TURN:
        this.turn++;
        this.turnPlayer = msg.player as 0 | 1;
        this.autoAi.newTurn();
        for (const bot of this.bots.values()) bot.newTurn();
        break;
      case OcgMessageType.NEW_PHASE:
        this.phase = PHASES[msg.phase] ?? this.phase;
        // Phase stops (smart mode): ask once at the Standby Phase, the start of the Battle Phase and the End Phase.
        // Other phases only stop when something happens. "Always" mode asks whenever a response is possible.
        this.phaseFresh = msg.phase === OcgPhase.STANDBY || msg.phase === OcgPhase.BATTLE_START || msg.phase === OcgPhase.END
          ? [true, true] : [false, false];
        break;
      case OcgMessageType.LPUPDATE:
        this.lp[msg.player as 0 | 1] = msg.lp;
        break;
      case OcgMessageType.DAMAGE:
      case OcgMessageType.PAY_LPCOST:
        this.lp[msg.player as 0 | 1] = Math.max(0, this.lp[msg.player as 0 | 1] - msg.amount);
        if (msg.type === OcgMessageType.DAMAGE) this.addEvent({ kind: 'damage', player: msg.player as 0 | 1, amount: msg.amount });
        break;
      case OcgMessageType.RECOVER:
        this.lp[msg.player as 0 | 1] += msg.amount;
        this.addEvent({ kind: 'recover', player: msg.player as 0 | 1, amount: msg.amount });
        break;
      case OcgMessageType.CHAINING:
        this.chainDepth = msg.chain_size;
        this.responseWindow = true;
        this.addEvent({ kind: 'activate', player: msg.controller, code: msg.code, at: { controller: msg.controller, location: msg.location, sequence: msg.sequence } });
        break;
      case OcgMessageType.MOVE:
        this.trackMove(msg);
        break;
      case OcgMessageType.WIN:
        {
          const loser = this.names[1 - msg.player] ?? 'The opponent';
          this.endReason = msg.player === 2 ? 'Both players lost at the same time'
            : msg.reason === 1 ? `${loser}'s LP reached 0`
            : msg.reason === 2 ? `${loser} could not draw a card`
            : msg.reason >= 0x10 ? `${this.names[msg.player]} won with a card effect`
            : (WIN_REASONS[msg.reason] ?? 'The duel ended').replace(/^opponent/, loser);
        }
        break;
      case OcgMessageType.CHAIN_END:
        this.chainDepth = 0;
        break;
      // "is being Summoned" (the moment Solemn-style cards can negate it) and "was Summoned"
      case OcgMessageType.SUMMONING:
      case OcgMessageType.SPSUMMONING:
      case OcgMessageType.FLIPSUMMONING:
      case OcgMessageType.SUMMONED:
      case OcgMessageType.SPSUMMONED:
      case OcgMessageType.FLIPSUMMONED:
      case OcgMessageType.ATTACK:
        this.responseWindow = true;
        break;
      case OcgMessageType.HINT:
        if (msg.hint_type === OcgHintType.SELECTMSG && (msg.player === 0 || msg.player === 1)) {
          this.selectHint[msg.player] = SELECT_HINTS[Number(msg.hint)] ?? effectText(msg.hint, this.cards) ?? '';
        }
        break;
    }
    this.trackReveal(msg);
    const line = describeMessage(msg, this.cards, this.names);
    if (line) this.log.push({ text: line });
    if (this.log.length > 400) this.log.splice(0, this.log.length - 400);
  }

  private addEvent(e: Omit<GameEvent, 'id'> & Record<string, unknown>): void {
    this.events.push({ id: this.nextEventId++, ...e } as GameEvent);
    if (this.events.length > 60) this.events.splice(0, this.events.length - 60);
  }

  /** Cards leaving the field, going to the hand, being banished...: one event each (code only if public). */
  private trackMove(msg: OcgMessage & { type: OcgMessageType.MOVE }): void {
    const from = msg.from, to = msg.to;
    if (!from.location || from.location === to.location || (msg.reason & REASON_DRAW)) return;
    const FIELD = OcgLocation.MZONE | OcgLocation.SZONE;
    const faceUp = (pos: number) => (pos & (OcgPosition.FACEUP_ATTACK | OcgPosition.FACEUP_DEFENSE)) !== 0;
    const fromField = (from.location & FIELD) !== 0;
    let kind: 'destroyed' | 'to-grave' | 'to-hand' | 'banished' | 'to-deck' | null = null;
    if (fromField && (msg.reason & REASON_DESTROY)) kind = 'destroyed';
    else if (to.location === OcgLocation.HAND) kind = 'to-hand';
    else if (to.location === OcgLocation.REMOVED) kind = 'banished';
    else if (to.location === OcgLocation.GRAVE && (fromField || from.location === OcgLocation.HAND)) kind = 'to-grave';
    else if ((to.location === OcgLocation.DECK || to.location === OcgLocation.EXTRA) && (fromField || from.location === OcgLocation.GRAVE)) kind = 'to-deck';
    if (!kind) return;
    // Everyone may see the card if it was face-up before, or ends up face-up where everyone can look.
    const wasPublic = (fromField && faceUp(from.position)) || from.location === OcgLocation.GRAVE || (from.location === OcgLocation.REMOVED && faceUp(from.position));
    const nowPublic = to.location === OcgLocation.GRAVE || (to.location === OcgLocation.REMOVED && faceUp(to.position));
    this.addEvent({
      kind, player: from.controller, code: wasPublic || nowPublic ? msg.card : 0,
      from: { controller: from.controller, location: from.location, sequence: from.sequence },
      to: { controller: to.controller, location: to.location, sequence: to.sequence },
    });
  }

  /**
   * Cards shown by an effect. CONFIRM_DECKTOP (excavate) is shown to both players;
   * CONFIRM_CARDS is shown to msg.player only (plus the owner, if it's a card in their hand).
   */
  private trackReveal(msg: OcgMessage): void {
    if (msg.type !== OcgMessageType.CONFIRM_DECKTOP && msg.type !== OcgMessageType.CONFIRM_CARDS) return;
    const codes = msg.cards.map((c) => c.code).filter((c) => c > 0);
    if (!codes.length) return;
    const list = codes.map((c) => this.cards.name(c)).join(', ');
    const who = (p: number) => this.names[p] ?? `Player ${p + 1}`;
    const add = (title: string, to?: 0 | 1) => {
      this.reveals.push({ id: this.nextRevealId++, to, title, codes });
      if (this.reveals.length > 20) this.reveals.shift();
      this.log.push({ text: `  ${title}: ${list}`, to });
    };
    if (msg.type === OcgMessageType.CONFIRM_DECKTOP) {
      add(`${who(msg.player)} reveals the top ${codes.length === 1 ? 'card' : `${codes.length} cards`} of their Deck`);
      return;
    }
    const seer = msg.player as 0 | 1;
    const first = msg.cards[0]!;
    const owner = first.controller as 0 | 1;
    const where = first.location === OcgLocation.HAND ? 'hand' : first.location === OcgLocation.DECK ? 'Deck' : 'field';
    if (owner === seer) {
      add(`${who(seer)} looks at a card in their ${where}`, seer);
    } else if (first.location === OcgLocation.DECK || first.location === OcgLocation.EXTRA) {
      // Their Deck: the owner doesn't know these cards either, so only the one looking sees them.
      add(`${who(seer)} looks at ${who(owner)}'s ${where}`, seer);
    } else {
      // A card in someone's hand or a Set card: its owner already knows it, so both players see the line.
      add(`${who(seer)} looks at ${codes.length === 1 ? 'a card' : `${codes.length} cards`} in ${who(owner)}'s ${where}`);
    }
  }

  /** Can this card be declared for this "declare a card name" question? */
  private declarable(code: number, opcodes: bigint[]): boolean {
    const info = this.cards.get(code);
    if (!info || info.data.alias !== 0 || Number(info.data.type) & 0x4000 /* token */) return false;
    return opcodes.length === 0 || cardMatchesOpcode(info.data, opcodes);
  }

  /** A bot declaring a card name: a random card from the two Decks that fits. */
  private botDeclare(msg: OcgMessage & { type: OcgMessageType.ANNOUNCE_CARD }): OcgResponse {
    const ok = this.deckCodes.filter((c) => this.declarable(c, msg.opcodes));
    const pool = ok.length ? ok : [...this.cards.cards.keys()].filter((c) => this.declarable(c, msg.opcodes)).slice(0, 50);
    return { type: OcgResponseType.ANNOUNCE_CARD, card: pool[Math.floor(Math.random() * pool.length)] ?? 0 };
  }

  /** Questions with no real choice (or that we don't ask players yet) are answered automatically. */
  private autoAnswer(msg: OcgMessage): OcgResponse | null {
    switch (msg.type) {
      case OcgMessageType.SELECT_IDLECMD:
      case OcgMessageType.SELECT_BATTLECMD:
        // A normal move is starting: the "something just happened" window is over.
        this.responseWindow = false;
        return null;
      case OcgMessageType.SELECT_CHAIN: {
        const pass: OcgResponse = { type: OcgResponseType.SELECT_CHAIN, index: null };
        if (msg.forced) return null;
        if (msg.selects.length === 0) return pass;
        const mode = this.chainModes[msg.player as 0 | 1];
        if (mode === 'always') return null;
        if (mode === 'never') return pass;
        // smart: ask when a trigger is waiting, a chain is open, something just happened,
        // or (once per phase) when a new phase starts.
        if (msg.spe_count > 0 || this.chainDepth > 0 || this.responseWindow) return null;
        if (this.phaseFresh[msg.player as 0 | 1]) {
          this.phaseFresh[msg.player as 0 | 1] = false;
          return null;
        }
        return pass;
      }
      case OcgMessageType.SELECT_PLACE:
      case OcgMessageType.SELECT_DISFIELD: {
        const free = freePlaces(msg.player, msg.field_mask);
        const count = Math.max(1, msg.count);
        // Only ask when there is a real choice; more than one zone at once is rare, so pick those automatically.
        if (free.length > count && count === 1) return null;
        const own = free.filter((p) => p.player === msg.player);
        const theirs = free.filter((p) => p.player !== msg.player);
        const preferred = msg.type === OcgMessageType.SELECT_PLACE ? own : theirs;
        const pool = preferred.length >= count ? preferred : free;
        const places = pool.slice(0, count);
        return msg.type === OcgMessageType.SELECT_PLACE
          ? { type: OcgResponseType.SELECT_PLACE, places }
          : { type: OcgResponseType.SELECT_DISFIELD, places };
      }
      case OcgMessageType.SELECT_POSITION: {
        const options = positionOptions(msg.positions);
        return options.length === 1 ? { type: OcgResponseType.SELECT_POSITION, position: options[0]![0] } : null;
      }
      case OcgMessageType.SELECT_COUNTER:
      case OcgMessageType.SORT_CARD:
      case OcgMessageType.SORT_CHAIN:
      case OcgMessageType.ROCK_PAPER_SCISSORS:
      case OcgMessageType.ANNOUNCE_NUMBER:
        return this.autoAi.choose(msg);
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------- questions

  private ref(c: { controller: 0 | 1; location: number; sequence: number; code: number }): CardRef {
    return { controller: c.controller, location: c.location, sequence: c.sequence, code: c.code };
  }

  private cardLabel(code: number): string {
    return code ? this.cards.name(code) : 'Face-down card';
  }

  private buildDecision(msg: OcgMessage): Pending {
    const id = this.nextDecisionId++;
    const responses: OcgResponse[] = [];
    const choices: ChoiceView[] = [];
    const add = (label: string, response: OcgResponse, card?: CardRef, detail?: string) => {
      choices.push({ id: responses.length, label, card, detail });
      responses.push(response);
    };
    const menu = (player: number, kind: string, prompt: string, canCancel = false, cancel?: OcgResponse): Pending => ({
      msg,
      view: { id, player: player as 0 | 1, mode: 'menu', kind, prompt, choices, min: 1, max: 1, canCancel },
      toResponse: (picks) => (picks === null ? cancel! : responses[picks[0]!]!),
    });
    const hint = (player: number, fallback: string) => this.selectHint[player as 0 | 1] || fallback;
    const describe = (desc: bigint) => effectText(desc, this.cards) ?? undefined;

    switch (msg.type) {
      case OcgMessageType.SELECT_IDLECMD: {
        const idle = (action: SelectIdleCMDAction, index: number | null): OcgResponse => ({ type: OcgResponseType.SELECT_IDLECMD, action, index });
        msg.summons.forEach((c, i) => add('Normal Summon', idle(SelectIdleCMDAction.SELECT_SUMMON, i), this.ref(c)));
        // Copies of the same card in the Deck (Vaporeon's Deck summon) would each be listed: show one per name.
        const deckSeen = new Set<number>();
        msg.special_summons.forEach((c, i) => {
          if (c.location === OcgLocation.DECK) { if (deckSeen.has(c.code)) return; deckSeen.add(c.code); }
          add('Special Summon', idle(SelectIdleCMDAction.SELECT_SPECIAL_SUMMON, i), this.ref(c));
        });
        msg.monster_sets.forEach((c, i) => add('Set', idle(SelectIdleCMDAction.SELECT_MONSTER_SET, i), this.ref(c)));
        msg.activates.forEach((c, i) => add('Activate', idle(SelectIdleCMDAction.SELECT_ACTIVATE, i), this.ref(c), describe(c.description)));
        msg.spell_sets.forEach((c, i) => add('Set', idle(SelectIdleCMDAction.SELECT_SPELL_SET, i), this.ref(c)));
        msg.pos_changes.forEach((c, i) => add('Change position', idle(SelectIdleCMDAction.SELECT_POS_CHANGE, i), this.ref(c)));
        if (msg.to_bp) add('Battle Phase', idle(SelectIdleCMDAction.TO_BP, null));
        if (msg.to_ep) add('End Turn', idle(SelectIdleCMDAction.TO_EP, null));
        return menu(msg.player, 'idle', 'Your move');
      }
      case OcgMessageType.SELECT_BATTLECMD: {
        const battle = (action: SelectBattleCMDAction, index: number | null): OcgResponse => ({ type: OcgResponseType.SELECT_BATTLECMD, action, index });
        msg.attacks.forEach((c, i) => add(c.can_direct ? 'Attack (direct possible)' : 'Attack', battle(SelectBattleCMDAction.SELECT_BATTLE, i), this.ref(c)));
        msg.chains.forEach((c, i) => add('Activate', battle(SelectBattleCMDAction.SELECT_CHAIN, i), this.ref(c), describe(c.description)));
        if (msg.to_m2) add('Main Phase 2', battle(SelectBattleCMDAction.TO_M2, null));
        if (msg.to_ep) add('End Turn', battle(SelectBattleCMDAction.TO_EP, null));
        return menu(msg.player, 'battle', 'Battle Phase');
      }
      case OcgMessageType.SELECT_CHAIN: {
        msg.selects.forEach((c, i) => add('Activate', { type: OcgResponseType.SELECT_CHAIN, index: i }, this.ref(c), describe(c.description)));
        if (!msg.forced) add("Don't activate", { type: OcgResponseType.SELECT_CHAIN, index: null });
        return menu(msg.player, 'chain', msg.forced ? 'Choose an effect to activate' : 'Do you want to activate a card or effect?');
      }
      case OcgMessageType.SELECT_EFFECTYN: {
        const text = describe(msg.description);
        add('Yes', { type: OcgResponseType.SELECT_EFFECTYN, yes: true }, this.ref(msg));
        add('No', { type: OcgResponseType.SELECT_EFFECTYN, yes: false });
        return menu(msg.player, 'yesno', `Use the effect of ${this.cardLabel(msg.code)}?${text ? `\n${text}` : ''}`);
      }
      case OcgMessageType.SELECT_YESNO: {
        add('Yes', { type: OcgResponseType.SELECT_YESNO, yes: true });
        add('No', { type: OcgResponseType.SELECT_YESNO, yes: false });
        return menu(msg.player, 'yesno', describe(msg.description) ?? 'Do you want to continue?');
      }
      case OcgMessageType.SELECT_OPTION: {
        msg.options.forEach((opt, i) => add(describe(opt) ?? `Option ${i + 1}`, { type: OcgResponseType.SELECT_OPTION, index: i }));
        return menu(msg.player, 'option', hint(msg.player, 'Select an option'));
      }
      case OcgMessageType.ANNOUNCE_CARD: {
        // The player types a name; the page searches /api/card-names and sends the card's code.
        const opcodes = msg.opcodes;
        return {
          msg,
          view: { id, player: msg.player as 0 | 1, mode: 'declare', kind: 'declare', prompt: 'Declare a card name', choices: [], min: 1, max: 1, canCancel: false },
          toResponse: (picks) => ({ type: OcgResponseType.ANNOUNCE_CARD, card: picks![0]! }),
          check: (picks) => (picks.length === 1 && this.declarable(picks[0]!, opcodes) ? null : "That card can't be declared here."),
        };
      }
      case OcgMessageType.ANNOUNCE_RACE: {
        // Declaring several Types at once isn't used by any card yet: the simple AI answers that.
        if (msg.count !== 1) { add('OK', this.autoAi.choose(msg)); return menu(msg.player, 'other', 'Continue'); }
        for (const race of raceBits(msg.available)) add(raceName(race), { type: OcgResponseType.ANNOUNCE_RACE, races: [race as never] });
        return menu(msg.player, 'option', 'Declare a Type');
      }
      case OcgMessageType.ANNOUNCE_ATTRIB: {
        if (msg.count !== 1) { add('OK', this.autoAi.choose(msg)); return menu(msg.player, 'other', 'Continue'); }
        for (const attr of attributeBits(msg.available)) add(attributeName(attr), { type: OcgResponseType.ANNOUNCE_ATTRIB, attributes: [attr as never] });
        return menu(msg.player, 'option', 'Declare an Attribute');
      }
      case OcgMessageType.SELECT_PLACE:
      case OcgMessageType.SELECT_DISFIELD: {
        const isPlace = msg.type === OcgMessageType.SELECT_PLACE;
        for (const place of freePlaces(msg.player, msg.field_mask)) {
          const response: OcgResponse = isPlace
            ? { type: OcgResponseType.SELECT_PLACE, places: [place] }
            : { type: OcgResponseType.SELECT_DISFIELD, places: [place] };
          add(zoneName(place.location, place.sequence), response, {
            controller: place.player as 0 | 1, location: place.location, sequence: place.sequence, code: 0,
          });
        }
        return menu(msg.player, 'place', isPlace ? hint(msg.player, 'Select a zone') : 'Select a zone to disable');
      }
      case OcgMessageType.SELECT_POSITION: {
        for (const [pos, label] of positionOptions(msg.positions)) add(label, { type: OcgResponseType.SELECT_POSITION, position: pos });
        return menu(msg.player, 'position', `Choose the battle position for ${this.cardLabel(msg.code)}`);
      }
      case OcgMessageType.SELECT_UNSELECT_CARD: {
        msg.select_cards.forEach((c, i) => add('Select', { type: OcgResponseType.SELECT_UNSELECT_CARD, index: i }, this.ref(c)));
        msg.unselect_cards.forEach((c, i) => add('Unselect', { type: OcgResponseType.SELECT_UNSELECT_CARD, index: msg.select_cards.length + i }, this.ref(c)));
        if (msg.can_finish) add('Finish', { type: OcgResponseType.SELECT_UNSELECT_CARD, index: null });
        return menu(msg.player, 'select_unselect', hint(msg.player, 'Select a card'), msg.can_cancel, { type: OcgResponseType.SELECT_UNSELECT_CARD, index: null });
      }
      case OcgMessageType.SELECT_CARD:
      case OcgMessageType.SELECT_TRIBUTE:
      case OcgMessageType.SELECT_SUM: {
        const selects = msg.selects as { controller: 0 | 1; location: number; sequence: number; code: number; amount?: number }[];
        selects.forEach((c, i) => choices.push({ id: i, label: this.cardLabel(c.code), card: this.ref(c), detail: c.amount ? `Value ${c.amount & 0xffff}` : undefined }));
        let prompt = hint(msg.player, msg.type === OcgMessageType.SELECT_TRIBUTE ? 'Select the monster(s) to Tribute' : 'Select card(s)');
        let min = msg.min;
        let max = msg.max;
        let canCancel = false;
        if (msg.type === OcgMessageType.SELECT_SUM) {
          prompt += ` (values must add up to ${msg.select_max ? 'at least ' : ''}${msg.amount})`;
          min = Math.max(1, msg.min);
          max = Math.max(min, msg.max || selects.length);
        } else {
          canCancel = msg.can_cancel;
        }
        const type = msg.type;
        return {
          msg,
          view: {
            id, player: msg.player as 0 | 1, mode: 'multi', kind: 'select_card', prompt, choices, canCancel,
            // Some cards count as 2 Tributes, so the engine's minimum can exceed the number of cards.
            min: Math.min(Math.max(min, 0), selects.length),
            max: Math.max(Math.min(Math.max(min, 0), selects.length), Math.min(Math.max(max, 1), selects.length)),
          },
          toResponse: (picks) => {
            const indicies = picks ? [...picks].sort((a, b) => a - b) : null;
            if (type === OcgMessageType.SELECT_SUM) return { type: OcgResponseType.SELECT_SUM, indicies: indicies ?? [] };
            if (type === OcgMessageType.SELECT_TRIBUTE) return { type: OcgResponseType.SELECT_TRIBUTE, indicies };
            return { type: OcgResponseType.SELECT_CARD, indicies };
          },
        };
      }
      default: {
        // Anything else: let the simple AI answer, but still show it as a one-button confirmation.
        const response = this.autoAi.choose(msg);
        add('OK', response);
        return menu('player' in msg ? (msg.player as number) : 0, 'other', 'Continue');
      }
    }
  }

  // ---------------------------------------------------------------- board snapshot

  /**
   * Snapshot of the duel as one player is allowed to see it.
   * viewer 'all' = test mode (one person plays both sides and sees everything).
   */
  view(viewer: 0 | 1 | 'all' = 'all'): GameView {
    const used = new Set<number>();
    /** Board positions whose card identity is hidden from this viewer. */
    const hidden = new Set<string>();
    const keyOf = (controller: number, location: number, sequence: number) => `${controller}:${location}:${sequence}`;
    const seesAll = viewer === 'all';

    const toView = (c: Partial<OcgCardQueryInfo> | null, controller: 0 | 1, location: OcgLocation, sequence: number): CardView | null => {
      if (!c) return null;
      const position = c.position ?? OcgPosition.FACEUP_ATTACK;
      const faceDown = (position & OcgPosition.FACEDOWN) !== 0;
      const secret = !seesAll && controller !== viewer && !c.isPublic && (location === OcgLocation.HAND || faceDown);
      if (secret) {
        hidden.add(keyOf(controller, location, sequence));
        return { code: 0, faceDown: true, defense: (position & OcgPosition.DEFENSE) !== 0 };
      }
      // ALIAS = the card's current name when an effect changed it (e.g. Psyduck's "No Weather Condition").
      const code = (c.alias && this.cards.get(c.alias) ? c.alias : c.code) ?? 0;
      if (code) used.add(code);
      return {
        code,
        faceDown,
        defense: (position & OcgPosition.DEFENSE) !== 0,
        atk: c.attack,
        def: c.defense,
        overlays: c.overlayCards?.length || undefined,
        counters: readCounters(c.counters),
      };
    };
    const query = (p: 0 | 1, loc: OcgLocation) => this.duel.queryLocation(p, loc, QUERY_FLAGS).map((c, i) => toView(c, p, loc, i));
    const list = (p: 0 | 1, loc: OcgLocation) => query(p, loc).filter((c): c is CardView => c !== null);
    const zones = (p: 0 | 1, loc: OcgLocation, size: number) => {
      const raw = query(p, loc);
      return Array.from({ length: size }, (_, i) => raw[i] ?? null);
    };
    const player = (p: 0 | 1): PlayerView => ({
      name: this.names[p],
      lp: Math.max(0, this.lp[p]),
      deckCount: this.duel.queryCount(p, OcgLocation.DECK),
      extraCount: this.duel.queryCount(p, OcgLocation.EXTRA),
      hand: list(p, OcgLocation.HAND),
      monsters: zones(p, OcgLocation.MZONE, 7),
      spells: zones(p, OcgLocation.SZONE, 8),
      grave: list(p, OcgLocation.GRAVE),
      banished: list(p, OcgLocation.REMOVED),
      // Your own Extra Deck is visible to you; the opponent's only as a count.
      extra: seesAll || p === viewer ? list(p, OcgLocation.EXTRA) : [],
      chainMode: this.chainModes[p],
    });
    const players: [PlayerView, PlayerView] = [player(0), player(1)];

    let decision: DecisionView | null = null;
    const pending = this.pending?.view ?? null;
    if (pending && (seesAll || pending.player === viewer)) {
      decision = {
        ...pending,
        choices: pending.choices.map((c) => {
          if (!c.card || seesAll || c.card.controller === viewer) return c;
          const secretPile = c.card.location === OcgLocation.DECK || c.card.location === OcgLocation.EXTRA;
          return hidden.has(keyOf(c.card.controller, c.card.location, c.card.sequence)) || secretPile
            ? { ...c, card: { ...c.card, code: 0 } }
            : c;
        }),
      };
      decision.choices.forEach((c) => c.card?.code && used.add(c.card.code));
    }

    const visibleReveals = this.reveals.filter((r) => seesAll || r.to === undefined || r.to === viewer)
      .slice(-5).map(({ id, title, codes }) => ({ id, title, codes }));
    for (const r of visibleReveals) r.codes.forEach((c) => used.add(c));
    const recentEvents = this.events.slice(-30);
    for (const e of recentEvents) if ('code' in e && e.code) used.add(e.code);
    const cards: Record<number, CardText> = {};
    for (const code of used) {
      const text = cardText(this.cards, code);
      if (text) cards[code] = text;
    }
    return {
      id: this.id,
      viewer: seesAll ? null : viewer,
      turn: this.turn,
      turnPlayer: this.turnPlayer,
      phase: this.phase,
      players,
      decision,
      waitingFor: this.winner === null && pending ? pending.player : null,
      log: this.log.filter((l) => seesAll || l.to === undefined || l.to === viewer).map((l) => l.text),
      reveals: visibleReveals,
      winner: this.winner,
      endReason: this.winner === null ? null : this.endReason,
      events: recentEvents,
      cards,
    };
  }

  /** Which player must answer right now (null if nobody). */
  get waitingFor(): 0 | 1 | null {
    return this.winner === null && this.pending ? this.pending.view.player : null;
  }
}

/**
 * ocgcore-wasm 0.1.7 reads counters backwards: it returns { count: type } instead of { type: count }.
 * We turn it around here. (Limitation: two counter types with the same count on one card collide.)
 */
function readCounters(raw: Record<number, number> | undefined): { name: string; count: number }[] | undefined {
  if (!raw) return undefined;
  const list = Object.entries(raw)
    .map(([count, type]) => ({ name: counterName(Number(type)), count: Number(count) }))
    .filter((x) => x.count > 0);
  return list.length ? list : undefined;
}

function zoneName(location: number, sequence: number): string {
  if (location === OcgLocation.MZONE) return sequence >= 5 ? 'Extra Monster Zone' : `Monster Zone ${sequence + 1}`;
  if (sequence === 5) return 'Field Zone';
  if (sequence >= 6) return 'Pendulum Zone';
  return `Spell & Trap Zone ${sequence + 1}`;
}

function positionOptions(mask: number): [number, string][] {
  const all: [number, string][] = [
    [OcgPosition.FACEUP_ATTACK, 'Face-up Attack'],
    [OcgPosition.FACEDOWN_ATTACK, 'Face-down Attack'],
    [OcgPosition.FACEUP_DEFENSE, 'Face-up Defense'],
    [OcgPosition.FACEDOWN_DEFENSE, 'Face-down Defense'],
  ];
  return all.filter(([p]) => (mask & p) !== 0);
}

function validatePicks(view: DecisionView, picks: Picks): string | null {
  if (picks === null) return view.canCancel ? null : 'This choice cannot be cancelled.';
  if (view.mode === 'declare') return Array.isArray(picks) && picks.length === 1 && Number.isInteger(picks[0]) ? null : 'Pick a card.';
  if (!Array.isArray(picks) || picks.some((p) => !Number.isInteger(p) || p < 0 || p >= view.choices.length)) {
    return 'Invalid choice.';
  }
  if (new Set(picks).size !== picks.length) return 'You picked the same card twice.';
  if (view.mode === 'menu' && picks.length !== 1) return 'Pick exactly one option.';
  if (view.mode === 'multi' && (picks.length < view.min || picks.length > view.max)) {
    return view.min === view.max ? `Select exactly ${view.min}.` : `Select between ${view.min} and ${view.max}.`;
  }
  return null;
}

export { LOCATION_LABEL };
