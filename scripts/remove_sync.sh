#!/bin/bash
# Interactive script to remove a sync configuration

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
    echo -e "${CYAN}║${NC}  ${RED}Remove Sync from CloudSyncBridge${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if a specific sync ID was provided
SYNC_ID_ARG="$1"

if [ -n "$SYNC_ID_ARG" ]; then
    # Sync ID provided - validate and remove directly (with confirmation)
    config_file="$SYNCS_DIR/${SYNC_ID_ARG}.conf"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Sync configuration not found: $SYNC_ID_ARG${NC}"
        echo ""
        echo "Use \"cloudsyncbridge list\" to see available syncs"
        exit 1
    fi

    # Load config to show details
    source "$config_file"

    show_banner

    echo -e "${YELLOW}You are about to remove this sync:${NC}"
    echo ""
    echo -e "${BLUE}ID:${NC} $SYNC_ID"
    echo -e "${BLUE}Name:${NC} $SYNC_NAME"
    echo -e "${BLUE}Source:${NC} $SOURCE_PATH"
    echo -e "${BLUE}Destination:${NC} $DEST_PATH"
    echo ""
    echo -e "${YELLOW}⚠  This will NOT delete your files, only the sync configuration.${NC}"
    echo ""

    CONFIRM_OPTIONS=("Yes, remove this sync" "No, cancel")
    CONFIRM_CHOICE=$(menu "Are you sure?" "${CONFIRM_OPTIONS[@]}")

    echo ""

    if [ $CONFIRM_CHOICE -ne 0 ]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        exit 0
    fi

    # Step 1: Remove sync configuration
    clear
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 1: Remove Sync Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "Removing sync configuration..."
    rm -f "$config_file"
    echo -e "${GREEN}✓${NC} Removed configuration: $SYNC_ID"
    echo ""
    echo -e "${GREEN}✓ Sync configuration removed${NC}"
    echo ""

    # Step 2: Clean up Unison archives
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 2: Clean Up Sync Archives${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    unison_dir="$HOME/.unison"
    if [ -d "$unison_dir" ]; then
        echo "Removing Unison archives for this sync..."
        archives_removed=$(find "$unison_dir" -name "*${SYNC_ID}*" -type f -delete -print 2>/dev/null | wc -l | xargs)

        if [ "$archives_removed" -gt 0 ]; then
            echo -e "${GREEN}✓${NC} Removed $archives_removed archive file(s)"
        else
            echo "No archives found for this sync"
        fi
    else
        echo "No Unison archives directory found"
    fi

    echo ""
    echo -e "${GREEN}✓ Archive cleanup complete${NC}"
    echo ""

    # Final summary
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Sync Removed Successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "The sync has been removed from CloudSyncBridge."
    echo ""
    echo -e "${BLUE}Your files are safe!${NC}"
    echo "Files remain in both locations:"
    echo "  • Source: $SOURCE_PATH"
    echo "  • iCloud: $DEST_PATH"
    echo ""
    echo -e "${YELLOW}Note: Automatic sync will continue for your other configured syncs.${NC}"
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

# Build arrays of sync information
SYNC_IDS=()
SYNC_NAMES=()
SYNC_SOURCES=()
SYNC_DESTS=()
SYNC_DISPLAY_OPTIONS=()

for config_file in "$SYNCS_DIR"/*.conf; do
    if [ -f "$config_file" ]; then
        (
            source "$config_file"

            # Use printf to output in a parseable format
            printf "%s|%s|%s|%s\n" "$SYNC_ID" "$SYNC_NAME" "$SOURCE_PATH" "$DEST_PATH"
        )
    fi
done | while IFS='|' read -r id name source dest; do
    SYNC_IDS+=("$id")
    SYNC_NAMES+=("$name")
    SYNC_SOURCES+=("$source")
    SYNC_DESTS+=("$dest")

    # Create display string
    SYNC_DISPLAY_OPTIONS+=("$name ($source)")
done

# We need to re-read this data since the while loop runs in a subshell
SYNC_IDS=()
SYNC_NAMES=()
SYNC_SOURCES=()
SYNC_DESTS=()
SYNC_DISPLAY_OPTIONS=()

for config_file in "$SYNCS_DIR"/*.conf; do
    if [ -f "$config_file" ]; then
        source "$config_file"
        SYNC_IDS+=("$SYNC_ID")
        SYNC_NAMES+=("$SYNC_NAME")
        SYNC_SOURCES+=("$SOURCE_PATH")
        SYNC_DESTS+=("$DEST_PATH")
        SYNC_DISPLAY_OPTIONS+=("$SYNC_NAME ($SOURCE_PATH)")
    fi
done

# Show current syncs
for i in "${!SYNC_IDS[@]}"; do
    echo -e "${GREEN}$((i+1)). ${SYNC_NAMES[$i]}${NC}"
    echo -e "   ${GRAY}ID: ${SYNC_IDS[$i]}${NC}"
    echo -e "   Source: ${SYNC_SOURCES[$i]}"
    echo -e "   iCloud: ${SYNC_DESTS[$i]}"
    echo ""
done

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Add cancel option
SYNC_DISPLAY_OPTIONS+=("Cancel - Don't remove anything")

# Show selection menu
SELECTED_INDEX=$(menu "Select a sync to remove:" "${SYNC_DISPLAY_OPTIONS[@]}")

# Check if user selected cancel
if [ $SELECTED_INDEX -eq ${#SYNC_IDS[@]} ]; then
    echo ""
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

# Get selected sync info
SELECTED_ID="${SYNC_IDS[$SELECTED_INDEX]}"
SELECTED_NAME="${SYNC_NAMES[$SELECTED_INDEX]}"
SELECTED_SOURCE="${SYNC_SOURCES[$SELECTED_INDEX]}"
SELECTED_DEST="${SYNC_DESTS[$SELECTED_INDEX]}"

clear
show_banner

echo -e "${YELLOW}You are about to remove this sync:${NC}"
echo ""
echo -e "${BLUE}ID:${NC} $SELECTED_ID"
echo -e "${BLUE}Name:${NC} $SELECTED_NAME"
echo -e "${BLUE}Source:${NC} $SELECTED_SOURCE"
echo -e "${BLUE}Destination:${NC} $SELECTED_DEST"
echo ""
echo -e "${YELLOW}⚠  This will NOT delete your files, only the sync configuration.${NC}"
echo ""

CONFIRM_OPTIONS=("Yes, remove this sync" "No, cancel")
CONFIRM_CHOICE=$(menu "Are you sure?" "${CONFIRM_OPTIONS[@]}")

echo ""

if [ $CONFIRM_CHOICE -ne 0 ]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

# Step 1: Remove sync configuration
clear
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Step 1: Remove Sync Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

config_file="$SYNCS_DIR/${SELECTED_ID}.conf"
echo "Removing sync configuration..."
rm -f "$config_file"
echo -e "${GREEN}✓${NC} Removed configuration: $SELECTED_ID"
echo ""
echo -e "${GREEN}✓ Sync configuration removed${NC}"
echo ""

# Step 2: Clean up Unison archives
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Step 2: Clean Up Sync Archives${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

unison_dir="$HOME/.unison"
if [ -d "$unison_dir" ]; then
    echo "Removing Unison archives for this sync..."
    archives_removed=$(find "$unison_dir" -name "*${SELECTED_ID}*" -type f -delete -print 2>/dev/null | wc -l | xargs)

    if [ "$archives_removed" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Removed $archives_removed archive file(s)"
    else
        echo "No archives found for this sync"
    fi
else
    echo "No Unison archives directory found"
fi

echo ""
echo -e "${GREEN}✓ Archive cleanup complete${NC}"
echo ""

# Final summary
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}   Sync Removed Successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "The sync has been removed from CloudSyncBridge."
echo ""
echo -e "${BLUE}Your files are safe!${NC}"
echo "Files remain in both locations:"
echo "  • Source: $SELECTED_SOURCE"
echo "  • iCloud: $SELECTED_DEST"
echo ""
echo -e "${YELLOW}Note: Automatic sync will continue for your other configured syncs.${NC}"
echo ""
