
#!/usr/bin/env bash
# health_check.sh - System health monitoring functions

# Check system load
check_system_load() {
    echo "--- SYSTEM LOAD ---"
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo "Load averages: $load_avg"

    # Check if load is too high (customize threshold)
    local cores=$(nproc)
    local high_load_threshold=$((cores * 2))
    local current_load=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs | cut -d'.' -f1)

    if [[ $current_load -gt $high_load_threshold ]]; then
        echo "⚠️  WARNING: Load average ($current_load) exceeds threshold ($high_load_threshold)"
        echo "Top 5 CPU-consuming processes:"
        ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head -6
    else
        echo "✅ Load is within normal range"
    fi
    echo ""
}

# Check disk usage
check_disk_usage() {
    echo "--- DISK USAGE ---"
    df -h | grep -v "tmpfs" | while read -r line; do
        echo "$line"
        # Check if any partition is above 85%
        local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        if [[ -n "$usage" && "$usage" -gt 85 ]]; then
            echo "⚠️  WARNING: Partition is ${usage}% full!"
        fi
    done
    echo ""
}

# Check memory usage
check_memory_usage() {
    echo "--- MEMORY USAGE ---"
    free -h
    echo ""

    # Check for OOM killer events
    if dmesg | grep -q "Out of memory"; then
        echo "⚠️  OOM Killer has been triggered (check dmesg for details)"
    else
        echo "✅ No OOM events detected"
    fi
    echo ""
}

# Check inodes
check_inodes() {
    echo "--- INODE USAGE ---"
    df -i | grep -v "tmpfs" | while read -r line; do
        echo "$line"
        local inode_usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        if [[ -n "$inode_usage" && "$inode_usage" -gt 85 ]]; then
            echo "⚠️  WARNING: Inode usage is ${inode_usage}% - too many small files!"
        fi
    done
    echo ""
}

# Check failed services
check_failed_services() {
    echo "--- FAILED SERVICES ---"
    local failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [[ $failed -eq 0 ]]; then
        echo "✅ All services are running"
    else
        echo "⚠️  Found $failed failed service(s):"
        systemctl --failed --no-legend
    fi
    echo ""
}

# Check failed SSH logins (last 24 hours)
check_failed_ssh_logins() {
    echo "--- FAILED SSH LOGINS (last 24h) ---"
    if command -v lastb &> /dev/null; then
        local failed_count=$(lastb | grep -c "$(date +%a)" 2>/dev/null || echo "0")
        echo "Failed login attempts today: $failed_count"
        if [[ $failed_count -gt 10 ]]; then
            echo "⚠️  High number of failed SSH attempts detected!"
            echo "Top offending IPs (last 24h):"
            sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
                tail -100 | awk '{print $NF}' | sort | uniq -c | sort -rn | head -5
        else
            echo "✅ SSH brute-force attempts are within normal range"
        fi
    else
        echo "⚠️  'lastb' command not available (try: sudo apt install util-linux)"
    fi
    echo ""
}

# Check cron jobs
check_cron_jobs() {
    echo "--- CRON JOB STATUS ---"
    # Check system crontabs
    if [[ -f /etc/crontab ]]; then
        echo "System crontab entries: $(grep -v '^#' /etc/crontab | grep -v '^$' | wc -l)"
    fi

    # Check user crons
    local user_cron_count=0
    for user in $(cut -d: -f1 /etc/passwd); do
        if crontab -u "$user" -l 2>/dev/null | grep -v '^#' | grep -v '^$' | grep -q .; then
            ((user_cron_count++))
        fi
    done
    echo "Users with active cron jobs: $user_cron_count"

    # Check if cron service is running
    if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
        echo "✅ Cron service is running"
    else
        echo "❌ Cron service is NOT running!"
    fi
    echo ""
}
