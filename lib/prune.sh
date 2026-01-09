# prune.sh - Shared prune logic for borg-up and rsnap
#
# This module provides tool-agnostic prune functionality.
# It requires callbacks to be defined before calling run_prune:
#   - list_items: Function that populates PRUNE_ITEMS array
#   - delete_item: Function that deletes a single item
#   - format_item: Function that formats an item for display
#
# Configuration variables (set before calling run_prune):
#   - ITEM_TYPE: "archive" or "snapshot" (for messages)
#   - ITEM_TYPE_PLURAL: "archives" or "snapshots"

# -----------------------------------------------------------------------------
# parse_prune_options: Parse prune command line options
# Usage: parse_prune_options "$@"
# Sets: PRUNE_MODE, PRUNE_VALUE
# Returns: Remaining arguments in PRUNE_REMAINING_ARGS array
# -----------------------------------------------------------------------------
parse_prune_options() {
    PRUNE_MODE=""
    PRUNE_VALUE=""
    PRUNE_REMAINING_ARGS=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --last|--first|--older|--newer)
                if [ -n "$PRUNE_MODE" ]; then
                    die "Options --last, --first, --older, --newer, and --all are mutually exclusive." $EXIT_INVALID_ARGS
                fi
                PRUNE_MODE="${1#--}"
                shift
                if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    PRUNE_VALUE="$1"
                    shift
                else
                    local value_desc="numeric value"
                    [[ "$PRUNE_MODE" =~ ^(older|newer)$ ]] && value_desc="numeric value (in days)"
                    die "You must provide a $value_desc for --$PRUNE_MODE." $EXIT_INVALID_ARGS
                fi
                ;;
            --all)
                if [ -n "$PRUNE_MODE" ]; then
                    die "Options --last, --first, --older, --newer, and --all are mutually exclusive." $EXIT_INVALID_ARGS
                fi
                PRUNE_MODE="all"
                shift
                ;;
            *)
                PRUNE_REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done

    # Default to interactive mode if no mode specified
    if [ -z "$PRUNE_MODE" ]; then
        PRUNE_MODE="interactive"
    fi
}

# -----------------------------------------------------------------------------
# get_items_to_prune: Determine which items should be pruned based on mode
# Usage: get_items_to_prune
# Requires: PRUNE_ITEMS array to be populated, PRUNE_MODE and PRUNE_VALUE set
# Sets: ITEMS_TO_PRUNE array (indices into PRUNE_ITEMS)
# Returns: 0 on success, 1 if no items match criteria
# -----------------------------------------------------------------------------
get_items_to_prune() {
    local total="${#PRUNE_ITEMS[@]}"
    ITEMS_TO_PRUNE=()

    case "$PRUNE_MODE" in
        last)
            if [ "$total" -lt "$PRUNE_VALUE" ]; then
                die "Total ${ITEM_TYPE_PLURAL} ($total) is less than the number to remove ($PRUNE_VALUE)." $EXIT_INVALID_ARGS
            fi
            # Last N items (newest, at end of sorted list)
            for (( i = total - PRUNE_VALUE; i < total; i++ )); do
                ITEMS_TO_PRUNE+=("$i")
            done
            ;;
        first)
            if [ "$total" -lt "$PRUNE_VALUE" ]; then
                die "Total ${ITEM_TYPE_PLURAL} ($total) is less than the number to remove ($PRUNE_VALUE)." $EXIT_INVALID_ARGS
            fi
            # First N items (oldest, at start of sorted list)
            for (( i = 0; i < PRUNE_VALUE; i++ )); do
                ITEMS_TO_PRUNE+=("$i")
            done
            ;;
        older)
            local current_epoch cutoff
            current_epoch=$(date +%s)
            cutoff=$(( current_epoch - PRUNE_VALUE * 86400 ))
            for (( i = 0; i < total; i++ )); do
                local item_epoch
                item_epoch=$(parse_timestamp "${PRUNE_ITEMS[$i]}")
                if [ "$item_epoch" -lt "$cutoff" ]; then
                    ITEMS_TO_PRUNE+=("$i")
                fi
            done
            if [ ${#ITEMS_TO_PRUNE[@]} -eq 0 ]; then
                echo "No ${ITEM_TYPE_PLURAL} older than $PRUNE_VALUE days found."
                return 1
            fi
            ;;
        newer)
            local current_epoch cutoff
            current_epoch=$(date +%s)
            cutoff=$(( current_epoch - PRUNE_VALUE * 86400 ))
            for (( i = 0; i < total; i++ )); do
                local item_epoch
                item_epoch=$(parse_timestamp "${PRUNE_ITEMS[$i]}")
                if [ "$item_epoch" -gt "$cutoff" ]; then
                    ITEMS_TO_PRUNE+=("$i")
                fi
            done
            if [ ${#ITEMS_TO_PRUNE[@]} -eq 0 ]; then
                echo "No ${ITEM_TYPE_PLURAL} newer than $PRUNE_VALUE days found."
                return 1
            fi
            ;;
        all)
            if [ "$total" -eq 0 ]; then
                echo "No ${ITEM_TYPE_PLURAL} to prune."
                return 1
            fi
            for (( i = 0; i < total; i++ )); do
                ITEMS_TO_PRUNE+=("$i")
            done
            ;;
    esac

    return 0
}

# -----------------------------------------------------------------------------
# display_prune_preview: Show items that will be pruned
# Usage: display_prune_preview
# Requires: ITEMS_TO_PRUNE and PRUNE_ITEMS arrays, format_item callback
# -----------------------------------------------------------------------------
display_prune_preview() {
    local mode_desc
    case "$PRUNE_MODE" in
        last)   mode_desc="The following newest $PRUNE_VALUE ${ITEM_TYPE_PLURAL} will be removed:" ;;
        first)  mode_desc="The following oldest $PRUNE_VALUE ${ITEM_TYPE_PLURAL} will be removed:" ;;
        older)
            local cutoff=$(( $(date +%s) - PRUNE_VALUE * 86400 ))
            mode_desc="The following ${ITEM_TYPE_PLURAL} older than $PRUNE_VALUE days (cutoff: $(date -d @$cutoff)) will be removed:"
            ;;
        newer)
            local cutoff=$(( $(date +%s) - PRUNE_VALUE * 86400 ))
            mode_desc="The following ${ITEM_TYPE_PLURAL} newer than $PRUNE_VALUE days (cutoff: $(date -d @$cutoff)) will be removed:"
            ;;
        all)    mode_desc="All ${ITEM_TYPE_PLURAL} will be removed:" ;;
        *)      mode_desc="The following ${ITEM_TYPE_PLURAL} will be removed:" ;;
    esac

    echo "Prune option --${PRUNE_MODE}: $mode_desc"
    for idx in "${ITEMS_TO_PRUNE[@]}"; do
        echo "- $(format_item "${PRUNE_ITEMS[$idx]}")"
    done
}

