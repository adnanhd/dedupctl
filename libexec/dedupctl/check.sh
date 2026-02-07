# dedupctl check command
# Perform an integrity check of the repository

run() {
    local repo_root

    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    echo "Performing integrity check on repository '${BORG_REPO}'..."
    borg check "${BORG_REPO}"
    echo "Check completed."
}
