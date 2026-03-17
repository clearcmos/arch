#!/bin/bash
set -euo pipefail

# Check if there are any PDFs in current directory
pdfs=$(find . -maxdepth 1 -name "*.pdf" -type f | sort -f)
if [ -z "$pdfs" ]; then
    echo "No PDF files found in current directory"
    exit 1
fi

total=$(echo "$pdfs" | wc -l)
echo "Found $total PDF(s) in current directory"
echo

# Interactive selection with fzf
selected=$(echo "$pdfs" | sed 's|^\./||' | fzf \
    --multi \
    --bind 'space:toggle,ctrl-a:select-all,ctrl-d:deselect-all' \
    --header 'SPACE=toggle | CTRL-A=select all | CTRL-D=deselect all | ENTER=confirm' \
    --prompt 'Select PDFs to merge: ' \
    --height 80% \
    --reverse \
    --border)

if [ -z "$selected" ]; then
    echo "No files selected"
    exit 1
fi

count=$(echo "$selected" | wc -l)
if [ "$count" -eq 1 ]; then
    echo "Only one file selected. Need at least 2 files to merge."
    exit 1
fi

echo "Selected $count files:"
echo "$selected" | sed 's/^/  /'
echo

read -rp "Output filename [merged.pdf]: " output
output=${output:-merged.pdf}

if [[ ! "$output" =~ \.pdf$ ]]; then
    output="${output}.pdf"
fi

if [ -f "$output" ]; then
    read -rp "'$output' already exists. Overwrite? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 1
    fi
fi

files=()
while IFS= read -r file; do
    files+=("$file")
done <<< "$selected"

# Check if any PDFs are encrypted
encrypted=false
for file in "${files[@]}"; do
    if pdfinfo "$file" 2>&1 | grep -q "Encrypted:.*yes"; then
        encrypted=true
        echo "Detected encrypted PDF: $file"
    fi
done

echo "Merging $count PDFs..."

if [ "$encrypted" = true ]; then
    echo "Using Ghostscript (handling encrypted PDFs)..."
    if gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -sOutputFile="$output" "${files[@]}"; then
        size=$(du -h "$output" | cut -f1)
        echo "Created: $output ($size)"
    else
        echo "Failed to merge PDFs with Ghostscript"
        exit 1
    fi
else
    if pdfunite "${files[@]}" "$output"; then
        size=$(du -h "$output" | cut -f1)
        echo "Created: $output ($size)"
    else
        echo "Failed to merge PDFs"
        exit 1
    fi
fi
