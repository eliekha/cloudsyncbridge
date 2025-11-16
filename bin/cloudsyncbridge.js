#!/usr/bin/env node

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const SCRIPTS_DIR = path.join(__dirname, '..', 'scripts');

function showBanner() {
  console.log(`
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
  `);
}

function isInstalled() {
  const homeDir = process.env.HOME;
  const syncManager = `${homeDir}/Library/icloud_backup/sync_manager.sh`;
  const syncsDir = `${homeDir}/Library/icloud_backup/syncs`;

  // Check for new multi-sync system
  if (fs.existsSync(syncManager) || fs.existsSync(syncsDir)) {
    return true;
  }

  // Fall back to legacy single-sync system
  const legacyConfig = `${homeDir}/Library/icloud_backup/config.sh`;
  return fs.existsSync(legacyConfig);
}

function showHelp() {
  showBanner();
  console.log('CloudSyncBridge - Bidirectional iCloud Sync for External Drives\n');

  if (!isInstalled()) {
    console.log('\x1b[1;33m⚠  CloudSyncBridge is not set up yet!\x1b[0m\n');
    console.log('\x1b[0;32mGet started:\x1b[0m');
    console.log('  cloudsyncbridge install    # Run the interactive installer\n');
  }

  console.log('Usage: cloudsyncbridge <command> [options]\n');
  console.log('Commands:');
  console.log('  install       - Install and configure CloudSyncBridge');
  console.log('  uninstall     - Remove CloudSyncBridge from your system');
  console.log('  add           - Add a new folder to sync to iCloud');
  console.log('  remove [id]   - Remove a sync configuration (interactive)');
  console.log('  list          - List all configured syncs');
  console.log('  enable [id]   - Enable a sync (interactive)');
  console.log('  disable [id]  - Disable a sync (interactive)');
  console.log('  status        - Check sync status and view running agents');
  console.log('  sync [id]     - Manually trigger sync (interactive)');
  console.log('  logs [id]     - View sync logs');
  console.log('  help          - Show this help message');
  console.log('  version       - Show version information');
  console.log('');
  console.log('Examples:');
  console.log('  cloudsyncbridge install        # Start interactive installation');
  console.log('  cloudsyncbridge add            # Add a new folder to sync');
  console.log('  cloudsyncbridge list           # List all configured syncs');
  console.log('  cloudsyncbridge sync           # Interactive sync menu');
  console.log('  cloudsyncbridge sync all       # Sync all enabled folders');
  console.log('  cloudsyncbridge sync my-sync   # Sync a specific folder by ID');
  console.log('  cloudsyncbridge enable         # Interactive enable menu');
  console.log('  cloudsyncbridge remove         # Interactive sync removal');
  console.log('');
}

function showVersion() {
  const packageJson = require('../package.json');
  console.log(`CloudSyncBridge v${packageJson.version}`);
}

function runScript(scriptName, args = []) {
  const scriptPath = path.join(SCRIPTS_DIR, scriptName);

  if (!fs.existsSync(scriptPath)) {
    console.error(`Error: Script not found: ${scriptPath}`);
    process.exit(1);
  }

  // Make script executable
  try {
    fs.chmodSync(scriptPath, '0755');
  } catch (err) {
    // Ignore chmod errors
  }

  // Run script interactively (inherit stdio)
  // Use bash -c to properly handle paths with spaces
  const escapedPath = scriptPath.replace(/'/g, "'\\''");
  const command = args.length > 0
    ? `'${escapedPath}' ${args.map(a => `'${a.replace(/'/g, "'\\''")}'`).join(' ')}`
    : `'${escapedPath}'`;

  const child = spawn('/bin/bash', ['-c', command], {
    stdio: 'inherit'
  });

  child.on('exit', (code) => {
    process.exit(code || 0);
  });

  child.on('error', (err) => {
    console.error(`Error running script: ${err.message}`);
    process.exit(1);
  });
}

