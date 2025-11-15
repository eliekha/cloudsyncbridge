#!/usr/bin/env node

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const SCRIPTS_DIR = path.join(__dirname, '..', 'scripts');

function showBanner() {
  console.log(`
   _____ _                 _  _____                  ____       _     _
  / ____| |               | |/ ____|                |  _ \     (_)   | |
 | |    | | ___  _   _  __| | (___  _   _ _ __   ___| |_) |_ __ _  __| | __ _  ___
 | |    | |/ _ \| | | |/ _` |\___ \| | | | '_ \ / __|  _ <| '__| |/ _` |/ _` |/ _ \
 | |____| | (_) | |_| | (_| |____) | |_| | | | | (__| |_) | |  | | (_| | (_| |  __/
  \_____|_|\___/ \__,_|\__,_|_____/ \__, |_| |_|\___|____/|_|  |_|\__,_|\__, |\___|
                                     __/ |                               __/ |
                                    |___/                               |___/
`);
}

function showHelp() {
  showBanner();
  console.log('CloudSyncBridge - Bidirectional iCloud Sync for External Drives\n');
  console.log('Usage: cloudsyncbridge <command>\n');
  console.log('Commands:');
  console.log('  install     - Install and configure CloudSyncBridge');
  console.log('  uninstall   - Remove CloudSyncBridge from your system');
  console.log('  status      - Check sync status and view running agents');
  console.log('  sync        - Manually trigger a sync');
  console.log('  logs        - View sync logs');
  console.log('  help        - Show this help message');
  console.log('  version     - Show version information');
  console.log('');
  console.log('Examples:');
  console.log('  cloudsyncbridge install    # Start interactive installation');
  console.log('  cloudsyncbridge status     # Check if sync is running');
  console.log('  cloudsyncbridge logs       # Follow sync logs in real-time');
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
  const child = spawn(scriptPath, args, {
    stdio: 'inherit',
    shell: true
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
  const configPath = `${homeDir}/Library/icloud_backup/config.sh`;

  // Check if installed
  if (!fs.existsSync(configPath)) {
    console.log('❌ CloudSyncBridge is not installed');
    console.log('\nRun: cloudsyncbridge install');
    return;
  }

  console.log('✓ CloudSyncBridge is installed\n');

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
  console.log(`\nConfiguration: ${configPath}`);
  console.log(`Logs: ${homeDir}/Library/Logs/icloud_backup/sync.log`);
}

function viewLogs() {
  const homeDir = process.env.HOME;
  const logFile = `${homeDir}/Library/Logs/icloud_backup/sync.log`;

  if (!fs.existsSync(logFile)) {
    console.error('Error: Log file not found. Is CloudBridge installed?');
    process.exit(1);
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
  const homeDir = process.env.HOME;
  const syncScript = `${homeDir}/Library/icloud_backup/sync_unison.sh`;

  if (!fs.existsSync(syncScript)) {
    console.error('Error: CloudSyncBridge is not installed');
    console.error('\nRun: cloudsyncbridge install');
    process.exit(1);
  }

  console.log('Triggering manual sync...\n');

  const child = spawn(syncScript, [], {
    stdio: 'inherit',
    shell: true
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

// Main command handler
const command = process.argv[2];

switch (command) {
  case 'install':
    runScript('install.sh');
    break;

  case 'uninstall':
    runScript('uninstall.sh');
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
