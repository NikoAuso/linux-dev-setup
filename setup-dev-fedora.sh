#!/bin/bash

# ─────────────────────────────────────────────
#  SETUP AMBIENTE DI SVILUPPO — FEDORA (44+)
#  Le parti comuni con Ubuntu sono in file separati (composer.sh, phpenv.sh, …)
#  richiamati con 'bash <parte>.sh'. Esegui con: bash setup-dev-fedora.sh
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
    htop btop \
    vim neovim \
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

# Redis
sudo dnf install -y redis
sudo systemctl enable --now redis

ok "Librerie di sistema, ImageMagick e Redis installati"

# ── TERMINALE (Starship + Tmux + Nerd Font) ───
step "Terminale (Starship + Tmux + Nerd Font)"
if [ -f "$COMMON_DIR/setup-terminal.sh" ]; then
    bash "$COMMON_DIR/setup-terminal.sh" || info "setup-terminal.sh non completato, proseguo"
else
    info "common/setup-terminal.sh non trovato: passo saltato"
fi
ok "Terminale configurato"

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
# Su Fedora non esiste mod_php: httpd esegue PHP via php-fpm (proxy fcgi).
# Senza questo, phpMyAdmin e i progetti sotto Apache non eseguono PHP.
sudo systemctl enable --now php-fpm
ok "PHP installato"

part composer.sh

# ── DIPENDENZE COMPILAZIONE PHP (php-build) ───
# Necessarie a phpenv per compilare PHP da sorgente; alcune non sono già nelle
# librerie di sistema sopra (libtidy-devel, libxslt-devel).
step "Dipendenze compilazione PHP (php-build)"
sudo dnf install -y \
    bzip2-devel libxml2-devel libcurl-devel \
    libjpeg-turbo-devel libpng-devel libwebp-devel \
    freetype-devel oniguruma-devel libzip-devel \
    sqlite-devel readline-devel libtidy-devel \
    libxslt-devel
ok "Dipendenze compilazione PHP installate"

part phpenv.sh
part php-tools.sh
part node.sh

# ── PYTHON ───────────────────────────────────
step "Python 3 + pip"
# Su Fedora venv è incluso in python3 (non esiste il pacchetto python3-venv)
sudo dnf install -y python3 python3-pip python3-devel

# pipx: su Fedora recente pip3 install --user è bloccato (PEP 668), si usa dnf
sudo dnf install -y pipx 2>/dev/null || pip3 install --user pipx --break-system-packages 2>/dev/null || pip3 install --user pipx

ok "Python 3 installato"

# ── JAVA (OpenJDK 25 LTS) ────────────────────
step "Java 25 (OpenJDK)"
sudo dnf install -y java-25-openjdk java-25-openjdk-devel 2>/dev/null \
    || sudo dnf install -y java-latest-openjdk java-latest-openjdk-devel
part java-home.sh
ok "Java 25 installato"

# ── MYSQL ────────────────────────────────────
step "MySQL Server"
sudo dnf install -y mysql-server mysql
sudo systemctl enable --now mysqld
ok "MySQL installato e avviato"
info "Esegui 'sudo mysql_secure_installation' per proteggere l'installazione"

# ── POSTGRESQL ────────────────────────────────
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

# ── DOCKER ───────────────────────────────────
step "Docker + Docker Compose"
# Scarica il .repo direttamente: compatibile sia con DNF4 che con DNF5
# (in DNF5 'config-manager --add-repo' non esiste più)
sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo \
    -o /etc/yum.repos.d/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
ok "Docker installato"
info "Riavvia la sessione per usare Docker senza sudo"

# ── APACHE (httpd) ────────────────────────────
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

# ── PHPMYADMIN ────────────────────────────────
step "phpMyAdmin"
sudo dnf install -y phpMyAdmin
sudo systemctl restart httpd
ok "phpMyAdmin installato — accessibile su http://localhost/phpMyAdmin"
info "Modifica /etc/phpMyAdmin/config.inc.php per configurare l'accesso"

part mailpit.sh nobody

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
    git-delta

part lazygit.sh

# Configura fzf nel .bashrc
if ! grep -q "fzf" "$HOME/.bashrc"; then
    echo '[ -f /usr/share/fzf/shell/key-bindings.bash ] && source /usr/share/fzf/shell/key-bindings.bash' >> "$HOME/.bashrc"
    echo '[ -f /usr/share/fzf/shell/completion.bash ] && source /usr/share/fzf/shell/completion.bash' >> "$HOME/.bashrc"
