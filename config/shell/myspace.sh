#!/bin/bash
printf "\n\033[1;36m%-12s %10s %10s %10s %6s\033[0m\n" "LOCATION" "SIZE" "USED" "AVAIL" "USE%"
printf "%.0s-" {1..52}
echo

# Local mounts
for mount in "/" "/mnt/data" "/mnt/syno"; do
    if mountpoint -q "$mount" 2>/dev/null || [ "$mount" = "/" ]; then
        read -r size used avail pct <<< $(df -h "$mount" 2>/dev/null | awk 'NR==2 {print $2, $3, $4, $5}')
        case "$mount" in
            "/") label="cmos" ;;
            "/mnt/data") label="cmos-data" ;;
            "/mnt/syno") label="syno" ;;
        esac
        printf "%-12s %10s %10s %10s %6s\n" "$label" "$size" "$used" "$avail" "$pct"
    fi
done

# Remote hosts
for host in misc jimmich; do
    result=$(ssh -o ConnectTimeout=3 -o BatchMode=yes "${host}.home.arpa" 'df -h /' 2>/dev/null | awk 'NR==2 {print $2, $3, $4, $5}')
    if [ -n "$result" ]; then
        read -r size used avail pct <<< "$result"
        printf "%-12s %10s %10s %10s %6s\n" "$host" "$size" "$used" "$avail" "$pct"
    else
        printf "%-12s %10s %10s %10s %6s\n" "$host" "-" "-" "-" "offline"
    fi
done
echo
