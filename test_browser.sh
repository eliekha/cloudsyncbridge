#!/bin/bash
# Quick test for the folder browser

source "$(dirname "$0")/scripts/folder_browser.sh"

echo "Testing folder browser..."
echo "Starting from: $HOME"
echo ""

selected=$(select_folder "$HOME")

clear
if [ -n "$selected" ]; then
    echo "✓ You selected: $selected"
else
    echo "✗ Selection cancelled"
fi
