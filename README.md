# BC-250 Bazzite Dashboard

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

The installer is currently a starter stub and will be implemented in a future release.

## Updating

```bash
./update.sh
```

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
