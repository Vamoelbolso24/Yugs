// The deck editor's filters (public/cardFilter.js) also run on the server, for admins searching every card.
// The same file is used so the browser and the server always agree.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { ROOT } from '../paths.ts';
import type { CardText } from '../game/types.ts';

export interface CardFilterApi {
  matches(card: CardText, filter: Record<string, unknown>): boolean;
  isActive(filter: Record<string, unknown>): boolean;
}

new Function(readFileSync(path.join(ROOT, 'public', 'cardFilter.js'), 'utf-8'))();
export const CardFilter = (globalThis as unknown as { CardFilter: CardFilterApi }).CardFilter;
