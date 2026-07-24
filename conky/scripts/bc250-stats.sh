#!/usr/bin/env bash
set -u

primary_interface() {
    ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

find_amd_gpu_device() {
    local card
    for card in /sys/class/drm/card[0-9]*; do
        [[ -r "$card/device/vendor" ]] || continue
        [[ "$(<"$card/device/vendor")" == "0x1002" ]] && { printf '%s\n' "$card/device"; return; }
    done
    return 1
}

format_temp() { awk -v c="$1" 'BEGIN {printf "%.0f°F / %.0f°C\n", c*9/5+32, c}'; }

cpu_temp() {
    local c
    c="$(sensors 2>/dev/null | awk '/Tctl:|Tdie:|Package id 0:/ {v=$2; gsub(/[+°C]/,"",v); print v; exit}')"
    [[ -n "$c" ]] && format_temp "$c" || printf 'N/A\n'
}

gpu_temp() {
    local device file value
    device="$(find_amd_gpu_device)" || { printf 'N/A\n'; return; }
    file="$(find "$device"/hwmon/hwmon* -maxdepth 1 -name temp1_input 2>/dev/null | head -n1)"
    [[ -r "$file" ]] || { printf 'N/A\n'; return; }
    value="$(<"$file")"
    format_temp "$(awk -v v="$value" 'BEGIN {print v/1000}')"
}

nvme_temp() {
    local hwmon input label value
    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -r "$hwmon/name" ]] || continue
        [[ "$(<"$hwmon/name")" == *nvme* ]] || continue
        input=""
        for input in "$hwmon"/temp*_input; do
            [[ -r "$input" ]] || continue
            label="${input%_input}_label"
            [[ -r "$label" && "$(<"$label")" == "Composite" ]] && break
        done
        [[ -r "${input:-}" ]] || continue
        value="$(<"$input")"
        format_temp "$(awk -v v="$value" 'BEGIN {print v/1000}')"
        return
    done
    value="$(sensors 2>/dev/null | awk '/^nvme/{n=1} n && /^Composite:/ {v=$2; gsub(/[+°C]/,"",v); print v; exit}')"
    [[ -n "$value" ]] && format_temp "$value" || printf 'N/A\n'
}

gpu_usage() {
    local device value
    device="$(find_amd_gpu_device)" || { printf '0\n'; return; }
    value="$(cat "$device/gpu_busy_percent" 2>/dev/null || true)"
    [[ "$value" =~ ^[0-9]+$ ]] && printf '%s\n' "$value" || printf '0\n'
}

gpu_usage_text() {
    local value
    value="$(gpu_usage)"
    [[ "$value" == 0 ]] && printf 'N/A\n' || printf '%s%%\n' "$value"
}

gpu_clock() {
    local device value
    device="$(find_amd_gpu_device)" || { printf 'N/A\n'; return; }
    value="$(awk '/\*/ {print $2; exit}' "$device/pp_dpm_sclk" 2>/dev/null || true)"
    printf '%s\n' "${value:-N/A}"
}

gpu_name() {
    local device slot name
    device="$(find_amd_gpu_device)" || { printf 'AMD GPU\n'; return; }
    slot="$(basename "$(readlink -f "$device")")"
    name="$(lspci -s "$slot" 2>/dev/null | sed -E 's/^[^:]+: //; s/ \(rev [^)]+\)$//' | cut -c1-42)"
    printf '%s\n' "${name:-AMD GPU}"
}

network_type() {
    local iface type
    iface="$(primary_interface)"
    [[ -n "$iface" ]] || { printf 'Disconnected\n'; return; }
    type="$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: -v i="$iface" '$1==i {print $2; exit}')"
    case "$type" in wifi) printf 'Wi-Fi\n';; ethernet) printf 'Ethernet\n';; *) printf '%s\n' "${type:-Unknown}";; esac
}

ssid() {
    local iface value
    iface="$(primary_interface)"
    [[ "$iface" == wl* ]] || { printf 'Wired connection\n'; return; }
    value="$(nmcli -t -f GENERAL.CONNECTION device show "$iface" 2>/dev/null | sed -n 's/^GENERAL\.CONNECTION://p' | head -n1)"
    printf '%s\n' "${value:-Unknown network}"
}

signal_value() {
    local iface
    iface="$(primary_interface)"
    [[ "$iface" == wl* ]] || return 1
    nmcli -t -f IN-USE,SIGNAL device wifi list ifname "$iface" 2>/dev/null | awk -F: '$1=="*" {print $2; exit}'
}

signal_bar() {
    local value bars
    value="$(signal_value || true)"
    [[ "$value" =~ ^[0-9]+$ ]] || { printf '%s\n' "${value:-Wired}"; return; }
    if ((value>=80)); then bars='▂▄▆█'; elif ((value>=60)); then bars='▂▄▆▆'; elif ((value>=40)); then bars='▂▄▂▄'; elif ((value>=20)); then bars='▂▂▂▂'; else bars='▁▁▁▁'; fi
    printf '%s  %s%%\n' "$bars" "$value"
}

local_ip() {
    local iface value
    iface="$(primary_interface)"
    value="$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]; exit}')"
    printf '%s\n' "${value:-Disconnected}"
}

storage_mount() {
    findmnt --real --list --noheadings --output TARGET,SIZE,FSTYPE,OPTIONS --bytes 2>/dev/null |
        awk '$1!="/" && $1!="/boot" && $1!="/boot/efi" && $3!~/^(overlay|squashfs|tmpfs|devtmpfs)$/ && $4~/(^|,)rw(,|$)/ {if($2>max){max=$2; mount=$1}} END{print mount}'
}

selected_mount() { local m; m="$(storage_mount)"; [[ -n "$m" ]] && printf '%s\n' "$m" || printf '/home\n'; }
storage_label() { local m; m="$(selected_mount)"; [[ "$m" =~ ^(/home|/var/home)$ ]] && printf 'Home Data\n' || basename "$m"; }
storage_summary() { df -h --output=used,size "$(selected_mount)" 2>/dev/null | awk 'NR==2 {print $1 " / " $2}'; }
storage_free() { df -h --output=avail "$(selected_mount)" 2>/dev/null | awk 'NR==2 {print $1}'; }
storage_percent() { df -P --output=pcent "$(selected_mount)" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$1); print $1}'; }
storage_filesystem() { findmnt -n -o FSTYPE --target "$(selected_mount)" 2>/dev/null | head -n1; }

case "${1:-}" in
    cpu_temp) cpu_temp;; gpu_temp) gpu_temp;; nvme_temp) nvme_temp;;
    gpu_usage) gpu_usage;; gpu_usage_text) gpu_usage_text;; gpu_clock) gpu_clock;; gpu_name) gpu_name;;
    interface) primary_interface;; network_type) network_type;; ssid) ssid;; signal_bar) signal_bar;; ip) local_ip;;
    storage_mount) selected_mount;; storage_label) storage_label;; storage_summary) storage_summary;;
    storage_free) storage_free;; storage_percent) storage_percent;; storage_filesystem) storage_filesystem;;
    *) printf 'Unknown command: %s\n' "${1:-}" >&2; exit 1;;
esac
