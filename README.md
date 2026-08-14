# Linux Monitoring & Auto-Maintenance System

A Bash-based Linux monitoring and automation system demonstrating practical Linux system administration, monitoring, alerting, service recovery, reporting, log management, security updates, and scheduled maintenance.

> **Portfolio focus:** Linux / Bash / systemd / cron / automation / troubleshooting  
> **Tested scope:** Ubuntu/Debian Linux

---

## Overview

The system provides:

- Real-time system monitoring
- Configurable warning/critical thresholds
- Automated alerting
- Critical-service self-healing
- Daily system reports
- Log retention and compression
- Weekly maintenance
- Security-update automation
- Cron-based scheduling

Built using Linux-native interfaces and utilities including `/proc`, `/sys`, `systemd`, `journalctl`, `ss`, and `iostat`.

---

## Architecture

```text
                         ┌─────────────────────────┐
                         │       monitor.sh        │
                         │   Real-time Dashboard   │
                         └────────────┬────────────┘
                                      │
             ┌────────────────────────┼────────────────────────┐
             │                        │                        │
             ▼                        ▼                        ▼
       Metrics Collection       alerts.sh                  logs/
             │                        │                        │
             │                        ▼                        ├── health_history.log
             │                  Alert Processing              ├── alerts.log
             │                        │                        ├── self_heal.log
             │                        ▼                        └── security_update.log
             │                  Alerts / Email
             │
             ├── CPU
             ├── Memory
             ├── Disk
             ├── Disk I/O
             ├── Load Average
             ├── Network Speed
             ├── Network Connections
             ├── System Errors
             ├── TCP Retransmissions
             └── Top Processes


                         ┌─────────────────────────┐
                         │      Cron Scheduler     │
                         └────────────┬────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
          ▼                           ▼                           ▼
   self_heal.sh                 report.sh                 maintenance.sh
          │                           │                           │
          ▼                           ▼                           ▼
      systemd                    reports/                log_rotation.sh
                                                              │
                                                              ▼
                                                          logs/*.gz

                              security_update.sh
                                      │
                                      ▼
                              Security Updates
```

---

## Features

- Real-time CPU, memory, disk, I/O, network, load and process monitoring
- Configurable warning/critical thresholds with alerting
- Automatic critical-service recovery with retries
- Daily system reports with compression
- Log retention, compression and pruning
- Weekly system maintenance and cleanup
- Automated security updates
- Cron-based scheduling

---

## Project Structure

```text
linux-monitoring-system/
├── alerts.sh
├── config.cfg
├── log_rotation.sh
├── maintenance.sh
├── monitor.sh
├── report.sh
├── security_update.sh
├── self_heal.sh
├── setup_cron.sh
├── logs/
├── reports/
├── screenshots/
│   └── normal--stressed.png
└── README.md
```

---

## Tech Stack

- Linux
- Bash
- systemd
- cron
- awk / grep / sed
- journalctl
- procfs / sysfs
- Git

---

## Configuration

All thresholds and operational settings are centralized in `config.cfg`.

Typical settings include:

- CPU, memory, disk and load thresholds
- Monitoring intervals
- Critical services and restart retries
- Log retention and rotation limits
- Email alert settings

---

## Requirements

- Linux (Ubuntu/Debian recommended)
- `bc`
- `sysstat` (`iostat`)
- `procps` (`top`, `free`, `ps`)
- `iproute2` (`ss`)
- `cron`
- `systemd`

Optional:

- `mail` / `sendmail` — email alerts
- `zip` / `gzip` — report compression
- `stress` — threshold testing

---

## Installation

```bash
git clone https://github.com/Mohammed-Azam-Sohail/linux-monitoring-system.git
cd linux-monitoring-system
chmod +x *.sh
```

Run the dashboard:

```bash
./monitor.sh
```

Install scheduled jobs:

```bash
./setup_cron.sh
```

---

## Testing Syntax

All shell scripts were syntax-checked successfully:

```bash
for f in *.sh; do
    bash -n "$f" || exit 1
done
```

### Stress Testing
The monitoring dashboard was tested using Linux `stress` to intentionally increase system load.
When configured thresholds were breached:

- Dashboard status changed from **NORMAL** to **WARNING/CRITICAL**
- Metric indicators changed color also indicated in screenshots folder
- Threshold-based alerts were triggered
