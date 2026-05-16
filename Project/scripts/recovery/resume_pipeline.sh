#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/checkpoint_manager.sh"
source "$UTILS_DIR/helpers.sh"

read_pipeline_state() {
    if [ ! -f "$PIPELINE_STATE" ]; then
        log_warn "No pipeline state file found."
        echo "UNKNOWN"
        return
    fi
    local status="" stage=""
    while IFS='=' read -r key value; do
        case "$key" in
            STATUS)        status="$value" ;;
            CURRENT_STAGE) stage="$value"  ;;
        esac
    done < "$PIPELINE_STATE"
    echo "$status:$stage"
}

show_recovery_report() {
    log_section "Pipeline Recovery Report"
    if [ -f "$PIPELINE_STATE" ]; then
        log_info "Last known pipeline state:"
        while IFS='=' read -r key value; do
            echo "    $key = $value"
        done < "$PIPELINE_STATE"
    fi
    echo ""
    show_checkpoint_status
    local resume_point
    resume_point=$(get_resume_point)
    if [ "$resume_point" = "done" ]; then
        log_success "All stages already complete!"
        log_info "Run: bash main_pipeline.sh --reset to start fresh"
    else
        log_warn "Pipeline will resume from Stage $resume_point"
    fi
}

validate_stage_outputs() {
    local stage="$1"
    log_info "Validating outputs from previous stages..."
    case "$stage" in
        1)
            log_info "Starting from Stage 1 — no dependencies"
            return 0
            ;;
        2)
            if [ ! -s "$RAW_COLLECTED" ]; then
                log_error "Stage 1 output missing: raw_collected.log"
                return 1
            fi
            ;;
        3)
            if [ ! -s "$FAILED_LOGINS" ] && [ ! -s "$SUSPICIOUS_IPS" ]; then
                log_error "Stage 2 outputs missing"
                return 1
            fi
            ;;
        4)
            if [ ! -s "$IP_SUMMARY" ] && [ ! -s "$ANOMALY_COUNTS" ]; then
                log_error "Stage 3 outputs missing"
                return 1
            fi
            ;;
    esac
    log_success "Previous stage outputs verified"
    return 0
}

resume_from_stage() {
    local start_stage="$1"
    log_info "Resuming pipeline from Stage $start_stage..."
    if ! validate_stage_outputs "$start_stage"; then
        log_error "Cannot resume — previous outputs missing"
        exit 1
    fi
    local stages=(1 2 3 4)
    local stage_scripts=(
        "$STAGES_DIR/stage1_collect.sh"
        "$STAGES_DIR/stage2_filter.sh"
        "$STAGES_DIR/stage3_aggregate.sh"
        "$STAGES_DIR/stage4_alert.sh"
    )
    local stage_names=("Log Collection" "Anomaly Filtering" "Data Aggregation" "Alert Generation")
    for i in "${!stages[@]}"; do
        local stage_num="${stages[$i]}"
        local script="${stage_scripts[$i]}"
        local name="${stage_names[$i]}"
        if [ "$stage_num" -lt "$start_stage" ]; then
            log_info "Skipping Stage $stage_num ($name) — already complete"
            continue
        fi
        log_info "Running Stage $stage_num: $name"
        if bash "$script"; then
            log_success "Stage $stage_num complete"
        else
            log_error "Stage $stage_num FAILED during resume"
            exit 1
        fi
    done
}

main() {
    init_logger
    log_section "Smart Resume System"
    show_recovery_report
    local resume_point
    resume_point=$(get_resume_point)
    if [ "$resume_point" = "done" ]; then
        log_success "Nothing to resume — all stages complete"
        log_info "Use: bash main_pipeline.sh --reset to run fresh"
        exit 0
    fi
    echo ""
    echo -e "${YELLOW}Resume from Stage $resume_point? (y/n):${NC} \c"
    read -r answer
    echo ""
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        log_info "Resume cancelled by user"
        exit 0
    fi
    resume_from_stage "$resume_point"
    log_success "Pipeline resume complete!"
}

main "$@"
