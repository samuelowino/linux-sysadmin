#!/usr/bin/env bash
# security_check.sh - Security-focused functions

# Check security updates
check_security_updates() {
    echo "--- SECURITY UPDATES ---"
    
    if command -v apt &> /dev/null; then
        # Debian/Ubuntu
        local updates=$(apt list --upgradable 2>/dev/null | grep -c "security")
        echo "Security updates available: $updates"
        if [[ $updates -gt 0 ]]; then
            echo "⚠️  Security updates are available. Run: sudo apt upgrade"
            echo "Recent security packages:"
            apt list --upgradable 2>/dev/null | grep security | head -5
        else
            echo "✅ All security packages are up-to-date"
        fi
        
    elif command -v dnf &> /dev/null; then
        # RHEL/Fedora
        local updates=$(dnf check-update --security 2>/dev/null | grep -c "security" || echo "0")
        echo "Security updates available: $updates"
        if [[ $updates -gt 0 ]]; then
            echo "⚠️  Security updates are available. Run: sudo dnf upgrade --security"
        else
            echo "✅ All security packages are up-to-date"
        fi
        
    elif command -v yum &> /dev/null; then
        # Older RHEL/CentOS
        local updates=$(yum check-update --security 2>/dev/null | grep -c "security" || echo "0")
        echo "Security updates available: $updates"
        if [[ $updates -gt 0 ]]; then
            echo "⚠️  Security updates are available. Run: sudo yum update --security"
        else
            echo "✅ All security packages are up-to-date"
        fi
    fi
    echo ""
}

# Check suspicious users
check_suspicious_users() {
    echo "--- USER ACCOUNT CHECK ---"
    
    # Check for users with UID 0 (root privileges)
    local root_users=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
    if [[ "$root_users" != "root" ]]; then
        echo "⚠️  Multiple users with UID 0 found: $root_users"
    else
        echo "✅ Only root has UID 0"
    fi
    
    # Check for users with empty passwords
    local empty_passwd=$(sudo awk -F: '($2 == "" || $2 == "*" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null)
    if [[ -n "$empty_passwd" ]]; then
        echo "⚠️  Users with no password or locked accounts: $empty_passwd"
    fi
    
    # Check for users with login shells that shouldn't have them
    local suspicious_shells=("/bin/bash" "/bin/sh" "/bin/zsh")
    local system_users=("daemon" "bin" "sys" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody" "systemd-network" "systemd-resolve" "messagebus" "syslog" "_apt" "uuidd" "tcpdump" "sshd" "landscape" "pollinate")
    
    for shell in "${suspicious_shells[@]}"; do
        for user in $(awk -F: -v s="$shell" '($NF == s) {print $1}' /etc/passwd); do
            local is_system=false
            for sysuser in "${system_users[@]}"; do
                if [[ "$user" == "$sysuser" ]]; then
                    is_system=true
                    break
                fi
            done
            if [[ "$is_system" == false ]]; then
                echo "ℹ️  Non-system user with shell access: $user"
            fi
        done
    done
    
    # Check for users who haven't logged in recently
    local stale_days=90
    echo "Users inactive for > $stale_days days:"
    lastlog | awk -v days="$stale_days" 'NR>1 && $NF > days {print $1, $NF, $3, $4, $5}' | head -5
    
    echo ""
}

# Check open ports
check_open_ports() {
    echo "--- OPEN PORTS ---"
    
    if command -v ss &> /dev/null; then
        # Listening ports with process info
        echo "Listening ports (TCP/UDP):"
        ss -tulpn | grep LISTEN | awk '{print $1, $4, $6}' | sed 's/users:(("//g' | sed 's/",.*//g'
    elif command -v netstat &> /dev/null; then
        netstat -tulpn | grep LISTEN
    else
        echo "⚠️  Neither 'ss' nor 'netstat' found"
    fi
    echo ""
}

# Check firewall status
check_firewall_status() {
    echo "--- FIREWALL STATUS ---"
    
    if command -v ufw &> /dev/null; then
        ufw status | head -5
    elif command -v firewalld &> /dev/null; then
        sudo firewall-cmd --state 2>/dev/null && sudo firewall-cmd --list-all
    elif command -v iptables &> /dev/null; then
        sudo iptables -L -n | head -10
        echo "... (use 'iptables -L -n' for full list)"
    else
        echo "⚠️  No firewall detected"
    fi
    echo ""
}
