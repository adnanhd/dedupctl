# common.sh - Shared utilities for borg-up and rsnap
#
# This file is sourced by the main scripts and command modules.
# It provides common utility functions used across both tools.

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_CONFIG_ERROR=3
readonly EXIT_OPERATION_FAILED=4

# Default excludes for backups
readonly DEFAULT_EXCLUDES=(".cache" "tmp" "__pycache__")

# Config file names
readonly CONFIG_BORG=".borgbackup"
readonly CONFIG_RSNAP=".myrsyncbackup"

# Cleanup registry for trap handlers
_CLEANUP_ITEMS=()

# -----------------------------------------------------------------------------
# die: Print error message to stderr and exit
# Usage: die "error message" [exit_code]
# -----------------------------------------------------------------------------
die() {
    echo "Error: $1" >&2
    exit "${2:-$EXIT_ERROR}"
}

# -----------------------------------------------------------------------------
# warn: Print warning message to stderr
# Usage: warn "warning message"
# -----------------------------------------------------------------------------
warn() {
    echo "Warning: $1" >&2
}

# -----------------------------------------------------------------------------
# find_repo_root: Search upward from a given directory for a config file
# Usage: find_repo_root <start_dir> <config_file>
# Returns: Prints the repository root path; returns 0 on success, 1 on failure
# -----------------------------------------------------------------------------
find_repo_root() {
    local dir config_file
    dir=$(realpath "$1")
    config_file="$2"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/$config_file" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# -----------------------------------------------------------------------------
# find_parent_repo: Search upward from parent of given dir for a config file
# Usage: find_parent_repo <current_repo_dir> <config_file>
# Returns: Prints the parent repository path; returns 0 on success, 1 on failure
# -----------------------------------------------------------------------------
find_parent_repo() {
    local current_repo parent_dir config_file
    current_repo=$(realpath "$1")
    config_file="$2"
    parent_dir=$(dirname "$current_repo")
    while [ "$parent_dir" != "/" ]; do
        if [ -f "$parent_dir/$config_file" ]; then
            echo "$parent_dir"
            return 0
        fi
        parent_dir=$(dirname "$parent_dir")
    done
    return 1
}

# -----------------------------------------------------------------------------
# require_config: Source config file and validate required variables
# Usage: require_config <config_file> <var1> [var2] ...
# Exits with error if config file missing or required variables not defined
# -----------------------------------------------------------------------------
require_config() {
    local config_file="$1"
    shift

    if [ ! -f "$config_file" ]; then
        die "Configuration file '$config_file' not found." $EXIT_CONFIG_ERROR
    fi

    source "$config_file"

    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            die "Invalid config file. It must define $var." $EXIT_CONFIG_ERROR
        fi
    done
}

# -----------------------------------------------------------------------------
# select_from_list: Interactive selection from a numbered list
# Usage: select_from_list <prompt> <array_name> [<item_type>]
# Sets: SELECTED_INDEX (0-based) and SELECTED_VALUE on success
# Returns: 0 on success, 1 on empty list or invalid selection
# -----------------------------------------------------------------------------
select_from_list() {
    local prompt="$1"
    local -n items_ref="$2"
    local item_type="${3:-item}"
    local i=1

    if [ ${#items_ref[@]} -eq 0 ]; then
        echo "No ${item_type}s available."
        return 1
    fi

    for item in "${items_ref[@]}"; do
        echo "  $i) $item"
        ((i++))
    done

    local choice
    read -rp "$prompt" choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#items_ref[@]}" ]; then
        echo "Invalid selection."
        return 1
    fi

    SELECTED_INDEX=$((choice - 1))
    SELECTED_VALUE="${items_ref[$SELECTED_INDEX]}"
    return 0
}

# -----------------------------------------------------------------------------
# select_multiple_from_list: Interactive selection of multiple items
# Usage: select_multiple_from_list <prompt> <array_name> [<item_type>]
# Sets: SELECTED_INDICES (array of 0-based indices) on success
# Returns: 0 on success, 1 on empty list or invalid selection
# -----------------------------------------------------------------------------
select_multiple_from_list() {
    local prompt="$1"
    local -n items_ref="$2"
    local item_type="${3:-item}"
    local i=1 total="${#items_ref[@]}"

    if [ "$total" -eq 0 ]; then
        echo "No ${item_type}s available."
        return 1
    fi

    for item in "${items_ref[@]}"; do
        echo "  $i) $item"
        ((i++))
    done

    local selection
    read -rp "$prompt" selection

    # Handle 'all' selection
    if [ "$selection" = "all" ]; then
        SELECTED_INDICES=()
        for (( i = 0; i < total; i++ )); do
            SELECTED_INDICES+=("$i")
        done
        return 0
    fi

    # Parse space-separated indices
    local indices=($selection)
    SELECTED_INDICES=()

    for index in "${indices[@]}"; do
        if ! [[ "$index" =~ ^[0-9]+$ ]]; then
            echo "Invalid input: '$index' is not a number."
            return 1
        fi
        if [ "$index" -lt 1 ] || [ "$index" -gt "$total" ]; then
            echo "Invalid selection: $index is out of range (1-$total)."
            return 1
        fi
        SELECTED_INDICES+=($((index - 1)))
    done

    return 0
}

# -----------------------------------------------------------------------------
# build_exclude_params: Build exclusion parameters for backup tools
# Usage: build_exclude_params <tool_type> [excludes_array_name]
# Sets: EXCLUDE_PARAMS array with properly formatted exclude flags
# tool_type: "borg" or "rsync"
# -----------------------------------------------------------------------------
build_exclude_params() {
    local tool_type="$1"
    local excludes_var="${2:-}"
    EXCLUDE_PARAMS=()

    local -a excludes
    if [ -n "$excludes_var" ] && declare -p "$excludes_var" &>/dev/null; then
        local -n excludes_ref="$excludes_var"
        excludes=("${excludes_ref[@]}")
    elif declare -p EXCLUDES &>/dev/null 2>&1; then
        excludes=("${EXCLUDES[@]}")
    else
        excludes=("${DEFAULT_EXCLUDES[@]}")
    fi

    case "$tool_type" in
        borg)
            for ex in "${excludes[@]}"; do
                EXCLUDE_PARAMS+=("--exclude" "$ex")
            done
            ;;
        rsync)
            for ex in "${excludes[@]}"; do
                EXCLUDE_PARAMS+=("--exclude=$ex")
            done
            ;;
        *)
            die "Unknown tool type: $tool_type" $EXIT_INVALID_ARGS
            ;;
    esac
}

