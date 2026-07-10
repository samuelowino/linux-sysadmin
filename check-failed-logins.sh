#!/usr/bin/env bash
# check-failed-logins.sh - Analyze failed login attempts
# Usage: ./check-failed-logins.sh [--top N] [--hours H] [--json]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TOP_N=10
HOURS=24
JSON_OUTPUT=false
AUTH_LOG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --top) TOP_N="$2"; shift 2 ;;
        --hours) HOURS="$2"; shift 2 ;;
        --json) JSON_OUTPUT=true; shift ;;
        --help) 
            echo "Usage: $0 [--top N] [--hours H] [--json]"
            echo "  --top N   : Show top N attacking IPs (default: 10)"
            echo "  --hours H : Check last H hours (default: 24)"
            echo "  --json    : Output in JSON format"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Find auth log
find_auth_log() {
    local logs=(
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/log/messages"
        "/var/log/syslog"
    )
    
    for log in "${logs[@]}"; do
        if [[ -f "$log" ]]; then
            echo "$log"
            return 0
        fi
    done
    return 1
}

AUTH_LOG=$(find_auth_log)

if [[ -z "$AUTH_LOG" ]]; then
    echo -e "${RED}❌ No authentication log found!${NC}"
    echo "Checked: /var/log/auth.log, /var/log/secure, /var/log/messages"
    exit 1
fi

# Function to get logs from last N hours
get_recent_logs() {
    if command -v journalctl &>/dev/null && [[ "$AUTH_LOG" == "/var/log/auth.log" || "$AUTH_LOG" == "/var/log/secure" ]]; then
        # Use journalctl for systemd systems
        journalctl --since "${HOURS}h ago" -u sshd -u ssh -u dropbear 2>/dev/null | cat
    else
        # Use log file directly
        if [[ -f "$AUTH_LOG" ]]; then
            # Get logs from last N hours using awk
            local since_time=$(date -d "${HOURS} hours ago" "+%b %d %H:%M:%S" 2>/dev/null || date -v-${HOURS}H "+%b %d %H:%M:%S" 2>/dev/null)
            if [[ -n "$since_time" ]]; then
                awk -v since="$since_time" '$0 > since' "$AUTH_LOG" 2>/dev/null || cat "$AUTH_LOG"
            else
                cat "$AUTH_LOG"
            fi
        fi
    fi
}

# Color output for JSON mode
if [[ "$JSON_OUTPUT" == true ]]; then
    # JSON output mode
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"host\": \"$(hostname)\","
    echo "  \"auth_log\": \"$AUTH_LOG\","
    echo "  \"analysis\": {"
    
    # Get counts
    local total_ssh_failures=$(grep -c "Failed password" "$AUTH_LOG" 2>/dev/null || echo "0")
    local total_invalid_users=$(grep -c "Invalid user" "$AUTH_LOG" 2>/dev/null || echo "0")
    local total_connection_errors=$(grep -c "Connection closed\|Connection reset" "$AUTH_LOG" 2>/dev/null || echo "0")
    
    echo "    \"ssh_failures\": $total_ssh_failures,"
    echo "    \"invalid_users\": $total_invalid_users,"
    echo "    \"connection_errors\": $total_connection_errors,"
    
    # Get top attacking IPs
    echo "    \"top_attackers\": ["
    grep "Failed password" "$AUTH_LOG" 2>/dev/null | awk '{print $(NF-3)}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort | uniq -c | sort -rn | head -"$TOP_N" | while read -r count ip; do
        echo "      {\"ip\": \"$ip\", \"attempts\": $count},"
    done | sed '$ s/,$//'
    echo "    ],"
    
    # Get top usernames tried
    echo "    \"top_usernames\": ["
    grep "Failed password\|Invalid user" "$AUTH_LOG" 2>/dev/null | grep -o "user [^ ]*" | awk '{print $2}' | sort | uniq -c | sort -rn | head -10 | while read -r count user; do
        echo "      {\"username\": \"$user\", \"attempts\": $count},"
    done | sed '$ s/,$//'
    echo "    ]"
    
    echo "  }"
    echo "}"
    exit 0
fi

# Normal output mode
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FAILED LOGIN ANALYSIS - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}  Log: $AUTH_LOG (last $HOURS hours)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}▶ SUMMARY STATISTICS${NC}"

