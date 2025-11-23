#!/bin/bash
# Interactive script to edit sync configuration

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
    echo -e "${CYAN}║${NC}  ${GREEN}Edit Sync Configuration - CloudSyncBridge${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if a specific sync ID was provided
SYNC_ID_ARG="$1"

if [ -z "$SYNC_ID_ARG" ]; then
    # No sync ID provided - show interactive selection
    show_banner

    echo -e "${CYAN}Select a sync to edit:${NC}"
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
    SYNC_DISPLAY_OPTIONS=()

    for config_file in "$SYNCS_DIR"/*.conf; do
        if [ -f "$config_file" ]; then
            source "$config_file"
            SYNC_IDS+=("$SYNC_ID")
            SYNC_NAMES+=("$SYNC_NAME")
            SYNC_SOURCES+=("$SOURCE_PATH")
            SYNC_DISPLAY_OPTIONS+=("$SYNC_NAME ($SOURCE_PATH)")
        fi
    done

    # Show syncs
    for i in "${!SYNC_IDS[@]}"; do
        echo -e "${GREEN}$((i+1)). ${SYNC_NAMES[$i]}${NC}"
        echo -e "   ${GRAY}ID: ${SYNC_IDS[$i]}${NC}"
        echo -e "   Source: ${SYNC_SOURCES[$i]}"
        echo ""
    done

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Add cancel option
    SYNC_DISPLAY_OPTIONS+=("Cancel - Don't edit anything")

    # Show selection menu
    SELECTED_INDEX=$(menu "Select a sync to edit:" "${SYNC_DISPLAY_OPTIONS[@]}")

    # Check if user selected cancel
    if [ $SELECTED_INDEX -eq ${#SYNC_IDS[@]} ]; then
        echo ""
        echo -e "${YELLOW}Cancelled.${NC}"
        exit 0
    fi

    SYNC_ID_ARG="${SYNC_IDS[$SELECTED_INDEX]}"
fi

# Load the selected sync configuration
config_file="$SYNCS_DIR/${SYNC_ID_ARG}.conf"

if [ ! -f "$config_file" ]; then
    echo -e "${RED}Error: Sync configuration not found: $SYNC_ID_ARG${NC}"
    echo ""
    echo "Use \"cloudsyncbridge list\" to see available syncs"
    exit 1
fi

# Source the config
source "$config_file"

# Show edit menu
show_banner

echo -e "${CYAN}Editing: ${GREEN}$SYNC_NAME${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

EDIT_OPTIONS=(
    "Toggle deletion sync (currently: ${SYNC_DELETIONS:-true})"
    "Cancel - Don't change anything"
)

EDIT_CHOICE=$(menu "What would you like to edit?" "${EDIT_OPTIONS[@]}")

echo ""

case $EDIT_CHOICE in
    0)
        # Toggle deletion sync
        if [ "${SYNC_DELETIONS:-true}" = "true" ]; then
            new_value="false"
            echo -e "${YELLOW}Disabling deletion sync...${NC}"
            echo "Files will be kept in both locations when deleted"
        else
            new_value="true"
            echo -e "${GREEN}Enabling deletion sync...${NC}"
            echo "Deletions will sync between locations"
        fi

        # Update config file
        if grep -q "^SYNC_DELETIONS=" "$config_file"; then
            sed -i '' "s/^SYNC_DELETIONS=.*/SYNC_DELETIONS=$new_value/" "$config_file"
        else
            # Add if not present (for backward compatibility)
            echo "" >> "$config_file"
            echo "# Sync deletions between locations (true = delete syncs, false = keep files)" >> "$config_file"
            echo "SYNC_DELETIONS=$new_value" >> "$config_file"
        fi

        echo ""
        echo -e "${GREEN}✓ Updated deletion sync setting${NC}"
        echo ""
        echo "Changes will take effect on the next sync."
        ;;
    *)
        echo -e "${YELLOW}Cancelled.${NC}"
        exit 0
        ;;
esac

echo ""
