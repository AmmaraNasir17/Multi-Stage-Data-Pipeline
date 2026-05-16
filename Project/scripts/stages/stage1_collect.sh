#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  stage1_collect.sh — Log Collection Stage
#  Collects all raw log files, validates them,
#  merges them into one file, and saves a checkpoint.
# ═══════════════════════════════════════════════════════════

# ── Load config and utilities ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/error_handler.sh"
source "$UTILS_DIR/checkpoint_manager.sh"
source "$UTILS_DIR/validator.sh"
source "$UTILS_DIR/helpers.sh"

# ────────────────────────────────────────
# MAIN FUNCTION
# ────────────────────────────────────────
run_stage1() {
    log_section "STAGE 1 — Log Collection"

    # ── Step 1: Check if already done (resume support) ──
    if checkpoint_exists 1; then
        log_warn "Stage 1 already completed. Skipping."
        log_warn "Delete checkpoints/stage1.done to re-run this stage."
        return 0
    fi

    # ── Step 2: Validate input directory exists ──
    validate_dir "$RAW_LOG_DIR" "raw_logs directory"

    # ── Step 3: Check disk space before writing ──
    check_disk_space

    # ── Step 4: List all log files found ──
    log_info "Scanning for log files in: $RAW_LOG_DIR"
    local log_files=()

    # Find all files in raw_logs directory
    while IFS= read -r -d '' file; do
        log_files+=("$file")
        log_info "  Found: $(basename "$file") ($(wc -l < "$file") lines)"
    done < <(find "$RAW_LOG_DIR" -type f -print0)

    # ── Step 5: Abort if no files found ──
    if [ ${#log_files[@]} -eq 0 ]; then
        log_error "No log files found in $RAW_LOG_DIR"
        log_error "Run: bash scripts/utils/generate_logs.sh first"
        exit 1
    fi

    log_info "Total files found: ${#log_files[@]}"

    # ── Step 6: Validate each file is non-empty ──
    log_info "Validating log files..."
    local valid_files=()
    for file in "${log_files[@]}"; do
        if validate_file "$file" "$(basename "$file")"; then
            valid_files+=("$file")
        else
            log_warn "Skipping empty file: $(basename "$file")"
        fi
    done

    if [ ${#valid_files[@]} -eq 0 ]; then
        log_error "All log files are empty. Nothing to process."
        exit 1
    fi

    # ── Step 7: Merge all valid logs into one file ──
    log_info "Merging ${#valid_files[@]} files into raw_collected.log..."
    > "$RAW_COLLECTED"   # clear/create output file

    for file in "${valid_files[@]}"; do
        local filename
        filename=$(basename "$file")

        # Add a separator comment so we know which file each section came from
        echo "# ── Source: $filename ──" >> "$RAW_COLLECTED"

        if [ "$DRY_RUN" = false ]; then
            cat "$file" >> "$RAW_COLLECTED"
        else
            log_warn "[DRY RUN] Would append: $filename"
        fi

        log_debug "Appended: $filename"
    done

    # ── Step 8: Sort merged file by timestamp ──
    log_info "Sorting merged log by timestamp..."
    sort "$RAW_COLLECTED" -o "$RAW_COLLECTED"

    # ── Step 9: Write collection summary to temp ──
    local total_lines
    total_lines=$(grep -v "^#" "$RAW_COLLECTED" | wc -l)
    local temp_summary="$TEMP_DIR/stage1_temp/collection_summary.txt"
    mkdir -p "$TEMP_DIR/stage1_temp"
    {
        echo "STAGE=1"
        echo "FILES_COLLECTED=${#valid_files[@]}"
        echo "TOTAL_LINES=$total_lines"
        echo "OUTPUT=$RAW_COLLECTED"
        echo "TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')"
    } > "$temp_summary"

    # ── Step 10: Print results ──
    log_success "Stage 1 Complete!"
    log_info "Files collected:  ${#valid_files[@]}"
    log_info "Total log lines:  $total_lines"
    log_info "Output file:      $RAW_COLLECTED"

    # ── Step 11: Save checkpoint ──
    save_checkpoint 1
}

# ── Run it ──
run_stage1
