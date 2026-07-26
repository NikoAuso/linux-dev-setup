#!/bin/bash

# ── phpenv + php-build (cross-distro) ────────
# Le dipendenze di compilazione (pacchetti -dev/-devel) vanno installate prima
# dal chiamante, sono specifiche per distro. Esegui con: bash phpenv.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "phpenv + php-build"

if [ ! -d "$HOME/.phpenv" ]; then
    git clone https://github.com/phpenv/phpenv.git "$HOME/.phpenv"
fi

if [ ! -d "$HOME/.phpenv/plugins/php-build" ]; then
    git clone https://github.com/php-build/php-build.git "$HOME/.phpenv/plugins/php-build"
fi

if ! grep -q "PHPENV_ROOT" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" << 'EOF'

export PHPENV_ROOT="$HOME/.phpenv"
export PATH="$PHPENV_ROOT/bin:$PATH"
eval "$(phpenv init -)"
EOF
fi
ok "phpenv installato"
info "Usa 'phpenv install 8.2.0' per installare altre versioni PHP"
info "Usa 'phpenv global 8.2.0' o 'phpenv local 8.2.0' per cambiare versione"
