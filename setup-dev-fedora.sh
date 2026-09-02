#!/bin/bash

# ─────────────────────────────────────────────
#  SETUP AMBIENTE DI SVILUPPO — FEDORA (44+)
#  Le parti comuni con Ubuntu sono in file separati (composer.sh, phpenv.sh, …)
#  richiamati con 'bash <parte>.sh'. Esegui con: bash setup-dev-fedora.sh
#  Cosa installare si sceglie con le opzioni (vedi common/options.sh, --help):
#      bash setup-dev-fedora.sh --no-postgres --no-desktop
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

# Logging: salva tutto l'output (stdout+stderr) in un file con timestamp
LOG_FILE="$SETUP_DIR/setup-fedora-$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG_FILE") 2>&1
info "Log completo dell'esecuzione in $LOG_FILE"

keep_sudo_alive
backup_bashrc

# ── AGGIORNAMENTO SISTEMA ─────────────────────
step "Aggiornamento sistema"
sudo dnf update -y
ok "Sistema aggiornato"

# ── STRUMENTI BASE ────────────────────────────
step "Strumenti base"
sudo dnf install -y \
    git curl wget unzip zip tar \
    make gcc gcc-c++ kernel-devel \
    openssl openssl-devel \
    ca-certificates gnupg2

# fastfetch — neofetch è stato rimosso da Fedora 38+
sudo dnf install -y fastfetch 2>/dev/null || sudo dnf install -y neofetch 2>/dev/null || true

ok "Strumenti base installati"

# ── LIBRERIE DI SISTEMA ───────────────────────
step "Librerie di sistema e dipendenze comuni"

# Equivalente di software-properties-common (Ubuntu) su Fedora
sudo dnf install -y dnf-plugins-core dnf-utils

sudo dnf install -y \
    libffi-devel \
    zlib-devel \
    bzip2-devel \
    readline-devel \
    ncurses-devel \
    sqlite-devel \
    libpq-devel \
    libsodium-devel \
    gmp-devel \
    libtool \
    autoconf \
    automake \
    pkgconf \
    patch \
    patchutils \
    gettext \
    fuse-libs \
    xclip \
    xsel \
    ImageMagick \
    ImageMagick-devel \
    libxml2-devel \
    libcurl-devel \
    oniguruma-devel \
    libzip-devel \
    libwebp-devel \
    libjpeg-turbo-devel \
    libpng-devel \
    freetype-devel

ok "Librerie di sistema e ImageMagick installati"
done_item "Librerie di sistema + ImageMagick"

# ── REDIS ────────────────────────────────────
if [ "$WITH_REDIS" = 1 ]; then
    step "Redis"
    sudo dnf install -y redis
    sudo systemctl enable --now redis
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
# Fedora 44 include PHP 8.4 con tutte le estensioni nei repo base (pacchetti
# mantenuti da Remi upstream). La modularità DNF è stata rimossa da Fedora 39+,
# quindi niente 'dnf module'/Remi: per una versione specifica si usa phpenv.
step "PHP + estensioni (repo Fedora)"
sudo dnf install -y \
    php php-cli php-fpm php-common \
    php-mbstring php-xml php-zip \
    php-gd php-intl php-bcmath php-opcache \
    php-pdo php-mysqlnd php-pgsql \
    php-dbg php-pecl-xdebug \
    php-soap php-pecl-redis \
    php-bz2

# imagick a parte: il pacchetto Fedora è compilato per il PHP dei repo base, e su
# un sistema con PHP da Remi la dipendenza php(api) non si risolve facendo fallire
# l'INTERA transazione (quindi tutte le estensioni). Variante -im7 = build Remi.
sudo dnf install -y php-pecl-imagick 2>/dev/null \
    || sudo dnf install -y php-pecl-imagick-im7 2>/dev/null \
    || info "php-pecl-imagick non disponibile per questo PHP, saltato"
# Su Fedora non esiste mod_php: httpd esegue PHP via php-fpm (proxy fcgi).
# Senza questo, phpMyAdmin e i progetti sotto Apache non eseguono PHP.
sudo systemctl enable --now php-fpm
ok "PHP installato"
done_item "PHP + estensioni (repo Fedora)"

