#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  generate_alerts.sh — Detailed Alert Generator
#  Produces categorized alerts with severity levels,
#  timestamps, and recommended actions for each alert.
#  Usage: bash scripts/alerts/generate_alerts.sh
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/validator.sh"

# ════════════════════════════════════════
# ALERT COUNTER
# Tracks how many of each level we fire
# ════════════════════════════════════════
ALERT_COUNT_CRITICAL=0
ALERT_COUNT_HIGH=0
ALERT_COUNT_MEDIUM=0
ALERT_COUNT_LOW=0

# ════════════════════════════════════════
# CORE ALERT WRITER
# Every alert goes through this function
# ════════════════════════════════════════
write_alert() {
    local severity="$1"    # CRITICAL HIGH MEDIUM LOW
    local category="$2"    # SSH WEB SYSTEM etc
    local message="$3"     # what happened
    local action="$4"      # what to do about it
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local entry="[$timestamp] [$severity] [$category] $message | ACTION: $action"

    # Write to main alerts log
    echo "$entry" >> "$ALERTS_LOG"

    # Write to severity-specific file
    case "$severity" in
        CRITICAL|HIGH)
            echo "$entry" >> "$CRITICAL_ALERTS"
            ALERT_COUNT_CRITICAL=$((ALERT_COUNT_CRITICAL + 1))
            ;;
        MEDIUM)
            echo "$entry" >> "$WARNING_ALERTS"
            ALERT_COUNT_HIGH=$((ALERT_COUNT_HIGH + 1))
            ;;
        LOW)
            echo "$entry" >> "$WARNING_ALERTS"
            ALERT_COUNT_MEDIUM=$((ALERT_COUNT_MEDIUM + 1))
            ;;
    esac

    # Print to terminal with color
    case "$severity" in
        CRITICAL) echo -e "${RED}[CRITICAL]${NC} [$category] $message" ;;
        HIGH)     echo -e "${RED}[HIGH]${NC}     [$category] $message" ;;
        MEDIUM)   echo -e "${YELLOW}[MEDIUM]${NC}  [$category] $message" ;;
        LOW)      echo -e "${BLUE}[LOW]${NC}     [$category] $message" ;;
    esac
}

