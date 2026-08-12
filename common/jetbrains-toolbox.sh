#!/bin/bash

# ── JetBrains Toolbox (cross-distro) ─────────
# Richiede jq e curl già installati. Esegui con: bash jetbrains-toolbox.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "JetBrains Toolbox"

TOOLBOX_DIR="$HOME/.local/share/JetBrains/Toolbox/bin"
if [ -x "$TOOLBOX_DIR/jetbrains-toolbox" ]; then
    ok "JetBrains Toolbox già installato"
    exit 0
fi

# 'release' oppure 'eap' per la early access
RELEASE_TYPE="${1:-release}"

RELEASE_JSON="$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=${RELEASE_TYPE}")"
TOOLBOX_URL="$(echo "$RELEASE_JSON" | jq -r '.TBA[0].downloads.linux.link')"
CHECKSUM_URL="$(echo "$RELEASE_JSON" | jq -r '.TBA[0].downloads.linux.checksumLink')"

if [ -z "$TOOLBOX_URL" ] || [ "$TOOLBOX_URL" = "null" ]; then
    info "API JetBrains non ha restituito un link di download: passo saltato"
    exit 0
fi

# La versione non è pinnata (l'API restituisce sempre l'ultima), quindi lo
# sha256 atteso arriva dal file .sha256 pubblicato accanto al tarball.
EXPECTED_SHA256="$(curl -fsSL "$CHECKSUM_URL" | awk '{print $1}')"

curl -fsSLo /tmp/jetbrains-toolbox.tar.gz "$TOOLBOX_URL"
verify_sha256 /tmp/jetbrains-toolbox.tar.gz "$EXPECTED_SHA256"

install -d "$TOOLBOX_DIR" "$HOME/.local/bin"
tar xzf /tmp/jetbrains-toolbox.tar.gz --directory="$TOOLBOX_DIR" --strip-components=2
rm -f /tmp/jetbrains-toolbox.tar.gz

ln -sf "$TOOLBOX_DIR/jetbrains-toolbox" "$HOME/.local/bin/jetbrains-toolbox"

ok "JetBrains Toolbox installato — avvialo con 'jetbrains-toolbox'"
info "Al primo avvio crea la voce nel menu e installa gli IDE (PhpStorm, ecc.)"
