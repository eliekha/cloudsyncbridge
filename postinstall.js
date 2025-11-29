#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Only show for global installs, not when used as a dependency
if (process.env.npm_config_global === 'true') {
  const GREEN = '\x1b[0;32m';
  const BLUE = '\x1b[0;34m';
  const YELLOW = '\x1b[1;33m';
  const NC = '\x1b[0m';

  // Check if CloudSyncBridge is already installed (upgrade scenario)
  const homeDir = process.env.HOME;
  const syncManager = `${homeDir}/Library/icloud_backup/sync_manager.sh`;
  const isUpgrade = fs.existsSync(syncManager);

  if (isUpgrade) {
    // This is an upgrade - update scripts and restart agents
    try {
      process.stdout.write(`\n${YELLOW}Detected CloudSyncBridge upgrade...${NC}\n`);
      process.stdout.write(`${BLUE}Updating scripts...${NC}\n`);

      // Copy updated scripts to install directory
      const scriptsDir = path.join(__dirname, 'scripts');
      const installDir = `${homeDir}/Library/icloud_backup`;

      // Copy all shell scripts to install directory
      const scriptsToUpdate = [
        'sync_manager.sh',
        'file_watcher.sh',
        'folder_browser.sh',
        'add_sync.sh',
        'manage_syncs.sh',
        'remove_sync.sh',
        'enable_sync.sh',
        'disable_sync.sh',
        'edit_sync.sh',
        'optimize_storage.sh',
        'sync_interactive.sh',
        'setup_agents.sh',
        'menu_functions.sh'
      ];

      for (const script of scriptsToUpdate) {
        const source = path.join(scriptsDir, script);
        const dest = path.join(installDir, script);
        if (fs.existsSync(source)) {
          fs.copyFileSync(source, dest);
          fs.chmodSync(dest, 0o755);
        }
      }

      process.stdout.write(`${GREEN}✓ Scripts updated${NC}\n`);
      process.stdout.write(`${BLUE}Restarting sync agents to load new code...${NC}\n`);

      execSync('launchctl unload ~/Library/LaunchAgents/com.icloudbackup.sync.*.plist 2>/dev/null || true', { stdio: 'ignore' });
      execSync('sleep 1', { stdio: 'ignore' });
      execSync('launchctl load ~/Library/LaunchAgents/com.icloudbackup.sync.*.plist 2>/dev/null || true', { stdio: 'ignore' });

      process.stdout.write(`${GREEN}✓ Agents restarted successfully${NC}\n\n`);
    } catch (err) {
      process.stdout.write(`${YELLOW}⚠ Could not update scripts/agents automatically. Run: cloudsyncbridge install${NC}\n\n`);
    }
  }

  // Write directly to process.stdout to ensure it's visible
  process.stdout.write(`
${GREEN}╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  CloudSyncBridge installed successfully! 🎉                ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝${NC}

${BLUE}Next steps:${NC}

${YELLOW}1.${NC} Run the interactive installer:
   ${GREEN}cloudsyncbridge install${NC}

${YELLOW}2.${NC} The installer will help you:
   • Select your external drive
   • Choose which folders to exclude
   • Set up automatic bidirectional sync

${BLUE}Need help?${NC}
   ${GREEN}cloudsyncbridge help${NC}

${BLUE}Documentation:${NC}
   https://github.com/eliekha/cloudsyncbridge#readme

`);
}
