#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  checkpoint_manager.sh — Resume-on-Failure System
#  Saves progress after each stage. If pipeline crashes,
#  it can resume from the last completed stage.
#  Usage: source scripts/utils/checkpoint_manager.sh
# ═══════════════════════════════════════════════════════════

# ────────────────────────────────────────
# HOW CHECKPOINTS WORK:
#
# After Stage 1 completes → create checkpoints/stage1.done
# After Stage 2 completes → create checkpoints/stage2.done
# ... and so on.
#
# When pipeline starts, it checks which .done files exist
# and skips those stages — resuming from the next one.
# ────────────────────────────────────────

# Save a checkpoint for a completed stage
# Usage: save_checkpoint 1
save_checkpoint() {
    local stage="$1"
    local checkpoint_file="$CHECKPOINT_DIR/stage${stage}.done"
    {
        echo "STAGE=$stage"
        echo "COMPLETED_AT=$(date '+%Y-%m-%d %H:%M:%S')"
        echo "STATUS=SUCCESS"
    } > "$checkpoint_file"
    log_info "Checkpoint saved: Stage $stage"
}

# Check if a stage already completed
# Usage: if checkpoint_exists 1; then ...
checkpoint_exists() {
    local stage="$1"
    [ -f "$CHECKPOINT_DIR/stage${stage}.done" ]
}

# Clear a specific stage checkpoint
# Usage: clear_checkpoint 2
clear_checkpoint() {
    local stage="$1"
    rm -f "$CHECKPOINT_DIR/stage${stage}.done"
    log_info "Checkpoint cleared: Stage $stage"
}

# Clear ALL checkpoints (full restart)
clear_all_checkpoints() {
    rm -f "$CHECKPOINT_DIR"/*.done
    rm -f "$PIPELINE_STATE"
    log_warn "All checkpoints cleared — pipeline will restart from Stage 1"
}

# Show which stages are done and which are pending
show_checkpoint_status() {
    log_section "Checkpoint Status"
    for stage in 1 2 3 4; do
        if checkpoint_exists "$stage"; then
            echo -e "  Stage $stage: ${GREEN}✔ COMPLETE${NC}"
        else
            echo -e "  Stage $stage: ${YELLOW}○ PENDING${NC}"
        fi
    done
    echo ""
}

# Find the next stage to run (for resume)
# Prints the number of the first incomplete stage
get_resume_point() {
    for stage in 1 2 3 4; do
        if ! checkpoint_exists "$stage"; then
            echo "$stage"
            return
        fi
    done
    echo "done"   # all stages complete
}

# Save overall pipeline state
# Usage: save_pipeline_state "RUNNING" 2
save_pipeline_state() {
    local status="$1"
    local current_stage="$2"
    {
        echo "STATUS=$status"
        echo "CURRENT_STAGE=$current_stage"
        echo "UPDATED_AT=$(date '+%Y-%m-%d %H:%M:%S')"
        echo "VERSION=$PIPELINE_VERSION"
    } > "$PIPELINE_STATE"
}
