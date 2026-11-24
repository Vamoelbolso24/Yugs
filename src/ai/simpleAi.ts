// A very simple AI that picks a legal-looking move for any decision the engine asks for.
// Used to test the engine (AI vs AI) and later as a practice opponent.
import {
  OcgLocation,
  OcgMessageType,
  OcgPosition,
  OcgResponseType,
  SelectBattleCMDAction,
  SelectIdleCMDAction,
  type OcgMessage,
  type OcgResponse,
  type SelectFieldPlace,
} from 'ocgcore-wasm';
import { pick, type Rng } from '../engine/random.ts';

/** Message types that need an answer from a player. */
export const DECISION_TYPES = new Set<number>([
  OcgMessageType.SELECT_BATTLECMD, OcgMessageType.SELECT_IDLECMD, OcgMessageType.SELECT_EFFECTYN,
  OcgMessageType.SELECT_YESNO, OcgMessageType.SELECT_OPTION, OcgMessageType.SELECT_CARD,
  OcgMessageType.SELECT_CHAIN, OcgMessageType.SELECT_PLACE, OcgMessageType.SELECT_POSITION,
  OcgMessageType.SELECT_TRIBUTE, OcgMessageType.SORT_CHAIN, OcgMessageType.SELECT_COUNTER,
  OcgMessageType.SELECT_SUM, OcgMessageType.SELECT_DISFIELD, OcgMessageType.SORT_CARD,
  OcgMessageType.SELECT_UNSELECT_CARD, OcgMessageType.ROCK_PAPER_SCISSORS, OcgMessageType.ANNOUNCE_RACE,
  OcgMessageType.ANNOUNCE_ATTRIB, OcgMessageType.ANNOUNCE_CARD, OcgMessageType.ANNOUNCE_NUMBER,
]);

function randomIndices(count: number, length: number, rng: Rng): number[] {
  const all = [...Array(length).keys()];
  for (let i = all.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [all[i], all[j]] = [all[j]!, all[i]!];
  }
  return all.slice(0, Math.min(count, length)).sort((a, b) => a - b);
}

/** Free zones from a field mask (set bits = unavailable; low 16 bits = the selecting player's side). */
export function freePlaces(player: number, mask: number): SelectFieldPlace[] {
  const places: SelectFieldPlace[] = [];
  for (let bit = 0; bit < 32; bit++) {
    if (mask & (1 << bit)) continue;
    const local = bit % 16;
    places.push({
      player: bit < 16 ? player : 1 - player,
      location: local < 8 ? OcgLocation.MZONE : OcgLocation.SZONE,
      sequence: local % 8,
    });
  }
  return places;
}

export class SimpleAi {
  private actionsThisTurn = 0;
  private readonly rng: Rng;
  constructor(rng: Rng) {
    this.rng = rng;
  }

  newTurn(): void {
    this.actionsThisTurn = 0;
  }

