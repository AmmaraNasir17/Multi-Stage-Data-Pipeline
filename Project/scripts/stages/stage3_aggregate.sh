#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/error_handler.sh"
source "$UTILS_DIR/checkpoint_manager.sh"
source "$UTILS_DIR/validator.sh"
source "$UTILS_DIR/helpers.sh"

aggregate_ip_summary() {
    log_info "Aggregating IP activity counts..."
    declare -A ip_counts
    local files=("$FAILED_LOGINS" "$SUSPICIOUS_IPS" "$SERVER_ERRORS")
    for file in "${files[@]}"; do
        [ ! -s "$file" ] && continue
        while IFS= read -r ip; do
            [ -n "$ip" ] && ip_counts["$ip"]=$(( ${ip_counts["$ip"]:-0} + 1 ))
        done < <(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$file")
    done

    > "$IP_SUMMARY"
    {
        echo "IP Activity Summary -- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        printf "%-20s | %-12s | %s\n" "IP Address" "Occurrences" "Risk Level"
        echo "-----------------------------------------------------"
    } >> "$IP_SUMMARY"

    for ip in "${!ip_counts[@]}"; do
        local count=${ip_counts[$ip]}
        local risk="LOW"
        if   [ "$count" -ge 20 ]; then risk="CRITICAL"
        elif [ "$count" -ge 10 ]; then risk="HIGH"
        elif [ "$count" -ge 5  ]; then risk="MEDIUM"
        fi
        printf "%-20s | %-12s | %s\n" "$ip" "$count" "$risk"
    done | sort -t'|' -k2 -rn >> "$IP_SUMMARY"
}

aggregate_anomaly_counts() {
    log_info "Aggregating anomaly type counts..."
    local failed_ssh invalid_users http_errors sys_errors sensitive_hits
    failed_ssh=$(grep -c "Failed password"    "$RAW_COLLECTED" 2>/dev/null || echo 0)
    invalid_users=$(grep -c "Invalid user"    "$RAW_COLLECTED" 2>/dev/null || echo 0)
    http_errors=$(grep -cE "\" [45][0-9]{2} " "$RAW_COLLECTED" 2>/dev/null || echo 0)
    sys_errors=$(grep -cE "ERROR:"            "$RAW_COLLECTED" 2>/dev/null || echo 0)
    sensitive_hits=$(grep -cEi "\.env|wp-admin|/admin|/passwd" "$RAW_COLLECTED" 2>/dev/null || echo 0)

    > "$ANOMALY_COUNTS"
    {
        echo "Anomaly Type Counts -- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        printf "%-30s %s\n" "Anomaly Type" "Count"
        echo "--------------------------------------"
        printf "%-30s %s\n" "Failed SSH Logins"      "$failed_ssh"
        printf "%-30s %s\n" "Invalid User Attempts"  "$invalid_users"
        printf "%-30s %s\n" "HTTP 4xx/5xx Errors"    "$http_errors"
        printf "%-30s %s\n" "System Errors"          "$sys_errors"
        printf "%-30s %s\n" "Sensitive Path Hits"    "$sensitive_hits"
        echo "--------------------------------------"
        printf "%-30s %s\n" "TOTAL" "$((failed_ssh + invalid_users + http_errors + sys_errors + sensitive_hits))"
    } >> "$ANOMALY_COUNTS"
}

aggregate_usage_stats() {
    log_info "Aggregating usage statistics..."
    local total_lines total_errors total_success unique_ips
    total_lines=$(grep -vc "^#" "$RAW_COLLECTED" || echo 0)
    total_errors=$(wc -l < "$SERVER_ERRORS" 2>/dev/null || echo 0)
    total_success=$(grep -c "Accepted\|200\|201" "$RAW_COLLECTED" 2>/dev/null || echo 0)
    unique_ips=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$RAW_COLLECTED" | sort -u | wc -l)

    > "$USAGE_STATS"
    {
        echo "Usage Statistics -- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        printf "%-30s : %s\n" "Total Log Lines"        "$total_lines"
        printf "%-30s : %s\n" "Total Error Events"     "$total_errors"
        printf "%-30s : %s\n" "Total Success Events"   "$total_success"
        printf "%-30s : %s\n" "Unique IP Addresses"    "$unique_ips"
    } >> "$USAGE_STATS"
}

run_stage3() {
    log_stage 3 "Data Aggregation"

    if checkpoint_exists 3; then
        log_warn "Stage 3 already completed. Skipping."
        return 0
    fi

    if ! checkpoint_exists 2; then
        log_error "Stage 2 has not completed yet!"
        exit 1
    fi

    validate_file "$RAW_COLLECTED"  "raw_collected.log"
    validate_file "$FAILED_LOGINS"  "failed_logins.txt"
    validate_file "$SUSPICIOUS_IPS" "suspicious_ips.txt"

    aggregate_ip_summary
    aggregate_anomaly_counts
    aggregate_usage_stats

    local unique_ips
    unique_ips=$(grep -cE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$IP_SUMMARY" 2>/dev/null || echo 0)

    echo ""
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo -e "${CYAN}  STAGE 3 RESULTS${NC}"
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Unique IPs Tracked"   "$unique_ips"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "IP Summary"           "output/aggregated/ip_summary.txt"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Anomaly Counts"       "output/aggregated/anomaly_counts.txt"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Usage Stats"          "output/aggregated/usage_statistics.txt"
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo ""

    save_checkpoint 3
}

run_stage3