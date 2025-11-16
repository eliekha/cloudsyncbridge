#!/bin/bash
# Interactive script to disable a sync configuration

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
    echo -e "${CYAN}║${NC}  ${YELLOW}Disable Sync in CloudSyncBridge${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if a specific sync ID was provided
SYNC_ID_ARG="$1"

if [ -n "$SYNC_ID_ARG" ]; then
    # Sync ID provided - disable directly
    config_file="$SYNCS_DIR/${SYNC_ID_ARG}.conf"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Sync configuration not found: $SYNC_ID_ARG${NC}"
        echo ""
        echo "Use \"cloudsyncbridge list\" to see available syncs"
        exit 1
    fi

    # Load config to check current status
    source "$config_file"

    if [ "${ENABLED:-true}" = "false" ]; then
        echo -e "${YELLOW}Sync '$SYNC_NAME' is already disabled${NC}"
        exit 0
    fi

    # Disable the sync
    sed -i '' 's/^ENABLED=.*/ENABLED=false/' "$config_file"

    echo -e "${YELLOW}○ Disabled sync: $SYNC_NAME${NC}"
    echo ""
    echo "The sync will be skipped in automatic sync cycles."
    echo -e "${GREEN}Your files remain safe in both locations.${NC}"
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

# Build arrays of sync information (only enabled syncs)
SYNC_IDS=()
SYNC_NAMES=()
SYNC_SOURCES=()
SYNC_DISPLAY_OPTIONS=()
ENABLED_COUNT=0

for config_file in "$SYNCS_DIR"/*.conf; do
    if [ -f "$config_file" ]; then
        source "$config_file"

        # Only show enabled syncs
        if [ "${ENABLED:-true}" = "true" ]; then
            SYNC_IDS+=("$SYNC_ID")
            SYNC_NAMES+=("$SYNC_NAME")
            SYNC_SOURCES+=("$SOURCE_PATH")
            SYNC_DISPLAY_OPTIONS+=("$SYNC_NAME ($SOURCE_PATH)")
            ((ENABLED_COUNT++))
        fi
    fi
done

if [ $ENABLED_COUNT -eq 0 ]; then
    echo -e "${YELLOW}All syncs are already disabled!${NC}"
    echo ""
    echo "Use \"cloudsyncbridge list\" to see all syncs"
    exit 0
fi

# Show enabled syncs
echo -e "${GREEN}Enabled syncs:${NC}"
echo ""
for i in "${!SYNC_IDS[@]}"; do
    echo -e "${GREEN}$((i+1)). ${SYNC_NAMES[$i]}${NC}"
    echo -e "   ${GRAY}ID: ${SYNC_IDS[$i]}${NC}"
    echo -e "   Source: ${SYNC_SOURCES[$i]}"
    echo ""
done

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Add cancel option
SYNC_DISPLAY_OPTIONS+=("Cancel - Don't disable anything")

# Show selection menu
SELECTED_INDEX=$(menu "Select a sync to disable:" "${SYNC_DISPLAY_OPTIONS[@]}")

# Check if user selected cancel
if [ $SELECTED_INDEX -eq ${#SYNC_IDS[@]} ]; then
    echo ""
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

# Get selected sync info
SELECTED_ID="${SYNC_IDS[$SELECTED_INDEX]}"
SELECTED_NAME="${SYNC_NAMES[$SELECTED_INDEX]}"

# Disable the sync
config_file="$SYNCS_DIR/${SELECTED_ID}.conf"
sed -i '' 's/^ENABLED=.*/ENABLED=false/' "$config_file"

echo ""
echo -e "${YELLOW}○ Disabled sync: $SELECTED_NAME${NC}"
echo ""
echo "The sync will be skipped in automatic sync cycles."
echo -e "${GREEN}Your files remain safe in both locations.${NC}"
echo ""
echo "To re-enable this sync later, run:"
echo -e "  ${GREEN}cloudsyncbridge enable $SELECTED_ID${NC}"
echo ""
