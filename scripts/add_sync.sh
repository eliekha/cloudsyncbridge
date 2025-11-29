#!/bin/bash
# Interactive script to add a new sync configuration

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
source "$SCRIPT_DIR/folder_browser.sh" 2>/dev/null
source "$SCRIPT_DIR/manage_syncs.sh" 2>/dev/null
source "$SCRIPT_DIR/menu_functions.sh" 2>/dev/null
source "$SCRIPT_DIR/exclusion_config.sh" 2>/dev/null
source "$SCRIPT_DIR/initial_sync.sh" 2>/dev/null

show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}Add New Sync to CloudSyncBridge${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show banner
show_banner

# First, show existing syncs
echo -e "${CYAN}Current Syncs:${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

INSTALL_DIR_LOCAL="$HOME/Library/icloud_backup"
SYNCS_DIR_LOCAL="$INSTALL_DIR_LOCAL/syncs"

if [ -d "$SYNCS_DIR_LOCAL" ]; then
    sync_count=0
    for config_file in "$SYNCS_DIR_LOCAL"/*.conf; do
        if [ -f "$config_file" ]; then
            (
                source "$config_file"
                ((sync_count++))
                echo -e "${GREEN}$sync_count. $SYNC_NAME${NC}"
                echo -e "   Source: $SOURCE_PATH"
                echo -e "   iCloud: $DEST_PATH"
                echo ""
            )
        fi
    done

    if [ $sync_count -eq 0 ]; then
        echo -e "${YELLOW}No syncs configured yet${NC}"
        echo ""
    fi
else
    echo -e "${YELLOW}No syncs configured yet${NC}"
    echo ""
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo ""

# Step 1: Select source folder using same browser as install
echo -e "${BLUE}Step 1: Select Folder to Sync${NC}"
echo "====================="
echo ""
echo "Use arrow keys to navigate:"
echo "  ↑/↓ - Move selection"
echo "  → - Expand folder"
echo "  ← - Collapse folder"
echo "  Enter - Select folder"
echo ""
echo "Press any key to open folder browser..."
read -n 1 -r

# Check if select_folder function is defined
if type -t select_folder > /dev/null 2>&1; then
    # Use a temp file for the result
    TEMP_FILE_FOLDER="/tmp/cloudsyncbridge_add_sync_$$"
    export FOLDER_BROWSER_RESULT_FILE="$TEMP_FILE_FOLDER"

    # Call select_folder directly (not in subshell)
    select_folder "$HOME"

    # Read result from temp file
    selected_path=$(cat "$TEMP_FILE_FOLDER" 2>/dev/null)
    rm -f "$TEMP_FILE_FOLDER"
    unset FOLDER_BROWSER_RESULT_FILE

    if [ -z "$selected_path" ] || [ "$selected_path" = "" ]; then
        clear
        echo -e "${YELLOW}Sync creation cancelled.${NC}"
        exit 0
    fi
else
    echo -e "${RED}ERROR: Folder browser not available${NC}"
    echo "Falling back to manual path entry..."
    echo ""
    echo -e "${YELLOW}Enter the full path to the folder:${NC}"
    read -p "Path: " selected_path

    # Trim quotes and whitespace
    selected_path=$(echo "$selected_path" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//')

    # Expand ~ to home directory if present
    selected_path="${selected_path/#\~/$HOME}"

    if [ -z "$selected_path" ] || [ ! -d "$selected_path" ]; then
        clear
        echo -e "${RED}Error: Invalid or non-existent path${NC}"
        echo -e "${YELLOW}Sync creation cancelled.${NC}"
        exit 1
    fi
fi

clear
show_banner

echo -e "${GREEN}✓ Selected folder:${NC} $selected_path"
echo ""

# Step 2: Ask for sync name
echo -e "${BLUE}Step 2: Name your iCloud backup folder${NC}"
folder_name=$(basename "$selected_path")
default_backup_name="${folder_name// /_}_Backup"
echo -e "${BLUE}Default: $default_backup_name${NC}"
echo ""
echo -e "Press Enter to use default, or type a custom name:"
read -p "> " sync_name

if [ -z "$sync_name" ]; then
    sync_name="$default_backup_name"
fi

echo ""
echo -e "${GREEN}✓ iCloud folder name:${NC} $sync_name"
echo ""

# Step 3: Configure exclusions using shared component
configure_exclusions "$selected_path" "$sync_name"

# Get the configured exclusions
exclude_folders=("${CONFIGURED_EXCLUDE_FOLDERS[@]}")
exclude_patterns=("${CONFIGURED_EXCLUDE_PATTERNS[@]}")

# Step 3.5: Deletion Sync Preference
echo ""
echo -e "${BLUE}Deletion Sync Preference${NC}"
echo "════════════════════════"
echo ""
echo "When you delete a file/folder in one location:"
echo ""
echo -e "${GREEN}• Sync deletions (default):${NC}"
echo "  Delete in source → deletes in iCloud"
echo "  Delete in iCloud → deletes in source"
echo ""
echo -e "${YELLOW}• Don't sync deletions:${NC}"
echo "  Deletions only affect the location where you delete"
echo "  Files remain in the other location (safer, but can cause duplicates)"
echo ""

DELETION_OPTIONS=(
    "Yes, sync deletions (recommended)"
    "No, keep files when deleted elsewhere (safer)"
)
DELETION_CHOICE=$(menu "Sync deletions between locations?" "${DELETION_OPTIONS[@]}")

echo ""

if [ $DELETION_CHOICE -eq 0 ]; then
    SYNC_DELETIONS="true"
    echo -e "${GREEN}✓ Deletions will be synced${NC}"
else
    SYNC_DELETIONS="false"
    echo -e "${YELLOW}✓ Deletions will NOT be synced (files kept in both locations)${NC}"
fi
echo ""

# Step 4: Confirmation
clear
show_banner

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}Review Your Sync Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Sync Name:${NC} $sync_name"
echo -e "${BLUE}Source:${NC} $selected_path"
echo -e "${BLUE}Destination:${NC} ~/Library/Mobile Documents/com~apple~CloudDocs/${sync_name}"
echo ""

if [ ${#exclude_folders[@]} -gt 0 ]; then
    echo -e "${BLUE}Excluded folders:${NC}"
    for folder in "${exclude_folders[@]}"; do
        echo "  • $folder"
    done
    echo ""
fi

if [ ${#exclude_patterns[@]} -gt 0 ]; then
    echo -e "${BLUE}Excluded file patterns:${NC}"
    for pattern in "${exclude_patterns[@]}"; do
        echo "  • $pattern"
    done
    echo ""
fi

if [ "$SYNC_DELETIONS" = "true" ]; then
    echo -e "${BLUE}Deletion sync:${NC} Enabled (deletions will sync)"
else
    echo -e "${BLUE}Deletion sync:${NC} Disabled (files kept when deleted elsewhere)"
fi
echo ""

# iCloud Storage Optimization prompt
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  iCloud Storage Optimization${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "CloudSyncBridge copies files to iCloud Drive, which means files"
echo "exist in BOTH your source location AND iCloud's local cache."
echo ""
echo -e "${GREEN}\"Optimize Mac Storage\"${NC} lets macOS automatically remove local"
echo "iCloud copies when disk space is needed. Files remain safe in iCloud"
echo "and download automatically when you access them."
echo ""

# Check current setting
CURRENT_OPTIMIZE=$(defaults read com.apple.bird "optimize-storage" 2>/dev/null || echo "0")

if [ "$CURRENT_OPTIMIZE" = "1" ]; then
    echo -e "Current setting: ${GREEN}ENABLED${NC} (recommended - saves disk space)"
else
    echo -e "Current setting: ${YELLOW}DISABLED${NC} (files take up double space)"
fi
echo ""

if [ "$CURRENT_OPTIMIZE" = "1" ]; then
    OPTIMIZE_OPTIONS=(
        "Keep enabled (recommended)"
        "Disable - keep all iCloud files locally"
    )
else
    OPTIMIZE_OPTIONS=(
        "Enable (recommended - saves space)"
        "Keep disabled - store all iCloud files locally"
    )
fi

OPTIMIZE_CHOICE=$(menu "Optimize Mac Storage setting:" "${OPTIMIZE_OPTIONS[@]}")

echo ""

if [ "$CURRENT_OPTIMIZE" = "1" ]; then
    # Currently enabled
    if [ $OPTIMIZE_CHOICE -eq 1 ]; then
        defaults write com.apple.bird "optimize-storage" -bool false
        echo -e "${YELLOW}✓ Optimize Mac Storage disabled${NC}"
        echo "  All iCloud files will be kept locally."
    else
        echo -e "${GREEN}✓ Keeping Optimize Mac Storage enabled${NC}"
    fi
else
    # Currently disabled
    if [ $OPTIMIZE_CHOICE -eq 0 ]; then
        defaults write com.apple.bird "optimize-storage" -bool true
        echo -e "${GREEN}✓ Optimize Mac Storage enabled${NC}"
        echo "  macOS will automatically free up space as needed."
    else
        echo -e "${YELLOW}✓ Keeping Optimize Mac Storage disabled${NC}"
        echo "  Note: Files will take up space in both locations."
    fi
fi

echo ""

CONFIRM_OPTIONS=("Yes, create this sync" "No, cancel")
CONFIRM_CHOICE=$(menu "Create this sync?" "${CONFIRM_OPTIONS[@]}")

echo ""

if [ $CONFIRM_CHOICE -ne 0 ]; then
    echo -e "${YELLOW}Sync creation cancelled.${NC}"
    exit 0
fi

# Step 5: Create the sync
echo ""
echo -e "${BLUE}Creating sync configuration...${NC}"

# Generate sync ID first (needed for patterns and initial sync)
sync_id=$(generate_sync_id "$selected_path")

# Combine folders and patterns into a single exclusions string for create_sync compatibility
# We'll manually edit the config after creation to add patterns
if create_sync "$selected_path" "$sync_name" "$SYNC_DELETIONS" "${exclude_folders[@]}"; then
    # If we have patterns, update the config file to include them
    if [ ${#exclude_patterns[@]} -gt 0 ]; then
        config_file="$HOME/Library/icloud_backup/syncs/${sync_id}.conf"

        # Build patterns string
        patterns_str=""
        for pattern in "${exclude_patterns[@]}"; do
            patterns_str="${patterns_str}    \"$pattern\"\n"
        done
        patterns_str="${patterns_str%\\n}"

        # Replace the empty SYNC_EXCLUDE_PATTERNS section
        sed -i '' "/SYNC_EXCLUDE_PATTERNS=(/{n;s/.*/$(echo -e "$patterns_str")/;}" "$config_file" 2>/dev/null || true
    fi
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}✓ Sync Created Successfully!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

    # Run initial sync prompt using shared component
    run_initial_sync 1 "$sync_id"

    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Sync Added Successfully! 🎉${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "Available commands:"
    echo ""
    echo -e "  ${GREEN}cloudsyncbridge sync${NC}     - Run sync manually"
    echo -e "  ${GREEN}cloudsyncbridge list${NC}     - View all syncs"
    echo -e "  ${GREEN}cloudsyncbridge logs${NC}     - Monitor sync logs"
    echo ""
else
    echo ""
    echo -e "${RED}✗ Failed to create sync configuration${NC}"
    exit 1
fi
