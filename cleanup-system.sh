#!/usr/bin/env bash
# cleanup-system.sh - Clean up temporary files, logs, and caches
# Usage: ./cleanup-system.sh [--dry-run] [--aggressive]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
AGGRESSIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --aggressive) AGGRESSIVE=true; shift ;;
        --help) 
            echo "Usage: $0 [--dry-run] [--aggressive]"
            echo "  --dry-run    : Show what would be deleted without deleting"
            echo "  --aggressive : Remove more files (older logs, package caches)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SYSTEM CLEANUP - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}⚠️  DRY RUN MODE - No files will be deleted${NC}"
fi

echo -e "\n${GREEN}▶ BEFORE CLEANUP${NC}"
echo "  Disk usage: $(df -h / | tail -1 | awk '{print $3 " used / " $2 " total (" $5 ")"}')"

echo -e "\n${GREEN}▶ CLEANING TEMPORARY FILES${NC}"
temp_dirs=("/tmp" "/var/tmp")
for dir in "${temp_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        old_files=$(find "$dir" -type f -atime +3 -not -path "/tmp/.X*" -not -path "/tmp/.ICE*" 2>/dev/null)
        count=$(echo "$old_files" | wc -l)
        if [[ -n "$old_files" && $count -gt 0 ]]; then
            echo "  $dir: $count old files found"
            if [[ "$DRY_RUN" == false ]]; then
                echo "$old_files" | xargs rm -f 2>/dev/null || true
                echo -e "  ${GREEN}✅ Cleaned $count files from $dir${NC}"
            else
                echo "  (would delete $count files from $dir)"
            fi
        else
            echo "  $dir: No old files to clean"
        fi
    fi
done

echo -e "\n${GREEN}▶ CLEANING PACKAGE MANAGER CACHE${NC}"
if command -v apt &>/dev/null; then
    cache_size=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
    echo "  APT cache size: $cache_size"
    if [[ "$DRY_RUN" == false ]]; then
        sudo apt clean 2>/dev/null && echo -e "  ${GREEN}✅ APT cache cleaned${NC}"
    else
        echo "  (would clean APT cache)"
    fi
elif command -v dnf &>/dev/null; then
    echo "  DNF cache:"
    if [[ "$DRY_RUN" == false ]]; then
        sudo dnf clean all 2>/dev/null && echo -e "  ${GREEN}✅ DNF cache cleaned${NC}"
    else
        echo "  (would clean DNF cache)"
    fi
fi

echo -e "\n${GREEN}▶ CLEANING OLD LOGS${NC}"
if [[ "$AGGRESSIVE" == true ]]; then
    # Find and rotate old logs
    old_logs=$(find /var/log -type f -name "*.log" -mtime +30 2>/dev/null)
    count=$(echo "$old_logs" | wc -l)
    if [[ -n "$old_logs" && $count -gt 0 ]]; then
        echo "  Found $count old log files (>30 days)"
        if [[ "$DRY_RUN" == false ]]; then
            echo "$old_logs" | xargs gzip -9 2>/dev/null || true
            echo -e "  ${GREEN}✅ Compressed $count old logs${NC}"
        else
            echo "  (would compress $count old logs)"
        fi
    else
        echo "  No old log files to compress"
    fi
fi

echo -e "\n${GREEN}▶ CLEANING TRASH AND JUNK${NC}"
# Clean user trash
for user in $(getent passwd | cut -d: -f1); do
    trash_dir="/home/$user/.local/share/Trash"
    if [[ -d "$trash_dir" ]]; then
        size=$(du -sh "$trash_dir" 2>/dev/null | cut -f1)
        echo "  $user's trash: $size"
        if [[ "$DRY_RUN" == false ]]; then
            rm -rf "$trash_dir"/* 2>/dev/null || true
            echo -e "  ${GREEN}✅ Cleaned $user's trash${NC}"
        else
            echo "  (would clean $user's trash)"
        fi
    fi
done

# Clean core dumps
core_dumps=$(find / -name "core.*" -type f 2>/dev/null | head -10)
if [[ -n "$core_dumps" ]]; then
    echo "  Found core dumps:"
    echo "$core_dumps" | sed 's/^/    /'
    if [[ "$DRY_RUN" == false ]]; then
        find / -name "core.*" -type f -delete 2>/dev/null || true
        echo -e "  ${GREEN}✅ Removed core dumps${NC}"
    fi
fi

echo -e "\n${GREEN}▶ AFTER CLEANUP${NC}"
echo "  Disk usage: $(df -h / | tail -1 | awk '{print $3 " used / " $2 " total (" $5 ")"}')"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "\n${YELLOW}⚠️  DRY RUN COMPLETE - No files were deleted${NC}"
    echo "  Run without --dry-run to apply changes"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
