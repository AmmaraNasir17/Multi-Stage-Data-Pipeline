#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/error_handler.sh"
source "$UTILS_DIR/checkpoint_manager.sh"
source "$UTILS_DIR/validator.sh"
source "$UTILS_DIR/helpers.sh"

RESUME_MODE=false
RESET_MODE=false
STATUS_MODE=false

for arg in "$@"; do
    case "$arg" in
        --resume)  RESUME_MODE=true  ;;
        --reset)   RESET_MODE=true   ;;
        --dry-run) DRY_RUN=true      ;;
        --status)  STATUS_MODE=true  ;;
        --verbose) VERBOSE=true      ;;
        --help)
            echo "Usage: bash main_pipeline.sh [OPTIONS]"
            echo "  --resume    Resume from last successful stage"
            echo "  --reset     Clear all checkpoints and restart"
            echo "  --dry-run   Test run without writing output"
            echo "  --status    Show current checkpoint status"
            echo "  --verbose   Show detailed debug output"
            exit 0
            ;;
    esac
done

print_banner() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Multi-Stage Data Processing Pipeline         ║${NC}"
    echo -e "${BLUE}║     Version: $PIPELINE_VERSION                             ║${NC}"
    echo -e "${BLUE}║     $(date '+%Y-%m-%d %H:%M:%S')                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

handle_reset() {
    log_warn "RESET MODE — clearing all checkpoints and outputs"
    clear_all_checkpoints
    rm -f "$RAW_COLLECTED"
    rm -f "$FAILED_LOGINS" "$SUSPICIOUS_IPS" "$SERVER_ERRORS"
    rm -f "$IP_SUMMARY" "$ANOMALY_COUNTS" "$USAGE_STATS"
    rm -f "$ALERTS_LOG" "$CRITICAL_ALERTS" "$WARNING_ALERTS"
    rm -f "$FINAL_SUMMARY" "$DAILY_REPORT"
    rm -f "$PIPELINE_LOG" "$ERROR_LOG" "$EXECUTION_LOG" "$DEBUG_LOG"
    rm -rf "$TEMP_DIR"/stage1_temp/* "$TEMP_DIR"/stage2_temp/* "$TEMP_DIR"/cache/*
    log_success "Reset complete. Pipeline will start fresh."
}

preflight_checks() {
    log_section "Pre-Flight Checks"
    validate_all_tools
    validate_output_dirs
    check_disk_space
    if [ ! -s "$AUTH_LOG" ] && [ ! -s "$APACHE_LOG" ] && [ ! -s "$SYS_LOG" ]; then
        log_warn "No input log files found! Generating sample logs..."
        bash "$UTILS_DIR/generate_logs.sh"
    fi
    log_success "Pre-flight checks passed"
}

run_stage() {
    local stage_num="$1"
    local stage_script="$2"
    local stage_name="$3"
    if [ "$RESUME_MODE" = true ] && checkpoint_exists "$stage_num"; then
        log_warn "Skipping Stage $stage_num ($stage_name) — already completed"
        return 0
    fi
    local stage_start
    stage_start=$(date +%s)
    save_pipeline_state "RUNNING" "$stage_num"
    if bash "$stage_script"; then
        local elapsed=$(( $(date +%s) - stage_start ))
        log_success "Stage $stage_num ($stage_name) finished in ${elapsed}s"
    else
        local exit_code=$?
        log_error "Stage $stage_num ($stage_name) FAILED (exit code: $exit_code)"
        log_error "Fix the issue then run: bash main_pipeline.sh --resume"
        save_pipeline_state "FAILED" "$stage_num"
        remove_lock
        exit $exit_code
    fi
}

print_final_summary() {
    local critical_count warning_count
    critical_count=$(wc -l < "$CRITICAL_ALERTS" 2>/dev/null || echo 0)
    warning_count=$(wc -l < "$WARNING_ALERTS"   2>/dev/null || echo 0)
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        PIPELINE COMPLETED SUCCESSFULLY           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${RED}Critical Alerts:${NC}  $critical_count"
    echo -e "  ${YELLOW}Warning Alerts:${NC}   $warning_count"
    echo ""
    echo -e "  Final Report:  $FINAL_SUMMARY"
    echo -e "  Alerts Log:    $ALERTS_LOG"
    echo -e "  Pipeline Log:  $PIPELINE_LOG"
    echo ""
    if [ "$critical_count" -gt 0 ]; then
        echo -e "${RED}  CRITICAL ALERTS DETECTED — review immediately!${NC}"
        echo ""
        cat "$CRITICAL_ALERTS"
    else
        echo -e "${GREEN}  No critical threats detected.${NC}"
    fi
    echo ""
}

main() {
    init_logger
    print_banner
    if [ "$STATUS_MODE" = true ]; then
        show_checkpoint_status
        exit 0
    fi
    if [ "$RESET_MODE" = true ]; then
        handle_reset
    fi
    if [ "$RESUME_MODE" = true ]; then
        log_warn "RESUME MODE — continuing from last checkpoint"
        show_checkpoint_status
    elif [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE — no files will be written"
    else
        log_info "NORMAL MODE — full pipeline run"
    fi
    create_lock
    trap remove_lock EXIT
    start_timer
    preflight_checks
    log_section "Starting Pipeline"
    run_stage 1 "$STAGES_DIR/stage1_collect.sh"   "Log Collection"
    run_stage 2 "$STAGES_DIR/stage2_filter.sh"    "Anomaly Filtering"
    run_stage 3 "$STAGES_DIR/stage3_aggregate.sh" "Data Aggregation"
    run_stage 4 "$STAGES_DIR/stage4_alert.sh"     "Alert Generation"
    log_section "Post-Pipeline Tasks"
    cleanup_temp
    backup_outputs
    save_pipeline_state "COMPLETED" "done"
    stop_timer
    print_final_summary
}

main "$@"
