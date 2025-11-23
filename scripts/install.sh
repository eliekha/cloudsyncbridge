#!/bin/bash

# Installation script for iCloud Bidirectional Sync System (Unison)
# This sets up the launchd agents to run automatically

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cat << "EOF"
  ╔══════════════════════════════════════════════════════════════════╗
  ║                                                                  ║
  ║    ██████╗██╗      ██████╗ ██╗   ██╗██████╗                      ║
  ║   ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗                     ║
  ║   ██║     ██║     ██║   ██║██║   ██║██║  ██║                     ║
  ║   ██║     ██║     ██║   ██║██║   ██║██║  ██║                     ║
  ║   ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝                     ║
  ║    ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝                      ║
  ║                                                                  ║
  ║   ███████╗██╗   ██╗███╗   ██╗ ██████╗                            ║
  ║   ██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝                            ║
  ║   ███████╗ ╚████╔╝ ██╔██╗ ██║██║                                 ║
  ║   ╚════██║  ╚██╔╝  ██║╚██╗██║██║                                 ║
  ║   ███████║   ██║   ██║ ╚████║╚██████╗                            ║
  ║   ╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝                            ║
  ║                                                                  ║
  ║   ██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗                   ║
  ║   ██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝                   ║
  ║   ██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗                     ║
  ║   ██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝                     ║
  ║   ██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗                   ║
  ║   ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝                   ║
  ║                                                                  ║
  ╚══════════════════════════════════════════════════════════════════╝
EOF
echo ""
echo -e "${GREEN}CloudSyncBridge - Bidirectional iCloud Sync for External Drives${NC}"
echo -e "${BLUE}Installation${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared components
source "$SCRIPT_DIR/exclusion_config.sh" 2>/dev/null
source "$SCRIPT_DIR/menu_functions.sh" 2>/dev/null
source "$SCRIPT_DIR/initial_sync.sh" 2>/dev/null


# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}ERROR: Homebrew not found.${NC}"
    echo "Please install Homebrew first:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# Check if Unison is installed
echo "Checking for Unison..."
if ! command -v unison &> /dev/null; then
    echo -e "${YELLOW}Unison not found. Installing via Homebrew...${NC}"
    brew install unison
    echo -e "${GREEN}Unison installed successfully${NC}"
else
    echo -e "${GREEN}Unison is already installed ($(unison -version | head -1))${NC}"
fi

# Check if fswatch is installed
echo "Checking for fswatch..."
if ! command -v fswatch &> /dev/null; then
    echo -e "${YELLOW}fswatch not found. Installing via Homebrew...${NC}"
    brew install fswatch
    echo -e "${GREEN}fswatch installed successfully${NC}"
else
    echo -e "${GREEN}fswatch is already installed${NC}"
fi

echo ""
echo -e "${BLUE}Checking Permissions${NC}"
echo "===================="
echo ""

# Function to check Full Disk Access
check_full_disk_access() {
    # Try to read a protected location to test Full Disk Access
    if ls "$HOME/Library/Safari" &>/dev/null 2>&1; then
        return 0  # Has access
    else
        return 1  # No access
    fi
}

# Check if Full Disk Access is granted
if check_full_disk_access; then
    echo -e "${GREEN}✓ Full Disk Access is already granted${NC}"
