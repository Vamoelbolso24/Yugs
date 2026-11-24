// Central place for folder locations, so nothing else hardcodes paths.
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const CARD_SCRIPTS_DIR = path.join(ROOT, 'vendor', 'CardScripts');
export const CARD_DB_FILES = [path.join(ROOT, 'vendor', 'BabelCDB', 'cards.cdb')];