# -----------------------------------------------------------------------------
# parse_timestamp: Convert backup timestamp format to epoch seconds
# Usage: parse_timestamp "2024-01-15_10:30:00"
# Returns: Epoch seconds, or 0 if parsing fails
# -----------------------------------------------------------------------------
parse_timestamp() {
    local timestamp="$1"
    local formatted
    formatted=$(echo "$timestamp" | tr '_' ' ')
    date -d "$formatted" +%s 2>/dev/null || echo 0
}

# -----------------------------------------------------------------------------
# register_cleanup: Register a path for cleanup on exit
# Usage: register_cleanup "/path/to/temp/dir"
# -----------------------------------------------------------------------------
register_cleanup() {
    _CLEANUP_ITEMS+=("$1")
}

# -----------------------------------------------------------------------------
# run_cleanup: Execute cleanup of registered items
# Usage: Called automatically by trap, or manually
# -----------------------------------------------------------------------------
run_cleanup() {
    for item in "${_CLEANUP_ITEMS[@]}"; do
        if [ -d "$item" ]; then
            rm -rf "$item" 2>/dev/null || true
        elif [ -f "$item" ]; then
            rm -f "$item" 2>/dev/null || true
        fi
    done
    _CLEANUP_ITEMS=()
}

# -----------------------------------------------------------------------------
# setup_cleanup_trap: Set up EXIT trap for automatic cleanup
# Usage: setup_cleanup_trap
# -----------------------------------------------------------------------------
setup_cleanup_trap() {
    trap run_cleanup EXIT
}

# -----------------------------------------------------------------------------
# confirm_action: Prompt user for yes/no confirmation
# Usage: confirm_action "Do you want to proceed"
# Returns: 0 if confirmed (y/Y), 1 otherwise
# -----------------------------------------------------------------------------
confirm_action() {
    local prompt="$1"
    local ans
    read -rp "${prompt} [yN]? " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# -----------------------------------------------------------------------------
# validate_positive_int: Check if value is a positive integer
# Usage: validate_positive_int "$value" || die "Invalid number"
# Returns: 0 if valid positive integer, 1 otherwise
# -----------------------------------------------------------------------------
validate_positive_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}
