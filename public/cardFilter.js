// Card search filters and sorting for the deck editor.
// Used by the browser (menus.js) and by the server (admin search over every card), so it is plain JavaScript
// that only sets globalThis.CardFilter. A card here is the "card text" object the server sends:
// { name, desc, type, frame, isMonster, attribute, race, level, atk, def }.
'use strict';
(function () {
  const T = {
    MONSTER: 0x1, SPELL: 0x2, TRAP: 0x4, NORMAL: 0x10, EFFECT: 0x20, FUSION: 0x40, RITUAL: 0x80, SPIRIT: 0x200,
    UNION: 0x400, GEMINI: 0x800, TUNER: 0x1000, SYNCHRO: 0x2000, TOKEN: 0x4000, QUICKPLAY: 0x10000,
    CONTINUOUS: 0x20000, EQUIP: 0x40000, FIELD: 0x80000, COUNTER: 0x100000, FLIP: 0x200000, TOON: 0x400000,
    XYZ: 0x800000, PENDULUM: 0x1000000, LINK: 0x4000000,
  };
  const has = (c, bit) => ((c.type || 0) & bit) !== 0;
  const isExtra = (c) => c.isMonster && has(c, T.FUSION | T.SYNCHRO | T.XYZ | T.LINK);

  const FRAMES = [
    ['monster', 'Monster (Main Deck)', (c) => c.isMonster && !isExtra(c)],
    ['extra', 'Extra Deck', isExtra],
    ['normal', 'Normal', (c) => c.isMonster && c.frame === 'normal'],
    ['effect', 'Effect', (c) => c.isMonster && c.frame === 'effect'],
    ['ritual', 'Ritual', (c) => c.isMonster && has(c, T.RITUAL)],
    ['fusion', 'Fusion', (c) => c.isMonster && has(c, T.FUSION)],
    ['synchro', 'Synchro', (c) => c.isMonster && has(c, T.SYNCHRO)],
    ['xyz', 'Xyz', (c) => c.isMonster && has(c, T.XYZ)],
    ['link', 'Link', (c) => c.isMonster && has(c, T.LINK)],
    ['pendulum', 'Pendulum', (c) => c.isMonster && has(c, T.PENDULUM)],
    ['spell', 'Spell', (c) => c.frame === 'spell'],
    ['trap', 'Trap', (c) => c.frame === 'trap'],
  ];
  const ICONS = [
    ['normal', 'Normal', (c) => !has(c, T.QUICKPLAY | T.CONTINUOUS | T.EQUIP | T.FIELD | T.RITUAL | T.COUNTER)],
    ['quickplay', 'Quick-Play', (c) => has(c, T.QUICKPLAY)],
    ['continuous', 'Continuous', (c) => has(c, T.CONTINUOUS)],
    ['equip', 'Equip', (c) => has(c, T.EQUIP)],
    ['field', 'Field', (c) => has(c, T.FIELD)],
    ['ritual', 'Ritual', (c) => has(c, T.RITUAL)],
    ['counter', 'Counter', (c) => has(c, T.COUNTER)],
  ];
  const ATTRIBUTES = ['LIGHT', 'DARK', 'WATER', 'FIRE', 'EARTH', 'WIND', 'DIVINE'];
  const RACES = ['Aqua', 'Beast', 'Beast-Warrior', 'Creator God', 'Cyberse', 'Dinosaur', 'Divine-Beast', 'Dragon', 'Fairy',
    'Fiend', 'Fish', 'Illusion', 'Insect', 'Machine', 'Plant', 'Psychic', 'Pyro', 'Reptile', 'Rock', 'Sea Serpent',
    'Spellcaster', 'Thunder', 'Warrior', 'Winged Beast', 'Wyrm', 'Zombie'];
  const RACE_WORDS = RACES.join('|').replace(/-/g, '\\-');

  // "Genre": what a card does, guessed from its text and card type (works the same for custom cards).
  const sentences = (d) => d.split(/(?<=[.:;])\s+|\n/);
  const anySentence = (c, re1, re2) => sentences(c.desc).some((s) => re1.test(s) && re2.test(s));
  const t = (re) => (c) => re.test(c.desc);
  const GENRES = [
    ['multi-attack', 'Attack multiple times', t(/second attack|third attack|attack (twice|all|up to)|attacks? on (each|all)|make up to \d+ attacks|attack .{0,30}once each/i)],
    ['attribute', 'Attribute-related', t(/\b(LIGHT|DARK|WATER|FIRE|EARTH|WIND|DIVINE)\b/)],
    ['indestructible', 'Cannot be destroyed', t(/cannot be destroyed|it is not destroyed|would be destroyed[^.]*instead|the first time .{0,40}would be destroyed/i)],
    ['no-normal-summon', 'Cannot Normal Summon', t(/cannot be Normal Summoned/i)],
    ['position', 'Change battle position', t(/battle position|change .{0,40}to (face-(up|down) )?(Attack|Defense) Position|flip .{0,30}face-down/i)],
    ['counter', 'Counter', (c) => /\b[A-Z][\w.]*[ -]Counters?\b|\bCounters?\b/.test(c.desc.replace(/Counter Traps?/g, ''))],
    ['damage', 'Damage LP', t(/\b\d+ damage|damage equal to|lose \d+ LP|\bdamage to your opponent for each|inflict damage/i)],
    ['destroy-deck', 'Destroy Deck', (c) => anySentence(c, /\b(send|banish|excavate)/i, /(top \d+ cards? of|from) (your |their |your opponent's |either player's |the )?Deck/i) && /(GY|Graveyard|banish)/i.test(c.desc)],
    ['destroy-hand', 'Destroy Hand', t(/discard|cards? (in|from) (their|your opponent's) hand/i)],
    ['destroy-monster', 'Destroy Monster', t(/destroy[^.]{0,80}monsters?|destroy (it|them|that target)\b/i)],
    ['destroy-spell', 'Destroy Spell/Trap', t(/destroy[^.]{0,80}(Spells?|Traps?|Spell\/Trap|Set cards?|cards? on the field)/i)],
    ['direct', 'Direct Attack', t(/attack (your opponent )?directly|direct attack/i)],
    ['flip', 'Flip Effect Monster', (c) => has(c, T.FLIP) || /^FLIP:/m.test(c.desc)],
    ['fusion-material', 'Fusion Material Monster', (c) => c.isMonster && !isExtra(c) && /Fusion/i.test(c.desc)],
    ['gamble', 'Gamble', t(/\bcoin|\bdie\b|\bdice\b|six-sided/i)],
    ['gemini', 'Gemini Monster', (c) => has(c, T.GEMINI)],
    ['draw', 'Help Draw', t(/\bdraws?\b/i)],
    ['atk-def', 'Increase/Decrease ATK/DEF', t(/(gains?|loses?|increase|decrease|becomes?|halve|double|reduce)[^.]{0,50}\b(ATK|DEF)\b|\b(ATK|DEF)\b[^.]{0,30}(becomes|is halved|is doubled)|[+-]\d+ (ATK|DEF)/i)],
    ['level', 'Level Modifier', t(/(increase|decrease|reduce|change|becomes?|gains?|loses?)[^.]{0,40}\bLevels?\b(?! \d+ or)|\bLevels?\b[^.]{0,20}(becomes|is increased|is reduced)/i)],
    ['limit-attack', 'Limit Attack', t(/cannot (declare an )?attack|cannot target [^.]{0,40}for attacks|skips? (their|your|the) (next )?Battle Phase|negate (the|that|an) attack/i)],
    ['link', 'Link Monster', (c) => has(c, T.LINK)],
    ['lv', 'LV Monster', (c) => /\bLV\d/.test(c.name)],
    ['negate', 'Negate effect', t(/negate/i)],
    ['pendulum', 'Pendulum', (c) => has(c, T.PENDULUM)],
    ['piercing', 'Piercing', t(/piercing/i)],
    ['from-gy', 'Recover from Graveyard', t(/(add|return)[^.]{0,80}(from|in) (your|either player's|the|their|your opponent's) (GY|Graveyard)[^.]{0,40}to (your|the|their) hand|(from|in) your (GY|Graveyard)[^.]{0,10}; add|(GY|Graveyard)[^.]{0,80}; add (it|them|that)|Special Summon[^.;]{0,80}from (your|either player's|the|their|your opponent's) (hand or )?(GY|Graveyard)/i)],
    ['recover', 'Recover LP', t(/gains? [^.]{0,30}\bLP\b|recover/i)],
    ['banish', 'Remove Card', t(/banish/i)],
    ['return', 'Return Card', t(/return[^.]{0,80}to (the|its owner's|your|their|the owner's) (hand|Deck)|shuffle[^.]{0,80}into the Deck/i)],
    ['ritual', 'Ritual', (c) => has(c, T.RITUAL) || /Ritual Summon/i.test(c.desc)],
    ['search', 'Search Deck', t(/add[^.]{0,100}from (your )?Deck to (your )?hand|from your Deck to your hand/i)],
    ['to-gy', 'Send to Graveyard', t(/send[^.]{0,80}to the (GY|Graveyard)/i)],
    ['control', 'Set controls', t(/take control|gain control|control of [^.]{0,30}(changes?|switch)|switch control/i)],
    ['special-summon', 'Special Summon', t(/Special Summon/)],
    ['spirit', 'Spirit Monster', (c) => has(c, T.SPIRIT)],
    ['synchro', 'Synchro Monster', (c) => has(c, T.SYNCHRO)],
    ['token', 'Token', t(/Token/)],
    ['toon', 'Toon Monster', (c) => has(c, T.TOON)],
    ['tuner', 'Tuner', (c) => has(c, T.TUNER)],
    ['type', 'Type-related', t(new RegExp(`\\b(${RACE_WORDS})(-Type)?\\b`))],
    ['union', 'Union Monster', (c) => has(c, T.UNION)],
    ['xyz', 'Xyz Monster', (c) => has(c, T.XYZ)],
  ];

  const isXyz = (c) => c.isMonster && has(c, T.XYZ);
  const isLink = (c) => c.isMonster && has(c, T.LINK);
  /** Level for Level filters (none for Xyz/Link), Rank for Rank filters (Xyz only). */
  const levelOf = (c) => (c.isMonster && !isXyz(c) && !isLink(c) ? c.level : null);
  const rankOf = (c) => (isXyz(c) ? c.level : null);

  /** A number range: { op: 'any' | 'eq' | 'ge' | 'le' | 'between', a, b }. Cards without the value never match. */
  function inRange(v, r) {
    if (!r || r.op === 'any') return true;
    if (v === null || v === undefined || v < 0) return false; // "?" ATK/DEF is -2
    const a = Number(r.a), b = Number(r.b);
    if (r.op === 'eq') return v === a;
    if (r.op === 'ge') return v >= a;
    if (r.op === 'le') return v <= a;
    if (r.op === 'between') return v >= Math.min(a, b) && v <= Math.max(a, b);
    return true;
  }

  function emptyFilter() {
    const any = () => ({ op: 'any', a: '', b: '' });
    return { q: '', frame: '', icon: '', attribute: '', race: '', genre: '', level: any(), rank: any(), atk: any(), def: any() };
  }

  /** Every filter that is set must match (they intersect). */
  function matches(c, f) {
    if (!c) return false;
    const q = (f.q || '').trim().toLowerCase();
    // anywhere in the name or the card text, not case sensitive ("umi" finds Umi, Numinous, "amperumi"...)
    if (q && !c.name.toLowerCase().includes(q) && !c.desc.toLowerCase().includes(q)) return false;
    if (f.frame) { const fr = FRAMES.find((x) => x[0] === f.frame); if (fr && !fr[2](c)) return false; }
    if (f.icon) {
      if (c.isMonster) return false;
      const ic = ICONS.find((x) => x[0] === f.icon); if (ic && !ic[2](c)) return false;
    }
    if (f.attribute && (!c.isMonster || c.attribute !== f.attribute)) return false;
    if (f.race && (!c.isMonster || c.race !== f.race)) return false;
    if (f.level && f.level.op !== 'any' && !inRange(levelOf(c), f.level)) return false;
    if (f.rank && f.rank.op !== 'any' && !inRange(rankOf(c), f.rank)) return false;
    if (f.atk && f.atk.op !== 'any' && !inRange(c.isMonster ? c.atk : null, f.atk)) return false;
    if (f.def && f.def.op !== 'any' && !inRange(c.isMonster && !isLink(c) ? c.def : null, f.def)) return false;
    if (f.genre) { const g = GENRES.find((x) => x[0] === f.genre); if (g && !g[2](c)) return false; }
    return true;
  }

  function isActive(f) {
    return !!(f && ((f.q || '').trim() || f.frame || f.icon || f.attribute || f.race || f.genre
      || ['level', 'rank', 'atk', 'def'].some((k) => f[k] && f[k].op !== 'any')));
  }

  // ---- sorting
  const FRAME_ORDER = ['normal', 'effect', 'ritual', 'fusion', 'synchro', 'xyz', 'link', 'token', 'spell', 'trap'];
  const kindRank = (c) => (c.isMonster ? (isExtra(c) ? 3 : 0) : c.frame === 'spell' ? 1 : 2);
  const SORTS = [
    ['default', 'Default'],
    ['name', 'Name'],
    ['frame', 'Frame'],
    ['level', 'Lv / Rank'],
    ['atk', 'ATK'],
    ['def', 'DEF'],
    ['attribute', 'Attribute'],
    ['race', 'Type'],
  ];
  /** Sorts card codes. get(code) -> card text. Cards without the value (e.g. Spells for ATK) go last. */
  function sort(codes, get, by, desc) {
    const name = (c) => (c ? c.name : '');
    const num = (c, key) => {
      if (!c || !c.isMonster) return null;
      if (key === 'level') return isLink(c) ? null : c.level;
      if (key === 'def' && isLink(c)) return null;
      return c[key] < 0 ? null : c[key];
    };
    const dir = desc ? -1 : 1;
    const cmp = (a, b) => {
      const A = get(a), B = get(b);
      if (!A || !B) return A ? -1 : B ? 1 : 0;
      let r = 0;
      switch (by) {
        case 'name': r = dir * name(A).localeCompare(name(B)); break;
        case 'frame': r = dir * (FRAME_ORDER.indexOf(A.frame) - FRAME_ORDER.indexOf(B.frame)); break;
        case 'attribute': case 'race': {
          const x = A.isMonster ? A[by] : '', y = B.isMonster ? B[by] : '';
          r = x && y ? dir * x.localeCompare(y) : x ? -1 : y ? 1 : 0; break;
        }
        case 'level': case 'atk': case 'def': {
          const x = num(A, by), y = num(B, by);
          r = x !== null && y !== null ? dir * (x - y) : x !== null ? -1 : y !== null ? 1 : 0; break;
        }
        default: // Monsters, Spells, Traps, Extra Deck; higher Levels first
          r = kindRank(A) - kindRank(B) || (B.level || 0) - (A.level || 0);
      }
      return r || name(A).localeCompare(name(B));
    };
    return [...codes].sort(cmp);
  }

  globalThis.CardFilter = { FRAMES, ICONS, ATTRIBUTES, RACES, GENRES, SORTS, emptyFilter, matches, isActive, sort, isExtra };
})();
