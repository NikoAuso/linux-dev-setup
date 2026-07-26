#!/bin/bash

# ── JAVA_HOME nel .bashrc (cross-distro) ─────
# L'installazione del JDK è specifica per distro e va fatta prima dal chiamante.
# Esegui con: bash java-home.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

if ! grep -q "JAVA_HOME" "$HOME/.bashrc"; then
    echo 'export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))' >> "$HOME/.bashrc"
    echo 'export PATH=$JAVA_HOME/bin:$PATH' >> "$HOME/.bashrc"
fi
ok "JAVA_HOME configurato nel .bashrc"
