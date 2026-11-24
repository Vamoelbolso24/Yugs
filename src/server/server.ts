// Local web server: serves the duel page and runs duels for it.
// Start with:  npm start   (then open http://localhost:3000)
import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { networkInterfaces } from 'node:os';
import { CardDatabase } from '../engine/cardDb.ts';
import { DuelSession } from '../game/session.ts';
import { RoomManager } from './rooms.ts';
import { Matchmaker } from './matchmaker.ts';
import { openDatabase } from '../db/database.ts';
import { createMailer } from '../auth/mailer.ts';
import { loadLocalSettings } from '../localSettings.ts';
import { Accounts, clearSessionCookie, sessionCookie, sessionToken } from '../auth/accounts.ts';
import { ContentError, PACK_ART_DIR, loadContent } from '../content/content.ts';
import { PackStore } from '../content/packStore.ts';
import { createAdminPackApi } from './adminPackApi.ts';
import { createNewsApi } from './newsApi.ts';
import { createChat } from './chat.ts';
import { createReports } from './reports.ts';
import { createAdminPlayers } from './adminPlayers.ts';
import { createSiteStatus } from './siteStatus.ts';
import { PlayerData } from '../game/playerData.ts';
import { createPlayerApi } from './playerApi.ts';
import { CUSTOM_PICS_DIR, customScriptReader } from '../content/customCards.ts';
import { setCustomScriptReader } from '../engine/scriptReader.ts';
import { CARD_DB_FILES, ROOT } from '../paths.ts';

const PORT = Number(process.env.PORT ?? 3000);
const PUBLIC_DIR = path.join(ROOT, 'public');
const BRANDING_DIR = path.join(ROOT, 'content', 'branding');
const MIME: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
};

console.log('Loading card database...');
const cards = new CardDatabase(CARD_DB_FILES);
console.log(`Loaded ${cards.cards.size} cards.`);
/** Local duels (practice, vs bot, admin test). viewer 'all' = one person plays both sides. */
const sessions = new Map<string, { session: DuelSession; ownerId: number | null; owner: string; viewer: 0 | 1 | 'all'; lastUsed: number }>();
/** Each account (or, logged out, each internet address) keeps at most this many practice/bot duels; starting another drops the oldest. */
const LOCAL_DUELS_EACH = 2;
/** All local duels together, so the server's memory can't fill up. */
const LOCAL_DUELS_MAX = 400;

function dropLocalDuel(id: string): void {
  const e = sessions.get(id);
  if (!e) return;
  sessions.delete(id);
  e.session.dispose();
}

/** Remembers a new local duel and makes room for it. */
function addLocalDuel(session: DuelSession, ownerId: number | null, owner: string, viewer: 0 | 1 | 'all'): void {
  const mine = [...sessions].filter(([, e]) => e.owner === owner).sort((a, b) => a[1].lastUsed - b[1].lastUsed);
  while (mine.length >= LOCAL_DUELS_EACH) dropLocalDuel(mine.shift()![0]);
  if (sessions.size >= LOCAL_DUELS_MAX) {
    const oldest = [...sessions].sort((a, b) => a[1].lastUsed - b[1].lastUsed)[0];
    if (oldest) dropLocalDuel(oldest[0]);
  }
  sessions.set(session.id, { session, ownerId, owner, viewer, lastUsed: Date.now() });
}

// Clean up practice/bot duels nobody touched for a while (finished: 15 minutes, unfinished: 2 hours).
setInterval(() => {
  const now = Date.now();
  for (const [id, e] of sessions) {
    const idle = now - e.lastUsed;
    if (idle > (e.session.winner !== null ? 15 * 60_000 : 2 * 60 * 60_000)) dropLocalDuel(id);
  }
}, 60_000).unref();
const db = openDatabase();
const localSettings = loadLocalSettings();
// YUGS_TEST_CODES=1 lets test scripts sign up without an inbox. Ignored when a real email key is set.
const testCodes = process.env.YUGS_TEST_CODES === '1' && !localSettings.resendApiKey;
if (testCodes) console.log('Test mode: sign-up codes are sent back to the browser. Never use this on the public server.');
const accounts = new Accounts(db, createMailer(localSettings), testCodes);
console.log(`Database ready (${accounts.listUsers().length} accounts).`);
let content;
try {
  content = loadContent(cards);
} catch (e) {
  if (e instanceof ContentError) {
    console.error(`\n${e.message}\n\nFix these in the content folder, then start the server again.`);
    process.exit(1);
  }
  throw e;
}
console.log(`Content ready: ${content.starters.length} starter decks, ${content.packs.length} packs, ${content.custom.length} custom cards.`);
setCustomScriptReader(customScriptReader());
const players = new PlayerData(db, cards, content);
const packStore = new PackStore(content, cards);
players.setShopSource(() => packStore.shopPacks());