# ════════════════════════════════════════
# CATEGORY 1 — SSH BRUTE FORCE ALERTS
# ════════════════════════════════════════
check_ssh_alerts() {
    log_info "Checking SSH brute force activity..."

    if [ ! -s "$FAILED_LOGINS" ]; then
        log_warn "No failed logins file found — skipping SSH check"
        return
    fi

    # Count failed logins per IP using associative array
    declare -A ip_counts
    while IFS= read -r ip; do
        [ -n "$ip" ] && ip_counts["$ip"]=$(( ${ip_counts["$ip"]:-0} + 1 ))
    done < <(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$FAILED_LOGINS")

    for ip in "${!ip_counts[@]}"; do
        local count=${ip_counts[$ip]}

        if [ "$count" -ge 50 ]; then
            write_alert "CRITICAL" "SSH" \
                "EXTREME brute force from $ip — $count attempts" \
                "Block IP immediately: sudo ufw deny from $ip"

        elif [ "$count" -ge 20 ]; then
            write_alert "CRITICAL" "SSH" \
                "Brute force attack from $ip — $count attempts" \
                "Block IP: sudo ufw deny from $ip to any port 22"

        elif [ "$count" -ge "$FAILED_LOGIN_THRESHOLD" ]; then
            write_alert "HIGH" "SSH" \
                "Elevated failed logins from $ip — $count attempts" \
                "Monitor IP and consider blocking port 22 access"

        elif [ "$count" -ge 2 ]; then
            write_alert "MEDIUM" "SSH" \
                "Multiple failed logins from $ip — $count attempts" \
                "Watch this IP for further activity"
        fi
    done

    # Check for invalid user attempts
    local invalid_count
    invalid_count=$(grep -c "Invalid user" "$FAILED_LOGINS" 2>/dev/null || echo 0)
    if [ "$invalid_count" -gt 5 ]; then
        write_alert "HIGH" "SSH" \
            "Invalid user attempts detected — $invalid_count tries" \
            "Check for username enumeration attack"
    fi
}

# ════════════════════════════════════════
# CATEGORY 2 — WEB SERVER ALERTS
# ════════════════════════════════════════
check_web_alerts() {
    log_info "Checking web server activity..."

    if [ ! -s "$SUSPICIOUS_IPS" ]; then
        log_warn "No suspicious IPs file — skipping web check"
        return
    fi

    # Count HTTP 4xx errors
    local err4xx err5xx
    err4xx=$(grep -cE "\" 4[0-9]{2} " "$SUSPICIOUS_IPS" 2>/dev/null || echo 0)
    err5xx=$(grep -cE "\" 5[0-9]{2} " "$SUSPICIOUS_IPS" 2>/dev/null || echo 0)

    if [ "$err5xx" -ge 20 ]; then
        write_alert "CRITICAL" "WEB" \
            "Massive server errors — $err5xx HTTP 5xx responses" \
            "Check web server logs and application health immediately"
    elif [ "$err5xx" -ge 10 ]; then
        write_alert "HIGH" "WEB" \
            "High server error rate — $err5xx HTTP 5xx responses" \
            "Investigate application errors in apache/nginx logs"
    fi

    if [ "$err4xx" -ge 30 ]; then
        write_alert "HIGH" "WEB" \
            "Excessive client errors — $err4xx HTTP 4xx responses" \
            "Possible scanning or probing activity — review access logs"
    elif [ "$err4xx" -ge 10 ]; then
        write_alert "MEDIUM" "WEB" \
            "Elevated client errors — $err4xx HTTP 4xx responses" \
            "Monitor for scanning patterns"
    fi

    # Check for sensitive path probing
    local env_hits admin_hits wp_hits
    env_hits=$(grep -c "\.env"     "$SUSPICIOUS_IPS" 2>/dev/null || echo 0)
    admin_hits=$(grep -c "/admin"  "$SUSPICIOUS_IPS" 2>/dev/null || echo 0)
    wp_hits=$(grep -c "wp-admin"   "$SUSPICIOUS_IPS" 2>/dev/null || echo 0)

    [ "$env_hits" -gt 0 ] && write_alert "CRITICAL" "WEB" \
        ".env file probed $env_hits times — credentials may be targeted" \
        "Ensure .env is not web-accessible. Block probing IP."

    [ "$admin_hits" -gt 5 ] && write_alert "HIGH" "WEB" \
        "Admin panel probed $admin_hits times" \
        "Enable rate limiting on /admin. Consider IP whitelist."

    [ "$wp_hits" -gt 0 ] && write_alert "MEDIUM" "WEB" \
        "WordPress admin probed $wp_hits times" \
        "Block wp-admin access from unknown IPs"
}

# ════════════════════════════════════════
# CATEGORY 3 — SYSTEM ERROR ALERTS
# ════════════════════════════════════════
check_system_alerts() {
    log_info "Checking system health..."

    if [ ! -s "$SERVER_ERRORS" ]; then
        log_warn "No server errors file — skipping system check"
        return
    fi

    local total_errors
    total_errors=$(wc -l < "$SERVER_ERRORS")

    # Overall error volume
    if [ "$total_errors" -ge 50 ]; then
        write_alert "CRITICAL" "SYSTEM" \
            "System error storm — $total_errors errors logged" \
            "Immediate investigation required — check all services"
    elif [ "$total_errors" -ge "$ERROR_THRESHOLD" ]; then
        write_alert "HIGH" "SYSTEM" \
            "High system error count — $total_errors errors" \
            "Review error logs: cat $SERVER_ERRORS"
    fi

    # Specific critical errors
    local oom_count segfault_count disk_count
    oom_count=$(grep -c "Out of memory"      "$SERVER_ERRORS" 2>/dev/null || echo 0)
    segfault_count=$(grep -c "Segmentation" "$SERVER_ERRORS" 2>/dev/null || echo 0)
    disk_count=$(grep -c "Disk I/O"         "$SERVER_ERRORS" 2>/dev/null || echo 0)

    [ "$oom_count" -gt 0 ] && write_alert "CRITICAL" "SYSTEM" \
        "Out of memory errors — $oom_count occurrences" \
        "Check memory usage: free -h. Consider adding swap or RAM."

    [ "$segfault_count" -gt 0 ] && write_alert "CRITICAL" "SYSTEM" \
        "Segmentation faults — $segfault_count occurrences" \
        "Check for corrupted binaries or memory issues"

    [ "$disk_count" -gt 0 ] && write_alert "HIGH" "SYSTEM" \
        "Disk I/O errors — $disk_count occurrences" \
        "Check disk health: sudo smartctl -a /dev/sda"
}

# ════════════════════════════════════════
# CATEGORY 4 — IP REPUTATION ALERTS
# ════════════════════════════════════════
check_ip_reputation_alerts() {
    log_info "Checking IP reputation..."

    if [ ! -f "$IP_SUMMARY" ]; then
        log_warn "No IP summary file — skipping reputation check"
        return
    fi

    # Extract critical risk IPs from summary
    local critical_ips
    critical_ips=$(grep "CRITICAL" "$IP_SUMMARY" 2>/dev/null | awk -F'|' '{print $1}' | tr -d ' ')

    while IFS= read -r ip; do
        [ -z "$ip" ] && continue
        local occurrences
        occurrences=$(grep "^$ip" "$IP_SUMMARY" 2>/dev/null | awk -F'|' '{print $2}' | tr -d ' ')
        write_alert "CRITICAL" "REPUTATION" \
            "IP $ip flagged CRITICAL — $occurrences total suspicious events" \
            "Block this IP: sudo ufw deny from $ip"
    done <<< "$critical_ips"
}

# ════════════════════════════════════════
# WRITE ALERT SUMMARY HEADER
# ════════════════════════════════════════
write_alert_header() {
    local header_file="$ALERTS_OUT_DIR/alert_header.txt"
    {
        echo "╔══════════════════════════════════════════════════╗"
        echo "║           DETAILED ALERT REPORT                  ║"
        echo "║  Generated: $(date '+%Y-%m-%d %H:%M:%S')               ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo ""
        echo "Severity Levels:"
        echo "  CRITICAL — Immediate action required"
        echo "  HIGH     — Action required within 1 hour"
        echo "  MEDIUM   — Review within 24 hours"
        echo "  LOW      — Monitor and log"
        echo ""
        echo "──────────────────────────────────────────────────"
        echo ""
    } > "$header_file"
}

# ════════════════════════════════════════
# PRINT ALERT SUMMARY
# ════════════════════════════════════════
print_alert_summary() {
    echo ""
    echo -e "${BLUE}═══ Alert Generation Summary ═══${NC}"
    echo -e "  ${RED}Critical/High:${NC} $ALERT_COUNT_CRITICAL"
    echo -e "  ${YELLOW}Medium:${NC}       $ALERT_COUNT_HIGH"
    echo -e "  ${BLUE}Low:${NC}          $ALERT_COUNT_MEDIUM"
    echo ""
    local total=$((ALERT_COUNT_CRITICAL + ALERT_COUNT_HIGH + ALERT_COUNT_MEDIUM))
    echo -e "  Total alerts generated: $total"
    echo ""
}

# ════════════════════════════════════════
# MAIN
# ════════════════════════════════════════
main() {
    init_logger
    log_section "Detailed Alert Generation"

    # Validate required input files exist
    validate_output_dirs

    # Clear old alert files
    > "$ALERTS_LOG"
    > "$CRITICAL_ALERTS"
    > "$WARNING_ALERTS"

    # Write header
    write_alert_header

    # Run all checks
    check_ssh_alerts
    check_web_alerts
    check_system_alerts
    check_ip_reputation_alerts

    # Summary
    print_alert_summary

    log_success "Alert generation complete"
    log_info "Critical alerts: $ALERTS_OUT_DIR/critical_alerts.txt"
    log_info "Warning alerts:  $ALERTS_OUT_DIR/warning_alerts.txt"
    log_info "Full log:        $ALERTS_LOG"
}

main "$@"
