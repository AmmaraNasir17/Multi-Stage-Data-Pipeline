#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  validator.sh — Input Validation Functions
#  Checks files, folders, and data before processing
#  Usage: source scripts/utils/validator.sh
# ═══════════════════════════════════════════════════════════

# Check that a file exists and is not empty
# Usage: validate_file "/path/to/file.log"
validate_file() {
    local filepath="$1"
    local label="${2:-$filepath}"   # optional readable name

    if [ ! -f "$filepath" ]; then
        log_error "File not found: $label"
        return 1
    fi

    if [ ! -s "$filepath" ]; then
        log_warn "File is empty: $label"
        return 1
    fi

    log_debug "File OK: $label"
    return 0
}

# Check that a directory exists
# Usage: validate_dir "/path/to/dir"
validate_dir() {
    local dirpath="$1"
    local label="${2:-$dirpath}"

    if [ ! -d "$dirpath" ]; then
        log_error "Directory not found: $label"
        return 1
    fi

    log_debug "Directory OK: $label"
    return 0
}

# Check that a command/tool is available
# Usage: validate_tool "awk"
validate_tool() {
    local tool="$1"
    if ! command -v "$tool" &>/dev/null; then
        log_error "Required tool not found: $tool"
        log_error "Install it with: sudo apt install $tool"
        return 1
    fi
    log_debug "Tool OK: $tool"
    return 0
}

# Validate ALL required tools at once
validate_all_tools() {
    log_info "Validating required tools..."
    local tools=("bash" "grep" "awk" "sed" "sort" "uniq" "wc" "date" "tee")
    local all_ok=true

    for tool in "${tools[@]}"; do
        if ! validate_tool "$tool"; then
            all_ok=false
        fi
    done

    if [ "$all_ok" = false ]; then
        log_error "One or more required tools are missing. Aborting."
        return 1
    fi

    log_success "All required tools are available"
}

# Validate ALL input log files exist and are non-empty
validate_input_logs() {
    log_info "Validating input log files..."
    local all_ok=true
    local log_files=("$AUTH_LOG" "$SYS_LOG" "$APACHE_LOG" "$SAMPLE_LOG")
    local log_names=("auth.log" "syslog" "apache.log" "sample_logs.log")

    for i in "${!log_files[@]}"; do
        if ! validate_file "${log_files[$i]}" "${log_names[$i]}"; then
            all_ok=false
        fi
    done

    if [ "$all_ok" = false ]; then
        log_error "Some input files are missing or empty"
        return 1
    fi

    log_success "All input log files validated"
}

# Validate output directories exist (create if missing)
validate_output_dirs() {
    log_info "Validating output directories..."
    local dirs=(
        "$OUTPUT_DIR" "$FILTERED_DIR" "$AGGREGATED_DIR"
        "$ALERTS_OUT_DIR" "$REPORTS_DIR" "$LOGS_DIR"
        "$CHECKPOINT_DIR" "$TEMP_DIR"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log_debug "Directory ready: $dir"
    done

    log_success "All output directories ready"
}
