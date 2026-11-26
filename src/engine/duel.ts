// Wraps the ocgcore engine: creates a duel, adds the decks, and steps it forward.
import createCore, {
  OcgDuelMode,
  OcgLocation,
  OcgMessageType,
  OcgPosition,
  OcgProcessResult,
  type OcgCardQueryInfo,
  type OcgCoreSync,
  type OcgDuelHandle,
  type OcgMessage,
  type OcgResponse,
} from 'ocgcore-wasm';
import type { CardDatabase } from './cardDb.ts';
import type { DeckCodes } from '../decks/starters.ts';
import { createScriptReader } from './scriptReader.ts';
import { createRng, shuffle } from './random.ts';

let corePromise: Promise<OcgCoreSync> | null = null;
export function getCore(): Promise<OcgCoreSync> {
  corePromise ??= createCore({ sync: true });
  return corePromise;
}

export interface DuelSetup {
  /** Decks for player 0 (goes first) and player 1. */
  decks: [DeckCodes, DeckCodes];
  seed?: number;
  startingLP?: number;
  /** Cards placed directly in each player's starting hand (they then draw fewer). */
  openingHands?: [number[], number[]];
}

export interface StepResult {
  status: OcgProcessResult;
  messages: OcgMessage[];
}

export class LocalDuel {
  readonly seed: number;
  /** Script/engine error messages collected during the duel. */
  readonly errors: string[];
  private readonly lib: OcgCoreSync;
  private readonly handle: OcgDuelHandle;
  /** Every answer given to the engine so far, in order. Seed + setup + these answers = this exact duel again. */
  readonly history: OcgResponse[] = [];
  /** How the duel was set up (to make copies of it). */
  setup!: DuelSetup;
  private constructor(lib: OcgCoreSync, handle: OcgDuelHandle, seed: number, errors: string[]) {
    this.lib = lib;
    this.handle = handle;
    this.seed = seed;
    this.errors = errors;
  }

  /**
   * A separate, identical copy of this duel (same seed, decks and answers), for trying moves out
   * without touching the real duel. The copy is at the same decision point as this duel.
   */
  async copy(cards: CardDatabase, scriptRoot: string, upTo = this.history.length): Promise<LocalDuel> {
    const twin = await LocalDuel.create(cards, scriptRoot, { ...this.setup, seed: this.seed });
    let i = 0;
    for (;;) {
      const { status } = twin.advance();
      if (status === OcgProcessResult.END || i >= upTo) break;
      twin.respond(this.history[i++]!);
    }
    return twin;
  }

  static async create(cards: CardDatabase, scriptRoot: string, setup: DuelSetup): Promise<LocalDuel> {
    const lib = await getCore();
    const seed = setup.seed ?? Math.floor(Math.random() * 2 ** 31);
    const rng = createRng(seed);
    const big = () => BigInt(Math.floor(rng() * 2 ** 32)) * 2n ** 32n + BigInt(Math.floor(rng() * 2 ** 32)) + 1n;
    const readScript = createScriptReader(scriptRoot);
    const errors: string[] = [];
    const team = (p: 0 | 1) => ({
      startingLP: setup.startingLP ?? 8000,
      startingDrawCount: Math.max(0, 5 - (setup.openingHands?.[p].length ?? 0)),
      drawCountPerTurn: 1,
    });

    const handle = lib.createDuel({
      // Master Rule 5 (current official rules): Extra Monster Zones, Link arrows, Pendulum Zones in the S/T row.
      flags: OcgDuelMode.MODE_MR5,
      seed: [big(), big(), big(), big()],
      team1: team(0),
      team2: team(1),
      cardReader: (code) => cards.get(code)?.data ?? null,
      scriptReader: (name) => readScript(name),
      errorHandler: (type, text) => errors.push(`[engine ${type}] ${text}`),
    });
    if (!handle) throw new Error('The engine could not create a duel.');

    for (const libScript of ['constant.lua', 'utility.lua']) {
      const content = readScript(libScript);
      if (!content || !lib.loadScript(handle, libScript, content)) {
        throw new Error(`Could not load ${libScript} from the card scripts folder.`);
      }
    }
    // Shared helpers for our custom cards (content/custom/scripts/custom_utility.lua), if present.
    const customUtil = readScript('custom_utility.lua');
    if (customUtil && !lib.loadScript(handle, 'custom_utility.lua', customUtil)) {
      errors.push('[custom] custom_utility.lua has an error, see the messages above.');
    }

    const duel = new LocalDuel(lib, handle, seed, errors);
    duel.setup = { ...setup, seed };
    ([0, 1] as const).forEach((player) => {
      const deck = setup.decks[player];
      const add = (code: number, location: OcgLocation) => {
        if (!cards.get(code)) throw new Error(`Card ${code} is not in the card database.`);
        lib.duelNewCard(handle, {
          team: player,
          duelist: 0,
          code,
          controller: player,
          location,
          sequence: 0,
          position: OcgPosition.FACEDOWN_DEFENSE,
        });
      };
      for (const code of shuffle(deck.main, rng)) add(code, OcgLocation.DECK);
      for (const code of setup.openingHands?.[player] ?? []) add(code, OcgLocation.HAND);
      for (const code of deck.extra) add(code, OcgLocation.EXTRA);
    });
    lib.startDuel(handle);
    return duel;
  }

  /** Winner (0 or 1), 2 for a draw, null while the duel is still going. */
  winner: number | null = null;

  /**
   * Runs the engine until it needs a player decision (WAITING) or the duel ends (END).
   * The engine does not stop by itself after announcing a winner, so we stop at the WIN message.
   */
  advance(): StepResult {
    const messages: OcgMessage[] = [];
    if (this.winner !== null) return { status: OcgProcessResult.END, messages };
    for (;;) {
      const status = this.lib.duelProcess(this.handle);
      for (const msg of this.lib.duelGetMessage(this.handle)) {
        messages.push(msg);
        if (msg.type === OcgMessageType.WIN) {
          this.winner = msg.player;
          return { status: OcgProcessResult.END, messages };
        }
      }
      if (status !== OcgProcessResult.CONTINUE) return { status, messages };
    }
  }

  /** Cards in one location (null entries = empty zones). */
  queryLocation(controller: 0 | 1, location: OcgLocation, flags: number): (Partial<OcgCardQueryInfo> | null)[] {
    return this.lib.duelQueryLocation(this.handle, { controller, location, flags } as Parameters<OcgCoreSync['duelQueryLocation']>[1]);
  }

  queryCount(controller: 0 | 1, location: OcgLocation): number {
    return this.lib.duelQueryCount(this.handle, controller, location);
  }

  respond(response: OcgResponse): void {
    this.history.push(response);
    this.lib.duelSetResponse(this.handle, response);
  }

  destroy(): void {
    this.lib.destroyDuel(this.handle);
  }
}