  choose(msg: OcgMessage): OcgResponse {
    const rng = this.rng;
    switch (msg.type) {
      case OcgMessageType.SELECT_IDLECMD: {
        this.actionsThisTurn++;
        const tired = this.actionsThisTurn > 12;
        const options: [SelectIdleCMDAction, number][] = [];
        if (!tired) {
          msg.summons.forEach((_, i) => options.push([SelectIdleCMDAction.SELECT_SUMMON, i], [SelectIdleCMDAction.SELECT_SUMMON, i]));
          msg.special_summons.forEach((_, i) => options.push([SelectIdleCMDAction.SELECT_SPECIAL_SUMMON, i]));
          msg.monster_sets.forEach((_, i) => options.push([SelectIdleCMDAction.SELECT_MONSTER_SET, i]));
          msg.activates.forEach((_, i) => options.push([SelectIdleCMDAction.SELECT_ACTIVATE, i]));
          msg.spell_sets.forEach((_, i) => options.push([SelectIdleCMDAction.SELECT_SPELL_SET, i]));
        }
        if (options.length && rng() < 0.85) {
          const [action, index] = pick(options, rng);
          return { type: OcgResponseType.SELECT_IDLECMD, action, index };
        }
        if (msg.to_bp && rng() < 0.9) return { type: OcgResponseType.SELECT_IDLECMD, action: SelectIdleCMDAction.TO_BP, index: null };
        if (msg.to_ep) return { type: OcgResponseType.SELECT_IDLECMD, action: SelectIdleCMDAction.TO_EP, index: null };
        const [action, index] = options.length ? pick(options, rng) : [SelectIdleCMDAction.TO_BP, null];
        return { type: OcgResponseType.SELECT_IDLECMD, action, index };
      }
      case OcgMessageType.SELECT_BATTLECMD: {
        if (msg.attacks.length && rng() < 0.9) {
          return { type: OcgResponseType.SELECT_BATTLECMD, action: SelectBattleCMDAction.SELECT_BATTLE, index: Math.floor(rng() * msg.attacks.length) };
        }
        if (msg.to_m2) return { type: OcgResponseType.SELECT_BATTLECMD, action: SelectBattleCMDAction.TO_M2, index: null };
        return { type: OcgResponseType.SELECT_BATTLECMD, action: SelectBattleCMDAction.TO_EP, index: null };
      }
      case OcgMessageType.SELECT_EFFECTYN:
        return { type: OcgResponseType.SELECT_EFFECTYN, yes: rng() < 0.9 };
      case OcgMessageType.SELECT_YESNO:
        return { type: OcgResponseType.SELECT_YESNO, yes: rng() < 0.7 };
      case OcgMessageType.SELECT_OPTION:
        return { type: OcgResponseType.SELECT_OPTION, index: Math.floor(rng() * msg.options.length) };
      case OcgMessageType.SELECT_CARD: {
        const count = Math.max(msg.min, 1);
        return { type: OcgResponseType.SELECT_CARD, indicies: randomIndices(count, msg.selects.length, rng) };
      }
      case OcgMessageType.SELECT_CHAIN: {
        if (msg.selects.length && (msg.forced || rng() < 0.5)) {
          return { type: OcgResponseType.SELECT_CHAIN, index: Math.floor(rng() * msg.selects.length) };
        }
        return { type: OcgResponseType.SELECT_CHAIN, index: null };
      }
      case OcgMessageType.SELECT_PLACE:
      case OcgMessageType.SELECT_DISFIELD: {
        const free = freePlaces(msg.player, msg.field_mask);
        const own = free.filter((p) => p.player === msg.player);
        const pool = own.length >= msg.count ? own : free;
        const places = randomIndices(Math.max(msg.count, 1), pool.length, rng).map((i) => pool[i]!);
        return msg.type === OcgMessageType.SELECT_PLACE
          ? { type: OcgResponseType.SELECT_PLACE, places }
          : { type: OcgResponseType.SELECT_DISFIELD, places };
      }
      case OcgMessageType.SELECT_POSITION: {
        const order = [OcgPosition.FACEUP_ATTACK, OcgPosition.FACEDOWN_DEFENSE, OcgPosition.FACEUP_DEFENSE, OcgPosition.FACEDOWN_ATTACK];
        const position = order.find((p) => (msg.positions & p) !== 0) ?? OcgPosition.FACEUP_ATTACK;
        return { type: OcgResponseType.SELECT_POSITION, position };
      }
      case OcgMessageType.SELECT_TRIBUTE:
        return { type: OcgResponseType.SELECT_TRIBUTE, indicies: randomIndices(Math.max(msg.min, 1), msg.selects.length, rng) };
      case OcgMessageType.SELECT_UNSELECT_CARD: {
        if (msg.select_cards.length === 0 || (msg.can_finish && rng() < 0.6)) {
          return { type: OcgResponseType.SELECT_UNSELECT_CARD, index: null };
        }
        return { type: OcgResponseType.SELECT_UNSELECT_CARD, index: Math.floor(rng() * msg.select_cards.length) };
      }
      case OcgMessageType.SELECT_COUNTER: {
        let left = msg.count;
        const counters = msg.cards.map((c) => {
          const take = Math.min(c.count, left);
          left -= take;
          return take;
        });
        return { type: OcgResponseType.SELECT_COUNTER, counters };
      }
      case OcgMessageType.SELECT_SUM: {
        const mustTotal = msg.selects_must.reduce((t, c) => t + (c.amount & 0xffff), 0);
        const target = msg.amount - mustTotal;
        const n = Math.min(msg.selects.length, 16);
        for (let mask = 1; mask < 1 << n; mask++) {
          let total = 0;
          const chosen: number[] = [];
          for (let i = 0; i < n; i++) {
            if (mask & (1 << i)) {
              total += msg.selects[i]!.amount & 0xffff;
              chosen.push(i);
            }
          }
          if (msg.select_max ? total >= target : total === target) {
            return { type: OcgResponseType.SELECT_SUM, indicies: chosen };
          }
        }
        return { type: OcgResponseType.SELECT_SUM, indicies: [] };
      }
      case OcgMessageType.SORT_CARD:
      case OcgMessageType.SORT_CHAIN:
        return { type: OcgResponseType.SORT_CARD, order: null };
      case OcgMessageType.ROCK_PAPER_SCISSORS:
        return { type: OcgResponseType.ROCK_PAPER_SCISSORS, value: pick([1, 2, 3] as const, rng) };
      case OcgMessageType.ANNOUNCE_NUMBER:
        return { type: OcgResponseType.ANNOUNCE_NUMBER, value: 0 };
      case OcgMessageType.ANNOUNCE_RACE: {
        const all = raceBits(msg.available);
        const races = all.sort(() => rng() - 0.5).slice(0, Math.max(1, msg.count));
        return { type: OcgResponseType.ANNOUNCE_RACE, races: races as never };
      }
      case OcgMessageType.ANNOUNCE_ATTRIB: {
        const all = attributeBits(msg.available);
        const attributes = all.sort(() => rng() - 0.5).slice(0, Math.max(1, msg.count));
        return { type: OcgResponseType.ANNOUNCE_ATTRIB, attributes: attributes as never };
      }
      default:
        throw new Error(`The AI does not know how to answer message type ${msg.type}`);
    }
  }
}

/** The single-bit Types (races) inside a bitmask, e.g. Pyro | Rock -> [Pyro, Rock]. */
export function raceBits(mask: bigint | number): bigint[] {
  const m = BigInt(mask);
  const out: bigint[] = [];
  for (let i = 0n; i < 64n; i++) if (m & (1n << i)) out.push(1n << i);
  return out;
}
/** The single-bit Attributes inside a bitmask. */
export function attributeBits(mask: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < 7; i++) if (mask & (1 << i)) out.push(1 << i);
  return out;
}
