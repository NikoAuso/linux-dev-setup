#!/bin/bash

# ── Alias tool moderni nel .bashrc (cross-distro) ─
# Esegui con: bash cli-aliases.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

if ! grep -q "Alias tool moderni" "$HOME/.bashrc"; then
cat >> "$HOME/.bashrc" << 'EOF'

# ── Alias tool moderni ───────────────────────
alias cat='bat --paging=never'
alias ls='eza --icons'
alias ll='eza -lah --icons --git'
alias lt='eza --tree --icons --level=2'
alias ff='fd'
alias rgs='rg'
alias lg='lazygit'
EOF
fi
ok "Alias tool moderni aggiunti"
