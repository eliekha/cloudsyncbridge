# CloudBridge

**Bidirectional iCloud Sync for External Drives**

CloudBridge automatically keeps your external drive and iCloud Drive perfectly in sync, similar to how macOS syncs Desktop and Documents folders. Built on Unison for intelligent bidirectional synchronization.

## Features

- **Bidirectional sync** - Changes sync both ways: external drive ↔ iCloud
- **Real-time monitoring** - Files sync within seconds when they change
- **Rename support** - Properly handles file and folder renames (not treated as deletions)
- **Conflict resolution** - Newer file automatically wins in conflicts
- **Configurable exclusions** - Interactively choose which folders and files to exclude
- **Fallback periodic sync** - Runs every 30 minutes to catch any missed changes
- **Automatic startup** - Runs automatically when your Mac starts and the drive is connected
- **Easy installation** - Interactive installer with arrow key navigation

## Installation

### Option 1: NPM (Recommended)

Install CloudBridge globally via npm:

```bash
npm install -g cloudbridge
```

Then run the installer:

```bash
cloudbridge install
```

Available commands:
- `cloudbridge install` - Interactive installation wizard
- `cloudbridge uninstall` - Remove CloudBridge
- `cloudbridge status` - Check sync status
- `cloudbridge sync` - Manually trigger sync
- `cloudbridge logs` - View sync logs
- `cloudbridge help` - Show help

### Option 2: Manual Installation

### Prerequisites

1. **Grant Full Disk Access to Terminal:**
   - Open **System Settings** > **Privacy & Security** > **Full Disk Access**
   - Click the lock icon and enter your password
   - Click the **+** button
   - Navigate to **Applications** folder
   - Select **Terminal.app** (or your terminal app like iTerm)
   - Click **Open**
   - Make sure the checkbox next to **Terminal** is enabled

   > **Note:** The installer will help you with this step automatically.

2. **Install Homebrew** (if not already installed):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

### Installation Steps

1. Clone or download this repository to your external drive

2. Open Terminal and navigate to the folder:
   ```bash
   cd "/Volumes/YourDriveName/path/to/cloudbridge"
   ```

3. Run the installation script:
   ```bash
   ./install.sh
   ```

4. Follow the interactive prompts:
   - Use ↑/↓ arrow keys to select your external drive from the list
   - Choose a backup folder name in iCloud
   - Select which top-level folders to exclude (use Space to toggle, Enter when done)
   - Optionally add specific subfolder paths to exclude (comma-separated)
   - Choose file patterns to exclude (*.env, .DS_Store, etc.)
   - Review and confirm settings

5. The installer will:
   - Install Unison and fswatch (via Homebrew)
   - Generate your configuration file
   - Set up automatic background sync agents
   - Perform an initial sync

## What Gets Synced

- **Location 1:** Your external drive (path specified during installation)
- **Location 2:** `~/Library/Mobile Documents/com~apple~CloudDocs/YourBackupFolder`
- **Sync direction:** Bidirectional (changes in either location sync to the other)

### Exclusions

During installation, you can interactively choose which folders and files to exclude from sync.

**Top-level folder exclusions** (interactive checkbox selection):
- `.DocumentRevisions-V100`, `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems` - macOS system folders (recommended)
- Any other top-level folders you want to skip

**Subfolder exclusions** (comma-separated paths):
- Specify relative paths like `Projects/node_modules`, `Documents/.git`, `Music/cache`
- Great for excluding nested folders without excluding their parent

**File pattern exclusions** (optional):
- `*.env` - Environment variables/secrets
- `.DS_Store`, `._*` - macOS system files
- Custom patterns like `*.log`, `*.tmp`, `node_modules`, `.git`, etc.

## Usage

The sync runs automatically in the background. No manual intervention needed!

### Manual Commands

**View sync logs:**
```bash
tail -f ~/Library/Logs/icloud_backup/sync.log
```

**Run manual sync:**
```bash
~/Library/icloud_backup/sync_unison.sh
```

**Check if agents are running:**
```bash
launchctl list | grep icloudbackup
```

You should see:
- `com.icloudbackup.unison.watch` - Real-time file watcher
- `com.icloudbackup.unison.periodic` - Periodic backup (every 30 min)

### Testing the Sync

**Test forward sync (external drive → iCloud):**
```bash
touch "/Volumes/YourDrive/test_forward.txt"
# Wait ~5-10 seconds, then check iCloud folder
```

**Test reverse sync (iCloud → external drive):**
```bash
touch ~/Library/Mobile\ Documents/com~apple~CloudDocs/YourBackupFolder/test_reverse.txt
# Wait ~5-10 seconds, then check external drive
```

**Test rename (works in both directions):**
```bash
# Create and rename a folder in iCloud
mkdir ~/Library/Mobile\ Documents/com~apple~CloudDocs/YourBackupFolder/test_folder
sleep 10
mv ~/Library/Mobile\ Documents/com~apple~CloudDocs/YourBackupFolder/test_folder \
   ~/Library/Mobile\ Documents/com~apple~CloudDocs/YourBackupFolder/renamed_folder
# Wait ~10 seconds - it will be properly renamed on external drive too!
```

