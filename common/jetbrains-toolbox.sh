#!/bin/bash

# ── JetBrains Toolbox (cross-distro) ─────────
# Richiede jq e curl già installati. Esegui con: bash jetbrains-toolbox.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "JetBrains Toolbox"

# ~/.local/share/JetBrains/Toolbox è la posizione che Toolbox usa per
# auto-aggiornarsi: scrive lì senza sudo e sostituisce il proprio binario.
# Installandolo sotto /opt gli update automatici fallirebbero in silenzio.
TOOLBOX_HOME="$HOME/.local/share/JetBrains/Toolbox"
TOOLBOX_DIR="$TOOLBOX_HOME/bin"

# Voce di menu e icona: il tarball le contiene in bin/ ma non le installa. Senza
# questo passo Toolbox non compare tra le applicazioni e resta di fatto invisibile.
# Exec punta al path assoluto: i launcher del menu non ereditano sempre il PATH
# di login, quindi il solo symlink in ~/.local/bin non basta.
install_menu_entry() {
    local apps="$HOME/.local/share/applications"
    local icons="$HOME/.local/share/icons/hicolor/scalable/apps"

    if [ -f "$TOOLBOX_DIR/toolbox.svg" ]; then
        install -Dm644 "$TOOLBOX_DIR/toolbox.svg" "$icons/jetbrains-toolbox.svg"
    fi

    install -d "$apps"
    cat > "$apps/jetbrains-toolbox.desktop" << EOF
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Comment=Gestore degli IDE JetBrains
Exec=$TOOLBOX_DIR/jetbrains-toolbox %u
Icon=jetbrains-toolbox
Categories=Development;IDE;
StartupWMClass=jetbrains-toolbox
StartupNotify=false
Terminal=false
EOF

    update-desktop-database "$apps" >/dev/null 2>&1 || true
    gtk-update-icon-cache -qtf "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
}

if [ -x "$TOOLBOX_DIR/jetbrains-toolbox" ]; then
    install_menu_entry
    ok "JetBrains Toolbox già installato (voce di menu aggiornata)"
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
install_menu_entry

ok "JetBrains Toolbox installato — cercalo nel menu o avvialo con 'jetbrains-toolbox'"
info "Al primo avvio installa gli IDE (PhpStorm, ecc.) e si aggiorna da solo"
