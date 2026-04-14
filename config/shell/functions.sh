# Shell functions

# ls - standard ls everywhere, with git ownership tags in ~/git
unalias ls 2>/dev/null
ls() {
    local resolved clean name tag
    resolved=$(readlink -f "$PWD" 2>/dev/null)
    if [[ ("$PWD" == "$HOME/git" || "$resolved" == "/mnt/data/git") && $# -eq 0 ]]; then
        command ls -lh --color=always --group-directories-first | while IFS= read -r line; do
            if [[ "$line" == total* ]]; then
                echo "$line"
                continue
            fi
            clean=$(printf '%s' "$line" | sed 's/\x1b\[[0-9;]*m//g')
            name="${clean##* }"
            tag=""
            if [[ -d "$name/.git" ]]; then
                if git -C "$name" remote get-url origin 2>/dev/null | grep -q clearcmos; then
                    tag=$' \e[32m[mine]\e[0m'
                elif git -C "$name" remote 2>/dev/null | while read -r r; do
                    git -C "$name" remote get-url "$r" 2>/dev/null
                done | grep -q clearcmos; then
                    tag=$' \e[33m[fork]\e[0m'
                fi
            fi
            printf '%s%s\n' "$line" "$tag"
        done
    else
        command ls -lh --color=auto --group-directories-first "$@"
    fi
}

# nano wrapper - switches xremap to nano mode so Ctrl+W passes through as
# nano search instead of closing the Konsole tab
nano() {
    ydotool key 192:1 192:0  # F22 -> set_mode: nano
    command nano "$@"
    ydotool key 191:1 191:0  # F21 -> set_mode: default
}

# Instawow wrapper - injects secrets from 1Password via op run
instawow() {
    op run --no-masking --env-file="$HOME/.config/op/secrets.env" -- instawow "$@"
}

# Cloudflare DNS wrappers - 1Password when GUI available, file fallback otherwise
cf-list() {
    if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        op run --no-masking --env-file="$HOME/.config/op/secrets.env" -- "$HOME/.local/bin/cf-list" "$@"
    else
        CLOUDFLARE_DNS_API_TOKEN="$(cat "$HOME/.config/cloudflare/token")" "$HOME/.local/bin/cf-list" "$@"
    fi
}
cf-delete() {
    if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        op run --no-masking --env-file="$HOME/.config/op/secrets.env" -- "$HOME/.local/bin/cf-delete" "$@"
    else
        CLOUDFLARE_DNS_API_TOKEN="$(cat "$HOME/.config/cloudflare/token")" "$HOME/.local/bin/cf-delete" "$@"
    fi
}

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

# clone - Clone a git repo into ~/git
# Reads from clipboard if no argument given
clone() {
    local url="${1:-$(wl-paste 2>/dev/null)}"

    if [[ -z "$url" ]]; then
        echo "No URL provided and clipboard is empty."
        return 1
    fi

    if [[ ! "$url" =~ ^(https?://|git@)[a-zA-Z0-9._-]+(:|/)[a-zA-Z0-9._/-]+(\.git)?$ ]]; then
        echo "Not a valid git repo URL: $url"
        return 1
    fi

    mkdir -p ~/git
    local dest=~/git/"$(basename "${url%.git}")"
    git clone "$url" "$dest" && echo "$dest" | tr -d '\n' | wl-copy && echo "Copied: $dest"
}

# g - cd to a directory in ~/git
# "g qc" + Enter fuzzy-matches to qc-law and cd's into it
g() {
    if [[ -z "$1" ]]; then
        cd ~/git
    else
        cd ~/git/"$1"
    fi
}

if [[ -n "$ZSH_VERSION" ]]; then
    _g_accept_line() {
        if [[ "$BUFFER" == g\ * ]]; then
            local query="${BUFFER#g }"
            local -a matches
            matches=("${(@f)$(find ~/git -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -i "$query" | sort)}")
            if (( ${#matches} == 1 )); then
                BUFFER="g ${matches[1]}"
            elif (( ${#matches} > 1 )); then
                # multiple matches - prefer prefix match, else take first
                local m
                for m in "${matches[@]}"; do
                    if [[ "${m:l}" == "${query:l}"* ]]; then
                        BUFFER="g $m"
                        break
                    fi
                done
            fi
        fi
        zle accept-line
    }
    zle -N _g_accept_line
    bindkey '^M' _g_accept_line

    _g() {
        local -a dirs
        dirs=("${(@f)$(find ~/git -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)}")
        compadd -a dirs
    }
    compdef _g g
fi

# --- FZF Utilities ---

export FZF_DEFAULT_OPTS='--height 80% --layout=reverse --border --preview-window=right:60%:wrap'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --max-results 50000'
export FZF_CTRL_T_COMMAND='fd --type f --hidden --exclude .git --max-results 50000'
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git --max-results 10000'

# fnano - Find file and search for string inside it, all from the fzf prompt
# Usage: type filename to filter files, add "search term" to highlight matches in preview
fnano() {
    local file
    file=$(find . -type f -not -path '*/\.*' 2>/dev/null | fzf \
        --prompt="Edit file: " \
        --header='Type filename, add "search" to highlight in preview' \
        --ansi \
        --preview-window=right:60%:wrap \
        --disabled \
        --bind "change:reload:bash -c 'q={q}; fname=\$(echo \"\$q\" | cut -d\\\"\\\" -f1 | sed \"s/ *\$//\"); if [[ -n \"\$fname\" ]]; then find . -type f -not -path \"*/\\.*\" 2>/dev/null | grep -i \"\$fname\"; else find . -type f -not -path \"*/\\.*\" 2>/dev/null; fi'" \
        --preview 'bash -c "q={q}; search=\$(echo \"\$q\" | sed -n \"s/[^\\\"]*\\\"\\(.*\\)/\\1/p\" | sed \"s/\\\"$//\"); if [[ -f {} ]]; then if [[ -n \"\$search\" ]]; then grep -n --color=always \"\$search\" {} 2>/dev/null || head -100 {} 2>/dev/null; else head -100 {} 2>/dev/null; fi; fi"'
    )

    if [[ -n "$file" ]]; then
        nano "$file"
    fi
}

# fcd - Navigate to selected directory
fcd() {
    local dir
    dir=$(find . -type d -not -path '*/\.*' 2>/dev/null | fzf \
        --prompt="Change to dir: " \
        --header="Select directory to navigate to" \
        --preview 'if [[ -d {} ]]; then
            ls -la {} 2>/dev/null | head -20
            echo ""
            echo "Files: $(find {} -maxdepth 1 -type f 2>/dev/null | wc -l)"
            echo "Dirs:  $(find {} -maxdepth 1 -type d 2>/dev/null | wc -l)"
        fi' \
        --preview-window=right:60%:wrap
    )

    if [[ -n "$dir" ]]; then
        cd "$dir" && echo "Changed to: $(pwd)"
    fi
}

# fcat - Display contents of selected file
fcat() {
    local file
    file=$(find . -type f -not -path '*/\.*' 2>/dev/null | fzf \
        --prompt="View file: " \
        --header="Select file to display contents" \
        --preview 'if [[ -f {} ]]; then
            head -100 {} 2>/dev/null || (echo "Cannot preview file contents" && echo "" && ls -lah {} && echo "" && file {})
        fi' \
        --preview-window=right:60%:wrap
    )

    if [[ -n "$file" ]]; then
        echo "=== Contents of $file ==="
        cat "$file"
    fi
}

# fgrep - Search for string in files and edit selected file with nano
fgrep() {
    local file
    file=$(echo "" | fzf --ansi \
        --prompt="Search in files: " \
        --header="Type to search file contents, select to edit" \
        --bind 'change:reload:bash -c "if [[ -n {q} ]]; then grep -r -l {q} . 2>/dev/null | grep -v \"^\\./ \\.\" ; else find . -type f -not -path \"*/\\.*\" 2>/dev/null | head -100; fi"' \
        --preview 'if [[ -n {q} ]] && [[ -f {} ]]; then
            grep -n --color=always {q} {} 2>/dev/null | head -50
        elif [[ -f {} ]]; then
            head -50 {} 2>/dev/null
        else
            echo "Start typing to search file contents"
        fi' \
        --preview-window=right:60%:wrap \
        --disabled
    )

    if [[ -n "$file" ]]; then
        nano "$file"
    fi
}
