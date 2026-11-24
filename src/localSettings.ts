// Private settings that must never be committed (API keys). They live in config.local.json
// next to package.json; git ignores that file. Copy config.local.example.json to start.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { ROOT } from './paths.ts';

export interface LocalSettings {
  /** Resend API key (starts with re_). Empty = no emails are sent; codes are printed in the server window. */
  resendApiKey: string;
  /** Who the emails come from. The domain must be verified in Resend. */
  emailFrom: string;
}

export function loadLocalSettings(): LocalSettings {
  const defaults: LocalSettings = { resendApiKey: '', emailFrom: 'Yugs <no-reply@playgrounddueling.com>' };
  try {
    const raw = JSON.parse(readFileSync(path.join(ROOT, 'config.local.json'), 'utf8')) as Partial<LocalSettings>;
    return {
      resendApiKey: typeof raw.resendApiKey === 'string' ? raw.resendApiKey.trim() : '',
      emailFrom: typeof raw.emailFrom === 'string' && raw.emailFrom.trim() ? raw.emailFrom.trim() : defaults.emailFrom,
    };
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== 'ENOENT') console.error('config.local.json could not be read:', (e as Error).message);
    return defaults;
  }
}
