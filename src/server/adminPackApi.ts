// Pack Maker endpoints (admins only): make packs, upload their artwork, and schedule next week's shop.
//   GET    /api/admin/packs              -> every pack, the shop (now + scheduled), card texts
//   POST   /api/admin/packs              { id?, name, description, cards: { common: [codes], ... } } -> save
//   DELETE /api/admin/packs/:id
//   POST   /api/admin/packs/:id/art      { image: "data:image/png;base64,..." }
//   PUT    /api/admin/shop               { next: [pack ids] }  (empty list = cancel the schedule)
//   PUT    /api/admin/banlist            { forbidden, limited, semiLimited: [codes] }
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Accounts } from '../auth/accounts.ts';
import type { CardDatabase } from '../engine/cardDb.ts';
import { cardTexts } from '../engine/cardText.ts';
import { RARITIES, type Pack, type Rarity } from '../content/content.ts';
import { SHOP_SIZE, nextWeeklyReset, saveBanlist, type PackStore } from '../content/packStore.ts';
import type { GameContent } from '../content/content.ts';

type Send = (res: ServerResponse, status: number, body: unknown) => void;
type ReadBody = (req: IncomingMessage, limit?: number) => Promise<Record<string, unknown>>;

export function packArtUrl(p: Pack): string | null {
  return p.art ? `/pack-art/${encodeURIComponent(p.art)}` : null;
}

export function createAdminPackApi(deps: { accounts: Accounts; packStore: PackStore; content: GameContent; cards: CardDatabase; sendJson: Send; readBody: ReadBody }) {
  const { accounts, packStore, content, cards, sendJson, readBody } = deps;

  const view = (p: Pack) => ({ id: p.id, name: p.name, description: p.description, cards: p.cards, size: p.size, ready: p.ready, missing: p.missing, art: packArtUrl(p) });
  const state = () => {
    const packs = packStore.all();
    return {
      packs: packs.map(view),
      shop: { ...packStore.shop(), size: SHOP_SIZE, nextReset: nextWeeklyReset().toISOString() },
      texts: cardTexts(cards, packs.flatMap((p) => Object.values(p.cards).flat() as number[])),
    };
  };

  return async function handle(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<boolean> {
    if (parts[0] !== 'admin' || !['packs', 'shop', 'banlist', 'card-texts'].includes(parts[1] ?? '')) return false;
    const user = accounts.userFromRequest(req);
    if (!user || !user.isAdmin) {
      sendJson(res, 403, { error: 'Admins only.' });
      return true;
    }
    const [, area, id, action] = parts;
    const m = req.method;

    if (area === 'packs' && m === 'GET' && !id) {
      sendJson(res, 200, state());
      return true;
    }
    if (area === 'packs' && m === 'POST' && !id) {
      const b = await readBody(req, 1_000_000);
      const input: Partial<Record<Rarity, number[]>> = {};
      const raw = (b.cards ?? {}) as Record<string, unknown>;
      for (const r of RARITIES) input[r] = Array.isArray(raw[r]) ? (raw[r] as unknown[]).map(Number).filter(Number.isInteger) : [];
      const r = packStore.save({ id: typeof b.id === 'string' ? b.id : undefined, name: String(b.name ?? ''), description: String(b.description ?? ''), cards: input });
      if (!r.ok) sendJson(res, 400, { error: r.error });
      else sendJson(res, 200, { saved: r.pack.id, ...state() });
      return true;
    }
    if (area === 'packs' && m === 'DELETE' && id && !action) {
      const r = packStore.remove(id);
      if (!r.ok) sendJson(res, 400, { error: r.error });
      else sendJson(res, 200, state());
      return true;
    }
    // POST /api/admin/packs/:id/copy  -> a new pack "<name> (copy)" with the same cards and artwork
    if (area === 'packs' && m === 'POST' && id && action === 'copy') {
      const r = packStore.copy(id);
      if (!r.ok) sendJson(res, 400, { error: r.error });
      else sendJson(res, 200, { saved: r.pack.id, ...state() });
      return true;
    }
    if (area === 'packs' && m === 'POST' && id && action === 'art') {
      const b = await readBody(req, 6_000_000);
      const match = /^data:(image\/[a-z+]+);base64,(.+)$/s.exec(String(b.image ?? ''));
      if (!match) {
        sendJson(res, 400, { error: 'That is not an image.' });
        return true;
      }
      const r = packStore.setArt(id, Buffer.from(match[2]!, 'base64'), match[1]!);
      if (!r.ok) sendJson(res, 400, { error: r.error });
      else sendJson(res, 200, state());
      return true;
    }
    // POST /api/admin/shop/start-now  -> next week's lineup goes in the shop immediately
    if (area === 'shop' && m === 'POST' && id === 'start-now') {
      const r = packStore.startNextNow();
      if (!r.ok) sendJson(res, 400, { error: r.error });
      else sendJson(res, 200, state());
      return true;
    }
    if (area === 'shop' && m === 'PUT') {
      const b = await readBody(req);
      const r = packStore.scheduleNext(Array.isArray(b.next) ? (b.next as unknown[]).map(String) : []);
      if (!r.ok) sendJson(res, 400, { error: r.error });
      else sendJson(res, 200, state());
      return true;
    }
    // POST /api/admin/card-texts  { codes: [passcodes] } -> texts for the known ones (Pack Maker .ydk import)
    if (area === 'card-texts' && m === 'POST') {
      const b = await readBody(req, 500_000);
      const codes = [...new Set((Array.isArray(b.codes) ? b.codes : []).map(Number).filter(Number.isInteger))].slice(0, 2000);
      const known = codes.filter((c) => cards.get(c));
      sendJson(res, 200, { codes: known, unknown: codes.filter((c) => !cards.get(c)), texts: cardTexts(cards, known) });
      return true;
    }

    // PUT /api/admin/banlist  { forbidden: [codes], limited: [codes], semiLimited: [codes] }
    if (area === 'banlist' && m === 'PUT') {
      const b = await readBody(req, 500_000);
      const r = saveBanlist(content, cards, b);
      if (!r.ok) sendJson(res, 400, { error: r.error });
      else sendJson(res, 200, { ...r.banlist, texts: cardTexts(cards, Object.values(r.banlist).flat()) });
      return true;
    }
    sendJson(res, 404, { error: 'Unknown request.' });
    return true;
  };
}
