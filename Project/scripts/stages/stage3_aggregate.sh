
#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  stage3_aggregate.sh — Data Aggregation Stage
#  Reads filtered files, counts occurrences,
#  uses associative arrays to build summaries
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
# AGGREGATION 1 — IP Summary
# Count how many times each IP appears
# across all filtered output files
# Uses a Bash associative array (like a dictionary)
# ────────────────────────────────────────
aggregate_ip_summary() {
    log_info "Aggregating IP activity counts..."

    # Declare associative array: ip -> count
    # Think of it like: ip_counts["192.168.1.1"] = 15
    declare -A ip_counts

    # Process each filtered file
    local files=("$FAILED_LOGINS" "$SUSPICIOUS_IPS" "$SERVER_ERRORS")

    for file in "${files[@]}"; do
        if [ ! -s "$file" ]; then
            continue
        fi

        # Use grep -oE to extract all IP addresses from the file
        # Regex: matches standard IPv4 format
        while IFS= read -r ip; do
            if [ -n "$ip" ]; then
                ip_counts["$ip"]=$(( ${ip_counts["$ip"]:-0} + 1 ))
            fi
        done < <(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$file")
    done

    # Write sorted summary (highest count first)
    > "$IP_SUMMARY"
    {
        echo "═══════════════════════════════════════"
        echo "  IP Activity Summary"
        echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "═══════════════════════════════════════"
        echo ""
        echo "IP Address          | Occurrences | Risk Level"
        echo "─────────────────────────────────────────────"
    } >> "$IP_SUMMARY"

    # Sort IPs by count descending and write to file
    for ip in "${!ip_counts[@]}"; do
        local count=${ip_counts[$ip]}
        local risk="LOW"
        if   [ "$count" -ge 20 ]; then risk="CRITICAL"
        elif [ "$count" -ge 10 ]; then risk="HIGH"
        elif [ "$count" -ge 5  ]; then risk="MEDIUM"
        fi
        printf "%-20s| %-12s| %s\n" "$ip" "$count" "$risk"
    done | sort -t'|' -k2 -rn >> "$IP_SUMMARY"

    local unique_ips=${#ip_counts[@]}
    log_info "  Unique IPs tracked: $unique_ips"
}

# ────────────────────────────────────────
# AGGREGATION 2 — Anomaly Counts
# Count each type of anomaly detected
# ────────────────────────────────────────
aggregate_anomaly_counts() {
    log_info "Aggregating anomaly type counts..."

    # Count each category using grep -c (count matching lines)
    local failed_ssh
    local invalid_users
    local http_errors
    local sys_errors
    local sensitive_hits

    failed_ssh=$(grep -c "Failed password" "$RAW_COLLECTED" 2>/dev/null || echo 0)
    invalid_users=$(grep -c "Invalid user" "$RAW_COLLECTED" 2>/dev/null || echo 0)
    http_errors=$(grep -cE "\" [45][0-9]{2} " "$RAW_COLLECTED" 2>/dev/null || echo 0)
    sys_errors=$(grep -cE "ERROR:" "$RAW_COLLECTED" 2>/dev/null || echo 0)
    sensitive_hits=$(grep -cEi "\.env|wp-admin|/admin|/passwd" "$RAW_COLLECTED" 2>/dev/null || echo 0)

    > "$ANOMALY_COUNTS"
    {
        echo "═══════════════════════════════════════"
        echo "  Anomaly Type Counts"
        echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "═══════════════════════════════════════"
        echo ""
        printf "%-30s %s\n" "Anomaly Type" "Count"
        echo "──────────────────────────────────────"
        printf "%-30s %s\n" "Failed SSH Logins"      "$failed_ssh"
        printf "%-30s %s\n" "Invalid User Attempts"  "$invalid_users"
        printf "%-30s %s\n" "HTTP 4xx/5xx Errors"    "$http_errors"
        printf "%-30s %s\n" "System Errors"          "$sys_errors"
        printf "%-30s %s\n" "Sensitive Path Hits"    "$sensitive_hits"
        echo ""
        printf "%-30s %s\n" "TOTAL" "$((failed_ssh + invalid_users + http_errors + sys_errors + sensitive_hits))"
    } >> "$ANOMALY_COUNTS"

    log_info "  Anomaly counts written to: $ANOMALY_COUNTS"
}

# ────────────────────────────────────────
# AGGREGATION 3 — Usage Statistics
# General stats about the log data
# ────────────────────────────────────────
aggregate_usage_stats() {
    log_info "Aggregating usage statistics..."

    local total_lines
    local total_errors
    local total_success
    local unique_ips
    local time_range_start
    local time_range_end

    total_lines=$(grep -v "^#" "$RAW_COLLECTED" | wc -l)
    total_errors=$(wc -l < "$SERVER_ERRORS" 2>/dev/null || echo 0)
    total_success=$(grep -c "Accepted\|200\|201" "$RAW_COLLECTED" 2>/dev/null || echo 0)
    unique_ips=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$RAW_COLLECTED" | sort -u | wc -l)
    time_range_start=$(grep -v "^#" "$RAW_COLLECTED" | head -1 | awk '{print $1, $2, $3}')
    time_range_end=$(grep -v "^#" "$RAW_COLLECTED" | tail -1 | awk '{print $1, $2, $3}')

    > "$USAGE_STATS"
    {
        echo "═══════════════════════════════════════"
        echo "  Usage Statistics"
        echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "═══════════════════════════════════════"
        echo ""
        printf "%-30s %s\n" "Total Log Lines:"        "$total_lines"
        printf "%-30s %s\n" "Total Error Events:"     "$total_errors"
        printf "%-30s %s\n" "Total Success Events:"   "$total_success"
        printf "%-30s %s\n" "Unique IP Addresses:"    "$unique_ips"
        printf "%-30s %s\n" "Log Start:"              "$time_range_start"
        printf "%-30s %s\n" "Log End:"                "$time_range_end"
    } >> "$USAGE_STATS"

    log_info "  Usage stats written to: $USAGE_STATS"
}

# ────────────────────────────────────────
# MAIN
# ────────────────────────────────────────
run_stage3() {
    log_section "STAGE 3 — Data Aggregation"

    if checkpoint_exists 3; then
        log_warn "Stage 3 already completed. Skipping."
        return 0
    fi

    if ! checkpoint_exists 2; then
        log_error "Stage 2 has not completed yet!"
        exit 1
    fi

    validate_file "$RAW_COLLECTED"    "raw_collected.log"
    validate_file "$FAILED_LOGINS"    "failed_logins.txt"
    validate_file "$SUSPICIOUS_IPS"   "suspicious_ips.txt"

    aggregate_ip_summary
    aggregate_anomaly_counts
    aggregate_usage_stats

    log_success "Stage 3 Complete!"
    log_info "IP Summary:     $IP_SUMMARY"
    log_info "Anomaly Counts: $ANOMALY_COUNTS"
    log_info "Usage Stats:    $USAGE_STATS"

    save_checkpoint 3
}

run_stage3
