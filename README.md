# CloudSyncBridge

**Bidirectional iCloud Sync for External Drives & Folders**

CloudSyncBridge automatically keeps multiple folders and external drives perfectly in sync with iCloud Drive, similar to how macOS syncs Desktop and Documents folders. Built on Unison for intelligent bidirectional synchronization with support for multiple syncs.

## Features

- **Multiple sync support** - Sync multiple folders/drives to iCloud simultaneously
- **Bidirectional sync** - Changes sync both ways: source ↔ iCloud
- **Deletion sync control** - Choose whether deletions sync between locations or keep files safe
- **Real-time monitoring** - Files sync within seconds when they change
- **Rename support** - Properly handles file and folder renames (not treated as deletions)
- **Conflict resolution** - Newer file automatically wins in conflicts
- **Interactive exclusions** - Visual multi-select menu to choose folders and file patterns to exclude
- **Folder browser** - Navigate your filesystem with arrow keys to select folders
- **Live progress tracking** - See real-time sync progress with file count, speed, and ETA
- **Fallback periodic sync** - Runs every 30 minutes to catch any missed changes
- **Automatic startup** - Runs automatically when your Mac starts
- **Automatic upgrades** - Scripts update automatically when you upgrade via npm
- **Easy management** - Interactive CLI for all operations (add, remove, enable, disable syncs)

## Installation

### NPM Installation (Recommended)

Install CloudSyncBridge globally via npm:

```bash
npm install -g cloudsyncbridge
```

Then run the interactive installer:

```bash
cloudsyncbridge install
```

The installer will:
- Check for prerequisites (Homebrew)
- Install Unison and fswatch automatically
- Guide you through selecting folders to sync
- Let you configure exclusions interactively
- Set up automatic background sync
- Optionally run an initial sync

## Available Commands

All commands support both direct (with arguments) and interactive modes:

### Core Commands

- **`cloudsyncbridge install`** - Interactive installation wizard
- **`cloudsyncbridge uninstall`** - Remove CloudSyncBridge from your system
- **`cloudsyncbridge add`** - Add a new folder to sync to iCloud (interactive)
- **`cloudsyncbridge remove [id]`** - Remove a sync configuration (interactive if no ID)
- **`cloudsyncbridge list`** - List all configured syncs
- **`cloudsyncbridge edit [id]`** - Edit sync settings like deletion sync (interactive if no ID)
- **`cloudsyncbridge status`** - Check sync status and view running agents

### Sync Management

- **`cloudsyncbridge sync`** - Interactive menu to select which sync to run
- **`cloudsyncbridge sync all`** - Sync all enabled folders
- **`cloudsyncbridge sync <id>`** - Sync a specific folder by ID
- **`cloudsyncbridge enable [id]`** - Enable a sync (interactive if no ID)
- **`cloudsyncbridge disable [id]`** - Disable a sync (interactive if no ID)

### Monitoring

- **`cloudsyncbridge logs [id]`** - View sync logs (all or specific)
- **`cloudsyncbridge help`** - Show help message
- **`cloudsyncbridge version`** - Show version information

## Quick Start Example

```bash
# Install
npm install -g cloudsyncbridge
cloudsyncbridge install

# Add another folder to sync
cloudsyncbridge add

# List all syncs
cloudsyncbridge list

# Run manual sync (interactive menu)
cloudsyncbridge sync

# View logs
cloudsyncbridge logs

# Toggle deletion sync for a sync
cloudsyncbridge edit

# Disable a sync temporarily
cloudsyncbridge disable

# Remove a sync
cloudsyncbridge remove
```

## What Gets Synced

Each sync configuration includes:
- **Source:** Your chosen folder or external drive
- **Destination:** `~/Library/Mobile Documents/com~apple~CloudDocs/YourBackupFolder`
- **Direction:** Bidirectional (changes in either location sync to the other)

### Multi-Sync Support

You can configure multiple syncs, each with its own:
- Source folder/drive
- iCloud destination folder
- Exclusion rules
- Deletion sync preference
- Enable/disable state

### Deletion Sync Control

When creating or editing a sync, you can choose how deletions are handled:

**Sync deletions (default):**
- Delete a file in source → deletes in iCloud
- Delete a file in iCloud → deletes in source
- Best for: True mirroring, keeping both locations identical

**Don't sync deletions (safer):**
- Deletions only affect the location where you delete
- Files remain in the other location even if deleted elsewhere
- Best for: Extra safety, preventing accidental data loss
- Note: Can lead to duplicates if you delete and recreate files

You can toggle this setting anytime using:
```bash
cloudsyncbridge edit
```

## Exclusion Configuration

During setup (install or add), you'll interactively configure exclusions:

### 1. Top-Level Folder Exclusions
Visual multi-select menu with pre-selected recommended exclusions:
- `.DocumentRevisions-V100`, `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems` (recommended)
- Any other top-level folders you want to skip
- Use Space to toggle, ↑/↓ to navigate, Enter to confirm

### 2. Subfolder Exclusions
Comma-separated relative paths:
- Example: `Projects/node_modules, Documents/.git, Music/cache`
- Great for excluding nested folders without excluding their parent

### 3. File Pattern Exclusions
Default patterns (optional):
- `*.env` - Environment variables/secrets
- `.DS_Store`, `._*` - macOS metadata files

Custom patterns:
- `*.log`, `*.tmp`, `node_modules`, `.git`, etc.

## Interactive Features

### Folder Browser
Navigate your filesystem with arrow keys:
- `↑/↓` - Move selection
- `→` - Expand folder
- `←` - Collapse folder
- `Enter` - Select folder
- Folders already being synced show a ⚡ indicator

