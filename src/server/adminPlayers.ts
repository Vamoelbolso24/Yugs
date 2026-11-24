// Admin tools for players: look someone up, see what they own, ban or unban them.
//   GET  /api/admin/players?q=name        (newest accounts when q is empty; 50 at most)
//   GET  /api/admin/players/:id           one player in detail (decks, recent packs)
//   POST /api/admin/players/:id/ban       { days: number | null (null = forever), reason }
//   POST /api/admin/players/:id/unban
//   POST /api/admin/players/:id/delete    { confirm: <their username> }  deletes the account and all its data
// Muting in chat uses the chat API: POST /api/admin/chat/mute { username, minutes }.
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Accounts } from '../auth/accounts.ts';
import type { Db } from '../db/database.ts';

type Send = (res: ServerResponse, status: number, body: unknown) => void;
type ReadBody = (req: IncomingMessage, limit?: number) => Promise<Record<string, unknown>>;

const SUMMARY = `SELECT u.id, u.username, u.email, u.email_verified, u.is_admin, u.elo, u.coins, u.wins, u.losses, u.draws,
    u.created_at, u.last_login_at, u.banned_until, u.ban_reason, u.chat_muted_until, u.free_packs, u.starter_deck,
    (SELECT COALESCE(SUM(copies), 0) FROM collection c WHERE c.user_id = u.id) AS cards,
    (SELECT COUNT(*) FROM collection c WHERE c.user_id = u.id) AS distinct_cards,
    (SELECT COUNT(*) FROM pack_openings p WHERE p.user_id = u.id) AS packs_opened,
    (SELECT COUNT(*) FROM pack_openings p WHERE p.user_id = u.id AND p.free = 0) AS packs_bought
  FROM users u`;

const view = (r: any) => ({
  id: r.id, username: r.username, email: r.email, emailVerified: r.email_verified === 1, isAdmin: r.is_admin === 1,
  elo: r.elo, coins: r.coins, wins: r.wins, losses: r.losses, draws: r.draws,
  createdAt: r.created_at, lastLoginAt: r.last_login_at, bannedUntil: r.banned_until, banReason: r.ban_reason,
  mutedUntil: r.chat_muted_until, freePacks: r.free_packs, starter: r.starter_deck,
  cards: r.cards, distinctCards: r.distinct_cards, packsOpened: r.packs_opened, packsBought: r.packs_bought,
});

export function createAdminPlayers(deps: {
  accounts: Accounts; db: Db; sendJson: Send; readBody: ReadBody;
  onBanned: (userId: number) => void;
}) {
  const { accounts, db, sendJson, readBody, onBanned } = deps;

  return async function handle(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<boolean> {
    if (parts[0] !== 'admin' || parts[1] !== 'players') return false;
    const user = accounts.userFromRequest(req);
    if (!user || !user.isAdmin) { sendJson(res, 403, { error: 'Admins only.' }); return true; }

    if (req.method === 'GET' && !parts[2]) {
      const q = (new URL(req.url ?? '', 'http://x').searchParams.get('q') ?? '').trim();
      const rows = q
        ? db.prepare(`${SUMMARY} WHERE u.username LIKE ? ESCAPE '\\' OR u.email LIKE ? ESCAPE '\\' ORDER BY u.username LIMIT 50`)
            .all(...Array(2).fill(`%${q.replace(/[\\%_]/g, (m) => '\\' + m)}%`))
        : db.prepare(`${SUMMARY} ORDER BY u.id DESC LIMIT 50`).all();
      const total = (db.prepare('SELECT COUNT(*) AS n FROM users').get() as { n: number }).n;
      sendJson(res, 200, { players: (rows as any[]).map(view), total });
      return true;
    }

    const id = Number(parts[2]);
    const row = Number.isInteger(id) ? (db.prepare(`${SUMMARY} WHERE u.id = ?`).get(id) as any) : undefined;
    if (!row) { sendJson(res, 404, { error: 'No such player.' }); return true; }

    if (req.method === 'GET' && !parts[3]) {
      const decks = db.prepare('SELECT id, name FROM decks WHERE user_id = ? ORDER BY name').all(id);
      const packs = (db.prepare('SELECT pack_id, free, opened_at, cards FROM pack_openings WHERE user_id = ? ORDER BY opened_at DESC LIMIT 20').all(id) as any[])
        .map((p) => ({ pack: p.pack_id, free: p.free === 1, openedAt: p.opened_at, cards: (() => { try { return JSON.parse(p.cards).length; } catch { return 0; } })() }));
      sendJson(res, 200, { player: view(row), decks, packs });
      return true;
    }

    if (req.method === 'POST' && parts[3] === 'ban') {
      if (row.is_admin === 1) { sendJson(res, 400, { error: 'Admins can\'t be banned. Remove their admin rights first.' }); return true; }
      const b = await readBody(req);
      const days = b.days === null ? null : Number(b.days);
      if (days !== null && !(days > 0 && days <= 3650)) { sendJson(res, 400, { error: 'Pick how long the ban lasts.' }); return true; }
      accounts.ban(id, days, String(b.reason ?? '').trim().slice(0, 300));
      onBanned(id);
      sendJson(res, 200, { player: view(db.prepare(`${SUMMARY} WHERE u.id = ?`).get(id)) });
      return true;
    }
    if (req.method === 'POST' && parts[3] === 'delete') {
      if (row.is_admin === 1) { sendJson(res, 400, { error: 'Admins can\'t be deleted. Remove their admin rights first.' }); return true; }
      const b = await readBody(req);
      if (String(b.confirm ?? '') !== row.username) { sendJson(res, 400, { error: `Type ${row.username} exactly to confirm.` }); return true; }
      onBanned(id); // ends their duels and queue spot first
      accounts.deleteAccount(id);
      sendJson(res, 200, { deleted: row.username });
      return true;
    }
    if (req.method === 'POST' && parts[3] === 'unban') {
      accounts.unban(id);
      sendJson(res, 200, { player: view(db.prepare(`${SUMMARY} WHERE u.id = ?`).get(id)) });
      return true;
    }
    sendJson(res, 404, { error: 'Unknown request.' });
    return true;
  };
}
