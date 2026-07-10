# 🐧 Linux SysAdmin Daily Toolkit

A collection of **standalone** bash scripts for daily Linux system administration tasks. Each script is independent, requires no configuration files, and can be executed on its own.

---

## 📋 Table of Contents
- [Features](#-features)
- [Quick Start](#-quick-start)
- [Scripts Overview](#-scripts-overview)
- [Installation](#-installation)
- [Usage Examples](#-usage-examples)
- [Cron Setup](#-cron-setup)
- [Script Details](#-script-details)
- [Tips & Tricks](#-tips--tricks)
- [Troubleshooting](#-troubleshooting)
- [Customization](#-customization)
- [License](#-license)

---

## ✨ Features

- **16 standalone scripts** - Each works independently
- **No configuration files** - Everything is self-contained
- **Color-coded output** - Easy to read at a glance
- **Safe operations** - Dry-run modes for destructive actions
- **Cross-distro** - Works on Ubuntu, Debian, RHEL, CentOS, Fedora
- **Production-ready** - Used in real-world environments
- **Zero dependencies** - Only uses standard Linux tools

---

## 🚀 Quick Start

```bash
# Clone or download the scripts
cd ~
mkdir sysadmin-tools
cd sysadmin-tools

# Download all scripts (or copy them manually)
# Then make them executable
chmod +x *.sh

# Run a quick health check
./check-system.sh

# Run the full daily report
./daily-report.sh
```

---

## 📚 Scripts Overview

| Script | Description | Use Case |
|--------|-------------|----------|
| **daily-report.sh** | Master wrapper - runs all checks | Daily morning report |
| **check-system.sh** | CPU, memory, load, uptime | Quick health check |
| **check-disk.sh** | Disk space, inodes, large files | Storage monitoring |
| **check-load.sh** | Detailed CPU & load stats | Performance analysis |
| **check-services.sh** | Service status | Verify critical services |
| **check-network.sh** | Connectivity, DNS, interfaces | Network troubleshooting |
| **check-ports.sh** | Open ports & listening services | Security audit |
| **check-security.sh** | Failed logins, user audit | Security monitoring |
| **check-users.sh** | User accounts, sudoers, logins | User management |
| **check-failed-logins.sh** | SSH attack analysis | Security incident response |
| **check-cron.sh** | Cron job status | Scheduled task monitoring |
| **check-logs.sh** | Error log analysis | Troubleshooting |
| **check-ssl.sh** | Certificate expiry | SSL certificate monitoring |
| **check-backups.sh** | Backup status | Backup verification |
| **check-updates.sh** | Available updates | Patch management |
| **cleanup-system.sh** | Temp files, caches, logs | System maintenance |

---

## 🔧 Installation

### Option 1: Manual Installation

```bash
# Create directory
mkdir -p ~/sysadmin-tools
cd ~/sysadmin-tools

# Create each script file (copy content from this README)
# ... or download from repository ...

# Make executable
chmod +x *.sh
```

### Option 2: One-Line Setup (if scripts are in a repository)

```bash
git clone https://github.com/yourusername/sysadmin-tools.git ~/sysadmin-tools
cd ~/sysadmin-tools
chmod +x *.sh
```

### Option 3: Quick Alias Setup

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# SysAdmin Tools Aliases
alias health='~/sysadmin-tools/check-system.sh'
alias disk='~/sysadmin-tools/check-disk.sh'
alias services='~/sysadmin-tools/check-services.sh'
alias security='~/sysadmin-tools/check-security.sh'
alias backup='~/sysadmin-tools/check-backups.sh'
alias ssl='~/sysadmin-tools/check-ssl.sh'
alias cleanup='~/sysadmin-tools/cleanup-system.sh --dry-run'
alias clean='~/sysadmin-tools/cleanup-system.sh'
alias daily='~/sysadmin-tools/daily-report.sh'
```

Then reload: `source ~/.bashrc`

---

## 💡 Usage Examples

### Basic Usage

```bash
# Quick health check
./check-system.sh

# Check disk space
./check-disk.sh

# Check specific domain SSL
./check-ssl.sh google.com

# Check SSL on custom port
./check-ssl.sh api.example.com 8443
```

### Advanced Usage

```bash
# Full daily report
./daily-report.sh

# Quick report (skips time-consuming checks)
./daily-report.sh --quick

# Report with email notification
./daily-report.sh --email

# Save report to custom location
./daily-report.sh --output /var/log/reports/daily.txt

# Cleanup with dry-run (see what would be deleted)
./cleanup-system.sh --dry-run

# Aggressive cleanup (removes older logs)
./cleanup-system.sh --aggressive

# Check logs from last 48 hours
./check-logs.sh --hours 48
```

### Combined Commands

```bash
# Check everything and email the report
./daily-report.sh --email

# Quick health check and save to file
./daily-report.sh --quick --output /tmp/health.txt

# Check disk and security together
./check-disk.sh && ./check-security.sh
```

---

## ⏰ Cron Setup

### Daily Morning Report (8:00 AM)

```bash
# Edit crontab
crontab -e

# Add this line
0 8 * * * /home/username/sysadmin-tools/daily-report.sh --email --output /var/log/daily-report-$(date +\%Y\%m\%d).txt
```

### Hourly Quick Check

```bash
# Every hour at minute 15
15 * * * * /home/username/sysadmin-tools/check-system.sh > /dev/null 2>&1
```

### Weekly Cleanup (Sunday at 2 AM)

```bash
0 2 * * 0 /home/username/sysadmin-tools/cleanup-system.sh --aggressive
```

### SSL Certificate Check (Daily at 9 AM)

```bash
0 9 * * * /home/username/sysadmin-tools/check-ssl.sh | grep -q "CRITICAL\|EXPIRED" && mail -s "SSL Alert" admin@example.com
```

---

## 📖 Script Details

### 1. `daily-report.sh` - Master Wrapper
Runs all other scripts and generates a comprehensive report.

**Options:**
- `--quick` - Skip time-consuming checks (backups, SSL, updates)
- `--email` - Send report via email
- `--output FILE` - Save report to custom file

**Example:** `./daily-report.sh --quick --email`

---

### 2. `check-system.sh` - System Health
Displays uptime, load average, memory usage, and top processes.

**Output includes:**
- System uptime and kernel version
- Load average vs CPU cores
- Memory usage with warning thresholds
- OOM killer events
- Top 5 CPU and memory consuming processes

---

### 3. `check-disk.sh` - Storage Monitoring
Shows disk usage, inode usage, and large files.

**Output includes:**
- Partition usage with warnings at 70% and 85%
- Inode usage warnings
- Top 5 largest directories
- Files > 500MB

---

### 4. `check-services.sh` - Service Status
Checks common system services.

**Services checked:**
- SSH/SSHD
- Web servers (nginx, apache, httpd)
- Databases (mysql, postgresql)
- Docker, Kubernetes
- Cron, syslog, firewall
- Fail2ban, Prometheus, Grafana

---

### 5. `check-ssl.sh` - Certificate Monitoring
Checks SSL/TLS certificate expiration.

**Features:**
- Check local certificate files
- Check remote domains: `./check-ssl.sh example.com`
- Check custom port: `./check-ssl.sh example.com 8443`
- Shows days remaining with color coding

**Locations scanned:**
- `/etc/ssl/certs`
- `/etc/letsencrypt/live`
- `/etc/pki/tls/certs`
- Web server configurations

---

### 6. `cleanup-system.sh` - System Maintenance
Safely removes temporary files and caches.

**Options:**
- `--dry-run` - Preview what would be deleted
- `--aggressive` - Remove older logs and more files

**What it cleans:**
- `/tmp` and `/var/tmp` files older than 3 days
- Package manager cache (apt/dnf/yum)
- User trash directories
- Core dumps
- (Aggressive) Logs older than 30 days

---

### 7. `check-security.sh` - Security Audit
Comprehensive security checks.

**Checks:**
- Failed SSH login attempts (last 24h)
- Users with UID 0 (root privileges)
- Users with empty passwords
- Recent sudo attempts
- Kernel vulnerability warnings

---

### 8. `check-network.sh` - Network Status
Network connectivity and performance.

**Checks:**
- Network interfaces and IPs
- Default gateway
- DNS servers
- Internet connectivity (8.8.8.8)
- DNS resolution
- Packet loss to gateway

---

### 9. `check-ports.sh` - Open Ports
Lists listening ports and services.

**Output includes:**
- TCP ports with service names
- UDP ports
- Common service status (SSH, HTTP, MySQL, etc.)

---

### 10. `check-backups.sh` - Backup Verification
Checks backup status and integrity.

**Checks:**
- Common backup directories
- Latest backup age
- Backup tools installed
- Recent backup errors in logs

---

### 11. `check-cron.sh` - Cron Jobs
Monitors scheduled tasks.

**Output includes:**
- Cron service status
- System and user crontabs
- Jobs scheduled to run daily
- Recent cron logs

---

### 12. `check-logs.sh` - Log Analysis
Analyzes system logs for errors.

**Options:**
- `--hours N` - Check last N hours (default 24)

**Checks:**
- Systemd journal errors and warnings
- Syslog errors
- Application logs (Nginx, Apache, MySQL, PostgreSQL)
- Log rotation status

---

### 13. `check-load.sh` - CPU Monitoring
Detailed CPU and load analysis.

**Output includes:**
- CPU information (cores, model, speed)
- Load average with percentage of capacity
- Top CPU-consuming processes
- System CPU statistics
- Process counts with zombie detection

---

### 14. `check-failed-logins.sh` - Attack Analysis
Analyzes failed login attempts.

**Checks:**
- Failed SSH attempts count
- Invalid username attempts
- Top attacking IPs
- Recent failures
- Fail2ban status
- SSH configuration hardening

---

### 15. `check-users.sh` - User Audit
Audits user accounts and activity.

**Output includes:**
- Total users and users with shells
- System users with shell access
- Recent and current logins
- Users with root privileges (sudoers)
- Last password changes

---

### 16. `check-updates.sh` - Patch Management
Checks for available system updates.

**Features:**
- Detects package manager (apt/dnf/yum)
- Shows number of available updates
- Highlights security updates
- Shows kernel updates requiring reboot

---

## 💪 Tips & Tricks

### Create a Dashboard

```bash
# Create a custom dashboard script
cat > ~/dashboard.sh << 'EOF'
#!/bin/bash
clear
echo "╔════════════════════════════════════════════════╗"
echo "║              SYSTEM DASHBOARD                  ║"
echo "╠════════════════════════════════════════════════╣"
./check-system.sh | head -20
echo "╠════════════════════════════════════════════════╣"
./check-disk.sh | head -10
echo "╠════════════════════════════════════════════════╣"
./check-services.sh | head -10
echo "╚════════════════════════════════════════════════╝"
EOF
chmod +x ~/dashboard.sh
```

### Quick Server Status

```bash
# One-liner status
echo "Load: $(uptime | awk -F'load average:' '{print $2}') | Disk: $(df -h / | tail -1 | awk '{print $5}') | Services: $(systemctl --failed | wc -l) failed"
```

### Monitor with Watch

```bash
# Update every 5 seconds
watch -n 5 ./check-system.sh

# Update every 2 seconds
watch -n 2 ./check-services.sh
```

### Email Alerts for Critical Issues

```bash
# Alert if disk > 90%
./check-disk.sh | grep -q "90%" && echo "Disk alert!" | mail -s "Disk Warning" admin@example.com
```

---

## 🛠 Troubleshooting

### Permission Issues

Some scripts require root privileges for full functionality:

```bash
# Run with sudo when needed
sudo ./check-users.sh
sudo ./cleanup-system.sh
```

### Missing Commands

If a script reports a missing command:

```bash
# Ubuntu/Debian
sudo apt install util-linux sysstat net-tools

# RHEL/CentOS/Fedora
sudo dnf install util-linux sysstat net-tools
```

### Script Not Executable

```bash
chmod +x scriptname.sh
```

### Color Codes Not Showing

Some terminals may not support color codes. Remove the color definitions or set:

```bash
export TERM=xterm-256color
```

---

## 🎨 Customization

### Changing Warning Thresholds

Edit the script variables directly:

```bash
# In check-disk.sh
DISK_WARNING=85  # Change to 90 for less strict
INODE_WARNING=85
```

### Adding Custom Services

In `check-services.sh`, add to the services array:

```bash
services=(
    # ... existing services ...
    "your-custom-service"
    "another-service"
)
```

### Custom Backup Directories

In `check-backups.sh`, modify the backup_dirs array:

```bash
backup_dirs=(
    "/backup"
    "/var/backups"
    "/mnt/nas/backups"  # Add your custom path
)
```

---

## 📝 License

MIT License - Free to use, modify, and distribute.

---

## 🤝 Contributing

Feel free to:
- Report bugs
- Suggest improvements
- Add new scripts
- Share your customizations

---

## 📞 Support

For issues:
1. Check the troubleshooting section
2. Run scripts with `--help` for options
3. Ensure all dependencies are installed

---

## 📊 Sample Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SYSTEM HEALTH CHECK - myserver
  2024-01-15 08:30:00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▶ UPTIME
 08:30:00 up 45 days,  3:12,  2 users,  load average: 0.08, 0.03, 0.01
Kernel: 5.15.0-91-generic
OS: Ubuntu 22.04.3 LTS

▶ LOAD AVERAGE
Load: 0.08, 0.03, 0.01 (Cores: 8)
✅ Load is normal

▶ MEMORY
              total        used        free      shared  buff/cache   available
Mem:           15Gi       2.3Gi        10Gi       245Mi       2.6Gi        12Gi
✅ Memory usage: 15%
─────────────────────────────────────────────────
```

---

## 🏁 Final Notes

- **All scripts are designed to be non-destructive** (except cleanup with proper flags)
- **Always test in a non-production environment first**
- **Review scripts before running with sudo**
- **Keep scripts updated for security fixes**
- **Share feedback and improvements**

---

**Happy SysAdmin-ing! 🐧🔧**
