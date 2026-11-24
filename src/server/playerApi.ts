// Web endpoints for the logged-in player's own things: starter choice, packs, collection, decks.
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Accounts } from '../auth/accounts.ts';
import type { CardDatabase } from '../engine/cardDb.ts';
import { cardText, cardTexts } from '../engine/cardText.ts';
import { CardFilter } from '../engine/cardFilter.ts';
import type { GameContent } from '../content/content.ts';
import type { PlayerData } from '../game/playerData.ts';

type Send = (res: ServerResponse, status: number, body: unknown) => void;
type ReadBody = (req: IncomingMessage) => Promise<Record<string, unknown>>;

export function createPlayerApi(deps: { accounts: Accounts; players: PlayerData; cards: CardDatabase; content: GameContent; sendJson: Send; readBody: ReadBody }) {
  const { accounts, players, cards, content, sendJson, readBody } = deps;

  const packView = (p: GameContent['packs'][number]) => ({
    id: p.id, name: p.name, description: p.description, size: p.size, slots: p.slots,
    cards: p.cards, art: p.art ? `/pack-art/${encodeURIComponent(p.art)}` : null,
  });

  return async function handle(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<boolean> {
    const [area, idPart, action] = parts;
    if (!['me', 'starters', 'packs', 'collection', 'decks', 'cards', 'card-names', 'banlist', 'standings'].includes(area ?? '')) return false;
    const user = accounts.userFromRequest(req);
    if (!user) {
      sendJson(res, 401, { error: 'Please log in.' });
      return true;
    }
    const get = req.method === 'GET';
    const post = req.method === 'POST';

    // GET /api/me  -> account + profile (starter chosen?, free packs, active deck)
    if (area === 'me' && get) {
      sendJson(res, 200, { user, profile: players.profile(user.id) });
      return true;
    }

    // GET /api/card-names?q=...  -> names only (any player; used to "declare a card name" in a duel)
    if (area === 'card-names' && get) {
      const q = (new URL(req.url ?? '', 'http://x').searchParams.get('q') ?? '').trim().toLowerCase();
      const found: { code: number; name: string }[] = [];
      if (q.length >= 2) {
        for (const [code, info] of cards.cards) {
          if (info.data.alias !== 0 || info.hidden || (Number(info.data.type) & 0x4000) /* token */) continue;
          if (info.name.toLowerCase().includes(q)) found.push({ code, name: info.name });
        }
      }
      // names that start with what was typed come first
      found.sort((a, b) => Number(!a.name.toLowerCase().startsWith(q)) - Number(!b.name.toLowerCase().startsWith(q)) || a.name.localeCompare(b.name));
      sendJson(res, 200, { cards: found.slice(0, 30) });
      return true;
    }

    // GET /api/cards?q=...   (admins: search every card in the game, including custom cards)
    if (area === 'cards' && get) {
      if (!user.isAdmin) {
        sendJson(res, 403, { error: 'Admins only.' });
        return true;
      }
      const params = new URL(req.url ?? '', 'http://x').searchParams;
      // ?custom=1 -> every custom card (so admins always see them in the deck editor)
      if (params.get('custom') === '1') {
        const custom = [...cards.cards.entries()]
          .filter(([, c]) => c.customId && !c.hidden && !(Number(c.data.type) & 0x4000) /* no Tokens or hidden cards */).map(([code]) => code).sort((a, b) => a - b);
        sendJson(res, 200, { cards: custom, texts: cardTexts(cards, custom) });
        return true;
      }
      // ?q=text (name or card text) and/or ?f={deck editor filters as JSON}
      const q = (params.get('q') ?? '').trim().toLowerCase();
      let filter: Record<string, unknown> = {};
      try { filter = JSON.parse(params.get('f') ?? '{}') as Record<string, unknown>; } catch { /* ignore a bad filter */ }
      filter.q = q;
      if (q.length < 2 && !CardFilter.isActive({ ...filter, q: '' })) {
        sendJson(res, 200, { cards: [], texts: {} });
        return true;
      }
      const found: { code: number; name: string; rank: number }[] = [];
      // exact name first, then names that start with it, then names that contain it, then card text only
      const rankOf = (name: string) => { const n = name.toLowerCase(); return !q ? 0 : n === q ? 0 : n.startsWith(q) ? 1 : n.includes(q) ? 2 : 3; };
      for (const [code, info] of cards.cards) {
        if (info.data.alias !== 0 || info.hidden || (Number(info.data.type) & 0x4000) /* token */) continue;
        const text = String(code) === q ? cardText(cards, code) : null;
        if (text) { found.push({ code, name: info.name, rank: 0 }); continue; }
        const t = cardText(cards, code);
        if (t && CardFilter.matches(t, filter)) found.push({ code, name: info.name, rank: rankOf(info.name) });
      }
      found.sort((a, b) => a.rank - b.rank || a.name.localeCompare(b.name));
      const codes = found.slice(0, 300).map((x) => x.code);
      sendJson(res, 200, { cards: codes, texts: cardTexts(cards, codes), total: found.length });
      return true;
    }

    // GET /api/starters
    if (area === 'starters' && get && !idPart) {
      const codes = content.starters.flatMap((s) => [...s.main, ...s.extra]);
      sendJson(res, 200, { starters: content.starters, cards: cardTexts(cards, codes) });
      return true;
    }
    // POST /api/starters/choose  { starterId }
    if (area === 'starters' && post && idPart === 'choose') {
      const body = await readBody(req);
      const r = players.chooseStarter(user.id, body.starterId);
      sendJson(res, r.ok ? 200 : 409, r.ok ? { profile: r.value } : { error: r.error });
      return true;
    }

    // GET /api/packs
    if (area === 'packs' && get && !idPart) {
      const active = players.activePacks();
      const codes = active.flatMap((p) => Object.values(p.cards).flat() as number[]);
      sendJson(res, 200, { packs: active.map(packView), cards: cardTexts(cards, codes) });
      return true;
    }
    // POST /api/packs/:id/open-free
    if (area === 'packs' && post && idPart && action === 'open-free') {
      const r = players.openFreePack(user.id, idPart);
      if (!r.ok) sendJson(res, 409, { error: r.error });
      else sendJson(res, 200, { ...r.value, pack: packView(r.value.pack), cardTexts: cardTexts(cards, r.value.cards.map((c) => c.code)) });
      return true;
    }
    // POST /api/packs/:id/buy  (coins + duels, then the pack lock)
    if (area === 'packs' && post && idPart && action === 'buy') {
      const r = players.buyPack(user.id, idPart);
      if (!r.ok) sendJson(res, 409, { error: r.error });
      else sendJson(res, 200, { ...r.value, pack: packView(r.value.pack), cardTexts: cardTexts(cards, r.value.cards.map((c) => c.code)) });
      return true;
    }

    // GET /api/standings?q=name  -> top 100, your place, players matching the search
    if (area === 'standings' && get) {
      const q = (new URL(req.url ?? '', 'http://x').searchParams.get('q') ?? '').slice(0, 30);
      sendJson(res, 200, players.standings(user.id, q));
      return true;
    }

    // GET /api/banlist  -> { forbidden, limited, semiLimited: [codes], texts }
    if (area === 'banlist' && get) {
      sendJson(res, 200, { ...content.banlist, texts: cardTexts(cards, Object.values(content.banlist).flat()) });
      return true;
    }

    // GET /api/collection
    if (area === 'collection' && get) {
      const owned = players.collection(user.id);
      sendJson(res, 200, { cards: owned, texts: cardTexts(cards, owned.map((c) => c.code)) });
      return true;
    }

    // Decks
    if (area === 'decks') {
      const id = idPart ? Number(idPart) : null;
      if (get && id === null) {
        const decks = players.decks(user.id);
        sendJson(res, 200, { decks, texts: cardTexts(cards, decks.flatMap((d) => [...d.main, ...d.extra])) });
        return true;
      }
      if (post && id === null) {
        const body = await readBody(req);
        const r = players.saveDeck(user.id, null, body.name, body.main, body.extra);
        sendJson(res, r.ok ? 200 : 400, r.ok ? { deck: r.value } : { error: r.error });
        return true;
      }
      if (id !== null && Number.isInteger(id)) {
        if (req.method === 'PUT') {
          const body = await readBody(req);
          const r = players.saveDeck(user.id, id, body.name, body.main, body.extra);
          sendJson(res, r.ok ? 200 : 400, r.ok ? { deck: r.value } : { error: r.error });
          return true;
        }
        if (req.method === 'DELETE') {
          const r = players.deleteDeck(user.id, id);
          sendJson(res, r.ok ? 200 : 409, r.ok ? { ok: true } : { error: r.error });
          return true;
        }
        if (post && action === 'activate') {
          const r = players.setActiveDeck(user.id, id);
          sendJson(res, r.ok ? 200 : 409, r.ok ? { ok: true } : { error: r.error });
          return true;
        }
      }
    }
    sendJson(res, 404, { error: 'Unknown request.' });
    return true;
  };
}
