// Turns engine messages into readable duel-log lines (for the test log and the in-game log).
import { OcgLocation, OcgMessageType, OcgPhase, OcgPosition, type OcgMessage } from 'ocgcore-wasm';
import type { CardDatabase } from './cardDb.ts';

const PHASE_NAMES: Record<number, string> = {
  [OcgPhase.DRAW]: 'Draw Phase',
  [OcgPhase.STANDBY]: 'Standby Phase',
  [OcgPhase.MAIN1]: 'Main Phase 1',
  [OcgPhase.BATTLE_START]: 'Battle Phase',
  [OcgPhase.MAIN2]: 'Main Phase 2',
  [OcgPhase.END]: 'End Phase',
};

const LOCATION_NAMES: Record<number, string> = {
  [OcgLocation.DECK]: 'Deck',
  [OcgLocation.HAND]: 'hand',
  [OcgLocation.MZONE]: 'Monster Zone',
  [OcgLocation.SZONE]: 'Spell & Trap Zone',
  [OcgLocation.GRAVE]: 'Graveyard',
  [OcgLocation.REMOVED]: 'banishment',
  [OcgLocation.EXTRA]: 'Extra Deck',
  [OcgLocation.OVERLAY]: 'Xyz material',
};

export const WIN_REASONS: Record<number, string> = {
  0: 'opponent surrendered',
  1: "opponent's LP reached 0",
  2: 'opponent could not draw',
  3: 'time limit',
  4: 'opponent lost connection',
};

export function describeMessage(msg: OcgMessage, cards: CardDatabase, playerNames: [string, string]): string | null {
  const who = (p: number) => playerNames[p] ?? `Player ${p + 1}`;
  const name = (code: number) => cards.name(code);
  switch (msg.type) {
    case OcgMessageType.NEW_TURN:
      return `\n=== ${who(msg.player)}'s turn ===`;
    case OcgMessageType.NEW_PHASE:
      return PHASE_NAMES[msg.phase] ? `  -- ${PHASE_NAMES[msg.phase]}` : null;
    case OcgMessageType.DRAW:
      return `${who(msg.player)} draws ${msg.drawn.length} card${msg.drawn.length === 1 ? '' : 's'}`;
    case OcgMessageType.SUMMONING:
      return `${who(msg.controller)} Normal Summons ${name(msg.code)}`;
    case OcgMessageType.SPSUMMONING:
      return `${who(msg.controller)} Special Summons ${name(msg.code)}`;
    case OcgMessageType.FLIPSUMMONING:
      return `${who(msg.controller)} Flip Summons ${name(msg.code)}`;
    case OcgMessageType.SET:
      return msg.location === OcgLocation.MZONE ? `${who(msg.controller)} sets a monster` : `${who(msg.controller)} sets a card`;
    case OcgMessageType.CHAINING:
      return `${who(msg.controller)} activates ${name(msg.code)}${msg.chain_size > 1 ? ` (Chain Link ${msg.chain_size})` : ''}`;
    case OcgMessageType.CHAIN_NEGATED:
    case OcgMessageType.CHAIN_DISABLED:
      return `  (the effect was negated)`;
    case OcgMessageType.ATTACK:
      return msg.target ? '  Attack declared' : '  Direct attack declared';
    case OcgMessageType.BATTLE:
      return `  Battle: ${msg.card.attack} ATK${msg.target && msg.target.location ? ` vs ${msg.target.position & OcgPosition.DEFENSE ? `${msg.target.defense} DEF` : `${msg.target.attack} ATK`}` : ''}`;
    case OcgMessageType.DAMAGE:
      return `  ${who(msg.player)} takes ${msg.amount} damage`;
    case OcgMessageType.RECOVER:
      return `  ${who(msg.player)} gains ${msg.amount} LP`;
    case OcgMessageType.PAY_LPCOST:
      return `  ${who(msg.player)} pays ${msg.amount} LP`;
    case OcgMessageType.MOVE: {
      if (msg.to.location === OcgLocation.GRAVE && msg.from.location !== OcgLocation.DECK && msg.from.location !== OcgLocation.HAND) {
        return `  ${name(msg.card)} goes to the Graveyard`;
      }
      if (msg.to.location === OcgLocation.REMOVED) return `  ${name(msg.card)} is banished`;
      if (msg.to.location === OcgLocation.HAND && msg.from.location !== OcgLocation.DECK) {
        return `  ${name(msg.card)} returns to the hand`;
      }
      if (msg.to.location === OcgLocation.HAND && msg.from.location === OcgLocation.DECK && msg.card) {
        return `  ${name(msg.card)} is added from the Deck to the ${LOCATION_NAMES[OcgLocation.HAND]}`;
      }
      return null;
    }
    case OcgMessageType.TOSS_COIN:
      return `  ${who(msg.player)} tosses a coin: ${msg.results.map((h) => (h ? 'Heads' : 'Tails')).join(', ')}`;
    case OcgMessageType.TOSS_DICE:
      return `  ${who(msg.player)} rolls a die: ${msg.results.join(', ')}`;
    case OcgMessageType.WIN:
      return msg.player === 2 ? '\n*** The duel is a draw! ***' : `\n*** ${who(msg.player)} wins! (${WIN_REASONS[msg.reason] ?? 'win'}) ***`;
    default:
      return null;
  }
}
