#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/error_handler.sh"
source "$UTILS_DIR/checkpoint_manager.sh"
source "$UTILS_DIR/validator.sh"
source "$UTILS_DIR/helpers.sh"

run_stage1() {
    log_stage 1 "Log Collection"

    if checkpoint_exists 1; then
        log_warn "Stage 1 already completed. Skipping."
        return 0
    fi

    validate_dir "$RAW_LOG_DIR" "raw_logs directory"
    check_disk_space

    log_info "Scanning for log files..."
    local log_files=()
    while IFS= read -r -d '' file; do
        log_files+=("$file")
    done < <(find "$RAW_LOG_DIR" -type f -print0)

    if [ ${#log_files[@]} -eq 0 ]; then
        log_error "No log files found in $RAW_LOG_DIR"
        exit 1
    fi

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
        log_error "All log files are empty."
        exit 1
    fi

    log_info "Merging ${#valid_files[@]} files into raw_collected.log..."
    > "$RAW_COLLECTED"
    for file in "${valid_files[@]}"; do
        echo "# -- Source: $(basename "$file") --" >> "$RAW_COLLECTED"
        if [ "$DRY_RUN" = false ]; then
            cat "$file" >> "$RAW_COLLECTED"
        fi
    done

    log_info "Sorting merged log by timestamp..."
    sort "$RAW_COLLECTED" -o "$RAW_COLLECTED"

    local total_lines
    total_lines=$(grep -vc "^#" "$RAW_COLLECTED")
    local temp_summary="$TEMP_DIR/stage1_temp/collection_summary.txt"
    mkdir -p "$TEMP_DIR/stage1_temp"
    {
        echo "STAGE=1"
        echo "FILES_COLLECTED=${#valid_files[@]}"
        echo "TOTAL_LINES=$total_lines"
        echo "TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')"
    } > "$temp_summary"

    echo ""
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo -e "${CYAN}  STAGE 1 RESULTS${NC}"
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Files Collected"   "${#valid_files[@]}"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Total Log Lines"   "$total_lines"
    printf  "  %-25s : ${WHITE}%s${NC}\n" "Output File"       "output/raw_collected.log"
    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo ""

    save_checkpoint 1
}

run_stage1