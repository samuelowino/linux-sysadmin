#!/usr/bin/env bash
# check-cron.sh - Check cron jobs and scheduled tasks
# Usage: ./check-cron.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  CRON JOB STATUS - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}▶ CRON SERVICE STATUS${NC}"
if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
    echo -e "  ${GREEN}✅ Cron service is running${NC}"
else
    echo -e "  ${RED}❌ Cron service is NOT running!${NC}"
    echo "  Start with: sudo systemctl start cron"
fi

echo -e "\n${GREEN}▶ SYSTEM CRONJOBS${NC}"
if [[ -f /etc/crontab ]]; then
    echo "  /etc/crontab:"
    grep -v "^#" /etc/crontab | grep -v "^$" | sed 's/^/    /'
fi

echo -e "\n${GREEN}▶ USER CRONJOBS${NC}"
user_count=0
for user in $(cut -d: -f1 /etc/passwd); do
    if crontab -u "$user" -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep -q .; then
        user_count=$((user_count + 1))
        echo "  $user:"
        crontab -u "$user" -l 2>/dev/null | grep -v "^#" | grep -v "^$" | sed 's/^/      /'
    fi
done

if [[ $user_count -eq 0 ]]; then
    echo "  No users have cron jobs configured"
else
    echo "  Total users with cron jobs: $user_count"
fi

echo -e "\n${GREEN}▶ DAILY CRONJOBS (scheduled to run today)${NC}"
# Show cron entries that run daily
for user in $(cut -d: -f1 /etc/passwd); do
    crontab -u "$user" -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep -E "@daily|@hourly|0\s+[0-9]" | sed "s/^/  $user: /" || true
done

echo -e "\n${GREEN}▶ CRON LOG (last 24h)${NC}"
if [[ -f /var/log/syslog ]]; then
    grep -i cron /var/log/syslog 2>/dev/null | tail -10 | sed 's/^/  /'
elif [[ -f /var/log/messages ]]; then
    grep -i cron /var/log/messages 2>/dev/null | tail -10 | sed 's/^/  /'
else
    echo "  No cron logs found"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
