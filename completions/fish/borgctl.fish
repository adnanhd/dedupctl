# Fish completions for borgctl (Borg backup) script

# Subcommand completions with detailed descriptions:
complete -c borgctl -f -a "init" -d "Initialize repository: creates .borgbackup and sets up the repository (repokey encryption)."
complete -c borgctl -f -a "backup" -d "Create backup archive: archives SOURCE_DIR (relative) using lz4 compression."
complete -c borgctl -f -a "prune" -d "Purge archives: remove old archives. Options: --last, --first, --older, --newer, --all; interactive if no option."
complete -c borgctl -f -a "mount" -d "Mount archive: mount a backup archive locally (interactive if not provided)."
complete -c borgctl -f -a "extract" -d "Extract archive: extract a backup archive to a destination directory."
complete -c borgctl -f -a "check" -d "Check repository: run 'borg check' to verify repository integrity."
complete -c borgctl -f -a "log" -d "Display log: view a backup log file."
complete -c borgctl -f -a "list" -d "List archives: list all available backup archives."
complete -c borgctl -f -a "diff" -d "Diff archives: compare two archives; leave first prompt empty for current state."
complete -c borgctl -f -a "size" -d "Size: display size and info for a selected archive."

# Options for the "init" and "backup" subcommands:
complete -c borgctl -n '__fish_seen_subcommand_from init backup' -a "--dry-run" -d "Simulate actions (dry run)"
complete -c borgctl -n '__fish_seen_subcommand_from init backup' -a "--force-full" -d "Force a full backup (skip incremental linking)"
complete -c borgctl -n '__fish_seen_subcommand_from init backup' -a "--create" -d "Alias for --force-full"

# Options for the "prune" subcommand:
complete -c borgctl -n '__fish_seen_subcommand_from prune' -a "--last" -d "Remove the newest X archives"
complete -c borgctl -n '__fish_seen_subcommand_from prune' -a "--first" -d "Remove the oldest X archives"
complete -c borgctl -n '__fish_seen_subcommand_from prune' -a "--older" -d "Remove archives older than X days"
complete -c borgctl -n '__fish_seen_subcommand_from prune' -a "--newer" -d "Remove archives newer than X days"
complete -c borgctl -n '__fish_seen_subcommand_from prune' -a "--all" -d "Remove all archives"
