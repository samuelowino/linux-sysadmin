#!/usr/bin/env bash
# check-logs.sh - Analyze recent system logs for errors
# Usage: ./check-logs.sh [--hours 24]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
HOURS=24
while [[ $# -gt 0 ]]; do
    case $1 in
        --hours) HOURS="$2"; shift 2 ;;
        --help) echo "Usage: $0 [--hours N]"; exit 0 ;;
        *) echo "Unknown option"; exit 1 ;;
    esac
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  LOG ANALYSIS (last $HOURS hours) - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Function to check journalctl
check_journal() {
    echo -e "\n${GREEN}▶ SYSTEMD JOURNAL ERRORS${NC}"
    if command -v journalctl &>/dev/null; then
        # Errors
        errors=$(journalctl --since "${HOURS}h ago" -p 3 -n 50 2>/dev/null | wc -l)
        echo "  Errors (priority 3): $errors"
        if [[ $errors -gt 0 ]]; then
            echo "  Recent errors:"
            journalctl --since "${HOURS}h ago" -p 3 -n 10 2>/dev/null | sed 's/^/    /'
        fi
        
        # Warnings
        warnings=$(journalctl --since "${HOURS}h ago" -p 4 -n 50 2>/dev/null | wc -l)
        echo "  Warnings (priority 4): $warnings"
        if [[ $warnings -gt 0 ]]; then
            echo "  Recent warnings:"
            journalctl --since "${HOURS}h ago" -p 4 -n 5 2>/dev/null | sed 's/^/    /'
        fi
    else
        echo "  journalctl not available"
    fi
}

# Function to check syslog
check_syslog() {
    echo -e "\n${GREEN}▶ SYSLOG ERRORS${NC}"
    
    syslog_files=("/var/log/syslog" "/var/log/messages" "/var/log/system.log")
    
    for log in "${syslog_files[@]}"; do
        if [[ -f "$log" ]]; then
            echo "  Checking: $log"
            errors=$(grep -i "error\|fail\|crit\|emerg" "$log" 2>/dev/null | tail -10 | wc -l)
            echo "  Recent errors: $errors"
            if [[ $errors -gt 0 ]]; then
                grep -i "error\|fail\|crit\|emerg" "$log" 2>/dev/null | tail -5 | sed 's/^/      /'
            fi
        fi
    done
}

# Check specific application logs
check_app_logs() {
    echo -e "\n${GREEN}▶ APPLICATION LOGS${NC}"
    
    # Nginx
    if [[ -f /var/log/nginx/error.log ]]; then
        errors=$(tail -50 /var/log/nginx/error.log 2>/dev/null | grep -c "error")
        echo "  Nginx errors (last 50 lines): $errors"
        tail -10 /var/log/nginx/error.log 2>/dev/null | sed 's/^/    /'
    fi
    
    # Apache
    if [[ -f /var/log/apache2/error.log ]]; then
        errors=$(tail -50 /var/log/apache2/error.log 2>/dev/null | grep -c "error")
        echo "  Apache errors (last 50 lines): $errors"
        tail -10 /var/log/apache2/error.log 2>/dev/null | sed 's/^/    /'
    fi
    
    # MySQL/MariaDB
    if [[ -f /var/log/mysql/error.log ]]; then
        errors=$(tail -50 /var/log/mysql/error.log 2>/dev/null | grep -c -i "error")
        echo "  MySQL errors (last 50 lines): $errors"
        tail -5 /var/log/mysql/error.log 2>/dev/null | sed 's/^/    /'
    fi
    
    # PostgreSQL
    if [[ -d /var/log/postgresql ]]; then
        latest=$(ls -t /var/log/postgresql/*.log 2>/dev/null | head -1)
        if [[ -f "$latest" ]]; then
            errors=$(tail -50 "$latest" 2>/dev/null | grep -c -i "error")
            echo "  PostgreSQL errors (last 50 lines): $errors"
            tail -5 "$latest" 2>/dev/null | sed 's/^/    /'
        fi
    fi
}

# Check log rotation
check_logrotate() {
    echo -e "\n${GREEN}▶ LOG ROTATION STATUS${NC}"
    
    if command -v logrotate &>/dev/null; then
        echo -e "  ${GREEN}✅ logrotate is installed${NC}"
        
        # Check last logrotate run
        if [[ -f /var/lib/logrotate/status ]]; then
            echo "  Last rotations:"
            tail -5 /var/lib/logrotate/status 2>/dev/null | sed 's/^/    /'
        fi
    else
        echo -e "  ${YELLOW}⚠️  logrotate not installed${NC}"
    fi
    
    # Check for large log files
    echo "  Large log files (>100MB):"
    find /var/log -type f -size +100M 2>/dev/null | while read -r f; do
        echo "    $(du -h "$f" 2>/dev/null | cut -f1) - $(basename "$f")"
    done || echo "    None"
}

# Run all checks
check_journal
check_syslog
check_app_logs
check_logrotate

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
