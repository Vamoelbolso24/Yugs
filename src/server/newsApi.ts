// Main page: news posts (admins write them) and the tutorial (content/tutorial.md, edit it by hand).
//   GET    /api/news                  -> { news: [...latest 20], tutorial, homeNote (markdown) }   (anyone)
//   POST   /api/admin/news            { title, body }        (admins)
//   PUT    /api/admin/news/:id        { title, body }
//   DELETE /api/admin/news/:id
import { readFileSync } from 'node:fs';
import path from 'node:path';
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Accounts } from '../auth/accounts.ts';
import type { Db } from '../db/database.ts';
import { CONTENT_DIR } from '../content/content.ts';

type Send = (res: ServerResponse, status: number, body: unknown) => void;
type ReadBody = (req: IncomingMessage, limit?: number) => Promise<Record<string, unknown>>;

export function createNewsApi(deps: { accounts: Accounts; db: Db; sendJson: Send; readBody: ReadBody }) {
  const { accounts, db, sendJson, readBody } = deps;
  const list = () => db.prepare('SELECT id, title, body, author, created_at AS createdAt, updated_at AS updatedAt FROM news ORDER BY created_at DESC LIMIT 20').all();
  const file = (name: string) => {
    try { return readFileSync(path.join(CONTENT_DIR, name), 'utf-8'); } catch { return ''; }
  };
  const tutorial = () => file('tutorial.md');
  /** The short note at the top of the main page (content/home-note.md). */
  const homeNote = () => file('home-note.md');
  const clean = (b: Record<string, unknown>) => {
    const title = String(b.title ?? '').trim().slice(0, 120);
    const body = String(b.body ?? '').trim().slice(0, 5000);
    return title && body ? { title, body } : null;
  };

  return async function handle(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<boolean> {
    if (parts[0] === 'news' && parts.length === 1 && req.method === 'GET') {
      sendJson(res, 200, { news: list(), tutorial: tutorial(), homeNote: homeNote() });
      return true;
    }
    if (parts[0] !== 'admin' || parts[1] !== 'news') return false;
    const user = accounts.userFromRequest(req);
    if (!user?.isAdmin) {
      sendJson(res, 403, { error: 'Admins only.' });
      return true;
    }
    const id = parts[2] ? Number(parts[2]) : null;
    const now = Date.now();
    if (req.method === 'POST' && id === null) {
      const v = clean(await readBody(req, 50_000));
      if (!v) { sendJson(res, 400, { error: 'A post needs a title and some text.' }); return true; }
      db.prepare('INSERT INTO news (title, body, author, created_at, updated_at) VALUES (?, ?, ?, ?, ?)').run(v.title, v.body, user.username, now, now);
    } else if (req.method === 'PUT' && id) {
      const v = clean(await readBody(req, 50_000));
      if (!v) { sendJson(res, 400, { error: 'A post needs a title and some text.' }); return true; }
      db.prepare('UPDATE news SET title = ?, body = ?, updated_at = ? WHERE id = ?').run(v.title, v.body, now, id);
    } else if (req.method === 'DELETE' && id) {
      db.prepare('DELETE FROM news WHERE id = ?').run(id);
    } else {
      sendJson(res, 404, { error: 'Unknown request.' });
      return true;
    }
    sendJson(res, 200, { news: list(), tutorial: tutorial(), homeNote: homeNote() });
    return true;
  };
}
