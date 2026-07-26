#!/bin/bash

# ── Estensioni VS Code (cross-distro) ────────
# Richiede il comando 'code' già installato. Esegui con: bash vscode-extensions.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Estensioni VS Code"

EXTENSIONS=(
    "bmewburn.vscode-intelephense-client"
    "xdebug.php-debug"
    "junstyle.php-cs-fixer"
    "SanderRonde.phpstan-vscode"
    "onecentlin.phpunit-snippets"
    "amiralizadeh9480.laravel-extra-intellisense"
    "ryannaddy.laravel-artisan"
    "eamodio.gitlens"
    "mhutchie.git-graph"
    "ms-azuretools.vscode-docker"
    "ms-vscode-remote.remote-containers"
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "bradlc.vscode-tailwindcss"
    "ms-python.python"
    "redhat.java"
    "usernamehw.errorlens"
    "streetsidesoftware.code-spell-checker"
    "editorconfig.editorconfig"
    "pkief.material-icon-theme"
    "zhuangtongfa.material-theme"
)

for EXT in "${EXTENSIONS[@]}"; do
    code --install-extension "$EXT" --force 2>/dev/null || true
done
ok "Estensioni VS Code installate"