part php-ini-dev.sh
done_item "php.ini di sviluppo + Xdebug (127.0.0.1:9003)"

part composer.sh
done_item "Composer"

# ── PHPENV ────────────────────────────────────
if [ "$WITH_PHPENV" = 1 ]; then
    # Dipendenze necessarie a phpenv per compilare PHP da sorgente; alcune non
    # sono già nelle librerie di sistema sopra (libtidy-devel, libxslt-devel).
    step "Dipendenze compilazione PHP (php-build)"
    sudo dnf install -y \
        bzip2-devel libxml2-devel libcurl-devel \
        libjpeg-turbo-devel libpng-devel libwebp-devel \
        freetype-devel oniguruma-devel libzip-devel \
        sqlite-devel readline-devel libtidy-devel \
        libxslt-devel
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
    # Su Fedora venv è incluso in python3 (non esiste il pacchetto python3-venv)
    sudo dnf install -y python3 python3-pip python3-devel

    # pipx: su Fedora recente pip3 install --user è bloccato (PEP 668), si usa dnf
    sudo dnf install -y pipx 2>/dev/null || pip3 install --user pipx --break-system-packages 2>/dev/null || pip3 install --user pipx
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
    sudo dnf install -y java-25-openjdk java-25-openjdk-devel 2>/dev/null \
        || sudo dnf install -y java-latest-openjdk java-latest-openjdk-devel
    part java-home.sh
    ok "Java 25 installato"
    done_item "Java (OpenJDK 25, fallback java-latest)"
fi

# ── MYSQL ────────────────────────────────────
if [ "$WITH_MYSQL" = 1 ]; then
    step "MySQL Server"
    # Su Plasma/KDE, Akonadi (KDE PIM) preinstalla mariadb-server, in conflitto con
    # mysql-server. In quel caso si usa MariaDB (drop-in di MySQL) senza rimuovere
    # Akonadi. MYSQL_SERVICE tiene il nome del servizio per la verifica finale.
    if rpm -q mariadb-server &>/dev/null; then
        MYSQL_SERVICE=mariadb
        sudo systemctl enable --now mariadb
        info "mariadb-server già presente (Akonadi/KDE): uso MariaDB invece di MySQL"
        ok "MariaDB attivo"
        done_item "MariaDB Server (già presente, compatibile MySQL)"
    else
        MYSQL_SERVICE=mysqld
        sudo dnf install -y mysql-server mysql
        sudo systemctl enable --now mysqld
        ok "MySQL installato e avviato"
        done_item "MySQL Server"
    fi
    info "Esegui 'sudo mysql_secure_installation' per proteggere l'installazione"
fi

# ── POSTGRESQL ────────────────────────────────
if [ "$WITH_POSTGRES" = 1 ]; then
    step "PostgreSQL"
    sudo dnf install -y postgresql postgresql-server postgresql-contrib
    # initdb solo se la data dir è vuota: initdb rifiuta una cartella non vuota,
    # quindi controllare l'assenza di PG_VERSION non basta (una init interrotta la
    # lascia popolata a metà). Se serve ripartire da una init rotta:
    #   sudo rm -rf /var/lib/pgsql/data/* && sudo postgresql-setup --initdb
    if [ -z "$(sudo sh -c 'ls -A /var/lib/pgsql/data 2>/dev/null')" ]; then
        sudo postgresql-setup --initdb
    fi
    sudo systemctl enable --now postgresql
    ok "PostgreSQL installato e avviato"
    info "Accedi con: sudo -u postgres psql"
    done_item "PostgreSQL"
fi

# ── DOCKER ───────────────────────────────────
if [ "$WITH_DOCKER" = 1 ]; then
    step "Docker + Docker Compose"
    # Scarica il .repo direttamente: compatibile sia con DNF4 che con DNF5
    # (in DNF5 'config-manager --add-repo' non esiste più)
    sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo \
        -o /etc/yum.repos.d/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
