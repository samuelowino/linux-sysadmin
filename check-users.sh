#!/usr/bin/env bash
# check-users.sh - Audit user accounts and activity
# Usage: ./check-users.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  USER AUDIT - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}▶ USER ACCOUNTS${NC}"
echo "  Total users: $(wc -l < /etc/passwd)"
echo "  Users with shells: $(grep -c -E "/(bash|sh|zsh|fish)$" /etc/passwd)"

echo -e "\n${GREEN}▶ SYSTEM USERS WITH SHELL ACCESS${NC}"
awk -F: '($3 < 1000 && $7 ~ /bash|sh|zsh|fish/) {print "  " $1 " (UID: " $3 ")"}' /etc/passwd | head -10
if [[ $(awk -F: '($3 < 1000 && $7 ~ /bash|sh|zsh|fish/)' /etc/passwd | wc -l) -gt 10 ]]; then
    echo "  ... and more"
fi

echo -e "\n${GREEN}▶ RECENT LOGINS (last 10)${NC}"
last -n 10 2>/dev/null | head -10 | sed 's/^/  /'

echo -e "\n${GREEN}▶ CURRENTLY LOGGED IN${NC}"
who | sed 's/^/  /'

echo -e "\n${GREEN}▶ USERS WITH ROOT PRIVILEGES${NC}"
if [[ -f /etc/sudoers ]]; then
    grep -v "^#" /etc/sudoers 2>/dev/null | grep -v "^$" | grep -E "ALL|NOPASSWD" | sed 's/^/  /' || true
fi

# Check sudoers.d directory
if [[ -d /etc/sudoers.d ]]; then
    for sudo_file in /etc/sudoers.d/*; do
        [[ -f "$sudo_file" ]] || continue
        grep -v "^#" "$sudo_file" 2>/dev/null | grep -v "^$" | grep -E "ALL|NOPASSWD" | sed 's/^/  /' || true
    done
fi

echo -e "\n${GREEN}▶ LAST PASSWORD CHANGES${NC}"
if [[ -f /etc/shadow ]] && [[ $EUID -eq 0 ]]; then
    echo "  (last 5 users)"
    awk -F: '{print $1, $3}' /etc/shadow 2>/dev/null | sort -k2 -n | tail -5 | while read -r user last_change; do
        if [[ "$last_change" != "" ]] && [[ "$last_change" != "*" ]]; then
            date_epoch=$((last_change * 86400))
            change_date=$(date -d "@$date_epoch" "+%Y-%m-%d" 2>/dev/null || echo "unknown")
            echo "    $user: $change_date"
        fi
    done
else
    echo "  (requires root to view /etc/shadow)"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