/** The player's address. Behind the HTTPS proxy (Caddy, same machine) the real one is in X-Forwarded-For. */
function clientAddress(req: IncomingMessage): string {
  const direct = req.socket.remoteAddress ?? 'unknown';
  const local = direct === '127.0.0.1' || direct === '::1' || direct === '::ffff:127.0.0.1';
  const forwarded = req.headers['x-forwarded-for'];
  if (local && typeof forwarded === 'string' && forwarded) return forwarded.split(',').at(-1)!.trim();
  return direct;
}

async function handleAuthApi(req: IncomingMessage, res: ServerResponse, action: string): Promise<void> {
  // GET /api/auth/me
  if (req.method === 'GET' && action === 'me') {
    const user = accounts.userFromRequest(req);
    return sendJson(res, 200, { user, needsEmail: user ? !accounts.hasEmail(user.id) : false });
  }
  if (req.method !== 'POST') return sendJson(res, 404, { error: 'Unknown request.' });
  const body = await readBody(req);
  const secure = req.headers['x-forwarded-proto'] === 'https';
  const address = clientAddress(req);
  const logIn = (user: { id: number }) => res.setHeader('Set-Cookie', sessionCookie(accounts.createSession(user.id), secure));

  // POST /api/auth/register { username, email, password } -> a code is emailed, then /verify
  if (action === 'register') {
    const r = await accounts.register(body.username, body.email, body.password, address);
    if (!r.ok) return sendJson(res, 400, { error: r.error });
    return sendJson(res, 200, { verify: true, username: r.value.username, email: r.value.email, ...(r.value.testCode ? { testCode: r.value.testCode } : {}) });
  }
  // POST /api/auth/verify { username, code }
  if (action === 'verify') {
    const r = accounts.verifySignup(body.username, body.code);
    if (!r.ok) return sendJson(res, 400, { error: r.error });
    logIn(r.value);
    return sendJson(res, 200, { user: accounts.getById(r.value.id) });
  }
  // POST /api/auth/resend { username, password }
  if (action === 'resend') {
    const r = await accounts.resendSignupCode(body.username, body.password, address);
    return r.ok ? sendJson(res, 200, { sent: true }) : sendJson(res, 400, { error: r.error });
  }
  // POST /api/auth/login { username, password }
  if (action === 'login') {
    const r = await accounts.login(body.username, body.password, address);
    if (!r.ok) return sendJson(res, 401, { error: r.error, verify: r.verify ?? false });
    logIn(r.value);
    return sendJson(res, 200, { user: r.value, needsEmail: !accounts.hasEmail(r.value.id) });
  }
  // POST /api/auth/forgot { email } -> a reset code is emailed (if the account exists)
  if (action === 'forgot') {
    const r = await accounts.forgotPassword(body.email, address);
    return r.ok ? sendJson(res, 200, { sent: true }) : sendJson(res, 400, { error: r.error });
  }
  // POST /api/auth/reset { email, code, password }
  if (action === 'reset') {
    const r = await accounts.resetWithCode(body.email, body.code, body.password, address);
    if (!r.ok) return sendJson(res, 400, { error: r.error });
    logIn(r.value);
    return sendJson(res, 200, { user: accounts.getById(r.value.id) });
  }
  // Older accounts: POST /api/auth/email { email } then POST /api/auth/email-code { code }
  if (action === 'email' || action === 'email-code') {
    const user = accounts.userFromRequest(req);
    if (!user) return sendJson(res, 401, { error: 'Log in first.' });
    if (action === 'email') {
      const r = await accounts.startAddEmail(user.id, body.email, address);
      return r.ok ? sendJson(res, 200, { sent: true }) : sendJson(res, 400, { error: r.error });
    }
    const r = accounts.finishAddEmail(user.id, body.code);
    return r.ok ? sendJson(res, 200, { user: r.value, needsEmail: false }) : sendJson(res, 400, { error: r.error });
  }

  // POST /api/auth/logout
  if (action === 'logout') {
    accounts.endSession(sessionToken(req));
    res.setHeader('Set-Cookie', clearSessionCookie());
    return sendJson(res, 200, { user: null });
  }
  return sendJson(res, 404, { error: 'Unknown request.' });
}
const rooms = new RoomManager(cards);
rooms.onFinished = (userIds, winner, surrendered, ranked) => players.recordDuel(userIds, winner, surrendered, ranked);
const matchmaker = new Matchmaker(rooms);

