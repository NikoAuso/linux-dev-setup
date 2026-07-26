#!/bin/bash

# ── mkcert (binario da GitHub, cross-distro) ─
# Il pacchetto nss-tools/libnss3-tools va installato prima dal chiamante.
# Esegui con: bash mkcert.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "mkcert (certificati HTTPS locali)"
# Versione pinnata + checksum: aggiornali insieme quando bumpi la release.
# Scarica in /tmp e verifica prima di installare come root nel PATH di sistema.
MKCERT_VER="1.4.4"
MKCERT_SHA256="6d31c65b03972c6dc4a14ab429f2928300518b26503f58723e532d1b0a3bbb52"
curl -fsSLo /tmp/mkcert "https://github.com/FiloSottile/mkcert/releases/download/v${MKCERT_VER}/mkcert-v${MKCERT_VER}-linux-amd64"
verify_sha256 /tmp/mkcert "$MKCERT_SHA256"
sudo install /tmp/mkcert /usr/local/bin/mkcert
rm -f /tmp/mkcert
mkcert -install
ok "mkcert installato — usa 'mkcert dominio.test' per generare certificati"
