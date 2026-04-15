# Work profile functions

ghere() {
    read -rp "Enter search string: " search
    if [[ -z "$search" ]]; then
        echo "No search string entered. Aborting."
        return 1
    fi
    grep -riI --exclude-dir={.git,deployment} --color=always "$search" .
}

# --- FZF Utilities ---

export FZF_DEFAULT_OPTS='--height 80% --layout=reverse --border --preview-window=right:60%:wrap'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --max-results 50000'
export FZF_CTRL_T_COMMAND='fd --type f --hidden --exclude .git --max-results 50000'
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git --max-results 10000'

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
