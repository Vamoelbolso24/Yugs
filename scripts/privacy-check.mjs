// Run before publishing the code:  node scripts/privacy-check.mjs
// Looks through every file git would publish (and every older saved version) for things that must stay private.
import { execFileSync } from 'node:child_process';

const git = (...args) => execFileSync('git', args, { encoding: 'utf8', maxBuffer: 1 << 30 });
const problems = [];

// 1. Files that must never be published.
const FORBIDDEN = [/^content\/custom\/pics\//, /^data\//, /config\.local\.json$/, /\.env$/, /\.db(-wal|-shm)?$/, /\.log$/, /\.(pem|key|p12)$/];
const ever = new Set(git('log', '--all', '--name-only', '--format=').split('\n').filter(Boolean));
for (const f of new Set([...ever, ...git("ls-files").split("\n").filter(Boolean)])) {
  if (FORBIDDEN.some((re) => re.test(f))) problems.push(`Private file saved in git: ${f}`);
}

// 2. Text that looks like a secret or personal info.
const PATTERNS = [
  [/re_[A-Za-z0-9_]{16,}/, 'Resend API key'],
  [/\b(sk|pk|ghp|gho|github_pat|xox[bp])[-_][A-Za-z0-9_]{16,}/, 'API token'],
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----/, 'private key'],
  [/[A-Za-z0-9._%+-]+@(proton\.me|protonmail\.com|gmail\.com|hotmail\.com|outlook\.com|yahoo\.com|icloud\.com)/i, 'personal email address'],
  [/C:\\\\?Users\\\\?[A-Za-z]/i, 'Windows user folder path'],
  [/\b(192\.168|10\.\d{1,3})\.\d{1,3}\.\d{1,3}\b/, 'home network address'],
];
const history = git('log', '--all', '-p', '--format=@@commit %h');
let commit = '';
const seen = new Set();
for (const line of history.split('\n')) {
  if (line.startsWith('@@commit ')) { commit = line.slice(9); continue; }
  if (!line.startsWith('+') && !line.startsWith('-')) continue;
  for (const [re, what] of PATTERNS) {
    const m = line.match(re);
    if (m && !seen.has(what + m[0])) {
      seen.add(what + m[0]);
      problems.push(`${what} in commit ${commit}: ${m[0].slice(0, 12)}...`);
    }
  }
}

// 3. Huge files (usually pictures or databases that slipped in).
for (const row of git('rev-list', '--objects', '--all').split('\n')) {
  const [sha, name] = row.split(' ');
  if (!name) continue;
  const size = Number(git('cat-file', '-s', sha));
  if (size > 1_000_000) problems.push(`Big file (${(size / 1e6).toFixed(1)} MB): ${name}`);
}

if (problems.length) {
  console.log(`\nFound ${problems.length} thing(s) to fix before publishing:\n`);
  for (const p of problems) console.log('  - ' + p);
  process.exitCode = 1;
} else {
  console.log('\nAll clear: nothing private found in the files or their history.');
}
