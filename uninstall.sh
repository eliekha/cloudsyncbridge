#!/bin/bash

# Uninstallation script for CloudSyncBridge

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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
echo -e "${YELLOW}CloudSyncBridge - Uninstallation${NC}"
echo ""

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

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Check if CloudSyncBridge is installed
if [ ! -d "$HOME/Library/icloud_backup" ] && \
   [ ! -f "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist" ] && \
   [ ! -f "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist" ]; then
    echo -e "${YELLOW}CloudSyncBridge doesn't appear to be installed.${NC}"
    echo ""
    echo "Nothing to uninstall."
    echo ""
    exit 0
fi

# Ask for confirmation before proceeding
echo -e "${YELLOW}Are you sure you want to uninstall CloudSyncBridge?${NC}"
echo ""
echo "This will:"
echo "  • Stop all automatic sync services"
echo "  • Remove CloudSyncBridge agents"
echo "  • Optionally remove scripts and configuration"
echo ""
echo -e "${GREEN}Your synced files will NOT be deleted.${NC}"
echo ""

CONFIRM_OPTIONS=("Yes, proceed with uninstall" "No, cancel")
CONFIRM_CHOICE=$(menu "Continue?" "${CONFIRM_OPTIONS[@]}")

echo ""

if [ $CONFIRM_CHOICE -eq 1 ]; then
    echo "Uninstall cancelled."
    echo ""
    exit 0
fi

# Step 1: Stop sync services
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Step 1: Stop Automatic Sync${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

AGENTS_FOUND=false

# Unload and remove Unison watch agent
if [ -f "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist" ]; then
    AGENTS_FOUND=true
    echo "Stopping real-time watcher..."
    launchctl unload "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist" 2>/dev/null || true
    rm "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist"
    echo -e "${GREEN}✓${NC} Removed real-time watcher"
fi

# Unload and remove Unison periodic agent
if [ -f "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist" ]; then
    AGENTS_FOUND=true
    echo "Stopping periodic sync..."
    launchctl unload "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist" 2>/dev/null || true
    rm "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist"
    echo -e "${GREEN}✓${NC} Removed periodic sync"
fi

# Clean up old rsync-based agents if they exist
for agent in com.icloudbackup.watch com.icloudbackup.watch.reverse com.icloudbackup.periodic; do
    if [ -f "$LAUNCH_AGENTS_DIR/${agent}.plist" ]; then
        AGENTS_FOUND=true
        echo "Removing old agent: ${agent}"
        launchctl unload "$LAUNCH_AGENTS_DIR/${agent}.plist" 2>/dev/null || true
        rm "$LAUNCH_AGENTS_DIR/${agent}.plist"
        echo -e "${GREEN}✓${NC} Removed ${agent}"
    fi
done

if [ "$AGENTS_FOUND" = true ]; then
    echo ""
    echo -e "${GREEN}✓ All sync agents stopped and removed${NC}"
else
    echo "No sync agents found (already removed or not configured)"
fi

# Stop any running Unison processes
echo ""
echo "Stopping any running sync processes..."
pkill -f "unison" 2>/dev/null && echo -e "${GREEN}✓${NC} Stopped running sync processes" || echo "No sync processes running"

# Clean up lock files
rm -f ~/.unison/lk* 2>/dev/null && echo -e "${GREEN}✓${NC} Cleaned up lock files" || true

echo ""
echo -e "${GREEN}✓ Automatic sync has been stopped${NC}"
echo ""

# Step 2: Remove files
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Step 2: Remove Files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The following files and folders can be removed:"
echo ""
echo "  • Scripts & config: ~/Library/icloud_backup/"
echo "  • Logs: ~/Library/Logs/icloud_backup/"
echo "  • Unison archives: ~/.unison/"
echo ""
echo -e "${GREEN}Note: Your synced files will NOT be deleted.${NC}"
echo "They remain in both locations (external drive and iCloud)."
echo ""

CLEANUP_OPTIONS=("Yes, remove all CloudSyncBridge files" "No, keep the files for now")
CLEANUP_CHOICE=$(menu "Remove scripts and data?" "${CLEANUP_OPTIONS[@]}")

echo ""

if [ $CLEANUP_CHOICE -eq 0 ]; then
    echo "Removing CloudSyncBridge files..."
    echo ""

    # Remove scripts
    if [ -d "$HOME/Library/icloud_backup" ]; then
        rm -rf "$HOME/Library/icloud_backup"
        echo -e "${GREEN}✓${NC} Removed scripts and configuration"
    fi

    # Remove logs
    if [ -d "$HOME/Library/Logs/icloud_backup" ]; then
        rm -rf "$HOME/Library/Logs/icloud_backup"
        echo -e "${GREEN}✓${NC} Removed logs"
    fi

    # Ask about Unison archives
    if [ -d "$HOME/.unison" ]; then
        echo ""
        echo -e "${YELLOW}About Unison archives:${NC}"
        echo "Unison keeps archive files that track sync state."
        echo -e "${RED}Warning: If you use Unison for other syncs, this will affect them too.${NC}"
        echo ""

        UNISON_OPTIONS=("Yes, remove Unison archives" "No, keep Unison archives")
        UNISON_CHOICE=$(menu "Remove Unison archives?" "${UNISON_OPTIONS[@]}")

        echo ""

        if [ $UNISON_CHOICE -eq 0 ]; then
            rm -rf "$HOME/.unison"
            echo -e "${GREEN}✓${NC} Removed Unison archives"
        else
            echo "Kept Unison archives at ~/.unison/"
        fi
    fi

    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Uninstallation Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "CloudSyncBridge has been completely removed from your system."
else
    echo "Keeping CloudSyncBridge files."
    echo ""
    echo "Files that remain:"
    echo "  • Scripts: ~/Library/icloud_backup/"
    echo "  • Logs: ~/Library/Logs/icloud_backup/"
    echo "  • Unison archives: ~/.unison/"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Sync Services Stopped${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "Automatic sync has been stopped, but files remain for manual use."
    echo ""
    echo "To remove files later, run:"
    echo "  cloudsyncbridge uninstall"
fi

echo ""
echo -e "${BLUE}Your synced data is safe!${NC}"
echo "Files remain in both locations:"
echo "  • Your external drive"
echo "  • iCloud Drive"
echo ""
echo "To reinstall later, run:"
echo "  cloudsyncbridge install"
echo ""
