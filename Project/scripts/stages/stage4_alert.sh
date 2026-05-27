#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/error_handler.sh"
source "$UTILS_DIR/checkpoint_manager.sh"
source "$UTILS_DIR/validator.sh"
source "$UTILS_DIR/helpers.sh"

check_failed_login_alerts() {
    log_info "Checking failed login thresholds..."
    declare -A ip_counts
    while IFS= read -r ip; do
        [ -n "$ip" ] && ip_counts["$ip"]=$(( ${ip_counts["$ip"]:-0} + 1 ))
    done < <(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$FAILED_LOGINS" 2>/dev/null)
    for ip in "${!ip_counts[@]}"; do
        local count=${ip_counts[$ip]}
        if [ "$count" -ge "$FAILED_LOGIN_THRESHOLD" ]; then
            local alert="[CRITICAL] $(date '+%Y-%m-%d %H:%M:%S') | BRUTE FORCE DETECTED | IP: $ip | Failed Logins: $count (threshold: $FAILED_LOGIN_THRESHOLD)"
            echo "$alert" | tee -a "$CRITICAL_ALERTS" >> "$ALERTS_LOG"
            log_warn "CRITICAL: $ip has $count failed logins"
        else
            echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') | Elevated failures | IP: $ip | Count: $count" >> "$WARNING_ALERTS"
        fi
    done
}

check_server_error_alerts() {
    log_info "Checking server error thresholds..."
    local error_count
    error_count=$(wc -l < "$SERVER_ERRORS" 2>/dev/null || echo 0)
    if [ "$error_count" -ge "$ERROR_THRESHOLD" ]; then
        local alert="[CRITICAL] $(date '+%Y-%m-%d %H:%M:%S') | HIGH ERROR RATE | Total Errors: $error_count (threshold: $ERROR_THRESHOLD)"
        echo "$alert" | tee -a "$CRITICAL_ALERTS" >> "$ALERTS_LOG"
        log_warn "CRITICAL: $error_count server errors detected"
    else
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') | Server errors normal: $error_count" >> "$ALERTS_LOG"
        log_info "Server errors OK: $error_count"
    fi
}

check_suspicious_ip_alerts() {
    log_info "Checking suspicious IP activity..."
    if [ -f "$IP_SUMMARY" ]; then
        while IFS='|' read -r ip count risk; do
            ip=$(echo "$ip"     | tr -d ' ')
            count=$(echo "$count" | tr -d ' ')
            risk=$(echo "$risk"  | tr -d ' ')
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

generate_final_report() {
    log_info "Generating final summary report..."
    local critical_count warning_count total_lines unique_ips
    critical_count=$(wc -l < "$CRITICAL_ALERTS" 2>/dev/null || echo 0)
    warning_count=$(wc -l  < "$WARNING_ALERTS"  2>/dev/null || echo 0)
    total_lines=$(grep -vc "^#" "$RAW_COLLECTED" 2>/dev/null || echo 0)
    unique_ips=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$RAW_COLLECTED" 2>/dev/null | sort -u | wc -l)

    > "$FINAL_SUMMARY"
    {
        echo "========================================================"
        echo "         SECURITY PIPELINE FINAL REPORT"
        echo "========================================================"
        printf "  %-18s : %s\n" "Generated"  "$(date '+%Y-%m-%d %H:%M:%S')"
        printf "  %-18s : %s\n" "Version"    "$PIPELINE_VERSION"
        printf "  %-18s : %s\n" "Host"       "$(hostname)"
        echo "========================================================"
        echo ""
        echo "--------------------------------------------------------"
        echo "  EXECUTIVE SUMMARY"
        echo "--------------------------------------------------------"
        printf "  %-30s : %s\n" "Total Log Lines Processed"  "$total_lines"
        printf "  %-30s : %s\n" "Unique IP Addresses"        "$unique_ips"
        printf "  %-30s : %s\n" "Critical Alerts"            "$critical_count"
        printf "  %-30s : %s\n" "Warning Alerts"             "$warning_count"
        echo ""
        echo "--------------------------------------------------------"
        echo "  ANOMALY BREAKDOWN"
        echo "--------------------------------------------------------"
        printf "  %-34s  %s\n" "Anomaly Type" "Count"
        echo "  ......................................................."
        grep -E "^(Failed|Invalid|HTTP|System|Sensitive|TOTAL)" "$ANOMALY_COUNTS" 2>/dev/null | while IFS= read -r line; do
            atype=$(echo "$line" | awk '{$(NF)=""; print}' | sed 's/[[:space:]]*$//')
            acount=$(echo "$line" | awk '{print $NF}')
            printf "  %-34s  %s\n" "$atype" "$acount"
        done
        echo ""
        echo "--------------------------------------------------------"
        echo "  IP RISK SUMMARY"
        echo "--------------------------------------------------------"
        printf "  %-22s  %-12s  %s\n" "IP Address" "Occurrences" "Risk Level"
        echo "  ......................................................."
        grep -E "CRITICAL|HIGH|MEDIUM|LOW" "$IP_SUMMARY" 2>/dev/null | while IFS='|' read -r ip count risk; do
            ip=$(echo "$ip"       | tr -d ' ')
            count=$(echo "$count" | tr -d ' ')
            risk=$(echo "$risk"   | tr -d ' ')
            printf "  %-22s  %-12s  %s\n" "$ip" "$count" "$risk"
        done
        echo ""
        echo "--------------------------------------------------------"
        echo "  CRITICAL ALERTS"
        echo "--------------------------------------------------------"
        if [ -s "$CRITICAL_ALERTS" ]; then
            cat "$CRITICAL_ALERTS"
        else
            echo "  No critical alerts."
        fi
        echo ""
        echo "--------------------------------------------------------"
        echo "  WARNING ALERTS"
        echo "--------------------------------------------------------"
        if [ -s "$WARNING_ALERTS" ]; then
            cat "$WARNING_ALERTS"
        else
            echo "  No warnings."
        fi
        echo ""
        echo "--------------------------------------------------------"
        echo "  USAGE STATISTICS"
        echo "--------------------------------------------------------"
        grep -E "^[A-Za-z]" "$USAGE_STATS" 2>/dev/null | while IFS= read -r line; do
            key=$(echo "$line" | cut -d: -f1 | xargs)
            val=$(echo "$line" | cut -d: -f2- | xargs)
            printf "  %-30s : %s\n" "$key" "$val"
        done
        echo ""
        echo "========================================================"
        printf "  Pipeline completed at %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================================"
    } >> "$FINAL_SUMMARY"

    cp "$FINAL_SUMMARY" "$DAILY_REPORT"
    log_success "Final report generated"
}

run_stage4() {
    log_stage 4 "Alert Generation"

    if checkpoint_exists 4; then
        log_warn "Stage 4 already completed. Skipping."
        return 0
    fi

    if ! checkpoint_exists 3; then
        log_error "Stage 3 has not completed yet!"
        exit 1
    fi

    > "$CRITICAL_ALERTS"
    > "$WARNING_ALERTS"
    > "$ALERTS_LOG"

    check_failed_login_alerts
    check_server_error_alerts
    check_suspicious_ip_alerts
    generate_final_report

    local critical_count
    critical_count=$(wc -l < "$CRITICAL_ALERTS" 2>/dev/null || echo 0)

    echo ""
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo -e "${CYAN}  STAGE 4 RESULTS${NC}"
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    printf  "  %-25s : ${RED}%s${NC}\n"    "Critical Alerts"    "$critical_count"
    printf  "  %-25s : ${YELLOW}%s${NC}\n" "Warning Alerts"     "$(wc -l < "$WARNING_ALERTS")"
    printf  "  %-25s : ${WHITE}%s${NC}\n"  "Alerts Log"         "output/alerts/alerts.log"
    printf  "  %-25s : ${WHITE}%s${NC}\n"  "Final Report"       "output/reports/final_summary.txt"
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo ""

    save_checkpoint 4
}

run_stage4