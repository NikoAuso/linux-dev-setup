#!/bin/bash

# ── lazygit (binario da GitHub, cross-distro) ─
# Esegui con: bash lazygit.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

if command -v lazygit &>/dev/null; then
    ok "lazygit già installato"
    exit 0
fi

# Versione pinnata + checksum: aggiornali insieme quando bumpi la release.
LAZYGIT_VERSION="0.62.2"
LAZYGIT_SHA256="8b9a4c2d0969cbea92b45c956dd2a44e1ba76900c9df49f1c60984045ce77984"
curl -fsSLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_x86_64.tar.gz"
verify_sha256 /tmp/lazygit.tar.gz "$LAZYGIT_SHA256"
tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo install /tmp/lazygit /usr/local/bin
rm -f /tmp/lazygit.tar.gz /tmp/lazygit
ok "lazygit installato"
