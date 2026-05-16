# ═══════════════════════════════════════════════════════════
#  anomaly_detector.awk — Cross-log anomaly detection
#  Scans any log file for suspicious patterns
#  Usage: awk -f scripts/parsers/anomaly_detector.awk <logfile>
# ═══════════════════════════════════════════════════════════

BEGIN {
    print "=== Anomaly Detection Scan ==="
    total_anomalies = 0
}

# SSH brute force indicators
/Failed password|Invalid user|authentication failure/ {
    print "[SSH BRUTE FORCE] " $0
    anomaly_type["SSH Brute Force"]++
    total_anomalies++
}

# Web scanning / probing
/\.env|wp-admin|\/admin|\/passwd|\/config|\/backup/ {
    print "[WEB PROBE] " $0
    anomaly_type["Web Probing"]++
    total_anomalies++
}

# HTTP error storms
/\" 4[0-9][0-9] |\" 5[0-9][0-9] / {
    print "[HTTP ERROR] " $0
    anomaly_type["HTTP Errors"]++
    total_anomalies++
}

# System-level errors
/ERROR:|Out of memory|Segmentation fault|Disk I\/O error/ {
    print "[SYSTEM ERROR] " $0
    anomaly_type["System Errors"]++
    total_anomalies++
}

END {
    print "\n=== Anomaly Summary ==="
    print "Total anomalies found: " total_anomalies
    for (type in anomaly_type) {
        print "  " type ": " anomaly_type[type]
    }
}
