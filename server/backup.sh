#!/usr/bin/env bash
# Daily backup: the database (accounts, collections, decks, news, chat) and the content folder
# (packs, shop, banlist, custom cards and pictures). Keeps the last 14 days.
set -euo pipefail
APP=/opt/yugs/app
OUT=/opt/yugs/backups
DAY=$(date +%F)
mkdir -p "$OUT"
if [ -f "$APP/data/yugs.db" ]; then
  sqlite3 "$APP/data/yugs.db" ".backup '$OUT/yugs-$DAY.db'"
fi
tar -czf "$OUT/content-$DAY.tgz" -C "$APP" content $( [ -f "$APP/data/site-status.json" ] && echo data/site-status.json )
find "$OUT" -name 'yugs-*.db' -mtime +14 -delete
find "$OUT" -name 'content-*.tgz' -mtime +14 -delete
