// Card details for the browser (name, text, stats), built from the card database.
import type { CardDatabase } from './cardDb.ts';
import type { CardText } from '../game/types.ts';
import { attributeName, cardFrame, raceName, typeLine } from './strings.ts';

export function cardText(cards: CardDatabase, code: number): CardText | null {
  const info = cards.get(code);
  if (!info) return null;
  const d = info.data;
  return {
    name: info.name,
    desc: info.desc,
    typeLine: [...(info.subtypes ?? []), typeLine(Number(d.type))].join(' / '),
    type: Number(d.type),
    frame: cardFrame(Number(d.type)),
    isMonster: (Number(d.type) & 1) !== 0,
    attribute: attributeName(Number(d.attribute)),
    race: raceName(BigInt(d.race)),
    level: d.level,
    atk: d.attack,
    def: d.defense,
    linkMarkers: Number(d.link_marker),
    lscale: d.lscale,
    rscale: d.rscale,
    image: info.image,
    customId: info.customId,
  };
}

export function cardTexts(cards: CardDatabase, codes: Iterable<number>): Record<number, CardText> {
  const out: Record<number, CardText> = {};
  for (const code of codes) {
    if (out[code]) continue;
    const t = cardText(cards, code);
    if (t) out[code] = t;
  }
  return out;
}
