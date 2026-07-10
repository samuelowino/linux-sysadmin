#!/usr/bin/env bash
# daily_check.sh - Master script that runs all daily tasks
# Usage: ./daily_check.sh [--quick] [--email]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="${SCRIPT_DIR}/modules"
CONFIG_DIR="${SCRIPT_DIR}/config"
LOG_FILE="${SCRIPT_DIR}/logs/daily_check_$(date +%Y%m%d).log"
REPORT_FILE="${SCRIPT_DIR}/logs/report_$(date +%Y%m%d).txt"

# Source configuration
source "${CONFIG_DIR}/settings.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log and echo
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo -e "$msg" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: $*"
    echo -e "${RED}$msg${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $*"
    echo -e "${GREEN}$msg${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  WARNING: $*"
    echo -e "${YELLOW}$msg${NC}" | tee -a "$LOG_FILE"
}

# Create report header
init_report() {
    {
        echo "=========================================="
        echo "  DAILY SYSTEM REPORT - $(date)"
        echo "  Host: $(hostname)"
        echo "  Kernel: $(uname -r)"
        echo "  Uptime: $(uptime -p)"
        echo "=========================================="
        echo ""
    } > "$REPORT_FILE"
}

# Check if running as root (some tasks need it)
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_warning "Not running as root. Some tasks may fail."
        log_warning "Run with sudo for full functionality."
    fi
}

# Parse arguments
QUICK_MODE=false
SEND_EMAIL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick) QUICK_MODE=true; shift ;;
        --email) SEND_EMAIL=true; shift ;;
        --help) 
            echo "Usage: $0 [--quick] [--email]"
            echo "  --quick  : Skip non-critical checks (disk, SSL, backups)"
            echo "  --email  : Send report via email"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Main execution
main() {
    log "========== STARTING DAILY CHECK =========="
    init_report
    check_privileges

    # Source all module scripts
    for module in "${MODULE_DIR}"/*.sh; do
        # shellcheck source=/dev/null
        source "$module"
    done

    # Run health checks (always run)
    log_success "Running Health Checks..."
    {
        check_system_load
        check_disk_usage
        check_memory_usage
        check_inodes
        check_failed_services
        check_failed_ssh_logins
        check_cron_jobs
    } >> "$REPORT_FILE" 2>&1

    # Run security checks
    log_success "Running Security Checks..."
    {
        check_security_updates
        check_suspicious_users
        check_open_ports
        check_firewall_status
    } >> "$REPORT_FILE" 2>&1

    # Run maintenance tasks (skip if quick mode)
    if [[ "$QUICK_MODE" == false ]]; then
        log_success "Running Maintenance Tasks..."
        {
            rotate_logs
            cleanup_temp_files
            clean_package_cache
        } >> "$REPORT_FILE" 2>&1

        # Verify backups
        log_success "Verifying Backups..."
        {
            verify_backups
        } >> "$REPORT_FILE" 2>&1

        # SSL Certificate checks
        log_success "Checking SSL Certificates..."
        {
            check_ssl_certificates
        } >> "$REPORT_FILE" 2>&1
    else
        log_warning "Quick mode: Skipping maintenance and backup checks."
    fi

    # Append summary
    {
        echo ""
        echo "=========================================="
        echo "  REPORT COMPLETE - $(date)"
        echo "=========================================="
    } >> "$REPORT_FILE"

    log_success "Daily check complete. Report saved to: $REPORT_FILE"

    # Display summary on screen
    echo ""
    echo "========== SUMMARY =========="
    tail -20 "$REPORT_FILE"
    echo "=============================="

    # Send email if requested
    if [[ "$SEND_EMAIL" == true ]]; then
        send_report_via_email
    fi

    log "========== DAILY CHECK COMPLETE =========="
}

# Email function
send_report_via_email() {
    if command -v mail &> /dev/null; then
        local subject="Daily System Report - $(hostname) - $(date +%Y-%m-%d)"
        mail -s "$subject" "$ADMIN_EMAIL" < "$REPORT_FILE"
        log_success "Report sent to $ADMIN_EMAIL"
    else
        log_error "'mail' command not found. Install mailutils or postfix."
    fi
}

# Run main function
main
