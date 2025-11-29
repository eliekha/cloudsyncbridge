#!/bin/bash
# Manage iCloud Drive "Optimize Mac Storage" setting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Source menu functions if available
if [ -f "$SCRIPT_DIR/menu_functions.sh" ]; then
    source "$SCRIPT_DIR/menu_functions.sh"
fi

show_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}Optimize Mac Storage - iCloud Drive${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

get_current_setting() {
    defaults read com.apple.bird "optimize-storage" 2>/dev/null || echo "0"
}

show_explanation() {
    echo -e "${BLUE}What is \"Optimize Mac Storage\"?${NC}"
    echo "════════════════════════════════"
    echo ""
    echo "When you sync files with CloudSyncBridge, files exist in TWO places locally:"
    echo ""
    echo -e "  ${YELLOW}1. Your source folder${NC} (e.g., external drive)"
    echo -e "  ${YELLOW}2. iCloud local cache${NC} (~/.../Mobile Documents/com~apple~CloudDocs/)"
    echo ""
    echo "This means files take up DOUBLE the disk space on your Mac."
    echo ""
    echo -e "${GREEN}With \"Optimize Mac Storage\" ENABLED:${NC}"
    echo "  • macOS automatically removes local iCloud copies when space is needed"
    echo "  • Files show as cloud icons (download on demand)"
    echo "  • Your source files remain untouched"
    echo "  • Files are always safe in iCloud servers"
    echo ""
    echo -e "${YELLOW}With \"Optimize Mac Storage\" DISABLED:${NC}"
    echo "  • All iCloud files stay on your Mac (uses more space)"
    echo "  • Instant access to all files (no download wait)"
    echo "  • Better for unreliable internet connections"
    echo ""
}

show_current_status() {
    local current=$(get_current_setting)
    echo -e "${BLUE}Current Setting${NC}"
    echo "═══════════════"
    echo ""
    if [ "$current" = "1" ]; then
        echo -e "  Optimize Mac Storage: ${GREEN}ENABLED${NC}"
        echo "  → macOS will automatically free up space"
    else
        echo -e "  Optimize Mac Storage: ${YELLOW}DISABLED${NC}"
        echo "  → All iCloud files are kept locally (uses more space)"
    fi
    echo ""
}

enable_optimize() {
    echo -e "${BLUE}Enabling Optimize Mac Storage...${NC}"
    defaults write com.apple.bird "optimize-storage" -bool true

    if [ "$(get_current_setting)" = "1" ]; then
        echo -e "${GREEN}✓ Optimize Mac Storage is now ENABLED${NC}"
        echo ""
        echo -e "${YELLOW}Note:${NC} Changes may take a few minutes to take effect."
        echo "      macOS will gradually free up space as needed."
        return 0
    else
        echo -e "${RED}✗ Failed to enable setting${NC}"
        return 1
    fi
}

disable_optimize() {
    echo -e "${BLUE}Disabling Optimize Mac Storage...${NC}"
    defaults write com.apple.bird "optimize-storage" -bool false

    if [ "$(get_current_setting)" = "0" ]; then
        echo -e "${GREEN}✓ Optimize Mac Storage is now DISABLED${NC}"
        echo ""
        echo -e "${YELLOW}Note:${NC} iCloud will begin downloading all files locally."
        echo "      This may take a while depending on your iCloud storage."
        return 0
    else
        echo -e "${RED}✗ Failed to disable setting${NC}"
        return 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    "status")
        show_banner
        show_current_status
        ;;
    "enable")
        show_banner
        enable_optimize
        ;;
    "disable")
        show_banner
        disable_optimize
        ;;
    "prompt")
        # Silent prompt mode for install/add scripts
        # Returns current setting and asks user what to do
        current=$(get_current_setting)
        echo ""
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}  iCloud Storage Optimization${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "CloudSyncBridge copies files to iCloud Drive, which means files"
        echo "exist in BOTH your source location AND iCloud's local cache."
        echo ""
        echo -e "${GREEN}\"Optimize Mac Storage\"${NC} lets macOS automatically remove local"
        echo "iCloud copies when disk space is needed. Files remain safe in iCloud"
        echo "and download automatically when you access them."
        echo ""

        if [ "$current" = "1" ]; then
            echo -e "Current setting: ${GREEN}ENABLED${NC} (recommended - saves disk space)"
        else
            echo -e "Current setting: ${YELLOW}DISABLED${NC} (files take up double space)"
        fi
        echo ""

        if [ "$current" = "1" ]; then
            OPTIMIZE_OPTIONS=(
                "Keep enabled (recommended)"
                "Disable - keep all files locally"
            )
        else
            OPTIMIZE_OPTIONS=(
                "Enable (recommended - saves space)"
                "Keep disabled - store all files locally"
            )
        fi

        OPTIMIZE_CHOICE=$(menu "Optimize Mac Storage setting:" "${OPTIMIZE_OPTIONS[@]}")

        echo ""

        if [ "$current" = "1" ]; then
            # Currently enabled
            if [ $OPTIMIZE_CHOICE -eq 1 ]; then
                disable_optimize
            else
                echo -e "${GREEN}✓ Keeping Optimize Mac Storage enabled${NC}"
            fi
        else
            # Currently disabled
            if [ $OPTIMIZE_CHOICE -eq 0 ]; then
                enable_optimize
            else
                echo -e "${YELLOW}✓ Keeping Optimize Mac Storage disabled${NC}"
                echo "  Note: Files will take up space in both locations."
            fi
        fi
        ;;
    *)
        # Interactive mode
        show_banner
        show_explanation
        show_current_status

        current=$(get_current_setting)

        if [ "$current" = "1" ]; then
            OPTIONS=(
                "Keep enabled (no change)"
                "Disable - keep all files locally"
            )
        else
            OPTIONS=(
                "Enable (recommended)"
                "Keep disabled (no change)"
            )
        fi

        CHOICE=$(menu "What would you like to do?" "${OPTIONS[@]}")

        echo ""

        if [ "$current" = "1" ]; then
            if [ $CHOICE -eq 1 ]; then
                disable_optimize
            else
                echo -e "${GREEN}✓ No changes made${NC}"
            fi
        else
            if [ $CHOICE -eq 0 ]; then
                enable_optimize
            else
                echo -e "${GREEN}✓ No changes made${NC}"
            fi
        fi
        ;;
esac

echo ""
