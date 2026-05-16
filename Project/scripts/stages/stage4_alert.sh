#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  stage4_alert.sh — Alert Generation Stage
#  Reads aggregated data, applies thresholds,
#  writes critical/warning alerts, generates final report
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/error_handler.sh"
source "$UTILS_DIR/checkpoint_manager.sh"
source "$UTILS_DIR/validator.sh"
source "$UTILS_DIR/helpers.sh"

# ────────────────────────────────────────
# ALERT FUNCTION 1 — Check Failed Logins
# If any IP exceeds threshold → CRITICAL alert
# ────────────────────────────────────────
check_failed_login_alerts() {
    log_info "Checking failed login thresholds..."

    declare -A ip_counts

    # Count failed logins per IP
    while IFS= read -r ip; do
        [ -n "$ip" ] && ip_counts["$ip"]=$(( ${ip_counts["$ip"]:-0} + 1 ))
    done < <(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$FAILED_LOGINS" 2>/dev/null)

    for ip in "${!ip_counts[@]}"; do
        local count=${ip_counts[$ip]}
        if [ "$count" -ge "$FAILED_LOGIN_THRESHOLD" ]; then
            local alert="[CRITICAL] $(date '+%Y-%m-%d %H:%M:%S') | BRUTE FORCE DETECTED | IP: $ip | Failed Logins: $count (threshold: $FAILED_LOGIN_THRESHOLD)"
            echo "$alert" | tee -a "$CRITICAL_ALERTS" >> "$ALERTS_LOG"
            log_warn "CRITICAL ALERT: $ip has $count failed logins!"
        else
            local alert="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') | Elevated failures | IP: $ip | Count: $count"
            echo "$alert" >> "$WARNING_ALERTS"
        fi
    done
}

# ────────────────────────────────────────
# ALERT FUNCTION 2 — Check Server Errors
# If error count exceeds threshold → alert
# ────────────────────────────────────────
check_server_error_alerts() {
    log_info "Checking server error thresholds..."

    local error_count
    error_count=$(wc -l < "$SERVER_ERRORS" 2>/dev/null || echo 0)

    if [ "$error_count" -ge "$ERROR_THRESHOLD" ]; then
        local alert="[CRITICAL] $(date '+%Y-%m-%d %H:%M:%S') | HIGH ERROR RATE | Total Errors: $error_count (threshold: $ERROR_THRESHOLD)"
        echo "$alert" | tee -a "$CRITICAL_ALERTS" >> "$ALERTS_LOG"
        log_warn "CRITICAL ALERT: $error_count server errors detected!"
    else
        local alert="[INFO] $(date '+%Y-%m-%d %H:%M:%S') | Server errors within normal range: $error_count"
        echo "$alert" >> "$ALERTS_LOG"
        log_info "Server errors OK: $error_count (below threshold)"
    fi
}

# ────────────────────────────────────────
# ALERT FUNCTION 3 — Check Suspicious IPs
# Any IP hitting sensitive paths → alert
# ────────────────────────────────────────
check_suspicious_ip_alerts() {
    log_info "Checking suspicious IP activity..."

    # Read IP summary and flag HIGH/CRITICAL risk IPs
    if [ -f "$IP_SUMMARY" ]; then
        while IFS='|' read -r ip count risk; do
            ip=$(echo "$ip" | tr -d ' ')
            count=$(echo "$count" | tr -d ' ')
            risk=$(echo "$risk" | tr -d ' ')

            if [ "$risk" = "CRITICAL" ]; then
                local alert="[CRITICAL] $(date '+%Y-%m-%d %H:%M:%S') | SUSPICIOUS IP | $ip | $count occurrences | Risk: CRITICAL"
                echo "$alert" | tee -a "$CRITICAL_ALERTS" >> "$ALERTS_LOG"
            elif [ "$risk" = "HIGH" ]; then
                local alert="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') | Suspicious IP | $ip | $count occurrences | Risk: HIGH"
                echo "$alert" | tee -a "$WARNING_ALERTS" >> "$ALERTS_LOG"
            fi
        done < <(grep -E "CRITICAL|HIGH" "$IP_SUMMARY" 2>/dev/null)
    fi
}

# ────────────────────────────────────────
# GENERATE FINAL REPORT
# Combines everything into one clean report
# ────────────────────────────────────────
generate_final_report() {
    log_info "Generating final summary report..."

    local critical_count warning_count
    critical_count=$(wc -l < "$CRITICAL_ALERTS" 2>/dev/null || echo 0)
    warning_count=$(wc -l < "$WARNING_ALERTS"  2>/dev/null || echo 0)

    > "$FINAL_SUMMARY"
    {
        echo "╔══════════════════════════════════════════════════╗"
        echo "║        PIPELINE FINAL SUMMARY REPORT            ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo "║  Generated: $(date '+%Y-%m-%d %H:%M:%S')               ║"
        echo "║  Version:   $PIPELINE_VERSION                             ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo ""
        echo "── ALERT SUMMARY ──────────────────────────────────"
        echo "  Critical Alerts:   $critical_count"
        echo "  Warning Alerts:    $warning_count"
        echo ""
        echo "── ANOMALY COUNTS ─────────────────────────────────"
        cat "$ANOMALY_COUNTS" 2>/dev/null
        echo ""
        echo "── TOP SUSPICIOUS IPs ──────────────────────────────"
        head -20 "$IP_SUMMARY" 2>/dev/null
        echo ""
        echo "── USAGE STATISTICS ────────────────────────────────"
        cat "$USAGE_STATS" 2>/dev/null
        echo ""
        echo "── CRITICAL ALERTS ─────────────────────────────────"
        if [ -s "$CRITICAL_ALERTS" ]; then
            cat "$CRITICAL_ALERTS"
        else
            echo "  No critical alerts."
        fi
        echo ""
        echo "── WARNING ALERTS ──────────────────────────────────"
        if [ -s "$WARNING_ALERTS" ]; then
            cat "$WARNING_ALERTS"
        else
            echo "  No warnings."
        fi
        echo ""
        echo "────────────────────────────────────────────────────"
        echo "  Pipeline completed successfully."
        echo "────────────────────────────────────────────────────"
    } >> "$FINAL_SUMMARY"

    # Also write a daily report
    cp "$FINAL_SUMMARY" "$DAILY_REPORT"

    log_success "Final report: $FINAL_SUMMARY"
}

# ────────────────────────────────────────
# MAIN
# ────────────────────────────────────────
run_stage4() {
    log_section "STAGE 4 — Alert Generation"

    if checkpoint_exists 4; then
        log_warn "Stage 4 already completed. Skipping."
        return 0
    fi

    if ! checkpoint_exists 3; then
        log_error "Stage 3 has not completed yet!"
        exit 1
    fi

    # Clear old alert files before writing fresh ones
    > "$CRITICAL_ALERTS"
    > "$WARNING_ALERTS"
    > "$ALERTS_LOG"

    check_failed_login_alerts
    check_server_error_alerts
    check_suspicious_ip_alerts
    generate_final_report

    local critical_count
    critical_count=$(wc -l < "$CRITICAL_ALERTS" 2>/dev/null || echo 0)

    log_success "Stage 4 Complete!"
    log_info "Critical alerts:  $critical_count"
    log_info "Alerts log:       $ALERTS_LOG"
    log_info "Final report:     $FINAL_SUMMARY"

    save_checkpoint 4
}

run_stage4
