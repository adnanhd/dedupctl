# borg-up extract command
# Extract a backup archive to a destination directory

run() {
    local repo_root destination archive

    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    # Determine destination
    if [ $# -gt 0 ]; then
        destination="$1"
        shift
    else
        read -rp "Enter the destination directory: " destination
    fi

    if [ -z "$destination" ]; then
        echo "Error: Destination cannot be empty."
        exit 1
    fi

    mkdir -p "$destination"

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
        local i=1
        for a in "${archives[@]}"; do
            echo "  $i) $a"
            ((i++))
        done
        read -rp "Enter the number of the archive to extract: " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#archives[@]}" ]; then
            echo "Invalid selection."
            exit 1
        fi
        archive="${archives[$((choice-1))]}"
    fi

    echo "Extracting archive '$archive' to '$destination'..."
    borg extract "${BORG_REPO}::${archive}" --target "$destination"
    echo "Extraction completed."
}
