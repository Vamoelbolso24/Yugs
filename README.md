# Yugs

A free, browser-based Yu-Gi-Oh! dueling game with a limited-collection economy.

Not affiliated with or endorsed by Konami or Shueisha. Yu-Gi-Oh! is a trademark of Shueisha and Konami.

## Setup (Windows)

1. Install Node.js (LTS) and Git.
2. Double-click `setup.bat`. It downloads the card scripts and card database from Project Ignis,
   installs the packages, and checks that the duel engine starts.

Run `setup.bat` again at any time to update the card data.

## Credits and license

- Duel engine: Project Ignis ygopro-core, via `ocgcore-wasm` (AGPL-3.0).
- Card scripts: Project Ignis CardScripts (AGPL-3.0). Card database: Project Ignis BabelCDB.
- This project is licensed under the GNU Affero General Public License v3.0 or later (see `LICENSE`).
  Source code: https://github.com/Vamoelbolso24/Yugs

## Running the public server (Ubuntu 24.04)

1. Point the domain's DNS (A records for `@` and `www`) at the server's IP address.
2. Log in as root (`ssh root@<server IP>`) and run:
   `curl -fsSL https://raw.githubusercontent.com/Vamoelbolso24/Yugs/main/server/setup.sh -o setup.sh && bash setup.sh`
   It installs Node.js 22, the game (from GitHub), the Project Ignis card data, HTTPS with Caddy, a firewall,
   a service that restarts the game if it stops, and a daily backup. It asks for the Resend key (hidden while you paste).
3. Copy the custom card pictures from your PC (they are not on GitHub), then run `yugs-restart`:
   `scp -r content\custom\pics root@<server IP>:/opt/yugs/app/content/custom/`
4. Create your account on the website, then run `yugs-admin make-admin <your username>` on the server.

Later: `yugs-update` (new version from GitHub), `yugs-log` (server messages), `yugs-admin list`.
