#!/usr/bin/env bash
# ssl_check.sh - SSL certificate monitoring

check_ssl_certificates() {
    echo "--- SSL CERTIFICATE CHECK ---"
    
    # Define certificates to check (edit these)
    local cert_paths=(
        "/etc/ssl/certs"
        "/etc/letsencrypt/live"
        "/etc/pki/tls/certs"
    )
    
    # Check common web server cert locations
    if [[ -f /etc/nginx/sites-enabled/* ]]; then
        # Try to extract from nginx configs
        for conf in /etc/nginx/sites-enabled/*; do
            if [[ -f "$conf" ]]; then
                local cert_file=$(grep -h "ssl_certificate" "$conf" 2>/dev/null | grep -v "^#" | awk '{print $2}' | tr -d ';' | head -1)
                if [[ -n "$cert_file" && -f "$cert_file" ]]; then
                    check_single_cert "$cert_file"
                fi
            fi
        done
    fi
    
    # Check Let's Encrypt certificates
    if [[ -d "/etc/letsencrypt/live" ]]; then
        echo "Checking Let's Encrypt certs:"
        for domain in /etc/letsencrypt/live/*; do
            if [[ -d "$domain" && -f "$domain/fullchain.pem" ]]; then
                check_single_cert "$domain/fullchain.pem" "$(basename "$domain")"
            fi
        done
    fi
    
    # Check general cert directories
    for dir in "${cert_paths[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "Checking $dir:"
            find "$dir" -name "*.pem" -o -name "*.crt" -o -name "*.cert" 2>/dev/null | while read -r cert; do
                if [[ -f "$cert" ]]; then
                    check_single_cert "$cert" "  $(basename "$cert")"
                fi
            done
        fi
    done
    
    echo ""
}

# Helper function to check individual certificate
check_single_cert() {
    local cert_file="$1"
    local label="${2:-$(basename "$cert_file")}"
    
    if ! command -v openssl &> /dev/null; then
        echo "⚠️  openssl not installed - cannot check certificates"
        return 1
    fi
    
    # Get expiry date
    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
    if [[ -z "$expiry_date" ]]; then
        echo "  ❌ $label - Could not parse (not a valid certificate?)"
        return
    fi
    
    # Convert to epoch
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
    if [[ -z "$expiry_epoch" ]]; then
        # macOS compatibility
        expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
    fi
    
    local current_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [[ $days_left -lt 0 ]]; then
        echo "  ❌ $label - EXPIRED on $expiry_date"
    elif [[ $days_left -lt 30 ]]; then
        echo "  ⚠️  $label - Expires in $days_left days ($expiry_date) - RENEW NOW!"
    elif [[ $days_left -lt 90 ]]; then
        echo "  ℹ️  $label - Expires in $days_left days ($expiry_date)"
    else
        echo "  ✅ $label - Valid until $expiry_date ($days_left days left)"
    fi
}
