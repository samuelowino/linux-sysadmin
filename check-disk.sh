#!/usr/bin/env bash
# check-disk.sh - Check disk usage and inodes
# Usage: ./check-disk.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  DISK USAGE REPORT - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}▶ DISK SPACE${NC}"
df -h | grep -v "tmpfs" | while read -r line; do
    echo "$line"
    usage=$(echo "$line" | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    if [[ -n "$usage" && "$usage" -gt 85 ]]; then
        echo -e "${RED}  ⚠️  Partition is ${usage}% full!${NC}"
    elif [[ -n "$usage" && "$usage" -gt 70 ]]; then
        echo -e "${YELLOW}  ⚠️  Partition is ${usage}% full${NC}"
    fi
done

echo -e "\n${GREEN}▶ INODE USAGE${NC}"
df -i | grep -v "tmpfs" | while read -r line; do
    echo "$line"
    inode_usage=$(echo "$line" | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    if [[ -n "$inode_usage" && "$inode_usage" -gt 85 ]]; then
        echo -e "${RED}  ⚠️  Inodes are ${inode_usage}% full!${NC}"
    fi
done

echo -e "\n${GREEN}▶ LARGEST DIRECTORIES (top 5)${NC}"
du -h / 2>/dev/null | sort -rh | head -5 || echo "  (Need root for full scan)"

echo -e "\n${GREEN}▶ LARGE FILES (>500MB)${NC}"
find / -type f -size +500M 2>/dev/null | head -10 | while read -r f; do
    echo "  $(du -h "$f" 2>/dev/null | cut -f1) - $f"
done || echo "  No large files found"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
