#!/bin/bash

# Uninstallation script for iCloud Bidirectional Sync System (Unison)

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cat << "EOF"
   _____ _                 _  _____                  ____       _     _
  / ____| |               | |/ ____|                |  _ \     (_)   | |
 | |    | | ___  _   _  __| | (___  _   _ _ __   ___| |_) |_ __ _  __| | __ _  ___
 | |    | |/ _ \| | | |/ _` |\___ \| | | | '_ \ / __|  _ <| '__| |/ _` |/ _` |/ _ \
 | |____| | (_) | |_| | (_| |____) | |_| | | | | (__| |_) | |  | | (_| | (_| |  __/
  \_____|_|\___/ \__,_|\__,_|_____/ \__, |_| |_|\___|____/|_|  |_|\__,_|\__, |\___|
                                     __/ |                               __/ |
                                    |___/                               |___/
EOF
echo ""
echo -e "${YELLOW}CloudSyncBridge - Uninstallation${NC}"
echo ""

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Unload and remove Unison watch agent
if [ -f "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist" ]; then
    echo "Stopping real-time watcher..."
    launchctl unload "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist" 2>/dev/null || true
    rm "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.watch.plist"
    echo -e "${GREEN}✓${NC} Removed real-time watcher"
else
    echo "Real-time watcher not found (already removed)"
fi

# Unload and remove Unison periodic agent
if [ -f "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist" ]; then
    echo "Stopping periodic sync..."
    launchctl unload "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist" 2>/dev/null || true
    rm "$LAUNCH_AGENTS_DIR/com.icloudbackup.unison.periodic.plist"
    echo -e "${GREEN}✓${NC} Removed periodic sync"
else
    echo "Periodic sync not found (already removed)"
fi

# Clean up old rsync-based agents if they exist
echo ""
echo "Checking for old rsync-based agents..."
for agent in com.icloudbackup.watch com.icloudbackup.watch.reverse com.icloudbackup.periodic; do
    if [ -f "$LAUNCH_AGENTS_DIR/${agent}.plist" ]; then
        echo "Removing old agent: ${agent}"
        launchctl unload "$LAUNCH_AGENTS_DIR/${agent}.plist" 2>/dev/null || true
        rm "$LAUNCH_AGENTS_DIR/${agent}.plist"
        echo -e "${GREEN}✓${NC} Removed ${agent}"
    fi
done

echo ""
echo -e "${GREEN}LaunchAgents removed successfully!${NC}"
echo ""

# Stop any running Unison processes
echo "Stopping any running sync processes..."
pkill -f "unison" 2>/dev/null && echo -e "${GREEN}✓${NC} Stopped running sync processes" || echo "No sync processes running"

# Clean up lock files
rm -f ~/.unison/lk* 2>/dev/null && echo -e "${GREEN}✓${NC} Cleaned up lock files" || true

echo ""
echo "The automatic sync has been stopped."
echo ""

# Ask if user wants to remove scripts and data
echo -e "${YELLOW}Do you want to remove the scripts and configuration files?${NC}"
echo "This will delete:"
echo "  • Scripts: ~/Library/icloud_backup/"
echo "  • Logs: ~/Library/Logs/icloud_backup/"
echo "  • Unison archives: ~/.unison/"
echo ""
echo "Note: Your synced files will NOT be deleted."
echo ""
read -p "Remove scripts and data? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
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

    # Remove Unison archives
    if [ -d "$HOME/.unison" ]; then
        echo ""
        echo -e "${YELLOW}Remove Unison archives?${NC}"
        echo "Warning: If you use Unison for other syncs, this will delete ALL Unison archives."
        read -p "Remove Unison archives? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.unison"
            echo -e "${GREEN}✓${NC} Removed Unison archives"
        else
            echo "Keeping Unison archives at ~/.unison/"
        fi
    fi

    echo ""
    echo -e "${GREEN}Complete cleanup finished!${NC}"
else
    echo "Keeping scripts and data files."
    echo ""
    echo "Files and directories that remain:"
    echo "  • Scripts: ~/Library/icloud_backup/"
    echo "  • Logs: ~/Library/Logs/icloud_backup/"
    echo "  • Unison archives: ~/.unison/"
    echo ""
    echo "To remove them later, run:"
    echo "  rm -rf ~/Library/icloud_backup/"
    echo "  rm -rf ~/Library/Logs/icloud_backup/"
    echo "  rm -rf ~/.unison/"
fi

echo ""
echo "Your synced files have NOT been deleted."
echo "They remain in both locations (external drive and iCloud)."
echo ""
