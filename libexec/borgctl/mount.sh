# borgctl mount command
# Mount a backup archive to a specified mount point

run() {
    local repo_root mount_point archive

    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    # Determine mount point
    if [ $# -gt 0 ]; then
        mount_point="$1"
        shift
    else
        read -rp "Enter the mount point directory: " mount_point
    fi

    if [ -z "$mount_point" ]; then
        echo "Error: Mount point cannot be empty."
        exit 1
    fi

    mkdir -p "$mount_point"

    # Get list of archives
    local archives
    mapfile -t archives < <(borg list "${BORG_REPO}" --short | sort)
    if [ ${#archives[@]} -eq 0 ]; then
        echo "No archives found in ${BORG_REPO}."
        exit 1
    fi

    # Determine archive
    if [ $# -gt 0 ]; then
        archive="$1"
    else
        echo "Available archives:"
        if select_from_list "Enter the number of the archive to mount: " archives "archive"; then
            archive="$SELECTED_VALUE"
        else
            exit 1
        fi
    fi

    echo "Mounting archive '$archive' to '$mount_point'..."
    borg mount "${BORG_REPO}::${archive}" "$mount_point"
    echo "Archive mounted. Use 'borg umount $mount_point' or 'umount $mount_point' to unmount."
}
