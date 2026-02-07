# dedupctl diff command
# Compare two archives

run() {
    local repo_root diff_archive1 diff_archive2 temp_dir

    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    # Get list of archives
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

    # Prompt for the first archive
    read -rp "Enter the number of the first archive for diff (or press Enter for current state): " choice
    if [ -z "$choice" ]; then
        diff_archive1="current"
    elif [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#archives[@]}" ]; then
            echo "Invalid selection."
            exit 1
        fi
        diff_archive1="${archives[$((choice-1))]}"
    else
        echo "Invalid input."
        exit 1
    fi

    # Prompt for the second archive (must choose from available archives)
    read -rp "Enter the number of the second archive for diff: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#archives[@]}" ]; then
         echo "Invalid selection."
         exit 1
    fi
    diff_archive2="${archives[$((choice-1))]}"

    if [ "$diff_archive1" = "current" ]; then
        echo "Comparing live state (current contents of SOURCE_DIR) with archive '$diff_archive2'..."
        # Create a temporary directory, extract the chosen snapshot there, then diff
        temp_dir=$(mktemp -d -t borgdiff-XXXXXX)
        # Ensure cleanup on exit or interrupt
        trap 'rm -rf "$temp_dir"' EXIT
        echo "Extracting archive '$diff_archive2' to temporary directory $temp_dir..."
        local source_dir
        source_dir="$(pwd)"
        (cd "$temp_dir" && borg extract "${BORG_REPO}::${diff_archive2}")
        echo "Running diff between current state and extracted snapshot..."
        diff -r "$source_dir" "$temp_dir" || true
        echo "Diff complete."
    else
        echo "Comparing archive '$diff_archive1' with archive '$diff_archive2'..."
        borg diff "${BORG_REPO}::${diff_archive1}" "${diff_archive2}"
    fi
}