# -----------------------------------------------------------------------------
# execute_prune: Delete the items marked for pruning
# Usage: execute_prune
# Requires: ITEMS_TO_PRUNE and PRUNE_ITEMS arrays, delete_item callback
# -----------------------------------------------------------------------------
execute_prune() {
    for idx in "${ITEMS_TO_PRUNE[@]}"; do
        delete_item "${PRUNE_ITEMS[$idx]}"
    done
    echo "${ITEM_TYPE^}s removed."
}

# -----------------------------------------------------------------------------
# run_prune_interactive: Run prune in interactive mode
# Usage: run_prune_interactive
# Requires: PRUNE_ITEMS array, format_item and delete_item callbacks
# -----------------------------------------------------------------------------
run_prune_interactive() {
    local total="${#PRUNE_ITEMS[@]}"

    if [ "$total" -eq 0 ]; then
        echo "No ${ITEM_TYPE_PLURAL} available to prune."
        return 0
    fi

    echo "Interactive mode: Enter the ${ITEM_TYPE} numbers to prune (separated by spaces), or type 'all' to prune all ${ITEM_TYPE_PLURAL}:"
    echo "Available ${ITEM_TYPE_PLURAL}:"

    if select_multiple_from_list "Your selection: " PRUNE_ITEMS "$ITEM_TYPE"; then
        if [ ${#SELECTED_INDICES[@]} -eq 0 ]; then
            echo "No ${ITEM_TYPE_PLURAL} selected."
            return 0
        fi

        # Check if all were selected
        if [ ${#SELECTED_INDICES[@]} -eq "$total" ]; then
            echo "About to prune ALL ${ITEM_TYPE_PLURAL}."
        fi

        echo "The following ${ITEM_TYPE_PLURAL} will be removed:"
        for idx in "${SELECTED_INDICES[@]}"; do
            echo "- $(format_item "${PRUNE_ITEMS[$idx]}")"
        done

        if confirm_action "Do you want to permanently delete these ${ITEM_TYPE_PLURAL}"; then
            for idx in "${SELECTED_INDICES[@]}"; do
                delete_item "${PRUNE_ITEMS[$idx]}"
            done
            echo "${ITEM_TYPE^}s removed."
        else
            echo "Aborted."
        fi
    fi
}

# -----------------------------------------------------------------------------
# run_prune: Main entry point for prune operations
# Usage: run_prune "$@"
# Requires: list_items, delete_item, format_item callbacks defined
#           ITEM_TYPE, ITEM_TYPE_PLURAL variables set
# -----------------------------------------------------------------------------
run_prune() {
    parse_prune_options "$@"

    # Populate PRUNE_ITEMS array via callback
    list_items

    local total="${#PRUNE_ITEMS[@]}"
    echo "Total ${ITEM_TYPE_PLURAL} found: $total"

    if [ "$PRUNE_MODE" = "interactive" ]; then
        run_prune_interactive
        return
    fi

    # Non-interactive mode
    if get_items_to_prune; then
        display_prune_preview

        if confirm_action "Do you want to permanently delete these ${ITEM_TYPE_PLURAL}"; then
            execute_prune
        else
            echo "Aborted."
        fi
    fi
}
