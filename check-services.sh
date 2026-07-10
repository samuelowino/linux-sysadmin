#!/usr/bin/env bash
# check-services.sh - Check all critical services
# Usage: ./check-services.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SERVICE STATUS - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Common services to check
services=(
    "ssh"
    "sshd"
    "nginx"
    "apache2"
    "httpd"
    "mysql"
    "mariadb"
    "postgresql"
    "docker"
    "kubelet"
    "cron"
    "crond"
    "rsyslog"
    "systemd-journald"
    "ufw"
    "firewalld"
    "fail2ban"
    "prometheus"
    "grafana-server"
)

echo -e "\n${GREEN}▶ CRITICAL SERVICES${NC}"
found_services=0
failed_services=0

for service in "${services[@]}"; do
    if systemctl list-units --type=service --all 2>/dev/null | grep -q "$service.service"; then
        found_services=$((found_services + 1))
        status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
        if [[ "$status" == "active" ]]; then
            echo -e "  ${GREEN}✅${NC} $service: running"
        elif [[ "$status" == "inactive" ]]; then
            echo -e "  ${YELLOW}⚠️${NC}  $service: stopped (not running)"
        elif [[ "$status" == "failed" ]]; then
            echo -e "  ${RED}❌${NC} $service: FAILED!"
            failed_services=$((failed_services + 1))
        fi
    fi
done

if [[ $failed_services -gt 0 ]]; then
    echo -e "\n${RED}⚠️  $failed_services service(s) are in failed state!${NC}"
    echo "  Run: systemctl --failed"
else
    echo -e "\n${GREEN}✅ All found services are running properly${NC}"
fi

# Show failed services
echo -e "\n${GREEN}▶ ALL FAILED SERVICES${NC}"
systemctl --failed --no-legend 2>/dev/null || echo "  None"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
