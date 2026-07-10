#!/usr/bin/env bash
# check-ports.sh - Check open ports and listening services
# Usage: ./check-ports.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  OPEN PORTS - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}▶ LISTENING PORTS (TCP)${NC}"
if command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep LISTEN | while read -r line; do
        port=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
        service=$(echo "$line" | grep -o 'users:(([^,)]*' | sed 's/users:(("//g' | sed 's/",.*//g')
        echo "  Port $port: $service"
    done
elif command -v netstat &>/dev/null; then
    netstat -tlnp 2>/dev/null | grep LISTEN | while read -r line; do
        port=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
        service=$(echo "$line" | awk '{print $7}' | cut -d/ -f2)
        echo "  Port $port: $service"
    done
else
    echo "  Neither ss nor netstat available"
fi

# UDP ports
echo -e "\n${GREEN}▶ LISTENING PORTS (UDP)${NC}"
if command -v ss &>/dev/null; then
    ss -ulnp 2>/dev/null | grep UNCONN | while read -r line; do
        port=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
        service=$(echo "$line" | grep -o 'users:(([^,)]*' | sed 's/users:(("//g' | sed 's/",.*//g')
        echo "  Port $port: $service"
    done
fi

# Check for common services
echo -e "\n${GREEN}▶ COMMON SERVICES STATUS${NC}"
common_ports=("22:SSH" "80:HTTP" "443:HTTPS" "3306:MySQL" "5432:PostgreSQL" "6379:Redis" "27017:MongoDB" "8080:Tomcat" "9090:Prometheus" "3000:Grafana" "6443:K8s-API" "10250:K8s-Kubelet")
for entry in "${common_ports[@]}"; do
    port="${entry%:*}"
    name="${entry#*:}"
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        echo -e "  ${GREEN}✅${NC} $name (port $port) - listening"
    else
        echo -e "  ${YELLOW}⚠️${NC}  $name (port $port) - not listening"
    fi
done

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
