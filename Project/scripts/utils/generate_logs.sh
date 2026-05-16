#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$UTILS_DIR/logger.sh"

log_section "Generating Fake Log Files"

BAD_IP1="192.168.1.100"
BAD_IP2="10.0.0.55"
BAD_IP3="172.16.0.200"
BAD_IP4="45.33.32.156"
GOOD_IP1="192.168.1.1"
GOOD_IP2="192.168.1.2"

generate_auth_log() {
    log_info "Generating auth.log..."
    > "$AUTH_LOG"
    for i in $(seq 1 30); do
        day=$((RANDOM % 28 + 1))
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        pid=$((RANDOM % 9000 + 1000))
        port=$((RANDOM % 10000 + 50000))
        printf "May %02d %02d:%02d:%02d server sshd[%d]: Accepted password for user1 from %s port %d ssh2\n" "$day" "$hour" "$min" "$sec" "$pid" "$GOOD_IP1" "$port" >> "$AUTH_LOG"
    done
    for i in $(seq 1 20); do
        day=$((RANDOM % 28 + 1))
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        pid=$((RANDOM % 9000 + 1000))
        port=$((RANDOM % 10000 + 50000))
        printf "May %02d %02d:%02d:%02d server sshd[%d]: Failed password for root from %s port %d ssh2\n" "$day" "$hour" "$min" "$sec" "$pid" "$BAD_IP1" "$port" >> "$AUTH_LOG"
    done
    for i in $(seq 1 15); do
        day=$((RANDOM % 28 + 1))
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        pid=$((RANDOM % 9000 + 1000))
        port=$((RANDOM % 10000 + 50000))
        printf "May %02d %02d:%02d:%02d server sshd[%d]: Failed password for admin from %s port %d ssh2\n" "$day" "$hour" "$min" "$sec" "$pid" "$BAD_IP2" "$port" >> "$AUTH_LOG"
    done
    for i in $(seq 1 15); do
        day=$((RANDOM % 28 + 1))
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        pid=$((RANDOM % 9000 + 1000))
        printf "May %02d %02d:%02d:%02d server sshd[%d]: Invalid user hacker from %s\n" "$day" "$hour" "$min" "$sec" "$pid" "$BAD_IP3" >> "$AUTH_LOG"
    done
    sort "$AUTH_LOG" -o "$AUTH_LOG"
    log_success "auth.log generated: $(wc -l < "$AUTH_LOG") lines"
}

generate_syslog() {
    log_info "Generating syslog..."
    > "$SYS_LOG"
    for i in $(seq 1 30); do
        day=$((RANDOM % 28 + 1))
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        pid=$((RANDOM % 9000 + 1000))
        printf "May %02d %02d:%02d:%02d server systemd[%d]: Started daily cleanup service\n" "$day" "$hour" "$min" "$sec" "$pid" >> "$SYS_LOG"
    done
    for i in $(seq 1 20); do
        day=$((RANDOM % 28 + 1))
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        pid=$((RANDOM % 9000 + 1000))
        printf "May %02d %02d:%02d:%02d server kernel[%d]: ERROR: Out of memory - process killed\n" "$day" "$hour" "$min" "$sec" "$pid" >> "$SYS_LOG"
    done
    for i in $(seq 1 10); do
        day=$((RANDOM % 28 + 1))
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        pid=$((RANDOM % 9000 + 1000))
        printf "May %02d %02d:%02d:%02d server apache2[%d]: ERROR: Connection refused\n" "$day" "$hour" "$min" "$sec" "$pid" >> "$SYS_LOG"
    done
    sort "$SYS_LOG" -o "$SYS_LOG"
    log_success "syslog generated: $(wc -l < "$SYS_LOG") lines"
}

generate_apache_log() {
    log_info "Generating apache.log..."
    > "$APACHE_LOG"
    for i in $(seq 1 40); do
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        size=$((RANDOM % 50000 + 200))
        printf "%s - - [16/May/2026:%02d:%02d:%02d +0000] \"GET /index.html HTTP/1.1\" 200 %d \"-\" \"Mozilla/5.0\"\n" "$GOOD_IP2" "$hour" "$min" "$sec" "$size" >> "$APACHE_LOG"
    done
    for i in $(seq 1 20); do
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        size=$((RANDOM % 5000 + 100))
        printf "%s - - [16/May/2026:%02d:%02d:%02d +0000] \"GET /admin HTTP/1.1\" 403 %d \"-\" \"curl/7.68.0\"\n" "$BAD_IP1" "$hour" "$min" "$sec" "$size" >> "$APACHE_LOG"
    done
    for i in $(seq 1 15); do
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        size=$((RANDOM % 5000 + 100))
        printf "%s - - [16/May/2026:%02d:%02d:%02d +0000] \"GET /.env HTTP/1.1\" 404 %d \"-\" \"python-requests/2.25\"\n" "$BAD_IP4" "$hour" "$min" "$sec" "$size" >> "$APACHE_LOG"
    done
    for i in $(seq 1 10); do
        hour=$((RANDOM % 24))
        min=$((RANDOM % 60))
        sec=$((RANDOM % 60))
        size=$((RANDOM % 5000 + 100))
        printf "%s - - [16/May/2026:%02d:%02d:%02d +0000] \"POST /wp-admin HTTP/1.1\" 500 %d \"-\" \"Mozilla/5.0\"\n" "$BAD_IP2" "$hour" "$min" "$sec" "$size" >> "$APACHE_LOG"
    done
    log_success "apache.log generated: $(wc -l < "$APACHE_LOG") lines"
}

generate_sample_and_test() {
    log_info "Generating sample_logs.log..."
    cat "$AUTH_LOG" "$SYS_LOG" "$APACHE_LOG" | sort > "$SAMPLE_LOG"
    log_success "sample_logs.log: $(wc -l < "$SAMPLE_LOG") lines"
    log_info "Generating test data..."
    grep -E "Accepted|200|Started" "$SAMPLE_LOG" > "$NORMAL_LOGS" 2>/dev/null || true
    grep -E "Failed|Invalid|ERROR|403|404|500|\.env|wp-admin|admin" "$SAMPLE_LOG" > "$ANOMALY_LOGS" 2>/dev/null || true
    cp "$SAMPLE_LOG" "$MIXED_LOGS"
    log_info "  Normal:  $(wc -l < "$NORMAL_LOGS") lines"
    log_info "  Anomaly: $(wc -l < "$ANOMALY_LOGS") lines"
}

generate_auth_log
generate_syslog
generate_apache_log
generate_sample_and_test
log_section "Log Generation Complete"
log_success "All files ready in: $RAW_LOG_DIR"
