#!/bin/bash
# Interactive script to enable a sync configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Source required scripts
source "$SCRIPT_DIR/manage_syncs.sh" 2>/dev/null
source "$SCRIPT_DIR/menu_functions.sh" 2>/dev/null

INSTALL_DIR="$HOME/Library/icloud_backup"
SYNCS_DIR="$INSTALL_DIR/syncs"

show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}Enable Sync in CloudSyncBridge${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if a specific sync ID was provided
SYNC_ID_ARG="$1"

if [ -n "$SYNC_ID_ARG" ]; then
    # Sync ID provided - enable directly
    config_file="$SYNCS_DIR/${SYNC_ID_ARG}.conf"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Sync configuration not found: $SYNC_ID_ARG${NC}"
        echo ""
        echo "Use \"cloudsyncbridge list\" to see available syncs"
        exit 1
    fi

    # Load config to check current status
    source "$config_file"

    if [ "${ENABLED:-true}" = "true" ]; then
        echo -e "${YELLOW}Sync '$SYNC_NAME' is already enabled${NC}"
        exit 0
    fi

    # Enable the sync
    sed -i '' 's/^ENABLED=.*/ENABLED=true/' "$config_file"

    echo -e "${GREEN}✓ Enabled sync: $SYNC_NAME${NC}"
    echo ""
    echo "The sync has been re-enabled and will be included in automatic sync cycles."
    echo ""

    # Offer to run sync now
    RUN_SYNC_OPTIONS=("Yes, sync now" "No, wait for automatic sync")
    RUN_SYNC_CHOICE=$(menu "Run sync now?" "${RUN_SYNC_OPTIONS[@]}")

    echo ""

    if [ $RUN_SYNC_CHOICE -eq 0 ]; then
        echo -e "${BLUE}Running sync for: $SYNC_NAME${NC}"
        echo ""

        # Clean up any stale Unison lock files
        rm -f ~/.unison/lk* 2>/dev/null || true

        # Run the sync using sync_manager.sh
        bash "$HOME/Library/icloud_backup/sync_manager.sh" sync "$SYNC_ID_ARG"

        SYNC_EXIT=$?
        echo ""
        if [ $SYNC_EXIT -eq 0 ]; then
            echo -e "${GREEN}✓ Sync complete!${NC}"
        else
            echo -e "${YELLOW}⚠ Sync completed with warnings (exit code: $SYNC_EXIT)${NC}"
            echo "Check logs: ~/Library/Logs/icloud_backup/${SYNC_ID_ARG}.log"
        fi
    else
        echo "Skipped sync. The sync will run automatically in the next cycle."
    fi
    echo ""
    exit 0
fi

# No sync ID provided - show interactive selection
show_banner

echo -e "${CYAN}Current Syncs:${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if any syncs exist
if [ ! -d "$SYNCS_DIR" ] || [ -z "$(ls -A "$SYNCS_DIR"/*.conf 2>/dev/null)" ]; then
    echo -e "${YELLOW}No syncs configured${NC}"
    echo ""
    echo "Use \"cloudsyncbridge add\" to create a new sync"
    exit 0
fi

# Build arrays of sync information (only disabled syncs)
SYNC_IDS=()
SYNC_NAMES=()
SYNC_SOURCES=()
SYNC_DISPLAY_OPTIONS=()
DISABLED_COUNT=0

for config_file in "$SYNCS_DIR"/*.conf; do
    if [ -f "$config_file" ]; then
        source "$config_file"

        # Only show disabled syncs
        if [ "${ENABLED:-true}" = "false" ]; then
            SYNC_IDS+=("$SYNC_ID")
            SYNC_NAMES+=("$SYNC_NAME")
            SYNC_SOURCES+=("$SOURCE_PATH")
            SYNC_DISPLAY_OPTIONS+=("$SYNC_NAME ($SOURCE_PATH)")
            ((DISABLED_COUNT++))
        fi
    fi
done

if [ $DISABLED_COUNT -eq 0 ]; then
    echo -e "${GREEN}All syncs are already enabled!${NC}"
    echo ""
    echo "Use \"cloudsyncbridge list\" to see all syncs"
    exit 0
fi

# Show disabled syncs
echo -e "${YELLOW}Disabled syncs:${NC}"
echo ""
for i in "${!SYNC_IDS[@]}"; do
    echo -e "${GRAY}$((i+1)). ${SYNC_NAMES[$i]}${NC}"
    echo -e "   ${GRAY}ID: ${SYNC_IDS[$i]}${NC}"
    echo -e "   Source: ${SYNC_SOURCES[$i]}"
    echo ""
done

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Add cancel option
SYNC_DISPLAY_OPTIONS+=("Cancel - Don't enable anything")

# Show selection menu
SELECTED_INDEX=$(menu "Select a sync to enable:" "${SYNC_DISPLAY_OPTIONS[@]}")

# Check if user selected cancel
if [ $SELECTED_INDEX -eq ${#SYNC_IDS[@]} ]; then
    echo ""
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

# Get selected sync info
SELECTED_ID="${SYNC_IDS[$SELECTED_INDEX]}"
SELECTED_NAME="${SYNC_NAMES[$SELECTED_INDEX]}"

# Enable the sync
config_file="$SYNCS_DIR/${SELECTED_ID}.conf"
sed -i '' 's/^ENABLED=.*/ENABLED=true/' "$config_file"

echo ""
echo -e "${GREEN}✓ Enabled sync: $SELECTED_NAME${NC}"
echo ""
echo "The sync has been re-enabled and will be included in automatic sync cycles."
echo ""

# Offer to run sync now
RUN_SYNC_OPTIONS=("Yes, sync now" "No, wait for automatic sync")
RUN_SYNC_CHOICE=$(menu "Run sync now?" "${RUN_SYNC_OPTIONS[@]}")

echo ""

if [ $RUN_SYNC_CHOICE -eq 0 ]; then
    echo -e "${BLUE}Running sync for: $SELECTED_NAME${NC}"
    echo ""

    # Clean up any stale Unison lock files
    rm -f ~/.unison/lk* 2>/dev/null || true

    # Run the sync using sync_manager.sh
    bash "$HOME/Library/icloud_backup/sync_manager.sh" sync "$SELECTED_ID"

    SYNC_EXIT=$?
    echo ""
    if [ $SYNC_EXIT -eq 0 ]; then
        echo -e "${GREEN}✓ Sync complete!${NC}"
    else
        echo -e "${YELLOW}⚠ Sync completed with warnings (exit code: $SYNC_EXIT)${NC}"
        echo "Check logs: ~/Library/Logs/icloud_backup/${SELECTED_ID}.log"
    fi
else
    echo "Skipped sync. The sync will run automatically in the next cycle."
fi
echo ""
