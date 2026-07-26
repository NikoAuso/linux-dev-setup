#!/bin/bash

# ── Configurazione Git globale (cross-distro) ─
# Esegui con: bash git-config.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Configurazione Git globale"
# Personalizza con i tuoi dati prima di lanciare lo script
git config --global user.name "Il Tuo Nome"
git config --global user.email "tua@email.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.syntax-theme "Dracula"
git config --global pull.rebase false
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.st "status -sb"
git config --global alias.undo "reset HEAD~1 --mixed"
ok "Git configurato con delta e alias utili"
