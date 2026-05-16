# ═══════════════════════════════════════════════════════════
#  auth_parser.awk — Parses auth.log
#  Extracts: failed logins, invalid users, source IPs
#  Usage: awk -f scripts/parsers/auth_parser.awk input/raw_logs/auth.log
# ═══════════════════════════════════════════════════════════

BEGIN {
    print "=== Auth Log Analysis ==="
    failed_count = 0
    success_count = 0
    invalid_count = 0
}

# Match failed password lines
/Failed password/ {
    # $0 = full line
    # Extract IP — it appears after "from" keyword
    for (i=1; i<=NF; i++) {
        if ($i == "from") {
            ip = $(i+1)
        }
        if ($i == "for") {
            user = $(i+1)
        }
    }
    failed_logins[ip]++
    failed_users[user]++
    failed_count++
    print "[FAILED LOGIN] IP: " ip " | User: " user " | Time: " $1" "$2" "$3
}

# Match successful logins
/Accepted password/ {
    for (i=1; i<=NF; i++) {
        if ($i == "from") ip = $(i+1)
        if ($i == "for")  user = $(i+1)
    }
    success_count++
    print "[SUCCESS LOGIN] IP: " ip " | User: " user
}

# Match invalid user attempts
/Invalid user/ {
    for (i=1; i<=NF; i++) {
        if ($i == "from") ip = $(i+1)
    }
    invalid_logins[ip]++
    invalid_count++
    print "[INVALID USER] IP: " ip " | Time: " $1" "$2" "$3
}

END {
    print "\n=== Summary ==="
    print "Total Failed Logins:  " failed_count
    print "Total Successful:     " success_count
    print "Total Invalid Users:  " invalid_count

    print "\n=== Failed Logins Per IP ==="
    for (ip in failed_logins) {
        print "  " ip " -> " failed_logins[ip] " attempts"
    }
}
