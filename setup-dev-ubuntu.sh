#!/bin/bash

# ─────────────────────────────────────────────
#  SETUP AMBIENTE DI SVILUPPO — UBUNTU
#  Le parti comuni con Fedora sono in file separati (composer.sh, phpenv.sh, …)
#  richiamati con 'bash <parte>.sh'. Esegui con: bash setup-dev-ubuntu.sh
#  Cosa installare si sceglie con le opzioni (vedi common/options.sh, --help):
#      bash setup-dev-ubuntu.sh --no-postgres --no-desktop
# ─────────────────────────────────────────────

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "Non eseguire questo script come root. Usa un utente normale con sudo."
    exit 1
fi

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$SETUP_DIR/common"
if [ ! -f "$COMMON_DIR/lib.sh" ]; then
    echo "common/lib.sh non trovato accanto a questo script." >&2
    exit 1
fi
# shellcheck source=common/lib.sh
source "$COMMON_DIR/lib.sh"
# shellcheck source=common/options.sh
source "$COMMON_DIR/options.sh" "$@"

# Esegue un file-parte comune dalla cartella common/
part() { bash "$COMMON_DIR/$1" "${@:2}"; }

# Configura il repo apt di Docker in formato deb822 (.sources). Idempotente,
# condiviso dai blocchi 'docker' e 'dockerdesktop'. Rimuove il vecchio
# docker.list, altrimenti la stessa suite risulterebbe configurata due volte
# (warning di apt) quando convivono engine e Docker Desktop.
setup_docker_apt_repo() {
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null << EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo apt update
}

# Logging: salva tutto l'output (stdout+stderr) in un file con timestamp
LOG_FILE="$SETUP_DIR/setup-ubuntu-$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG_FILE") 2>&1
info "Log completo dell'esecuzione in $LOG_FILE"

keep_sudo_alive
backup_bashrc

# ── AGGIORNAMENTO SISTEMA ─────────────────────
step "Aggiornamento sistema"
sudo apt update && sudo apt upgrade -y
ok "Sistema aggiornato"

# ── STRUMENTI BASE ────────────────────────────
step "Strumenti base"
sudo apt install -y \
    git curl wget unzip zip tar \
    build-essential \
    openssl \
    ca-certificates gnupg

# fastfetch (sostituto moderno di neofetch, rimosso in Ubuntu 24.04+)
sudo apt install -y fastfetch 2>/dev/null || sudo apt install -y neofetch 2>/dev/null || true

ok "Strumenti base installati"

# ── LIBRERIE DI SISTEMA ───────────────────────
step "Librerie di sistema e dipendenze comuni"

sudo apt install -y software-properties-common

sudo apt install -y \
    libffi-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libncurses-dev \
    libsqlite3-dev \
    libpq-dev \
    libsodium-dev \
    libgmp-dev \
    libtool \
    autoconf \
    automake \
    pkg-config \
    patch \
    patchutils \
    gettext \
    xclip \
    xsel \
    imagemagick \
    libmagickwand-dev \
    libssl-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    libzip-dev \
    libwebp-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev

# libfuse2 — Ubuntu 22.04 usa libfuse2, Ubuntu 24.04+ usa libfuse2t64
sudo apt install -y libfuse2 2>/dev/null || sudo apt install -y libfuse2t64 2>/dev/null || true

ok "Librerie di sistema e ImageMagick installati"
done_item "Librerie di sistema + ImageMagick"

# ── REDIS ────────────────────────────────────
if [ "$WITH_REDIS" = 1 ]; then
    step "Redis"
    sudo apt install -y redis-server
    sudo systemctl enable --now redis-server
    ok "Redis installato e avviato"
    done_item "Redis"
fi

# ── TERMINALE (Starship + Tmux + Nerd Font) ───
if [ "$WITH_TERMINAL" = 1 ]; then
    step "Terminale (Starship + Tmux + Nerd Font)"
    part setup-terminal.sh || info "setup-terminal.sh non completato, proseguo"
    ok "Terminale configurato"
    done_item "Starship + Tmux (su bash)"
fi

# ── PHP ───────────────────────────────────────
step "PHP + estensioni (versione di default dei repo Ubuntu)"
sudo apt install -y \
    php php-cli php-fpm php-common \
    php-mbstring php-xml php-curl php-zip \
    php-gd php-intl php-bcmath \
    php-mysql php-pgsql \
    php-xdebug php-phpdbg \
    php-soap php-redis php-imagick \
    php-bz2 php-sqlite3

