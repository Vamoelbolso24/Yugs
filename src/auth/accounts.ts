// Accounts: sign up, log in, log out, and "who is this request from?" (login cookie).
import { createHash, randomBytes, randomInt } from 'node:crypto';
import type { IncomingMessage } from 'node:http';
import type { Db } from '../db/database.ts';
import { hashPassword, verifyPassword } from './passwords.ts';
import type { SendMail } from './mailer.ts';

export interface User {
  id: number;
  username: string;
  isAdmin: boolean;
  elo: number;
  coins: number;
}

export const SESSION_COOKIE = 'yugs_session';
const SESSION_DAYS = 30;
const USERNAME_RE = /^[A-Za-z0-9_-]{3,20}$/;

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]+\.[^\s@]{2,}$/;
const CODE_MINUTES = 15;
const CODE_TRIES = 5;
/** Unverified sign-ups older than this free their username and email again. */
const UNVERIFIED_HOURS = 24;

type Result<T> = { ok: true; value: T } | { ok: false; error: string; verify?: boolean };
export type CodePurpose = 'verify' | 'reset';

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');

interface UserRow {
  id: number;
  username: string;
  password_hash: string;
  is_admin: number;
  elo: number;
  coins: number;
  email: string | null;
  email_verified: number;
  banned_until: number;
  ban_reason: string | null;
}

/** "Banned forever" is stored as this far-future time. */
export const BAN_FOREVER = 8_640_000_000_000_000;

export function banMessage(until: number, reason: string | null): string {
  const when = until >= BAN_FOREVER ? 'permanently' : `until ${new Date(until).toUTCString().replace(/:\d\d GMT$/, ' UTC')}`;
  return `This account is banned ${when}.${reason ? ` Reason: ${reason}` : ''} Questions: support@playgrounddueling.com`;
}
const toUser = (r: UserRow): User => ({ id: r.id, username: r.username, isAdmin: r.is_admin === 1, elo: r.elo, coins: r.coins });

/** Limits repeated failed logins (per username and per address) to slow down password guessing. */
class LoginLimiter {
  private readonly fails = new Map<string, number[]>();
  private readonly max: number;
  private readonly windowMs: number;
  constructor(max = 8, windowMs = 15 * 60 * 1000) {
    this.max = max;
    this.windowMs = windowMs;
  }

  blocked(keys: string[]): boolean {
    const now = Date.now();
    return keys.some((k) => (this.fails.get(k) ?? []).filter((t) => now - t < this.windowMs).length >= this.max);
  }
  fail(keys: string[]): void {
    const now = Date.now();
    for (const k of keys) this.fails.set(k, [...(this.fails.get(k) ?? []).filter((t) => now - t < this.windowMs), now]);
  }
  clear(keys: string[]): void {
    for (const k of keys) this.fails.delete(k);
  }
}

export class Accounts {
  private readonly db: Db;
  private readonly limiter = new LoginLimiter();
  /** Emails sent: at most 5 an hour per account or address. */
  private readonly mailLimiter = new LoginLimiter(5, 60 * 60 * 1000);
  /** And at most one a minute per account. */
  private readonly lastMail = new Map<string, number>();
  /** Sign-ups per address: 10 an hour. */
  private readonly signupLimiter = new LoginLimiter(10, 60 * 60 * 1000);
  private readonly sendMail: SendMail | null;
  /** Test servers only (no Resend key + YUGS_TEST_CODES=1): the last code per user, so test scripts can sign up. */
  readonly testCodes: Map<number, string> | null = null;

  constructor(db: Db, sendMail: SendMail | null = null, testCodes = false) {
    this.db = db;
    this.sendMail = sendMail;
    if (testCodes) this.testCodes = new Map();
  }

  normalizeEmail(email: unknown): string | null {
    if (typeof email !== 'string') return null;
    const e = email.trim().toLowerCase();
    return e.length <= 200 && EMAIL_RE.test(e) ? e : null;
  }

