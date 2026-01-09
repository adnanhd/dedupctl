# borg-up init command
# Initialize a Borg backup repository

run() {
    local src
    if [ $# -gt 0 ] && [ -d "$1" ]; then
        src=$(realpath "$1")
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
