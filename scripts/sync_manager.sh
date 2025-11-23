#!/bin/bash
# Multi-sync manager for CloudSyncBridge
# Manages multiple bidirectional syncs to iCloud

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Directories
readonly CONFIG_DIR="$HOME/Library/icloud_backup"
readonly SYNCS_DIR="$CONFIG_DIR/syncs"
readonly LOG_DIR="$HOME/Library/Logs/icloud_backup"
readonly GLOBAL_CONFIG="$CONFIG_DIR/global.conf"

# Color codes (only set if not already defined)
if [ -z "$GREEN" ]; then
    readonly GREEN='\033[0;32m'
    readonly BLUE='\033[0;34m'
    readonly YELLOW='\033[1;33m'
    readonly RED='\033[0;31m'
    readonly NC='\033[0m'
fi

# Ensure directories exist
mkdir -p "$SYNCS_DIR" "$LOG_DIR"

# Logging function
log() {
    local sync_id="${1:-system}"
    local message="$2"
    local log_file="$LOG_DIR/${sync_id}.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$log_file"
}

# Progress tracking variables
TOTAL_FILES=0
COMPLETED_FILES=0
START_TIME=0
TOTAL_SIZE=0

# Parse Unison output for progress
parse_progress() {
    local sync_id="$1"
    local line

    while IFS= read -r line; do
        # Log all output
        echo "$line" >> "$LOG_DIR/${sync_id}.log"

        # Count total items to sync
        if [[ "$line" =~ ^([0-9]+)\ items\ will\ be\ synced ]]; then
            TOTAL_FILES="${BASH_REMATCH[1]}"
            START_TIME=$(date +%s)
            echo "$line"
        fi

        # Extract total size
        if [[ "$line" =~ ([0-9.]+)\ (B|KiB|MiB|GiB|TiB)\ to\ be\ synced ]]; then
            TOTAL_SIZE="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
            echo "$line"
        fi

        # Show file operations - START
        if [[ "$line" =~ ^\[BGN\]\ Copying ]]; then
            # Extract filename
            local filename=$(echo "$line" | sed 's/\[BGN\] Copying //' | sed 's/ from .*//')

            if [ $TOTAL_FILES -gt 0 ]; then
                local next_count=$((COMPLETED_FILES + 1))
                local percent=$((next_count * 100 / TOTAL_FILES))
                printf "${BLUE}[%d/%d - %d%%]${NC} Syncing: ${YELLOW}%s${NC}\n" \
                    $next_count $TOTAL_FILES $percent "$filename"
            else
                echo -e "${BLUE}Syncing:${NC} ${YELLOW}$filename${NC}"
            fi
        fi

        # Track completed files - END
        if [[ "$line" =~ ^\[END\]\ Copying ]]; then
            ((COMPLETED_FILES++))

            if [ $TOTAL_FILES -gt 0 ]; then
                local percent=$((COMPLETED_FILES * 100 / TOTAL_FILES))
                local elapsed=$(($(date +%s) - START_TIME))

                # Calculate speed and ETA
                if [ $elapsed -gt 0 ]; then
                    local files_per_sec=$(echo "scale=2; $COMPLETED_FILES / $elapsed" | bc)
                    local remaining_files=$((TOTAL_FILES - COMPLETED_FILES))
                    local eta_sec=$(echo "scale=0; $remaining_files / $files_per_sec" | bc 2>/dev/null || echo "0")

                    # Format ETA
                    local eta_str=""
                    if [ $eta_sec -gt 0 ]; then
                        local eta_min=$((eta_sec / 60))
                        local eta_sec_rem=$((eta_sec % 60))
                        if [ $eta_min -gt 0 ]; then
                            eta_str="${eta_min}m ${eta_sec_rem}s"
                        else
                            eta_str="${eta_sec}s"
                        fi
                    else
                        eta_str="calculating..."
                    fi

                    # Show completion with stats
                    printf "  ${GREEN}✓ Complete${NC} | ${YELLOW}Speed: %.1f files/s${NC} | ${CYAN}ETA: %s${NC}\n" \
                        $files_per_sec "$eta_str"
                fi
            fi
        fi

        # Show important messages
        if [[ "$line" =~ ^\[ERROR\]|^error|^Error|^Propagating|^Looking|^Reconciling ]]; then
            echo "$line"
        fi
    done

    # Final newline
    if [ $TOTAL_FILES -gt 0 ]; then
        echo ""
    fi
}