# Get counts correctly
total_ssh_failures=$(grep -c "Failed password" "$AUTH_LOG" 2>/dev/null || echo "0")
total_invalid_users=$(grep -c "Invalid user" "$AUTH_LOG" 2>/dev/null || echo "0")
total_connection_errors=$(grep -c "Connection closed\|Connection reset\|Connection refused" "$AUTH_LOG" 2>/dev/null || echo "0")
total_auth_failures=$(grep -c "authentication failure" "$AUTH_LOG" 2>/dev/null || echo "0")

echo -e "  ${CYAN}SSH Password Failures:${NC} $total_ssh_failures"
echo -e "  ${CYAN}Invalid Usernames Attempted:${NC} $total_invalid_users"
echo -e "  ${CYAN}Authentication Failures:${NC} $total_auth_failures"
echo -e "  ${CYAN}Connection Errors:${NC} $total_connection_errors"

# Determine threat level
threat_level="LOW"
threat_color="$GREEN"
if [[ $total_ssh_failures -gt 1000 ]]; then
    threat_level="CRITICAL"
    threat_color="$RED"
elif [[ $total_ssh_failures -gt 100 ]]; then
    threat_level="HIGH"
    threat_color="$RED"
elif [[ $total_ssh_failures -gt 10 ]]; then
    threat_level="MEDIUM"
    threat_color="$YELLOW"
fi

echo -e "  ${CYAN}Threat Level:${NC} ${threat_color}$threat_level${NC}"

echo -e "\n${GREEN}▶ TOP ATTACKING IP ADDRESSES${NC}"
if [[ $total_ssh_failures -eq 0 ]]; then
    echo -e "  ${GREEN}✅ No failed SSH attempts found${NC}"
else
    echo "  (Last $HOURS hours)"
    grep "Failed password" "$AUTH_LOG" 2>/dev/null | \
        awk '{print $(NF-3)}' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
        sort | uniq -c | sort -rn | head -"$TOP_N" | \
        while read -r count ip; do
            # Check if IP is in common safe lists
            if [[ "$ip" == "127.0.0.1" || "$ip" == "::1" || "$ip" == "10."* || "$ip" == "192.168."* || "$ip" == "172.16."* || "$ip" == "172.17."* || "$ip" == "172.18."* || "$ip" == "172.19."* || "$ip" == "172.20."* || "$ip" == "172.21."* || "$ip" == "172.22."* || "$ip" == "172.23."* || "$ip" == "172.24."* || "$ip" == "172.25."* || "$ip" == "172.26."* || "$ip" == "172.27."* || "$ip" == "172.28."* || "$ip" == "172.29."* || "$ip" == "172.30."* || "$ip" == "172.31."* ]]; then
                echo -e "  ${YELLOW}⚠️${NC} $count attempts from $ip (local/internal)"
            else
                # Try to get geolocation (optional - requires curl)
                if command -v curl &>/dev/null; then
                    geo=$(curl -s "http://ip-api.com/line/$ip?fields=countryCode,region,city" 2>/dev/null | head -1 || echo "unknown")
                    if [[ -n "$geo" && "$geo" != "unknown" ]]; then
                        echo -e "  ${RED}🚨${NC} $count attempts from $ip ($geo)"
                    else
                        echo -e "  ${RED}🚨${NC} $count attempts from $ip"
                    fi
                else
                    echo -e "  ${RED}🚨${NC} $count attempts from $ip"
                fi
            fi
        done
fi

echo -e "\n${GREEN}▶ MOST COMMON USERNAMES ATTEMPTED${NC}"
grep "Failed password\|Invalid user" "$AUTH_LOG" 2>/dev/null | \
    grep -o "user [^ ]*" | \
    awk '{print $2}' | \
    sort | uniq -c | sort -rn | head -10 | \
    while read -r count user; do
        if [[ "$user" == "root" || "$user" == "admin" || "$user" == "ubuntu" || "$user" == "debian" ]]; then
            echo -e "  ${RED}⚠️${NC} $count attempts for user: $user (common target!)"
        else
            echo -e "  ${YELLOW}⚠️${NC} $count attempts for user: $user"
        fi
    done

