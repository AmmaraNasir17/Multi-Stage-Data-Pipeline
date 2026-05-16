#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

show_disk_usage() {
    log_section "Current Disk Usage"
    echo ""
    echo "  Directory              Size"
    echo "  ─────────────────────────────"
    for dir in "$TEMP_DIR" "$LOGS_DIR" "$OUTPUT_DIR" "$BACKUP_DIR"; do
        if [ -d "$dir" ]; then
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            printf "  %-25s %s\n" "$(basename "$dir")/" "$size"
        fi
    done
    echo ""
}

clean_temp() {
    log_info "Cleaning temp files..."
    rm -rf "$TEMP_DIR"/stage1_temp/*
    rm -rf "$TEMP_DIR"/stage2_temp/*
    rm -rf "$TEMP_DIR"/cache/*
    log_success "Temp files cleaned"
}

clean_logs() {
    log_info "Clearing log files..."
    > "$PIPELINE_LOG"
    > "$ERROR_LOG"
    > "$EXECUTION_LOG"
    > "$DEBUG_LOG"
    log_success "Log files cleared"
}

clean_output() {
    log_info "Cleaning output files..."
    rm -f "$RAW_COLLECTED"
    rm -f "$FAILED_LOGINS" "$SUSPICIOUS_IPS" "$SERVER_ERRORS"
    rm -f "$IP_SUMMARY" "$ANOMALY_COUNTS" "$USAGE_STATS"
    rm -f "$ALERTS_LOG" "$CRITICAL_ALERTS" "$WARNING_ALERTS"
    rm -f "$FINAL_SUMMARY" "$DAILY_REPORT"
    log_success "Output files cleaned"
}

clean_backups() {
    log_info "Cleaning old backups..."
    local count
    count=$(find "$BACKUP_DIR" -mindepth 2 -maxdepth 2 -type d | wc -l)
    rm -rf "$BACKUP_DIR"/logs_backup/*
    rm -rf "$BACKUP_DIR"/reports_backup/*
    rm -rf "$BACKUP_DIR"/checkpoints_backup/*
    log_success "Removed $count old backup directories"
}

clean_checkpoints() {
    log_info "Cleaning checkpoints..."
    rm -f "$CHECKPOINT_DIR"/*.done
    rm -f "$PIPELINE_STATE"
    log_success "All checkpoints cleared"
}

clean_all() {
    log_warn "FULL CLEANUP — removing all generated files"
    clean_temp
    clean_logs
    clean_output
    clean_backups
    clean_checkpoints
    rm -f "$LOCK_FILE"
    log_success "Full cleanup complete"
}

show_usage() {
    echo ""
    echo "Usage: bash scripts/recovery/cleanup.sh [option]"
    echo ""
    echo "Options:"
    echo "  --temp         Clean temp files only"
    echo "  --logs         Clear log file contents"
    echo "  --output       Remove all output files"
    echo "  --backups      Remove old backup directories"
    echo "  --checkpoints  Clear stage checkpoints"
    echo "  --all          Clean everything"
    echo ""
}

main() {
    init_logger
    log_section "Cleanup Tool"
    local option="${1:-}"
    if [ -z "$option" ]; then
        show_usage
        show_disk_usage
        exit 0
    fi
    if [ "$option" = "--all" ] || [ "$option" = "--output" ]; then
        echo -e "${YELLOW}This will delete output files. Continue? (y/n):${NC} \c"
        read -r answer
        echo ""
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            log_info "Cleanup cancelled"
            exit 0
        fi
    fi
    case "$option" in
        --temp)        clean_temp        ;;
        --logs)        clean_logs        ;;
        --output)      clean_output      ;;
        --backups)     clean_backups     ;;
        --checkpoints) clean_checkpoints ;;
        --all)         clean_all         ;;
        *)
            log_error "Unknown option: $option"
            show_usage
            exit 1
            ;;
    esac
    echo ""
    show_disk_usage
}

main "$@"
