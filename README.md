# dedupctl

A command-line tool for managing [BorgBackup](https://www.borgbackup.org/) repositories with encryption, compression, and incremental archives.

## Features

- Initialize a Borg backup repository with encryption (repokey)
- Create new backup archives (with lz4 compression and exclude support)
- Prune old archives (interactive or option-based: `--last`, `--first`, `--older`, `--newer`, `--all`)
- Mount, extract, and check repository integrity
- Compare (diff) archives (including live state vs snapshot)
- View logs and list archives

## Repository Structure

```
dedupctl/
├── dedupctl                    # Main script
├── lib/                       # Shared libraries (git submodule)
│   ├── common.sh
│   └── prune.sh
├── libexec/dedupctl/           # Command modules
│   ├── init.sh
│   ├── backup.sh
│   ├── prune.sh
│   ├── mount.sh
│   ├── extract.sh
│   ├── check.sh
│   ├── diff.sh
│   ├── size.sh
│   ├── log.sh
│   └── list.sh
├── completions/
│   ├── bash/dedupctl.bash
│   └── fish/dedupctl.fish
├── Makefile
└── README.md
```

## Installation

```bash
git clone --recurse-submodules git@github.com:adnanhd/dedupctl.git
cd dedupctl
make install
```

### Custom Install Location

```bash
make PREFIX=/usr/local install
```

### What Gets Installed

| Component | Default Location |
|-----------|------------------|
| Script (`dedupctl`) | `~/.local/bin/` |
| Libraries (`lib/*.sh`) | `~/.local/lib/dedupctl/` |
| Command modules (`libexec/`) | `~/.local/libexec/dedupctl/` |
| Bash completions | `~/.local/share/bash-completion/completions/` |
| Fish completions | `~/.config/fish/completions/` |

### Uninstall

```bash
make uninstall
```

## Usage

```bash
# Initialize a backup repository
dedupctl init /path/to/your/project

# Create a backup
dedupctl backup [--dry-run] [--force-full]

# Prune old archives
dedupctl prune                 # Interactive mode
dedupctl prune --last 3        # Remove newest 3
dedupctl prune --first 3       # Remove oldest 3
dedupctl prune --older 30      # Remove older than 30 days
dedupctl prune --newer 7       # Remove newer than 7 days
dedupctl prune --all           # Remove all

# Mount an archive
dedupctl mount [<mount_point>] [<archive>]

# Extract an archive
dedupctl extract [<destination>] [<archive>]

# Compare archives
dedupctl diff                  # Press Enter for current state vs archive

# Other commands
dedupctl check                 # Verify repository integrity
dedupctl size                  # Show archive size info
dedupctl log                   # View backup logs
dedupctl list                  # List all archives
```

## Configuration

Configuration is stored in `.borgbackup` in your project root:

```bash
SOURCE_DIR="./"
BORG_REPO="/path/to/borg/repository"
# Optional: EXCLUDES=(".cache" "node_modules" "*.log")
```

### Default Excludes

By default, the following are excluded:
- `.cache`
- `tmp`
- `__pycache__`

Override by defining an `EXCLUDES` array in your config file.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BORG_BACKUP_ROOT` | `~/.borg_backups` | Root directory for Borg repositories |

## License

This project is licensed under the [MIT License](LICENSE).
