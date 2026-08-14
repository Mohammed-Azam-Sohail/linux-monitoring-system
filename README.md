# Linux Monitoring & Auto-Maintenance System

A Bash-based Linux monitoring and automation system designed to demonstrate practical Linux system administration, monitoring, alerting, service recovery, reporting, log management, security updates, and scheduled maintenance.

> **Portfolio focus:** Linux / Bash / systemd / cron / automation / troubleshooting  
> **Tested scope:** Linux (Ubuntu/Debian environment)  

---

## Overview

This project provides a lightweight Linux monitoring and maintenance system built primarily with Bash and standard Linux utilities.

The system combines:

- Real-time system monitoring
- Configurable warning and critical thresholds
- Automated alerting
- Critical service self-healing
- Daily system reports
- Log retention and compression
- Weekly maintenance
- Security-update automation
- Cron-based scheduling

The project uses Linux-native interfaces and utilities such as `/proc`, `/sys`, `systemd`, `journalctl`, `ss`, `iostat`, and cron.

---

## Architecture


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
                                      │                           │
                                      │                           ▼
                                      │                       logs/*.gz
                                      │
                                      ▼
                              Generated Reports

                              security_update.sh
                                      │
                                      ▼
                              Security Updates


## Features

- Real-time CPU, memory, disk, I/O, network, load and process monitoring
- Configurable warning/critical thresholds with alerting
- Automatic critical-service recovery with retries
- Daily system reports with compression
- Log retention, compression and pruning
- Weekly system maintenance and cleanup
- Automated security updates
- Cron-based scheduling for all recurring tasks

## Project Structure

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
└── README.md

## Tech Stack

- Linux
- Bash
- systemd
- cron
- awk / grep / sed
- journalctl
- procfs / sysfs
- Git


## Configuration

All thresholds and operational settings are centralized in `config.cfg`.

Typical settings include:

- CPU, memory, disk and load thresholds
- Monitoring intervals
- Critical services and restart retries
- Log retention and rotation limits
- Email alert settings

## Requirements

- Linux (Ubuntu/Debian recommended)
- `bc`
- `sysstat` (`iostat`)
- `procps` (`top`, `free`, `ps`)
- `iproute2` (`ss`)
- `util-linux` (`find`, `logger`, etc.)
- `cron`
- `systemd`

Optional:
- `mail` / `sendmail` for email alerts
- `zip` or `gzip` for report compression
- `stress` for threshold/stress testing

## Installation

git clone https://github.com/Mohammed-Azam-Sohail/linux-monitoring-system.git
cd linux-monitoring-system
chmod +x *.sh

## Testing

All shell scripts were syntax-checked successfully:
for f in *.sh; do
    bash -n "$f" || exit 1
done

### Stress Testing

The monitoring dashboard was tested using Linux `stress` to intentionally increase system load.
When configured thresholds were breached:
- Dashboard status changed from **NORMAL** to **WARNING/CRITICAL**
- Corresponding metric indicators changed color
- Threshold-based alerts were triggered
