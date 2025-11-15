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

# Interactive menu function with arrow key navigation
menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local last_selected=-1

    # Hide cursor
    tput civis >&2

    # Draw initial menu (to stderr so it doesn't get captured)
    echo -e "${YELLOW}${prompt}${NC}" >&2
    echo -e "${BLUE}Use ↑/↓ arrows to navigate, Enter to select${NC}" >&2
    for i in "${!options[@]}"; do
        echo "" >&2
    done

    while true; do
        # Move cursor to start of options (skip prompt + instruction line)
        tput cuu $(( ${#options[@]} )) >&2

        # Display options
        for i in "${!options[@]}"; do
            # Clear the line
            tput el >&2
            if [ $i -eq $selected ]; then
                echo -e "  ${GREEN}▶ ${options[$i]}${NC}" >&2
            else
                echo "    ${options[$i]}" >&2
            fi
        done

        # Read key from tty
        IFS= read -rsn1 key </dev/tty

        # Handle arrow keys (escape sequences)
        if [ "$key" = $'\x1b' ]; then
            IFS= read -rsn2 key </dev/tty
            case "$key" in
                '[A') # Up arrow
                    ((selected--))
                    if [ $selected -lt 0 ]; then
                        selected=$(( ${#options[@]} - 1 ))
                    fi
                    ;;
                '[B') # Down arrow
                    ((selected++))
                    if [ $selected -ge ${#options[@]} ]; then
                        selected=0
                    fi
                    ;;
            esac
        elif [ "$key" = "" ]; then
            # Enter key
            break
        fi
    done

    # Show cursor
    tput cnorm >&2

    # Output selected index to stdout (not stderr)
    echo "$selected"
}

# Multi-select menu function with space to toggle, enter to confirm
# Usage: multi_select_menu "prompt" preselect_pattern option1 option2 option3...
# preselect_pattern: regex pattern to match options that should be pre-checked (use "NONE" for no preselection)
multi_select_menu() {
    local prompt="$1"
    local preselect_pattern="$2"
    shift 2
    local options=("$@")
    local selected=0
    local -a checked=()

    # Initialize checkboxes - pre-check items matching pattern
    for i in "${!options[@]}"; do
        if [ "$preselect_pattern" != "NONE" ] && [[ "${options[$i]}" =~ $preselect_pattern ]]; then
            checked[$i]=1
        else
            checked[$i]=0
        fi
    done

    # Hide cursor
    tput civis >&2

    # Draw initial menu header (to stderr so it doesn't get captured)
    echo -e "${YELLOW}${prompt}${NC}" >&2
    echo -e "${BLUE}Use ↑/↓ to navigate, Space to toggle [✓], Enter when done${NC}" >&2

    # Draw initial options
    for i in "${!options[@]}"; do
        local checkbox="[ ]"
        if [ ${checked[$i]} -eq 1 ]; then
            checkbox="[✓]"
        fi

        if [ $i -eq $selected ]; then
            echo -e "  ${GREEN}▶ ${checkbox} ${options[$i]}${NC}" >&2
        else
            echo "    ${checkbox} ${options[$i]}" >&2
        fi
    done

    while true; do
        # Read key from tty (IFS= prevents trimming of space character)
        IFS= read -rsn1 key </dev/tty

        # Handle key input FIRST before redrawing
        local should_redraw=0

        if [ "$key" = $'\x1b' ]; then
            # Arrow key - read the rest of the escape sequence
            IFS= read -rsn2 rest </dev/tty
            case "$rest" in
                '[A') # Up arrow
                    ((selected--))
                    if [ $selected -lt 0 ]; then
                        selected=$(( ${#options[@]} - 1 ))
                    fi
                    should_redraw=1
                    ;;
                '[B') # Down arrow
                    ((selected++))
                    if [ $selected -ge ${#options[@]} ]; then
                        selected=0
                    fi
                    should_redraw=1
                    ;;
            esac
        elif [ "$key" = " " ]; then
            # Space - toggle selection
            if [ ${checked[$selected]} -eq 1 ]; then
                checked[$selected]=0
            else
                checked[$selected]=1
            fi
            should_redraw=1
        elif [ "$key" = "" ]; then
            # Enter - done
            break
        fi

        # Only redraw if something changed
        if [ $should_redraw -eq 1 ]; then
            # Move cursor back up to start of options
            tput cuu $(( ${#options[@]} )) >&2

            # Redraw all options
            for i in "${!options[@]}"; do
                tput el >&2
                local checkbox="[ ]"
                if [ ${checked[$i]} -eq 1 ]; then
                    checkbox="[✓]"
                fi

                if [ $i -eq $selected ]; then
                    echo -e "  ${GREEN}▶ ${checkbox} ${options[$i]}${NC}" >&2
                else
                    echo "    ${checkbox} ${options[$i]}" >&2
                fi
            done
        fi
    done

    # Show cursor
    tput cnorm >&2

    # Return checked items as space-separated indices (only this goes to stdout)
    local result=""
    for i in "${!checked[@]}"; do
        if [ ${checked[$i]} -eq 1 ]; then
            result="$result $i"
        fi
    done
    echo "$result"
}

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

# Build array of available drives (compatible with bash 3.2+)
DRIVES=()
while IFS= read -r drive; do
    DRIVES+=("$drive")
done < <(ls -1 /Volumes/ | grep -v "Macintosh HD")

# Build menu options
MENU_OPTIONS=()
for drive in "${DRIVES[@]}"; do
    MENU_OPTIONS+=("/Volumes/$drive")
done
MENU_OPTIONS+=("Other (enter custom path)")

# Show menu
DRIVE_CHOICE=$(menu "Select your external drive:" "${MENU_OPTIONS[@]}")

echo ""

if [ "$DRIVE_CHOICE" -eq ${#DRIVES[@]} ]; then
    # Custom path option
    echo -e "${YELLOW}Enter the full path to your external drive:${NC}"
    echo "Example: /Volumes/MyExternalDrive"
    read -p "Path: " SOURCE_DRIVE
else
    # Selected from list
    SOURCE_DRIVE="${MENU_OPTIONS[$DRIVE_CHOICE]}"
fi

# Validate the path
if [ ! -d "$SOURCE_DRIVE" ]; then
    echo -e "${RED}ERROR: Directory does not exist: $SOURCE_DRIVE${NC}"
    echo "Please check the path and try again."
    exit 1
fi

echo -e "${GREEN}✓ Selected: $SOURCE_DRIVE${NC}"

# Extract drive name for backup folder
DRIVE_NAME=$(basename "$SOURCE_DRIVE")
BACKUP_FOLDER_NAME="${DRIVE_NAME// /_}_Backup"

echo ""
echo -e "${YELLOW}Enter the backup folder name in iCloud:${NC}"
echo -e "${BLUE}Press Enter to use default: $BACKUP_FOLDER_NAME${NC}"
read -p "Folder name (or press Enter for default): " USER_BACKUP_NAME

if [ -n "$USER_BACKUP_NAME" ]; then
    BACKUP_FOLDER_NAME="$USER_BACKUP_NAME"
fi

ICLOUD_DRIVE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
BACKUP_FOLDER="$ICLOUD_DRIVE/$BACKUP_FOLDER_NAME"

echo ""
echo -e "${BLUE}Exclusion Configuration${NC}"
echo "======================="
echo ""

# Scan for top-level folders in source drive
echo "Scanning folders in $SOURCE_DRIVE..."
FOLDER_OPTIONS=()
while IFS= read -r folder; do
    # Include ALL folders (visible and hidden)
    if [ -d "$SOURCE_DRIVE/$folder" ]; then
        FOLDER_OPTIONS+=("$folder")
    fi
done < <(ls -1a "$SOURCE_DRIVE" 2>/dev/null | grep -v '^\.\.?$')

# Default recommended exclusions
RECOMMENDED_EXCLUDES=(
    ".Spotlight-V100"
    ".DocumentRevisions-V100"
    ".TemporaryItems"
    ".Trashes"
    ".fseventsd"
)

# Build display options with "(recommended)" labels
FULL_FOLDER_OPTIONS=()
for folder in "${FOLDER_OPTIONS[@]}"; do
    # Check if it's a recommended exclusion
    is_recommended=0
    for rec in "${RECOMMENDED_EXCLUDES[@]}"; do
        if [ "$folder" = "$rec" ]; then
            is_recommended=1
            break
        fi
    done

    if [ $is_recommended -eq 1 ]; then
        FULL_FOLDER_OPTIONS+=("$folder (recommended)")
    else
        FULL_FOLDER_OPTIONS+=("$folder")
    fi
done

echo "Found ${#FOLDER_OPTIONS[@]} folders"

if [ ${#FULL_FOLDER_OPTIONS[@]} -gt 0 ]; then
    echo ""
    echo "Select folders to EXCLUDE from sync:"
    echo -e "${BLUE}Recommended exclusions are pre-selected${NC}"
    echo ""

    SELECTED_INDICES=$(multi_select_menu "Choose folders to exclude:" "\(recommended\)" "${FULL_FOLDER_OPTIONS[@]}")

    # Build exclude folders array from selection
    EXCLUDE_FOLDERS=()
    for idx in $SELECTED_INDICES; do
        # Remove " (recommended)" suffix if present
        folder="${FOLDER_OPTIONS[$idx]}"
        EXCLUDE_FOLDERS+=("$folder")
    done

    echo ""
    if [ ${#EXCLUDE_FOLDERS[@]} -gt 0 ]; then
        echo -e "${GREEN}✓ Will exclude ${#EXCLUDE_FOLDERS[@]} top-level folder(s)${NC}"
    else
        echo -e "${YELLOW}No top-level folders will be excluded${NC}"
    fi
else
    EXCLUDE_FOLDERS=()
    echo -e "${YELLOW}No folders found in source drive${NC}"
fi

# Subfolder exclusions
echo ""
echo -e "${BLUE}Subfolder Exclusions${NC}"
echo "===================="
echo ""
echo "Do you want to exclude any specific subfolders?"
echo "Example: Projects/node_modules, Documents/cache"
echo ""

SUBFOLDER_OPTIONS=("Yes, add subfolder exclusions" "No, skip this step")
SUBFOLDER_CHOICE=$(menu "Exclude specific subfolders?" "${SUBFOLDER_OPTIONS[@]}")

echo ""

if [ $SUBFOLDER_CHOICE -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}Enter subfolder paths to exclude (comma-separated):${NC}"
    echo "Paths are relative to your external drive root."
    echo "Example: Projects/temp, Documents/.git, Music/duplicates"
    echo ""
    read -p "Subfolder paths: " subfolder_input

    if [ -n "$subfolder_input" ]; then
        # Split by comma and trim whitespace
        IFS=',' read -ra SUBFOLDERS <<< "$subfolder_input"
        for subfolder in "${SUBFOLDERS[@]}"; do
            # Trim leading/trailing whitespace
            subfolder=$(echo "$subfolder" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "$subfolder" ]; then
                EXCLUDE_FOLDERS+=("$subfolder")
                echo -e "${GREEN}✓ Added: $subfolder${NC}"
            fi
        done
    fi
    echo ""
    echo -e "${GREEN}✓ Total folders to exclude: ${#EXCLUDE_FOLDERS[@]}${NC}"
else
    echo "Skipped subfolder exclusions"
fi

# File patterns to exclude
echo ""
echo -e "${BLUE}File Pattern Exclusions${NC}"
echo "========================"
echo ""
echo "Default exclusions:"
echo "  • *.env (environment files)"
echo "  • .DS_Store (macOS metadata)"
echo "  • ._* (macOS resource forks)"
echo ""

PATTERN_OPTIONS=("Yes, add default exclusions" "No, skip defaults")
PATTERN_CHOICE=$(menu "Add these default exclusions?" "${PATTERN_OPTIONS[@]}")

echo ""

EXCLUDE_PATTERNS=()
if [ $PATTERN_CHOICE -eq 0 ]; then
    EXCLUDE_PATTERNS=("*.env" ".DS_Store" "._*")
    echo -e "${GREEN}✓ Added default file patterns${NC}"
else
    echo "Skipped default patterns"
fi

# Allow custom patterns
echo ""
echo -e "${YELLOW}Add custom file patterns to exclude? (one per line, empty line to finish)${NC}"
echo "Examples: *.log, *.tmp, node_modules, .git"
echo ""

while true; do
    read -p "Pattern (or press Enter to finish): " custom_pattern
    if [ -z "$custom_pattern" ]; then
        break
    fi
    EXCLUDE_PATTERNS+=("$custom_pattern")
    echo -e "${GREEN}✓ Added: $custom_pattern${NC}"
done

if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Total file patterns to exclude: ${#EXCLUDE_PATTERNS[@]}${NC}"
fi

echo ""
echo -e "${GREEN}Configuration Summary:${NC}"
echo "  Source: $SOURCE_DRIVE"
echo "  Destination: $BACKUP_FOLDER"
if [ ${#EXCLUDE_FOLDERS[@]} -gt 0 ]; then
    echo "  Excluded folders (${#EXCLUDE_FOLDERS[@]}):"
    for folder in "${EXCLUDE_FOLDERS[@]}"; do
        echo "    • $folder"
    done
else
    echo "  Excluded folders: None"
fi
if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
    echo "  Excluded patterns (${#EXCLUDE_PATTERNS[@]}):"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        echo "    • $pattern"
    done
else
    echo "  Excluded patterns: None"
fi
CONFIRM_OPTIONS=("Yes, continue with installation" "No, cancel installation")
CONFIRM_CHOICE=$(menu "Continue with these settings?" "${CONFIRM_OPTIONS[@]}")

echo ""

if [ $CONFIRM_CHOICE -ne 0 ]; then
    echo "Installation cancelled."
    exit 0
fi

# Create necessary directories
INSTALL_DIR="$HOME/Library/icloud_backup"
LOG_DIR="$HOME/Library/Logs/icloud_backup"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo ""
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Generate config.sh from template
echo ""
echo "Generating configuration file..."

# Build folder exclusions string
EXCLUDE_FOLDERS_STR=""
for folder in "${EXCLUDE_FOLDERS[@]}"; do
    EXCLUDE_FOLDERS_STR="${EXCLUDE_FOLDERS_STR}    \"$folder\"\n"
done
# Remove trailing newline
EXCLUDE_FOLDERS_STR="${EXCLUDE_FOLDERS_STR%\\n}"

# Build pattern exclusions string
EXCLUDE_PATTERNS_STR=""
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    EXCLUDE_PATTERNS_STR="${EXCLUDE_PATTERNS_STR}    \"$pattern\"\n"
done
# Remove trailing newline
EXCLUDE_PATTERNS_STR="${EXCLUDE_PATTERNS_STR%\\n}"

cat > "$INSTALL_DIR/config.sh" << EOF
#!/bin/bash

# CloudSyncBridge Configuration
# Generated by CloudSyncBridge installer

# Source: External drive to back up
SOURCE_DRIVE="$SOURCE_DRIVE"

# Destination: iCloud Drive folder
ICLOUD_DRIVE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
BACKUP_FOLDER="$BACKUP_FOLDER"

# Folders to exclude (relative to source drive)
EXCLUDE_FOLDERS=(
$(echo -e "$EXCLUDE_FOLDERS_STR")
)

# File patterns to exclude
EXCLUDE_PATTERNS=(
$(echo -e "$EXCLUDE_PATTERNS_STR")
)

# Log file location
LOG_DIR="$HOME/Library/Logs/icloud_backup"
LOG_FILE="\$LOG_DIR/sync.log"
EOF

echo -e "${GREEN}✓${NC} Created config.sh"

# Copy scripts to ~/Library/icloud_backup
echo ""
echo "Installing scripts..."

# Create Unison sync script
cat > "$INSTALL_DIR/sync_unison.sh" << 'SYNCEOF'
#!/bin/bash
# Unison bidirectional sync script
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
mkdir -p "$LOG_DIR"
LOCK_FILE="$LOG_DIR/.sync_unison.lock"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UNISON] $1" | tee -a "$LOG_FILE"; }
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo 0)
        if ps -p "$lock_pid" > /dev/null 2>&1; then
            log "Sync already running (PID: $lock_pid). Skipping."
            return 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    return 0
}
set_lock() { echo $$ > "$LOCK_FILE"; }
remove_lock() { rm -f "$LOCK_FILE"; }
trap remove_lock EXIT
check_source_mounted() {
    if [ ! -d "$SOURCE_DRIVE" ]; then
        log "ERROR: External drive not mounted at $SOURCE_DRIVE"
        return 1
    fi
    return 0
}
build_ignore_args() {
    IGNORE_ARGS=()
    for folder in "${EXCLUDE_FOLDERS[@]}"; do
        IGNORE_ARGS+=("-ignore" "Path $folder")
    done
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        IGNORE_ARGS+=("-ignore" "Name $pattern")
    done
}
perform_sync() {
    check_lock || exit 0
    log "Starting bidirectional sync"
    check_source_mounted || exit 1
    mkdir -p "$BACKUP_FOLDER"
    set_lock
    build_ignore_args
    log "Running Unison sync..."
    /opt/homebrew/bin/unison "$SOURCE_DRIVE" "$BACKUP_FOLDER" -auto -batch -times -perms 0 -fat -prefer newer -confirmbigdel=false "${IGNORE_ARGS[@]}" -logfile "$LOG_FILE" 2>&1 | while read line; do
        echo "$line" | tee -a "$LOG_FILE"
    done
    UNISON_EXIT_CODE=${PIPESTATUS[0]}
    if [ $UNISON_EXIT_CODE -eq 0 ]; then
        log "Sync completed successfully"
    elif [ $UNISON_EXIT_CODE -eq 1 ]; then
        log "WARNING: Some files were skipped, but sync completed"
    else
        log "ERROR: Sync failed with exit code $UNISON_EXIT_CODE"
        exit $UNISON_EXIT_CODE
    fi
}
perform_sync
SYNCEOF

chmod +x "$INSTALL_DIR/sync_unison.sh"
echo -e "${GREEN}✓${NC} Installed sync_unison.sh"

# Create watch script
cat > "$INSTALL_DIR/watch_unison.sh" << 'WATCHEOF'
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WATCH] $1" | tee -a "$LOG_FILE"; }
if ! command -v fswatch &> /dev/null; then
    log "ERROR: fswatch not found"
    exit 1
fi
[ ! -d "$BACKUP_FOLDER" ] && mkdir -p "$BACKUP_FOLDER"
log "Starting file system watcher on both locations..."
/opt/homebrew/bin/fswatch -0 --event Created --event Updated --event Removed --event Renamed --exclude '/\.Spotlight-V100/' --exclude '/\.DocumentRevisions-V100/' --exclude '/\.TemporaryItems/' --exclude '/\.Trashes/' --exclude '/\.fseventsd/' --exclude '\.DS_Store$' --exclude '/Applications/' --exclude '\.unison' --latency 5 "$SOURCE_DRIVE" "$BACKUP_FOLDER" | while read -d "" event; do
    [[ "$event" == "$SOURCE_DRIVE"* ]] && log "Change on external drive: $event" || log "Change in iCloud: $event"
    log "Triggering sync..."
    "$SCRIPT_DIR/sync_unison.sh"
done
WATCHEOF

chmod +x "$INSTALL_DIR/watch_unison.sh"
echo -e "${GREEN}✓${NC} Installed watch_unison.sh"

# Create launchd agents (skip if user chose manual-only mode)
if [ "$SKIP_AUTO_SYNC" != "true" ]; then
    echo ""
    echo "Installing launchd agents..."

    # Unload old agents if they exist
    for agent in com.icloudbackup.unison.watch com.icloudbackup.unison.periodic; do
        if [ -f "$LAUNCH_AGENTS_DIR/${agent}.plist" ]; then
            launchctl unload "$LAUNCH_AGENTS_DIR/${agent}.plist" 2>/dev/null || true
        fi
    done

    # Watch agent
    cat > "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist" << WATCHPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.icloudbackup.unison.watch</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/watch_unison.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>PathState</key>
        <dict>
            <key>$SOURCE_DRIVE</key>
            <true/>
        </dict>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/icloudbackup.unison.watch.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/icloudbackup.unison.watch.error.log</string>
    <key>ThrottleInterval</key>
    <integer>5</integer>
</dict>
</plist>
WATCHPLIST

echo -e "${GREEN}✓${NC} Installed watch agent"

# Periodic agent
cat > "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist" << PERIODICPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.icloudbackup.unison.periodic</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/sync_unison.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/icloudbackup.unison.periodic.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/icloudbackup.unison.periodic.error.log</string>
</dict>
</plist>
PERIODICPLIST

echo -e "${GREEN}✓${NC} Installed periodic agent"

    # Clean up before starting agents
    echo ""
    echo "Preparing to start agents..."

    # Clean Unison locks
    rm -f ~/.unison/lk* 2>/dev/null || true

    # Kill any existing Unison processes
    pkill -f "unison.*$SOURCE_DRIVE" 2>/dev/null || true
    sleep 1

    # Load agents
    echo "Starting agents..."
    launchctl load "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist"
    echo -e "${GREEN}✓${NC} Started real-time watcher"

    launchctl load "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist"
    echo -e "${GREEN}✓${NC} Started periodic sync"

    # Ask about initial sync
    echo ""
    echo -e "${BLUE}Initial Sync${NC}"
    echo "============"
    echo ""
    echo "The initial sync will copy all files from your external drive to iCloud."
    echo -e "${YELLOW}Note: This may take a while depending on drive size.${NC}"
    echo ""

    SYNC_OPTIONS=("Yes, run initial sync now" "No, I'll sync manually later")
    SYNC_CHOICE=$(menu "Run initial sync?" "${SYNC_OPTIONS[@]}")

    echo ""

    if [ $SYNC_CHOICE -eq 0 ]; then
        echo -e "${BLUE}Running initial sync...${NC}"
        echo ""

        # Clean up any stale Unison lock files
        echo "Cleaning up any stale Unison lock files..."
        rm -f ~/.unison/lk* 2>/dev/null || true

        # Kill any existing Unison processes
        pkill -f "unison.*$SOURCE_DRIVE" 2>/dev/null || true
        sleep 1

        echo -e "${YELLOW}Syncing... This may take several minutes for large drives.${NC}"
        echo ""
        "$INSTALL_DIR/sync_unison.sh"
        echo ""
        echo -e "${GREEN}✓ Initial sync complete!${NC}"
    else
        echo "Skipped initial sync. Run manually when ready:"
        echo "  ~/Library/icloud_backup/sync_unison.sh"
    fi

    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Installation Complete! 🎉${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "Your bidirectional sync system is now running:"
    echo "  • Real-time sync when files change in either location"
    echo "  • Periodic sync every 30 minutes as fallback"
    echo "  • Uses Unison for intelligent bidirectional sync"
    echo "  • Supports renames and deletions"
    echo ""
    echo "Locations:"
    echo "  • External drive: $SOURCE_DRIVE"
    echo "  • iCloud: $BACKUP_FOLDER"
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
else
    # Manual-only mode
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Installation Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Auto-sync was skipped.${NC}"
    echo "Scripts have been installed for manual use only."
    echo ""
    echo "Locations:"
    echo "  • External drive: $SOURCE_DRIVE"
    echo "  • iCloud: $BACKUP_FOLDER"
    echo ""

    # Ask about initial sync in manual mode too
    echo ""
    MANUAL_SYNC_OPTIONS=("Yes, run a sync now" "No, I'll sync manually later")
    MANUAL_SYNC_CHOICE=$(menu "Would you like to run an initial sync?" "${MANUAL_SYNC_OPTIONS[@]}")

    echo ""

    if [ $MANUAL_SYNC_CHOICE -eq 0 ]; then
        echo -e "${BLUE}Running sync...${NC}"
        echo ""

        # Clean up any stale Unison lock files
        echo "Cleaning up any stale Unison lock files..."
        rm -f ~/.unison/lk* 2>/dev/null || true

        # Kill any existing Unison processes
        pkill -f "unison.*$SOURCE_DRIVE" 2>/dev/null || true
        sleep 1

        echo -e "${YELLOW}Syncing... This may take several minutes for large drives.${NC}"
        echo ""
        "$INSTALL_DIR/sync_unison.sh"
        echo ""
        echo -e "${GREEN}✓ Sync complete!${NC}"
    fi

    echo ""
    echo "Useful commands:"
    echo "  • Manual sync: cloudsyncbridge sync"
    echo "  • View logs: cloudsyncbridge logs"
    echo ""
    echo "To enable auto-sync later:"
    echo "  1. Grant Full Disk Access to Terminal.app in System Settings"
    echo "  2. Run: cloudsyncbridge install"
    echo ""
    echo -e "${GREEN}Happy syncing! 🚀${NC}"
    echo ""
fi