fi

part cli-aliases.sh

ok "bat, eza, fzf, ripgrep, fd, jq, httpie, lazygit, git-delta installati"

# ── VS CODE ───────────────────────────────────
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

# ── MKCERT ────────────────────────────────────
sudo dnf install -y nss-tools
part mkcert.sh

# ── GITHUB CLI ────────────────────────────────
step "GitHub CLI (gh)"
sudo curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo \
    -o /etc/yum.repos.d/gh-cli.repo
sudo dnf install -y gh
ok "GitHub CLI installato — autenticati con: gh auth login"

# ── DIRENV ────────────────────────────────────
step "direnv (variabili d'ambiente per progetto)"
sudo dnf install -y direnv
if ! grep -q "direnv hook" "$HOME/.bashrc"; then
    echo 'eval "$(direnv hook bash)"' >> "$HOME/.bashrc"
fi
ok "direnv installato — crea un file .envrc nella cartella del progetto"

part git-config.sh
part dev-aliases.sh

# ── APP DESKTOP & EXTRA ───────────────────────
step "App desktop ed extra (Chrome, Postman, Telegram, VLC, MEGAsync, GPaste, git-filter-repo)"

# git-filter-repo + GPaste — nei repo Fedora
sudo dnf install -y git-filter-repo gpaste gnome-shell-extension-gpaste 2>/dev/null \
    || sudo dnf install -y git-filter-repo gpaste

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

part app-folders.sh

part verify.sh php-fpm httpd mysqld postgresql docker redis mailpit

# ── RIEPILOGO FINALE ─────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup completato con successo!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Installato:${NC}"
echo -e "  ${GREEN}✓${NC} Starship + Tmux (su bash)"
echo -e "  ${GREEN}✓${NC} PHP + estensioni (repo Fedora) + Composer"
echo -e "  ${GREEN}✓${NC} phpenv + php-build (gestore versioni PHP)"
echo -e "  ${GREEN}✓${NC} php-cs-fixer, PHPStan, Pint, Infection, PHPUnit"
echo -e "  ${GREEN}✓${NC} Node.js LTS (nvm)"
echo -e "  ${GREEN}✓${NC} Python 3 + pip"
echo -e "  ${GREEN}✓${NC} Java (OpenJDK 25, fallback java-latest)"
echo -e "  ${GREEN}✓${NC} MySQL Server"
echo -e "  ${GREEN}✓${NC} Docker + Docker Compose"
echo -e "  ${GREEN}✓${NC} bat, eza, fzf, ripgrep, fd, jq, httpie, lazygit, git-delta"
echo -e "  ${GREEN}✓${NC} Apache (httpd) + mod_rewrite + mod_ssl"
echo -e "  ${GREEN}✓${NC} phpMyAdmin (http://localhost/phpMyAdmin)"
echo -e "  ${GREEN}✓${NC} Mailpit — UI http://localhost:8025 | SMTP :1025"
echo -e "  ${GREEN}✓${NC} VS Code + 21 estensioni"
echo -e "  ${GREEN}✓${NC} PostgreSQL"
echo -e "  ${GREEN}✓${NC} mkcert (HTTPS locale)"
echo -e "  ${GREEN}✓${NC} GitHub CLI (gh)"
echo -e "  ${GREEN}✓${NC} direnv (env per progetto)"
if [ "${MEGA_SKIPPED:-0}" = "1" ]; then
    echo -e "  ${GREEN}✓${NC} Chrome, Postman, Telegram, VLC, GPaste, git-filter-repo ${YELLOW}(MEGAsync saltato)${NC}"
else
    echo -e "  ${GREEN}✓${NC} Chrome, Postman, Telegram, VLC, MEGAsync, GPaste, git-filter-repo"
fi
echo -e "  ${GREEN}✓${NC} Librerie di sistema + ImageMagick + Redis"
echo -e "  ${GREEN}✓${NC} Menu applicazioni organizzato in cartelle per scopo"
echo -e "  ${GREEN}✓${NC} Git configurato con delta"
echo ""
echo -e "  ${YELLOW}Azioni post-riavvio:${NC}"
echo -e "  • sudo mysql_secure_installation"
echo -e "  • phpenv install <versione> per aggiungere versioni PHP extra"
echo ""
echo -e "  ${CYAN}Riavvia il sistema per applicare tutte le modifiche.${NC}"
echo ""
