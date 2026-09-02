# ─────────────────────────────────────────────
#  SETUP AMBIENTE DI SVILUPPO — NixOS
#
#  NixOS è dichiarativo: a differenza di Ubuntu/Fedora non si "installa" nulla
#  con uno script imperativo. Si importa questo modulo nella configurazione di
#  sistema e si ricostruisce lo stato:
#
#      # 1. copia questo file (es. in /etc/nixos/dev-setup.nix)
#      # 2. in /etc/nixos/configuration.nix, dentro imports = [ ... ]:
#      #        ./dev-setup.nix
#      # 3. applica:
#      sudo nixos-rebuild switch
#
#  Per TOGLIERE un blocco (equivalente di --no-<nome> negli .sh): commenta la
#  sua sezione e rilancia 'nixos-rebuild switch'. Nix rimuove ciò che non è più
#  dichiarato — niente residui, niente disinstall manuali.
#
#  phpenv/nvm NON hanno senso qui: le versioni di PHP e Node si scelgono dal
#  pacchetto nixpkgs (php82/php83/php84, nodejs_20/_22). Per versioni diverse
#  per-progetto si usa un flake o shell.nix, non un version-manager imperativo.
# ─────────────────────────────────────────────

{ config, pkgs, lib, ... }:

let
  # CAMBIA con il tuo username: serve per aggiungerti ai gruppi docker/httpd.
  username = "nikoauso";

  # PHP di sviluppo: una sola build con estensioni + php.ini già dentro.
  # Equivale a php-tools + php-ini-dev.sh degli altri script.
  phpDev = pkgs.php84.buildEnv {
    extensions = { enabled, all }: enabled ++ (with all; [
      xdebug redis imagick
    ]);
    # Le altre estensioni (mbstring, curl, zip, gd, intl, bcmath, opcache, pdo,
    # mysqli, pdo_mysql, pgsql, soap, bz2, sqlite3) sono già in 'enabled' di
    # default in nixpkgs; qui aggiungiamo solo quelle non abilitate di serie.
    extraConfig = ''
      display_errors = On
      display_startup_errors = On
      error_reporting = E_ALL
      memory_limit = 512M
      max_execution_time = 120
      upload_max_filesize = 64M
      post_max_size = 64M

      [xdebug]
      xdebug.mode = debug
      xdebug.start_with_request = trigger
      xdebug.client_host = 127.0.0.1
      xdebug.client_port = 9003
    '';
  };
in
{
  # vscode / chrome / postman / jetbrains sono unfree.
  nixpkgs.config.allowUnfree = true;

  # Abilita 'nix profile' e i flake (installi imperativi: nix profile install nixpkgs#foo).
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ── PACCHETTI DI SISTEMA ──────────────────────
  environment.systemPackages = with pkgs; [
    # strumenti base
    git curl wget unzip zip gnutar
    gcc gnumake pkg-config openssl cacert fastfetch

    # PHP + Composer (composer legato allo stesso php)
    phpDev
    php84Packages.composer

    # tool PHP globali (php-cs-fixer, phpstan, ecc. si installano via composer
    # global; qui i binari nativi disponibili in nixpkgs)
    phpstan php84Packages.php-cs-fixer

    # Node.js LTS  — blocco 'node'
    nodejs_22

    # Python  — blocco 'python'
    python3 mycli pgcli

    # Java  — blocco 'java'
    jdk

    # tool CLI moderni  — nomi dei comandi già corretti su Nix
    bat eza fzf ripgrep fd jq httpie lazygit delta shellcheck
    direnv mkcert gh act tmux git-filter-repo

    # desktop  — blocco 'desktop' (commenta la riga per escluderli)
    google-chrome postman telegram-desktop vlc megasync
    vscode          # blocco 'vscode'
    jetbrains-toolbox  # blocco 'jetbrains'
  ];

  # Nerd Font (JetBrainsMono) — blocco 'terminal'
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # ── TERMINALE ─────────────────────────────────
  programs.starship.enable = true;   # prompt

  # direnv hook + fzf keybindings per le shell interattive.
  # (programs.fzf esiste solo in home-manager, non come modulo NixOS: qui si
  #  sorgono a mano gli script del pacchetto.)
  environment.interactiveShellInit = ''
    eval "$(direnv hook bash)"
    source ${pkgs.fzf}/share/fzf/key-bindings.bash
    source ${pkgs.fzf}/share/fzf/completion.bash
  '';

  # alias  — equivalente di cli-aliases.sh / dev-aliases.sh
  environment.shellAliases = {
    ll = "eza -la --icons --git";
    cat = "bat";
    gs = "git status";
    gp = "git pull";
    dco = "docker compose";
    a = "php artisan";
    pest = "./vendor/bin/pest";
  };

  # ── SERVIZI: DATABASE ─────────────────────────
  # blocco 'mysql'
  services.mysql = {
    enable = true;
    package = pkgs.mysql84;
  };

  # blocco 'postgres' — initdb è gestito da NixOS, niente postgresql-setup
  services.postgresql = {
    enable = true;
    enableTCPIP = false;   # solo socket locale, come default dev
  };

  # blocco 'redis'
  services.redis.servers."" = {
    enable = true;
    port = 6379;
  };

  # ── DOCKER ────────────────────────────────────
  # blocco 'docker' — log rotation come nel daemon.json degli altri script
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      log-driver = "json-file";
      log-opts = { max-size = "10m"; max-file = "3"; };
    };
  };

  # ── APACHE (httpd) ────────────────────────────
  # blocco 'apache' — su NixOS Apache esegue PHP via mod_php dichiarato qui.
  services.httpd = {
    enable = true;
    enablePHP = true;
    phpPackage = phpDev;
    adminAddr = "admin@localhost";
    virtualHosts."localhost" = {
      documentRoot = "/var/www/html";
      # AllowOverride All solo per la DocumentRoot (abilita .htaccess dei progetti)
      extraConfig = ''
        <Directory "/var/www/html">
          AllowOverride All
          Require all granted
        </Directory>
      '';
    };
  };

  # ── MAILPIT ───────────────────────────────────
  # blocco 'mailpit' — UI http://localhost:8025 | SMTP :1025
  # Ricorda: in phpDev.extraConfig aggiungi 'sendmail_path' se vuoi che mail()
  # finisca in Mailpit:  sendmail_path = "${pkgs.mailpit}/bin/mailpit sendmail"
  # nixpkgs recenti (>= 25.05) hanno rimosso services.mailpit.enable in favore
  # del modello multi-istanza: definire un'istanza la abilita.
  services.mailpit.instances.default = { };

  # ── phpMyAdmin ────────────────────────────────
  # blocco 'phpmyadmin' — nixpkgs non ha un modulo dedicato: si serve la webroot
  # via httpd. Decommenta (richiede il blocco apache + mysql attivi).
  # services.httpd.virtualHosts."localhost".extraConfig = lib.mkAfter ''
  #   Alias /phpmyadmin "${pkgs.phpmyadmin}/share/phpmyadmin"
  #   <Directory "${pkgs.phpmyadmin}/share/phpmyadmin">
  #     Require all granted
  #   </Directory>
  # '';

  # ── UTENTE: gruppi per docker/apache ──────────
  users.users.${username}.extraGroups = [ "docker" "wwwrun" ];
}