function checkStatus() {
  showBanner();
  console.log('CloudSyncBridge Status\n');

  const homeDir = process.env.HOME;
  const syncManager = `${homeDir}/Library/icloud_backup/sync_manager.sh`;
  const syncsDir = `${homeDir}/Library/icloud_backup/syncs`;
  const legacyConfig = `${homeDir}/Library/icloud_backup/config.sh`;

  // Check if installed
  if (!isInstalled()) {
    console.log('❌ CloudSyncBridge is not installed');
    console.log('\nRun: cloudsyncbridge install');
    return;
  }

  console.log('✓ CloudSyncBridge is installed\n');

  // Detect system type
  const isMultiSync = fs.existsSync(syncManager) || fs.existsSync(syncsDir);

  if (isMultiSync) {
    // Show configured syncs count
    try {
      if (fs.existsSync(syncsDir)) {
        const configs = fs.readdirSync(syncsDir).filter(f => f.endsWith('.conf'));
        console.log(`Configured syncs: ${configs.length}`);
        console.log('(Use "cloudsyncbridge list" to see details)\n');
      }
    } catch (err) {
      // Ignore errors
    }
  } else {
    console.log('System: Legacy single-sync\n');
  }

  // Check agents
  try {
    const agents = execSync('launchctl list | grep icloudbackup', { encoding: 'utf8' });
    console.log('Running agents:');
    console.log(agents);
  } catch (err) {
    console.log('⚠ No agents running\n');
  }

  // Check Unison processes
  try {
    const processes = execSync('ps aux | grep unison | grep -v grep', { encoding: 'utf8' });
    if (processes.trim()) {
      console.log('Active sync processes:');
      const lines = processes.trim().split('\n');
      console.log(`  ${lines.length} Unison process(es) running`);
    }
  } catch (err) {
    console.log('No active sync processes');
  }

  // Show config location
  if (isMultiSync) {
    console.log(`\nConfiguration: ${syncsDir}`);
    console.log(`Logs: ${homeDir}/Library/Logs/icloud_backup/`);
  } else {
    console.log(`\nConfiguration: ${legacyConfig}`);
    console.log(`Logs: ${homeDir}/Library/Logs/icloud_backup/sync.log`);
  }
}

function viewLogs() {
  const homeDir = process.env.HOME;
  const logDir = `${homeDir}/Library/Logs/icloud_backup`;
  const syncId = process.argv[3]; // Optional sync ID

  // Check if log directory exists
  if (!fs.existsSync(logDir)) {
    console.error('Error: Log directory not found. Is CloudSyncBridge installed?');
    process.exit(1);
  }

  let logFile;

  if (syncId) {
    // View specific sync log
    logFile = `${logDir}/${syncId}.log`;

    if (!fs.existsSync(logFile)) {
      console.error(`Error: Log file not found for sync: ${syncId}`);
      console.error(`\nExpected: ${logFile}`);
      console.error('\nUse "cloudsyncbridge list" to see available syncs');
      process.exit(1);
    }
  } else {
    // Default to system log or show available logs
    logFile = `${logDir}/system.log`;

    if (!fs.existsSync(logFile)) {
      // Try to find any log files
      try {
        const logs = fs.readdirSync(logDir).filter(f => f.endsWith('.log'));

        if (logs.length === 0) {
          console.error('Error: No log files found');
          process.exit(1);
        }

        console.log('Available log files:');
        logs.forEach(log => {
          const logName = log.replace('.log', '');
          console.log(`  • cloudsyncbridge logs ${logName}`);
        });
        console.log('\nOr view all logs in:', logDir);
        process.exit(0);
      } catch (err) {
        console.error('Error reading log directory:', err.message);
        process.exit(1);
      }
    }
  }

  console.log(`Following logs from: ${logFile}\n`);
  console.log('Press Ctrl+C to exit\n');

  const child = spawn('tail', ['-f', '-n', '50', logFile], {
    stdio: 'inherit'
  });

  child.on('exit', () => {
    process.exit(0);
  });
}

