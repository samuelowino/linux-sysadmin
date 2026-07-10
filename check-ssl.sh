#!/usr/bin/env bash
# check-ssl.sh - Check SSL/TLS certificate expiration
# Usage: ./check-ssl.sh [domain.com] or check all local certs

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SSL CERTIFICATE CHECK - $(hostname)${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if OpenSSL is installed
if ! command -v openssl &>/dev/null; then
    echo -e "${RED}❌ OpenSSL not installed!${NC}"
    echo "  Install: sudo apt install openssl  or  sudo dnf install openssl"
    exit 1
fi

# Function to check a certificate file
check_cert_file() {
    local cert="$1"
    local name="$2"
    
    if [[ ! -f "$cert" ]]; then
        return 1
    fi
    
    expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
    if [[ -z "$expiry" ]]; then
        echo -e "  ${RED}❌ Cannot parse certificate: $name${NC}"
        return 1
    fi
    
    # Convert to epoch (Linux)
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
    if [[ "$expiry_epoch" -eq 0 ]]; then
        # macOS
        expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry" +%s 2>/dev/null || echo "0")
    fi
    
    current_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [[ $days_left -lt 0 ]]; then
        echo -e "  ${RED}❌ EXPIRED on $expiry${NC}"
    elif [[ $days_left -lt 7 ]]; then
        echo -e "  ${RED}⚠️  CRITICAL: $days_left days left ($expiry)${NC}"
    elif [[ $days_left -lt 30 ]]; then
        echo -e "  ${YELLOW}⚠️  $days_left days left ($expiry) - RENEW SOON!${NC}"
    else
        echo -e "  ${GREEN}✅ $days_left days left ($expiry)${NC}"
    fi
}

# If domain provided as argument, check it remotely
if [[ $# -gt 0 ]]; then
    domain="$1"
    port="${2:-443}"
    echo -e "\n${GREEN}▶ REMOTE CERTIFICATE: $domain:$port${NC}"
    
    if timeout 5 openssl s_client -connect "${domain}:${port}" -servername "$domain" < /dev/null 2>/dev/null | openssl x509 -enddate -noout 2>/dev/null; then
        cert_info=$(timeout 5 openssl s_client -connect "${domain}:${port}" -servername "$domain" < /dev/null 2>/dev/null | openssl x509 -enddate -noout 2>/dev/null)
        expiry=$(echo "$cert_info" | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
        current_epoch=$(date +%s)
        days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
        echo "  Expires: $expiry"
        echo -e "  Days left: $days_left"
        if [[ $days_left -lt 30 ]]; then
            echo -e "  ${RED}⚠️  Certificate expiring soon!${NC}"
        else
            echo -e "  ${GREEN}✅ Certificate is valid${NC}"
        fi
    else
        echo -e "  ${RED}❌ Cannot connect to $domain:$port${NC}"
    fi
    exit 0
fi

# Check local certificate files
echo -e "\n${GREEN}▶ LOCAL CERTIFICATES${NC}"

# Common certificate locations
cert_dirs=(
    "/etc/ssl/certs"
    "/etc/letsencrypt/live"
    "/etc/pki/tls/certs"
    "/usr/local/share/ca-certificates"
)

found_certs=false

for dir in "${cert_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "  Checking: $dir"
        find "$dir" -type f \( -name "*.pem" -o -name "*.crt" -o -name "*.cert" \) 2>/dev/null | while read -r cert; do
            check_cert_file "$cert" "$(basename "$cert")"
            found_certs=true
        done
    fi
done

# Check Let's Encrypt specific
if [[ -d "/etc/letsencrypt/live" ]]; then
    echo -e "\n${GREEN}▶ LET'S ENCRYPT CERTIFICATES${NC}"
    for domain_dir in /etc/letsencrypt/live/*/; do
        if [[ -f "${domain_dir}fullchain.pem" ]]; then
            domain=$(basename "$domain_dir")
            echo "  Domain: $domain"
            check_cert_file "${domain_dir}fullchain.pem" "$domain"
        fi
    done
fi

if [[ "$found_certs" == false ]]; then
    echo -e "  ${YELLOW}⚠️  No local certificate files found${NC}"
fi

# Check web server configs for certs
echo -e "\n${GREEN}▶ CERTIFICATES IN WEB SERVER CONFIGS${NC}"
if [[ -d "/etc/nginx" ]]; then
    grep -r "ssl_certificate" /etc/nginx/ 2>/dev/null | grep -v "^#" | awk '{print $2}' | tr -d ';' | sort -u | while read -r cert; do
        if [[ -f "$cert" ]]; then
            echo "  Nginx: $(basename "$cert")"
            check_cert_file "$cert" "$(basename "$cert")"
        fi
    done
fi

if [[ -d "/etc/apache2" ]]; then
    grep -r "SSLCertificateFile" /etc/apache2/ 2>/dev/null | grep -v "^#" | awk '{print $2}' | sort -u | while read -r cert; do
        if [[ -f "$cert" ]]; then
            echo "  Apache: $(basename "$cert")"
            check_cert_file "$cert" "$(basename "$cert")"
        fi
    done
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
