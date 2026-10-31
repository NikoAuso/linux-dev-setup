#!/bin/bash

# ── gitleaks (binario da GitHub, cross-distro) + hook pre-commit globale ─
# Esegui con: bash gitleaks.sh

set -euo pipefail
PART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$PART_DIR/lib.sh"

if command -v gitleaks &>/dev/null; then
    ok "gitleaks già installato"
else
    # Versione pinnata + checksum: aggiornali insieme quando bumpi la release.
    GITLEAKS_VERSION="8.30.1"
    GITLEAKS_SHA256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
    # Cartella privata, non /tmp condivisa: il binario estratto finisce in
    # /usr/local/bin via sudo e nessun altro utente deve poterlo sostituire.
    TMP_DIR="$(mktemp -d)"
    curl -fsSLo "$TMP_DIR/gitleaks.tar.gz" "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
    verify_sha256 "$TMP_DIR/gitleaks.tar.gz" "$GITLEAKS_SHA256"
    tar xf "$TMP_DIR/gitleaks.tar.gz" -C "$TMP_DIR" gitleaks
    sudo install -m 0755 "$TMP_DIR/gitleaks" /usr/local/bin/gitleaks
    rm -rf "$TMP_DIR"
    ok "gitleaks installato"
fi

# Hook globale via core.hooksPath: copre ogni repo, anche quelle già clonate.
# Un core.hooksPath globale scelto altrove non lo tocchiamo.
HOOKS_DIR="$HOME/.config/git/hooks"
CURRENT_HOOKS_PATH="$(git config --global --get core.hooksPath || true)"
if [ -n "$CURRENT_HOOKS_PATH" ] && [ "$CURRENT_HOOKS_PATH" != "$HOOKS_DIR" ]; then
    info "core.hooksPath globale è già $CURRENT_HOOKS_PATH: hook gitleaks non installato"
    exit 0
fi

mkdir -p "$HOOKS_DIR"
cat > "$HOME/.config/git/gitleaks.toml" << 'EOF'
# Regole predefinite di gitleaks + quelle sotto (installato da linux-dev-setup).
[extend]
useDefault = true

# Variabili di collection/environment Postman: nome e valore stanno su righe
# diverse e la regola generic-api-key del default non le vede.
[[rules]]
id = "postman-variable-secret"
description = "Valore di una variabile Postman con nome da segreto"
regex = '''(?i)"key"\s*:\s*"[^"]*(?:token|secret|password|passwd|api[_-]?key|auth)[^"]*"\s*,\s*"value"\s*:\s*"([A-Za-z0-9+/=_]{20,})"'''
secretGroup = 1
entropy = 3.5
EOF

cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Hook pre-commit globale (installato da linux-dev-setup): blocca il commit se
# gitleaks trova segreti nei file staged. Falso positivo: commento
# "gitleaks:allow" sulla riga, o il fingerprint in .gitleaksignore.
# Poi esegue l'hook pre-commit della repo, che core.hooksPath salterebbe.
# shortcut: inoltra solo pre-commit; con hook di repo di altro tipo (git-lfs,
# commit-msg) o un core.hooksPath locale (husky) va esteso.
set -e
# --config scavalcherebbe il .gitleaks.toml della repo: lo passiamo solo se manca
config=()
[ -f .gitleaks.toml ] || config=(--config "$HOME/.config/git/gitleaks.toml")
gitleaks git --pre-commit --staged --redact --no-banner --verbose "${config[@]}"
repo_hook="$(git rev-parse --git-common-dir)/hooks/pre-commit"
if [ -x "$repo_hook" ]; then
    exec "$repo_hook" "$@"
fi
EOF
chmod +x "$HOOKS_DIR/pre-commit"
git config --global core.hooksPath "$HOOKS_DIR"
ok "Hook pre-commit globale: gitleaks blocca i segreti nei commit"
