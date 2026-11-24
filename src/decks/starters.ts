// Test decks for the first playable duel. Each entry: [passcode, copies, name].
export type DeckEntry = [number, number, string];

export interface DeckList {
  name: string;
  main: DeckEntry[];
  extra: DeckEntry[];
}

/** A deck as lists of passcodes, ready for the engine. */
export interface DeckCodes {
  main: number[];
  extra: number[];
}

const expand = (entries: DeckEntry[]) => entries.flatMap(([code, copies]) => Array<number>(copies).fill(code));

export function expandDeck(deck: DeckList): DeckCodes {
  return { main: expand(deck.main), extra: expand(deck.extra) };
}

export const YUGI_DECK: DeckList = {
  name: "Yugi's Classic Deck",
  main: [
    // Monsters (20)
    [46986414, 1, 'Dark Magician'],
    [70781052, 1, 'Summoned Skull'],
    [6368038, 1, 'Gaia The Fierce Knight'],
    [28279543, 1, 'Curse of Dragon'],
    [91152256, 2, 'Celtic Guardian'],
    [32452818, 2, 'Beaver Warrior'],
    [13039848, 2, 'Giant Soldier of Stone'],
    [41392891, 2, 'Feral Imp'],
    [15025844, 2, 'Mystical Elf'],
    [90357090, 2, 'Silver Fang'],
    [54652250, 2, 'Man-Eater Bug'],
    [87796900, 2, 'Winged Dragon, Guardian of the Fortress #1'],
    // Spells (12)
    [53129443, 1, 'Dark Hole'],
    [12580477, 1, 'Raigeki'],
    [83764718, 1, 'Monster Reborn'],
    [66788016, 2, 'Fissure'],
    [84257639, 2, 'Dian Keto the Cure Master'],
    [91595718, 1, 'Book of Secret Arts'],
    [72302403, 1, 'Swords of Revealing Light'],
    [4031928, 1, 'Change of Heart'],
    [24094653, 1, 'Polymerization'],
    [55144522, 1, 'Pot of Greed'],
    // Traps (8)
    [4206964, 2, 'Trap Hole'],
    [50045299, 1, 'Dragon Capture Jar'],
    [12607053, 2, 'Waboku'],
    [51482758, 1, 'Remove Trap'],
    [17814387, 1, 'Reinforcements'],
    [44209392, 1, 'Castle Walls'],
  ],
  extra: [
    [66889139, 1, 'Gaia the Dragon Champion'],
    [98502113, 1, 'Dark Paladin'],
  ],
};

export const KAIBA_DECK: DeckList = {
  name: "Kaiba's Classic Deck",
  main: [
    // Monsters (24)
    [89631139, 3, 'Blue-Eyes White Dragon'],
    [5053103, 2, 'Battle Ox'],
    [17985575, 1, 'Lord of D.'],
    [76184692, 2, 'Hitotsu-Me Giant'],
    [24611934, 2, 'Ryu-Kishin Powered'],
    [97590747, 2, 'La Jinn the Mystical Genie of the Lamp'],
    [66602787, 2, 'Saggi the Dark Clown'],
    [26378150, 1, 'Rude Kaiser'],
    [30113682, 1, 'Judge Man'],
    [68516705, 2, 'Mystic Horseman'],
    [50005633, 1, 'Swordstalker'],
    [91939608, 1, 'Rogue Doll'],
    [67724379, 1, 'Koumori Dragon'],
    [14898066, 1, 'Vorse Raider'],
    [15303296, 1, 'Ryu-Kishin'],
    [17444133, 1, 'Kaiser Sea Horse'],
    // Spells (8)
    [43973174, 1, 'The Flute of Summoning Dragon'],
    [83764718, 1, 'Monster Reborn'],
    [53129443, 1, 'Dark Hole'],
    [66788016, 1, 'Fissure'],
    [19523799, 1, 'Ookazi'],
    [24094653, 1, 'Polymerization'],
    [68005187, 1, 'Soul Exchange'],
    [55144522, 1, 'Pot of Greed'],
    // Traps (8)
    [57728570, 1, 'Crush Card Virus'],
    [24068492, 2, 'Just Desserts'],
    [29267084, 2, 'Shadow Spell'],
    [4206964, 1, 'Trap Hole'],
    [44095762, 1, 'Mirror Force'],
    [14315573, 1, 'Negate Attack'],
  ],
  // Number 39 and Link Spider are not classic Kaiba cards: they are here to test Xyz/Link
  // Summons and the Extra Monster Zones.
  extra: [
    [23995346, 1, 'Blue-Eyes Ultimate Dragon'],
    [84013237, 1, 'Number 39: Utopia'],
    [98978921, 1, 'Link Spider'],
  ],
};