# OPcache: pacchetto a sé sulle vecchie Ubuntu, già nel core da PHP 8.5
# (dove 'php-opcache' non ha candidato e farebbe abortire apt)
sudo apt install -y php-opcache 2>/dev/null || true
ok "PHP installato"
done_item "PHP + estensioni"

part php-ini-dev.sh
done_item "php.ini di sviluppo + Xdebug (127.0.0.1:9003)"

part composer.sh
done_item "Composer"

# ── PHPENV ────────────────────────────────────
if [ "$WITH_PHPENV" = 1 ]; then
    # Dipendenze necessarie a phpenv per compilare PHP da sorgente; tidy e xslt
    # non sono già nelle librerie di sistema sopra.
    step "Dipendenze compilazione PHP (php-build)"
    sudo apt install -y \
        libbz2-dev libxml2-dev libcurl4-openssl-dev \
        libjpeg-dev libpng-dev libwebp-dev \
        libfreetype6-dev libonig-dev libzip-dev \
        libsqlite3-dev libreadline-dev libtidy-dev \
        libxslt1-dev
    ok "Dipendenze compilazione PHP installate"

    part phpenv.sh
    done_item "phpenv + php-build (gestore versioni PHP)"
fi

part php-tools.sh
if [ "$WITH_LARAVEL" = 1 ]; then
    done_item "php-cs-fixer, PHPStan, Infection, PHPUnit, Pint, laravel/installer"
else
    done_item "php-cs-fixer, PHPStan, Infection, PHPUnit"
fi

# ── NODE ─────────────────────────────────────
if [ "$WITH_NODE" = 1 ]; then
    part node.sh
    done_item "Node.js LTS (nvm)"
fi

# ── PYTHON ───────────────────────────────────
if [ "$WITH_PYTHON" = 1 ]; then
    step "Python 3 + pip"
    sudo apt install -y python3 python3-pip python3-venv python3-dev

    # pipx: su Ubuntu 24.04+ pip3 install --user è bloccato (PEP 668), si usa apt
    sudo apt install -y pipx 2>/dev/null || pip3 install --user pipx --break-system-packages 2>/dev/null || pip3 install --user pipx
    pipx ensurepath >/dev/null 2>&1 || true

    # Client CLI dei database, isolati da pipx (hanno dipendenze Python proprie)
    if [ "$WITH_MYSQL" = 1 ]; then
        pipx install mycli || info "mycli non installato"
    fi
    if [ "$WITH_POSTGRES" = 1 ]; then
        pipx install pgcli || info "pgcli non installato"
    fi

    ok "Python 3 installato"
    done_item "Python 3 + pip + pipx (mycli/pgcli)"
fi

# ── JAVA (OpenJDK 25 LTS) ────────────────────
if [ "$WITH_JAVA" = 1 ]; then
    step "Java 25 (OpenJDK)"
    sudo apt install -y openjdk-25-jdk openjdk-25-jre 2>/dev/null \
        || sudo apt install -y default-jdk
    part java-home.sh
    ok "Java installato"
    done_item "Java (OpenJDK 25, fallback default-jdk)"
fi

# ── MYSQL ────────────────────────────────────
if [ "$WITH_MYSQL" = 1 ]; then
    step "MySQL Server"
    # Su Plasma/KDE, Akonadi (KDE PIM) preinstalla mariadb-server, in conflitto con
    # mysql-server. In quel caso si usa MariaDB (drop-in di MySQL) senza rimuovere
    # Akonadi. MYSQL_SERVICE tiene il nome del servizio per la verifica finale.
    if dpkg -s mariadb-server &>/dev/null; then
        MYSQL_SERVICE=mariadb
        sudo systemctl enable --now mariadb
        info "mariadb-server già presente (Akonadi/KDE): uso MariaDB invece di MySQL"
        ok "MariaDB attivo"
        done_item "MariaDB Server (già presente, compatibile MySQL)"
    else
        MYSQL_SERVICE=mysql
        sudo apt install -y mysql-server mysql-client
        sudo systemctl enable --now mysql
        ok "MySQL installato e avviato"
        done_item "MySQL Server"
    fi
    info "Esegui 'sudo mysql_secure_installation' per proteggere l'installazione"
