#!/usr/bin/env bash
# check-failed-logins.sh - Advanced security audit for failed login attempts
# Usage: ./check-failed-logins.sh [--top N] [--hours H] [--json] [--email EMAIL] [--slack WEBHOOK] [--watch]

set -euo pipefail

# ============================================================
# Configuration
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

TOP_N=10
HOURS=24
JSON_OUTPUT=false
EMAIL_RECIPIENT=""
SLACK_WEBHOOK=""
WATCH_MODE=false
ALERT_THRESHOLD=100
CACHE_DIR="/tmp/check-failed-logins_$$"
AUTH_LOG=""
EXIT_CODE=0

# ============================================================
# Argument Parsing
# ============================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --top) TOP_N="$2"; shift 2 ;;
        --hours) HOURS="$2"; shift 2 ;;
        --json) JSON_OUTPUT=true; shift ;;
        --email) EMAIL_RECIPIENT="$2"; shift 2 ;;
        --slack) SLACK_WEBHOOK="$2"; shift 2 ;;
        --watch) WATCH_MODE=true; shift ;;
        --alert) ALERT_THRESHOLD="$2"; shift 2 ;;
        --help) 
            cat << EOF
Usage: $0 [OPTIONS]

Options:
  --top N          Show top N attacking IPs (default: 10)
  --hours H        Check last H hours (default: 24)
  --json           Output in JSON format
  --email EMAIL    Send report to email address
  --slack WEBHOOK  Send report to Slack webhook URL
  --watch          Watch mode - continuously monitor (Ctrl+C to exit)
  --alert N        Exit with code 2 if failures exceed N (default: 100)
  --help           Show this help message

Examples:
  $0 --top 20 --hours 48
  $0 --json --alert 50
  $0 --watch --slack https://hooks.slack.com/services/XXX
EOF
            exit 0
            ;;
        *) echo -e "${RED}❌ Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ============================================================
# Cache and Temporary Files
# ============================================================
mkdir -p "$CACHE_DIR"
trap 'rm -rf "$CACHE_DIR"' EXIT

# ============================================================
# Log Detection
# ============================================================
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
    echo -e "${RED}❌ No authentication log found!${NC}" >&2
    echo "Checked: /var/log/auth.log, /var/log/secure, /var/log/messages" >&2
    exit 1
fi

# ============================================================
# Core Functions
# ============================================================

# Get logs from last N hours (reliable version)
get_recent_logs() {
    local log_output=""
    
    if command -v journalctl &>/dev/null; then
        # Try multiple unit names
        log_output=$(journalctl --since "${HOURS}h ago" \
            -u sshd -u ssh -u dropbear -u systemd-logind \
            --no-pager 2>/dev/null | cat || true)
        
        # Fallback to auth log if journalctl returns nothing
        if [[ -z "$log_output" && -f "$AUTH_LOG" ]]; then
            log_output=$(tail -n 50000 "$AUTH_LOG" 2>/dev/null || true)
        fi
    elif [[ -f "$AUTH_LOG" ]]; then
        # Use perl for accurate date parsing on syslog
        if command -v perl &>/dev/null; then
            local since_epoch
            since_epoch=$(date -d "${HOURS} hours ago" "+%s" 2>/dev/null || date -v-${HOURS}H "+%s" 2>/dev/null || echo "")
            
            if [[ -n "$since_epoch" ]]; then
                log_output=$(perl -n -e '
                    my $since = shift @ARGV;
                    if (/^(\w{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})/) {
                        my $month = {Jan=>0,Feb=>1,Mar=>2,Apr=>3,May=>4,Jun=>5,
                                     Jul=>6,Aug=>7,Sep=>8,Oct=>9,Nov=>10,Dec=>11}->{$1};
                        my $day = $2;
                        my $hour = $3;
                        my $min = $4;
                        my $sec = $5;
                        my $now = time();
                        my $year = (localtime($now))[5] + 1900;
                        my $epoch = timelocal($sec, $min, $hour, $day, $month, $year);
                        if ($epoch < $now - 86400 * 30 && $month > 6) { $year -= 1; $epoch = timelocal($sec, $min, $hour, $day, $month, $year); }
                        print if $epoch >= $since;
                    } elsif (/^(\w{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})/ && $1) {
                        # Fallback: print everything
                        print;
                    }
                ' "$since_epoch" "$AUTH_LOG" 2>/dev/null || tail -50000 "$AUTH_LOG")
            else
                log_output=$(tail -50000 "$AUTH_LOG" 2>/dev/null)
            fi
        else
            log_output=$(tail -50000 "$AUTH_LOG" 2>/dev/null)
        fi
    fi
    
    echo "$log_output"
}

# Get count from logs safely
count_pattern() {
    local pattern="$1"
    local logs="$2"
    echo "$logs" | grep -c "$pattern" 2>/dev/null || echo 0
}

# Extract IPs from log entries
extract_ips() {
    local logs="$1"
    local pattern="${2:-Failed password}"
    echo "$logs" | grep "$pattern" 2>/dev/null | \
        awk '{for(i=1;i<=NF;i++){if($i~/([0-9]{1,3}\.){3}[0-9]{1,3}/){print $i}}}' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true
}

# Extract usernames from log entries
extract_usernames() {
    local logs="$1"
    echo "$logs" | grep "Failed password\|Invalid user" 2>/dev/null | \
        grep -o "user [^ ]*" | awk '{print $2}' | \
        sort -u | head -50 || true
}

# Check if IP is internal
is_internal_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^(127\.|10\.|192\.168\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|::1) ]]; then
        return 0
    fi
    return 1
}

