#!/bin/bash

# ── Tool PHP globali (cross-distro) ──────────
# Richiede composer già installato. Esegui con: bash php-tools.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Tool PHP globali (php-cs-fixer, PHPStan, Infection, PHPUnit)"

PACKAGES=(
    friendsofphp/php-cs-fixer
    phpstan/phpstan
    infection/infection
    phpunit/phpunit
)

# Pint e l'installer sono specifici di Laravel: si aggiungono solo se richiesto
if [ "${WITH_LARAVEL:-1}" = 1 ]; then
    PACKAGES+=(laravel/pint laravel/installer)
fi

composer global require "${PACKAGES[@]}"

# La home di Composer non è sempre ~/.config/composer (COMPOSER_HOME o un
# ~/.composer preesistente la spostano): la si chiede a composer stesso.
COMPOSER_BIN="$(composer config --global home)/vendor/bin"
if ! grep -q "$COMPOSER_BIN" "$HOME/.bashrc"; then
    echo "export PATH=\"$COMPOSER_BIN:\$PATH\"" >> "$HOME/.bashrc"
fi
ok "Tool PHP globali installati in $COMPOSER_BIN"
