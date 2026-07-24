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
ASSUME_YES=false
INSTALL_ONLY=false

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s [--yes]\n' "${0##*/}"
    printf '  --yes  Install available Git updates without prompting.\n'
}

while (($# > 0)); do
    case "$1" in
        --yes|-y)
            ASSUME_YES=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --install-only)
            # Internal option used after this script updates its own repository.
            INSTALL_ONLY=true
            ;;
        *)
            usage >&2
            die "Unknown option: $1"
            ;;
    esac
    shift
done

update_repository() {
    local upstream local_commit remote_commit answer

    command -v git >/dev/null 2>&1 ||
        die "Git is required to check for repository updates."

    git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
        die "This copy was not installed from a Git repository. Download or clone the latest release manually."

    if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain)" ]]; then
        die "The repository has uncommitted changes. Commit or discard them before updating."
    fi

    upstream="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    [[ -n "$upstream" ]] ||
        die "The current branch has no upstream branch. Configure one before updating."

    printf 'Checking %s for updates...\n' "$upstream"
    git -C "$PROJECT_DIR" fetch --prune

    local_commit="$(git -C "$PROJECT_DIR" rev-parse HEAD)"
    remote_commit="$(git -C "$PROJECT_DIR" rev-parse '@{upstream}')"

    if [[ "$local_commit" == "$remote_commit" ]]; then
        printf 'The repository is already up to date.\n'
        return 0
    fi

    if ! git -C "$PROJECT_DIR" merge-base --is-ancestor HEAD '@{upstream}'; then
        die "The local and upstream branches have diverged. Resolve them manually with Git."
    fi

    printf '\nAvailable updates:\n'
    git -C "$PROJECT_DIR" log --oneline --decorate HEAD..'@{upstream}'
    printf '\nFiles changed:\n'
    git -C "$PROJECT_DIR" diff --stat HEAD..'@{upstream}'

    if [[ "$ASSUME_YES" != true ]]; then
        [[ -t 0 ]] || die "Confirmation requires a terminal. Rerun with --yes to update non-interactively."
        read -r -p "Download and install these updates? [y/N] " answer
        [[ "$answer" =~ ^[Yy]$ ]] || {
            printf 'Update cancelled.\n'
            exit 0
        }
    fi

    git -C "$PROJECT_DIR" merge --ff-only '@{upstream}'
    printf 'Repository updated successfully.\n'

    # Continue from the newly downloaded script instead of executing a file
    # that may have changed underneath the current shell process.
    exec "$PROJECT_DIR/update.sh" --install-only
}

if [[ "$INSTALL_ONLY" != true ]]; then
    update_repository
fi

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