echo -e "\n${GREEN}▶ RECENT FAILED ATTEMPTS (last 10)${NC}"
grep "Failed password" "$AUTH_LOG" 2>/dev/null | tail -10 | \
    sed 's/^/  /' | \
    while read -r line; do
        # Highlight the IP in the line
        echo "$line" | sed -E 's/([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/\x1b[31m\1\x1b[0m/g'
    done

echo -e "\n${GREEN}▶ FAIL2BAN STATUS${NC}"
if command -v fail2ban-client &>/dev/null; then
    if sudo fail2ban-client status 2>/dev/null | grep -q "Status"; then
        echo -e "  ${GREEN}✅ fail2ban is running${NC}"
        echo "  Active jails:"
        sudo fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/^/    /'
        
        # Show banned IPs
        echo "  Recently banned IPs:"
        for jail in $(sudo fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list://g' | tr -d ' ' | tr ',' ' '); do
            if [[ -n "$jail" ]]; then
                banned=$(sudo fail2ban-client status "$jail" 2>/dev/null | grep "Banned IP list" | sed 's/.*://g' | tr -d ' ')
                if [[ -n "$banned" ]]; then
                    echo "    $jail: $banned"
                fi
            fi
        done
    else
        echo -e "  ${YELLOW}⚠️  fail2ban is installed but not running${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  fail2ban not installed${NC}"
    echo "  Install: sudo apt install fail2ban  or  sudo dnf install fail2ban"
fi

echo -e "\n${GREEN}▶ SSH HARDENING CHECK${NC}"
if [[ -f /etc/ssh/sshd_config ]]; then
    # Check PasswordAuthentication
    pass_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "not set")
    if [[ "$pass_auth" == "no" ]]; then
        echo -e "  ${GREEN}✅ PasswordAuthentication: no (good)${NC}"
    elif [[ "$pass_auth" == "yes" ]]; then
        echo -e "  ${RED}⚠️  PasswordAuthentication: yes (consider disabling)${NC}"
    else
        echo -e "  ${YELLOW}⚠️  PasswordAuthentication: $pass_auth (default may be yes)${NC}"
    fi
    
    # Check PermitRootLogin
    root_login=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "not set")
    if [[ "$root_login" == "no" || "$root_login" == "without-password" || "$root_login" == "prohibit-password" ]]; then
        echo -e "  ${GREEN}✅ PermitRootLogin: $root_login (good)${NC}"
    elif [[ "$root_login" == "yes" ]]; then
        echo -e "  ${RED}⚠️  PermitRootLogin: yes (consider changing)${NC}"
    else
        echo -e "  ${YELLOW}⚠️  PermitRootLogin: $root_login${NC}"
    fi
    
    # Check SSH Port
    ssh_port=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
    if [[ "$ssh_port" == "22" ]]; then
        echo -e "  ${YELLOW}⚠️  SSH Port: 22 (default - consider changing)${NC}"
    else
        echo -e "  ${GREEN}✅ SSH Port: $ssh_port (non-default)${NC}"
    fi
    
    # Check MaxAuthTries
    max_tries=$(grep -i "^MaxAuthTries" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "not set")
    if [[ -n "$max_tries" && "$max_tries" -le 3 ]]; then
        echo -e "  ${GREEN}✅ MaxAuthTries: $max_tries${NC}"
    elif [[ -n "$max_tries" ]]; then
        echo -e "  ${YELLOW}⚠️  MaxAuthTries: $max_tries (consider reducing to 3)${NC}"
    fi
fi

echo -e "\n${GREEN}▶ RECOMMENDATIONS${NC}"
if [[ $total_ssh_failures -gt 100 ]]; then
    echo -e "  ${RED}🔴 High number of SSH attacks detected!${NC}"
    echo "  1. Install and configure fail2ban"
    echo "  2. Disable password authentication (use SSH keys)"
    echo "  3. Change SSH port from 22"
    echo "  4. Use AllowUsers or AllowGroups to restrict access"
    echo "  5. Consider using a VPN or bastion host"
elif [[ $total_ssh_failures -gt 10 ]]; then
    echo -e "  ${YELLOW}🟡 Moderate SSH attack activity${NC}"
    echo "  1. Ensure fail2ban is running"
    echo "  2. Review authorized_keys for unused keys"
    echo "  3. Consider rate limiting"
else
    echo -e "  ${GREEN}🟢 Low attack activity - continue monitoring${NC}"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
