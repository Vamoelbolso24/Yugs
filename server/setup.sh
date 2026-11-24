#!/usr/bin/env bash
# Yugs: Playground Dueling - one-time setup of a fresh Ubuntu 24.04 server.
# Run as root:
#   curl -fsSL https://raw.githubusercontent.com/Vamoelbolso24/Yugs/main/server/setup.sh -o setup.sh && bash setup.sh
# Safe to run again: it skips what is already done.
set -euo pipefail

DOMAIN="playgrounddueling.com"
REPO="https://github.com/Vamoelbolso24/Yugs.git"
HOME_DIR="/opt/yugs"
APP="$HOME_DIR/app"

step() { printf '\n\033[1;36m== %s\033[0m\n' "$1"; }
[ "$(id -u)" -eq 0 ] || { echo "Run this as root."; exit 1; }
export DEBIAN_FRONTEND=noninteractive

step "Spare memory on disk (swap, 1 GB)"
if ! swapon --show | grep -q .; then
  fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "Swap on."
else
  echo "Swap already on."
fi

step "System updates and tools"
apt-get update -q
apt-get upgrade -yq
apt-get install -yq git curl ca-certificates sqlite3 ufw unattended-upgrades caddy
# Security updates install themselves every day.
dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true

step "Node.js 22"
if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 22 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -yq nodejs
fi
node -v

step "Firewall: only SSH, HTTP and HTTPS"
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null
ufw status | head -8

step "Yugs user and code"
id yugs >/dev/null 2>&1 || useradd --system --home-dir "$HOME_DIR" --create-home --shell /usr/sbin/nologin yugs
if [ -d "$APP/.git" ]; then
  sudo -u yugs git -C "$APP" pull --ff-only
else
  sudo -u yugs git clone "$REPO" "$APP"
fi
cd "$APP"

step "Card scripts and card database (Project Ignis)"
for name in CardScripts BabelCDB; do
  if [ -d "vendor/$name/.git" ]; then
    sudo -u yugs git -C "vendor/$name" pull --ff-only
  else
    sudo -u yugs git clone --depth 1 "https://github.com/ProjectIgnis/$name.git" "vendor/$name"
  fi
done

step "Packages"
sudo -u yugs npm ci --omit=dev --no-audit --no-fund
sudo -u yugs mkdir -p data content/custom/pics "$HOME_DIR/backups"

step "Email key (Resend)"
if [ -f config.local.json ] && grep -q '"re_' config.local.json; then
  echo "Already set. (To change it: nano $APP/config.local.json, then: systemctl restart yugs)"
else
  echo "Paste your Resend API key (starts with re_) and press Enter."
  echo "Nothing shows while you paste; that is normal. Just press Enter to skip for now."
  read -rs RESEND_KEY </dev/tty || RESEND_KEY=""
  echo
  RESEND_KEY="$RESEND_KEY" node -e 'process.stdout.write(JSON.stringify({ resendApiKey: (process.env.RESEND_KEY || "").trim(), emailFrom: "Yugs <no-reply@playgrounddueling.com>" }, null, 2) + "\n")' > config.local.json
  chown yugs:yugs config.local.json
  chmod 600 config.local.json
  [ -n "$RESEND_KEY" ] && echo "Key saved." || echo "Skipped: emails will not be sent until you add the key."
  unset RESEND_KEY
fi

step "Run Yugs as a service (starts on boot, restarts if it crashes)"
cat > /etc/systemd/system/yugs.service <<UNIT
[Unit]
Description=Yugs: Playground Dueling
After=network.target

[Service]
User=yugs
WorkingDirectory=$APP
Environment=PORT=3000
Environment=HOST=127.0.0.1
ExecStart=/usr/bin/node src/server/server.ts
Restart=always
RestartSec=3
MemoryMax=700M

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now yugs
systemctl restart yugs

step "HTTPS (Caddy gets a free certificate by itself)"
cat > /etc/caddy/Caddyfile <<CADDY
$DOMAIN {
	encode gzip
	reverse_proxy 127.0.0.1:3000 {
		flush_interval -1
	}
}

www.$DOMAIN {
	redir https://$DOMAIN{uri} permanent
}
CADDY
systemctl enable caddy >/dev/null 2>&1
systemctl reload caddy || systemctl restart caddy

step "Daily backup (04:17 server time, last 14 days kept in $HOME_DIR/backups)"
cat > /etc/cron.d/yugs-backup <<CRON
17 4 * * * yugs /bin/bash $APP/server/backup.sh
CRON

step "Shortcuts"
cat > /usr/local/bin/yugs-update <<'SH'
#!/usr/bin/env bash
exec /bin/bash /opt/yugs/app/server/update.sh "$@"
SH
cat > /usr/local/bin/yugs-restart <<'SH'
#!/usr/bin/env bash
# Restart the game (also fixes file owners after copying pictures in).
chown -R yugs:yugs /opt/yugs/app/content
systemctl restart yugs
sleep 3
systemctl --no-pager --lines=5 status yugs | head -8 || true
SH
cat > /usr/local/bin/yugs-admin <<'SH'
#!/usr/bin/env bash
# yugs-admin list | make-admin <username> | reset-password <username> <new password>
cd /opt/yugs/app && exec sudo -u yugs node scripts/admin.ts "$@"
SH
cat > /usr/local/bin/yugs-log <<'SH'
#!/usr/bin/env bash
exec journalctl -u yugs -n 100 -f
SH
chmod +x /usr/local/bin/yugs-update /usr/local/bin/yugs-admin /usr/local/bin/yugs-log /usr/local/bin/yugs-restart

sleep 3
step "Done"
systemctl --no-pager --lines=0 status yugs | head -3 || true
cat <<MSG

Yugs is installed. Next:
  1. Copy the custom card pictures from your PC (see the instructions Claude gave you).
  2. Open https://$DOMAIN once the domain points here, and create your account.
  3. Make yourself admin:   yugs-admin make-admin YOUR_USERNAME

Useful commands on this server:
  yugs-update      get the newest version from GitHub and restart
  yugs-restart     restart the game (run it after copying pictures in)
  yugs-log         watch what the game server prints (Ctrl+C to stop watching)
  yugs-admin list  list accounts
MSG
