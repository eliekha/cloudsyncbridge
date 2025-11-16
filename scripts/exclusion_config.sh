#!/bin/bash
# Reusable exclusion configuration component
# Used by both install.sh and add_sync.sh

# Get script directory for sourcing shared files
SCRIPT_DIR_EXCL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared menu functions
source "$SCRIPT_DIR_EXCL/menu_functions.sh" 2>/dev/null

# This function configures exclusions for a sync
# Returns exclusions in a format that can be used by create_sync
configure_exclusions() {
    local sync_path="$1"
    local sync_name="$2"

    echo ""
    echo -e "${CYAN}Configuring exclusions for: ${GREEN}$sync_name${NC}"
    echo -e "${GRAY}Path: $sync_path${NC}"
    echo ""

    # Scan for top-level folders
    echo "Scanning folders..."
    FOLDER_OPTIONS=()
    while IFS= read -r folder; do
        # Skip . and .. explicitly
        if [ "$folder" = "." ] || [ "$folder" = ".." ]; then
            continue
        fi
        # Include ALL other folders (visible and hidden)
        if [ -d "$sync_path/$folder" ]; then
            FOLDER_OPTIONS+=("$folder")
        fi
    done < <(ls -1a "$sync_path" 2>/dev/null)

    # Default recommended exclusions
    RECOMMENDED_EXCLUDES=(
        ".Spotlight-V100"
        ".DocumentRevisions-V100"
        ".TemporaryItems"
        ".Trashes"
        ".fseventsd"
    )

    # Build display options with "(recommended)" labels
    FULL_FOLDER_OPTIONS=()
    for folder in "${FOLDER_OPTIONS[@]}"; do
        # Check if it's a recommended exclusion
        is_recommended=0
        for rec in "${RECOMMENDED_EXCLUDES[@]}"; do
            if [ "$folder" = "$rec" ]; then
                is_recommended=1
                break
            fi
        done

        if [ $is_recommended -eq 1 ]; then
            FULL_FOLDER_OPTIONS+=("$folder (recommended)")
        else
            FULL_FOLDER_OPTIONS+=("$folder")
        fi
    done

    echo "Found ${#FOLDER_OPTIONS[@]} folders"

    EXCLUDE_FOLDERS=()
    EXCLUDE_PATTERNS=()

    if [ ${#FULL_FOLDER_OPTIONS[@]} -gt 0 ]; then
        echo ""
        echo "Select folders to EXCLUDE from sync:"
        echo -e "${BLUE}Recommended exclusions are pre-selected${NC}"
        echo ""

        SELECTED_INDICES=$(multi_select_menu "Choose folders to exclude:" "\(recommended\)" "${FULL_FOLDER_OPTIONS[@]}")

        # Build exclude folders array from selection
        for idx in $SELECTED_INDICES; do
            # Remove " (recommended)" suffix if present
            folder="${FOLDER_OPTIONS[$idx]}"
            EXCLUDE_FOLDERS+=("$folder")
        done

        echo ""
        if [ ${#EXCLUDE_FOLDERS[@]} -gt 0 ]; then
            echo -e "${GREEN}✓ Will exclude ${#EXCLUDE_FOLDERS[@]} top-level folder(s)${NC}"
        else
            echo -e "${YELLOW}No top-level folders will be excluded${NC}"
        fi
    else
        echo -e "${YELLOW}No folders found in source${NC}"
    fi

    # Subfolder exclusions
    echo ""
    echo -e "${BLUE}Subfolder Exclusions${NC}"
    echo "===================="
    echo ""
    echo "Do you want to exclude any specific subfolders?"
    echo "Example: Projects/node_modules, Documents/cache"
    echo ""

    SUBFOLDER_OPTIONS=("Yes, add subfolder exclusions" "No, skip this step")
    SUBFOLDER_CHOICE=$(menu "Exclude specific subfolders?" "${SUBFOLDER_OPTIONS[@]}")

    echo ""

    if [ $SUBFOLDER_CHOICE -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}Enter subfolder paths to exclude (comma-separated):${NC}"
        echo "Paths are relative to the source folder root."
        echo "Example: Projects/temp, Documents/.git, Music/duplicates"
        echo ""
        read -p "Subfolder paths: " subfolder_input

        if [ -n "$subfolder_input" ]; then
            # Split by comma and trim whitespace
            IFS=',' read -ra SUBFOLDERS <<< "$subfolder_input"
            for subfolder in "${SUBFOLDERS[@]}"; do
                # Trim leading/trailing whitespace
                subfolder=$(echo "$subfolder" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [ -n "$subfolder" ]; then
                    EXCLUDE_FOLDERS+=("$subfolder")
                    echo -e "${GREEN}✓ Added: $subfolder${NC}"
                fi
            done
        fi
        echo ""
        echo -e "${GREEN}✓ Total folders to exclude: ${#EXCLUDE_FOLDERS[@]}${NC}"
    else
        echo "Skipped subfolder exclusions"
    fi

    # File patterns to exclude
    echo ""
    echo -e "${BLUE}File Pattern Exclusions${NC}"
    echo "========================"
    echo ""
    echo "Default exclusions:"
    echo "  • *.env (environment files)"
    echo "  • .DS_Store (macOS metadata)"
    echo "  • ._* (macOS resource forks)"
    echo ""

    PATTERN_OPTIONS=("Yes, add default exclusions" "No, skip defaults")
    PATTERN_CHOICE=$(menu "Add these default exclusions?" "${PATTERN_OPTIONS[@]}")

    echo ""

    if [ $PATTERN_CHOICE -eq 0 ]; then
        EXCLUDE_PATTERNS+=("*.env" ".DS_Store" "._*")
        echo -e "${GREEN}✓ Added default exclusions${NC}"
    fi

    # Custom patterns
    echo ""
    echo -e "${YELLOW}Add custom file patterns to exclude? (Enter to skip)${NC}"
    echo "Example: *.log, *.tmp, .cache"

    while true; do
        read -p "Pattern (or Enter to finish): " custom_pattern
        if [ -z "$custom_pattern" ]; then
            break
        fi
        EXCLUDE_PATTERNS+=("$custom_pattern")
        echo -e "${GREEN}✓ Added: $custom_pattern${NC}"
    done

    if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
        echo ""
        echo -e "${GREEN}Total file patterns to exclude: ${#EXCLUDE_PATTERNS[@]}${NC}"
    fi

    # Set arrays for caller to use (can't export arrays in bash 3.2)
    CONFIGURED_EXCLUDE_FOLDERS=("${EXCLUDE_FOLDERS[@]}")
    CONFIGURED_EXCLUDE_PATTERNS=("${EXCLUDE_PATTERNS[@]}")
}
