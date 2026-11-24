// Maintenance mode. While it is on, players can't start new duels (duels already running can finish)
// and they see your message instead of the menus. Admins can still do everything.
// Saved in data/site-status.json so it survives a restart.
//   GET  /api/status             -> { maintenance, message }      (anyone)
//   POST /api/admin/status       { maintenance, message }          (admins)
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Accounts } from '../auth/accounts.ts';
import { ROOT } from '../paths.ts';

type Send = (res: ServerResponse, status: number, body: unknown) => void;
type ReadBody = (req: IncomingMessage, limit?: number) => Promise<Record<string, unknown>>;
export interface SiteStatus { maintenance: boolean; message: string }

const DEFAULT_MESSAGE = 'Yugs is being updated. Duels already running can be finished; new duels open again soon.';

export function createSiteStatus(deps: { accounts: Accounts; sendJson: Send; readBody: ReadBody }) {
  const { accounts, sendJson, readBody } = deps;
  const file = path.join(path.dirname(process.env.YUGS_DB ?? path.join(ROOT, 'data', 'yugs.db')), 'site-status.json');
  let status: SiteStatus = { maintenance: false, message: '' };
  try {
    const raw = JSON.parse(readFileSync(file, 'utf8'));
    status = { maintenance: raw.maintenance === true, message: typeof raw.message === 'string' ? raw.message : '' };
  } catch { /* no file yet */ }
  if (status.maintenance) console.log('Maintenance mode is ON (turn it off on the main page, or delete ' + file + ').');

  const view = () => ({ maintenance: status.maintenance, message: status.message || DEFAULT_MESSAGE });

  return {
    /** True when this request must be refused because of maintenance (it then answers it). */
    blockNewDuel(req: IncomingMessage, res: ServerResponse): boolean {
      if (!status.maintenance || accounts.userFromRequest(req)?.isAdmin) return false;
      sendJson(res, 503, { error: view().message, maintenance: true });
      return true;
    },
    async handle(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<boolean> {
      if (parts[0] === 'status' && parts.length === 1 && req.method === 'GET') {
        sendJson(res, 200, view());
        return true;
      }
      if (parts[0] !== 'admin' || parts[1] !== 'status') return false;
      if (!accounts.userFromRequest(req)?.isAdmin) { sendJson(res, 403, { error: 'Admins only.' }); return true; }
      if (req.method !== 'POST') { sendJson(res, 404, { error: 'Unknown request.' }); return true; }
      const b = await readBody(req);
      status = { maintenance: b.maintenance === true, message: String(b.message ?? '').trim().slice(0, 500) };
      mkdirSync(path.dirname(file), { recursive: true });
      writeFileSync(file, JSON.stringify(status, null, 2));
      console.log(`Maintenance mode turned ${status.maintenance ? 'ON' : 'off'}.`);
      sendJson(res, 200, view());
      return true;
    },
  };
}