# Load global configuration
load_global_config() {
    if [ -f "$GLOBAL_CONFIG" ]; then
        source "$GLOBAL_CONFIG"
    else
        # Defaults
        export ICLOUD_DRIVE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
        export EXCLUDE_PATTERNS=(".DS_Store" "*.tmp" ".Trash" ".fseventsd" ".Spotlight-V100" ".TemporaryItems")
    fi
}

# Get all sync configurations
get_all_syncs() {
    find "$SYNCS_DIR" -name "*.conf" -type f 2>/dev/null | sort
}

# Get enabled syncs only
get_enabled_syncs() {
    while IFS= read -r config_file; do
        if [ -f "$config_file" ]; then
            # Source config to check if enabled
            (
                source "$config_file"
                if [ "${ENABLED:-true}" = "true" ]; then
                    echo "$config_file"
                fi
            )
        fi
    done < <(get_all_syncs)
}

# Load a specific sync config
load_sync_config() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Source the config
    source "$config_file"

    # Validate required fields
    if [ -z "$SYNC_ID" ] || [ -z "$SOURCE_PATH" ] || [ -z "$DEST_PATH" ]; then
        log "system" "ERROR: Invalid config file: $config_file"
        return 1
    fi

    return 0
}

# Check if source path is accessible
check_source_accessible() {
    local source_path="$1"

    if [ ! -d "$source_path" ]; then
        return 1
    fi

    # Check if we can read the directory
    if [ ! -r "$source_path" ]; then
        return 1
    fi

    return 0
}

