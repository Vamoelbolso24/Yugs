#!/usr/bin/env bash
# Get the newest Yugs from GitHub and restart. Run as root:  yugs-update
# Tip: turn on Maintenance mode in the game a few minutes before, and off after.
set -euo pipefail
APP=/opt/yugs/app
cd "$APP"
echo "== Backup first"
sudo -u yugs /bin/bash "$APP/server/backup.sh"
echo "== Downloading the new version"
if ! sudo -u yugs git pull --ff-only; then
  echo
  echo "STOPPED: files on the server were changed (for example packs made with the Pack Maker here)"
  echo "and they clash with the new version. Nothing was lost. Send Claude this list:"
  sudo -u yugs git status --short
  exit 1
fi
echo "== Card data"
for name in CardScripts BabelCDB; do sudo -u yugs git -C "vendor/$name" pull --ff-only || true; done
echo "== Packages"
sudo -u yugs npm ci --omit=dev --no-audit --no-fund
echo "== Restarting"
systemctl restart yugs
sleep 3
systemctl --no-pager --lines=5 status yugs | head -8 || true
echo "Updated."
