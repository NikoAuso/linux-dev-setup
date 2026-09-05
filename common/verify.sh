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

# present <etichetta> <comando di test...> — verifica la presenza senza eseguire
# l'applicazione: una GUI invocata con --version si aprirebbe davvero.
present() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        ok "$label — installato"
    else
        info "MANCANTE: $label"
        FAIL=1
    fi
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
# Il client può essere 'mysql' o 'mariadb' (MariaDB recente non installa il symlink)
if [ "${WITH_MYSQL:-1}" = 1 ]; then
    if command -v mysql >/dev/null 2>&1; then check mysql --version; else check mariadb --version; fi
fi
check_if "${WITH_POSTGRES:-1}"  psql --version
check_if "${WITH_REDIS:-1}"     redis-cli --version
check_if "${WITH_DOCKER:-1}"    docker --version
check_if "${WITH_MAILPIT:-1}"   mailpit version
check_if "${WITH_VSCODE:-1}"    code --version
check_if "${WITH_ACT:-1}"       act --version

# App del blocco desktop: senza questi controlli un fallimento lì passava
# inosservato e lo script chiudeva comunque con "Setup completato".
if [ "${WITH_DESKTOP:-1}" = 1 ]; then
    present "google-chrome"   command -v google-chrome
    present "vlc"             command -v vlc
    present "megasync"        command -v megasync
    # Su Fedora è un modulo Python esposto come sottocomando git, non un binario
    present "git-filter-repo" sh -c 'command -v git-filter-repo || git filter-repo --version'
    # Il pacchetto Fedora installa /usr/bin/Telegram; il fallback è il Flatpak
    present "telegram"        sh -c 'command -v Telegram || command -v telegram-desktop || flatpak info org.telegram.desktop'
    present "postman"         sh -c 'flatpak info com.getpostman.Postman || command -v postman'
    if [ "$(detect_desktop)" = gnome ]; then
        present "gpaste"      command -v gpaste-client
    fi
fi

# Docker Desktop gira come user service e non ha un 'docker-desktop --version'
# comodo: si verifica il binario installato.
if [ "${WITH_DOCKERDESKTOP:-0}" = 1 ]; then
    if [ -x /opt/docker-desktop/bin/docker-desktop ]; then
        ok "docker-desktop — installato"
    else
        info "MANCANTE: docker-desktop"
        FAIL=1
    fi
fi

# Toolbox non si interroga da CLI (aprirebbe la GUI): si verifica il binario.
# La voce di menu è a parte: il tarball la contiene ma non la installa, e senza
# quella Toolbox risulta invisibile tra le applicazioni.
if [ "${WITH_JETBRAINS:-1}" = 1 ]; then
    present "jetbrains-toolbox" test -x "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
    present "jetbrains-toolbox (voce di menu)" test -f "$HOME/.local/share/applications/jetbrains-toolbox.desktop"
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
