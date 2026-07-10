#!/usr/bin/env bash
# check-load.sh - Detailed CPU and load monitoring
# Usage: ./check-load.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  CPU & LOAD MONITOR - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}▶ CPU INFORMATION${NC}"
echo "  Cores: $(nproc)"
echo "  Architecture: $(uname -m)"
if command -v lscpu &>/dev/null; then
    lscpu | grep -E "Model name|CPU MHz|BogoMIPS" | sed 's/^/  /'
fi

echo -e "\n${GREEN}▶ CURRENT LOAD AVERAGE${NC}"
load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
cores=$(nproc)
echo -e "  Load: $load"
echo -e "  Cores: $cores"

# Calculate load as percentage of cores
load1=$(echo "$load" | cut -d',' -f1 | xargs)
load1_num=$(echo "$load1" | cut -d'.' -f1)
if [[ -n "$load1_num" ]]; then
    percent=$((load1_num * 100 / cores))
    if [[ $percent -gt 80 ]]; then
        echo -e "  ${RED}⚠️  Load is at ${percent}% of capacity!${NC}"
    elif [[ $percent -gt 50 ]]; then
        echo -e "  ${YELLOW}⚠️  Load is at ${percent}% of capacity${NC}"
    else
        echo -e "  ${GREEN}✅ Load is at ${percent}% of capacity${NC}"
    fi
fi

echo -e "\n${GREEN}▶ CPU USAGE (top 5 processes)${NC}"
ps -eo pid,ppid,user,cmd,%cpu --sort=-%cpu | head -6 | column -t

echo -e "\n${GREEN}▶ SYSTEM CPU STATISTICS${NC}"
if command -v mpstat &>/dev/null; then
    mpstat 1 3 2>/dev/null | tail -5 | sed 's/^/  /'
else
    echo "  (mpstat not installed - install sysstat package)"
    echo "  Overall usage:"
    top -bn1 | grep "Cpu(s)" | sed 's/^/  /'
fi

echo -e "\n${GREEN}▶ PROCESS COUNT${NC}"
echo "  Total processes: $(ps aux | wc -l)"
echo "  Running processes: $(ps aux | grep -c " R " || echo "0")"
echo "  Sleeping processes: $(ps aux | grep -c " S " || echo "0")"
echo "  Zombie processes: $(ps aux | grep -c " Z " || echo "0")"

zombies=$(ps aux | grep -c " Z " || echo "0")
if [[ $zombies -gt 5 ]]; then
    echo -e "  ${RED}⚠️  High number of zombie processes: $zombies${NC}"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
