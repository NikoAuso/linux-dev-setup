#!/bin/bash

# ─────────────────────────────────────────────
#  HELPER CONDIVISI — output colorato + utilità
#  Va sourcato dagli altri script, non eseguito da solo.
# ─────────────────────────────────────────────

# Usati dai file che sorgono questa lib (shellcheck non lo vede analizzandola sola)
# shellcheck disable=SC2034
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
CYAN='\033[0;36m'
# shellcheck disable=SC2034
NC='\033[0m'

step() { echo -e "\n${CYAN}──────────────────────────────${NC}"; echo -e "${YELLOW}  $1${NC}"; echo -e "${CYAN}──────────────────────────────${NC}"; }
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
info() { echo -e "  ${YELLOW}→${NC} $1"; }

backup_if_exists() {
    if [ -f "$1" ]; then
        cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"
        info "Backup di $(basename "$1") salvato"
    fi
}

backup_bashrc() { backup_if_exists "$HOME/.bashrc"; }

# Chiede la password sudo una volta e la tiene viva finché lo script gira,
# così i download lunghi non fanno scadere il timestamp e ricomparire il prompt
# a metà esecuzione. Va chiamata dai soli script principali (non dalle parti).
keep_sudo_alive() {
    sudo -v
    while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done &
}

# Verifica lo sha256 di un file: interrompe (ed elimina il file) se non combacia
# con l'hash atteso. Usato per i binari scaricati da release pinnate.
verify_sha256() {
    local file="$1" expected="$2" actual
    actual="$(sha256sum "$file" | awk '{print $1}')"
    if [ "$actual" != "$expected" ]; then
        echo "ERRORE: checksum sha256 non valido per $(basename "$file")" >&2
        echo "  atteso:  $expected" >&2
        echo "  trovato: $actual" >&2
        rm -f "$file"
        exit 1
    fi
}
