#!/usr/bin/env bash
# check-backups.sh - Verify backup status and integrity
# Usage: ./check-backups.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  BACKUP STATUS - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Common backup locations
backup_dirs=(
    "/backup"
    "/var/backups"
    "/data/backup"
    "/mnt/backup"
    "/opt/backup"
    "/home/backup"
)

echo -e "\n${GREEN}▶ BACKUP DIRECTORIES${NC}"
found=false

for dir in "${backup_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        found=true
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        count=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✅${NC} $dir - Size: $size, Files: $count"
        
        # Check latest backup
        latest=$(ls -t "$dir" 2>/dev/null | head -1)
        if [[ -n "$latest" ]]; then
            latest_path="$dir/$latest"
            if [[ -f "$latest_path" || -d "$latest_path" ]]; then
                modified=$(stat -c %Y "$latest_path" 2>/dev/null || stat -f %m "$latest_path" 2>/dev/null)
                if [[ -n "$modified" ]]; then
                    age_hours=$(( ( $(date +%s) - modified ) / 3600 ))
                    if [[ $age_hours -lt 24 ]]; then
                        echo -e "    Latest: $latest (${age_hours}h ago) ${GREEN}✓${NC}"
                    elif [[ $age_hours -lt 72 ]]; then
                        echo -e "    Latest: $latest (${age_hours}h ago) ${YELLOW}⚠️${NC}"
                    else
                        echo -e "    Latest: $latest (${age_hours}h ago) ${RED}❌${NC}"
                    fi
                fi
            fi
        fi
    fi
done

if [[ "$found" == false ]]; then
    echo -e "  ${RED}❌ No backup directories found!${NC}"
    echo "  Checked: ${backup_dirs[*]}"
fi

# Check backup tools
echo -e "\n${GREEN}▶ BACKUP TOOLS INSTALLED${NC}"
backup_tools=("rsync" "borg" "restic" "duplicity" "rclone" "tar" "gzip" "bzip2")
for tool in "${backup_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        version=$($tool --version 2>/dev/null | head -1 | cut -d' ' -f1-2 || echo "installed")
        echo -e "  ${GREEN}✅${NC} $tool - $version"
    else
        echo -e "  ${YELLOW}❌${NC} $tool - not installed"
    fi
done

# Check for backup logs
echo -e "\n${GREEN}▶ BACKUP LOGS${NC}"
backup_logs=("/var/log/backup" "/var/log/backups" "/var/log/rsync" "/var/log/duplicity")
for log_dir in "${backup_logs[@]}"; do
    if [[ -d "$log_dir" ]]; then
        echo "  $log_dir:"
        ls -lt "$log_dir" 2>/dev/null | head -3 | sed 's/^/    /'
    fi
done

# Check for failed backup processes
echo -e "\n${GREEN}▶ RECENT BACKUP ERRORS (last 24h)${NC}"
if command -v journalctl &>/dev/null; then
    journalctl --since "24 hours ago" 2>/dev/null | grep -i "backup.*fail" | head -5 | sed 's/^/  /' || echo "  No backup errors found"
else
    grep -i "backup.*fail" /var/log/syslog 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  No backup errors found"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