// Find a duel (ranked): POST /api/match (join the queue), GET /api/match (status, poll), DELETE /api/match (cancel)
async function handleMatchApi(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const user = accounts.userFromRequest(req);
  if (!user) return sendJson(res, 401, { error: 'Log in to find a duel.' });
  if (req.method === 'POST') {
    if (siteStatus.blockNewDuel(req, res)) return;
    const deck = players.duelDeck(user.id);
    if (!deck.ok) return sendJson(res, 409, { error: deck.error });
    return sendJson(res, 200, matchmaker.join(user, user.elo, deck.value));
  }
  if (req.method === 'DELETE') {
    matchmaker.leave(user.id);
    return sendJson(res, 200, { status: 'idle' });
  }
  return sendJson(res, 200, matchmaker.status(user.id));
}

async function handleRoomApi(req: IncomingMessage, res: ServerResponse, parts: string[], url: URL): Promise<void> {
  const user = accounts.userFromRequest(req);
  // POST /api/room  -> create a room, you get seat 0 (you duel with your active deck)
  if (req.method === 'POST' && parts.length === 1) {
    if (!user) return sendJson(res, 401, { error: 'Log in to create an online duel.' });
    if (siteStatus.blockNewDuel(req, res)) return;
    const deck = players.duelDeck(user.id);
    if (!deck.ok) return sendJson(res, 409, { error: deck.error });
    return sendJson(res, 200, rooms.create(user, deck.value));
  }
  const room = parts[1] ? rooms.get(parts[1]) : undefined;
  if (!room) return sendJson(res, 404, { error: 'This duel link is not valid anymore.' });

  // POST /api/room/:id/join   (also gives your seat back if you are already in this duel)
  if (req.method === 'POST' && parts[2] === 'join') {
    if (!user) return sendJson(res, 401, { error: 'Log in to join this duel.' });
    const back = rooms.rejoin(room, user);
    if (back) return sendJson(res, 200, { roomId: room.id, ...back });
    if (siteStatus.blockNewDuel(req, res)) return;
    const deck = players.duelDeck(user.id);
    if (!deck.ok) return sendJson(res, 409, { error: deck.error });
    const result = await rooms.join(room, user, deck.value);
    return sendJson(res, 'error' in result ? 409 : 200, { roomId: room.id, ...result });
  }

  // Everything else needs the seat token.
  const tok = req.method === 'GET' ? url.searchParams.get('token') : (await readBody(req)).token;
  const seat = rooms.seatOf(room, tok);
  if (seat === null) return sendJson(res, 403, { error: 'You are not a player in this duel.' });

  // GET /api/room/:id/events?token=...   (live updates)
  if (req.method === 'GET' && parts[2] === 'events') return rooms.subscribe(room, seat, res);

  // GET /api/room/:id/state?token=...
  if (req.method === 'GET' && parts[2] === 'state') return sendJson(res, 200, rooms.state(room, seat));

  return sendJson(res, 404, { error: 'Unknown request.' });
}

