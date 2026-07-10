#!/usr/bin/env bash
# maintenance.sh - Maintenance and cleanup functions

# Rotate logs manually (if logrotate fails)
rotate_logs() {
    echo "--- LOG ROTATION ---"
    
    if command -v logrotate &> /dev/null; then
        # Check if logrotate is configured
        if [[ -f /etc/logrotate.conf ]]; then
            echo "✅ logrotate is installed. Running dry-run:"
            logrotate -d /etc/logrotate.conf 2>&1 | grep -v "considering" | head -10
            
            # Actually run logrotate if needed
            echo "Running logrotate..."
            sudo logrotate -f /etc/logrotate.conf 2>/dev/null && echo "✅ Log rotation completed" || echo "⚠️  Log rotation had issues"
        fi
    else
        echo "⚠️  logrotate not installed"
    fi
    
    # Check for large log files (>100MB)
    echo "Large log files (>100MB):"
    find /var/log -type f -size +100M 2>/dev/null | while read -r logfile; do
        echo "⚠️  $logfile ($(du -h "$logfile" | cut -f1))"
    done
    echo ""
}

# Clean up temporary files
cleanup_temp_files() {
    echo "--- TEMP FILE CLEANUP ---"
    
    local temp_dirs=("/tmp" "/var/tmp")
    local age_days=3
    
    for dir in "${temp_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "Cleaning $dir (files older than $age_days days):"
            local old_files=$(find "$dir" -type f -atime +$age_days -not -path "/tmp/.X*" -not -path "/tmp/.ICE*" 2>/dev/null)
            local file_count=$(echo "$old_files" | wc -l)
            
            if [[ $file_count -gt 0 && -n "$old_files" ]]; then
                echo "Found $file_count old files to remove"
                # Actually remove in production - uncomment below
                # echo "$old_files" | xargs rm -f 2>/dev/null && echo "✅ Cleaned $file_count files"
                echo "(Dry-run: would remove $file_count files)"
            else
                echo "✅ No old temporary files found"
            fi
        fi
    done
    echo ""
}

# Clean package manager cache
clean_package_cache() {
    echo "--- PACKAGE CACHE CLEANUP ---"
    
    if command -v apt &> /dev/null; then
        local cache_size=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
        echo "APT cache size: $cache_size"
        echo "Cleaning apt cache..."
        sudo apt clean 2>/dev/null && echo "✅ APT cache cleaned"
        
    elif command -v dnf &> /dev/null; then
        echo "Cleaning DNF cache..."
        sudo dnf clean all 2>/dev/null && echo "✅ DNF cache cleaned"
        
    elif command -v yum &> /dev/null; then
        echo "Cleaning YUM cache..."
        sudo yum clean all 2>/dev/null && echo "✅ YUM cache cleaned"
    fi
    echo ""
}
