#!/bin/bash

# ─────────────────────────────────────────────
#  SETUP TERMINALE — Starship + Tmux + Nerd Font
#  Cross-distro (Ubuntu/Fedora). Target: bash.
#  Esegui con: bash common/setup-terminal.sh
# ─────────────────────────────────────────────

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "Non eseguire questo script come root. Usa un utente normale con sudo."
    exit 1
fi

PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

# ── RILEVA IL PACKAGE MANAGER ─────────────────
if command -v dnf &>/dev/null; then
    PM_INSTALL="sudo dnf install -y"
elif command -v apt &>/dev/null; then
    sudo apt update
    PM_INSTALL="sudo apt install -y"
else
    echo "Package manager non supportato (serve dnf o apt)." >&2
    exit 1
fi

# ── DIPENDENZE ────────────────────────────────
step "Dipendenze (tmux, git, curl, unzip, fontconfig)"
$PM_INSTALL tmux git curl unzip fontconfig
ok "Dipendenze installate"

# ── STARSHIP ─────────────────────────────────
step "Starship prompt"
# Binario dalla release taggata invece di 'curl | sh' di uno script mutabile
# che si auto-eleva a root. Coerente con lazygit.sh/mailpit.sh.
if ! command -v starship &>/dev/null; then
    # Versione pinnata + checksum: aggiornali insieme quando bumpi la release.
    STARSHIP_VERSION="1.26.0"
    STARSHIP_SHA256="b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3"
    curl -fsSLo /tmp/starship.tar.gz \
        "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz"
    verify_sha256 /tmp/starship.tar.gz "$STARSHIP_SHA256"
    tar xf /tmp/starship.tar.gz -C /tmp starship
    sudo install /tmp/starship /usr/local/bin
    rm -f /tmp/starship.tar.gz /tmp/starship
fi
if ! grep -q "starship init" "$HOME/.bashrc"; then
    echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
fi

mkdir -p "$HOME/.config"
backup_if_exists "$HOME/.config/starship.toml"
cat > "$HOME/.config/starship.toml" << 'EOF'
add_newline = true
command_timeout = 1000

format = """
$directory$git_branch$git_status$php$nodejs$docker_context$cmd_duration
$character"""

[directory]
truncation_length = 3
truncate_to_repo = true
style = "bold cyan"

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold red"

[php]
symbol = " "
format = "[$symbol($version )]($style)"
style = "bold blue"

[nodejs]
symbol = " "
format = "[$symbol($version )]($style)"
style = "bold green"

[docker_context]
symbol = " "
format = "[$symbol$context]($style) "
only_with_files = true

[cmd_duration]
min_time = 2000
format = "[ $duration]($style) "
style = "yellow"

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"
EOF
ok "Starship installato e configurato"

# ── NERD FONT ─────────────────────────────────
step "JetBrainsMono Nerd Font (icone per prompt e eza)"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
    mkdir -p "$FONT_DIR"
    # Versione pinnata + checksum: aggiornali insieme quando bumpi la release.
    NERDFONT_VERSION="3.4.0"
    NERDFONT_SHA256="76f05ff3ace48a464a6ca57977998784ff7bdbb65a6d915d7e401cd3927c493c"
    if curl -fsSLo /tmp/JetBrainsMono.zip \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERDFONT_VERSION}/JetBrainsMono.zip"; then
        verify_sha256 /tmp/JetBrainsMono.zip "$NERDFONT_SHA256"
        unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR" >/dev/null
        rm -f /tmp/JetBrainsMono.zip
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
        ok "Nerd Font installata"
        info "Imposta 'JetBrainsMono Nerd Font' come font del terminale (GNOME Terminal → Preferenze → profilo → Testo)"
    else
        info "Download della Nerd Font fallito, saltato (scaricala da nerdfonts.com)"
    fi
else
    ok "Nerd Font già presente"
fi

# ── TMUX ─────────────────────────────────────
step "Tmux (config)"
backup_if_exists "$HOME/.tmux.conf"
cat > "$HOME/.tmux.conf" << 'EOF'
# Prefisso su Ctrl-a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
setw -g automatic-rename off
set -sg escape-time 0

# Colori veri (serve al prompt e a eza)
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"

# Split che mantengono la cartella corrente
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Naviga i pannelli con Alt+frecce (senza prefisso)
bind -n M-Left  select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up    select-pane -U
bind -n M-Down  select-pane -D

# Copia stile vi
setw -g mode-keys vi
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel

# Ricarica config
bind r source-file ~/.tmux.conf \; display "Config ricaricata!"

# Status bar minimale
set -g status-style "bg=black,fg=white"
set -g status-right "#[fg=cyan]%H:%M #[fg=green]%d/%m"

# ── Plugin (TPM) ─────────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
run '~/.tmux/plugins/tpm/tpm'
EOF
ok "Tmux configurato"

# ── TPM + PLUGIN ──────────────────────────────
step "TPM (plugin manager per tmux) + persistenza sessioni"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
# Installa i plugin in modo non interattivo (non fatale se fallisce)
"$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || \
    info "Plugin non installati ora: apri tmux e premi Ctrl-a + I"
ok "TPM installato (resurrect + continuum per ripristinare le sessioni)"

# ── RIEPILOGO ────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  Terminale configurato!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Starship + config (~/.config/starship.toml)"
echo -e "  ${GREEN}✓${NC} JetBrainsMono Nerd Font"
echo -e "  ${GREEN}✓${NC} Tmux + config (~/.tmux.conf)"
echo -e "  ${GREEN}✓${NC} TPM + tmux-resurrect + tmux-continuum"
echo ""
echo -e "  ${YELLOW}Da fare a mano:${NC}"
echo -e "  • Imposta 'JetBrainsMono Nerd Font' come font del terminale"
echo -e "  • Ricarica la shell:  source ~/.bashrc"
echo -e "  • In tmux, se i plugin non ci sono:  Ctrl-a + I"
echo ""
