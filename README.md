# linux-dev-setup

[![shellcheck](https://github.com/NikoAuso/linux-dev-setup/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/NikoAuso/linux-dev-setup/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Script di setup per un ambiente di sviluppo completo, su **Ubuntu** e **Fedora**.
Un solo comando installa e configura toolchain, database, servizi web e utility da riga di comando,
in modo **idempotente** (rilanciabile senza rompere nulla).

## Cosa installa

**Linguaggi e runtime**
- PHP + estensioni (mbstring, xml, curl, zip, gd, intl, bcmath, opcache, pdo, mysql, pgsql, xdebug, redis, imagick, soap, bz2, sqlite)
- `php.ini` di sviluppo pronto: Xdebug su `127.0.0.1:9003` (modo `trigger`), errori visibili, limiti alzati
- Composer + tool globali: php-cs-fixer, PHPStan, Infection, PHPUnit (+ Pint e `laravel new` con `WITH_LARAVEL`)
- phpenv + php-build (per compilare/gestire più versioni di PHP)
- Node.js LTS via nvm
- Python 3 + pip + pipx
- Java (OpenJDK 25, con fallback)

**Database e servizi**
- MySQL Server
- PostgreSQL
- Redis
- Docker + Docker Compose (con rotazione dei log dei container)
- Docker Desktop (opt-in con `--dockerdesktop`, richiede KVM)
- Apache (httpd/apache2) con moduli rewrite/ssl/headers
- phpMyAdmin
- Mailpit (email testing locale: UI su `:8025`, SMTP su `:1025`) — `mail()` di PHP ci finisce dentro

**Strumenti da terminale**
- Starship prompt + Tmux + Nerd Font (JetBrainsMono)
- bat, eza, fzf, ripgrep, fd, jq, httpie, lazygit, git-delta, shellcheck
- direnv, mkcert (HTTPS locale), GitHub CLI (`gh`), act (GitHub Actions in locale)
- `mycli` / `pgcli` via pipx (solo se il database corrispondente è attivo)
- Alias per git, Docker, Laravel e i tool moderni

**Applicazioni desktop**
- VS Code + estensioni (PHP, Laravel, Docker, Python, Java, ecc.)
- JetBrains Toolbox (PhpStorm & co.)
- Chrome, Postman, Telegram, VLC, MEGAsync + clipboard manager (GPaste su GNOME, su Plasma c'è già Klipper)
- Organizzazione automatica del menu applicazioni in cartelle (solo GNOME; Plasma raggruppa già per categoria)

**Git**
- Configurazione globale con delta come pager e alias utili

## Requisiti

- **Ubuntu** 24.04+ oppure **Fedora** 44+
- Desktop: **GNOME** e **KDE Plasma** supportati senza modifiche. Gli script rilevano il desktop e adattano i passi specifici (menu applicazioni, clipboard manager, database); su altri DE i passi GNOME-only vengono saltati senza errori.
- Utente normale con privilegi `sudo` (**non** eseguire come root)
- Connessione a internet

## Uso

```bash
# Ubuntu
bash setup-dev-ubuntu.sh

# Fedora
bash setup-dev-fedora.sh
```

### Scegliere cosa installare

Ogni blocco è attivo di default (`bash setup-dev-<distro>.sh` senza argomenti installa tutto).
Le opzioni servono soprattutto a togliere:

```bash
bash setup-dev-fedora.sh --help          # elenco dei blocchi

# solo PostgreSQL, senza app desktop né JetBrains
bash setup-dev-fedora.sh --no-mysql --no-desktop --no-jetbrains

# ambiente minimo: niente desktop, niente IDE, niente phpenv
bash setup-dev-ubuntu.sh --no-desktop --no-vscode --no-jetbrains --no-phpenv

# aggiungere un blocco opt-in (Docker Desktop, disattivo di default)
bash setup-dev-ubuntu.sh --dockerdesktop
```

| Blocco | Cosa comprende |
|---|---|
| `terminal` | Starship + Tmux + Nerd Font |
| `phpenv` | phpenv + php-build + dipendenze di compilazione |
| `laravel` | Pint e `laravel/installer` globali |
| `node` | Node.js LTS via nvm |
| `python` | Python 3 + pip + pipx (mycli/pgcli) |
| `java` | OpenJDK |
| `mysql` | MySQL Server + mycli (su KDE usa il MariaDB preinstallato da Akonadi) |
| `postgres` | PostgreSQL + pgcli |
| `redis` | Redis |
| `docker` | Docker + Docker Compose |
| `dockerdesktop` | Docker Desktop — **opt-in**, attiva con `--dockerdesktop` |
| `apache` | Apache |
| `phpmyadmin` | phpMyAdmin (forzato off senza `apache` o `mysql`) |
| `mailpit` | Mailpit + `sendmail_path` di PHP |
| `vscode` | VS Code + estensioni |
| `jetbrains` | JetBrains Toolbox |
| `act` | act |
| `desktop` | Chrome, Postman, Telegram, VLC, MEGAsync, clipboard manager (GPaste su GNOME, Klipper su Plasma) |

`--<nome>` lo include esplicitamente, `--no-<nome>` lo esclude. Le stesse scelte si possono
passare come variabili d'ambiente `WITH_<NOME>=0` (utile negli script); la riga di comando
ha la precedenza sull'ambiente.

I default stanno in [`common/options.sh`](common/options.sh). Il riepilogo finale e
`verify.sh` seguono gli stessi flag, quindi non segnalano come mancante ciò che hai escluso.

## Struttura

```
setup-dev-ubuntu.sh    # entrypoint Ubuntu (apt)
setup-dev-fedora.sh    # entrypoint Fedora (dnf)
common/                # logica condivisa tra le due distro
├── lib.sh             # helper: output colorato, backup, keepalive sudo, riepilogo
├── options.sh         # flag WITH_* — cosa installare
├── composer.sh        # Composer (con verifica checksum)
├── phpenv.sh          # phpenv + php-build
├── php-ini-dev.sh     # php.ini di sviluppo + Xdebug
├── php-tools.sh       # tool PHP globali
├── node.sh            # Node.js via nvm
├── mailpit.sh         # Mailpit + servizio systemd
├── mkcert.sh          # certificati HTTPS locali
├── lazygit.sh         # lazygit dall'ultima release
├── act.sh             # act (GitHub Actions in locale)
├── setup-terminal.sh  # Starship + Tmux + Nerd Font
├── vscode-extensions.sh
├── jetbrains-toolbox.sh # JetBrains Toolbox (checksum dall'API JetBrains)
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
- **KDE Plasma**: dove Akonadi ha già installato MariaDB, il blocco `mysql` lo riusa invece di installare `mysql-server` (che sarebbe in conflitto), senza rimuovere il backend di KDE PIM.
- **Azioni post-setup** suggerite a fine run: `sudo mysql_secure_installation`, eventuali versioni PHP extra con `phpenv install <versione>`.

## Personalizzazione

L'identità git si passa da fuori, e viene scritta **solo se non è già configurata**
(un rilancio non sovrascrive nome ed email reali):

```bash
GIT_USER_NAME="Mario Rossi" GIT_USER_EMAIL="mario@example.com" bash setup-dev-fedora.sh
```

Cosa installare si sceglie con le opzioni descritte sopra.

## Licenza

[MIT](LICENSE)
