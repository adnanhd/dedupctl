# dedupctl backup command
# Create a new backup archive

# parse_backup_options: set DRY_RUN from the options and refuse anything
# else, so that a mistyped flag never turns into a real backup.
parse_backup_options() {
    DRY_RUN=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                ;;
            -h|--help)
                usage 0
                ;;
            *)
                die "backup: unknown option '$1'" $EXIT_INVALID_ARGS
                ;;
        esac
        shift
    done
}

perform_backup() {
    local source_dir="$1"
    shift
    local repo_dir="$1"
    shift

    # "$@" is the command line's options, already checked by
    # parse_backup_options; they are passed on unchanged to a parent
    # repository's backup below, so a --dry-run stays a dry run there.

    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H:%M:%S')
    local archive_name="${timestamp}"

    local dry_flag=""
    if [ "$DRY_RUN" = true ]; then
        dry_flag="--dry-run"
        echo "Dry run mode enabled. No changes will be made."
    fi

    # Build exclusion parameters using common.sh function
    build_exclude_params "borg"

    echo "Starting Borg backup of '${source_dir}' as archive '${archive_name}'..."
    # A dry run writes no log: it must leave the repository as it was.
    local log_file=/dev/null
    if [ "$DRY_RUN" != true ]; then
        mkdir -p "${repo_dir}/logs"
        log_file="${repo_dir}/logs/${timestamp}.log"
    fi

    ( cd "${source_dir}" &&
      borg create $dry_flag --verbose --stats --compression lz4 \
          "${EXCLUDE_PARAMS[@]}" \
          "${repo_dir}::${archive_name}" . ) 2>&1 | tee "$log_file"

    echo "Backup completed and archived as '${archive_name}'."

    local parent_repo
    # Search from the repository root (the current directory), not from
    # SOURCE_DIR: a SOURCE_DIR below the root would find this repository's
    # own .borgbackup and back it up again.
    parent_repo=$(find_parent_repo "$(pwd)" ".borgbackup") || true
    if [ -n "${parent_repo:-}" ]; then
        echo "Found parent Borg backup repository at '${parent_repo}'."
        echo "Initiating backup for the parent repository..."
        ( cd "${parent_repo}" && exec "$SCRIPT_PATH" backup "$@" )
    fi
}

run() {
    parse_backup_options "$@"

    local repo_root
    repo_root=$(find_repo_root "$(pwd)" ".borgbackup") || {
        echo "No Borg backup repository found in the current directory or its parents (missing .borgbackup)."
        exit 1
    }
    cd "$repo_root" || exit 1

    require_config ".borgbackup" SOURCE_DIR BORG_REPO

    perform_backup "$SOURCE_DIR" "$BORG_REPO" "$@"
}
