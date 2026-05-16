# ═══════════════════════════════════════════════════════════
#  syslog_parser.awk — Parses system logs
#  Extracts ERROR entries and counts by service
#  Usage: awk -f scripts/parsers/syslog_parser.awk input/raw_logs/syslog
# ═══════════════════════════════════════════════════════════

BEGIN {
    print "=== Syslog Analysis ==="
    error_count = 0
    normal_count = 0
}

/ERROR/ {
    service = $5         # 5th field = service name
    gsub(/\[.*\]/, "", service)   # remove PID like [1234]
    gsub(/:/, "", service)

    # Everything from field 6 onward = message
    msg = ""
    for (i=6; i<=NF; i++) msg = msg " " $i

    errors[service]++
    error_count++
    print "[ERROR] Service: " service " | Message:" msg
}

!/ERROR/ {
    normal_count++
}

END {
    print "\n=== Summary ==="
    print "Total Errors:   " error_count
    print "Normal entries: " normal_count

    print "\n=== Errors Per Service ==="
    for (svc in errors) {
        print "  " svc " -> " errors[svc] " errors"
    }
}
