#!/bin/bash
# File watcher for CloudSyncBridge
# Monitors source directories and triggers syncs when changes occur

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Directories
readonly CONFIG_DIR="$HOME/Library/icloud_backup"
readonly SYNCS_DIR="$CONFIG_DIR/syncs"
readonly SYNC_MANAGER="$CONFIG_DIR/sync_manager.sh"
readonly LOG_DIR="$HOME/Library/Logs/icloud_backup"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/watcher.log"
}

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    log "ERROR: fswatch is not installed. Install it with: brew install fswatch"
    exit 1
fi

# Get all enabled syncs and their SOURCE paths only
# Note: We don't watch iCloud folders because fswatch can't reliably detect changes there
# iCloud changes are handled by periodic sync instead
get_watch_paths() {
    local paths=()

    while IFS= read -r config_file; do
        if [ -f "$config_file" ]; then
            # Source config to get source path and enabled status
            (
                source "$config_file"
                if [ "${ENABLED:-true}" = "true" ]; then
                    # Output source path only (not iCloud destination)
                    if [ -d "$SOURCE_PATH" ]; then
                        echo "$SOURCE_PATH|$SYNC_ID"
                    fi
                fi
            )
        fi
    done < <(find "$SYNCS_DIR" -name "*.conf" -type f 2>/dev/null)
}

# Build the watch paths array
WATCH_CONFIGS=$(get_watch_paths)

if [ -z "$WATCH_CONFIGS" ]; then
    log "No enabled syncs found. Exiting."
    exit 0
fi

# Extract paths and sync IDs (bash 3.2 compatible)
WATCH_PATHS=()
WATCH_SYNC_IDS=()

while IFS='|' read -r path sync_id; do
    if [ -n "$path" ] && [ -d "$path" ]; then
        WATCH_PATHS+=("$path")
        WATCH_SYNC_IDS+=("$sync_id")
        log "Watching [source]: $path (sync: $sync_id)"
    fi
done <<< "$WATCH_CONFIGS"

if [ ${#WATCH_PATHS[@]} -eq 0 ]; then
    log "No valid paths to watch. Exiting."
    exit 0
fi

log "File watcher started. Monitoring ${#WATCH_PATHS[@]} path(s)"

# Debounce mechanism - track last sync time per sync ID (newline-separated)
LAST_SYNC_TIMES=""
DEBOUNCE_SECONDS=5

# Helper to get last sync time for a sync ID
get_last_sync_time() {
    local sync_id="$1"
    local time_entry=$(echo "$LAST_SYNC_TIMES" | grep "^${sync_id}|" | head -1)
    if [ -n "$time_entry" ]; then
        echo "${time_entry#*|}"
    else
        echo "0"
    fi
}

# Helper to update last sync time
update_last_sync_time() {
    local sync_id="$1"
    local new_time="$2"
    # Remove old entry
    LAST_SYNC_TIMES=$(echo "$LAST_SYNC_TIMES" | grep -v "^${sync_id}|" || echo "")
    # Add new entry
    LAST_SYNC_TIMES="${LAST_SYNC_TIMES}${sync_id}|${new_time}"$'\n'
}

# Watch for changes and trigger syncs
fswatch -r -l 2 "${WATCH_PATHS[@]}" | while read changed_path; do
    # Find which sync this path belongs to
    for i in "${!WATCH_PATHS[@]}"; do
        watch_path="${WATCH_PATHS[$i]}"
        if [[ "$changed_path" == "$watch_path"* ]]; then
            sync_id="${WATCH_SYNC_IDS[$i]}"

            # Debounce - don't sync if we just synced recently
            current_time=$(date +%s)
            last_time=$(get_last_sync_time "$sync_id")
            time_diff=$((current_time - last_time))

            if [ $time_diff -lt $DEBOUNCE_SECONDS ]; then
                # Too soon, skip
                continue
            fi

            # Trigger sync
            log "Change detected in $watch_path - triggering sync for $sync_id"
            update_last_sync_time "$sync_id" "$current_time"

            # Run sync in background to avoid blocking the watcher
            (
                "$SYNC_MANAGER" sync "$sync_id" >> "$LOG_DIR/watcher.log" 2>&1
            ) &

            break
        fi
    done
done
