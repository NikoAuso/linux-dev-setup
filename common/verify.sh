#!/bin/bash

# ── Verifica finale della toolchain (cross-distro) ─
# Controlla che i comandi principali rispondano e che i servizi siano attivi.
# I servizi da controllare si passano come argomenti (specifici per distro).
# NON usa 'set -e': un controllo fallito deve segnalare, non abortire.
# Esegui con: bash verify.sh [servizio ...]

set -o pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Verifica installazione"

# Carica gli ambienti che vivono nel .bashrc: in questa shell non interattiva
# nvm/phpenv/composer-bin non sono ancora nel PATH, altrimenti falsi negativi.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.phpenv/bin:$HOME/.config/composer/vendor/bin:$PATH"
command -v phpenv >/dev/null 2>&1 && eval "$(phpenv init - 2>/dev/null)"

FAIL=0

# check <comando> [argomenti per stampare la versione]
check() {
    local cmd="$1"; shift
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd — $("$cmd" "$@" 2>&1 | head -n1)"
    else
        info "MANCANTE: $cmd"
        FAIL=1
    fi
}

check git --version
check php --version
check composer --version
check node --version
check npm --version
check phpenv --version
check pint --version
check docker --version
check mysql --version
check psql --version
check gh --version
check mkcert -version
check code --version
check java -version

# Servizi passati dal chiamante (nomi specifici per distro)
for svc in "$@"; do
    if systemctl is-active --quiet "$svc"; then
        ok "servizio attivo: $svc"
    else
        info "servizio NON attivo: $svc"
        FAIL=1
    fi
done

if [ "$FAIL" = 0 ]; then
    ok "Tutti i controlli superati"
else
    info "Alcuni controlli non superati: rivedi le righe sopra"
fi