# Opt-in (--dockerdesktop): GUI + VM sopra l'engine. Non è nel repo, si scarica
# come .rpm diretto da Docker; richiede KVM (virtualizzazione attiva nel BIOS).
if [ "$WITH_DOCKERDESKTOP" = 1 ]; then
    step "Docker Desktop"

    # Il .rpm risolve le dipendenze dal repo di Docker: se il blocco 'docker' non
    # l'ha già configurato (--no-docker), lo si prepara qui.
    if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
        sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo \
            -o /etc/yum.repos.d/docker-ce.repo
    fi

    tmp_rpm="$(mktemp --suffix=.rpm)"
    curl -fSL -o "$tmp_rpm" https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64.rpm
    sudo dnf install -y "$tmp_rpm"
    rm -f "$tmp_rpm"

    ok "Docker Desktop installato"
    info "Avvialo dal menu applicazioni; il primo avvio chiede l'accettazione dei termini"
    done_item "Docker Desktop"
fi

# ── APACHE (httpd) ────────────────────────────
if [ "$WITH_APACHE" = 1 ]; then
    step "Apache (httpd)"
    sudo dnf install -y httpd mod_ssl
    sudo systemctl enable --now httpd
    sudo usermod -aG apache "$USER"

    sudo setsebool -P httpd_can_network_connect 1
    # Nessuna apertura del firewall: lo sviluppo locale usa il loopback (localhost),
    # che non passa dal firewall. Aprire http/https esporrebbe i siti dev e phpMyAdmin
    # a tutta la LAN. Per abilitare di proposito i test da altri dispositivi:
    #   sudo firewall-cmd --permanent --add-service=http --add-service=https
    #   sudo firewall-cmd --reload

    # Abilita .htaccess (AllowOverride All) SOLO per la DocumentRoot, con un drop-in
    # in conf.d. Evita il 'sed' globale su httpd.conf che allargava l'override anche
    # a <Directory /> (root del filesystem), indebolendo tutto il server.
    # rewrite/headers/ssl/deflate sono già caricati di default via conf.modules.d.
    sudo tee /etc/httpd/conf.d/dev-allowoverride.conf > /dev/null << 'EOF'
<Directory "/var/www/html">
    AllowOverride All
</Directory>
EOF
    sudo systemctl restart httpd
    ok "Apache (httpd) installato e configurato"
    done_item "Apache (httpd) + mod_rewrite + mod_ssl"
fi

# ── PHPMYADMIN ────────────────────────────────
if [ "$WITH_PHPMYADMIN" = 1 ]; then
    step "phpMyAdmin"
    sudo dnf install -y phpMyAdmin
    sudo systemctl restart httpd
    ok "phpMyAdmin installato — accessibile su http://localhost/phpMyAdmin"
    info "Modifica /etc/phpMyAdmin/config.inc.php per configurare l'accesso"
    done_item "phpMyAdmin (http://localhost/phpMyAdmin)"
fi

# ── MAILPIT ──────────────────────────────────
if [ "$WITH_MAILPIT" = 1 ]; then
    part mailpit.sh nobody
    done_item "Mailpit — UI http://localhost:8025 | SMTP :1025"
fi

# ── CLI TOOLS ────────────────────────────────
step "Tool CLI moderni"

# Su Fedora bat/fd/eza/git-delta sono nei repo con i nomi corretti dei comandi
# (bat, fd, eza, delta) — non servono i symlink batcat/fdfind di Ubuntu.
sudo dnf install -y \
    bat \
    eza \
    fzf \
    ripgrep \
    fd-find \
    jq \
    httpie \
    git-delta \
    ShellCheck

part lazygit.sh

# Configura fzf nel .bashrc
if ! grep -q "fzf" "$HOME/.bashrc"; then
    echo '[ -f /usr/share/fzf/shell/key-bindings.bash ] && source /usr/share/fzf/shell/key-bindings.bash' >> "$HOME/.bashrc"
    echo '[ -f /usr/share/fzf/shell/completion.bash ] && source /usr/share/fzf/shell/completion.bash' >> "$HOME/.bashrc"
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
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo tee /etc/yum.repos.d/vscode.repo > /dev/null << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo dnf install -y code
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
sudo dnf install -y nss-tools
part mkcert.sh
done_item "mkcert (HTTPS locale)"

