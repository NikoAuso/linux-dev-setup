#!/bin/bash

# ── Organizzazione menu app GNOME (cross-distro) ─
# Esegui con: bash app-folders.sh (dentro una sessione grafica GNOME)
# Solo GNOME: Plasma e gli altri DE raggruppano già le app per categoria
# freedesktop nativamente, quindi qui vengono saltati.

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Organizzazione applicazioni del menu in cartelle per scopo"

if [ "$(detect_desktop)" != gnome ]; then
    info "Desktop non GNOME: Plasma e altri DE raggruppano già le app per categoria, organizzazione menu saltata"
elif command -v gsettings &>/dev/null && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    APPF_SCHEMA="org.gnome.desktop.app-folders"
    APPF_BASE="/org/gnome/desktop/app-folders/folders"

    gsettings set "$APPF_SCHEMA" folder-children \
        "['Sviluppo', 'Internet', 'Multimedia', 'Grafica', 'Ufficio', 'Sistema', 'Utilita']"

    set_app_folder() {
        local id="$1" name="$2" cats="$3"
        local path="${APPF_SCHEMA}.folder:${APPF_BASE}/${id}/"
        gsettings set "$path" name "$name"
        gsettings set "$path" translate false
        gsettings set "$path" categories "$cats"
    }

    set_app_folder Sviluppo   "Sviluppo"   "['Development', 'IDE']"
    set_app_folder Internet   "Internet"   "['Network', 'WebBrowser', 'Email', 'InstantMessaging']"
    set_app_folder Multimedia "Multimedia" "['AudioVideo', 'Audio', 'Video', 'Player']"
    set_app_folder Grafica    "Grafica"    "['Graphics', 'Photography']"
    set_app_folder Ufficio    "Ufficio"    "['Office']"
    set_app_folder Sistema    "Sistema"    "['System', 'Settings']"
    set_app_folder Utilita    "Utilità"    "['Utility', 'Accessories']"

    ok "Applicazioni del menu organizzate in cartelle per scopo"
else
    info "gsettings o sessione grafica GNOME non disponibili: organizzazione menu saltata"
    info "Rilancia questo blocco da un terminale in sessione GNOME per applicarla"
fi
