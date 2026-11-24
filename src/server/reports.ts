// Bug reports: players send them from the game, admins read them in a list.
//   POST  /api/reports                 { text, context }   (logged in; 5 per hour)
//   GET   /api/admin/reports?status=open|fixed|closed|all
//   PUT   /api/admin/reports/:id       { status }
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Accounts } from '../auth/accounts.ts';
import type { Db } from '../db/database.ts';

type Send = (res: ServerResponse, status: number, body: unknown) => void;
type ReadBody = (req: IncomingMessage, limit?: number) => Promise<Record<string, unknown>>;
const STATUSES = ['open', 'fixed', 'closed'];

export function createReports(deps: { accounts: Accounts; db: Db; sendJson: Send; readBody: ReadBody }) {
  const { accounts, db, sendJson, readBody } = deps;
  const recent = new Map<number, number[]>();

  return async function handle(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<boolean> {
    const mine = parts[0] === 'reports';
    const admin = parts[0] === 'admin' && parts[1] === 'reports';
    if (!mine && !admin) return false;
    const user = accounts.userFromRequest(req);
    if (!user) { sendJson(res, 401, { error: 'Log in to send a report.' }); return true; }

    if (mine && req.method === 'POST') {
      const b = await readBody(req, 60_000);
      const text = String(b.text ?? '').trim().slice(0, 3000);
      if (text.length < 5) { sendJson(res, 400, { error: 'Tell us a bit more about what happened.' }); return true; }
      const now = Date.now();
      const times = (recent.get(user.id) ?? []).filter((t) => now - t < 3_600_000);
      if (times.length >= 5) { sendJson(res, 429, { error: 'You sent several reports already. Please wait a while before sending more.' }); return true; }
      recent.set(user.id, [...times, now]);
      const context = JSON.stringify(b.context ?? {}).slice(0, 20_000);
      db.prepare('INSERT INTO bug_reports (user_id, username, text, context, created_at) VALUES (?, ?, ?, ?, ?)').run(user.id, user.username, text, context, now);
      sendJson(res, 200, { ok: true });
      return true;
    }

    if (admin) {
      if (!user.isAdmin) { sendJson(res, 403, { error: 'Admins only.' }); return true; }
      if (req.method === 'GET') {
        const status = new URL(req.url ?? '', 'http://x').searchParams.get('status') ?? 'open';
        const rows = (status === 'all'
          ? db.prepare('SELECT * FROM bug_reports ORDER BY created_at DESC LIMIT 200').all()
          : db.prepare('SELECT * FROM bug_reports WHERE status = ? ORDER BY created_at DESC LIMIT 200').all(status)) as any[];
        const counts = Object.fromEntries((db.prepare('SELECT status, COUNT(*) AS n FROM bug_reports GROUP BY status').all() as any[]).map((r) => [r.status, r.n]));
        sendJson(res, 200, {
          reports: rows.map((r) => ({ id: r.id, username: r.username, text: r.text, context: JSON.parse(r.context), status: r.status, createdAt: r.created_at })),
          counts,
        });
        return true;
      }
      if (req.method === 'PUT' && parts[2]) {
        const status = String((await readBody(req)).status ?? '');
        if (!STATUSES.includes(status)) { sendJson(res, 400, { error: 'Unknown status.' }); return true; }
        db.prepare('UPDATE bug_reports SET status = ? WHERE id = ?').run(status, Number(parts[2]));
        sendJson(res, 200, { ok: true });
        return true;
      }
    }
    sendJson(res, 404, { error: 'Unknown request.' });
    return true;
  };
}
