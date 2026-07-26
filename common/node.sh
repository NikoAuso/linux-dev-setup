#!/bin/bash

# ── Node.js LTS via nvm (cross-distro) ───────
# Esegui con: bash node.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Node.js LTS (via nvm)"
curl -fsSL -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# nvm non è compatibile con set -e/-u: disattivati solo per questo blocco
set +eu
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts
nvm alias default node

# corepack — gestore per pnpm e yarn (|| true: fallisce se gli shim esistono già)
corepack enable || true
set -eu

if ! grep -q "NVM_DIR" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" << 'EOF'

# nvm (lazy: la prima chiamata a node/npm/npx/nvm lo inizializza)
export NVM_DIR="$HOME/.nvm"
_load_nvm() {
  unset -f nvm node npm npx _load_nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _load_nvm; nvm "$@"; }
node() { _load_nvm; node "$@"; }
npm()  { _load_nvm; npm "$@"; }
npx()  { _load_nvm; npx "$@"; }
EOF
fi
ok "Node.js LTS installato via nvm"
