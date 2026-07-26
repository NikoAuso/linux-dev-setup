# linux-dev-setup

[![shellcheck](https://github.com/NikoAuso/linux-dev-setup/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/NikoAuso/linux-dev-setup/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Script di setup per un ambiente di sviluppo completo, su **Ubuntu** e **Fedora**.
Un solo comando installa e configura toolchain, database, servizi web e utility da riga di comando,
in modo **idempotente** (rilanciabile senza rompere nulla).

## Cosa installa

**Linguaggi e runtime**
- PHP + estensioni (mbstring, xml, curl, zip, gd, intl, bcmath, opcache, pdo, mysql, pgsql, xdebug, redis, imagick, soap, bz2, sqlite)
- Composer + tool globali: php-cs-fixer, PHPStan, Pint, Infection, PHPUnit
- phpenv + php-build (per compilare/gestire più versioni di PHP)
- Node.js LTS via nvm
- Python 3 + pip + pipx
- Java (OpenJDK 25, con fallback)

**Database e servizi**
- MySQL Server
- PostgreSQL
- Redis
- Docker + Docker Compose
- Apache (httpd/apache2) con moduli rewrite/ssl/headers
- phpMyAdmin
- Mailpit (email testing locale: UI su `:8025`, SMTP su `:1025`)

**Strumenti da terminale**
- Starship prompt + Tmux + Nerd Font (JetBrainsMono)
- bat, eza, fzf, ripgrep, fd, jq, httpie, lazygit, git-delta
- direnv, mkcert (HTTPS locale), GitHub CLI (`gh`)
- Alias per git, Docker, Laravel e i tool moderni

**Applicazioni desktop**
- VS Code + estensioni (PHP, Laravel, Docker, Python, Java, ecc.)
- Chrome, Postman, Telegram, VLC, MEGAsync, GPaste
- Organizzazione automatica del menu applicazioni GNOME in cartelle

**Git**
- Configurazione globale con delta come pager e alias utili

## Requisiti

- **Ubuntu** 24.04+ oppure **Fedora** 44+
- Utente normale con privilegi `sudo` (**non** eseguire come root)
- Connessione a internet

## Uso

```bash
# Ubuntu
bash setup-dev-ubuntu.sh

# Fedora
bash setup-dev-fedora.sh
```

Lo script chiede la password `sudo` una volta e la mantiene viva per tutta la durata.
Al termine riavvia il sistema (o almeno la sessione) per applicare gruppi (docker, apache) e PATH.

## Struttura

```
setup-dev-ubuntu.sh    # entrypoint Ubuntu (apt)
setup-dev-fedora.sh    # entrypoint Fedora (dnf)
common/                # logica condivisa tra le due distro
├── lib.sh             # helper: output colorato, backup, keepalive sudo
├── composer.sh        # Composer (con verifica checksum)
├── phpenv.sh          # phpenv + php-build
├── php-tools.sh       # tool PHP globali
├── node.sh            # Node.js via nvm
├── mailpit.sh         # Mailpit + servizio systemd
├── mkcert.sh          # certificati HTTPS locali
├── lazygit.sh         # lazygit dall'ultima release
├── setup-terminal.sh  # Starship + Tmux + Nerd Font
├── vscode-extensions.sh
├── git-config.sh      # identità e config git globale
├── cli-aliases.sh / dev-aliases.sh
├── java-home.sh / app-folders.sh
└── verify.sh          # verifica finale di comandi e servizi
```

Gli entrypoint richiamano le parti comuni con `bash common/<parte>.sh`, passando solo le
differenze specifiche della distro (nomi pacchetti, gestore, servizi).

## Note

- **Logging**: ogni esecuzione salva l'output completo in `setup-<distro>-<timestamp>.log`.
- **Verifica**: alla fine `verify.sh` controlla che i comandi principali rispondano e che i servizi siano attivi, segnalando in giallo ciò che manca.
- **Idempotenza**: pacchetti già presenti vengono saltati, le righe nel `.bashrc` vengono aggiunte una sola volta.
- **Azioni post-setup** suggerite a fine run: `sudo mysql_secure_installation`, eventuali versioni PHP extra con `phpenv install <versione>`.

## Personalizzazione

L'identità git è impostata in [`common/git-config.sh`](common/git-config.sh): modifica
`user.name` e `user.email` con i tuoi dati prima di lanciare lo script.

## Licenza

[MIT](LICENSE)
