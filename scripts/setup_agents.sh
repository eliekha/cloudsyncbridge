#!/bin/bash
# Set up launchd agents for CloudSyncBridge multi-sync

# Directories
readonly INSTALL_DIR="$HOME/Library/icloud_backup"
readonly LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Color codes (only set if not already defined)
if [ -z "$GREEN" ]; then
    readonly GREEN='\033[0;32m'
    readonly BLUE='\033[0;34m'
    readonly YELLOW='\033[1;33m'
    readonly RED='\033[0;31m'
    readonly NC='\033[0m'
fi

# Ensure directories exist
mkdir -p "$LAUNCH_AGENTS_DIR"

echo -e "${BLUE}Setting up automatic sync agents...${NC}"

# Check for fswatch
if ! command -v fswatch &> /dev/null; then
    echo -e "${YELLOW}fswatch not found. Installing via Homebrew...${NC}"

    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Error: Homebrew is not installed.${NC}"
        echo "Please install Homebrew from https://brew.sh"
        echo "Or install fswatch manually: brew install fswatch"
        echo ""
        echo "Continuing without file watcher (will use periodic sync only)..."
        SKIP_WATCHER=true
    else
        brew install fswatch
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ fswatch installed${NC}"
        else
            echo -e "${YELLOW}Warning: Could not install fswatch. File watching will be disabled.${NC}"
            SKIP_WATCHER=true
        fi
    fi
else
    echo -e "${GREEN}✓ fswatch is available${NC}"
fi

# Unload old agents if they exist
echo "Stopping existing agents..."
for agent in com.icloudbackup.unison.watch com.icloudbackup.unison.periodic com.icloudbackup.sync.periodic com.icloudbackup.sync.watch; do
    if [ -f "$LAUNCH_AGENTS_DIR/${agent}.plist" ]; then
        launchctl unload "$LAUNCH_AGENTS_DIR/${agent}.plist" 2>/dev/null || true
        launchctl remove "${agent}" 2>/dev/null || true
    fi
done

# Create new multi-sync periodic agent
cat > "$LAUNCH_AGENTS_DIR/com.icloudbackup.sync.periodic.plist" << 'PERIODICPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.icloudbackup.sync.periodic</string>
    <key>ProgramArguments</key>
    <array>
        <string>INSTALL_DIR_PLACEHOLDER/sync_manager.sh</string>
        <string>all</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>StandardOutPath</key>
    <string>/tmp/icloudbackup.sync.periodic.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/icloudbackup.sync.periodic.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
PERIODICPLIST

# Replace placeholder with actual install directory
sed -i '' "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$LAUNCH_AGENTS_DIR/com.icloudbackup.sync.periodic.plist"

echo -e "${GREEN}✓${NC} Created periodic sync agent (runs every 30 minutes)"

# Create file watcher agent (if fswatch is available)
if [ "${SKIP_WATCHER:-false}" != "true" ]; then
    cat > "$LAUNCH_AGENTS_DIR/com.icloudbackup.sync.watch.plist" << 'WATCHPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.icloudbackup.sync.watch</string>
    <key>ProgramArguments</key>
    <array>
        <string>INSTALL_DIR_PLACEHOLDER/file_watcher.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/icloudbackup.sync.watch.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/icloudbackup.sync.watch.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
WATCHPLIST

    # Replace placeholder
    sed -i '' "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$LAUNCH_AGENTS_DIR/com.icloudbackup.sync.watch.plist"

    echo -e "${GREEN}✓${NC} Created file watcher agent (real-time sync)"
fi

# Clean up before starting agents
echo ""
echo "Preparing to start agents..."

# Clean Unison locks
rm -f ~/.unison/lk* 2>/dev/null || true

# Kill any existing Unison processes
pkill -f "unison" 2>/dev/null || true
sleep 1

# Load the new agents
echo "Starting agents..."
launchctl load "$LAUNCH_AGENTS_DIR/com.icloudbackup.sync.periodic.plist" 2>/dev/null || true
launchctl start com.icloudbackup.sync.periodic 2>/dev/null || true

if [ "${SKIP_WATCHER:-false}" != "true" ]; then
    launchctl load "$LAUNCH_AGENTS_DIR/com.icloudbackup.sync.watch.plist" 2>/dev/null || true
    launchctl start com.icloudbackup.sync.watch 2>/dev/null || true
fi

echo -e "${GREEN}✓${NC} Started sync agents"
echo ""
echo -e "${BLUE}Automatic sync is now enabled!${NC}"

if [ "${SKIP_WATCHER:-false}" != "true" ]; then
    echo "• Real-time sync: Local changes push to iCloud immediately"
fi
echo "• Periodic sync: iCloud changes pull to local every 60 seconds"
echo ""
echo "To trigger a manual sync now: ${GREEN}cloudsyncbridge sync${NC}"
