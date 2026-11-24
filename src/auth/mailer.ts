// Sends emails through Resend (https://resend.com). Without an API key it prints them in the server window instead.
import type { LocalSettings } from '../localSettings.ts';

export interface Mail {
  to: string;
  subject: string;
  text: string;
}

export type SendMail = (mail: Mail) => Promise<boolean>;

const escapeHtml = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);

export function createMailer(settings: LocalSettings): SendMail {
  if (!settings.resendApiKey) {
    console.log('No Resend key in config.local.json: emails will be printed here instead of sent.');
    return async (mail) => {
      console.log(`\n[email to ${mail.to}] ${mail.subject}\n${mail.text}\n`);
      return true;
    };
  }
  return async (mail) => {
    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${settings.resendApiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: settings.emailFrom,
          to: [mail.to],
          subject: mail.subject,
          text: mail.text,
          html: `<div style="font-family:sans-serif;font-size:15px;line-height:1.5">${escapeHtml(mail.text).replace(/\n/g, '<br>')}</div>`,
        }),
      });
      if (!res.ok) {
        console.error(`Email to ${mail.to} failed: ${res.status} ${await res.text()}`);
        return false;
      }
      return true;
    } catch (e) {
      console.error(`Email to ${mail.to} failed:`, (e as Error).message);
      return false;
    }
  };
}
