#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  helpers.sh — General Helper Functions
#  Lock file, disk space, timer, dry-run, temp cleanup
#  Usage: source scripts/utils/helpers.sh
# ═══════════════════════════════════════════════════════════

# ────────────────────────────────────────
# LOCK FILE
# Prevents two instances of pipeline
# running at the same time
# ────────────────────────────────────────
create_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE")
        log_error "Pipeline already running! (PID: $pid)"
        log_error "If this is wrong, delete: $LOCK_FILE"
        exit 1
    fi
    echo $$ > "$LOCK_FILE"
    log_info "Lock created (PID: $$)"
}

remove_lock() {
    rm -f "$LOCK_FILE"
    log_info "Lock removed"
}

# ────────────────────────────────────────
# DISK SPACE CHECK
# Warns if less than 100MB free
# ────────────────────────────────────────
check_disk_space() {
    local min_kb=102400   # 100MB in kilobytes
    local free_kb
    free_kb=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $4}')

    if [ "$free_kb" -lt "$min_kb" ]; then
        log_warn "Low disk space: only $((free_kb / 1024))MB free"
        log_warn "Pipeline may fail when writing output files"
    else
        log_info "Disk space OK: $((free_kb / 1024))MB available"
    fi
}

# ────────────────────────────────────────
# RUNTIME TIMER
# Track how long the pipeline takes
# ────────────────────────────────────────
PIPELINE_START_TIME=0

start_timer() {
    PIPELINE_START_TIME=$(date +%s)   # seconds since epoch
    log_info "Timer started"
}

stop_timer() {
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - PIPELINE_START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    log_info "Total runtime: ${minutes}m ${seconds}s"
    echo "Total runtime: ${minutes}m ${seconds}s" >> "$FINAL_SUMMARY"
}

# ────────────────────────────────────────
# DRY RUN CHECK
# If DRY_RUN=true, print what would happen
# instead of actually doing it
# ────────────────────────────────────────
dry_run_check() {
    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE — no files will be written"
        log_warn "Set DRY_RUN=false in config.sh to run for real"
        return 0
    fi
    return 1
}

# ────────────────────────────────────────
# TEMP CLEANUP
# Remove temp files after pipeline finishes
# ────────────────────────────────────────
cleanup_temp() {
    if [ "$KEEP_TEMP" = false ]; then
        rm -rf "$TEMP_DIR"/stage1_temp/* \
               "$TEMP_DIR"/stage2_temp/* \
               "$TEMP_DIR"/cache/*
        log_info "Temp files cleaned up"
    else
        log_info "Keeping temp files (KEEP_TEMP=true)"
    fi
}

# ────────────────────────────────────────
# BACKUP
# Copy outputs to backup folder
# ────────────────────────────────────────
backup_outputs() {
    local backup_date
    backup_date=$(date '+%Y%m%d_%H%M%S')
    cp -r "$LOGS_DIR"     "$BACKUP_DIR/logs_backup/logs_$backup_date"
    cp -r "$REPORTS_DIR"  "$BACKUP_DIR/reports_backup/reports_$backup_date"
    cp -r "$CHECKPOINT_DIR" "$BACKUP_DIR/checkpoints_backup/checkpoints_$backup_date"
    log_success "Backup created: $backup_date"
}

# ────────────────────────────────────────
# PRINT PIPELINE HEADER
# Shows at the very start of every run
# ────────────────────────────────────────
print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║   Multi-Stage Data Processing Pipeline   ║"
    echo "║   Version: $PIPELINE_VERSION                      ║"
    echo "║   Started: $(date '+%Y-%m-%d %H:%M:%S')        ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}