else
    # Loop to allow retry
    FDA_GRANTED=false
    while [ "$FDA_GRANTED" = "false" ]; do
        echo -e "${YELLOW}Full Disk Access Required${NC}"
        echo ""
        echo "For automatic syncing to work, bash needs Full Disk Access permission."
        echo "This allows the sync agents to read files from your external drive."
        echo ""

        # Interactive menu for permission options
        FDA_OPTIONS=(
            "Open System Settings to grant access (recommended)"
            "Skip auto-sync (install scripts for manual use only)"
            "Cancel installation"
        )
        FDA_CHOICE=$(menu "What would you like to do?" "${FDA_OPTIONS[@]}")

        case "$FDA_CHOICE" in
            0)
                echo ""
                echo -e "${BLUE}Opening System Settings...${NC}"
                echo ""
                echo "Please follow these steps:"
                echo "  1. Click the lock icon and enter your password"
                echo "  2. Click the '+' button"
                echo "  3. Navigate to Applications folder"
                echo "  4. Find and select 'Terminal.app' (or your terminal app)"
                echo "  5. Click 'Open'"
                echo "  6. Enable the checkbox next to 'Terminal'"
                echo ""
                echo -e "${YELLOW}Note: Terminal.app needs access, not bash directly${NC}"
                echo ""

                # Open System Settings to Full Disk Access
                open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"

                echo "Press Enter after you've granted Full Disk Access..."
                read -p ""

                # Verify access was granted
                if check_full_disk_access; then
                    echo -e "${GREEN}✓ Full Disk Access verified!${NC}"
                    FDA_GRANTED=true
                else
                    echo -e "${RED}⚠ Full Disk Access not detected${NC}"
                    echo ""

                    # Interactive menu for retry options
                    RETRY_OPTIONS=(
                        "Try again"
                        "Continue anyway (auto-sync might fail)"
                        "Cancel installation"
                    )
                    RETRY_CHOICE=$(menu "Auto-sync may not work properly. Would you like to:" "${RETRY_OPTIONS[@]}")

                    case "$RETRY_CHOICE" in
                        0)
                            echo ""
                            echo -e "${BLUE}Checking again...${NC}"
                            echo ""
                            # Loop will continue
                            ;;
                        1)
                            echo ""
                            echo -e "${YELLOW}Continuing without verified Full Disk Access...${NC}"
                            FDA_GRANTED=true
                            ;;
                        *)
                            echo ""
                            echo "Installation cancelled."
                            exit 0
                            ;;
                    esac
                fi
                ;;
            1)
                echo ""
                echo -e "${YELLOW}Installing scripts for manual use only...${NC}"
                SKIP_AUTO_SYNC=true
                FDA_GRANTED=true
                ;;
            *)
                echo ""
                echo "Installation cancelled."
                exit 0
                ;;
        esac
    done
fi

echo ""
echo -e "${BLUE}Configuration${NC}"
echo "============="
echo ""

# Source folder browser and sync management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source folder_browser.sh
if [ -f "$SCRIPT_DIR/folder_browser.sh" ]; then
    source "$SCRIPT_DIR/folder_browser.sh" || {
        echo -e "${YELLOW}Warning: Could not load folder browser. Will use manual path entry.${NC}" >&2
    }
else
    echo -e "${YELLOW}Warning: folder_browser.sh not found. Will use manual path entry.${NC}" >&2
fi

# Source manage_syncs.sh
if [ -f "$SCRIPT_DIR/manage_syncs.sh" ]; then
    source "$SCRIPT_DIR/manage_syncs.sh" || {
        echo -e "${YELLOW}Warning: Could not load sync management.${NC}" >&2
    }
else
    echo -e "${YELLOW}Warning: manage_syncs.sh not found.${NC}" >&2
fi

# Array to store selected syncs
declare -a SELECTED_SYNCS_PATHS=()
declare -a SELECTED_SYNCS_NAMES=()
declare -a SELECTED_SYNCS_EXCLUDES=()

# Function to add a sync configuration
add_sync_to_list() {
    local source_path="$1"
    local sync_name="$2"
    local excludes="$3"

    SELECTED_SYNCS_PATHS+=("$source_path")
    SELECTED_SYNCS_NAMES+=("$sync_name")
    SELECTED_SYNCS_EXCLUDES+=("$excludes")
}