# GeoIP lookup with caching
geo_lookup() {
    local ip="$1"
    local cache_file="$CACHE_DIR/geo_cache.txt"
    local result=""
    
    # Check cache
    if [[ -f "$cache_file" ]]; then
        result=$(grep "^$ip|" "$cache_file" 2>/dev/null | cut -d'|' -f2- || true)
    fi
    
    if [[ -z "$result" ]]; then
        # Try local geoiplookup first (faster)
        if command -v geoiplookup &>/dev/null; then
            result=$(geoiplookup "$ip" 2>/dev/null | head -1 | cut -d: -f2- | xargs)
        fi
        
        # Fallback to online API with timeout
        if [[ -z "$result" || "$result" == *"not found"* ]]; then
            result=$(curl -s --max-time 1 "http://ip-api.com/line/$ip?fields=countryCode,city,org" 2>/dev/null | head -3 | tr '\n' ' ' | xargs || true)
        fi
        
        # Cache the result
        echo "$ip|$result" >> "$cache_file" 2>/dev/null
    fi
    
    echo "$result"
}

# Get effective SSH config (reliable)
get_ssh_config() {
    local param="$1"
    local value="not set"
    
    if command -v sshd &>/dev/null && [[ -f /etc/ssh/sshd_config ]]; then
        value=$(sshd -T 2>/dev/null | grep -i "^$param" | awk '{print $2}' || echo "not set")
    elif [[ -f /etc/ssh/sshd_config ]]; then
        value=$(grep -i "^$param" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "not set")
    fi
    
    echo "$value"
}

# ============================================================
# Alert Functions
# ============================================================

send_email() {
    local subject="$1"
    local body="$2"
    local recipient="$3"
    
    if command -v mail &>/dev/null; then
        echo "$body" | mail -s "$subject" "$recipient" 2>/dev/null && return 0
    fi
    
    if command -v sendmail &>/dev/null; then
        echo -e "Subject: $subject\n\n$body" | sendmail "$recipient" 2>/dev/null && return 0
    fi
    
    return 1
}

send_slack() {
    local message="$1"
    local webhook="$2"
    
    if command -v curl &>/dev/null; then
        local payload=$(jq -n --arg msg "$message" '{text: $msg, mrkdwn: true}')
        curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$webhook" >/dev/null 2>&1
        return $?
    fi
    return 1
}

# ============================================================
# Main Analysis Function
# ============================================================