### Live Sync Progress
During sync, see real-time updates:
```
[1/100 - 1%] Syncing: Projects
  ✓ Complete | Speed: 2.3 files/s | ETA: 42s

[2/100 - 2%] Syncing: Documents
  ✓ Complete | Speed: 2.5 files/s | ETA: 39s
```

## Usage

The sync runs automatically in the background. No manual intervention needed!

### Automatic Sync

Two background agents run automatically:
- **File watcher** - Detects changes in real-time
- **Periodic sync** - Runs every 30 minutes as a fallback

### Manual Sync

Trigger a manual sync anytime:
```bash
cloudsyncbridge sync
```

Or sync a specific folder:
```bash
cloudsyncbridge sync my-folder
```

### Managing Syncs

**View all syncs:**
```bash
cloudsyncbridge list
```

**Add a new sync:**
```bash
cloudsyncbridge add
```

**Temporarily disable a sync:**
```bash
cloudsyncbridge disable
```

**Re-enable a sync:**
```bash
cloudsyncbridge enable
# Optionally run sync immediately after enabling
```

**Remove a sync:**
```bash
cloudsyncbridge remove
# Files remain safe in both locations
```

## How It Works

1. **Multi-sync manager** (`sync_manager.sh`) manages all configured syncs
2. **File watcher agent** monitors all enabled sync sources for changes
3. **Periodic agent** runs all enabled syncs every 30 minutes
4. **Unison** provides intelligent bidirectional sync with rename detection
5. **Real-time progress** shows file-by-file sync status with statistics
6. Changes sync to both locations, then iCloud uploads to Apple's cloud

### Why Unison?

- **Better than rsync** for bidirectional sync
- **Rename detection** - Knows when you rename vs delete+create
- **Conflict resolution** - Automatically handles conflicts (newer wins)
- **State tracking** - Maintains archives to understand what changed
- **Battle-tested** - Used for decades in production environments

## Configuration Files

All syncs are stored as individual configuration files:

**Sync configurations:**
- Location: `~/Library/icloud_backup/syncs/`
- Format: `sync-id.conf`
- Each contains: source path, destination, exclusions, enabled state

**Global configuration:**
- Location: `~/Library/icloud_backup/global.conf`
- Contains: global exclude patterns, iCloud Drive path

**Logs:**
- Location: `~/Library/Logs/icloud_backup/`
- Format: `sync-id.log` for each sync, `system.log` for global events

## Requirements

- macOS
- iCloud Drive enabled
- Homebrew (installed automatically if needed)
- Sufficient iCloud storage space
- Full Disk Access granted to Terminal.app

## Troubleshooting

### Sync not running?
```bash
# Check agent status
cloudsyncbridge status

# Check logs
cloudsyncbridge logs

# Manually trigger sync
cloudsyncbridge sync
```

### Files not syncing?
- Wait 10-15 seconds after making a change
- Check if folder is enabled: `cloudsyncbridge list`
- Run manual sync: `cloudsyncbridge sync`
- Check logs: `cloudsyncbridge logs`

### Permission errors?
- Grant Full Disk Access to Terminal.app
- System Settings → Privacy & Security → Full Disk Access
- Add Terminal.app and enable the checkbox

### "Archives are locked" error?
```bash
# Stop all sync processes
pkill -f unison

# Remove lock files
rm -f ~/.unison/lk*

# Restart sync
cloudsyncbridge sync
```

### Out of iCloud storage?
- Check usage: System Settings → Apple ID → iCloud
- Disable syncs: `cloudsyncbridge disable`
- Add more exclusions to existing syncs
- Upgrade iCloud storage plan

### Initial sync taking long?
- Large folders can take 10-30+ minutes on first sync
- Monitor progress: `cloudsyncbridge logs`
- Syncs run sequentially for multiple folders
- Subsequent syncs are much faster (only changed files)

### iCloud taking long to upload to Apple's servers?
This is separate from our sync - we sync to the local iCloud Drive folder, then macOS uploads to Apple's servers.

**Speed up iCloud upload:**
```bash
# Restart iCloud daemon
killall bird

# Check iCloud status
brctl log --wait --shorten

# Keep Mac awake and plugged in for faster uploads
```

## Advanced

### Customize exclusions
Edit the config file for a specific sync:
```bash
# Find your sync ID
cloudsyncbridge list

# Edit config
nano ~/Library/icloud_backup/syncs/your-sync-id.conf

# Restart agents for changes to take effect
launchctl unload ~/Library/LaunchAgents/com.icloudbackup.sync.*.plist
launchctl load ~/Library/LaunchAgents/com.icloudbackup.sync.*.plist
```

### Clear Unison archives (forces full rescan)
```bash
rm -rf ~/.unison/ar*
```

### View background agent logs
```bash
# File watcher
tail -f ~/Library/Logs/icloud_backup/watch.log

# Periodic sync
tail -f ~/Library/Logs/icloud_backup/periodic.log
```

## File Locations

- **Scripts:** `~/Library/icloud_backup/`
- **Sync configs:** `~/Library/icloud_backup/syncs/*.conf`
- **Global config:** `~/Library/icloud_backup/global.conf`
- **Logs:** `~/Library/Logs/icloud_backup/`
- **LaunchAgents:** `~/Library/LaunchAgents/com.icloudbackup.sync.*.plist`
- **Unison archives:** `~/.unison/`
- **iCloud folders:** `~/Library/Mobile Documents/com~apple~CloudDocs/`

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Built with [Unison](https://www.cis.upenn.edu/~bcpierce/unison/) file synchronizer
- Uses [fswatch](https://github.com/emcrisostomo/fswatch) for real-time file monitoring
