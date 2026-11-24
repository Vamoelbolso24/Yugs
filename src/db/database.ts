// The game database: one SQLite file (data/yugs.db). On the live server this file lives
// on the server's disk; players can never reach it directly.
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { ROOT } from '../paths.ts';

/**
 * Schema changes, applied in order. Never edit a migration that has already run:
 * add a new one at the end instead.
 */
const MIGRATIONS: string[] = [
  // 1: accounts and login sessions
  `CREATE TABLE users (
     id            INTEGER PRIMARY KEY,
     username      TEXT NOT NULL UNIQUE COLLATE NOCASE,
     password_hash TEXT NOT NULL,
     is_admin      INTEGER NOT NULL DEFAULT 0,
     elo           INTEGER NOT NULL DEFAULT 1000,
     coins         INTEGER NOT NULL DEFAULT 0,
     created_at    INTEGER NOT NULL,
     last_login_at INTEGER
   );
   CREATE TABLE sessions (
     token_hash  TEXT PRIMARY KEY,
     user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     created_at  INTEGER NOT NULL,
     expires_at  INTEGER NOT NULL
   );
   CREATE INDEX sessions_user ON sessions(user_id);`,

  // 2: collections, decks, starter choice, free packs, pack history
  `ALTER TABLE users ADD COLUMN starter_deck TEXT;
   ALTER TABLE users ADD COLUMN free_packs INTEGER NOT NULL DEFAULT 0;
   ALTER TABLE users ADD COLUMN active_deck_id INTEGER;
   CREATE TABLE collection (
     user_id           INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     code              INTEGER NOT NULL,
     copies            INTEGER NOT NULL,
     first_obtained_at INTEGER NOT NULL,
     PRIMARY KEY (user_id, code)
   );
   CREATE TABLE decks (
     id         INTEGER PRIMARY KEY,
     user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     name       TEXT NOT NULL,
     main       TEXT NOT NULL,
     extra      TEXT NOT NULL,
     created_at INTEGER NOT NULL,
     updated_at INTEGER NOT NULL
   );
   CREATE INDEX decks_user ON decks(user_id);
   CREATE TABLE pack_openings (
     id        INTEGER PRIMARY KEY,
     user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     pack_id   TEXT NOT NULL,
     cards     TEXT NOT NULL,
     free      INTEGER NOT NULL,
     opened_at INTEGER NOT NULL
   );
   CREATE INDEX pack_openings_user ON pack_openings(user_id, opened_at);`,

  // 3: bad-luck protection (previous pack was all Commons -> next pack's last card is Rare or better)
  `ALTER TABLE users ADD COLUMN guaranteed_rare_next INTEGER NOT NULL DEFAULT 0;`,

  // 4: buying packs: duels played since the last purchase, packs bought before the lock, when the lock ends
  `ALTER TABLE users ADD COLUMN duels_since_pack INTEGER NOT NULL DEFAULT 0;
   ALTER TABLE users ADD COLUMN packs_before_lock INTEGER NOT NULL DEFAULT 0;
   ALTER TABLE users ADD COLUMN pack_lock_until INTEGER NOT NULL DEFAULT 0;`,

  // 5: ranked record for the Standings page
  `ALTER TABLE users ADD COLUMN wins INTEGER NOT NULL DEFAULT 0;
   ALTER TABLE users ADD COLUMN losses INTEGER NOT NULL DEFAULT 0;
   ALTER TABLE users ADD COLUMN draws INTEGER NOT NULL DEFAULT 0;
   CREATE INDEX users_elo ON users(elo DESC);`,

  // 6: news posts on the main page
  `CREATE TABLE news (
     id         INTEGER PRIMARY KEY,
     title      TEXT NOT NULL,
     body       TEXT NOT NULL,
     author     TEXT NOT NULL,
     created_at INTEGER NOT NULL,
     updated_at INTEGER NOT NULL
   );`,

  // 7: main menu chat (+ mutes)
  `CREATE TABLE chat_messages (
     id         INTEGER PRIMARY KEY,
     user_id    INTEGER NOT NULL,
     username   TEXT NOT NULL,
     text       TEXT NOT NULL,
     created_at INTEGER NOT NULL,
     deleted    INTEGER NOT NULL DEFAULT 0
   );
   ALTER TABLE users ADD COLUMN chat_muted_until INTEGER NOT NULL DEFAULT 0;`,

  // 8: bug reports
  `CREATE TABLE bug_reports (
     id         INTEGER PRIMARY KEY,
     user_id    INTEGER NOT NULL,
     username   TEXT NOT NULL,
     text       TEXT NOT NULL,
     context    TEXT NOT NULL,
     status     TEXT NOT NULL DEFAULT 'open',
     created_at INTEGER NOT NULL
   );
   CREATE INDEX bug_reports_status ON bug_reports(status, created_at);`,

  // 9: email sign-up. Older accounts have no email and count as verified.
  `ALTER TABLE users ADD COLUMN email TEXT;
   ALTER TABLE users ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 1;
   CREATE UNIQUE INDEX users_email ON users(email);
   CREATE TABLE email_codes (
     user_id    INTEGER NOT NULL,
     purpose    TEXT NOT NULL,
     email      TEXT NOT NULL,
     code_hash  TEXT NOT NULL,
     expires_at INTEGER NOT NULL,
     attempts   INTEGER NOT NULL DEFAULT 0,
     PRIMARY KEY (user_id, purpose)
   );`,

  // 10: bans (banned_until: 0 = not banned, a time = banned until then)
  `ALTER TABLE users ADD COLUMN banned_until INTEGER NOT NULL DEFAULT 0;
   ALTER TABLE users ADD COLUMN ban_reason TEXT;`,
];

export type Db = DatabaseSync;

export function openDatabase(file = process.env.YUGS_DB ?? path.join(ROOT, 'data', 'yugs.db')): Db {
  if (file !== ':memory:') mkdirSync(path.dirname(file), { recursive: true });
  const db = new DatabaseSync(file);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');
  db.exec('CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)');
  const row = db.prepare('SELECT version FROM schema_version').get() as { version: number } | undefined;
  let version = row?.version ?? 0;
  if (!row) db.prepare('INSERT INTO schema_version (version) VALUES (0)').run();
  while (version < MIGRATIONS.length) {
    db.exec('BEGIN');
    try {
      db.exec(MIGRATIONS[version]!);
      version++;
      db.prepare('UPDATE schema_version SET version = ?').run(version);
      db.exec('COMMIT');
    } catch (e) {
      db.exec('ROLLBACK');
      throw e;
    }
  }
  return db;
}