# Main configuration loop
while true; do
    # Show currently selected syncs
    SYNC_STATUS=""
    if [ ${#SELECTED_SYNCS_PATHS[@]} -gt 0 ]; then
        SYNC_STATUS="${BLUE}Selected folders to sync:${NC}\n"
        for i in "${!SELECTED_SYNCS_PATHS[@]}"; do
            SYNC_STATUS+="  ${GREEN}✓${NC} ${SELECTED_SYNCS_NAMES[$i]} (${SELECTED_SYNCS_PATHS[$i]})\n"
        done
        SYNC_STATUS+="\n"
    fi

    # Show banner and status before menu
    {
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}CloudSyncBridge Configuration${NC}                             ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        if [ -n "$SYNC_STATUS" ]; then
            echo -e "$SYNC_STATUS"
        fi
    } >&2

    # Main menu
    if [ ${#SELECTED_SYNCS_PATHS[@]} -eq 0 ]; then
        CONFIG_MENU_OPTIONS=(
            "Add external drive"
            "Add folder to sync"
            "Cancel installation"
        )
        CONFIG_CHOICE=$(menu "What would you like to sync?" "${CONFIG_MENU_OPTIONS[@]}")
    else
        CONFIG_MENU_OPTIONS=(
            "Add external drive"
            "Add folder to sync"
            "Continue to installation"
        )
        CONFIG_CHOICE=$(menu "Add more folders or continue?" "${CONFIG_MENU_OPTIONS[@]}")
    fi

    case "$CONFIG_CHOICE" in
        0)
            # Add external drive
            clear
            echo -e "${BLUE}Select External Drive${NC}"
            echo "====================="
            echo ""

            # Build array of available drives
            DRIVES=()
            while IFS= read -r drive; do
                DRIVES+=("$drive")
            done < <(ls -1 /Volumes/ | grep -v "Macintosh HD")

            # Build menu options
            DRIVE_MENU_OPTIONS=()
            for drive in "${DRIVES[@]}"; do
                DRIVE_MENU_OPTIONS+=("/Volumes/$drive")
            done
            DRIVE_MENU_OPTIONS+=("Other (enter custom path)")
            DRIVE_MENU_OPTIONS+=("← Back to main menu")

            # Show menu
            DRIVE_CHOICE=$(menu "Select your external drive:" "${DRIVE_MENU_OPTIONS[@]}")

            echo ""

            # Check if user selected "Back"
            if [ "$DRIVE_CHOICE" -eq $((${#DRIVES[@]} + 1)) ]; then
                continue  # Go back to main menu
            elif [ "$DRIVE_CHOICE" -eq ${#DRIVES[@]} ]; then
                # Custom path option
                echo -e "${YELLOW}Enter the full path to your external drive:${NC}"
                echo "Example: /Volumes/MyExternalDrive"
                read -p "Path: " SOURCE_DRIVE

                # Allow empty input to go back
                if [ -z "$SOURCE_DRIVE" ]; then
                    echo -e "${YELLOW}Cancelled${NC}"
                    sleep 1
                    continue
                fi
            else
                # Selected from list
                SOURCE_DRIVE="${DRIVE_MENU_OPTIONS[$DRIVE_CHOICE]}"
            fi

            # Validate the path
            if [ ! -d "$SOURCE_DRIVE" ]; then
                echo -e "${RED}ERROR: Directory does not exist: $SOURCE_DRIVE${NC}"
                echo "Please check the path and try again."
                echo "Press Enter to continue..."
                read -p ""
                continue
            fi

            # Get backup name
            DRIVE_NAME=$(basename "$SOURCE_DRIVE")
            BACKUP_FOLDER_NAME="${DRIVE_NAME// /_}_Backup"

            echo ""
            echo -e "${YELLOW}Enter the backup folder name in iCloud:${NC}"
            echo -e "${BLUE}Press Enter to use default: $BACKUP_FOLDER_NAME${NC}"
            read -p "Folder name (or press Enter for default): " USER_BACKUP_NAME

            if [ -n "$USER_BACKUP_NAME" ]; then
                BACKUP_FOLDER_NAME="$USER_BACKUP_NAME"
            fi

            # Add to list (we'll handle exclusions later)
            add_sync_to_list "$SOURCE_DRIVE" "$BACKUP_FOLDER_NAME" ""

            echo ""
            echo -e "${GREEN}✓ Added: $SOURCE_DRIVE${NC}"
            sleep 1
            ;;

        1)
            # Add folder
            clear
            echo -e "${BLUE}Select Folder to Sync${NC}"
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
                TEMP_FILE_FOLDER="/tmp/cloudsyncbridge_selected_$$"
                export FOLDER_BROWSER_RESULT_FILE="$TEMP_FILE_FOLDER"

                # Call select_folder directly (not in subshell)
                select_folder "$HOME"

                # Read result from temp file
                SELECTED_FOLDER=$(cat "$TEMP_FILE_FOLDER" 2>/dev/null)
                rm -f "$TEMP_FILE_FOLDER"
                unset FOLDER_BROWSER_RESULT_FILE

                if [ -n "$SELECTED_FOLDER" ] && [ "$SELECTED_FOLDER" != "" ]; then
                    clear
                    FOLDER_NAME=$(basename "$SELECTED_FOLDER")
                    BACKUP_FOLDER_NAME="${FOLDER_NAME// /_}_Backup"

                    echo -e "${YELLOW}Enter the backup folder name in iCloud:${NC}"
                    echo -e "${BLUE}Press Enter to use default: $BACKUP_FOLDER_NAME${NC}"
                    read -p "Folder name (or press Enter for default): " USER_BACKUP_NAME

                    if [ -n "$USER_BACKUP_NAME" ]; then
                        BACKUP_FOLDER_NAME="$USER_BACKUP_NAME"
                    fi

                    add_sync_to_list "$SELECTED_FOLDER" "$BACKUP_FOLDER_NAME" ""

                    echo ""
                    echo -e "${GREEN}✓ Added: $SELECTED_FOLDER${NC}"
                    sleep 1
                else
                    clear
                    echo -e "${YELLOW}Cancelled - returning to main menu${NC}"
                    sleep 1
                fi
            else
                echo -e "${RED}ERROR: Folder browser not available${NC}"
                echo "Falling back to manual path entry..."
                echo ""
                echo -e "${YELLOW}Enter the full path to the folder:${NC}"
                read -p "Path: " SELECTED_FOLDER

                if [ -d "$SELECTED_FOLDER" ]; then
                    FOLDER_NAME=$(basename "$SELECTED_FOLDER")
                    BACKUP_FOLDER_NAME="${FOLDER_NAME// /_}_Backup"
                    add_sync_to_list "$SELECTED_FOLDER" "$BACKUP_FOLDER_NAME" ""
                    echo -e "${GREEN}✓ Added: $SELECTED_FOLDER${NC}"
                    sleep 1
                else
                    echo -e "${RED}ERROR: Directory does not exist${NC}"
                    sleep 2
                fi
            fi
            ;;

        2)
            # Continue to installation OR Cancel installation
            if [ ${#SELECTED_SYNCS_PATHS[@]} -eq 0 ]; then
                # Cancel installation
                echo ""
                echo -e "${YELLOW}Installation cancelled.${NC}"
                exit 0
            else
                # Continue to installation
                break
            fi
            ;;
    esac
done

# For now, set legacy variables from first sync for backward compatibility
SOURCE_DRIVE="${SELECTED_SYNCS_PATHS[0]}"
BACKUP_FOLDER_NAME="${SELECTED_SYNCS_NAMES[0]}"
ICLOUD_DRIVE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
BACKUP_FOLDER="$ICLOUD_DRIVE/$BACKUP_FOLDER_NAME"

echo ""
echo -e "${BLUE}Exclusion Configuration${NC}"
echo "======================="
echo ""

# Configure exclusions for each selected sync
for sync_idx in "${!SELECTED_SYNCS_PATHS[@]}"; do
    SYNC_PATH="${SELECTED_SYNCS_PATHS[$sync_idx]}"
    SYNC_NAME="${SELECTED_SYNCS_NAMES[$sync_idx]}"

    # Use shared exclusion configuration component
    configure_exclusions "$SYNC_PATH" "$SYNC_NAME"

    # Store exclusions for this sync
    EXCLUSIONS_STR=""
    for folder in "${CONFIGURED_EXCLUDE_FOLDERS[@]}"; do
        EXCLUSIONS_STR+="$folder"$'\n'
    done
    for pattern in "${CONFIGURED_EXCLUDE_PATTERNS[@]}"; do
        EXCLUSIONS_STR+="PATTERN:$pattern"$'\n'
    done
    SELECTED_SYNCS_EXCLUDES[$sync_idx]="$EXCLUSIONS_STR"

    # Ask about deletion sync preference
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
        SELECTED_SYNCS_DELETIONS[$sync_idx]="true"
        echo -e "${GREEN}✓ Deletions will be synced${NC}"
    else
        SELECTED_SYNCS_DELETIONS[$sync_idx]="false"
        echo -e "${YELLOW}✓ Deletions will NOT be synced (files kept in both locations)${NC}"
    fi

    echo ""
    echo -e "${GREEN}✓ Configuration complete for: $SYNC_NAME${NC}"
    echo ""
done

# Show final configuration summary
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Configuration Summary${NC}                                      ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

for sync_idx in "${!SELECTED_SYNCS_PATHS[@]}"; do
    echo -e "${BLUE}Sync $((sync_idx + 1)): ${GREEN}${SELECTED_SYNCS_NAMES[$sync_idx]}${NC}"
    echo -e "  Source: ${SELECTED_SYNCS_PATHS[$sync_idx]}"
    echo -e "  Destination: ~/Library/Mobile Documents/com~apple~CloudDocs/${SELECTED_SYNCS_NAMES[$sync_idx]}"

    # Count exclusions (filter out empty lines)
    EXCLUDE_COUNT=$(echo "${SELECTED_SYNCS_EXCLUDES[$sync_idx]}" | grep -v '^$' | wc -l | xargs)
    if [ "$EXCLUDE_COUNT" -gt 0 ]; then
        echo -e "  Exclusions: $EXCLUDE_COUNT item(s)"
    else
        echo -e "  Exclusions: None"
    fi

    # Show deletion sync preference
    if [ "${SELECTED_SYNCS_DELETIONS[$sync_idx]}" = "false" ]; then
        echo -e "  Deletion sync: ${YELLOW}disabled (files kept when deleted)${NC}"
    else
        echo -e "  Deletion sync: ${GREEN}enabled${NC}"
    fi
    echo ""
done

CONFIRM_OPTIONS=("Yes, continue with installation" "No, cancel installation")
CONFIRM_CHOICE=$(menu "Continue with these settings?" "${CONFIRM_OPTIONS[@]}")

echo ""

if [ $CONFIRM_CHOICE -ne 0 ]; then
    echo "Installation cancelled."
    exit 0
fi

# Create necessary directories
if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/Library/icloud_backup"
fi
if [ -z "$SYNCS_DIR" ]; then
    SYNCS_DIR="$INSTALL_DIR/syncs"
fi
if [ -z "$LOG_DIR" ]; then
    LOG_DIR="$HOME/Library/Logs/icloud_backup"
fi
if [ -z "$LAUNCH_AGENTS_DIR" ]; then
    LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
fi

echo ""
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$SYNCS_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Create all sync configurations
echo ""
echo "Creating sync configurations..."

for sync_idx in "${!SELECTED_SYNCS_PATHS[@]}"; do
    SYNC_PATH="${SELECTED_SYNCS_PATHS[$sync_idx]}"
    SYNC_NAME="${SELECTED_SYNCS_NAMES[$sync_idx]}"
    SYNC_EXCLUSIONS="${SELECTED_SYNCS_EXCLUDES[$sync_idx]}"

    # Generate sync ID
    SYNC_ID=$(echo "$SYNC_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-_')

    # Check for duplicates
    COUNTER=1
    ORIGINAL_ID="$SYNC_ID"
    while [ -f "$SYNCS_DIR/${SYNC_ID}.conf" ]; do
        SYNC_ID="${ORIGINAL_ID}-${COUNTER}"
        ((COUNTER++))
    done

    # Parse exclusions
    EXCLUDE_FOLDERS=()
    EXCLUDE_PATTERNS=()
    while IFS= read -r line; do
        if [[ "$line" == PATTERN:* ]]; then
            EXCLUDE_PATTERNS+=("${line#PATTERN:}")
        elif [ -n "$line" ]; then
            EXCLUDE_FOLDERS+=("$line")
        fi
    done <<< "$SYNC_EXCLUSIONS"

    # Build exclusion strings
    EXCLUDE_FOLDERS_STR=""
    for folder in "${EXCLUDE_FOLDERS[@]}"; do
        EXCLUDE_FOLDERS_STR="${EXCLUDE_FOLDERS_STR}    \"$folder\"\n"
    done
    EXCLUDE_FOLDERS_STR="${EXCLUDE_FOLDERS_STR%\\n}"

    EXCLUDE_PATTERNS_STR=""
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        EXCLUDE_PATTERNS_STR="${EXCLUDE_PATTERNS_STR}    \"$pattern\"\n"
    done
    EXCLUDE_PATTERNS_STR="${EXCLUDE_PATTERNS_STR%\\n}"

    # Create iCloud destination path
    ICLOUD_DRIVE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
    DEST_PATH="$ICLOUD_DRIVE/${SYNC_NAME}"

    # Create sync configuration file
    cat > "$SYNCS_DIR/${SYNC_ID}.conf" << EOF
#!/bin/bash
# CloudSyncBridge Sync Configuration
# Generated on $(date)

# Sync identification
SYNC_ID="$SYNC_ID"
SYNC_NAME="$SYNC_NAME"

# Sync paths
SOURCE_PATH="$SYNC_PATH"
DEST_PATH="$DEST_PATH"

# Exclude folders (relative to source)
EXCLUDE_FOLDERS=(
$(echo -e "$EXCLUDE_FOLDERS_STR")
)

# Exclude patterns (in addition to global patterns)
SYNC_EXCLUDE_PATTERNS=(
$(echo -e "$EXCLUDE_PATTERNS_STR")
)

# Enable this sync
ENABLED=true

# Sync deletions between locations (true = delete syncs, false = keep files)
SYNC_DELETIONS=${SELECTED_SYNCS_DELETIONS[$sync_idx]}

# Track first sync (prevents deletions on initial sync)
FIRST_SYNC_DONE=false
EOF

    echo -e "${GREEN}✓ Created sync: $SYNC_NAME ($SYNC_ID)${NC}"
done

echo ""
echo -e "${GREEN}✓ All sync configurations created${NC}"

# Copy sync manager and related scripts
echo ""
echo "Installing sync management scripts..."
cp "$SCRIPT_DIR/sync_manager.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/manage_syncs.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/file_watcher.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/sync_manager.sh"
chmod +x "$INSTALL_DIR/manage_syncs.sh"
chmod +x "$INSTALL_DIR/file_watcher.sh"
echo -e "${GREEN}✓ Installed sync management scripts${NC}"

# Create global config
cat > "$INSTALL_DIR/global.conf" << 'GLOBALEOF'
#!/bin/bash
# CloudSyncBridge Global Configuration

# iCloud Drive location
ICLOUD_DRIVE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"

# Global exclude patterns (applied to all syncs)
EXCLUDE_PATTERNS=(".DS_Store" "*.tmp" ".Trash" ".fseventsd" ".Spotlight-V100" ".TemporaryItems")
GLOBALEOF

echo -e "${GREEN}✓${NC} Created global configuration"

# Initial Sync Section (before starting agents)
run_initial_sync "${#SELECTED_SYNCS_PATHS[@]}" "all"

# Set up and start launchd agents for automatic syncing
echo ""
echo -e "${BLUE}Setting up automatic sync...${NC}"
bash "$SCRIPT_DIR/setup_agents.sh"

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}   Installation Complete! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "Your bidirectional sync system is now running:"
    echo "  • Automatic sync every 30 minutes"
    echo "  • Uses Unison for intelligent bidirectional sync"
    echo "  • Supports renames and deletions"
    echo ""
    echo "Configured syncs (${#SELECTED_SYNCS_PATHS[@]}):"
    for sync_idx in "${!SELECTED_SYNCS_PATHS[@]}"; do
        echo ""
        echo -e "${BLUE}$((sync_idx + 1)). ${SELECTED_SYNCS_NAMES[$sync_idx]}${NC}"
        echo "   Source: ${SELECTED_SYNCS_PATHS[$sync_idx]}"
        echo "   iCloud: ~/Library/Mobile Documents/com~apple~CloudDocs/${SELECTED_SYNCS_NAMES[$sync_idx]}"
    done
    echo ""

    # Test instructions
    echo ""
    echo -e "${BLUE}═══════════════════════════${NC}"
    echo -e "${BLUE}   Test Your Setup${NC}"
    echo -e "${BLUE}═══════════════════════════${NC}"
    echo ""
    echo "To verify real-time sync is working:"
    echo ""
    echo "1. Create a test folder on your external drive:"
    echo "   mkdir \"$SOURCE_DRIVE/test_sync\""
    echo ""
    echo "2. Wait a few seconds and check iCloud:"
    echo "   ls \"$BACKUP_FOLDER/test_sync\""
    echo ""
    echo "3. Try the reverse - create a folder in iCloud:"
    echo "   mkdir \"$BACKUP_FOLDER/test_icloud\""
    echo ""
    echo "4. Check it appears on your external drive:"
    echo "   ls \"$SOURCE_DRIVE/test_icloud\""
    echo ""

    echo ""
    echo "Useful commands:"
    echo "  • View logs: cloudsyncbridge logs"
    echo "  • Manual sync: cloudsyncbridge sync"
    echo "  • Check status: cloudsyncbridge status"
    echo ""
    echo -e "${GREEN}Happy syncing! 🚀${NC}"
    echo ""
