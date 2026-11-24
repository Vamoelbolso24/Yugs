// Loads card data (stats + text) from Project Ignis .cdb (SQLite) files.
import { DatabaseSync } from 'node:sqlite';
import type { OcgCardData } from 'ocgcore-wasm';

export interface CardInfo {
  data: OcgCardData;
  name: string;
  desc: string;
  /** Effect prompt strings (str1..str16) used by aux.Stringid(code, n). */
  strings: string[];
  /** Custom cards only: their ID (as text, e.g. "1900000000") and artwork URL. */
  customId?: string;
  image?: string;
  /** Custom subtypes like "Pokemon" (shown in the type line). */
  subtypes?: string[];
  /** Custom cards with "Hidden: yes": only used by scripts, never in collections or Decks. */
  hidden?: boolean;
}

const TYPE_LINK = 0x4000000;

export class CardDatabase {
  readonly cards = new Map<number, CardInfo>();

  constructor(files: string[]) {
    for (const file of files) this.load(file);
  }

  private load(file: string): void {
    const db = new DatabaseSync(file, { readOnly: true });
    const stmt = db.prepare(
      `SELECT d.id, d.alias, d.setcode, d.type, d.atk, d.def, d.level, d.race, d.attribute, t.name, t.desc,
              t.str1, t.str2, t.str3, t.str4, t.str5, t.str6, t.str7, t.str8,
              t.str9, t.str10, t.str11, t.str12, t.str13, t.str14, t.str15, t.str16
       FROM datas d JOIN texts t ON t.id = d.id`,
    );
    stmt.setReadBigInts(true);
    for (const row of stmt.all() as Record<string, bigint | string | null>[]) {
      const code = Number(row.id);
      const type = Number(row.type);
      const levelField = Number(row.level);
      const def = Number(row.def);
      const isLink = (type & TYPE_LINK) !== 0;
      const setcodeField = BigInt(row.setcode ?? 0n);
      const setcodes: number[] = [];
      for (let i = 0n; i < 4n; i++) {
        const s = Number((setcodeField >> (16n * i)) & 0xffffn);
        if (s) setcodes.push(s);
      }
      this.cards.set(code, {
        name: String(row.name ?? ''),
        desc: String(row.desc ?? ''),
        strings: Array.from({ length: 16 }, (_, i) => String(row[`str${i + 1}`] ?? '')),
        data: {
          code,
          alias: Number(row.alias),
          setcodes,
          type,
          level: levelField & 0xff,
          attribute: Number(row.attribute),
          race: BigInt(row.race ?? 0n),
          attack: Number(row.atk),
          defense: isLink ? 0 : def,
          lscale: (levelField >>> 24) & 0xff,
          rscale: (levelField >>> 16) & 0xff,
          link_marker: isLink ? def : 0,
        },
      });
    }
    db.close();
  }

  private nameIndex: Map<string, number> | null = null;

  /** Finds a card by its exact English name (not case sensitive). Alternate-art copies are ignored. */
  findByName(name: string): number | null {
    if (!this.nameIndex) {
      this.nameIndex = new Map();
      for (const [code, info] of [...this.cards].sort((a, b) => a[0] - b[0])) {
        const key = info.name.toLowerCase();
        if (info.data.alias === 0 && !this.nameIndex.has(key)) this.nameIndex.set(key, code);
      }
    }
    return this.nameIndex.get(name.trim().toLowerCase()) ?? null;
  }

  /** The "real" card a code stands for (alternate artworks share their original's identity). */
  baseCode(code: number): number {
    const alias = this.cards.get(code)?.data.alias ?? 0;
    return alias || code;
  }

  /** Fusion, Synchro, Xyz and Link monsters live in the Extra Deck. */
  isExtraDeckCard(code: number): boolean {
    const type = Number(this.cards.get(code)?.data.type ?? 0);
    return (type & (0x40 | 0x2000 | 0x800000 | 0x4000000)) !== 0;
  }

  /** Adds a card that is not in the .cdb files (our custom cards). */
  addCard(code: number, info: CardInfo): void {
    this.cards.set(code, info);
    this.nameIndex = null;
  }

  get(code: number): CardInfo | undefined {
    return this.cards.get(code);
  }

  name(code: number): string {
    return this.cards.get(code)?.name ?? (code ? `#${code}` : 'a face-down card');
  }
}
