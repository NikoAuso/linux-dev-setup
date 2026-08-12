#!/bin/bash

# ── Verifica finale della toolchain (cross-distro) ─
# Controlla che i comandi principali rispondano e che i servizi siano attivi.
# I servizi da controllare si passano come argomenti (specifici per distro).
# I comandi opzionali seguono i flag WITH_* esportati da common/options.sh.
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
export PATH="$HOME/.phpenv/bin:$HOME/.local/bin:$PATH"
if command -v composer >/dev/null 2>&1; then
    COMPOSER_HOME_DIR="$(composer config --global home 2>/dev/null)"
    [ -n "$COMPOSER_HOME_DIR" ] && export PATH="$COMPOSER_HOME_DIR/vendor/bin:$PATH"
fi
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

# check_if <flag> <comando> [argomenti] — salta se il flag è a 0
check_if() {
    local flag="$1"; shift
    [ "$flag" = 1 ] && check "$@"
}

# ── Sempre presenti ───────────────────────────
check git --version
check php --version
check composer --version
check phpstan --version
check jq --version
check delta --version
check gh --version
check mkcert -version
check direnv --version
check shellcheck --version
check lazygit --version

# ── Opzionali (seguono i flag WITH_*) ─────────
check_if "${WITH_TERMINAL:-1}"  starship --version
check_if "${WITH_TERMINAL:-1}"  tmux -V
check_if "${WITH_PHPENV:-1}"    phpenv --version
check_if "${WITH_LARAVEL:-1}"   pint --version
check_if "${WITH_LARAVEL:-1}"   laravel --version
check_if "${WITH_NODE:-1}"      node --version
check_if "${WITH_NODE:-1}"      npm --version
check_if "${WITH_PYTHON:-1}"    python3 --version
check_if "${WITH_JAVA:-1}"      java -version
check_if "${WITH_MYSQL:-1}"     mysql --version
check_if "${WITH_POSTGRES:-1}"  psql --version
check_if "${WITH_REDIS:-1}"     redis-cli --version
check_if "${WITH_DOCKER:-1}"    docker --version
check_if "${WITH_MAILPIT:-1}"   mailpit version
check_if "${WITH_VSCODE:-1}"    code --version
check_if "${WITH_ACT:-1}"       act --version

# Toolbox non si interroga da CLI (aprirebbe la GUI): si verifica il binario
if [ "${WITH_JETBRAINS:-1}" = 1 ]; then
    if [ -x "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" ]; then
        ok "jetbrains-toolbox — installato"
    else
        info "MANCANTE: jetbrains-toolbox"
        FAIL=1
    fi
fi

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
