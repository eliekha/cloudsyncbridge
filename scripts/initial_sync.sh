#!/bin/bash
# Shared initial sync component for CloudSyncBridge
# Used by install.sh and add_sync.sh

# Get script directory for sourcing shared files
SCRIPT_DIR_SYNC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared menu functions if not already loaded
if ! type -t menu > /dev/null 2>&1; then
    source "$SCRIPT_DIR_SYNC/menu_functions.sh" 2>/dev/null
fi

# Perform initial sync prompt and execution
# Parameters:
#   $1 - Number of syncs configured (for display)
#   $2 - Optional: Specific sync ID to sync (if not provided, syncs all)
run_initial_sync() {
    local num_syncs="${1:-1}"
    local sync_id="${2:-all}"

    echo ""
    echo -e "${BLUE}Initial Sync${NC}"
    echo "============"
    echo ""
    echo "The initial sync will copy all files to iCloud."
    echo -e "${YELLOW}Note: This may take a while depending on the amount of data.${NC}"
    echo ""

    if [ "$num_syncs" -eq 1 ]; then
        echo "You have 1 folder configured for syncing."
    else
        echo "You have $num_syncs folder(s) configured for syncing."
    fi
    echo ""

    SYNC_OPTIONS=("Yes, run initial sync now" "No, I'll sync manually later")
    SYNC_CHOICE=$(menu "Run initial sync?" "${SYNC_OPTIONS[@]}")

    echo ""

    if [ $SYNC_CHOICE -eq 0 ]; then
        if [ "$num_syncs" -eq 1 ]; then
            echo -e "${BLUE}Running initial sync...${NC}"
        else
            echo -e "${BLUE}Running initial sync for all configured folders...${NC}"
        fi
        echo ""

        # Clean up any stale Unison lock files
        echo "Cleaning up any stale Unison lock files..."
        rm -f ~/.unison/lk* 2>/dev/null || true

        # Kill any existing Unison processes
        pkill -f "unison" 2>/dev/null || true
        sleep 1

        echo -e "${YELLOW}Starting sync...${NC}"
        if [ "$num_syncs" -gt 1 ]; then
            echo -e "${BLUE}Note: Each folder will be synced sequentially.${NC}"
        fi
        echo ""

        # Determine which sync_manager.sh to use
        local sync_manager=""
        if [ -f "$HOME/Library/icloud_backup/sync_manager.sh" ]; then
            sync_manager="$HOME/Library/icloud_backup/sync_manager.sh"
        elif [ -f "$SCRIPT_DIR_SYNC/sync_manager.sh" ]; then
            sync_manager="$SCRIPT_DIR_SYNC/sync_manager.sh"
        else
            echo -e "${RED}Error: sync_manager.sh not found${NC}"
            return 1
        fi

        # Run sync_manager.sh to sync
        bash "$sync_manager" "$sync_id"

        SYNC_EXIT=$?
        echo ""
        if [ $SYNC_EXIT -eq 0 ] || [ $SYNC_EXIT -eq 1 ]; then
            echo -e "${GREEN}✓ Initial sync complete!${NC}"
        else
            echo -e "${RED}✗ Sync failed (exit code: $SYNC_EXIT)${NC}"
            echo "Check logs: $HOME/Library/icloud_backup/logs/sync.log"
        fi
    else
        echo "Skipped initial sync. Run manually when ready:"
        echo "  cloudsyncbridge sync"
    fi
}

# Export function for use in other scripts
export -f run_initial_sync
