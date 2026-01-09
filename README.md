# Borg-up & Rsnap

**Borg-up** and **rsnap** are two command-line tools for managing backups using Borg and rsync, respectively. This package includes the main backup scripts along with shell completions for both Bash and Fish.

## Features

### Borg-up (BorgBackup)
- Initialize a Borg backup repository with encryption (repokey)
- Create new backup archives (with lz4 compression and exclude support)
- Prune old archives (interactive or option-based: `--last`, `--first`, `--older`, `--newer`, `--all`)
- Mount, extract, and check repository integrity
- Compare (diff) archives (including live state vs snapshot)
- View logs and list archives

### Rsnap (rsync)
- Initialize a backup repository (creates a `.myrsyncbackup` file)
- Take incremental snapshot backups using rsync with hard-linking
- Prune snapshots (interactive or option-based)
- Restore snapshots with optional `--delete` and `--exclude` flags
- Compare snapshots (diff) including live state comparison
- Check snapshot integrity (broken symlinks, readability)
- View logs and list snapshots

## Repository Structure

```
borg-rsnap/
├── README.md
├── LICENSE
├── Makefile
├── borg-up                    # Main Borg backup script
├── rsnap                      # Main rsync backup script
├── lib/
│   ├── common.sh              # Shared utilities
│   └── prune.sh               # Shared prune logic
├── libexec/
│   ├── borg-up/               # Borg command modules
│   │   ├── init.sh
│   │   ├── backup.sh
│   │   ├── prune.sh
│   │   ├── mount.sh
│   │   ├── extract.sh
│   │   ├── check.sh
│   │   ├── diff.sh
│   │   ├── size.sh
│   │   ├── log.sh
│   │   └── list.sh
│   └── rsnap/                 # rsync command modules
│       ├── init.sh
│       ├── snapshot.sh
│       ├── prune.sh
│       ├── restore.sh
│       ├── check.sh
│       ├── diff.sh
│       ├── size.sh
│       ├── log.sh
│       └── list.sh
└── completions/
    ├── bash/
    │   ├── borg-up.bash
    │   └── rsnap.bash
    └── fish/
        ├── borg-up.fish
        └── rsnap.fish
```

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yourusername/borg-rsnap.git
cd borg-rsnap

# Install to ~/.local (default)
make install
```

### Custom Install Location

```bash
# Install to a custom prefix
make PREFIX=/usr/local install

# Or install to a specific directory
make PREFIX=$HOME/tools install
```

### What Gets Installed

| Component | Default Location |
|-----------|------------------|
| Scripts (`borg-up`, `rsnap`) | `~/.local/bin/` |
| Libraries (`lib/*.sh`) | `~/.local/lib/borg-rsnap/` |
| Command modules (`libexec/`) | `~/.local/libexec/borg-rsnap/` |
| Bash completions | `~/.local/share/bash-completion/completions/` |
| Fish completions | `~/.config/fish/completions/` |

### Uninstall

```bash
make uninstall
```

### PATH Setup

Make sure `~/.local/bin` is in your PATH. Add this to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

For Fish, add to `~/.config/fish/config.fish`:

```fish
set -gx PATH $HOME/.local/bin $PATH
```

## Usage

### Borg-up

```bash
# Initialize a backup repository
borg-up init /path/to/your/project

# Create a backup
borg-up backup [--dry-run] [--force-full]

# Prune old archives
borg-up prune                 # Interactive mode
borg-up prune --last 3        # Remove newest 3
borg-up prune --first 3       # Remove oldest 3
borg-up prune --older 30      # Remove older than 30 days
borg-up prune --newer 7       # Remove newer than 7 days
borg-up prune --all           # Remove all

# Mount an archive
borg-up mount [<mount_point>] [<archive>]

# Extract an archive
borg-up extract [<destination>] [<archive>]

# Compare archives
borg-up diff                  # Press Enter for current state vs archive

# Other commands
borg-up check                 # Verify repository integrity
borg-up size                  # Show archive size info
borg-up log                   # View backup logs
borg-up list                  # List all archives
```

### Rsnap

```bash
# Initialize a backup repository
rsnap init /path/to/your/project

# Create a snapshot
rsnap snapshot [--dry-run] [--force-full]

# Prune old snapshots
rsnap prune                   # Interactive mode
rsnap prune --last 3          # Remove newest 3
rsnap prune --first 3         # Remove oldest 3
rsnap prune --older 30        # Remove older than 30 days
rsnap prune --all             # Remove all

# Restore a snapshot
rsnap restore                           # Interactive selection
rsnap restore 2024-01-15_10:30:00       # Specific snapshot
rsnap restore --delete                  # Delete files not in snapshot (dangerous!)
rsnap restore --exclude=.git            # Exclude patterns

# Compare snapshots
rsnap diff                    # Press Enter for current state vs snapshot

# Other commands
rsnap check                   # Verify snapshot integrity
rsnap size                    # Show snapshot size
rsnap log                     # View backup logs
rsnap list                    # List all snapshots
```

## Configuration

### Borg-up

Configuration is stored in `.borgbackup` in your project root:

```bash
SOURCE_DIR="./"
BORG_REPO="/path/to/borg/repository"
# Optional: EXCLUDES=(".cache" "node_modules" "*.log")
```

### Rsnap

Configuration is stored in `.myrsyncbackup` in your project root:

```bash
SOURCE_DIR="./"
BACKUP_DIR="/path/to/rsync/backups"
# Optional: EXCLUDES=(".cache" "node_modules" "*.log")
```

### Default Excludes

Both tools exclude by default:
- `.cache`
- `tmp`
- `__pycache__`

Override by defining `EXCLUDES` array in your config file.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BORG_BACKUP_ROOT` | `~/.borg_backups` | Root directory for Borg repositories |
| `RSYNC_BACKUP_ROOT` | `~/.rsync_backups` | Root directory for rsync snapshots |

## Contributing

Contributions, suggestions, and bug reports are welcome! Please submit issues and pull requests via GitHub.

## License

This project is licensed under the [MIT License](LICENSE).
