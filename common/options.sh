#!/bin/bash

# ─────────────────────────────────────────────
#  OPZIONI — cosa installare
#  Va sourcato dagli entrypoint passando i loro argomenti:
#      source "$COMMON_DIR/options.sh" "$@"
#
#  Ogni blocco è attivo di default (il senso dello script è "un comando e hai
#  tutto"), quindi le opzioni servono soprattutto a togliere:
#      bash setup-dev-fedora.sh --no-mysql --no-desktop
#      bash setup-dev-fedora.sh --laravel --no-jetbrains
#
#  Equivalente via variabili d'ambiente (la riga di comando ha la precedenza):
#      WITH_MYSQL=0 bash setup-dev-fedora.sh
# ─────────────────────────────────────────────

OPTION_NAMES=(terminal phpenv laravel node python java mysql postgres redis
              docker dockerdesktop apache phpmyadmin mailpit vscode jetbrains act desktop)

# Opzioni disattive di default: opt-in esplicito con --<nome>. Il resto è on.
OPTION_DEFAULT_OFF=(dockerdesktop)

# Nome dell'entrypoint che ci sta sourcando, letto qui: dentro una funzione
# gli indici di BASH_SOURCE scalano e punterebbero a options.sh stesso.
_ENTRYPOINT="$(basename "${BASH_SOURCE[1]:-setup-dev-<distro>.sh}")"

# nome-opzione → variabile: laravel → WITH_LARAVEL
_flag_var() { echo "WITH_${1^^}"; }

_usage() {
    cat << EOF
Uso: bash $_ENTRYPOINT [opzioni]

  --<nome>      installa il blocco (è già il default, serve per essere espliciti)
  --no-<nome>   esclude il blocco
  --help        questo messaggio

Blocchi (tutti attivi di default, tranne quelli marcati opt-in):
  terminal    Starship + Tmux + Nerd Font
  phpenv      phpenv + php-build + dipendenze di compilazione
  laravel     Pint e laravel/installer globali
  node        Node.js LTS via nvm
  python      Python 3 + pip + pipx (mycli/pgcli)
  java        OpenJDK
  mysql       MySQL Server + mycli
  postgres    PostgreSQL + pgcli
  redis       Redis
  docker      Docker + Docker Compose
  dockerdesktop  Docker Desktop (opt-in, richiede KVM) — usa --dockerdesktop
  apache      Apache
  phpmyadmin  phpMyAdmin (forzato off senza apache o mysql)
  mailpit     Mailpit (+ sendmail_path di PHP)
  vscode      VS Code + estensioni
  jetbrains   JetBrains Toolbox
  act         act (GitHub Actions in locale)
  desktop     Chrome, Postman, Telegram, VLC, MEGAsync, GPaste

Identità git (scritta solo se non già configurata):
  GIT_USER_NAME="Mario Rossi" GIT_USER_EMAIL=mario@example.com bash setup-dev-<distro>.sh
EOF
}

# ── Default: la variabile d'ambiente se c'è, altrimenti 1 (0 per gli opt-in) ──
for _name in "${OPTION_NAMES[@]}"; do
    _var="$(_flag_var "$_name")"
    case " ${OPTION_DEFAULT_OFF[*]} " in
        *" $_name "*) _default=0 ;;
        *)            _default=1 ;;
    esac
    printf -v "$_var" '%s' "${!_var:-$_default}"
done

# ── Riga di comando: sovrascrive i default ──
while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h) _usage; exit 0 ;;
        --no-*)    _name="${1#--no-}"; _val=0 ;;
        --*)       _name="${1#--}";    _val=1 ;;
        *)         echo "Argomento non riconosciuto: $1" >&2; _usage >&2; exit 1 ;;
    esac

    case " ${OPTION_NAMES[*]} " in
        *" $_name "*) ;;
        *) echo "Opzione non riconosciuta: $1" >&2; _usage >&2; exit 1 ;;
    esac

    printf -v "$(_flag_var "$_name")" '%s' "$_val"
    shift
done

# phpMyAdmin non ha senso senza il server web e senza il database che amministra
if [ "$WITH_APACHE" != 1 ] || [ "$WITH_MYSQL" != 1 ]; then
    # shellcheck disable=SC2034  # esportata più sotto dal ciclo su OPTION_NAMES
    WITH_PHPMYADMIN=0
fi

# Esportate perché anche le parti in common/ (che girano in un processo separato
# via 'bash') devono vederle.
for _name in "${OPTION_NAMES[@]}"; do
    export "$(_flag_var "$_name")"
done
unset _name _var _val _default
