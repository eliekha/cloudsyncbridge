#!/usr/bin/env node

// Only show for global installs, not when used as a dependency
if (process.env.npm_config_global === 'true') {
  const GREEN = '\x1b[0;32m';
  const BLUE = '\x1b[0;34m';
  const YELLOW = '\x1b[1;33m';
  const NC = '\x1b[0m';

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