analyze_logs() {
    local logs="$1"
    local json_output="${2:-false}"
    local output=""
    
    # Count failures from the time-filtered logs
    local total_ssh_failures=$(count_pattern "Failed password" "$logs")
    local total_invalid_users=$(count_pattern "Invalid user" "$logs")
    local total_connection_errors=$(count_pattern "Connection closed\|Connection reset\|Connection refused" "$logs")
    local total_auth_failures=$(count_pattern "authentication failure" "$logs")
    
    # Set exit code if threshold exceeded
    if [[ $total_ssh_failures -gt $ALERT_THRESHOLD ]]; then
        EXIT_CODE=2
    fi
    
    # Determine threat level
    local threat_level="LOW"
    local threat_color="$GREEN"
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
    
    # Get top IPs
    local top_ips=""
    local top_ips_json=""
    if [[ $total_ssh_failures -gt 0 ]]; then
        top_ips=$(extract_ips "$logs" "Failed password" | sort | uniq -c | sort -rn | head -"$TOP_N")
        top_ips_json=$(echo "$top_ips" | while read -r count ip; do
            if [[ -n "$ip" && -n "$count" ]]; then
                local geo=""
                if ! is_internal_ip "$ip"; then
                    geo=$(geo_lookup "$ip")
                fi
                echo "{\"ip\":\"$ip\",\"attempts\":$count,\"geo\":\"$geo\"},"
            fi
        done | sed '$ s/,$//')
    fi
    
    # Get top usernames
    local top_users=""
    local top_users_json=""
    if [[ $total_ssh_failures -gt 0 || $total_invalid_users -gt 0 ]]; then
        top_users=$(extract_usernames "$logs" | sort | uniq -c | sort -rn | head -10)
        top_users_json=$(echo "$top_users" | while read -r count user; do
            if [[ -n "$user" && -n "$count" ]]; then
                echo "{\"username\":\"$user\",\"attempts\":$count},"
            fi
        done | sed '$ s/,$//')
    fi
    
    # Unique IPs count
    local unique_ips=0
    if [[ $total_ssh_failures -gt 0 ]]; then
        unique_ips=$(extract_ips "$logs" "Failed password" | sort -u | wc -l)
    fi
    
    # Unique usernames count
    local unique_users=0
    if [[ $total_ssh_failures -gt 0 || $total_invalid_users -gt 0 ]]; then
        unique_users=$(extract_usernames "$logs" | sort -u | wc -l)
    fi
    
    # JSON output
    if [[ "$json_output" == true ]]; then
        cat << EOF
{
  "timestamp": "$(date -Iseconds 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "host": "$(hostname)",
  "auth_log": "$AUTH_LOG",
  "hours": $HOURS,
  "analysis": {
    "summary": {
      "ssh_failures": $total_ssh_failures,
      "invalid_users": $total_invalid_users,
      "auth_failures": $total_auth_failures,
      "connection_errors": $total_connection_errors,
      "unique_ips": $unique_ips,
      "unique_usernames": $unique_users,
      "threat_level": "$threat_level"
    },
    "top_attackers": [$top_ips_json],
    "top_usernames": [$top_users_json]
  }
}
EOF
        return 0
    fi
    
    # ============================================================
    # Build Human-Readable Output
    # ============================================================
    output+=$(cat << EOF
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}  FAILED LOGIN ANALYSIS - $(hostname)${NC}
${BLUE}  $(date)${NC}
${BLUE}  Log: $AUTH_LOG (last $HOURS hours)${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${GREEN}▶ SUMMARY STATISTICS${NC}
  ${CYAN}SSH Password Failures:${NC} $total_ssh_failures
  ${CYAN}Invalid Usernames Attempted:${NC} $total_invalid_users
  ${CYAN}Authentication Failures:${NC} $total_auth_failures
  ${CYAN}Connection Errors:${NC} $total_connection_errors
  ${CYAN}Threat Level:${NC} ${threat_color}$threat_level${NC}
  ${CYAN}Unique Attacking IPs:${NC} $unique_ips
  ${CYAN}Unique Usernames Attempted:${NC} $unique_users

EOF
)
    
    # Top attacking IPs
    output+="${GREEN}▶ TOP ATTACKING IP ADDRESSES${NC}\n"
    if [[ $total_ssh_failures -eq 0 ]]; then
        output+="  ${GREEN}✅ No failed SSH attempts found${NC}\n"
    else
        output+="  (Last $HOURS hours)\n"
        echo "$top_ips" | while read -r count ip; do
            if [[ -n "$ip" && -n "$count" ]]; then
                if is_internal_ip "$ip"; then
                    output+="  ${YELLOW}⚠️${NC} $count attempts from $ip (internal)\n"
                else
                    local geo_info=$(geo_lookup "$ip")
                    if [[ -n "$geo_info" && "$geo_info" != " " && "$geo_info" != *"not found"* ]]; then
                        output+="  ${RED}🚨${NC} $count attempts from $ip (${geo_info})\n"
                    else
                        output+="  ${RED}🚨${NC} $count attempts from $ip\n"
                    fi
                fi
            fi
        done
    fi
    output+="\n"
    
    # Top usernames
    output+="${GREEN}▶ MOST COMMON USERNAMES ATTEMPTED${NC}\n"
    local common_users="^(root|admin|administrator|ubuntu|debian|test|guest|user|oracle|mysql|postgres|webmaster|ftp|backup|admin123|password|test123)$"
    echo "$top_users" | while read -r count user; do
        if [[ -n "$user" && -n "$count" ]]; then
            if [[ "$user" =~ $common_users ]]; then
                output+="  ${RED}⚠️${NC} $count attempts for user: $user (COMMON TARGET!)\n"
            else
                output+="  ${YELLOW}⚠️${NC} $count attempts for user: $user\n"
            fi
        fi
    done
    output+="\n"
    
    # Recent attempts
    output+="${GREEN}▶ RECENT FAILED ATTEMPTS (last 10)${NC}\n"
    echo "$logs" | grep "Failed password" 2>/dev/null | tail -10 | \
        sed 's/^/  /' | \
        while read -r line; do
            # Highlight IPs
            output+="$(echo "$line" | sed -E 's/([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/\x1b[31m\1\x1b[0m/g')\n"
        done
    output+="\n"
    
    # ============================================================
    # System Health Checks
    # ============================================================
    
    # Fail2ban status
    output+="${GREEN}▶ FAIL2BAN STATUS${NC}\n"
    if command -v fail2ban-client &>/dev/null; then
        local fail2ban_ok=false
        if fail2ban-client status 2>/dev/null | grep -q "Status"; then
            fail2ban_ok=true
            output+="  ${GREEN}✅ fail2ban is running${NC}\n"
            
            local jails=$(sudo -n fail2ban-client status 2>/dev/null 2>/dev/null | grep "Jail list" | sed 's/.*Jail list://g' | tr -d '`' | tr ',' ' ' | xargs || echo "")
            if [[ -z "$jails" ]]; then
                jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list://g' | tr -d '`' | tr ',' ' ' | xargs || echo "")
            fi
            
            output+="  Active jails:\n"
            local banned_found=false
            for jail in $jails; do
                if [[ -n "$jail" ]]; then
                    local banned=""
                    banned=$(sudo -n fail2ban-client status "$jail" 2>/dev/null | grep "Banned IP list" | sed 's/.*://g' | tr -d ' ' || true)
                    if [[ -z "$banned" ]]; then
                        banned=$(fail2ban-client status "$jail" 2>/dev/null | grep "Banned IP list" | sed 's/.*://g' | tr -d ' ' || true)
                    fi
                    if [[ -n "$banned" && "$banned" != " " ]]; then
                        output+="    $jail: $banned\n"
                        banned_found=true
                    fi
                fi
            done
            if [[ "$banned_found" == false ]]; then
                output+="    No IPs currently banned\n"
            fi
        else
            output+="  ${YELLOW}⚠️  fail2ban is installed but not running${NC}\n"
            output+="  Start with: sudo systemctl start fail2ban\n"
        fi
    else
        output+="  ${YELLOW}⚠️  fail2ban not installed${NC}\n"
        output+="  Install: sudo apt install fail2ban  or  sudo dnf install fail2ban\n"
    fi
    output+="\n"
    
    # SSH hardening check
    output+="${GREEN}▶ SSH HARDENING CHECK${NC}\n"
    if [[ -f /etc/ssh/sshd_config ]]; then
        local pass_auth=$(get_ssh_config "PasswordAuthentication")
        if [[ "$pass_auth" == "no" ]]; then
            output+="  ${GREEN}✅ PasswordAuthentication: no (good)${NC}\n"
        elif [[ "$pass_auth" == "yes" ]]; then
            output+="  ${RED}⚠️  PasswordAuthentication: yes (consider disabling)${NC}\n"
        else
            output+="  ${YELLOW}⚠️  PasswordAuthentication: $pass_auth (default may be yes)${NC}\n"
        fi
        
        local root_login=$(get_ssh_config "PermitRootLogin")
        if [[ "$root_login" == "no" || "$root_login" == "without-password" || "$root_login" == "prohibit-password" ]]; then
            output+="  ${GREEN}✅ PermitRootLogin: $root_login (good)${NC}\n"
        elif [[ "$root_login" == "yes" ]]; then
            output+="  ${RED}⚠️  PermitRootLogin: yes (consider changing)${NC}\n"
        else
            output+="  ${YELLOW}⚠️  PermitRootLogin: $root_login${NC}\n"
        fi
        
        local ssh_port=$(get_ssh_config "Port")
        if [[ -z "$ssh_port" || "$ssh_port" == "not set" ]]; then
            ssh_port="22"
        fi
        if [[ "$ssh_port" == "22" ]]; then
            output+="  ${YELLOW}⚠️  SSH Port: 22 (default - consider changing)${NC}\n"
        else
            output+="  ${GREEN}✅ SSH Port: $ssh_port (non-default)${NC}\n"
        fi
        
        local max_tries=$(get_ssh_config "MaxAuthTries")
        if [[ "$max_tries" =~ ^[0-9]+$ ]]; then
            if [[ $max_tries -le 3 ]]; then
                output+="  ${GREEN}✅ MaxAuthTries: $max_tries${NC}\n"
            else
                output+="  ${YELLOW}⚠️  MaxAuthTries: $max_tries (consider reducing to 3)${NC}\n"
            fi
        fi
        
        local pubkey=$(get_ssh_config "PubkeyAuthentication")
        if [[ "$pubkey" == "yes" ]]; then
            output+="  ${GREEN}✅ PubkeyAuthentication: yes${NC}\n"
        elif [[ "$pubkey" == "no" ]]; then
            output+="  ${RED}⚠️  PubkeyAuthentication: no (consider enabling)${NC}\n"
        else
            output+="  ${YELLOW}⚠️  PubkeyAuthentication: $pubkey${NC}\n"
        fi
        
        # Check AllowUsers/AllowGroups
        local allow_users=$(grep -i "^AllowUsers" /etc/ssh/sshd_config 2>/dev/null | sed 's/AllowUsers //i' || true)
        if [[ -n "$allow_users" ]]; then
            output+="  ${GREEN}✅ AllowUsers configured: $allow_users${NC}\n"
        else
            output+="  ${YELLOW}⚠️  AllowUsers not configured (consider restricting)${NC}\n"
        fi
        
        # Check Protocol version
        local protocol=$(get_ssh_config "Protocol")
        if [[ "$protocol" == "2" ]]; then
            output+="  ${GREEN}✅ Protocol: 2 (good)${NC}\n"
        elif [[ "$protocol" == "1" ]]; then
            output+="  ${RED}⚠️  Protocol: 1 (insecure!)${NC}\n"
        fi
        
        # Check ClientAliveInterval
        local client_alive=$(get_ssh_config "ClientAliveInterval")
        if [[ "$client_alive" =~ ^[0-9]+$ ]]; then
            if [[ $client_alive -le 300 ]]; then
                output+="  ${GREEN}✅ ClientAliveInterval: $client_alive${NC}\n"
            else
                output+="  ${YELLOW}⚠️  ClientAliveInterval: $client_alive (consider reducing)${NC}\n"
            fi
        fi
    fi
    output+="\n"
    
    # Recommendations
    output+="${GREEN}▶ RECOMMENDATIONS${NC}\n"
    if [[ $total_ssh_failures -gt 100 ]]; then
        output+="  ${RED}🔴 CRITICAL: High number of SSH attacks detected!${NC}\n"
        output+="  1. IMMEDIATE: Install and configure fail2ban\n"
        output+="  2. IMMEDIATE: Disable password authentication (use SSH keys)\n"
        output+="  3. IMMEDIATE: Change SSH port from 22\n"
        output+="  4. Use AllowUsers or AllowGroups to restrict access\n"
        output+="  5. Consider using a VPN or bastion host\n"
        output+="  6. Use geoip blocking for high-risk countries\n"
        output+="  7. Review all user accounts and authorized_keys\n"
    elif [[ $total_ssh_failures -gt 10 ]]; then
        output+="  ${YELLOW}🟡 Moderate SSH attack activity${NC}\n"
        output+="  1. Ensure fail2ban is running and properly configured\n"
        output+="  2. Review authorized_keys for unused or suspicious keys\n"
        output+="  3. Consider rate limiting with ufw or iptables\n"
        output+="  4. Audit user accounts regularly\n"
    else
        output+="  ${GREEN}🟢 Low attack activity - continue monitoring${NC}\n"
        output+="  1. Keep fail2ban running and updated\n"
        output+="  2. Regular security audits\n"
        output+="  3. Keep system updated with security patches\n"
        output+="  4. Review logs periodically\n"
    fi
    output+="\n"
    
    # Top attacking countries (if geoip available and enough data)
    if [[ $total_ssh_failures -gt 10 ]]; then
        output+="${GREEN}▶ TOP ATTACKING COUNTRIES${NC}\n"
        local geo_cache="$CACHE_DIR/geo_country.txt"
        extract_ips "$logs" "Failed password" | head -50 | while read -r ip; do
            if ! is_internal_ip "$ip"; then
                local geo=$(geo_lookup "$ip")
                local country=$(echo "$geo" | awk '{print $1}')
                if [[ -n "$country" && "$country" != " " ]]; then
                    echo "$country"
                fi
            fi
        done | sort | uniq -c | sort -rn | head -5 | \
            while read -r count country; do
                if [[ -n "$country" && -n "$count" ]]; then
                    output+="  $country: $count IPs\n"
                fi
            done
        output+="\n"
    fi
    
    output+="${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "$output"
}

