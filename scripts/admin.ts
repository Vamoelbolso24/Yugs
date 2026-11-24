// Admin commands for the account database. Run in PowerShell inside the Yugs folder:
//   node scripts/admin.ts list
//   node scripts/admin.ts reset-password <username> <new password>
//   node scripts/admin.ts make-admin <username>
import { openDatabase } from '../src/db/database.ts';
import { Accounts } from '../src/auth/accounts.ts';

const [command, username, password] = process.argv.slice(2);
const accounts = new Accounts(openDatabase());

switch (command) {
  case 'list':
    for (const u of accounts.listUsers()) console.log(`${u.id}\t${u.username}${u.isAdmin ? ' (admin)' : ''}\tELO ${u.elo}\tcoins ${u.coins}`);
    break;
  case 'reset-password': {
    if (!username || !password) throw new Error('Usage: node scripts/admin.ts reset-password <username> <new password>');
    const r = await accounts.resetPassword(username, password);
    console.log(r.ok ? `Password for ${r.value.username} changed. They have been logged out everywhere.` : r.error);
    break;
  }
  case 'make-admin':
    if (!username) throw new Error('Usage: node scripts/admin.ts make-admin <username>');
    console.log(accounts.setAdmin(username, true) ? `${username} is now an admin.` : `No user called ${username}.`);
    break;
  default:
    console.log('Commands: list | reset-password <username> <new password> | make-admin <username>');
}
