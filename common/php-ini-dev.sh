#!/bin/bash

# ── php.ini di sviluppo + Xdebug (cross-distro) ─
# Richiede php e php-xdebug già installati. Esegui con: bash php-ini-dev.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

step "Configurazione PHP per lo sviluppo (Xdebug, limiti, errori)"

# Dove finiscono gli .ini aggiuntivi: Fedora ha una sola /etc/php.d condivisa da
# tutti i SAPI, Ubuntu una conf.d per SAPI (cli, fpm, apache2).
SCAN_DIR="$(php -r 'echo PHP_CONFIG_FILE_SCAN_DIR;')"
case "$SCAN_DIR" in
    "")           info "PHP non espone una scan dir per gli .ini: passo saltato"; exit 0 ;;
    */cli/conf.d) PHP_ETC="$(dirname "$(dirname "$SCAN_DIR")")"; CONF_DIRS=("$PHP_ETC"/*/conf.d) ;;
    *)            CONF_DIRS=("$SCAN_DIR") ;;
esac

for dir in "${CONF_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    sudo tee "$dir/99-dev.ini" > /dev/null << 'EOF'
; Generato da linux-dev-setup — impostazioni per lo sviluppo locale.
; NON usare questi valori in produzione.

; start_with_request=trigger: Xdebug si attiva solo quando la richiesta porta
; XDEBUG_TRIGGER (lo mandano l'estensione del browser e "Listen for Xdebug" di
; VS Code). Con 'yes' ogni singola richiesta CLI e web rallenterebbe.
xdebug.mode = debug,develop,coverage
xdebug.start_with_request = trigger
xdebug.client_host = 127.0.0.1
xdebug.client_port = 9003
xdebug.idekey = VSCODE

memory_limit = 512M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 120
display_errors = On
display_startup_errors = On
error_reporting = E_ALL
date.timezone = Europe/Rome
EOF

    # mail() e sendmail di PHP consegnati a Mailpit invece che al MTA di sistema
    # (che in locale non c'è): le mail finiscono nella UI su :8025 e non escono.
    # Il binario arriva dopo, con mailpit.sh: qui si scrive solo il percorso.
    if [ "${WITH_MAILPIT:-1}" = 1 ]; then
        echo 'sendmail_path = "/usr/local/bin/mailpit sendmail --smtp-addr 127.0.0.1:1025"' \
            | sudo tee -a "$dir/99-dev.ini" > /dev/null
    fi

    info "Scritto $dir/99-dev.ini"
done

# Ricarica solo i servizi già attivi (Apache/php-fpm possono non esserci ancora)
sudo systemctl try-restart php-fpm httpd apache2 2>/dev/null || true

ok "PHP configurato per lo sviluppo — Xdebug in ascolto su 127.0.0.1:9003"
