#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/checkpoint_manager.sh"

show_usage() {
    echo ""
    echo "Usage: bash scripts/recovery/rollback.sh <stage>"
    echo ""
    echo "Stages:"
    echo "  1 — Log Collection"
    echo "  2 — Anomaly Filtering"
    echo "  3 — Data Aggregation"
    echo "  4 — Alert Generation"
    echo "  all — Rollback everything"
    echo ""
}

clear_stage_outputs() {
    local stage="$1"
    case "$stage" in
        1)
            log_info "Clearing Stage 1 outputs..."
            rm -f "$RAW_COLLECTED"
            rm -rf "$TEMP_DIR/stage1_temp/"*
            ;;
        2)
            log_info "Clearing Stage 2 outputs..."
            rm -f "$FAILED_LOGINS" "$SUSPICIOUS_IPS" "$SERVER_ERRORS"
            rm -rf "$TEMP_DIR/stage2_temp/"*
            ;;
        3)
            log_info "Clearing Stage 3 outputs..."
            rm -f "$IP_SUMMARY" "$ANOMALY_COUNTS" "$USAGE_STATS"
            ;;
        4)
            log_info "Clearing Stage 4 outputs..."
            rm -f "$ALERTS_LOG" "$CRITICAL_ALERTS" "$WARNING_ALERTS"
            rm -f "$FINAL_SUMMARY" "$DAILY_REPORT"
            ;;
    esac
}

rollback_stage() {
    local stage="$1"
    log_section "Rolling Back Stage $stage"
    if ! checkpoint_exists "$stage"; then
        log_warn "Stage $stage has no checkpoint — may not have run yet"
    fi
    clear_checkpoint "$stage"
    clear_stage_outputs "$stage"
    log_warn "Clearing later stages that depend on Stage $stage..."
    for later_stage in $(seq $((stage + 1)) 4); do
        if checkpoint_exists "$later_stage"; then
            clear_checkpoint "$later_stage"
            clear_stage_outputs "$later_stage"
            log_info "  Cleared Stage $later_stage"
        fi
    done
    log_success "Rollback complete for Stage $stage and dependents"
}

rerun_stage() {
    local stage="$1"
    local scripts=(
        ""
        "$STAGES_DIR/stage1_collect.sh"
        "$STAGES_DIR/stage2_filter.sh"
        "$STAGES_DIR/stage3_aggregate.sh"
        "$STAGES_DIR/stage4_alert.sh"
    )
    local names=("" "Log Collection" "Anomaly Filtering" "Data Aggregation" "Alert Generation")
    log_info "Rerunning Stage $stage: ${names[$stage]}"
    if bash "${scripts[$stage]}"; then
        log_success "Stage $stage rerun successfully"
    else
        log_error "Stage $stage failed during rerun"
        exit 1
    fi
}

main() {
    init_logger
    local target="${1:-}"
    if [ -z "$target" ]; then
        show_usage
        exit 1
    fi
    if [ "$target" = "all" ]; then
        log_section "Rolling Back ALL Stages"
        for stage in 4 3 2 1; do
            clear_checkpoint "$stage" 2>/dev/null || true
            clear_stage_outputs "$stage"
        done
        rm -f "$PIPELINE_STATE"
        log_success "Full rollback complete"
        log_info "Run: bash main_pipeline.sh to start fresh"
        exit 0
    fi
    if ! [[ "$target" =~ ^[1-4]$ ]]; then
        log_error "Invalid stage: $target (must be 1, 2, 3, 4, or all)"
        show_usage
        exit 1
    fi
    show_checkpoint_status
    echo ""
    echo -e "${YELLOW}Rollback Stage $target and dependents? (y/n):${NC} \c"
    read -r answer
    echo ""
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        log_info "Rollback cancelled"
        exit 0
    fi
    rollback_stage "$target"
    echo ""
    echo -e "${YELLOW}Rerun Stage $target now? (y/n):${NC} \c"
    read -r rerun_answer
    echo ""
    if [ "$rerun_answer" = "y" ] || [ "$rerun_answer" = "Y" ]; then
        rerun_stage "$target"
        log_info "To continue: bash main_pipeline.sh --resume"
    else
        log_info "Run when ready: bash main_pipeline.sh --resume"
    fi
}

main "$@"