async function handleRoomAction(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<void> {
  const room = parts[1] ? rooms.get(parts[1]) : undefined;
  if (!room) return sendJson(res, 404, { error: 'This duel link is not valid anymore.' });
  const body = await readBody(req);
  const seat = rooms.seatOf(room, body.token);
  if (seat === null) return sendJson(res, 403, { error: 'You are not a player in this duel.' });
  if (parts[2] === 'answer') {
    const result = rooms.answer(room, seat, body.decisionId, body.picks);
    return sendJson(res, result.ok ? 200 : 409, result.ok ? rooms.state(room, seat) : { error: result.error, ...rooms.state(room, seat) });
  }
  if (parts[2] === 'settings') {
    const mode = body.chainMode;
    if (mode !== 'smart' && mode !== 'always' && mode !== 'never') return sendJson(res, 400, { error: 'Unknown setting.' });
    rooms.setChainMode(room, seat, mode);
    return sendJson(res, 200, rooms.state(room, seat));
  }
  if (parts[2] === 'surrender') {
    rooms.surrender(room, seat);
    return sendJson(res, 200, rooms.state(room, seat));
  }
  return sendJson(res, 404, { error: 'Unknown request.' });
}

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

async function readBody(req: IncomingMessage, limit = 100_000): Promise<Record<string, unknown>> {
  let raw = '';
  for await (const chunk of req) {
    raw += chunk;
    if (raw.length > limit) throw new Error('Request too large');
  }
  return raw ? (JSON.parse(raw) as Record<string, unknown>) : {};
}

async function serveStatic(urlPath: string, res: ServerResponse): Promise<void> {
  // Custom card artwork: /custom-pics/<ID>.jpg  (from content/custom/pics)
  // Pack artwork: /pack-art/<file>  (from content/packs/art)
  // Site logo and link-preview image: /branding/<file>  (from content/branding, kept out of git like the card pictures)
  const fromCustom = urlPath.startsWith('/custom-pics/');
  const fromPackArt = urlPath.startsWith('/pack-art/');
  const fromBranding = urlPath.startsWith('/branding/');
  const base = fromCustom ? CUSTOM_PICS_DIR : fromPackArt ? PACK_ART_DIR : fromBranding ? BRANDING_DIR : PUBLIC_DIR;
  const prefix = fromCustom ? '/custom-pics/' : fromPackArt ? '/pack-art/' : fromBranding ? '/branding/' : '';
  const relative = urlPath === '/' ? 'index.html' : decodeURIComponent(urlPath.slice(prefix.length)).replace(/^\/+/, '');
  const file = path.resolve(base, relative);
  if (!file.startsWith(base + path.sep)) {
    res.writeHead(403).end('Forbidden');
    return;
  }
  try {
    const content = await readFile(file);
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-cache' });
    res.end(content);
  } catch {
    res.writeHead(404).end('Not found');
  }
}

/** Addresses other computers on the same network can use to reach this server. */
function lanUrls(): string[] {
  const urls: string[] = [];
  for (const list of Object.values(networkInterfaces())) {
    for (const a of list ?? []) {
      if (a.family === 'IPv4' && !a.internal && !a.address.startsWith('169.254.')) urls.push(`http://${a.address}:${PORT}`);
    }
  }
  return urls;
}

const playerApi = createPlayerApi({ accounts, players, cards, content, sendJson, readBody });
const newsApi = createNewsApi({ accounts, db, sendJson, readBody });
const chatApi = createChat({ accounts, db, sendJson, readBody });
const reportsApi = createReports({ accounts, db, sendJson, readBody });
const siteStatus = createSiteStatus({ accounts, sendJson, readBody });
const adminPlayersApi = createAdminPlayers({
  accounts, db, sendJson, readBody,
  onBanned: (userId) => { rooms.forfeitUser(userId, 'was banned'); matchmaker.leave(userId); },
});
const adminPackApi = createAdminPackApi({ accounts, packStore, content, cards, sendJson, readBody });

async function handleApi(req: IncomingMessage, res: ServerResponse, parts: string[]): Promise<void> {
  if (await playerApi(req, res, parts)) return;
  if (await adminPackApi(req, res, parts)) return;
  if (await newsApi(req, res, parts)) return;
  if (await chatApi(req, res, parts)) return;
  if (await reportsApi(req, res, parts)) return;
  if (await adminPlayersApi(req, res, parts)) return;
  if (await siteStatus.handle(req, res, parts)) return;
  // GET /api/info
  if (req.method === 'GET' && parts[0] === 'info') return sendJson(res, 200, { lanUrls: lanUrls() });

  // POST /api/duel  { mode: 'test', ... }  -> start a local duel
  //   mode 'test': admins only. { deckA, deckB, hand: [card codes] } you play both sides,
  //                deck A starts with the given cards in hand. Ownership is not checked.
  if (req.method === 'POST' && parts.length === 1 && parts[0] === 'duel') {
    if (siteStatus.blockNewDuel(req, res)) return;
    const body = await readBody(req);
    const seed = typeof body.seed === 'number' ? body.seed : undefined;
    const user = accounts.userFromRequest(req);
    if (body.mode === 'test') {
      if (!user?.isAdmin) return sendJson(res, 403, { error: 'Test duels are for admins.' });
      const all = players.decks(user.id);
      const a = all.find((d) => d.id === body.deckA);
      const b = all.find((d) => d.id === body.deckB);
      if (!a || !b) return sendJson(res, 400, { error: 'Pick two of your decks.' });
      const hand = (Array.isArray(body.hand) ? body.hand : []).filter((c): c is number => Number.isInteger(c) && !!cards.get(c as number)).slice(0, 10);
      const session = await DuelSession.start(cards, {
        decks: [a, b], names: [`${a.name}`, `${b.name}`], seed, openingHands: [hand, []],
      });
      addLocalDuel(session, user.id, `u:${user.id}`, 'all');
      return sendJson(res, 200, session.view());
    }
    // Practice (hotseat) and vs-bot duels were removed for the public game; a better bot may come back later.
    return sendJson(res, 404, { error: 'Practice and bot duels are not available. Find a duel or invite a friend.' });
  }

  // Anything else that isn't a duel: say so (an old server that wasn't restarted after an update ends up here).
  if (parts[0] !== 'duel') return sendJson(res, 404, { error: 'Unknown request. If the game was just updated, restart the server.' });
  const entry = parts[1] ? sessions.get(parts[1]) : undefined;
  if (!entry) return sendJson(res, 404, { error: 'This duel was closed (it ended, sat unused too long, or you started a newer one). Start a new duel.' });
  entry.lastUsed = Date.now();
  if (entry.ownerId !== null && accounts.userFromRequest(req)?.id !== entry.ownerId) return sendJson(res, 403, { error: 'This is not your duel.' });
  const { session, viewer } = entry;
  const show = () => session.view(viewer);

  // GET /api/duel/:id
  if (req.method === 'GET' && parts.length === 2) return sendJson(res, 200, show());

  // POST /api/duel/:id/answer  { decisionId, picks }
  if (req.method === 'POST' && parts[2] === 'answer') {
    const body = await readBody(req);
    const picks = body.picks === null ? null : Array.isArray(body.picks) ? (body.picks as number[]) : undefined;
    if (picks === undefined || typeof body.decisionId !== 'number') return sendJson(res, 400, { error: 'Bad answer format.' });
    const result = session.answer(body.decisionId, picks, viewer === 'all' ? undefined : viewer);
    if (!result.ok) return sendJson(res, 409, { error: result.error, view: show() });
    return sendJson(res, 200, show());
  }

  // POST /api/duel/:id/settings  { player, chainMode }
  if (req.method === 'POST' && parts[2] === 'settings') {
    const body = await readBody(req);
    const mode = body.chainMode;
    if (mode !== 'smart' && mode !== 'always' && mode !== 'never') return sendJson(res, 400, { error: 'Unknown setting.' });
    session.setChainMode(viewer === 'all' ? (body.player === 1 ? 1 : 0) : viewer, mode);
    return sendJson(res, 200, show());
  }

  // POST /api/duel/:id/surrender  { player }
  if (req.method === 'POST' && parts[2] === 'surrender') {
    const body = await readBody(req);
    session.surrender(viewer === 'all' ? (body.player === 1 ? 1 : 0) : viewer);
    return sendJson(res, 200, show());
  }

  return sendJson(res, 404, { error: 'Unknown request.' });
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', 'http://localhost');
  try {
    if (url.pathname.startsWith('/api/auth/')) {
      await handleAuthApi(req, res, url.pathname.slice('/api/auth/'.length));
    } else if (url.pathname === '/api/match') {
      await handleMatchApi(req, res);
    } else if (url.pathname.startsWith('/api/room')) {
      const parts = url.pathname.slice(5).split('/').filter(Boolean);
      if (req.method === 'POST' && ['answer', 'settings', 'surrender'].includes(parts[2] ?? '')) await handleRoomAction(req, res, parts);
      else await handleRoomApi(req, res, parts, url);
    } else if (url.pathname.startsWith('/api/')) {
      await handleApi(req, res, url.pathname.slice(5).split('/').filter(Boolean));
    } else {
      await serveStatic(url.pathname, res);
    }
  } catch (e) {
    console.error(e);
    if (!res.headersSent) sendJson(res, 500, { error: 'Something went wrong on the server. Details are in the server window.' });
  }
});

// Live-update connections stay open, so don't time them out.
server.requestTimeout = 0;
server.headersTimeout = 60_000;

// HOST=127.0.0.1 on the public server: only Caddy (HTTPS, same machine) can reach the game directly.
server.listen(PORT, process.env.HOST || undefined, () => {
  console.log(`\nYugs is running. Open this address in your browser:\n\n    http://localhost:${PORT}\n`);
  const lan = lanUrls();
  if (lan.length) console.log(`Phones and other computers on the same Wi-Fi can use:\n\n${lan.map((u) => `    ${u}`).join('\n')}\n`);
  console.log('Keep this window open while you play. Press Ctrl+C to stop.');
});
