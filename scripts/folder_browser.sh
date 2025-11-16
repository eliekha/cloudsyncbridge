#!/bin/bash
# Interactive folder browser with tree navigation
# Usage: source folder_browser.sh && select_folder "/starting/path"

# Color codes (only set if not already defined)
if [ -z "$GREEN" ]; then
    readonly GREEN='\033[0;32m'
    readonly BLUE='\033[0;34m'
    readonly YELLOW='\033[1;33m'
    readonly CYAN='\033[0;36m'
    readonly GRAY='\033[0;90m'
    readonly NC='\033[0m'
fi

# Track expanded/collapsed state (bash 3.2 compatible)
# Use newline-separated strings instead of associative arrays
EXPANDED_DIRS=""
VISIBLE_ITEMS=()
SELECTED_INDEX=0

# Check if a folder is currently being synced
is_synced() {
    local path="$1"
    local syncs_dir="$HOME/Library/icloud_backup/syncs"

    # Check new multi-sync system
    if [ -d "$syncs_dir" ]; then
        for config_file in "$syncs_dir"/*.conf; do
            if [ -f "$config_file" ]; then
                # Source config and check if SOURCE_PATH matches
                (
                    source "$config_file" 2>/dev/null
                    if [ "$SOURCE_PATH" = "$path" ]; then
                        exit 0
                    fi
                    exit 1
                ) && return 0
            fi
        done
    fi

    # Check legacy single-sync config
    local config_dir="$HOME/Library/icloud_backup"
    if [ -f "$config_dir/config.sh" ]; then
        if grep -q "SOURCE_DRIVE=\"$path\"" "$config_dir/config.sh" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Helper functions for bash 3.2 compatibility

# Check if a directory is in the expanded list
is_expanded() {
    local dir="$1"
    echo "$EXPANDED_DIRS" | grep -Fxq "$dir"
}

# Add directory to expanded list
mark_expanded() {
    local dir="$1"
    if ! is_expanded "$dir"; then
        EXPANDED_DIRS+="$dir"$'\n'
    fi
}

# Remove directory from expanded list
mark_collapsed() {
    local dir="$1"
    EXPANDED_DIRS=$(echo "$EXPANDED_DIRS" | grep -Fxv "$dir")
}

# Get immediate children of a directory
get_children() {
    local dir="$1"

    # Scan directory for subdirectories (only one level)
    find "$dir" -maxdepth 1 -type d ! -path "$dir" ! -name ".*" 2>/dev/null | sort
}

# Check if directory has subdirectories
has_children() {
    local dir="$1"
    local children=$(get_children "$dir")
    [ -n "$children" ]
}

# Build the visible items list based on expanded state
build_visible_list() {
    local start_path="$1"
    local depth="${2:-0}"
    local prefix="${3:-}"

    # Add current directory to visible list if depth > 0
    if [ $depth -gt 0 ]; then
        local sync_indicator=""
        if is_synced "$start_path"; then
            sync_indicator=" ${YELLOW}⚡${NC}"
        fi

        local expanded_marker=""
        if has_children "$start_path"; then
            if is_expanded "$start_path"; then
                expanded_marker="[-] "
            else
                expanded_marker="[+] "
            fi
        else
            expanded_marker="    "
        fi

        VISIBLE_ITEMS+=("$depth|$start_path|$prefix$expanded_marker$(basename "$start_path")$sync_indicator")
    fi

    # If expanded, show children
    if is_expanded "$start_path" || [ $depth -eq 0 ]; then
        local child_prefix="$prefix  "
        if [ $depth -gt 0 ]; then
            child_prefix="$prefix  "
        fi

        # Get children
        local children=$(get_children "$start_path")
        if [ -n "$children" ]; then
            while IFS= read -r dir; do
                if [ -n "$dir" ] && [ -d "$dir" ]; then
                    build_visible_list "$dir" $((depth + 1)) "$child_prefix"
                fi
            done <<< "$children"
        fi
    fi
}

# Render the current view
render_view() {
    local start_path="$1"
    local is_initial="${2:-false}"

    if [ "$is_initial" = "true" ]; then
        # Initial render - clear screen and draw everything
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}Select a folder to sync to iCloud${NC}                          ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GRAY}Use ↑/↓ to navigate, → to expand, ← to collapse, Enter to select${NC}"
        echo -e "${GRAY}Press 'q' to cancel${NC}"
        echo ""

        # Build initial visible list
        VISIBLE_ITEMS=()
        build_visible_list "$start_path" 0 ""

        # Pre-allocate space for items
        for item in "${VISIBLE_ITEMS[@]}"; do
            echo ""
        done
    fi

    # Move cursor back to start of items list (7 lines up for header)
    if [ ${#VISIBLE_ITEMS[@]} -gt 0 ]; then
        tput cuu $(( ${#VISIBLE_ITEMS[@]} ))
    fi

    # Display items with selection highlight
    local idx=0
    for item in "${VISIBLE_ITEMS[@]}"; do
        # Clear the line
        tput el

        # Parse pipe-delimited string without using cut (UTF-8 safe)
        local depth="${item%%|*}"
        local rest="${item#*|}"
        local path="${rest%%|*}"
        local display="${rest#*|}"

        if [ $idx -eq $SELECTED_INDEX ]; then
            echo -e "${BLUE}→ $display${NC}"
        else
            echo -e "  $display"
        fi

        ((idx++))
    done
}

# Get the path at current selection
get_selected_path() {
    if [ ${#VISIBLE_ITEMS[@]} -eq 0 ]; then
        echo ""
        return
    fi

    local item="${VISIBLE_ITEMS[$SELECTED_INDEX]}"
    # Parse pipe-delimited string without using cut (UTF-8 safe)
    local rest="${item#*|}"
    local path="${rest%%|*}"
    echo "$path"
}

# Main folder selection function
select_folder() {
    local start_path="${1:-$HOME}"

    # Normalize path
    start_path=$(cd "$start_path" && pwd)

    # Initialize with start directory expanded
    mark_expanded "$start_path"
    SELECTED_INDEX=0

    # Disable terminal echo and enable raw mode
    stty -echo -icanon time 0 min 0

    # Hide cursor
    tput civis

    local running=true
    local selected_path=""
    local need_rebuild=true

    # Initial render
    render_view "$start_path" "true"

    while $running; do
        # Rebuild visible list if needed (after expand/collapse)
        if [ "$need_rebuild" = "true" ]; then
            # Clear and redraw everything
            clear
            render_view "$start_path" "true"
            need_rebuild=false
        else
            # Just redraw items (smooth navigation)
            render_view "$start_path" "false"
        fi

        # Read single character
        local key=""
        IFS= read -rsn1 key

        # Handle escape sequences (arrow keys)
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key # Read the rest of the escape sequence
        fi

        case "$key" in
            "[A"|"k") # Up arrow or k
                if [ $SELECTED_INDEX -gt 0 ]; then
                    ((SELECTED_INDEX--))
                fi
                ;;
            "[B"|"j") # Down arrow or j
                if [ $SELECTED_INDEX -lt $((${#VISIBLE_ITEMS[@]} - 1)) ]; then
                    ((SELECTED_INDEX++))
                fi
                ;;
            "[C"|"l") # Right arrow or l - expand
                local current_path=$(get_selected_path)
                if [ -n "$current_path" ] && [ -d "$current_path" ]; then
                    mark_expanded "$current_path"
                    need_rebuild=true
                fi
                ;;
            "[D"|"h") # Left arrow or h - collapse
                local current_path=$(get_selected_path)
                if [ -n "$current_path" ] && is_expanded "$current_path"; then
                    mark_collapsed "$current_path"
                    need_rebuild=true
                fi
                ;;
            "") # Enter
                selected_path=$(get_selected_path)
                if [ -n "$selected_path" ]; then
                    running=false
                fi
                ;;
            "q"|"Q") # Quit
                selected_path=""
                running=false
                ;;
        esac
    done

    # Restore terminal
    stty echo icanon
    tput cnorm

    # Clear screen after browser
    clear

    # Return selected path (write to temp file if provided, otherwise stdout)
    if [ -n "${FOLDER_BROWSER_RESULT_FILE:-}" ]; then
        echo "$selected_path" > "$FOLDER_BROWSER_RESULT_FILE"
    else
        echo "$selected_path"
    fi
}

# Export functions for use in other scripts
export -f select_folder
export -f is_synced
export -f is_expanded
export -f mark_expanded
export -f mark_collapsed
export -f get_children
export -f has_children
export -f build_visible_list
export -f render_view
export -f get_selected_path
