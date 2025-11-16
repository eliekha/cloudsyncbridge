#!/bin/bash
# Sync configuration management for CloudSyncBridge

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Directories
readonly CONFIG_DIR="$HOME/Library/icloud_backup"
readonly SYNCS_DIR="$CONFIG_DIR/syncs"

# Color codes (only set if not already defined)
if [ -z "$GREEN" ]; then
    readonly GREEN='\033[0;32m'
    readonly BLUE='\033[0;34m'
    readonly YELLOW='\033[1;33m'
    readonly RED='\033[0;31m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
fi

# Ensure directories exist
mkdir -p "$SYNCS_DIR"

# Generate a unique sync ID from a path
generate_sync_id() {
    local source_path="$1"

    # Get basename and sanitize
    local basename=$(basename "$source_path")
    local sync_id=$(echo "$basename" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-_')

    # Check if ID already exists
    local counter=1
    local final_id="$sync_id"

    while [ -f "$SYNCS_DIR/${final_id}.conf" ]; do
        final_id="${sync_id}-${counter}"
        ((counter++))
    done

    echo "$final_id"
}

# Create a new sync configuration
create_sync() {
    local source_path="$1"
    local sync_name="${2:-}"
    local exclude_folders=("${@:3}")

    # Normalize paths
    source_path=$(cd "$source_path" 2>/dev/null && pwd || echo "$source_path")

    # Validate source path
    if [ ! -d "$source_path" ]; then
        echo -e "${RED}Error: Source path does not exist: $source_path${NC}"
        return 1
    fi

    # Generate sync ID
    local sync_id=$(generate_sync_id "$source_path")

    # Default sync name
    if [ -z "$sync_name" ]; then
        sync_name=$(basename "$source_path")
    fi

    # Generate destination path in iCloud
    local icloud_drive="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
    local dest_basename="${sync_name// /_}_Backup"
    local dest_path="$icloud_drive/$dest_basename"

    # Create config file
    local config_file="$SYNCS_DIR/${sync_id}.conf"

    cat > "$config_file" << EOF
# CloudSyncBridge Sync Configuration
# Generated on $(date)

# Sync identification
SYNC_ID="$sync_id"
SYNC_NAME="$sync_name"

# Sync paths
SOURCE_PATH="$source_path"
DEST_PATH="$dest_path"

# Exclude folders (relative to source)
EXCLUDE_FOLDERS=(
$(for folder in "${exclude_folders[@]}"; do echo "    \"$folder\""; done)
)

# Exclude patterns (in addition to global patterns)
SYNC_EXCLUDE_PATTERNS=(
    # Add custom patterns here
)

# Enable this sync
ENABLED=true

# Track first sync (prevents deletions on initial sync)
FIRST_SYNC_DONE=false
EOF

    echo -e "${GREEN}✓ Created sync configuration: $sync_id${NC}"
    echo -e "${BLUE}  Source:${NC} $source_path"
    echo -e "${BLUE}  Destination:${NC} $dest_path"
    echo -e "${BLUE}  Config:${NC} $config_file"
    echo ""

    return 0
}

# Remove a sync configuration
remove_sync() {
    local sync_id="$1"
    local config_file="$SYNCS_DIR/${sync_id}.conf"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Sync configuration not found: $sync_id${NC}"
        return 1
    fi

    # Load config to show what we're removing
    source "$config_file"

    echo -e "${YELLOW}Removing sync configuration:${NC}"
    echo -e "${BLUE}  ID:${NC} $SYNC_ID"
    echo -e "${BLUE}  Name:${NC} $SYNC_NAME"
    echo -e "${BLUE}  Source:${NC} $SOURCE_PATH"
    echo ""

    # Confirm deletion
    read -p "Are you sure you want to remove this sync? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        return 0
    fi

    # Remove config file
    rm -f "$config_file"

    # Also remove Unison archives
    local unison_dir="$HOME/.unison"
    if [ -d "$unison_dir" ]; then
        # Try to find and remove related archives
        # This is a simplified approach - in practice, Unison archive names are complex
        echo -e "${BLUE}Cleaning up Unison archives...${NC}"
        find "$unison_dir" -name "*${sync_id}*" -type f -delete 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Sync configuration removed${NC}"

    return 0
}

# Enable a sync
enable_sync() {
    local sync_id="$1"
    local config_file="$SYNCS_DIR/${sync_id}.conf"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Sync configuration not found: $sync_id${NC}"
        return 1
    fi

    # Update ENABLED field
    sed -i '' 's/^ENABLED=.*/ENABLED=true/' "$config_file"

    echo -e "${GREEN}✓ Sync enabled: $sync_id${NC}"
    return 0
}

# Disable a sync
disable_sync() {
    local sync_id="$1"
    local config_file="$SYNCS_DIR/${sync_id}.conf"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Sync configuration not found: $sync_id${NC}"
        return 1
    fi

    # Update ENABLED field
    sed -i '' 's/^ENABLED=.*/ENABLED=false/' "$config_file"

    echo -e "${YELLOW}○ Sync disabled: $sync_id${NC}"
    return 0
}

# Show sync details
show_sync() {
    local sync_id="$1"
    local config_file="$SYNCS_DIR/${sync_id}.conf"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Sync configuration not found: $sync_id${NC}"
        return 1
    fi

    source "$config_file"

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  Sync Configuration Details                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}ID:${NC} $SYNC_ID"
    echo -e "${BLUE}Name:${NC} $SYNC_NAME"
    echo -e "${BLUE}Source:${NC} $SOURCE_PATH"
    echo -e "${BLUE}Destination:${NC} $DEST_PATH"
    echo -e "${BLUE}Status:${NC} ${ENABLED:-true}"
    echo ""

    if [ ${#EXCLUDE_FOLDERS[@]} -gt 0 ]; then
        echo -e "${BLUE}Excluded Folders:${NC}"
        for folder in "${EXCLUDE_FOLDERS[@]}"; do
            echo "  - $folder"
        done
        echo ""
    fi

    echo -e "${BLUE}Config File:${NC} $config_file"
    echo ""
}

# Export functions for use in other scripts
export -f generate_sync_id
export -f create_sync
export -f remove_sync
export -f enable_sync
export -f disable_sync
export -f show_sync

# Command-line interface
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being run directly, not sourced
    case "${1:-}" in
        create)
            shift
            create_sync "$@"
            ;;
        remove)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Missing sync ID${NC}"
                echo "Usage: $0 remove <sync-id>"
                exit 1
            fi
            remove_sync "$2"
            ;;
        enable)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Missing sync ID${NC}"
                echo "Usage: $0 enable <sync-id>"
                exit 1
            fi
            enable_sync "$2"
            ;;
        disable)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Missing sync ID${NC}"
                echo "Usage: $0 disable <sync-id>"
                exit 1
            fi
            disable_sync "$2"
            ;;
        show)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Missing sync ID${NC}"
                echo "Usage: $0 show <sync-id>"
                exit 1
            fi
            show_sync "$2"
            ;;
        *)
            echo "Usage: $0 {create|remove|enable|disable|show} [args...]"
            echo ""
            echo "Commands:"
            echo "  create <source> [name] [exclude...]  - Create a new sync"
            echo "  remove <id>                          - Remove a sync"
            echo "  enable <id>                          - Enable a sync"
            echo "  disable <id>                         - Disable a sync"
            echo "  show <id>                            - Show sync details"
            exit 1
            ;;
    esac
fi
