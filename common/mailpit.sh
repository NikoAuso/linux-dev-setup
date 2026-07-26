#!/bin/bash

# ── Mailpit + servizio systemd (cross-distro) ─
# $1 = gruppo di sistema del servizio (Ubuntu: nogroup, Fedora: nobody).
# Esegui con: bash mailpit.sh [gruppo]

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

GROUP="${1:-nobody}"

step "Mailpit (email testing locale)"
# Scarica il binario dalla release taggata invece di eseguire come root uno
# script remoto dal branch 'develop' (mutabile). Stesso approccio di lazygit.sh.
if ! command -v mailpit &>/dev/null; then
    # Versione pinnata + checksum: aggiornali insieme quando bumpi la release.
    MAILPIT_VERSION="1.30.3"
    MAILPIT_SHA256="6c7af993fb4054def4adfc7c85b40f9570fd6172eaccd0221c4969f2cc7a6294"
    curl -fsSLo /tmp/mailpit.tar.gz \
        "https://github.com/axllent/mailpit/releases/download/v${MAILPIT_VERSION}/mailpit-linux-amd64.tar.gz"
    verify_sha256 /tmp/mailpit.tar.gz "$MAILPIT_SHA256"
    tar xf /tmp/mailpit.tar.gz -C /tmp mailpit
    sudo install /tmp/mailpit /usr/local/bin
    rm -f /tmp/mailpit.tar.gz /tmp/mailpit
fi

# Crea il servizio systemd per avviarlo automaticamente
sudo tee /etc/systemd/system/mailpit.service > /dev/null << EOF
[Unit]
Description=Mailpit - Email testing tool
After=network.target

[Service]
# Vincolato a localhost: di default mailpit ascolta su tutte le interfacce
# (0.0.0.0), esponendo su LAN la UI con tutte le mail e un relay SMTP aperto.
ExecStart=/usr/local/bin/mailpit --listen 127.0.0.1:8025 --smtp 127.0.0.1:1025
Restart=always
User=nobody
Group=${GROUP}

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now mailpit
ok "Mailpit installato — UI su http://localhost:8025 | SMTP su porta 1025"
