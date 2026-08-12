#!/bin/bash

# ── Configurazione Git globale (cross-distro) ─
# Esegui con: bash git-config.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Configurazione Git globale"

# L'identità si imposta solo se non c'è già: un rilancio dello script su una
# macchina configurata non deve sovrascrivere nome ed email reali.
# Passala da fuori:  GIT_USER_NAME="Mario Rossi" GIT_USER_EMAIL=m@r.it bash …
if ! git config --global --get user.name >/dev/null; then
    git config --global user.name "${GIT_USER_NAME:-Il Tuo Nome}"
fi
if ! git config --global --get user.email >/dev/null; then
    git config --global user.email "${GIT_USER_EMAIL:-tua@email.com}"
fi
info "Identità git: $(git config --global user.name) <$(git config --global user.email)>"

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
