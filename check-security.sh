#!/usr/bin/env bash
# check-security.sh - Security audit and vulnerability checks
# Usage: ./check-security.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SECURITY AUDIT - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Failed SSH logins
echo -e "\n${GREEN}▶ FAILED SSH LOGINS (last 24h)${NC}"
if command -v lastb &>/dev/null; then
    count=$(lastb 2>/dev/null | head -20 | wc -l)
    if [[ $count -gt 0 ]]; then
        echo -e "${RED}⚠️  $count failed login attempts in last 24h${NC}"
        lastb 2>/dev/null | head -10 | awk '{print "  " $1 " from " $3}'
    else
        echo -e "${GREEN}✅ No failed logins found${NC}"
    fi
else
    echo "  lastb command not available"
fi

# Suspicious users
echo -e "\n${GREEN}▶ USER ACCOUNT AUDIT${NC}"
# Users with UID 0
root_users=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
if [[ "$root_users" != "root" ]]; then
    echo -e "${RED}⚠️  Multiple users with UID 0: $root_users${NC}"
else
    echo -e "${GREEN}✅ Only root has UID 0${NC}"
fi

# Users with empty passwords (requires root)
if [[ $EUID -eq 0 ]]; then
    empty_pass=$(awk -F: '($2 == "" || $2 == "*") {print $1}' /etc/shadow 2>/dev/null | head -5)
    if [[ -n "$empty_pass" ]]; then
        echo -e "${RED}⚠️  Users with weak passwords: $empty_pass${NC}"
    fi
fi

# Recent sudo attempts
echo -e "\n${GREEN}▶ SUDO ATTEMPTS (last 24h)${NC}"
if [[ -f /var/log/auth.log ]]; then
    grep "sudo" /var/log/auth.log 2>/dev/null | tail -5 | sed 's/^/  /'
elif [[ -f /var/log/secure ]]; then
    grep "sudo" /var/log/secure 2>/dev/null | tail -5 | sed 's/^/  /'
fi

# Kernel vulnerabilities
echo -e "\n${GREEN}▶ KNOWN VULNERABILITIES${NC}"
if [[ -f /proc/version ]]; then
    if grep -q "Ubuntu" /proc/version 2>/dev/null; then
        echo "  Ubuntu: Run 'sudo apt update && sudo apt upgrade' for security patches"
    elif grep -q "Red Hat" /proc/version 2>/dev/null; then
        echo "  RHEL: Run 'sudo yum update --security' for security patches"
    fi
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
