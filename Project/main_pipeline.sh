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
            echo ""
            echo "  Usage: bash main_pipeline.sh [OPTIONS]"
            echo ""
            echo "  Options:"
            echo "    --resume    Resume from last successful stage"
            echo "    --reset     Clear all checkpoints and restart"
            echo "    --dry-run   Test run without writing output"
            echo "    --status    Show current checkpoint status"
            echo "    --verbose   Show detailed debug output"
            echo "    --help      Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "  Unknown option: $arg"
            echo "  Run: bash main_pipeline.sh --help"
            exit 1
            ;;
    esac
done

print_banner() {
    local date_str mode_str
    date_str=$(date '+%Y-%m-%d %H:%M:%S')
    if   [ "$DRY_RUN"     = true ]; then mode_str="DRY RUN"
    elif [ "$RESUME_MODE" = true ]; then mode_str="RESUME"
    elif [ "$RESET_MODE"  = true ]; then mode_str="RESET"
    else mode_str="NORMAL"
    fi
    echo ""
    echo -e "${BLUE}${BOLD}  ########################################################${NC}"
    echo -e "${BLUE}${BOLD}  #                                                      #${NC}"
    echo -e "${BLUE}${BOLD}  #      MULTI-STAGE DATA PROCESSING PIPELINE            #${NC}"
    echo -e "${BLUE}${BOLD}  #      Security Log Analysis System                    #${NC}"
    echo -e "${BLUE}${BOLD}  #                                                      #${NC}"
    echo -e "${BLUE}${BOLD}  ########################################################${NC}"
    printf  "${BLUE}  #  %-20s : %-29s#${NC}\n" "Version"  "$PIPELINE_VERSION"
    printf  "${BLUE}  #  %-20s : %-29s#${NC}\n" "Started"  "$date_str"
    printf  "${BLUE}  #  %-20s : %-29s#${NC}\n" "Host"     "$(hostname)"
    printf  "${BLUE}  #  %-20s : %-29s#${NC}\n" "Mode"     "$mode_str"
    echo -e "${BLUE}${BOLD}  ########################################################${NC}"
    echo ""
}

handle_reset() {
    log_warn "RESET MODE -- clearing all checkpoints and outputs"
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
        log_warn "No input log files found -- generating sample logs..."
        bash "$UTILS_DIR/generate_logs.sh"
    fi
    log_success "Pre-flight checks passed"
}

run_stage() {
    local stage_num="$1"
    local stage_script="$2"
    local stage_name="$3"
    if [ "$RESUME_MODE" = true ] && checkpoint_exists "$stage_num"; then
        log_warn "Skipping Stage $stage_num ($stage_name) -- already completed"
        return 0
    fi
    local stage_start
    stage_start=$(date +%s)
    save_pipeline_state "RUNNING" "$stage_num"
    if bash "$stage_script"; then
        local stage_end elapsed
        stage_end=$(date +%s)
        elapsed=$((stage_end - stage_start))
        echo ""
        echo -e "  ${GREEN}${BOLD}  Stage $stage_num complete -- finished in ${elapsed}s${NC}"
        echo ""
    else
        local exit_code=$?
        log_error "Stage $stage_num ($stage_name) FAILED with exit code $exit_code"
        log_error "Fix the issue and run: bash main_pipeline.sh --resume"
        save_pipeline_state "FAILED" "$stage_num"
        remove_lock
        exit $exit_code
    fi
}

print_final_summary() {
    local critical_count warning_count total_lines unique_ips
    critical_count=$(wc -l < "$CRITICAL_ALERTS" 2>/dev/null || echo 0)
    warning_count=$(wc -l  < "$WARNING_ALERTS"  2>/dev/null || echo 0)
    total_lines=$(grep -vc "^#" "$RAW_COLLECTED" 2>/dev/null || echo 0)
    unique_ips=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$RAW_COLLECTED" 2>/dev/null | sort -u | wc -l)

    echo ""
    echo -e "${BOLD}  ########################################################${NC}"
    echo -e "${BOLD}  #           PIPELINE EXECUTION COMPLETE               #${NC}"
    echo -e "${BOLD}  ########################################################${NC}"
    echo ""
    echo -e "${BOLD}  STAGE RESULTS${NC}"
    echo -e "  ${DIM}........................................................${NC}"
    printf  "  ${GREEN}>>>${NC} Stage 1  %-20s %s\n" "Log Collection"  "[ COMPLETE ]"
    printf  "  ${GREEN}>>>${NC} Stage 2  %-20s %s\n" "Filtering"       "[ COMPLETE ]"
    printf  "  ${GREEN}>>>${NC} Stage 3  %-20s %s\n" "Aggregation"     "[ COMPLETE ]"
    printf  "  ${GREEN}>>>${NC} Stage 4  %-20s %s\n" "Alerts"          "[ COMPLETE ]"
    echo ""
    echo -e "${BOLD}  PIPELINE STATISTICS${NC}"
    echo -e "  ${DIM}........................................................${NC}"
    printf  "  %-28s : ${WHITE}%s${NC}\n"  "Total Log Lines Processed"  "$total_lines"
    printf  "  %-28s : ${WHITE}%s${NC}\n"  "Unique IP Addresses Found"  "$unique_ips"
    printf  "  %-28s : ${RED}%s${NC}\n"    "Critical Alerts Fired"      "$critical_count"
    printf  "  %-28s : ${YELLOW}%s${NC}\n" "Warning Alerts Fired"       "$warning_count"
    echo ""
    if [ "$critical_count" -gt 0 ]; then
        echo -e "${RED}${BOLD}  !! CRITICAL THREATS DETECTED -- Immediate Action Required !!${NC}"
        echo -e "${RED}  ........................................................${NC}"
        while IFS= read -r line; do
            local timestamp type detail
            timestamp=$(echo "$line" | awk -F'|' '{gsub(/ /,"",$1); print $1}' | tr -d '[]A-Z')
            type=$(echo "$line"      | awk -F'|' '{gsub(/^ | $/,"",$2); print $2}')
            detail=$(echo "$line"    | awk -F'|' '{gsub(/^ | $/,"",$3); print $3}')
            printf "  ${RED}%-20s  %-28s  %s${NC}\n" "$timestamp" "$type" "$detail"
        done < "$CRITICAL_ALERTS"
        echo -e "${RED}  ........................................................${NC}"
    else
        echo -e "${GREEN}${BOLD}  All Clear -- No critical threats detected.${NC}"
    fi
    echo ""
    echo -e "  ${DIM}........................................................${NC}"
    printf  "  ${DIM}%-15s : %s${NC}\n" "Final Report"  "output/reports/final_summary.txt"
    printf  "  ${DIM}%-15s : %s${NC}\n" "Alerts"        "output/alerts/critical_alerts.txt"
    printf  "  ${DIM}%-15s : %s${NC}\n" "Pipeline Log"  "logs/pipeline.log"
    echo -e "  ${DIM}........................................................${NC}"
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
        log_warn "RESUME MODE -- continuing from last checkpoint"
        show_checkpoint_status
    elif [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE -- no files will be written"
    else
        log_info "NORMAL MODE -- full pipeline run"
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