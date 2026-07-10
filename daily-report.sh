#!/usr/bin/env bash
# daily-report.sh - Run all checks and generate a comprehensive report
# Usage: ./daily-report.sh [--quick] [--email] [--output file.txt]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="${SCRIPT_DIR}/daily_report_$(date +%Y%m%d_%H%M%S).txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

QUICK=false
SEND_EMAIL=false
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick) QUICK=true; shift ;;
        --email) SEND_EMAIL=true; shift ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --help) 
            echo "Usage: $0 [--quick] [--email] [--output file.txt]"
            echo "  --quick   : Skip time-consuming checks (backups, ssl)"
            echo "  --email   : Send report via email"
            echo "  --output  : Save report to custom file"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -n "$OUTPUT_FILE" ]]; then
    REPORT_FILE="$OUTPUT_FILE"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  GENERATING DAILY REPORT${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Start report
{
    echo "DAILY SYSTEM REPORT - $(hostname)"
    echo "Generated: $(date)"
    echo "Quick mode: $QUICK"
    echo "=========================================="
    echo ""
} > "$REPORT_FILE"

# Function to run a script and append output
run_check() {
    local script="$1"
    local name="$2"
    
    echo -e "\n${YELLOW}Running: $name...${NC}"
    echo "" >> "$REPORT_FILE"
    echo "--- $name ---" >> "$REPORT_FILE"
    
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        if [[ "$QUICK" == true ]]; then
            case "$script" in
                check-ssl.sh|check-backups.sh|check-updates.sh)
                    echo "(skipped in quick mode)" >> "$REPORT_FILE"
                    echo -e "  ${YELLOW}Skipped (quick mode)${NC}"
                    return
                    ;;
            esac
        fi
        
        if bash "$SCRIPT_DIR/$script" >> "$REPORT_FILE" 2>&1; then
            echo -e "  ${GREEN}✅ Completed${NC}"
        else
            echo -e "  ${RED}❌ Failed${NC}"
        fi
    else
        echo "Script not found: $script" >> "$REPORT_FILE"
        echo -e "  ${RED}❌ Script not found${NC}"
    fi
}

# Run all checks
echo -e "\n${GREEN}Running system checks...${NC}"
run_check "check-system.sh" "System Health"
run_check "check-disk.sh" "Disk Usage"
run_check "check-load.sh" "CPU Load"
run_check "check-services.sh" "Services"
run_check "check-network.sh" "Network"
run_check "check-ports.sh" "Open Ports"
run_check "check-security.sh" "Security"
run_check "check-users.sh" "User Audit"
run_check "check-failed-logins.sh" "Failed Logins"
run_check "check-cron.sh" "Cron Jobs"
run_check "check-logs.sh" "Log Analysis"

if [[ "$QUICK" == false ]]; then
    run_check "check-ssl.sh" "SSL Certificates"
    run_check "check-backups.sh" "Backups"
    run_check "check-updates.sh" "Updates"
    run_check "cleanup-system.sh" "Cleanup"
fi

# Append summary
{
    echo ""
    echo "=========================================="
    echo "REPORT COMPLETE"
    echo "=========================================="
} >> "$REPORT_FILE"

echo -e "\n${GREEN}✅ Report generated: $REPORT_FILE${NC}"

# Show summary
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Report summary:"
tail -30 "$REPORT_FILE" | head -20
echo "..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Email if requested
if [[ "$SEND_EMAIL" == true ]]; then
    if command -v mail &>/dev/null; then
        subject="Daily Report - $(hostname) - $(date +%Y-%m-%d)"
        mail -s "$subject" "${ADMIN_EMAIL:-root}" < "$REPORT_FILE"
        echo -e "${GREEN}✅ Report sent via email${NC}"
    else
        echo -e "${RED}❌ 'mail' command not found${NC}"
    fi
fi

echo -e "\n${GREEN}Done!${NC}"
