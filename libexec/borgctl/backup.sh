# borg-up backup command
# Create a new backup archive

perform_backup() {
    local source_dir="$1"
    shift
    local repo_dir="$1"
    shift

    local DRY_RUN=false
    local FORCE_FULL=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force-full|--create)
                FORCE_FULL=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                shift
                ;;
        esac
    done

    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H:%M:%S')
    local archive_name="${timestamp}"

    local dry_flag=""
    if [ "$DRY_RUN" = true ]; then
        dry_flag="--dry-run"
        echo "Dry run mode enabled. No changes will be made."
    fi

    echo "Starting Borg backup of '${source_dir}' as archive '${archive_name}'..."
    mkdir -p "${repo_dir}/logs"
    local log_file="${repo_dir}/logs/${timestamp}.log"

    ( cd "${source_dir}" &&
      borg create $dry_flag --verbose --stats --compression lz4 "${repo_dir}::${archive_name}" . ) | tee "$log_file"

    echo "Backup completed and archived as '${archive_name}'."

    local parent_repo
    parent_repo=$(find_parent_repo "${source_dir}" ".borgbackup") || true
    if [ -n "${parent_repo:-}" ]; then
        echo "Found parent Borg backup repository at '${parent_repo}'."
        echo "Initiating backup for the parent repository..."
        ( cd "${parent_repo}" && exec "$SCRIPT_PATH" backup "$@" )
    fi
}

run() {
    local repo_root
    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found in the current directory or its parents (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" SOURCE_DIR BORG_REPO

    perform_backup "$SOURCE_DIR" "$BORG_REPO" "$@"
}
