// Human-readable text for engine prompts and card types.
import type { CardDatabase } from './cardDb.ts';
import { counterLabel } from '../content/customCards.ts';

/** Scripts show a counter's name in a menu with description COUNTER_DESC_BASE + counter type (Pokemon.CounterDesc). */
export const COUNTER_DESC_BASE = 0x7c00000000000000n;

/** Prompts for HINT_SELECTMSG values (HINTMSG_* constants in CardScripts/constant.lua). */
export const SELECT_HINTS: Record<number, string> = {
  60: 'Heads',
  61: 'Tails',
  70: 'Monster card',
  71: 'Spell card',
  72: 'Trap card',
  500: 'Select the card(s) to Tribute',
  501: 'Select the card(s) to discard',
  502: 'Select the card(s) to destroy',
  503: 'Select the card(s) to banish',
  504: 'Select the card(s) to send to the Graveyard',
  505: 'Select the card(s) to return to the hand',
  506: 'Select the card(s) to add to your hand',
  507: 'Select the card(s) to return to the Deck',
  508: 'Select the monster to Normal Summon',
  509: 'Select the monster to Special Summon',
  510: 'Select the card to Set',
  511: 'Select the Fusion Material',
  512: 'Select the Synchro Material',
  513: 'Select the Xyz Material',
  514: 'Select a face-up card',
  515: 'Select a face-down card',
  516: 'Select a monster in Attack Position',
  517: 'Select a monster in Defense Position',
  518: 'Select the card to equip',
  519: 'Select the material to detach',
  520: 'Select the monster to take control of',
  521: 'Select the card to destroy instead',
  522: 'Select a face-up Attack Position monster',
  523: 'Select a face-up Defense Position monster',
  524: 'Select a face-down Attack Position monster',
  525: 'Select a face-down Defense Position monster',
  526: 'Select the card(s) to reveal',
  527: 'Select the card to place on the field',
  528: 'Select the monster to change its battle position',
  529: 'Select your card',
  530: "Select your opponent's card",
  531: 'Select the monster(s) to Tribute',
  532: 'Select the monster to detach material from',
  533: 'Select the Link Material',
  549: 'Select the attack target',
  550: 'Select an effect',
  551: 'Select the target',
  552: 'Call heads or tails',
  553: 'Select a die result',
  554: 'Select a card type',
  555: 'Select an option',
  556: 'Select the effect to resolve',
  560: 'Select',
  561: 'Select a battle position',
  562: 'Declare an Attribute',
  563: 'Declare a Type',
  564: 'Declare a card name',
  565: 'Declare a number',
  566: 'Select the effect to activate',
  567: 'Declare a Level/Rank',
  568: 'Select the card to resolve',
  569: 'Select a zone',
  570: 'Select a zone to disable',
  571: 'Select the zone to move to',
  572: 'Select the card to place a counter on',
  575: 'Select the card to negate',
  576: 'Select ATK or DEF',
  577: 'Select the card to apply this to',
  578: 'Select the card to attach',
  579: 'Select the card to return to the Graveyard',
};

/**
 * Effect descriptions are encoded by aux.Stringid as (code << 20) | index (older scripts: code * 16 + index).
 * Returns the card's prompt text when it can be decoded, otherwise null.
 */
export function effectText(desc: bigint, cards: CardDatabase): string | null {
  if (desc <= 0n) return null;
  if (desc >= COUNTER_DESC_BASE && desc < COUNTER_DESC_BASE + 0x100000n) return counterLabel(Number(desc - COUNTER_DESC_BASE));
  for (const [shift, mask] of [[20n, 0xfffffn], [4n, 0xfn]] as const) {
    const card = desc >> shift ? cards.get(Number(desc >> shift)) : undefined;
    const index = Number(desc & mask);
    if (card && index < 16) return card.strings[index] || `${card.name}'s effect`;
  }
  return SELECT_HINTS[Number(desc)] ?? null;
}

const TYPE = {
  MONSTER: 0x1, SPELL: 0x2, TRAP: 0x4, NORMAL: 0x10, EFFECT: 0x20, FUSION: 0x40, RITUAL: 0x80,
  SYNCHRO: 0x2000, XYZ: 0x800000, PENDULUM: 0x1000000, LINK: 0x4000000, TOKEN: 0x4000,
  QUICKPLAY: 0x10000, CONTINUOUS: 0x20000, EQUIP: 0x40000, FIELD: 0x80000, COUNTER: 0x100000,
} as const;

/** Short category used by the board to pick a card frame colour. */
export function cardFrame(type: number): string {
  if (type & TYPE.SPELL) return 'spell';
  if (type & TYPE.TRAP) return 'trap';
  if (type & TYPE.TOKEN) return 'token';
  if (type & TYPE.LINK) return 'link';
  if (type & TYPE.XYZ) return 'xyz';
  if (type & TYPE.SYNCHRO) return 'synchro';
  if (type & TYPE.FUSION) return 'fusion';
  if (type & TYPE.RITUAL) return 'ritual';
  if (type & TYPE.EFFECT) return 'effect';
  return 'normal';
}

export function typeLine(type: number): string {
  const parts: string[] = [];
  if (type & TYPE.MONSTER) {
    for (const [name, bit] of [['Fusion', TYPE.FUSION], ['Ritual', TYPE.RITUAL], ['Synchro', TYPE.SYNCHRO],
      ['Xyz', TYPE.XYZ], ['Pendulum', TYPE.PENDULUM], ['Link', TYPE.LINK], ['Effect', TYPE.EFFECT], ['Normal', TYPE.NORMAL]] as const) {
      if (type & bit) parts.push(name);
    }
    return `${parts.join(' / ') || 'Normal'} Monster`;
  }
  const kind = type & TYPE.SPELL ? 'Spell' : 'Trap';
  for (const [name, bit] of [['Quick-Play', TYPE.QUICKPLAY], ['Continuous', TYPE.CONTINUOUS], ['Equip', TYPE.EQUIP],
    ['Field', TYPE.FIELD], ['Counter', TYPE.COUNTER], ['Ritual', TYPE.RITUAL]] as const) {
    if (type & bit) parts.push(name);
  }
  return `${parts.length ? parts.join(' ') + ' ' : 'Normal '}${kind}`;
}

const ATTRIBUTES: Record<number, string> = { 1: 'EARTH', 2: 'WATER', 4: 'FIRE', 8: 'WIND', 16: 'LIGHT', 32: 'DARK', 64: 'DIVINE' };
export function attributeName(attribute: number): string {
  return ATTRIBUTES[attribute] ?? '';
}

const RACES = ['Warrior', 'Spellcaster', 'Fairy', 'Fiend', 'Zombie', 'Machine', 'Aqua', 'Pyro', 'Rock', 'Winged Beast',
  'Plant', 'Insect', 'Thunder', 'Dragon', 'Beast', 'Beast-Warrior', 'Dinosaur', 'Fish', 'Sea Serpent', 'Reptile',
  'Psychic', 'Divine-Beast', 'Creator God', 'Wyrm', 'Cyberse', 'Illusion'];
export function raceName(race: bigint): string {
  for (let i = 0; i < RACES.length; i++) if (race & (1n << BigInt(i))) return RACES[i]!;
  return '';
}
