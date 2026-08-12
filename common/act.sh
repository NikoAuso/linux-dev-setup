#!/bin/bash

# ── act — GitHub Actions in locale (cross-distro) ─
# Esegui con: bash act.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

if command -v act &>/dev/null; then
    ok "act già installato"
    exit 0
fi

# Versione pinnata + checksum: aggiornali insieme quando bumpi la release.
ACT_VERSION="0.2.89"
ACT_SHA256="0191d6f1f3b716b5c55820032605d05fc3c1cdbf581ebeff655019e5dd1524c0"
curl -fsSLo /tmp/act.tar.gz "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/act_Linux_x86_64.tar.gz"
verify_sha256 /tmp/act.tar.gz "$ACT_SHA256"
tar xf /tmp/act.tar.gz -C /tmp act
sudo install /tmp/act /usr/local/bin
rm -f /tmp/act.tar.gz /tmp/act
ok "act installato — richiede Docker; lancia le workflow con 'act -l' / 'act push'"
