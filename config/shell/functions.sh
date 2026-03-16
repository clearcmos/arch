# Shell functions

claim-files() {
    local files
    files=$(find . -user root -group root -print)

    if [[ -z "$files" ]]; then
        echo "No files owned by root:root found."
        return
    fi

    echo "Files owned by root:root:"
    echo "----------------------------------"
    while IFS= read -r f; do
        printf "%s:%s %s\n" "$(stat -c "%U" "$f")" "$(stat -c "%G" "$f")" "$f"
    done <<< "$files"

    echo
    read -rp "Do you want to claim these files as nicholas:users? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        while IFS= read -r f; do
            sudo chown nicholas:users "$f"
            echo "Changed ownership: $f"
        done <<< "$files"
    else
        echo "No changes made."
    fi
}

ghere() {
    read -rp "Enter search string: " search
    if [[ -z "$search" ]]; then
        echo "No search string entered. Aborting."
        return 1
    fi
    grep -riI --exclude-dir={.git,deployment} --color=always "$search" .
}

gc() {
    echo "Checking how much space would be freed by garbage collection..."

    local tmpfile
    tmpfile=$(mktemp)

    sudo nix-collect-garbage --dry-run > "$tmpfile"

    local path_count
    path_count=$(grep -c "^Would delete" "$tmpfile" || true)

    local total_bytes=0

    while read -r line; do
        size=$(echo "$line" | grep -o '[0-9.]\+ [KMGT]iB\|[0-9]\+ B' | sed 's/[[:space:]].*//')
        unit=$(echo "$line" | grep -o '[KMGT]iB\|B')

        case "$unit" in
            "B")    bytes=$size ;;
            "KiB")  bytes=$(echo "$size * 1024" | bc) ;;
            "MiB")  bytes=$(echo "$size * 1024 * 1024" | bc) ;;
            "GiB")  bytes=$(echo "$size * 1024 * 1024 * 1024" | bc) ;;
            "TiB")  bytes=$(echo "$size * 1024 * 1024 * 1024 * 1024" | bc) ;;
        esac

        total_bytes=$(echo "$total_bytes + ${bytes%%.*}" | bc)
    done < <(grep "would be deleted" "$tmpfile")

    if [ "$total_bytes" -lt 1024 ]; then
        total_hr="${total_bytes} B"
    elif [ "$total_bytes" -lt 1048576 ]; then
        total_hr="$(echo "scale=2; $total_bytes/1024" | bc) KiB"
    elif [ "$total_bytes" -lt 1073741824 ]; then
        total_hr="$(echo "scale=2; $total_bytes/1048576" | bc) MiB"
    else
        total_hr="$(echo "scale=2; $total_bytes/1073741824" | bc) GiB"
    fi

    echo "Garbage collection would free approximately $total_hr from $path_count path(s)"
    echo
    echo "Run 'sudo nix-collect-garbage' to actually free this space"

    rm "$tmpfile"
}
