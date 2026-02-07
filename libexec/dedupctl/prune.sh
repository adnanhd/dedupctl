# dedupctl prune command
# Purge backup archives from the repository

# Source the shared prune library
source "$LIB_DIR/prune.sh"

# Configure item type for messages
ITEM_TYPE="archive"
ITEM_TYPE_PLURAL="archives"

# Callback: List all archives and populate PRUNE_ITEMS array
list_items() {
    mapfile -t PRUNE_ITEMS < <(borg list "${BORG_REPO}" --short | sort)
}

# Callback: Delete a single archive
delete_item() {
    local archive="$1"
    borg delete "${BORG_REPO}::${archive}"
}

# Callback: Format an archive for display
format_item() {
    local archive="$1"
    echo "${BORG_REPO}::${archive}"
}

run() {
    local repo_root
    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    run_prune "$@"
}
