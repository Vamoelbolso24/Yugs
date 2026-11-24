// The data the server sends to the browser. Plain JSON only (no bigints).

export interface CardRef {
  controller: 0 | 1;
  location: number;
  sequence: number;
  /** Passcode, 0 when the card is hidden from the viewer. */
  code: number;
}

export interface CardView {
  code: number;
  faceDown: boolean;
  defense: boolean;
  atk?: number;
  def?: number;
  overlays?: number;
  /** Counters on the card, e.g. [{ name: 'Harden', count: 2 }]. */
  counters?: { name: string; count: number }[];
}

export interface PlayerView {
  name: string;
  lp: number;
  deckCount: number;
  extraCount: number;
  hand: CardView[];
  /** 7 entries: Main Monster Zones 0-4, Extra Monster Zones 5-6. */
  monsters: (CardView | null)[];
  /** 8 entries: Spell & Trap Zones 0-4, Field Zone 5, Pendulum Zones 6-7. */
  spells: (CardView | null)[];
  grave: CardView[];
  banished: CardView[];
  /** Extra Deck contents (only filled for players allowed to see them). */
  extra: CardView[];
  /** When this player is asked whether to respond with a card or effect. */
  chainMode: ChainMode;
}

/**
 * smart:  ask only when something just happened (summon, attack, activation) or a chain is open.
 * always: ask at every point where a response is possible.
 * never:  never ask (only mandatory effects are shown).
 */
export type ChainMode = 'smart' | 'always' | 'never';

export interface ChoiceView {
  id: number;
  label: string;
  card?: CardRef;
  detail?: string;
}

export interface DecisionView {
  id: number;
  player: 0 | 1;
  /** menu: pick exactly one choice. multi: pick between min and max choices. declare: type a card name (answer = [card code]). */
  mode: 'menu' | 'multi' | 'declare';
  /** What kind of question this is (idle, battle, chain, select_card, ...), for the UI. */
  kind: string;
  prompt: string;
  choices: ChoiceView[];
  min: number;
  max: number;
  canCancel: boolean;
  error?: string;
}

export interface CardText {
  name: string;
  desc: string;
  typeLine: string;
  /** Raw type bits (TYPE_* constants), used by the deck editor filters. */
  type: number;
  frame: string;
  isMonster: boolean;
  attribute: string;
  race: string;
  level: number;
  atk: number;
  def: number;
  /** Link arrows bitmask (Link monsters only). */
  linkMarkers: number;
  lscale: number;
  rscale: number;
  /** Custom cards: artwork URL and our ID. */
  image?: string;
  customId?: string;
}

/**
 * Something to animate on the board: a card activated, cards that moved, life points that changed.
 * Only public information: code is 0 when the card was hidden from at least one player.
 */
export interface EventPlace { controller: 0 | 1; location: number; sequence: number }
export type GameEvent =
  | { id: number; kind: 'activate'; player: 0 | 1; code: number; at: EventPlace }
  | { id: number; kind: 'destroyed' | 'to-grave' | 'to-hand' | 'banished' | 'to-deck'; player: 0 | 1; code: number; from: EventPlace; to: EventPlace }
  | { id: number; kind: 'damage' | 'recover'; player: 0 | 1; amount: number };

export interface GameView {
  id: string;
  /** Which player this view is for (null = test mode, both players visible). */
  viewer: 0 | 1 | null;
  turn: number;
  turnPlayer: 0 | 1;
  phase: string;
  players: [PlayerView, PlayerView];
  /** Your question, if it is your turn to decide (only sent to the player who must answer). */
  decision: DecisionView | null;
  /** Which player the duel is waiting on. */
  waitingFor: 0 | 1 | null;
  log: string[];
  /** The last few cards shown by effects (excavated / revealed / looked at) that this viewer may see. */
  reveals: { id: number; title: string; codes: number[] }[];
  winner: number | null;
  /** How the duel ended ("Kaiba's LP reached 0", "Yugi surrendered"...), once it has. */
  endReason: string | null;
  /** Recent things to animate, oldest first (ids keep growing during the duel). */
  events: GameEvent[];
  cards: Record<number, CardText>;
}
