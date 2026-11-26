// Finds and reads the Lua scripts the engine asks for (card effects + shared libraries).
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

const CARD_SCRIPT_DIRS = ['official', 'pre-release', 'pre-errata', 'unofficial', 'goat', 'rush', 'skill'];

/** Extra place to look for scripts first (our custom cards). Set once at server start. */
let customReader: ((name: string) => string | null) | null = null;
export function setCustomScriptReader(reader: (name: string) => string | null): void {
  customReader = reader;
}

/** Script files read so far, shared by every duel (they don't change while the server runs). */
const sharedCaches = new Map<string, Map<string, string | null>>();

export function createScriptReader(root: string): (name: string) => string | null {
  let cache = sharedCaches.get(root);
  if (!cache) sharedCaches.set(root, (cache = new Map()));
  return (name: string) => {
    const cached = cache.get(name);
    if (cached !== undefined) return cached;
    const custom = customReader?.(name);
    if (custom) {
      cache.set(name, custom);
      return custom;
    }
    const base = path.basename(name);
    const candidates = /^c\d+\.lua$/.test(base)
      ? CARD_SCRIPT_DIRS.map((dir) => path.join(root, dir, base))
      : [path.join(root, name), path.join(root, base)];
    let content: string | null = null;
    for (const file of candidates) {
      if (existsSync(file)) {
        content = readFileSync(file, 'utf-8');
        break;
      }
    }
    cache.set(name, content);
    return content;
  };
}
