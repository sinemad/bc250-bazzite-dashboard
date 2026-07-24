#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONKY_SOURCE="$PROJECT_DIR/conky"
SERVICE_SOURCE="$PROJECT_DIR/systemd/conky.service"
CONKY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/conky"
SERVICE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE_FILE="$SERVICE_DIR/conky.service"
BACKUP_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/bc250-bazzite-dashboard/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

command -v conky >/dev/null 2>&1 || die "Conky is not installed."
command -v systemctl >/dev/null 2>&1 || die "systemctl was not found."
[[ -f "$CONKY_SOURCE/bc250.conf" ]] || die "Missing packaged file: conky/bc250.conf"
[[ -f "$CONKY_SOURCE/scripts/bc250-stats.sh" ]] || die "Missing packaged file: conky/scripts/bc250-stats.sh"
[[ -f "$SERVICE_SOURCE" ]] || die "Missing packaged file: systemd/conky.service"
[[ -e "$CONKY_DIR/bc250.conf" || -e "$SERVICE_FILE" ]] || die "The dashboard is not installed. Run ./install.sh first."

backup_file() {
    local source="$1"
    local relative="$2"

    [[ -e "$source" ]] || return 0
    mkdir -p "$BACKUP_ROOT/$STAMP/$(dirname -- "$relative")"
    cp -a -- "$source" "$BACKUP_ROOT/$STAMP/$relative"
}

backup_file "$CONKY_DIR/bc250.conf" "conky/bc250.conf"
backup_file "$CONKY_DIR/scripts/bc250-stats.sh" "conky/scripts/bc250-stats.sh"
backup_file "$SERVICE_FILE" "systemd/conky.service"

mkdir -p "$CONKY_DIR/scripts" "$SERVICE_DIR"
install -m 0644 "$CONKY_SOURCE/bc250.conf" "$CONKY_DIR/bc250.conf"
install -m 0755 "$CONKY_SOURCE/scripts/bc250-stats.sh" "$CONKY_DIR/scripts/bc250-stats.sh"
install -m 0644 "$SERVICE_SOURCE" "$SERVICE_FILE"

NETWORK_INTERFACE="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-lo}"
sed -i "s/NETWORK_INTERFACE/$NETWORK_INTERFACE/g" "$CONKY_DIR/bc250.conf"

systemctl --user daemon-reload
systemctl --user enable conky.service >/dev/null
systemctl --user restart conky.service

printf 'BC-250 Bazzite Dashboard updated and restarted.\n'
printf 'Network graphs configured for: %s\n' "$NETWORK_INTERFACE"
printf 'Previous files backed up to: %s\n' "$BACKUP_ROOT/$STAMP"
