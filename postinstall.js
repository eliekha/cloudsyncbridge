#!/usr/bin/env node

const GREEN = '\x1b[0;32m';
const BLUE = '\x1b[0;34m';
const YELLOW = '\x1b[1;33m';
const NC = '\x1b[0m'; // No Color

console.log(`
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