  /** Frees usernames and emails held by sign-ups that were never verified. */
  private dropStaleSignups(): void {
    const old = this.db
      .prepare('SELECT id FROM users WHERE email_verified = 0 AND created_at < ?')
      .all(Date.now() - UNVERIFIED_HOURS * 3_600_000) as { id: number }[];
    for (const { id } of old) {
      try {
        this.db.prepare('DELETE FROM email_codes WHERE user_id = ?').run(id);
        this.db.prepare('DELETE FROM sessions WHERE user_id = ?').run(id);
        this.db.prepare('DELETE FROM users WHERE id = ? AND email_verified = 0').run(id);
      } catch {
        // Something else points at this account: leave it.
      }
    }
  }

  /** Makes a 6-digit code, stores its hash and emails it. */
  async sendCode(userId: number, purpose: CodePurpose, email: string, address: string): Promise<Result<true>> {
    const now = Date.now();
    const keys = [`m:${userId}`, `a:${address}`];
    const last = this.lastMail.get(`${userId}:${purpose}`) ?? 0;
    if (now - last < 60_000) return { ok: false, error: `Wait ${Math.ceil((60_000 - (now - last)) / 1000)} seconds before asking for another code.` };
    if (this.mailLimiter.blocked(keys)) return { ok: false, error: 'Too many emails. Wait an hour and try again.' };
    if (!this.sendMail) return { ok: false, error: 'Emails are not set up on this server.' };
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    this.db
      .prepare(
        `INSERT INTO email_codes (user_id, purpose, email, code_hash, expires_at, attempts) VALUES (?, ?, ?, ?, ?, 0)
         ON CONFLICT (user_id, purpose) DO UPDATE SET email = excluded.email, code_hash = excluded.code_hash,
           expires_at = excluded.expires_at, attempts = 0`,
      )
      .run(userId, purpose, email, hashToken(`${userId}:${purpose}:${code}`), now + CODE_MINUTES * 60_000);
    this.lastMail.set(`${userId}:${purpose}`, now);
    this.testCodes?.set(userId, code);
    this.mailLimiter.fail(keys);
    const user = this.getById(userId)!;
    const sent = await this.sendMail(
      purpose === 'verify'
        ? {
            to: email,
            subject: `Your Yugs code: ${code}`,
            text: `Hi ${user.username},\n\nYour Yugs verification code is: ${code}\n\nIt works for ${CODE_MINUTES} minutes. If you didn't sign up for Yugs: Playground Dueling, you can ignore this email.`,
          }
        : {
            to: email,
            subject: `Yugs password reset code: ${code}`,
            text: `Hi ${user.username},\n\nYour Yugs password reset code is: ${code}\n\nIt works for ${CODE_MINUTES} minutes. If you didn't ask for a new password, you can ignore this email; your password stays the same.`,
          },
    );
    return sent ? { ok: true, value: true } : { ok: false, error: 'The email could not be sent. Try again in a minute.' };
  }

  /** Checks a code; on success it is used up and the email it was sent to is returned. */
  private useCode(userId: number, purpose: CodePurpose, code: unknown): Result<string> {
    const row = this.db.prepare('SELECT * FROM email_codes WHERE user_id = ? AND purpose = ?').get(userId, purpose) as
      | { email: string; code_hash: string; expires_at: number; attempts: number }
      | undefined;
    if (!row || row.expires_at < Date.now()) return { ok: false, error: 'That code expired. Ask for a new one.' };
    if (row.attempts >= CODE_TRIES) return { ok: false, error: 'Too many wrong codes. Ask for a new one.' };
    const clean = typeof code === 'string' ? code.replace(/\D/g, '') : '';
    if (hashToken(`${userId}:${purpose}:${clean}`) !== row.code_hash) {
      this.db.prepare('UPDATE email_codes SET attempts = attempts + 1 WHERE user_id = ? AND purpose = ?').run(userId, purpose);
      const left = CODE_TRIES - row.attempts - 1;
      return { ok: false, error: left > 0 ? `Wrong code. ${left} ${left === 1 ? 'try' : 'tries'} left.` : 'Too many wrong codes. Ask for a new one.' };
    }
    this.db.prepare('DELETE FROM email_codes WHERE user_id = ? AND purpose = ?').run(userId, purpose);
    return { ok: true, value: row.email };
  }

