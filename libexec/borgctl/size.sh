# borg-up size command
# Display size and info for an archive

run() {
    local repo_root archive

    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
         echo "No Borg backup repository found (missing .borgbackup)."
         exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    local archives
    mapfile -t archives < <(borg list "${BORG_REPO}" --short | sort)
    if [ ${#archives[@]} -eq 0 ]; then
         echo "No archives found in ${BORG_REPO}."
         exit 1
    fi

    echo "Available archives:"
    local i=1
    for a in "${archives[@]}"; do
         echo "  $i) $a"
         ((i++))
    done
    read -rp "Enter the number of the archive to check size: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#archives[@]}" ]; then
         echo "Invalid selection."
         exit 1
    fi
    archive="${archives[$((choice-1))]}"

    echo "Size and info for archive '$archive':"
    borg info "${BORG_REPO}::${archive}"
}