fi

# ── POSTGRESQL ────────────────────────────────
if [ "$WITH_POSTGRES" = 1 ]; then
    step "PostgreSQL"
    sudo apt install -y postgresql postgresql-client postgresql-contrib
    sudo systemctl enable --now postgresql
    ok "PostgreSQL installato e avviato"
    info "Accedi con: sudo -u postgres psql"
    done_item "PostgreSQL"
fi

# ── DOCKER ───────────────────────────────────
if [ "$WITH_DOCKER" = 1 ]; then
    step "Docker + Docker Compose"
    setup_docker_apt_repo
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Rotazione dei log dei container: senza questa, un container loquace riempie
    # /var/lib/docker fino a saturare il disco. Non tocca una config esistente.
    if [ ! -f /etc/docker/daemon.json ]; then
        sudo install -d /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
    fi

    sudo systemctl enable --now docker
    sudo systemctl restart docker
    sudo usermod -aG docker "$USER"
    ok "Docker installato"
    info "Riavvia la sessione per usare Docker senza sudo"
    done_item "Docker + Docker Compose (log rotation 10m x3)"
fi

# ── DOCKER DESKTOP ────────────────────────────
# Opt-in (--dockerdesktop): GUI + VM sopra l'engine. Non è nel repo apt, si scarica
# come .deb diretto da Docker; richiede KVM (virtualizzazione attiva nel BIOS).
if [ "$WITH_DOCKERDESKTOP" = 1 ]; then
    step "Docker Desktop"

    # La .deb risolve le dipendenze dal repo apt di Docker: se il blocco 'docker'
    # non l'ha già configurato (--no-docker), lo si prepara qui.
    [ -f /etc/apt/keyrings/docker.asc ] || setup_docker_apt_repo

    tmp_deb="$(mktemp --suffix=.deb)"
    curl -fSL -o "$tmp_deb" https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb
    sudo apt install -y "$tmp_deb"
    rm -f "$tmp_deb"

    ok "Docker Desktop installato"
    info "Avvialo dal menu applicazioni; il primo avvio chiede l'accettazione dei termini"
    done_item "Docker Desktop"
fi

# ── APACHE2 ───────────────────────────────────
if [ "$WITH_APACHE" = 1 ]; then
    step "Apache2"
    sudo apt install -y apache2
    sudo systemctl enable --now apache2
    sudo usermod -aG www-data "$USER"

    # Abilita i moduli più usati
    sudo a2enmod rewrite headers ssl deflate

    # Abilita .htaccess (AllowOverride All) SOLO per la DocumentRoot, con un file di
    # conf dedicato invece di un 'sed' su apache2.conf: il default Ubuntu per
    # /var/www è AllowOverride None, quindi senza questo i .htaccess sono ignorati.
    sudo tee /etc/apache2/conf-available/dev-allowoverride.conf > /dev/null << 'EOF'
<Directory "/var/www/html">
    AllowOverride All
</Directory>
EOF
    sudo a2enconf dev-allowoverride
    sudo systemctl restart apache2
    ok "Apache2 installato e configurato"
    done_item "Apache2 + moduli (rewrite, ssl, headers)"
fi

# ── PHPMYADMIN ────────────────────────────────
if [ "$WITH_PHPMYADMIN" = 1 ]; then
    step "phpMyAdmin"
    # Precompila le risposte per evitare prompt interattivi.
    # La password dell'utente di controllo interno di phpMyAdmin è generata a caso
    # (non viene mai digitata: il login avviene con le credenziali MySQL), così non
    # resta un segreto debole hardcoded nel repo. admin-pass è la password di root
    # MySQL: su un'installazione locale root usa auth_socket, quindi resta vuota.
    PMA_CTRL_PASS="$(openssl rand -base64 18)"
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $PMA_CTRL_PASS" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password " | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $PMA_CTRL_PASS" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections

    sudo apt install -y phpmyadmin
    sudo phpenmod mbstring
    sudo systemctl restart apache2
    ok "phpMyAdmin installato — accessibile su http://localhost/phpmyadmin"
    info "Login con credenziali MySQL. root usa auth_socket: imposta una password root con 'sudo mysql_secure_installation' o crea un utente dedicato per accedere"
    done_item "phpMyAdmin (http://localhost/phpmyadmin)"