## Customization

Edit `~/Library/icloud_backup/config.sh` to customize:
- Excluded folders
- Excluded file patterns
- Backup destination name

After making changes, restart the agents:
```bash
launchctl unload ~/Library/LaunchAgents/com.icloudbackup.unison.watch.plist
launchctl unload ~/Library/LaunchAgents/com.icloudbackup.unison.periodic.plist
launchctl load ~/Library/LaunchAgents/com.icloudbackup.unison.watch.plist
launchctl load ~/Library/LaunchAgents/com.icloudbackup.unison.periodic.plist
```

## Uninstallation

To stop automatic syncs:
```bash
./uninstall.sh
```

Or manually:
```bash
launchctl unload ~/Library/LaunchAgents/com.icloudbackup.unison.watch.plist
launchctl unload ~/Library/LaunchAgents/com.icloudbackup.unison.periodic.plist
rm ~/Library/LaunchAgents/com.icloudbackup.unison.*.plist
```

This removes the background agents but keeps your synced files in both locations.

To completely remove everything:
```bash
rm -rf ~/Library/icloud_backup/
rm -rf ~/Library/Logs/icloud_backup/
rm -rf ~/.unison/
```

To delete synced files (WARNING - permanent deletion):
```bash
rm -rf ~/Library/Mobile\ Documents/com~apple~CloudDocs/YourBackupFolder
```

## How It Works

1. **Unified file watcher** (`watch_unison.sh`) uses `fswatch` to monitor BOTH locations for changes
2. **Sync script** (`sync_unison.sh`) uses Unison for intelligent bidirectional sync
3. **Unison** maintains archive files to track state and detect renames/moves
4. **launchd agents** run the watcher and periodic sync in the background
5. Changes sync to both locations, then iCloud syncs to Apple's cloud

### Why Unison?

- **Better than rsync** for bidirectional sync
- **Rename detection** - Knows when you rename vs delete+create
- **Conflict resolution** - Automatically handles conflicts (newer wins)
- **State tracking** - Maintains archives to understand what changed
- **Battle-tested** - Used for decades in production environments

## Requirements

- macOS
- iCloud Drive enabled
- Homebrew (for installing Unison and fswatch)
- Sufficient iCloud storage space
- Full Disk Access granted to Terminal.app

## Troubleshooting

**Sync not running?**
- Check if drive is mounted: `ls "/Volumes/YourDrive"`
- Check agent status: `launchctl list | grep icloudbackup`
- Check logs: `tail -f ~/Library/Logs/icloud_backup/sync.log`

**Files not syncing?**
- Wait 10-15 seconds after making a change
- Check if Unison is running: `ps aux | grep unison`
- Manually trigger sync: `~/Library/icloud_backup/sync_unison.sh`

**Out of iCloud storage?**
- Check usage in System Settings > Apple ID > iCloud
- Upgrade storage plan or exclude more folders in `config.sh`

**Permission errors?**
- Grant Full Disk Access to Terminal.app (see Prerequisites)
- Check logs for "Operation not permitted" errors

**"Archives are locked" error?**
- Stop all sync processes: `pkill -f unison`
- Remove lock files: `rm -f ~/.unison/lk*`
- Restart sync: `~/Library/icloud_backup/sync_unison.sh`

**Initial sync taking too long?**
- Large drives can take 10-30+ minutes on first sync
- Check progress: `ps aux | grep unison` (high CPU = actively syncing)
- View what's syncing: `tail -f ~/Library/Logs/icloud_backup/sync.log`

**Conflicts?**
- Unison automatically chooses the newer file
- Check logs for "conflict" messages
- Manually resolve by keeping the version you want

**Initial sync taking long?**
- First sync scans all files and can take 30+ minutes for large drives
- Subsequent syncs are much faster (only changed files)
- Monitor progress: `tail -f ~/Library/Logs/icloud_backup/sync.log`

## Advanced

**View Unison archives:**
```bash
ls ~/.unison/
```

**Clear archives (forces full resync):**
```bash
rm -rf ~/.unison/ar*
```

**Customize Unison options:**
Edit `~/Library/icloud_backup/sync_unison.sh` and modify the Unison command parameters.

**Sync multiple drives:**
Run the installer separately for each drive. Each will get its own configuration and backup folder.

## File Locations

- **Scripts:** `~/Library/icloud_backup/`
- **Configuration:** `~/Library/icloud_backup/config.sh` (generated during installation)
- **Configuration template:** `config.sh.example` (in repository)
- **Logs:** `~/Library/Logs/icloud_backup/sync.log`
- **LaunchAgents:** `~/Library/LaunchAgents/com.icloudbackup.unison.*.plist`
- **Unison archives:** `~/.unison/`
- **iCloud backup folder:** `~/Library/Mobile Documents/com~apple~CloudDocs/YourBackupFolder`

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Built with [Unison](https://www.cis.upenn.edu/~bcpierce/unison/) file synchronizer
- Uses [fswatch](https://github.com/emcrisostomo/fswatch) for real-time file monitoring
