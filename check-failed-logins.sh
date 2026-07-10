#!/usr/bin/env bash
# check-failed-logins.sh - Analyze failed login attempts
# Usage: ./check-failed-logins.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FAILED LOGIN ANALYSIS - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}▶ FAILED LOGIN ATTEMPTS${NC}"

# Check various log files
auth_logs=("/var/log/auth.log" "/var/log/secure" "/var/log/messages")

for log in "${auth_logs[@]}"; do
    if [[ -f "$log" ]]; then
        echo -e "\n  Checking: $log"
        
        # Failed SSH attempts
        failed_ssh=$(grep -c "Failed password" "$log" 2>/dev/null || echo "0")
        echo "  SSH failures: $failed_ssh"
        
        # Invalid users
        invalid_users=$(grep -c "Invalid user" "$log" 2>/dev/null || echo "0")
        echo "  Invalid usernames: $invalid_users"
        
        # Top offending IPs
        echo "  Top 5 attacking IPs (SSH):"
        grep "Failed password" "$log" 2>/dev/null | awk '{print $NF}' | sort | uniq -c | sort -rn | head -5 | sed 's/^/      /'
        
        # Recent failures
        echo "  Recent failures (last 5):"
        grep "Failed password" "$log" 2>/dev/null | tail -5 | sed 's/^/      /'
    fi
done

# Check if fail2ban is running
echo -e "\n${GREEN}▶ FAIL2BAN STATUS${NC}"
if command -v fail2ban-client &>/dev/null; then
    status=$(sudo fail2ban-client status 2>/dev/null || echo "not running")
    if [[ "$status" != "not running" ]]; then
        echo -e "  ${GREEN}✅ fail2ban is running${NC}"
        echo "  Jails:"
        sudo fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/^/    /'
    else
        echo -e "  ${YELLOW}⚠️  fail2ban is not running${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  fail2ban not installed${NC}"
fi

echo -e "\n${GREEN}▶ SSH CONFIGURATION${NC}"
if [[ -f /etc/ssh/sshd_config ]]; then
    echo "  PasswordAuthentication: $(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "not set")"
    echo "  PermitRootLogin: $(grep -i "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "not set")"
    echo "  Port: $(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")"
fi

# Summary
echo -e "\n${GREEN}▶ SUMMARY${NC}"
total_failed=0
for log in "${auth_logs[@]}"; do
    if [[ -f "$log" ]]; then
        count=$(grep -c "Failed password" "$log" 2>/dev/null || echo "0")
        total_failed=$((total_failed + count))
    fi
done

if [[ $total_failed -gt 100 ]]; then
    echo -e "  ${RED}⚠️  HIGH: $total_failed total failed attempts${NC}"
    echo "  Consider:"
    echo "    - Implement fail2ban"
    echo "    - Disable password authentication"
    echo "    - Change SSH port"
elif [[ $total_failed -gt 10 ]]; then
    echo -e "  ${YELLOW}⚠️  $total_failed total failed attempts${NC}"
else
    echo -e "  ${GREEN}✅ $total_failed total failed attempts${NC}"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