fi

# ── MAILPIT ──────────────────────────────────
if [ "$WITH_MAILPIT" = 1 ]; then
    part mailpit.sh nogroup
    done_item "Mailpit — UI http://localhost:8025 | SMTP :1025"
fi

# ── CLI TOOLS ────────────────────────────────
step "Tool CLI moderni"

sudo apt install -y \
    bat \
    fzf \
    ripgrep \
    fd-find \
    jq \
    httpie \
    shellcheck

# eza — nei repo ufficiali Ubuntu da 24.04
sudo apt install -y eza

# git-delta — non nei repo ufficiali Ubuntu, va installato dal .deb di GitHub
if ! command -v delta &>/dev/null; then
    # Versione pinnata + checksum: aggiornali insieme quando bumpi la release.
    DELTA_VERSION="0.19.2"
    DELTA_SHA256="ea4f0222950ee750a3d38dd80d03bce4cee07a3f63928fc47548383bcaf23093"
    curl -fsSLo /tmp/delta.deb "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb"
    verify_sha256 /tmp/delta.deb "$DELTA_SHA256"
    sudo dpkg -i /tmp/delta.deb
    rm /tmp/delta.deb
fi

# Su Ubuntu 'bat' si chiama 'batcat' — creiamo il symlink
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
fi

# Su Ubuntu 'fd' si chiama 'fdfind' — creiamo il symlink
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
fi

part lazygit.sh

# Configura fzf nel .bashrc
if ! grep -q "fzf" "$HOME/.bashrc"; then
    echo '[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash' >> "$HOME/.bashrc"
    echo '[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash' >> "$HOME/.bashrc"
fi

part cli-aliases.sh

ok "bat, eza, fzf, ripgrep, fd, jq, httpie, lazygit, git-delta, shellcheck installati"
done_item "bat, eza, fzf, ripgrep, fd, jq, httpie, lazygit, git-delta, shellcheck"

if [ "$WITH_ACT" = 1 ]; then
    part act.sh
    done_item "act (GitHub Actions in locale)"
fi

# ── VS CODE ───────────────────────────────────
if [ "$WITH_VSCODE" = 1 ]; then
    step "Visual Studio Code"
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
    sudo chmod a+r /etc/apt/keyrings/microsoft.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

    sudo apt update
    sudo apt install -y code
    ok "VS Code installato"

    part vscode-extensions.sh
    done_item "VS Code + estensioni"
fi

# ── JETBRAINS TOOLBOX ─────────────────────────
if [ "$WITH_JETBRAINS" = 1 ]; then
    part jetbrains-toolbox.sh
    done_item "JetBrains Toolbox"
fi

# ── MKCERT ────────────────────────────────────
sudo apt install -y libnss3-tools
part mkcert.sh
done_item "mkcert (HTTPS locale)"

# ── GITHUB CLI ────────────────────────────────
step "GitHub CLI (gh)"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh
ok "GitHub CLI installato — autenticati con: gh auth login"
done_item "GitHub CLI (gh)"

# ── DIRENV ────────────────────────────────────
step "direnv (variabili d'ambiente per progetto)"
sudo apt install -y direnv
if ! grep -q "direnv hook" "$HOME/.bashrc"; then
    echo 'eval "$(direnv hook bash)"' >> "$HOME/.bashrc"
fi
ok "direnv installato — crea un file .envrc nella cartella del progetto"
done_item "direnv (env per progetto)"

part git-config.sh
done_item "Git configurato con delta"

part dev-aliases.sh

