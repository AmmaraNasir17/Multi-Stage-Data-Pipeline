#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

check_threshold() {
    local value="$1"
    local threshold="$2"
    local label="$3"
    local unit="${4:-}"

    if ! [[ "$value" =~ ^[0-9]+$ ]] || ! [[ "$threshold" =~ ^[0-9]+$ ]]; then
        log_error "Invalid numbers: value=$value threshold=$threshold"
        return 2
    fi

    local percent=$(( (value * 100) / threshold ))

    if [ "$value" -ge "$threshold" ]; then
        echo -e "${RED}[EXCEEDED]${NC} $label: $value$unit (threshold: $threshold$unit) -- ${percent}% of limit"
        return 0
    elif [ "$percent" -ge 80 ]; then
        echo -e "${YELLOW}[WARNING]${NC}  $label: $value$unit (threshold: $threshold$unit) -- ${percent}% of limit"
        return 0
    else
        echo -e "${GREEN}[OK]${NC}       $label: $value$unit (threshold: $threshold$unit) -- ${percent}% of limit"
        return 1
    fi
}

scan_all_thresholds() {
    log_section "Threshold Scan All Metrics"
    local any_exceeded=false

    if [ -s "$FAILED_LOGINS" ]; then
        declare -A ip_counts
        while IFS= read -r ip; do
            [ -n "$ip" ] && ip_counts["$ip"]=$(( ${ip_counts["$ip"]:-0} + 1 ))
        done < <(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$FAILED_LOGINS")
        echo ""
        echo "-- Failed Login Thresholds --"
        for ip in "${!ip_counts[@]}"; do
            local count=${ip_counts[$ip]}
            if ! check_threshold "$count" "$FAILED_LOGIN_THRESHOLD" "Failed logins from $ip"; then
                any_exceeded=true
            fi
        done
    fi

    if [ -s "$SERVER_ERRORS" ]; then
        local error_count
        error_count=$(wc -l < "$SERVER_ERRORS")
        echo ""
        echo "-- Server Error Thresholds --"
        if ! check_threshold "$error_count" "$ERROR_THRESHOLD" "Total server errors"; then
            any_exceeded=true
        fi
    fi

    if [ -s "$SUSPICIOUS_IPS" ]; then
        local http_errors
        http_errors=$(grep -cE "\" [45][0-9]{2} " "$SUSPICIOUS_IPS" 2>/dev/null || echo 0)
        echo ""
        echo "-- HTTP Error Thresholds --"
        if ! check_threshold "$http_errors" "$ERROR_THRESHOLD" "HTTP 4xx/5xx errors"; then
            any_exceeded=true
        fi
    fi

    echo ""
    echo "-- Disk Space Thresholds --"
    local free_mb
    free_mb=$(df "$PROJECT_ROOT" | awk 'NR==2 {print int($4/1024)}')
    if [ "$free_mb" -lt 100 ]; then
        echo -e "${RED}[EXCEEDED]${NC} Free disk space: ${free_mb}MB (minimum: 100MB)"
        any_exceeded=true
    else
        echo -e "${GREEN}[OK]${NC}       Free disk space: ${free_mb}MB (minimum: 100MB)"
    fi

    echo ""
    if [ "$any_exceeded" = true ]; then
        log_warn "Some thresholds exceeded -- review alerts"
        return 1
    else
        log_success "All metrics within acceptable thresholds"
        return 0
    fi
}

show_thresholds() {
    log_section "Current Threshold Settings"
    echo ""
    printf "  %-35s %s\n" "Metric" "Threshold"
    echo "  ------------------------------------------"
    printf "  %-35s %s\n" "Failed SSH logins per IP:"  "$FAILED_LOGIN_THRESHOLD"
    printf "  %-35s %s\n" "Server errors total:"       "$ERROR_THRESHOLD"
    printf "  %-35s %s\n" "HTTP requests per IP:"      "$REQUEST_THRESHOLD"
    echo ""
    log_info "Edit thresholds in: config.sh"
}

main() {
    init_logger
    local command="${1:-scan}"
    case "$command" in
        check)
            local value="${2:-}"
            local threshold="${3:-}"
            local label="${4:-metric}"
            if [ -z "$value" ] || [ -z "$threshold" ]; then
                log_error "Usage: threshold_checker.sh check <value> <threshold> <label>"
                exit 1
            fi
            check_threshold "$value" "$threshold" "$label"
            ;;
        scan)
            scan_all_thresholds
            ;;
        show)
            show_thresholds
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Usage: bash threshold_checker.sh [check|scan|show]"
            exit 1
            ;;
    esac
}

main "$@"