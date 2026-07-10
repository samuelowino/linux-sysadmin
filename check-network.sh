#!/usr/bin/env bash
# check-network.sh - Network connectivity and performance
# Usage: ./check-network.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  NETWORK STATUS - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Interface status
echo -e "\n${GREEN}▶ NETWORK INTERFACES${NC}"
ip addr show 2>/dev/null | grep -E "^[0-9]|inet " | grep -v "127.0.0.1" | while read -r line; do
    if [[ "$line" =~ ^[0-9] ]]; then
        echo "  $line"
    elif [[ "$line" =~ inet[[:space:]] ]]; then
        echo "    $line"
    fi
done

# Default gateway
echo -e "\n${GREEN}▶ DEFAULT GATEWAY${NC}"
ip route | grep default | head -1 || echo "  No default gateway found"

# DNS Servers
echo -e "\n${GREEN}▶ DNS SERVERS${NC}"
cat /etc/resolv.conf 2>/dev/null | grep nameserver | sed 's/^/  /'

# Connectivity test
echo -e "\n${GREEN}▶ EXTERNAL CONNECTIVITY${NC}"
if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✅ Internet connectivity: OK${NC}"
else
    echo -e "${RED}❌ Cannot reach internet (8.8.8.8)${NC}"
fi

# DNS resolution test
echo -e "\n${GREEN}▶ DNS RESOLUTION${NC}"
if nslookup google.com &>/dev/null; then
    echo -e "${GREEN}✅ DNS resolution: OK${NC}"
else
    echo -e "${RED}❌ DNS resolution failed${NC}"
fi

# Network stats
echo -e "\n${GREEN}▶ NETWORK STATISTICS${NC}"
if command -v ss &>/dev/null; then
    connections=$(ss -tulpn 2>/dev/null | wc -l)
    echo "  Active connections: $((connections - 1))"
else
    echo "  ss command not available"
fi

# Packet loss
echo -e "\n${GREEN}▶ PACKET LOSS (to gateway)${NC}"
gateway=$(ip route | grep default | awk '{print $3}')
if [[ -n "$gateway" ]]; then
    if ping -c 5 -W 1 "$gateway" 2>/dev/null | grep -q "packet loss"; then
        loss=$(ping -c 5 -W 1 "$gateway" 2>/dev/null | grep "packet loss" | awk '{print $6}')
        echo "  Loss to gateway: $loss"
    fi
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
