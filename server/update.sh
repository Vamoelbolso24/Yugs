#!/usr/bin/env bash
# Get the newest Yugs from GitHub and restart. Run as root:  yugs-update
# Tip: turn on Maintenance mode in the game a few minutes before, and off after.
set -euo pipefail
APP=/opt/yugs/app
cd "$APP"
# Files copied in as root (pictures, logo) must belong to the game's own account.
chown -R yugs:yugs "$APP/content"
chmod -R u+rwX,go+rX "$APP/content"
echo "== Backup first"
sudo -u yugs /bin/bash "$APP/server/backup.sh"
G="sudo -u yugs git -c user.name=Yugs-server -c user.email=server@localhost"
echo "== Keeping changes made on the live site (Pack Maker, shop, banlist...)"
$G add -A content
$G commit -q -m "Changes made on the live site" || echo "(none)"
echo "== Downloading the new version"
$G fetch -q origin
if ! $G merge --no-edit -q origin/main; then
  $G merge --abort || true
  echo
  echo "STOPPED: a file changed both on the live site and in the new version."
  echo "Nothing was lost and the game keeps running the old version. Send Claude this list:"
  $G diff --name-only HEAD...origin/main -- content
  exit 1
fi
echo "== Card data"
for name in CardScripts BabelCDB; do sudo -u yugs git -C "vendor/$name" pull --ff-only || true; done
echo "== Packages"
sudo -u yugs npm ci --omit=dev --no-audit --no-fund
echo "== HTTPS settings"
if ! cmp -s "$APP/server/Caddyfile" /etc/caddy/Caddyfile; then
  cp "$APP/server/Caddyfile" /etc/caddy/Caddyfile
  systemctl reload caddy && echo "Caddy settings updated."
else
  echo "(unchanged)"
fi
echo "== Restarting"
systemctl restart yugs
sleep 3
systemctl --no-pager --lines=5 status yugs | head -8 || true
echo "Updated."