# ── GITHUB CLI ────────────────────────────────
step "GitHub CLI (gh)"
sudo curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo \
    -o /etc/yum.repos.d/gh-cli.repo
sudo dnf install -y gh
ok "GitHub CLI installato — autenticati con: gh auth login"
done_item "GitHub CLI (gh)"

# ── DIRENV ────────────────────────────────────
step "direnv (variabili d'ambiente per progetto)"
sudo dnf install -y direnv
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

    # git-filter-repo — nei repo Fedora
    sudo dnf install -y git-filter-repo

    # Clipboard manager: GPaste è per GNOME; Plasma usa Klipper (già integrato)
    if [ "$(detect_desktop)" = gnome ]; then
        sudo dnf install -y gpaste gnome-shell-extension-gpaste 2>/dev/null \
            || sudo dnf install -y gpaste
        CLIPBOARD="GPaste"
    else
        CLIPBOARD="Klipper (già presente)"
        info "Desktop non GNOME: GPaste saltato, Plasma usa Klipper"
    fi

    # VLC — richiede RPM Fusion (repo non-free/free non incluso di default in Fedora)
    sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" 2>/dev/null || true
    sudo dnf install -y vlc || info "VLC non installato (verifica RPM Fusion)"

    # Google Chrome — repo ufficiale Google
    if ! command -v google-chrome &>/dev/null; then
        sudo tee /etc/yum.repos.d/google-chrome.repo > /dev/null << 'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
        sudo dnf install -y google-chrome-stable
    fi

    # Telegram — nei repo Fedora, fallback su Flatpak
    sudo dnf install -y telegram-desktop 2>/dev/null || TELEGRAM_FLATPAK=1

    # Postman — non nei repo Fedora: via Flatpak (Flathub)
    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y --noninteractive flathub com.getpostman.Postman || info "Postman (Flatpak) saltato"
    if [ "${TELEGRAM_FLATPAK:-0}" = "1" ]; then
        flatpak install -y --noninteractive flathub org.telegram.desktop || info "Telegram saltato"
    fi

    # MEGAsync — RPM ufficiale per la versione di Fedora in uso
    if ! command -v megasync &>/dev/null; then
        MEGA_VER="$(rpm -E %fedora)"
        if curl -fsSLo /tmp/megasync.rpm "https://mega.nz/linux/repo/Fedora_${MEGA_VER}/x86_64/megasync-Fedora_${MEGA_VER}_x86_64.rpm"; then
            sudo dnf install -y /tmp/megasync.rpm
            rm -f /tmp/megasync.rpm
        else
            MEGA_SKIPPED=1
            info "Pacchetto MEGAsync per Fedora ${MEGA_VER} non disponibile, saltato (scaricalo da mega.nz/desktop)"
        fi
    fi

    ok "App desktop ed extra installate"
    if [ "${MEGA_SKIPPED:-0}" = "1" ]; then
        done_item "Chrome, Postman, Telegram, VLC, ${CLIPBOARD}, git-filter-repo ${YELLOW}(MEGAsync saltato)${NC}"
    else
        done_item "Chrome, Postman, Telegram, VLC, MEGAsync, ${CLIPBOARD}, git-filter-repo"
    fi

    part app-folders.sh || info "app-folders.sh non completato, proseguo"
    if [ "$(detect_desktop)" = gnome ]; then
        done_item "Menu applicazioni organizzato in cartelle per scopo"
    fi
fi

# ── VERIFICA ─────────────────────────────────
VERIFY_SERVICES=(php-fpm)
if [ "$WITH_APACHE" = 1 ];   then VERIFY_SERVICES+=(httpd); fi
if [ "$WITH_MYSQL" = 1 ];    then VERIFY_SERVICES+=("${MYSQL_SERVICE:-mysqld}"); fi
if [ "$WITH_POSTGRES" = 1 ]; then VERIFY_SERVICES+=(postgresql); fi
if [ "$WITH_DOCKER" = 1 ];   then VERIFY_SERVICES+=(docker); fi
if [ "$WITH_REDIS" = 1 ];    then VERIFY_SERVICES+=(redis); fi
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