# ── APP DESKTOP & EXTRA ───────────────────────
if [ "$WITH_DESKTOP" = 1 ]; then
    step "App desktop ed extra (Chrome, Postman, Telegram, VLC, MEGAsync, clipboard manager, git-filter-repo)"

    # Ogni installazione qui è guardata con '|| info': sono app indipendenti e con
    # 'set -e' un singolo fallimento (una source apt rotta, uno snap ritirato)
    # farebbe saltare in silenzio tutte quelle successive.
    DESKTOP_ENV="$(detect_desktop)"

    # VLC, git-filter-repo — nei repo Ubuntu
    sudo apt install -y vlc git-filter-repo || info "VLC/git-filter-repo non installati"

    # Clipboard manager: GPaste è per GNOME; Plasma usa Klipper (già integrato).
    # gpaste-2 è daemon + CLI: l'integrazione nella shell sta nell'estensione.
    if [ "$DESKTOP_ENV" = gnome ]; then
        sudo apt install -y gpaste-2 gnome-shell-extension-gpaste \
            || sudo apt install -y gpaste-2 \
            || info "GPaste non installato"
        CLIPBOARD="GPaste"
    else
        CLIPBOARD="Klipper (già presente)"
        info "Desktop non GNOME: GPaste saltato, Plasma usa Klipper"
    fi

    # Google Chrome — repo ufficiale Google. 'apt update' esce non-zero se una
    # qualunque altra source è rotta (PPA stantio, release EOL): senza guardia si
    # porterebbe dietro tutto il resto del blocco.
    if ! command -v google-chrome &>/dev/null; then
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
            | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
        sudo chmod a+r /etc/apt/keyrings/google-chrome.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
            | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
        sudo apt update || info "apt update con errori, proseguo"
        sudo apt install -y google-chrome-stable || info "Google Chrome non installato"
    fi

    # Postman e Telegram — via snap
    if command -v snap &>/dev/null; then
        snap list postman &>/dev/null || sudo snap install postman || info "Postman (snap) saltato"
        snap list telegram-desktop &>/dev/null || sudo snap install telegram-desktop || info "Telegram (snap) saltato"
    else
        info "snap non disponibile: Postman e Telegram saltati"
    fi

    # MEGAsync — .deb ufficiale per la versione di Ubuntu in uso
    if ! command -v megasync &>/dev/null; then
        MEGA_VER="$(. /etc/os-release && echo "$VERSION_ID")"
        if curl -fsSLo /tmp/megasync.deb "https://mega.nz/linux/repo/xUbuntu_${MEGA_VER}/amd64/megasync-xUbuntu_${MEGA_VER}_amd64.deb"; then
            sudo apt install -y /tmp/megasync.deb || MEGA_SKIPPED=1
            rm -f /tmp/megasync.deb
        else
            MEGA_SKIPPED=1
            info "Pacchetto MEGAsync per Ubuntu ${MEGA_VER} non disponibile, saltato (scaricalo da mega.nz/desktop)"
        fi
    fi

    ok "App desktop ed extra installate"
    if [ "${MEGA_SKIPPED:-0}" = "1" ]; then
        done_item "Chrome, Postman, Telegram, VLC, ${CLIPBOARD}, git-filter-repo ${YELLOW}(MEGAsync saltato)${NC}"
    else
        done_item "Chrome, Postman, Telegram, VLC, MEGAsync, ${CLIPBOARD}, git-filter-repo"
    fi

    part app-folders.sh || info "app-folders.sh non completato, proseguo"
    if [ "$DESKTOP_ENV" = gnome ]; then
        done_item "Menu applicazioni organizzato in cartelle per scopo"
    fi
fi

# ── VERIFICA ─────────────────────────────────
VERIFY_SERVICES=()
if [ "$WITH_APACHE" = 1 ];   then VERIFY_SERVICES+=(apache2); fi
if [ "$WITH_MYSQL" = 1 ];    then VERIFY_SERVICES+=("${MYSQL_SERVICE:-mysql}"); fi
if [ "$WITH_POSTGRES" = 1 ]; then VERIFY_SERVICES+=(postgresql); fi
if [ "$WITH_DOCKER" = 1 ];   then VERIFY_SERVICES+=(docker); fi
if [ "$WITH_REDIS" = 1 ];    then VERIFY_SERVICES+=(redis-server); fi
if [ "$WITH_MAILPIT" = 1 ];  then VERIFY_SERVICES+=(mailpit); fi
part verify.sh "${VERIFY_SERVICES[@]}"

# ── RIEPILOGO FINALE ─────────────────────────
print_summary
echo -e "  ${YELLOW}Azioni post-riavvio:${NC}"
if [ "$WITH_MYSQL" = 1 ]; then
    echo -e "  • sudo mysql_secure_installation"
fi
if [ "$WITH_PHPENV" = 1 ]; then
    echo -e "  • phpenv install <versione> per aggiungere versioni PHP extra"
fi
echo ""
echo -e "  ${CYAN}Riavvia il sistema per applicare tutte le modifiche.${NC}"
echo ""
