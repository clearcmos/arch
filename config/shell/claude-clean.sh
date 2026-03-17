#!/bin/bash
set -euo pipefail

echo "Claude Code cleanup"
echo "==================="

deleted=0
freed=0

# Clean old conversations (older than 7 days)
for dir in /home/*/.claude/projects /root/.claude/projects; do
    [ -d "$dir" ] || continue
    while IFS= read -r f; do
        size=$(stat -c%s "$f" 2>/dev/null || echo 0)
        rm -f "$f"
        freed=$((freed + size))
        deleted=$((deleted + 1))
    done < <(find "$dir" -name "*.jsonl" -mtime +7 -type f 2>/dev/null)
done

echo "Conversations: removed $deleted file(s)"

# Clean old debug logs (older than 7 days)
debug_deleted=0
for dir in /home/*/.claude/debug /root/.claude/debug; do
    [ -d "$dir" ] || continue
    while IFS= read -r f; do
        size=$(stat -c%s "$f" 2>/dev/null || echo 0)
        rm -f "$f"
        freed=$((freed + size))
        debug_deleted=$((debug_deleted + 1))
    done < <(find "$dir" -type f -mtime +7 2>/dev/null)
done

echo "Debug logs: removed $debug_deleted file(s)"

# Clean failed telemetry
telem_deleted=0
for dir in /home/*/.claude/telemetry /root/.claude/telemetry; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        size=$(stat -c%s "$f" 2>/dev/null || echo 0)
        rm -f "$f"
        freed=$((freed + size))
        telem_deleted=$((telem_deleted + 1))
    done
done

echo "Telemetry: removed $telem_deleted file(s)"

# Clean transient cache dirs
cache_deleted=0
for base in /home/*/.claude /root/.claude; do
    for subdir in shell-snapshots session-env paste-cache cache usage-data; do
        dir="$base/$subdir"
        [ -d "$dir" ] || continue
        while IFS= read -r f; do
            size=$(stat -c%s "$f" 2>/dev/null || echo 0)
            rm -f "$f"
            freed=$((freed + size))
            cache_deleted=$((cache_deleted + 1))
        done < <(find "$dir" -type f -mtime +7 2>/dev/null)
    done
done

echo "Cache: removed $cache_deleted file(s)"

# Clean old Claude Code versions (keep only latest)
for dir in /home/*/.local/share/claude/versions /root/.local/share/claude/versions; do
    [ -d "$dir" ] || continue
    latest=$(ls -v "$dir" | tail -1)
    for f in "$dir"/*; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        if [ "$name" != "$latest" ]; then
            size=$(stat -c%s "$f" 2>/dev/null || echo 0)
            rm -f "$f"
            freed=$((freed + size))
            echo "Version: removed $name (kept $latest)"
        fi
    done
done

# Human-readable size
if [ $freed -ge 1073741824 ]; then
    human=$(echo "scale=1; $freed / 1073741824" | bc)G
elif [ $freed -ge 1048576 ]; then
    human=$(echo "scale=1; $freed / 1048576" | bc)M
elif [ $freed -ge 1024 ]; then
    human=$(echo "scale=0; $freed / 1024" | bc)K
else
    human="${freed}B"
fi

echo "Freed: $human"