  private rowByName(username: unknown): UserRow | undefined {
    return typeof username === 'string' ? (this.db.prepare('SELECT * FROM users WHERE username = ?').get(username) as UserRow | undefined) : undefined;
  }
  private rowByEmail(email: string | null): UserRow | undefined {
    return email ? (this.db.prepare('SELECT * FROM users WHERE email = ?').get(email) as UserRow | undefined) : undefined;
  }

  /** Sign-up step 2: the code from the email. Returns the user, now verified. */
  verifySignup(username: unknown, code: unknown): Result<User> {
    const row = this.rowByName(username);
    if (!row) return { ok: false, error: 'That sign-up expired. Create the account again.' };
    if (row.email_verified) return { ok: false, error: 'This account is already verified. Log in.' };
    const used = this.useCode(row.id, 'verify', code);
    if (!used.ok) return used;
    this.db.prepare('UPDATE users SET email_verified = 1, last_login_at = ? WHERE id = ?').run(Date.now(), row.id);
    return { ok: true, value: toUser(row) };
  }

  /** Sends a new sign-up code (needs the password so strangers can't spam someone's inbox). */
  async resendSignupCode(username: unknown, password: unknown, address: string): Promise<Result<true>> {
    const row = this.rowByName(username);
    if (!row || row.email_verified || !row.email || typeof password !== 'string' || !(await verifyPassword(password, row.password_hash))) {
      return { ok: false, error: 'Create the account again.' };
    }
    return this.sendCode(row.id, 'verify', row.email, address);
  }

  /** Forgot password: emails a reset code if that email belongs to an account. Always "ok" so emails can't be probed. */
  async forgotPassword(email: unknown, address: string): Promise<Result<true>> {
    const e = this.normalizeEmail(email);
    if (!e) return { ok: false, error: 'Enter the email address of your account.' };
    const row = this.rowByEmail(e);
    if (row && row.email_verified) {
      const sent = await this.sendCode(row.id, 'reset', e, address);
      if (!sent.ok) return sent;
    }
    return { ok: true, value: true };
  }

  /** Forgot password step 2: code + new password. Logs out everywhere else. */
  async resetWithCode(email: unknown, code: unknown, password: unknown, address: string): Promise<Result<User>> {
    const keys = [`r:${address}`];
    if (this.limiter.blocked(keys)) return { ok: false, error: 'Too many failed attempts. Wait 15 minutes and try again.' };
    const problem = this.validatePassword(password);
    if (problem) return { ok: false, error: problem };
    const row = this.rowByEmail(this.normalizeEmail(email));
    if (!row) {
      this.limiter.fail(keys);
      return { ok: false, error: 'That code expired. Ask for a new one.' };
    }
    const used = this.useCode(row.id, 'reset', code);
    if (!used.ok) {
      this.limiter.fail(keys);
      return used;
    }
    this.db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(await hashPassword(password as string), row.id);
    this.db.prepare('DELETE FROM sessions WHERE user_id = ?').run(row.id);
    return { ok: true, value: toUser(row) };
  }

  /** For older accounts without an email: send a code to a new address. */
  async startAddEmail(userId: number, email: unknown, address: string): Promise<Result<true>> {
    const e = this.normalizeEmail(email);
    if (!e) return { ok: false, error: 'That email address doesn\'t look right.' };
    this.dropStaleSignups();
    const taken = this.rowByEmail(e);
    if (taken && taken.id !== userId) return { ok: false, error: 'That email is already used by another account.' };
    return this.sendCode(userId, 'verify', e, address);
  }

  finishAddEmail(userId: number, code: unknown): Result<User> {
    const used = this.useCode(userId, 'verify', code);
    if (!used.ok) return used;
    try {
      this.db.prepare('UPDATE users SET email = ?, email_verified = 1 WHERE id = ?').run(used.value, userId);
    } catch {
      return { ok: false, error: 'That email is already used by another account.' };
    }
    return { ok: true, value: this.getById(userId)! };
  }

