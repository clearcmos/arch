#!/usr/bin/env bash
# Video utility with multiple modes
# Usage: video --discord
set -e

VIDEO_DIR="/mnt/data/software"
VIDEO_EXTENSIONS="mp4|mkv|webm|avi|mov|flv|ts|wmv"
DISCORD_MAX_MB=10

show_help() {
    echo "Usage: video <flag>"
    echo ""
    echo "Flags:"
    echo "  --discord    Convert a video for Discord (10MB max, trimmed, clipboard)"
    echo "  --help       Show this help"
}

discord_mode() {
    # Find video files sorted by most recent
    mapfile -t videos < <(find "$VIDEO_DIR" -maxdepth 3 -type f -regextype posix-extended \
        -regex ".*\.($VIDEO_EXTENSIONS)" -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-)

    if [ ${#videos[@]} -eq 0 ]; then
        echo "No video files found in $VIDEO_DIR"
        exit 1
    fi

    # Display numbered list with relative paths and sizes
    echo "Videos in $VIDEO_DIR (most recent first):"
    echo ""
    for i in "${!videos[@]}"; do
        rel_path="${videos[$i]#$VIDEO_DIR/}"
        file_size=$(du -h "${videos[$i]}" | cut -f1)
        if [ "$i" -eq 0 ]; then
            printf "  \033[1;32m[%d] %s (%s) [default]\033[0m\n" "$((i+1))" "$rel_path" "$file_size"
        else
            printf "  [%d] %s (%s)\n" "$((i+1))" "$rel_path" "$file_size"
        fi
        # Show first 20 only
        if [ "$i" -ge 19 ]; then
            echo "  ... and $((${#videos[@]} - 20)) more"
            break
        fi
    done

    echo ""
    read -p "Select video [1]: " selection
    selection="${selection:-1}"

    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#videos[@]} ]; then
        echo "Invalid selection"
        exit 1
    fi

    input="${videos[$((selection-1))]}"
    echo ""
    echo "Selected: $(basename "$input")"

    # Get video duration
    duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null)
    if [ -z "$duration" ]; then
        echo "Error: Could not read video duration"
        exit 1
    fi

    # Calculate trimmed duration (remove first 1s and last 2s)
    trimmed_duration=$(python3 -c "
d = float('$duration')
trimmed = d - 3.0
if trimmed <= 0:
    print('ERROR')
else:
    print(f'{trimmed:.3f}')
")

    if [ "$trimmed_duration" = "ERROR" ]; then
        echo "Error: Video too short to trim (${duration}s)"
        exit 1
    fi

    echo "Original duration: ${duration}s → Trimmed: ${trimmed_duration}s (removing first 1s + last 2s)"

    # Calculate target bitrate for 10MB limit
    # 10MB = 10 * 1024 * 1024 * 8 bits, reserve 128kbps for audio
    target_bitrate=$(python3 -c "
target_bits = $DISCORD_MAX_MB * 1024 * 1024 * 8
audio_bps = 128 * 1024
duration = float('$trimmed_duration')
video_bps = int((target_bits / duration) - audio_bps)
# Cap at 5Mbps (no point going higher for Discord)
video_bps = min(video_bps, 5000 * 1024)
# Floor at 100kbps
video_bps = max(video_bps, 100 * 1024)
print(video_bps)
")

    echo "Target video bitrate: $((target_bitrate / 1024))kbps"

    # Output to same directory as input
    input_dir="$(dirname "$input")"
    output="${input_dir}/discord-$(date +%Y%m%d-%H%M%S).mp4"

    echo ""
    echo "Encoding (two-pass for best quality)..."

    # Two-pass encoding for accurate file size
    # Pass 1
    ffmpeg -y -ss 1 -i "$input" -t "$trimmed_duration" \
        -c:v libx264 -b:v "$target_bitrate" -preset medium \
        -pass 1 -passlogfile /tmp/discord-ffmpeg \
        -an -f null /dev/null 2>/dev/null

    # Pass 2
    ffmpeg -y -ss 1 -i "$input" -t "$trimmed_duration" \
        -c:v libx264 -b:v "$target_bitrate" -preset medium \
        -pass 2 -passlogfile /tmp/discord-ffmpeg \
        -c:a aac -b:a 128k \
        -movflags +faststart \
        "$output" 2>/dev/null

    # Clean up pass logs
    rm -f /tmp/discord-ffmpeg-*.log /tmp/discord-ffmpeg-*.log.mbtree

    if [ ! -f "$output" ]; then
        echo "Error: Encoding failed"
        exit 1
    fi

    file_size_bytes=$(stat -c%s "$output")
    file_size_mb=$(python3 -c "print(f'{$file_size_bytes / 1024 / 1024:.1f}')")

    # If still over limit, re-encode with lower bitrate
    if [ "$file_size_bytes" -gt $((DISCORD_MAX_MB * 1024 * 1024)) ]; then
        echo "Output ${file_size_mb}MB > ${DISCORD_MAX_MB}MB, re-encoding with lower bitrate..."
        lower_bitrate=$(python3 -c "
ratio = ($DISCORD_MAX_MB * 1024 * 1024) / $file_size_bytes * 0.95
print(int($target_bitrate * ratio))
")
        ffmpeg -y -ss 1 -i "$input" -t "$trimmed_duration" \
            -c:v libx264 -b:v "$lower_bitrate" -preset medium \
            -pass 1 -passlogfile /tmp/discord-ffmpeg \
            -an -f null /dev/null 2>/dev/null

        ffmpeg -y -ss 1 -i "$input" -t "$trimmed_duration" \
            -c:v libx264 -b:v "$lower_bitrate" -preset medium \
            -pass 2 -passlogfile /tmp/discord-ffmpeg \
            -c:a aac -b:a 96k \
            -movflags +faststart \
            "$output" 2>/dev/null

        rm -f /tmp/discord-ffmpeg-*.log /tmp/discord-ffmpeg-*.log.mbtree
        file_size_bytes=$(stat -c%s "$output")
        file_size_mb=$(python3 -c "print(f'{$file_size_bytes / 1024 / 1024:.1f}')")
    fi

    echo ""
    echo "Output: $output (${file_size_mb}MB)"

    # Delete the original file
    rm -f "$input"
    echo "Deleted original: $(basename "$input")"

    # Copy file to clipboard for Wayland (Discord paste)
    wl-copy -t text/uri-list "file://$output"
    echo "Copied to clipboard - paste in Discord with Ctrl+V"
}

# Main
case "${1:-}" in
    --discord)
        discord_mode
        ;;
    --help|-h|"")
        show_help
        ;;
    *)
        echo "Unknown flag: $1"
        show_help
        exit 1
        ;;
esac
