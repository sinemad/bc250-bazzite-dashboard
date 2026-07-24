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

install_missing_packages() {
    local command package
    local -a requirements=(
        "conky:conky"
        "sensors:lm_sensors"
        "nmcli:NetworkManager"
        "ip:iproute"
        "findmnt:util-linux"
        "lsblk:util-linux"
        "lspci:pciutils"
    )
    local -a missing_packages=()

    for requirement in "${requirements[@]}"; do
        command="${requirement%%:*}"
        package="${requirement#*:}"

        if ! command -v "$command" >/dev/null 2>&1; then
            if [[ ! " ${missing_packages[*]} " =~ [[:space:]]${package}[[:space:]] ]]; then
                missing_packages+=("$package")
            fi
        fi
    done

    ((${#missing_packages[@]} == 0)) && return 0

    command -v rpm-ostree >/dev/null 2>&1 || {
        printf 'Missing required packages: %s\n' "${missing_packages[*]}" >&2
        die "rpm-ostree was not found; install the missing packages manually."
    }

    printf 'The following required packages are missing: %s\n' "${missing_packages[*]}"
    printf 'Installing them with rpm-ostree...\n'

    rpm-ostree install "${missing_packages[@]}" ||
        die "Package installation failed. No dashboard files were installed."

    printf '\nRequired packages were added to the next Bazzite deployment.\n'
    printf 'Reboot the computer, return to this directory, and run ./install.sh again.\n'
    exit 0
}

install_missing_packages

command -v systemctl >/dev/null 2>&1 || die "systemctl was not found."
[[ -f "$CONKY_SOURCE/bc250.conf" ]] || die "Missing packaged file: conky/bc250.conf"
[[ -f "$CONKY_SOURCE/scripts/bc250-stats.sh" ]] || die "Missing packaged file: conky/scripts/bc250-stats.sh"
[[ -f "$SERVICE_SOURCE" ]] || die "Missing packaged file: systemd/conky.service"

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
systemctl --user enable --now conky.service

printf 'BC-250 Bazzite Dashboard installed.\n'
printf 'Network graphs configured for: %s\n' "$NETWORK_INTERFACE"
printf 'Service status: systemctl --user status conky.service\n'
if [[ -d "$BACKUP_ROOT/$STAMP" ]]; then
    printf 'Previous files backed up to: %s\n' "$BACKUP_ROOT/$STAMP"
fi
