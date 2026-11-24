// Checks that everything needed for the duel engine is in place.
import { readdirSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
let ok = true;
const pass = (m) => console.log('  OK    ' + m);
const fail = (m) => { console.log('  FAIL  ' + m); ok = false; };

const major = Number(process.versions.node.split('.')[0]);
if (major >= 22) pass(`Node.js ${process.versions.node}`);
else fail(`Node.js ${process.versions.node} is too old - install the LTS version`);

const official = path.join(root, 'vendor', 'CardScripts', 'official');
if (existsSync(official)) {
  const n = readdirSync(official).filter((f) => /^c\d+\.lua$/.test(f)).length;
  n > 1000 ? pass(`${n} card scripts found`) : fail(`only ${n} card scripts found`);
} else fail('vendor/CardScripts/official is missing');

const babel = path.join(root, 'vendor', 'BabelCDB');
if (existsSync(babel)) {
  const cdbs = readdirSync(babel).filter((f) => f.endsWith('.cdb'));
  cdbs.length
    ? pass(`${cdbs.length} card databases found (${cdbs.slice(0, 3).join(', ')}${cdbs.length > 3 ? ', ...' : ''})`)
    : fail('no .cdb files in vendor/BabelCDB');
} else fail('vendor/BabelCDB is missing');

try {
  const mod = await import('ocgcore-wasm');
  pass('ocgcore-wasm package loaded');
  const createCore = mod.default;
  if (typeof createCore !== 'function') {
    throw new Error('engine start function not found; exports: ' + Object.keys(mod).join(', '));
  }
  const lib = await createCore({ sync: true });
  const v = typeof lib.getVersion === 'function' ? lib.getVersion() : null;
  pass('duel engine started' + (v ? ` (core version ${JSON.stringify(v)})` : ''));
} catch (e) {
  fail('duel engine did not start: ' + (e?.message ?? e));
}

try {
  await import('node:sqlite');
  pass('built-in SQLite available (for reading the card database)');
} catch {
  console.log('  NOTE  built-in SQLite not available - we will use a package instead');
}

console.log(ok ? '\nSetup check passed.' : '\nSetup check found problems.');
process.exit(ok ? 0 : 1);
