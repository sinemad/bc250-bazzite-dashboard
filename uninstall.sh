#!/usr/bin/env bash
set -euo pipefail

CONKY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/conky"
SERVICE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE_FILE="$SERVICE_DIR/conky.service"
BACKUP_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/bc250-bazzite-dashboard/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
REMOVAL_BACKUP="$BACKUP_ROOT/uninstall-$STAMP"

backup_file() {
    local source="$1"
    local relative="$2"

    [[ -e "$source" ]] || return 0
    mkdir -p "$REMOVAL_BACKUP/$(dirname -- "$relative")"
    cp -a -- "$source" "$REMOVAL_BACKUP/$relative"
}

systemctl --user disable --now conky.service >/dev/null 2>&1 || true

backup_file "$CONKY_DIR/bc250.conf" "conky/bc250.conf"
backup_file "$CONKY_DIR/scripts/bc250-stats.sh" "conky/scripts/bc250-stats.sh"
backup_file "$SERVICE_FILE" "systemd/conky.service"

rm -f -- "$CONKY_DIR/bc250.conf"
rm -f -- "$CONKY_DIR/scripts/bc250-stats.sh"
rm -f -- "$SERVICE_FILE"

# Remove directories only when this leaves them empty; preserve unrelated files.
rmdir -- "$CONKY_DIR/scripts" 2>/dev/null || true
rmdir -- "$CONKY_DIR" 2>/dev/null || true
rmdir -- "$SERVICE_DIR" 2>/dev/null || true

systemctl --user daemon-reload
systemctl --user reset-failed conky.service >/dev/null 2>&1 || true

printf 'BC-250 Bazzite Dashboard uninstalled.\n'
if [[ -d "$REMOVAL_BACKUP" ]]; then
    printf 'Removed files backed up to: %s\n' "$REMOVAL_BACKUP"
fi
printf 'Existing historical backups were preserved in: %s\n' "$BACKUP_ROOT"
