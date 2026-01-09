# borg-up prune command
# Purge backup archives from the repository

run() {
    local mode="" value=""
    if [ $# -gt 0 ]; then
        while [ $# -gt 0 ]; do
            case "$1" in
                --last)
                    if [ -n "$mode" ]; then
                        echo "Error: Options --last, --first, --older, --newer, and --all are mutually exclusive."
                        exit 1
                    fi
                    mode="last"
                    shift
                    if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                        value="$1"
                        shift
                    else
                        echo "Error: You must provide a numeric value for --last."
                        exit 1
                    fi
                    ;;
                --first)
                    if [ -n "$mode" ]; then
                        echo "Error: Options --last, --first, --older, --newer, and --all are mutually exclusive."
                        exit 1
                    fi
                    mode="first"
                    shift
                    if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                        value="$1"
                        shift
                    else
                        echo "Error: You must provide a numeric value for --first."
                        exit 1
                    fi
                    ;;
                --older)
                    if [ -n "$mode" ]; then
                        echo "Error: Options --last, --first, --older, --newer, and --all are mutually exclusive."
                        exit 1
                    fi
                    mode="older"
                    shift
                    if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                        value="$1"
                        shift
                    else
                        echo "Error: You must provide a numeric value (in days) for --older."
                        exit 1
                    fi
                    ;;
                --newer)
                    if [ -n "$mode" ]; then
                        echo "Error: Options --last, --first, --older, --newer, and --all are mutually exclusive."
                        exit 1
                    fi
                    mode="newer"
                    shift
                    if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                        value="$1"
                        shift
                    else
                        echo "Error: You must provide a numeric value (in days) for --newer."
                        exit 1
                    fi
                    ;;
                --all)
                    if [ -n "$mode" ]; then
                        echo "Error: Options --last, --first, --older, --newer, and --all are mutually exclusive."
                        exit 1
                    fi
                    mode="all"
                    shift
                    ;;
                *)
                    echo "Unknown option: $1"
                    usage
                    ;;
            esac
        done
    fi

    if [ -z "$mode" ]; then
        mode="interactive"
    fi

    local repo_root
    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" BORG_REPO

    local archives
    mapfile -t archives < <(borg list "${BORG_REPO}" --short | sort)
    local total="${#archives[@]}"
    echo "Total archives found: $total"

    if [ "$mode" != "interactive" ]; then
        case "$mode" in
            last)
                if [ "$total" -lt "$value" ]; then
                    echo "Error: Total archives ($total) is less than the number to remove ($value)."
                    exit 1
                fi
                echo "Purge option --last: The following newest $value archives will be removed:"
                for (( i = total - value; i < total; i++ )); do
                    echo "- ${BORG_REPO}::${archives[i]}"
                done
                ;;
            first)
                if [ "$total" -lt "$value" ]; then
                    echo "Error: Total archives ($total) is less than the number to remove ($value)."
                    exit 1
                fi
                echo "Purge option --first: The following oldest $value archives will be removed:"
                for (( i = 0; i < value; i++ )); do
                    echo "- ${BORG_REPO}::${archives[i]}"
                done
                ;;
            older)
                local current_epoch
                current_epoch=$(date +%s)
                local cutoff=$(( current_epoch - value * 86400 ))
                local found=0
                echo "Purge option --older: The following archives older than $value days (cutoff: $(date -d @$cutoff)) will be removed:"
                for archive in "${archives[@]}"; do
                    local archive_epoch
                    archive_epoch=$(parse_timestamp "$archive")
                    if [ "$archive_epoch" -lt "$cutoff" ]; then
                        echo "- ${BORG_REPO}::${archive}"
                        found=$(( found + 1 ))
                    fi
                done
                if [ "$found" -eq 0 ]; then
                    echo "No archives older than $value days found."
                    exit 0
                fi
                ;;
            newer)
                local current_epoch
                current_epoch=$(date +%s)
                local cutoff=$(( current_epoch - value * 86400 ))
                local found=0
                echo "Purge option --newer: The following archives newer than $value days (cutoff: $(date -d @$cutoff)) will be removed:"
                for archive in "${archives[@]}"; do
                    local archive_epoch
                    archive_epoch=$(parse_timestamp "$archive")
                    if [ "$archive_epoch" -gt "$cutoff" ]; then
                        echo "- ${BORG_REPO}::${archive}"
                        found=$(( found + 1 ))
                    fi
                done
                if [ "$found" -eq 0 ]; then
                    echo "No archives newer than $value days found."
                    exit 0
                fi
                ;;
            all)
                if [ "$total" -eq 0 ]; then
                    echo "No archives to purge."
                    exit 0
                fi
                echo "Purge option --all: All archives will be removed:"
                for archive in "${archives[@]}"; do
                    echo "- ${BORG_REPO}::${archive}"
                done
                ;;
            *)
                echo "Unknown purge mode: $mode"
                usage
                ;;
        esac
        read -rp "Do you want to permanently delete these archives [yN]? " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            case "$mode" in
                last)
                    for (( i = total - value; i < total; i++ )); do
                        borg delete "${BORG_REPO}::${archives[i]}"
                    done
                    ;;
                first)
                    for (( i = 0; i < value; i++ )); do
                        borg delete "${BORG_REPO}::${archives[i]}"
                    done
                    ;;
                older)
                    for archive in "${archives[@]}"; do
                        local archive_epoch
                        archive_epoch=$(parse_timestamp "$archive")
                        if [ "$archive_epoch" -lt "$cutoff" ]; then
                            borg delete "${BORG_REPO}::${archive}"
                        fi
                    done
                    ;;
                newer)
                    for archive in "${archives[@]}"; do
                        local archive_epoch
                        archive_epoch=$(parse_timestamp "$archive")
                        if [ "$archive_epoch" -gt "$cutoff" ]; then
                            borg delete "${BORG_REPO}::${archive}"
                        fi
                    done
                    ;;
                all)
                    for archive in "${archives[@]}"; do
                        borg delete "${BORG_REPO}::${archive}"
                    done
                    ;;
            esac
            echo "Archives removed."
        else
            echo "Aborted."
        fi
    else
        # Interactive mode
        echo "Interactive mode: Enter the archive numbers to purge (separated by spaces), or type 'all' to purge all archives:"
        echo "Available archives:"
        local i=1
        for archive in "${archives[@]}"; do
            echo "  $i) $archive"
            ((i++))
        done
        read -rp "Your selection: " selection
        if [ "$selection" = "all" ]; then
            echo "About to purge ALL archives."
            read -rp "Do you want to permanently delete these archives [yN]? " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                for archive in "${archives[@]}"; do
                    borg delete "${BORG_REPO}::${archive}"
                done
                echo "All archives removed."
            else
                echo "Aborted."
            fi
        else
            local indices
            indices=($selection)
            echo "The following archives will be removed:"
            for index in "${indices[@]}"; do
                if ! [[ "$index" =~ ^[0-9]+$ ]]; then
                    echo "Invalid input: '$index' is not a number."
                    exit 1
                fi
                if [ "$index" -lt 1 ] || [ "$index" -gt "$total" ]; then
                    echo "Invalid selection: $index is out of range (1-$total)."
                    exit 1
                fi
                echo "- ${BORG_REPO}::${archives[$(( index - 1 ))]}"
            done
            read -rp "Do you want to permanently delete these archives [yN]? " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                for index in "${indices[@]}"; do
                    borg delete "${BORG_REPO}::${archives[$(( index - 1 ))]}"
                done
                echo "Archives removed."
            else
                echo "Aborted."
            fi
        fi
    fi
}