function manualSync() {
  const syncId = process.argv[3]; // Optional sync ID

  // If no sync ID provided, run interactive selection
  if (!syncId) {
    runScript('sync_interactive.sh');
    return;
  }

  // Sync ID provided - run directly
  const homeDir = process.env.HOME;
  const syncManager = `${homeDir}/Library/icloud_backup/sync_manager.sh`;

  // Check for new multi-sync system first
  if (fs.existsSync(syncManager)) {
    console.log('Triggering manual sync...\n');

    const args = syncId === 'all' ? ['all'] : ['sync', syncId];
    const escapedPath = syncManager.replace(/'/g, "'\\''");
    const command = `'${escapedPath}' ${args.map(a => `'${a.replace(/'/g, "'\\''")}'`).join(' ')}`;

    const child = spawn('/bin/bash', ['-c', command], {
      stdio: 'inherit'
    });

    child.on('exit', (code) => {
      if (code === 0) {
        console.log('\n✓ Sync complete!');
      } else {
        console.error(`\n✗ Sync failed with exit code ${code}`);
      }
      process.exit(code || 0);
    });
    return;
  }

  // Fall back to legacy single sync
  const syncScript = `${homeDir}/Library/icloud_backup/sync_unison.sh`;

  if (!fs.existsSync(syncScript)) {
    console.error('Error: CloudSyncBridge is not installed');
    console.error('\nRun: cloudsyncbridge install');
    process.exit(1);
  }

  console.log('Triggering manual sync...\n');

  const escapedScript = syncScript.replace(/'/g, "'\\''");
  const child = spawn('/bin/bash', ['-c', `'${escapedScript}'`], {
    stdio: 'inherit'
  });

  child.on('exit', (code) => {
    if (code === 0) {
      console.log('\n✓ Sync complete!');
    } else {
      console.error(`\n✗ Sync failed with exit code ${code}`);
    }
    process.exit(code || 0);
  });
}

function addSync() {
  runScript('add_sync.sh');
}

function removeSync() {
  const syncId = process.argv[3];

  // Pass sync ID as argument if provided, otherwise run interactively
  if (syncId) {
    runScript('remove_sync.sh', [syncId]);
  } else {
    runScript('remove_sync.sh');
  }
}

function listSyncs() {
  const homeDir = process.env.HOME;
  const syncManager = `${homeDir}/Library/icloud_backup/sync_manager.sh`;

  if (!fs.existsSync(syncManager)) {
    console.error('Error: CloudSyncBridge is not installed');
    console.error('\nRun: cloudsyncbridge install');
    process.exit(1);
  }

  const escapedPath = syncManager.replace(/'/g, "'\\''");
  const child = spawn('/bin/bash', ['-c', `'${escapedPath}' 'list'`], {
    stdio: 'inherit'
  });

  child.on('exit', (code) => {
    process.exit(code || 0);
  });
}

function enableSync() {
  const syncId = process.argv[3];

  // Pass sync ID as argument if provided, otherwise run interactively
  if (syncId) {
    runScript('enable_sync.sh', [syncId]);
  } else {
    runScript('enable_sync.sh');
  }
}

function disableSync() {
  const syncId = process.argv[3];

  // Pass sync ID as argument if provided, otherwise run interactively
  if (syncId) {
    runScript('disable_sync.sh', [syncId]);
  } else {
    runScript('disable_sync.sh');
  }
}

// Main command handler
const command = process.argv[2];

switch (command) {
  case 'install':
    runScript('install.sh');
    break;

  case 'uninstall':
    runScript('uninstall.sh');
    break;

  case 'add':
    addSync();
    break;

  case 'remove':
    removeSync();
    break;

  case 'list':
    listSyncs();
    break;

  case 'enable':
    enableSync();
    break;

  case 'disable':
    disableSync();
    break;

  case 'status':
    checkStatus();
    break;

  case 'sync':
    manualSync();
    break;

  case 'logs':
    viewLogs();
    break;

  case 'version':
  case '--version':
  case '-v':
    showVersion();
    break;

  case 'help':
  case '--help':
  case '-h':
  case undefined:
    showHelp();
    break;

  default:
    console.error(`Unknown command: ${command}\n`);
    showHelp();
    process.exit(1);
}
