#!/usr/bin/env bash
# check-system.sh - Comprehensive system health check
# Usage: ./check-system.sh [--quick]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SYSTEM HEALTH CHECK - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Uptime
echo -e "\n${GREEN}▶ UPTIME${NC}"
uptime
echo "Kernel: $(uname -r)"
echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "Unknown")"

# Load average
echo -e "\n${GREEN}▶ LOAD AVERAGE${NC}"
load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
cores=$(nproc)
echo "Load: $load (Cores: $cores)"
load_num=$(echo "$load" | cut -d',' -f1 | xargs | cut -d'.' -f1)
if [[ $load_num -gt $((cores * 2)) ]]; then
    echo -e "${RED}⚠️  High load detected!${NC}"
else
    echo -e "${GREEN}✅ Load is normal${NC}"
fi

# Memory
echo -e "\n${GREEN}▶ MEMORY${NC}"
free -h
mem_total=$(free -m | awk 'NR==2{print $2}')
mem_used=$(free -m | awk 'NR==2{print $3}')
mem_percent=$((mem_used * 100 / mem_total))
if [[ $mem_percent -gt 90 ]]; then
    echo -e "${RED}⚠️  Memory usage: ${mem_percent}% (Critical!)${NC}"
elif [[ $mem_percent -gt 75 ]]; then
    echo -e "${YELLOW}⚠️  Memory usage: ${mem_percent}% (High)${NC}"
else
    echo -e "${GREEN}✅ Memory usage: ${mem_percent}%${NC}"
fi

# Check for OOM
if dmesg 2>/dev/null | grep -q "Out of memory" || journalctl -k 2>/dev/null | grep -q "Out of memory"; then
    echo -e "${RED}⚠️  OOM Killer has been triggered!${NC}"
fi

# Processes
echo -e "\n${GREEN}▶ TOP 5 CPU CONSUMERS${NC}"
ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -6

echo -e "\n${GREEN}▶ TOP 5 MEMORY CONSUMERS${NC}"
ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%mem | head -6

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