# ============================================================
# Watch Mode
# ============================================================

watch_mode() {
    echo -e "${GREEN}🔍 Watching logs for new failed login attempts...${NC}"
    echo -e "Press Ctrl+C to exit\n"
    
    if command -v journalctl &>/dev/null; then
        sudo -n journalctl -f -u sshd -u ssh -o cat 2>/dev/null | while read -r line; do
            if echo "$line" | grep -q "Failed password"; then
                local ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
                local user=$(echo "$line" | grep -o "user [^ ]*" | awk '{print $2}')
                echo -e "${RED}🚨${NC} Failed login attempt - IP: ${RED}$ip${NC} User: ${YELLOW}$user${NC} $(date '+%H:%M:%S')"
                
                # Send immediate alert for critical events
                if [[ -n "$SLACK_WEBHOOK" ]]; then
                    send_slack "🚨 Failed SSH attempt from \`$ip\` as user \`$user\` on $(hostname)" "$SLACK_WEBHOOK"
                fi
            fi
        done
    else
        tail -f "$AUTH_LOG" 2>/dev/null | while read -r line; do
            if echo "$line" | grep -q "Failed password"; then
                local ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
                local user=$(echo "$line" | grep -o "user [^ ]*" | awk '{print $2}')
                echo -e "${RED}🚨${NC} Failed login attempt - IP: ${RED}$ip${NC} User: ${YELLOW}$user${NC} $(date '+%H:%M:%S')"
                
                if [[ -n "$SLACK_WEBHOOK" ]]; then
                    send_slack "🚨 Failed SSH attempt from \`$ip\` as user \`$user\` on $(hostname)" "$SLACK_WEBHOOK"
                fi
            fi
        done
    fi
}

