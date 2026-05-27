#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/error_handler.sh"
source "$UTILS_DIR/checkpoint_manager.sh"
source "$UTILS_DIR/validator.sh"
source "$UTILS_DIR/helpers.sh"

filter_failed_logins() {
    log_info "Filtering failed login attempts..."
    grep -Ei "Failed password|authentication failure|FAILED LOGIN" \
        "$RAW_COLLECTED" > "$FAILED_LOGINS" 2>/dev/null || true
}

filter_suspicious_ips() {
    log_info "Filtering suspicious IP activity..."
    grep -Ei "\.env|wp-admin|/admin|/passwd|/config|Invalid user|SENSITIVE PATH|WEB PROBE" \
        "$RAW_COLLECTED" > "$SUSPICIOUS_IPS" 2>/dev/null || true
    grep -E "\" [45][0-9]{2} " \
        "$RAW_COLLECTED" >> "$SUSPICIOUS_IPS" 2>/dev/null || true
    sort -u "$SUSPICIOUS_IPS" -o "$SUSPICIOUS_IPS"
}

filter_server_errors() {
    log_info "Filtering server errors..."
    grep -Ei "ERROR:|error|Out of memory|Segmentation fault|Disk I/O|Connection refused|SYSTEM ERROR" \
        "$RAW_COLLECTED" > "$SERVER_ERRORS" 2>/dev/null || true
}

run_awk_parsers() {
    log_info "Running AWK parsers for deep analysis..."
    mkdir -p "$TEMP_DIR/stage2_temp"
    if validate_file "$AUTH_LOG" "auth.log"; then
        awk -f "$PARSERS_DIR/auth_parser.awk" "$AUTH_LOG" \
            > "$TEMP_DIR/stage2_temp/auth_analysis.txt" 2>/dev/null
    fi
    if validate_file "$APACHE_LOG" "apache.log"; then
        awk -f "$PARSERS_DIR/apache_parser.awk" "$APACHE_LOG" \
            > "$TEMP_DIR/stage2_temp/apache_analysis.txt" 2>/dev/null
    fi
    if validate_file "$SYS_LOG" "syslog"; then
        awk -f "$PARSERS_DIR/syslog_parser.awk" "$SYS_LOG" \
            > "$TEMP_DIR/stage2_temp/syslog_analysis.txt" 2>/dev/null
    fi
    awk -f "$PARSERS_DIR/anomaly_detector.awk" "$RAW_COLLECTED" \
        > "$TEMP_DIR/stage2_temp/anomaly_scan.txt" 2>/dev/null
    log_success "AWK parsers finished"
}

run_stage2() {
    log_stage 2 "Anomaly Detection and Filtering"

    if checkpoint_exists 2; then
        log_warn "Stage 2 already completed. Skipping."
        return 0
    fi

    if ! checkpoint_exists 1; then
        log_error "Stage 1 has not completed yet!"
        exit 1
    fi

    validate_file "$RAW_COLLECTED" "raw_collected.log"

    filter_failed_logins
    filter_suspicious_ips
    filter_server_errors
    run_awk_parsers

    echo ""
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo -e "${CYAN}  STAGE 2 RESULTS${NC}"
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Failed Logins"     "$(wc -l < "$FAILED_LOGINS") entries"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Suspicious IPs"    "$(wc -l < "$SUSPICIOUS_IPS") entries"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Server Errors"     "$(wc -l < "$SERVER_ERRORS") entries"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "AWK Analysis"      "temp/stage2_temp/"
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo ""

    save_checkpoint 2
}

run_stage2