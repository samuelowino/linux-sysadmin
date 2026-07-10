#!/usr/bin/env bash
# check-updates.sh - Check for available system updates
# Usage: ./check-updates.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SYSTEM UPDATES - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}▶ PACKAGE UPDATES${NC}"

# Detect package manager
if command -v apt &>/dev/null; then
    echo "  Package manager: APT (Debian/Ubuntu)"
    
    echo "  Updating package lists..."
    sudo apt update 2>/dev/null >/dev/null || echo "  ⚠️  'apt update' failed (run with sudo?)"
    
    updates=$(apt list --upgradable 2>/dev/null | wc -l)
    security=$(apt list --upgradable 2>/dev/null | grep -c security || echo "0")
    
    echo "  Total updates available: $((updates - 1))"
    if [[ $security -gt 0 ]]; then
        echo -e "  ${RED}⚠️  Security updates available: $security${NC}"
        apt list --upgradable 2>/dev/null | grep security | head -5 | sed 's/^/    /'
    else
        echo -e "  ${GREEN}✅ No security updates pending${NC}"
    fi
    
elif command -v dnf &>/dev/null; then
    echo "  Package manager: DNF (RHEL/Fedora)"
    
    # Check for updates
    updates=$(dnf check-update 2>/dev/null | wc -l)
    security=$(dnf check-update --security 2>/dev/null | wc -l)
    
    echo "  Total updates available: $((updates - 1))"
    if [[ $security -gt 1 ]]; then
        echo -e "  ${RED}⚠️  Security updates available: $((security - 1))${NC}"
    else
        echo -e "  ${GREEN}✅ No security updates pending${NC}"
    fi
    
elif command -v yum &>/dev/null; then
    echo "  Package manager: YUM (RHEL/CentOS)"
    updates=$(yum check-update 2>/dev/null | wc -l)
    echo "  Total updates available: $((updates - 1))"
    
else
    echo -e "  ${YELLOW}⚠️  Unknown package manager${NC}"
fi

echo -e "\n${GREEN}▶ KERNEL VERSION${NC}"
echo "  Current: $(uname -r)"
if command -v apt &>/dev/null; then
    kernel_updates=$(apt list --upgradable 2>/dev/null | grep -c "linux-image" || echo "0")
    if [[ $kernel_updates -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠️  Kernel update available ($kernel_updates) - reboot needed!${NC}"
    else
        echo -e "  ${GREEN}✅ Kernel is up to date${NC}"
    fi
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
