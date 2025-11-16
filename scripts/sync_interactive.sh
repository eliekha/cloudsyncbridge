#!/bin/bash
# Interactive script to trigger manual sync

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
source "$SCRIPT_DIR/menu_functions.sh" 2>/dev/null

INSTALL_DIR="$HOME/Library/icloud_backup"
SYNCS_DIR="$INSTALL_DIR/syncs"

show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}Manual Sync - CloudSyncBridge${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_banner

echo -e "${CYAN}Available Syncs:${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if any syncs exist
if [ ! -d "$SYNCS_DIR" ] || [ -z "$(ls -A "$SYNCS_DIR"/*.conf 2>/dev/null)" ]; then
    echo -e "${YELLOW}No syncs configured${NC}"
    echo ""
    echo "Use \"cloudsyncbridge add\" to create a new sync"
    exit 0
fi

# Build arrays of sync information
SYNC_IDS=()
SYNC_NAMES=()
SYNC_SOURCES=()
SYNC_STATUSES=()
SYNC_DISPLAY_OPTIONS=()

for config_file in "$SYNCS_DIR"/*.conf; do
    if [ -f "$config_file" ]; then
        source "$config_file"

        status_icon="✓"
        status_text="enabled"
        if [ "${ENABLED:-true}" = "false" ]; then
            status_icon="○"
            status_text="disabled"
        fi

        SYNC_IDS+=("$SYNC_ID")
        SYNC_NAMES+=("$SYNC_NAME")
        SYNC_SOURCES+=("$SOURCE_PATH")
        SYNC_STATUSES+=("$status_text")
        SYNC_DISPLAY_OPTIONS+=("$status_icon $SYNC_NAME ($SOURCE_PATH)")
    fi
done

# Count enabled syncs
ENABLED_COUNT=0
for status in "${SYNC_STATUSES[@]}"; do
    if [ "$status" = "enabled" ]; then
        ((ENABLED_COUNT++))
    fi
done

# Show syncs
for i in "${!SYNC_IDS[@]}"; do
    if [ "${SYNC_STATUSES[$i]}" = "enabled" ]; then
        echo -e "${GREEN}✓ ${SYNC_NAMES[$i]}${NC}"
    else
        echo -e "${GRAY}○ ${SYNC_NAMES[$i]} (disabled)${NC}"
    fi
    echo -e "   ${GRAY}ID: ${SYNC_IDS[$i]}${NC}"
    echo -e "   Source: ${SYNC_SOURCES[$i]}"
    echo ""
done

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ $ENABLED_COUNT -eq 0 ]; then
    echo -e "${YELLOW}No enabled syncs to run${NC}"
    echo ""
    echo "Enable a sync with: cloudsyncbridge enable"
    exit 0
fi

# Add "Sync all" option at the top
MENU_OPTIONS=("✓ Sync all enabled folders ($ENABLED_COUNT)")
MENU_OPTIONS+=("${SYNC_DISPLAY_OPTIONS[@]}")
MENU_OPTIONS+=("Cancel - Don't sync anything")

# Show selection menu
SELECTED_INDEX=$(menu "Select sync to run:" "${MENU_OPTIONS[@]}")

# Check if user selected cancel
if [ $SELECTED_INDEX -eq $((${#SYNC_IDS[@]} + 1)) ]; then
    echo ""
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

echo ""

# Clean up any stale Unison lock files
rm -f ~/.unison/lk* 2>/dev/null || true

# Check if "Sync all" was selected
if [ $SELECTED_INDEX -eq 0 ]; then
    echo -e "${BLUE}Syncing all enabled folders...${NC}"
    echo ""

    bash "$INSTALL_DIR/sync_manager.sh" all

    SYNC_EXIT=$?
    echo ""
    if [ $SYNC_EXIT -eq 0 ]; then
        echo -e "${GREEN}✓ All syncs complete!${NC}"
    else
        echo -e "${YELLOW}⚠ Some syncs completed with warnings${NC}"
        echo "Check logs: ~/Library/Logs/icloud_backup/"
    fi
else
    # Get selected sync (subtract 1 because of "Sync all" option)
    ACTUAL_INDEX=$((SELECTED_INDEX - 1))
    SELECTED_ID="${SYNC_IDS[$ACTUAL_INDEX]}"
    SELECTED_NAME="${SYNC_NAMES[$ACTUAL_INDEX]}"
    SELECTED_STATUS="${SYNC_STATUSES[$ACTUAL_INDEX]}"

    # Check if sync is disabled
    if [ "$SELECTED_STATUS" = "disabled" ]; then
        echo -e "${YELLOW}This sync is currently disabled.${NC}"
        echo ""
        echo "Enable it first with: cloudsyncbridge enable $SELECTED_ID"
        exit 1
    fi

    echo -e "${BLUE}Syncing: $SELECTED_NAME${NC}"
    echo ""

    bash "$INSTALL_DIR/sync_manager.sh" sync "$SELECTED_ID"

    SYNC_EXIT=$?
    echo ""
    if [ $SYNC_EXIT -eq 0 ]; then
        echo -e "${GREEN}✓ Sync complete!${NC}"
    else
        echo -e "${YELLOW}⚠ Sync completed with warnings (exit code: $SYNC_EXIT)${NC}"
        echo "Check logs: ~/Library/Logs/icloud_backup/${SELECTED_ID}.log"
    fi
fi

echo ""