  hasEmail(userId: number): boolean {
    const row = this.db.prepare('SELECT email FROM users WHERE id = ?').get(userId) as { email: string | null } | undefined;
    return !!row?.email;
  }

  validateUsername(username: unknown): string | null {
    if (typeof username !== 'string' || !USERNAME_RE.test(username)) {
      return 'Usernames are 3-20 characters: letters, numbers, _ and - only.';
    }
    return null;
  }

  validatePassword(password: unknown): string | null {
    if (typeof password !== 'string' || password.length < 8) return 'Passwords need at least 8 characters.';
    if (password.length > 200) return 'That password is too long.';
    return null;
  }

  /** Sign-up step 1: makes an unverified account and emails a code. Log in happens after verifySignup. */
  async register(username: unknown, email: unknown, password: unknown, address: string): Promise<Result<{ username: string; email: string; testCode?: string }>> {
    const e = this.normalizeEmail(email);
    const problem = this.validateUsername(username) ?? (e ? null : 'Enter a real email address; your code is sent there.') ?? this.validatePassword(password);
    if (problem) return { ok: false, error: problem };
    if (this.signupLimiter.blocked([`a:${address}`])) return { ok: false, error: 'Too many sign-ups from here. Wait an hour and try again.' };
    this.dropStaleSignups();
    if (this.rowByName(username)) return { ok: false, error: 'That username is taken.' };
    if (this.rowByEmail(e)) return { ok: false, error: 'That email already has an account. Log in, or use "Forgot password?".' };
    const hash = await hashPassword(password as string);
    let id: number;
    try {
      const info = this.db
        .prepare('INSERT INTO users (username, password_hash, created_at, email, email_verified) VALUES (?, ?, ?, ?, 0)')
        .run(username as string, hash, Date.now(), e);
      id = Number(info.lastInsertRowid);
    } catch {
      return { ok: false, error: 'That username or email is taken.' };
    }
    this.signupLimiter.fail([`a:${address}`]);
    // A new account can get the number of a deleted one: forget that one's email timers.
    this.lastMail.delete(`${id}:verify`);
    this.lastMail.delete(`${id}:reset`);
    this.mailLimiter.clear([`m:${id}`]);
    const sent = await this.sendCode(id, 'verify', e!, address);
    if (!sent.ok) {
      this.db.prepare('DELETE FROM email_codes WHERE user_id = ?').run(id);
      this.db.prepare('DELETE FROM users WHERE id = ?').run(id);
      return sent;
    }
    return { ok: true, value: { username: username as string, email: e!, testCode: this.testCodes?.get(id) } };
  }

  async login(username: unknown, password: unknown, address: string): Promise<Result<User>> {
    if (typeof username !== 'string' || typeof password !== 'string') return { ok: false, error: 'Enter your username and password.' };
    const keys = [`u:${username.toLowerCase()}`, `a:${address}`];
    if (this.limiter.blocked(keys)) return { ok: false, error: 'Too many failed attempts. Wait 15 minutes and try again.' };
    const row = this.db.prepare('SELECT * FROM users WHERE username = ?').get(username) as UserRow | undefined;
    // Always run the hash check so wrong usernames take as long as wrong passwords.
    const valid = await verifyPassword(password, row?.password_hash ?? 'scrypt$16384$8$1$AAAAAAAAAAAAAAAAAAAAAA==$AA==');
    if (!row || !valid) {
      this.limiter.fail(keys);
      return { ok: false, error: 'Wrong username or password.' };
    }
    this.limiter.clear(keys);
    if (row.banned_until > Date.now()) return { ok: false, error: banMessage(row.banned_until, row.ban_reason) };
    if (!row.email_verified) {
      // Correct password, but the email was never confirmed: send them to the code screen.
      return { ok: false, error: 'Enter the code we emailed you to finish signing up.', verify: true };
    }
    this.db.prepare('UPDATE users SET last_login_at = ? WHERE id = ?').run(Date.now(), row.id);
    return { ok: true, value: toUser(row) };
  }

