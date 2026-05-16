# ═══════════════════════════════════════════════════════════
#  apache_parser.awk — Parses Apache access logs
#  Extracts: error codes, suspicious paths, IP request counts
#  Usage: awk -f scripts/parsers/apache_parser.awk input/raw_logs/apache.log
# ═══════════════════════════════════════════════════════════

BEGIN {
    print "=== Apache Log Analysis ==="
    error_count = 0
    ok_count = 0
}

{
    ip     = $1          # first field = IP address
    method = $6          # "GET  or "POST" etc (inside quotes)
    path   = $7          # requested path
    code   = $9          # HTTP status code
    size   = $10         # response size in bytes

    # Remove leading quote from method
    gsub(/"/, "", method)
    gsub(/"/, "", path)

    # Count requests per IP
    ip_requests[ip]++

    # Classify by status code
    if (code >= 400) {
        error_count++
        error_codes[code]++
        print "[ERROR " code "] IP: " ip " | Path: " path
    } else {
        ok_count++
    }

    # Flag sensitive paths
    if (path ~ /admin|\.env|wp-admin|passwd|config|backup/) {
        print "[SENSITIVE PATH] IP: " ip " -> " path " (code: " code ")"
        sensitive_hits[ip]++
    }
}

END {
    print "\n=== Summary ==="
    print "Total OK requests:    " ok_count
    print "Total Error requests: " error_count

    print "\n=== Requests Per IP ==="
    for (ip in ip_requests) {
        print "  " ip " -> " ip_requests[ip] " requests"
    }

    print "\n=== Error Code Breakdown ==="
    for (code in error_codes) {
        print "  HTTP " code " -> " error_codes[code] " times"
    }

    print "\n=== Sensitive Path Hits ==="
    for (ip in sensitive_hits) {
        print "  " ip " -> " sensitive_hits[ip] " hits"
    }
}
