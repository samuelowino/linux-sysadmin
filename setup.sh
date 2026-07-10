#!/usr/bin/env bash
# setup-tools.sh - Install all sysadmin tools
set -e
TOOLS_DIR="$HOME/linux-sysadmin"
echo "🚀 Setting up SysAdmin Tools..."
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"
chmod +x *.sh
echo "Tools installed to: $TOOLS_DIR"
echo ""
echo "Usage examples:"
echo "  ./check-system.sh     - Quick system health"
echo "  ./daily-report.sh     - Full report"
echo "  ./daily-report.sh --email --quick  - Quick report with email"
echo ""
echo "Optional: Add to crontab with"
echo "  0 8 * * * $TOOLS_DIR/daily-report.sh --email --output /var/log/daily-report.txt"
