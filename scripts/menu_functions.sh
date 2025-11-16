#!/bin/bash
# Shared menu functions for CloudSyncBridge
# Used by install.sh, add_sync.sh, and exclusion_config.sh

menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local last_selected=-1

    # Hide cursor
    tput civis >&2

    # Draw initial menu (to stderr so it doesn't get captured)
    echo -e "${YELLOW}${prompt}${NC}" >&2
    echo -e "${BLUE}Use ↑/↓ arrows to navigate, Enter to select${NC}" >&2
    for i in "${!options[@]}"; do
        echo "" >&2
    done

    while true; do
        # Move cursor to start of options (skip prompt + instruction line)
        tput cuu $(( ${#options[@]} )) >&2

        # Display options
        for i in "${!options[@]}"; do
            # Clear the line
            tput el >&2
            if [ $i -eq $selected ]; then
                echo -e "  ${GREEN}▶ ${options[$i]}${NC}" >&2
            else
                echo "    ${options[$i]}" >&2
            fi
        done

        # Read key from tty
        IFS= read -rsn1 key </dev/tty

        # Handle arrow keys (escape sequences)
        if [ "$key" = $'\x1b' ]; then
            IFS= read -rsn2 key </dev/tty
            case "$key" in
                '[A') # Up arrow
                    ((selected--))
                    if [ $selected -lt 0 ]; then
                        selected=$(( ${#options[@]} - 1 ))
                    fi
                    ;;
                '[B') # Down arrow
                    ((selected++))
                    if [ $selected -ge ${#options[@]} ]; then
                        selected=0
                    fi
                    ;;
            esac
        elif [ "$key" = "" ]; then
            # Enter key
            break
        fi
    done

    # Show cursor
    tput cnorm >&2

    # Output selected index to stdout (not stderr)
    echo "$selected"
}
multi_select_menu() {
    local prompt="$1"
    local preselect_pattern="$2"
    shift 2
    local options=("$@")
    local selected=0
    local -a checked=()

    # Initialize checkboxes - pre-check items matching pattern
    for i in "${!options[@]}"; do
        if [ "$preselect_pattern" != "NONE" ] && [[ "${options[$i]}" =~ $preselect_pattern ]]; then
            checked[$i]=1
        else
            checked[$i]=0
        fi
    done

    # Hide cursor
    tput civis >&2

    # Draw initial menu header (to stderr so it doesn't get captured)
    echo -e "${YELLOW}${prompt}${NC}" >&2
    echo -e "${BLUE}Use ↑/↓ to navigate, Space to toggle [✓], Enter when done${NC}" >&2

    # Draw initial options
    for i in "${!options[@]}"; do
        local checkbox="[ ]"
        if [ ${checked[$i]} -eq 1 ]; then
            checkbox="[✓]"
        fi

        if [ $i -eq $selected ]; then
            echo -e "  ${GREEN}▶ ${checkbox} ${options[$i]}${NC}" >&2
        else
            echo "    ${checkbox} ${options[$i]}" >&2
        fi
    done

    while true; do
        # Read key from tty (IFS= prevents trimming of space character)
        IFS= read -rsn1 key </dev/tty

        # Handle key input FIRST before redrawing
        local should_redraw=0

        if [ "$key" = $'\x1b' ]; then
            # Arrow key - read the rest of the escape sequence
            IFS= read -rsn2 rest </dev/tty
            case "$rest" in
                '[A') # Up arrow
                    ((selected--))
                    if [ $selected -lt 0 ]; then
                        selected=$(( ${#options[@]} - 1 ))
                    fi
                    should_redraw=1
                    ;;
                '[B') # Down arrow
                    ((selected++))
                    if [ $selected -ge ${#options[@]} ]; then
                        selected=0
                    fi
                    should_redraw=1
                    ;;
            esac
        elif [ "$key" = " " ]; then
            # Space - toggle selection
            if [ ${checked[$selected]} -eq 1 ]; then
                checked[$selected]=0
            else
                checked[$selected]=1
            fi
            should_redraw=1
        elif [ "$key" = "" ]; then
            # Enter - done
            break
        fi

        # Only redraw if something changed
        if [ $should_redraw -eq 1 ]; then
            # Move cursor back up to start of options
            tput cuu $(( ${#options[@]} )) >&2

            # Redraw all options
            for i in "${!options[@]}"; do
                tput el >&2
                local checkbox="[ ]"
                if [ ${checked[$i]} -eq 1 ]; then
                    checkbox="[✓]"
                fi

                if [ $i -eq $selected ]; then
                    echo -e "  ${GREEN}▶ ${checkbox} ${options[$i]}${NC}" >&2
                else
                    echo "    ${checkbox} ${options[$i]}" >&2
                fi
            done
        fi
    done

    # Show cursor
    tput cnorm >&2

    # Return checked items as space-separated indices (only this goes to stdout)
    local result=""
    for i in "${!checked[@]}"; do
        if [ ${checked[$i]} -eq 1 ]; then
            result="$result $i"
        fi
    done
    echo "$result"
}
