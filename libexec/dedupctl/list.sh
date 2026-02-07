# dedupctl list command
# List all available backup archives in the repository

run() {
    local repo_root

    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    echo "Available archives in '${BORG_REPO}':"
    borg list "${BORG_REPO}"
}
