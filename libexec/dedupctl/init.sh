# dedupctl init command
# Initialize a Borg backup repository

run() {
    local path=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage 0
                ;;
            -*)
                die "init takes no options: '$1'" $EXIT_INVALID_ARGS
                ;;
            *)
                [ -z "$path" ] || die "init takes at most one path." $EXIT_INVALID_ARGS
                path="$1"
                ;;
        esac
        shift
    done

    local src
    if [ -n "$path" ]; then
        [ -d "$path" ] || die "'$path' is not a directory." $EXIT_INVALID_ARGS
        src=$(realpath "$path")
    else
        src=$(pwd)
    fi

    if [ -f "$src/.borgbackup" ]; then
        echo "Borg repository already initialized in '$src'. Skipping initialization."
        exit 0
    fi

    local safe_name
    safe_name=$(echo "$src" | sed 's/!/!!/g' | sed 's/\//!/g')
    local repo_dir="${BORG_BACKUP_ROOT}/${safe_name}"

    if [ -d "$repo_dir" ]; then
        echo "Borg repository already exists at '${repo_dir}'."
    else
        mkdir -p "${repo_dir}"
        echo "Initializing Borg repository at ${repo_dir} with encryption (repokey)..."
        borg init --encryption=repokey "${repo_dir}"
    fi

    mkdir -p "${repo_dir}/logs"

    cat > "${src}/.borgbackup" <<EOF
# Borg backup configuration for ${src}
SOURCE_DIR="./"
BORG_REPO="${repo_dir}"
EOF

    echo "Initialized Borg backup repository for '${src}'."
    echo "Repository is located at '${repo_dir}'."
}
