#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  stage2_filter.sh — Anomaly Detection & Filtering Stage
#  Reads raw_collected.log, uses grep/awk to separate
#  suspicious activity into categorized output files
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
# FILTER FUNCTION 1 — Failed Logins
# Uses grep to find all failed SSH attempts
# ────────────────────────────────────────
filter_failed_logins() {
    log_info "Filtering failed login attempts..."

    # grep -E = extended regex
    # -i     = case insensitive
    # We search for these patterns in the collected log
    grep -Ei "Failed password|authentication failure|FAILED LOGIN" \
        "$RAW_COLLECTED" > "$FAILED_LOGINS" 2>/dev/null || true

    local count
    count=$(wc -l < "$FAILED_LOGINS")
    log_info "  Failed logins found: $count"
}

# ────────────────────────────────────────
# FILTER FUNCTION 2 — Suspicious IPs
# Finds IPs hitting sensitive paths or
# generating lots of errors
# ────────────────────────────────────────
filter_suspicious_ips() {
    log_info "Filtering suspicious IP activity..."

    # Combine: sensitive path hits + repeated errors + invalid users
    grep -Ei "\.env|wp-admin|/admin|/passwd|/config|Invalid user|SENSITIVE PATH|WEB PROBE" \
        "$RAW_COLLECTED" > "$SUSPICIOUS_IPS" 2>/dev/null || true

    # Also add HTTP 4xx/5xx hits
    grep -E "\" [45][0-9]{2} " \
        "$RAW_COLLECTED" >> "$SUSPICIOUS_IPS" 2>/dev/null || true

    # Remove duplicates
    sort -u "$SUSPICIOUS_IPS" -o "$SUSPICIOUS_IPS"

    local count
    count=$(wc -l < "$SUSPICIOUS_IPS")
    log_info "  Suspicious IP entries found: $count"
}

# ────────────────────────────────────────
# FILTER FUNCTION 3 — Server Errors
# Finds system-level errors from syslog
# ────────────────────────────────────────
filter_server_errors() {
    log_info "Filtering server errors..."

    grep -Ei "ERROR:|error|Out of memory|Segmentation fault|Disk I/O|Connection refused|SYSTEM ERROR" \
        "$RAW_COLLECTED" > "$SERVER_ERRORS" 2>/dev/null || true

    local count
    count=$(wc -l < "$SERVER_ERRORS")
    log_info "  Server errors found: $count"
}

# ────────────────────────────────────────
# AWK ANALYSIS — Run parsers on raw log
# Saves structured analysis to temp files
# ────────────────────────────────────────
run_awk_parsers() {
    log_info "Running AWK parsers for deep analysis..."
    mkdir -p "$TEMP_DIR/stage2_temp"

    # Auth log analysis
    if validate_file "$AUTH_LOG" "auth.log"; then
        awk -f "$PARSERS_DIR/auth_parser.awk" "$AUTH_LOG" \
            > "$TEMP_DIR/stage2_temp/auth_analysis.txt" 2>/dev/null
        log_debug "Auth parser complete"
    fi

    # Apache log analysis
    if validate_file "$APACHE_LOG" "apache.log"; then
        awk -f "$PARSERS_DIR/apache_parser.awk" "$APACHE_LOG" \
            > "$TEMP_DIR/stage2_temp/apache_analysis.txt" 2>/dev/null
        log_debug "Apache parser complete"
    fi

    # Syslog analysis
    if validate_file "$SYS_LOG" "syslog"; then
        awk -f "$PARSERS_DIR/syslog_parser.awk" "$SYS_LOG" \
            > "$TEMP_DIR/stage2_temp/syslog_analysis.txt" 2>/dev/null
        log_debug "Syslog parser complete"
    fi

    # Full anomaly scan on merged log
    awk -f "$PARSERS_DIR/anomaly_detector.awk" "$RAW_COLLECTED" \
        > "$TEMP_DIR/stage2_temp/anomaly_scan.txt" 2>/dev/null
    log_debug "Anomaly detector complete"

    log_success "AWK parsers finished"
}

# ────────────────────────────────────────
# MAIN
# ────────────────────────────────────────
run_stage2() {
    log_section "STAGE 2 — Anomaly Detection & Filtering"

    # ── Resume check ──
    if checkpoint_exists 2; then
        log_warn "Stage 2 already completed. Skipping."
        return 0
    fi

    # ── Dependency check: Stage 1 must be done first ──
    if ! checkpoint_exists 1; then
        log_error "Stage 1 has not completed yet!"
        log_error "Run Stage 1 first before Stage 2."
        exit 1
    fi

    # ── Validate input exists ──
    validate_file "$RAW_COLLECTED" "raw_collected.log"

    # ── Run all filters ──
    filter_failed_logins
    filter_suspicious_ips
    filter_server_errors
    run_awk_parsers

    # ── Summary ──
    log_success "Stage 2 Complete!"
    log_info "Failed logins:     $(wc -l < "$FAILED_LOGINS") entries"
    log_info "Suspicious IPs:    $(wc -l < "$SUSPICIOUS_IPS") entries"
    log_info "Server errors:     $(wc -l < "$SERVER_ERRORS") entries"
    log_info "AWK analysis:      $TEMP_DIR/stage2_temp/"

    save_checkpoint 2
}

run_stage2
