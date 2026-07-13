#!/usr/bin/env bash
# check-disk.sh - Safe disk monitoring
# Usage: ./check-disk.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
EXIT_CODE=0

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  DISK USAGE REPORT - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Disk space - physical devices only
echo -e "\n${GREEN}▶ DISK SPACE${NC}"
df -h | grep -E '^/dev/' | while read -r line; do
    echo "$line"
    usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    if [[ -n "$usage" && "$usage" -gt 85 ]]; then
        echo -e "${RED}  ⚠️  Partition is ${usage}% full!${NC}"
        EXIT_CODE=1
    elif [[ -n "$usage" && "$usage" -gt 70 ]]; then
        echo -e "${YELLOW}  ⚠️  Partition is ${usage}% full${NC}"
    fi
done

# Inodes - physical only
echo -e "\n${GREEN}▶ INODE USAGE${NC}"
df -i | grep -E '^/dev/' | while read -r line; do
    echo "$line"
    inode_usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    if [[ -n "$inode_usage" && "$inode_usage" -gt 85 ]]; then
        echo -e "${RED}  ⚠️  Inodes are ${inode_usage}% full!${NC}"
        EXIT_CODE=1
    fi
done

# Largest directories (exclude virtual filesystems)
echo -e "\n${GREEN}▶ LARGEST DIRECTORIES (top 5)${NC}"
timeout 30s du -h --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --max-depth=3 / 2>/dev/null | sort -rh | head -5 || echo "  Scan timed out (30s limit)"

# Large files (safe find)
echo -e "\n${GREEN}▶ LARGE FILES (>500MB)${NC}"
timeout 20s find / -type f -size +500M \
    -not -path "/proc/*" \
    -not -path "/sys/*" \
    -not -path "/dev/*" \
    -not -path "/run/*" \
    -not -path "/tmp/*" 2>/dev/null \
    -exec du -h {} \; 2>/dev/null | sort -rh | head -10 || echo "  No large files found or scan timed out"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Show actual root usage summary
echo -e "\n${BLUE}▶ QUICK SUMMARY${NC}"
echo "  $(df -h / | tail -1 | awk '{print $5}') of root disk used"
echo "  $(df -i / | tail -1 | awk '{print $5}') of root inodes used"

exit $EXIT_CODE
