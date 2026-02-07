# borgctl log command
# Display a backup log file

run() {
    local repo_root

    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    local logs_dir="${BORG_REPO}/logs"
    mapfile -t logs < <(find "${logs_dir}" -maxdepth 1 -type f -name '*.log' 2>/dev/null | sort)
    if [ ${#logs[@]} -eq 0 ]; then
        echo "No log files found in ${logs_dir}."
        exit 0
    fi

    local log_choice=""
    if [ $# -gt 0 ]; then
        log_choice="$1"
        if [[ "$log_choice" =~ ^[0-9]+$ ]]; then
            local index=$(( log_choice - 1 ))
            if [ $index -ge 0 ] && [ $index -lt ${#logs[@]} ]; then
                log_choice="${logs[$index]}"
            else
                echo "Invalid log index: $1"
                exit 1
            fi
        else
            local found=""
            for lf in "${logs[@]}"; do
                if [[ "$(basename "$lf")" == *"$log_choice"* ]]; then
                    found="$lf"
                    break
                fi
            done
            if [ -z "$found" ]; then
                echo "No log file matches '$log_choice'."
                exit 1
            fi
            log_choice="$found"
        fi
    else
        echo "Available log files:"
        local i=1
        for lf in "${logs[@]}"; do
            echo "  $i) $(basename "$lf")"
            ((i++))
        done
        read -rp "Enter the number of the log file to view: " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#logs[@]}" ]; then
            echo "Invalid selection."
            exit 1
        fi
        log_choice="${logs[$((choice-1))]}"
    fi

    echo "Displaying log file: $(basename "$log_choice")"
    less "$log_choice"
}
