// Main menu chat: one shared room for everyone logged in (not shown during duels).
//   GET    /api/chat/events            live stream (Server-Sent Events): history, new messages, deletions
//   POST   /api/chat                   { text }
//   DELETE /api/admin/chat/:id         (admins) remove a message for everyone
//   POST   /api/admin/chat/mute        (admins) { username, minutes }  minutes 0 = unmute
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Accounts } from '../auth/accounts.ts';
import type { Db } from '../db/database.ts';

type Send = (res: ServerResponse, status: number, body: unknown) => void;
type ReadBody = (req: IncomingMessage, limit?: number) => Promise<Record<string, unknown>>;

const HISTORY = 100;
const MAX_LENGTH = 300;
const MIN_GAP_MS = 2000;

interface ChatMessage { id: number; username: string; text: string; createdAt: number }

export function createChat(deps: { accounts: Accounts; db: Db; sendJson: Send; readBody: ReadBody }) {
  const { accounts, db, sendJson, readBody } = deps;
  const clients = new Map<ServerResponse, number>(); // stream -> user id
  const lastSent = new Map<number, number>();

  const history = (): ChatMessage[] =>
    (db.prepare('SELECT id, username, text, created_at AS createdAt FROM chat_messages WHERE deleted = 0 ORDER BY id DESC LIMIT ?').all(HISTORY) as unknown as ChatMessage[]).reverse();
  const online = () => new Set(clients.values()).size;
  const push = (event: unknown) => {
    const data = `data: ${JSON.stringify(event)}\n\n`;
    for (const res of clients.keys()) res.write(data);
  };
  setInterval(() => { for (const res of clients.keys()) res.write(': ping\n\n'); }, 20_000).unref();

  return async function handle(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<boolean> {
    const isChat = parts[0] === 'chat';
    const isAdmin = parts[0] === 'admin' && parts[1] === 'chat';
    if (!isChat && !isAdmin) return false;
    const user = accounts.userFromRequest(req);
    if (!user) { sendJson(res, 401, { error: 'Log in to chat.' }); return true; }

    if (isChat && parts[1] === 'events' && req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-store', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
      res.write('retry: 3000\n\n');
      clients.set(res, user.id);
      res.write(`data: ${JSON.stringify({ type: 'history', messages: history(), online: online() })}\n\n`);
      push({ type: 'online', online: online() });
      res.on('close', () => { clients.delete(res); push({ type: 'online', online: online() }); });
      return true;
    }

    if (isChat && !parts[1] && req.method === 'POST') {
      const text = String((await readBody(req, 5_000)).text ?? '').replace(/\s+/g, ' ').trim();
      if (!text) { sendJson(res, 400, { error: 'Write something first.' }); return true; }
      if (text.length > MAX_LENGTH) { sendJson(res, 400, { error: `Messages can be up to ${MAX_LENGTH} letters.` }); return true; }
      const muted = (db.prepare('SELECT chat_muted_until FROM users WHERE id = ?').get(user.id) as { chat_muted_until: number }).chat_muted_until;
      if (muted > Date.now()) {
        const mins = Math.ceil((muted - Date.now()) / 60_000);
        sendJson(res, 403, { error: `You are muted for ${mins >= 120 ? `${Math.ceil(mins / 60)} more hours` : `${mins} more minute${mins === 1 ? '' : 's'}`}.` });
        return true;
      }
      const now = Date.now();
      if (now - (lastSent.get(user.id) ?? 0) < MIN_GAP_MS) { sendJson(res, 429, { error: 'Slow down a little.' }); return true; }
      lastSent.set(user.id, now);
      const r = db.prepare('INSERT INTO chat_messages (user_id, username, text, created_at) VALUES (?, ?, ?, ?)').run(user.id, user.username, text, now);
      // keep the table small
      db.prepare('DELETE FROM chat_messages WHERE id <= ?').run(Number(r.lastInsertRowid) - 1000);
      push({ type: 'message', message: { id: Number(r.lastInsertRowid), username: user.username, text, createdAt: now } });
      sendJson(res, 200, { ok: true });
      return true;
    }

    if (isAdmin) {
      if (!user.isAdmin) { sendJson(res, 403, { error: 'Admins only.' }); return true; }
      if (req.method === 'DELETE' && parts[2]) {
        const id = Number(parts[2]);
        db.prepare('UPDATE chat_messages SET deleted = 1 WHERE id = ?').run(id);
        push({ type: 'delete', id });
        sendJson(res, 200, { ok: true });
        return true;
      }
      if (req.method === 'POST' && parts[2] === 'mute') {
        const b = await readBody(req);
        const minutes = Math.max(0, Math.min(60 * 24 * 365, Number(b.minutes) || 0));
        const until = minutes ? Date.now() + minutes * 60_000 : 0;
        const r = db.prepare('UPDATE users SET chat_muted_until = ? WHERE username = ? COLLATE NOCASE').run(until, String(b.username ?? ''));
        if (!r.changes) { sendJson(res, 404, { error: 'No player with that name.' }); return true; }
        sendJson(res, 200, { ok: true, until });
        return true;
      }
    }
    sendJson(res, 404, { error: 'Unknown request.' });
    return true;
  };
}