# Build Unison ignore arguments from config
build_ignore_args() {
    IGNORE_ARGS=()

    # Add global exclude patterns
    load_global_config
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        IGNORE_ARGS+=("-ignore" "Name $pattern")
    done

    # Add sync-specific exclude folders
    if [ ${#EXCLUDE_FOLDERS[@]} -gt 0 ]; then
        for folder in "${EXCLUDE_FOLDERS[@]}"; do
            IGNORE_ARGS+=("-ignore" "Path $folder")
        done
    fi

    # Add sync-specific exclude patterns
    if [ ${#SYNC_EXCLUDE_PATTERNS[@]} -gt 0 ]; then
        for pattern in "${SYNC_EXCLUDE_PATTERNS[@]}"; do
            IGNORE_ARGS+=("-ignore" "Name $pattern")
        done
    fi
}

# Perform sync for a single configuration
perform_sync() {
    local config_file="$1"
    local sync_id=""
    local sync_name=""
    local source_path=""
    local dest_path=""

    # Load configuration
    if ! load_sync_config "$config_file"; then
        return 1
    fi

    # Use loaded variables
    sync_id="$SYNC_ID"
    sync_name="${SYNC_NAME:-$sync_id}"
    source_path="$SOURCE_PATH"
    dest_path="$DEST_PATH"

    local lock_file="$LOG_DIR/.${sync_id}.lock"

    # Check if already running
    if [ -f "$lock_file" ]; then
        local lock_pid=$(cat "$lock_file" 2>/dev/null || echo 0)
        if ps -p "$lock_pid" > /dev/null 2>&1; then
            log "$sync_id" "Sync already running (PID: $lock_pid). Skipping."
            return 0
        else
            rm -f "$lock_file"
        fi
    fi

    log "$sync_id" "Starting sync: $sync_name"

    # Check source accessibility
    if ! check_source_accessible "$source_path"; then
        log "$sync_id" "ERROR: Source path not accessible: $source_path"
        return 1
    fi

    # Create lock file
    echo $$ > "$lock_file"
    trap "rm -f '$lock_file'" EXIT

    # Ensure destination exists
    mkdir -p "$dest_path"

    # Build ignore arguments
    build_ignore_args

    # Run Unison sync
    log "$sync_id" "Syncing: $source_path <-> $dest_path"

    # Reset progress counters
    TOTAL_FILES=0
    COMPLETED_FILES=0

    # Build deletion args based on SYNC_DELETIONS setting
    DELETION_ARGS=()
    if [ "${SYNC_DELETIONS:-true}" = "false" ]; then
        # Don't sync deletions - keep files in both locations
        # Specify -nodeletion twice (once for each root) to prevent deletions in both directions
        DELETION_ARGS+=("-nodeletion" "$source_path" "-nodeletion" "$dest_path")
        log "$sync_id" "Deletion sync disabled - files will be kept when deleted elsewhere"
    fi

    # Check if this is the first sync and build command accordingly
    if [ "${FIRST_SYNC_DONE:-false}" = "false" ]; then
        log "$sync_id" "First sync detected - will copy all files and prefer source on conflicts"

        /opt/homebrew/bin/unison \
            "$source_path" \
            "$dest_path" \
            -auto \
            -batch \
            -times \
            -perms 0 \
            -fat \
            -force "$source_path" \
            -confirmbigdel=false \
            "${IGNORE_ARGS[@]}" \
            "${DELETION_ARGS[@]}" \
            -logfile "$LOG_DIR/${sync_id}.log"

        local exit_code=$?
    else
        /opt/homebrew/bin/unison \
            "$source_path" \
            "$dest_path" \
            -auto \
            -batch \
            -times \
            -perms 0 \
            -fat \
            -prefer newer \
            -confirmbigdel=false \
            "${IGNORE_ARGS[@]}" \
            "${DELETION_ARGS[@]}" \
            -logfile "$LOG_DIR/${sync_id}.log"

        local exit_code=$?
    fi

    # Mark first sync as complete only if successful
    # Exit code 0 = perfect sync
    # Exit code 1 = some items were skipped
    if [ "${FIRST_SYNC_DONE:-false}" = "false" ]; then
        if [ $exit_code -eq 0 ] || [ $exit_code -eq 1 ]; then
            log "$sync_id" "First sync complete - future syncs will use bidirectional mode"
            # Update config file to mark first sync done
            if [ -f "$config_file" ]; then
                if grep -q "^FIRST_SYNC_DONE=" "$config_file"; then
                    sed -i '' 's/^FIRST_SYNC_DONE=.*/FIRST_SYNC_DONE=true/' "$config_file"
                else
                    echo "FIRST_SYNC_DONE=true" >> "$config_file"
                fi
            fi
        else
            log "$sync_id" "First sync had errors - will retry with source preference on next sync"
        fi
    fi

    # Remove lock file
    rm -f "$lock_file"

    # Check result
    if [ $exit_code -eq 0 ]; then
        log "$sync_id" "Sync completed successfully"
        return 0
    elif [ $exit_code -eq 1 ]; then
        log "$sync_id" "WARNING: Some files were skipped, but sync completed"
        return 0
    else
        log "$sync_id" "ERROR: Sync failed with exit code $exit_code"
        return $exit_code
    fi
}

# Sync all enabled configurations
sync_all() {
    load_global_config

    local sync_count=0
    local success_count=0
    local fail_count=0

    log "system" "Starting multi-sync session"

    while IFS= read -r config_file; do
        ((sync_count++))

        if perform_sync "$config_file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done < <(get_enabled_syncs)

    log "system" "Multi-sync session complete: $success_count succeeded, $fail_count failed out of $sync_count total"

    if [ $fail_count -gt 0 ]; then
        return 1
    fi

    return 0
}

# Sync a specific configuration by ID
sync_by_id() {
    local sync_id="$1"
    local config_file="$SYNCS_DIR/${sync_id}.conf"

    if [ ! -f "$config_file" ]; then
        echo "Error: Sync configuration not found: $sync_id"
        return 1
    fi

    perform_sync "$config_file"
}

# List all syncs with status
list_syncs() {
    echo -e "${BLUE}CloudSyncBridge - Configured Syncs${NC}"
    echo ""

    local has_syncs=false

    while IFS= read -r config_file; do
        has_syncs=true

        # Load config
        (
            source "$config_file"

            local status_icon="✓"
            local status_color="$GREEN"

            if [ "${ENABLED:-true}" != "true" ]; then
                status_icon="○"
                status_color="$YELLOW"
            fi

            echo -e "${status_color}${status_icon}${NC} ${SYNC_NAME:-$SYNC_ID}"
            echo -e "  ${BLUE}ID:${NC} $SYNC_ID"
            echo -e "  ${BLUE}Source:${NC} $SOURCE_PATH"
            echo -e "  ${BLUE}Destination:${NC} $DEST_PATH"
            echo -e "  ${BLUE}Status:${NC} ${ENABLED:-true}"

            local deletion_status="enabled"
            if [ "${SYNC_DELETIONS:-true}" = "false" ]; then
                deletion_status="disabled (files kept when deleted)"
            fi
            echo -e "  ${BLUE}Deletion sync:${NC} $deletion_status"
            echo ""
        )
    done < <(get_all_syncs)

    if ! $has_syncs; then
        echo "No sync configurations found."
        echo ""
        echo "Add a new sync with: cloudsyncbridge add"
    fi
}

# Main entry point
case "${1:-all}" in
    all)
        sync_all
        ;;
    list)
        list_syncs
        ;;
    sync)
        if [ -n "$2" ]; then
            sync_by_id "$2"
        else
            echo "Usage: $0 sync <sync-id>"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {all|list|sync <id>}"
        exit 1
        ;;
esac
