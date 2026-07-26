#!/bin/bash

# ── Alias sviluppo nel .bashrc (cross-distro) ─
# Esegui con: bash dev-aliases.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Alias sviluppo nel .bashrc"
if ! grep -q "Alias sviluppo" "$HOME/.bashrc"; then
cat >> "$HOME/.bashrc" << 'EOF'

# ── Alias sviluppo ───────────────────────────
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git lg'
alias art='php artisan'
alias sail='./vendor/bin/sail'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias phpcs='php-cs-fixer fix'
alias stan='phpstan analyse'
alias pint='./vendor/bin/pint'
alias pest='./vendor/bin/pest'
alias pu='./vendor/bin/phpunit'
EOF
fi
ok "Alias aggiunti"