  /** Creates a login session and returns the secret token for the cookie. */
  createSession(userId: number): string {
    const token = randomBytes(32).toString('base64url');
    const now = Date.now();
    this.db
      .prepare('INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)')
      .run(hashToken(token), userId, now, now + SESSION_DAYS * 86_400_000);
    this.db.prepare('DELETE FROM sessions WHERE expires_at < ?').run(now);
    return token;
  }

  endSession(token: string | null): void {
    if (token) this.db.prepare('DELETE FROM sessions WHERE token_hash = ?').run(hashToken(token));
  }

  userFromToken(token: string | null): User | null {
    if (!token) return null;
    const row = this.db
      .prepare(
        `SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = ? AND s.expires_at > ? AND u.banned_until <= ?`,
      )
      .get(hashToken(token), Date.now(), Date.now()) as UserRow | undefined;
    return row ? toUser(row) : null;
  }

  userFromRequest(req: IncomingMessage): User | null {
    return this.userFromToken(sessionToken(req));
  }

  getById(id: number): User | null {
    const row = this.db.prepare('SELECT * FROM users WHERE id = ?').get(id) as UserRow | undefined;
    return row ? toUser(row) : null;
  }

  /** Admin tool: set a new password and log the user out everywhere. */
  async resetPassword(username: string, newPassword: string): Promise<Result<User>> {
    const problem = this.validatePassword(newPassword);
    if (problem) return { ok: false, error: problem };
    const row = this.db.prepare('SELECT * FROM users WHERE username = ?').get(username) as UserRow | undefined;
    if (!row) return { ok: false, error: `No user called ${username}.` };
    this.db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(await hashPassword(newPassword), row.id);
    this.db.prepare('DELETE FROM sessions WHERE user_id = ?').run(row.id);
    return { ok: true, value: toUser(row) };
  }

  /** Admin tool: ban (logs them out everywhere). days = null means forever. */
  ban(userId: number, days: number | null, reason: string): void {
    const until = days === null ? BAN_FOREVER : Date.now() + days * 86_400_000;
    this.db.prepare('UPDATE users SET banned_until = ?, ban_reason = ? WHERE id = ?').run(until, reason || null, userId);
    this.db.prepare('DELETE FROM sessions WHERE user_id = ?').run(userId);
  }

  /** Admin tool (player asked for it): deletes the account and everything linked to it. */
  deleteAccount(userId: number): void {
    this.db.exec('BEGIN');
    try {
      for (const table of ['email_codes', 'chat_messages', 'bug_reports', 'sessions', 'collection', 'decks', 'pack_openings']) {
        this.db.prepare(`DELETE FROM ${table} WHERE user_id = ?`).run(userId);
      }
      this.db.prepare('DELETE FROM users WHERE id = ?').run(userId);
      this.db.exec('COMMIT');
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
  }

  unban(userId: number): void {
    this.db.prepare('UPDATE users SET banned_until = 0, ban_reason = NULL WHERE id = ?').run(userId);
  }

  setAdmin(username: string, isAdmin: boolean): boolean {
    return this.db.prepare('UPDATE users SET is_admin = ? WHERE username = ?').run(isAdmin ? 1 : 0, username).changes > 0;
  }

  listUsers(): User[] {
    return (this.db.prepare('SELECT * FROM users ORDER BY id').all() as unknown as UserRow[]).map(toUser);
  }
}

export function sessionToken(req: IncomingMessage): string | null {
  const header = req.headers.cookie ?? '';
  for (const part of header.split(';')) {
    const [k, ...v] = part.trim().split('=');
    if (k === SESSION_COOKIE) return decodeURIComponent(v.join('='));
  }
  return null;
}

export function sessionCookie(token: string, secure: boolean): string {
  return `${SESSION_COOKIE}=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${SESSION_DAYS * 86400}${secure ? '; Secure' : ''}`;
}

export function clearSessionCookie(): string {
  return `${SESSION_COOKIE}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`;
}