# ============================================================
# Main Execution
# ============================================================

main() {
    if [[ "$WATCH_MODE" == true ]]; then
        watch_mode
        exit 0
    fi
    
    # Get recent logs once (performance optimization)
    local recent_logs=$(get_recent_logs)
    
    # Check if logs are empty
    if [[ -z "$recent_logs" ]]; then
        echo -e "${YELLOW}⚠️  No logs found for the last $HOURS hours${NC}"
        echo "  This might mean:"
        echo "  - No SSH activity during this period"
        echo "  - Log rotation removed older entries"
        echo "  - SSH is not running or logging is disabled"
        exit 0
    fi
    
    # Analyze logs
    local report=$(analyze_logs "$recent_logs" "$JSON_OUTPUT")
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$report"
    else
        echo "$report"
    fi
    
    # Send alerts if configured
    if [[ -n "$EMAIL_RECIPIENT" ]]; then
        send_email "SSH Attack Report - $(hostname)" "$report" "$EMAIL_RECIPIENT"
        if [[ $? -eq 0 ]]; then
            echo -e "\n${GREEN}✅ Report sent to $EMAIL_RECIPIENT${NC}"
        else
            echo -e "\n${YELLOW}⚠️  Failed to send email to $EMAIL_RECIPIENT${NC}"
        fi
    fi
    
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local slack_msg="*SSH Attack Report - $(hostname)*\n"
        slack_msg+="Failures: $(echo "$report" | grep -i "ssh password failures" | sed 's/[^0-9]*//g' || echo "0")\n"
        slack_msg+="Threat Level: $(echo "$report" | grep -i "threat level" | cut -d: -f2 | xargs || echo "Unknown")"
        send_slack "$slack_msg" "$SLACK_WEBHOOK"
        echo -e "\n${GREEN}✅ Report sent to Slack${NC}"
    fi
    
    exit $EXIT_CODE
}

# ============================================================
# Execute
# ============================================================

main
