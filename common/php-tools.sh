#!/bin/bash

# ── Tool PHP globali (cross-distro) ──────────
# Richiede composer già installato. Esegui con: bash php-tools.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Tool PHP globali (php-cs-fixer, PHPStan, Pint, Infection)"

composer global require \
    friendsofphp/php-cs-fixer phpstan/phpstan laravel/pint \
    infection/infection phpunit/phpunit

if ! grep -q "composer/vendor/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> "$HOME/.bashrc"
fi
ok "php-cs-fixer, PHPStan, Pint, Infection, PHPUnit installati globalmente"
