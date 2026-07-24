# BC-250 Bazzite Dashboard
[![Version](https://img.shields.io/github/v/release/sinemad/bc250-bazzite-dashboard?label=version)](https://github.com/sinemad/bc250-bazzite-dashboard/releases)
[![License](https://img.shields.io/github/license/sinemad/bc250-bazzite-dashboard)](LICENSE)

A lightweight Conky dashboard for BC-250 systems running Bazzite.

## Features

- Automatic hardware detection
- CPU and GPU temperatures
- CPU and GPU utilization
- NVMe temperature
- Memory usage
- Automatic storage detection that ignores Bazzite's immutable root filesystem
- Wi-Fi SSID and signal strength
- Network throughput graphs
- IP address and system uptime
- Automatic startup through a systemd user service

## Requirements

- Bazzite Desktop Mode
- Conky
- lm_sensors
- nvme-cli
- NetworkManager

## Installation

```bash
git clone https://github.com/USERNAME/bc250-bazzite-dashboard.git
cd bc250-bazzite-dashboard
./install.sh
```

The installer backs up an existing dashboard, installs the configuration and
helper, detects the active network interface, and enables the systemd user
service. Run it from Bazzite Desktop Mode without `sudo`.

If required packages are missing, the installer adds them with `rpm-ostree`
and asks you to reboot. After rebooting, run `./install.sh` again to finish the
dashboard installation.

## Updating

```bash
./update.sh
```

The updater fetches the configured upstream Git branch, displays available
commits and changed files, and asks for confirmation before fast-forwarding the
local repository. It then backs up the installed files, deploys the update, and
restarts Conky. Repositories with uncommitted or diverged changes are left
untouched. For non-interactive use, run `./update.sh --yes`.

## Uninstalling

```bash
./uninstall.sh
```

## Troubleshooting

Restart the dashboard:

```bash
systemctl --user restart conky.service
```

View service logs:

```bash
journalctl --user -u conky.service
```

Verify the monitoring helper:

```bash
~/.config/conky/scripts/bc250-stats.sh cpu_temp
```

## License

MIT
