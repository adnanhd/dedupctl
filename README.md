# Borg-up & Rsnap

**Borg-up** and **rsnap** are two command‑line tools for managing backups using Borg and rsync, respectively. This package includes the main backup scripts along with shell completions for both Bash and Fish. With these tools you can:

- **Borg-up**  
  - Initialize a Borg backup repository with encryption (repokey)  
  - Create new backup archives (with lz4 compression)  
  - Purge old archives (with interactive or option‑based purging, including diff and size features)  
  - Mount, extract, check repository integrity, view logs, and list archives  
  - Compare (diff) archives (including an option to compare the live state against a snapshot)

- **Rsnap**  
  - Initialize a backup repository (creates a `.myrsyncbackup` file)  
  - Take new incremental snapshot backups using rsync  
  - Purge, restore, view logs, list snapshots, compare snapshots (diff), and check snapshot size (using `du -sh`)

## Features

- **Interactive and Option-Based Commands:**  
  For commands like purge and diff, you can choose between interactive mode (prompting you to select items) or pass command‑line options (e.g. `--last 3`, `--older 30`, etc.).

- **Shell Completions:**  
  Bash and Fish completions are provided so that you get auto‑completion and (in Fish) detailed descriptions.

- **Portable Installation:**  
  All scripts and completion files are packaged in this repository, and an installer (via Makefile) is provided to copy files into the proper locations (e.g. `~/.local/bin/`, `~/.local/share/bash-completion/completions/`, and `~/.config/fish/completions/`).

## Repository Structure

```
borg-rsnap/
├── README.md
├── LICENSE
├── Makefile
├── borg-up             # Borg backup script (executable)
├── rsnap               # Rsync backup script (executable)
├── completions/
│   ├── bash/
│   │   ├── borg-up.bash
│   │   └── rsnap.bash
│   └── fish/
│       ├── borg-up.fish
│       └── rsnap.fish
└── docs/               # (Optional) Documentation and examples
```

## Installation

You can install the tools and completions by running the provided Makefile. For example:

```bash
# Clone the repository
git clone https://github.com/yourusername/borg-rsnap.git
cd borg-rsnap

# Run the install target (adjust PREFIX if needed)
make install
```

This will install:

- The **borg-up** and **rsnap** scripts into `~/.local/bin/` (or your chosen PREFIX/bin)
- Bash completions into `~/.local/share/bash-completion/completions/`
- Fish completions into `~/.config/fish/completions/`

To uninstall, run:

```bash
make uninstall
```

## Usage

After installation, make sure that the installation directories are in your PATH and that your shell loads the completion files. Then you can run the tools:

### Borg-up

```bash
borg-up init /path/to/your/project
borg-up backup [--dry-run] [--force-full]
borg-up prune --last 3      # (or --first, --older, --newer, --all)
borg-up mount [<mount_point>] [<archive>]
borg-up extract [<destination>] [<archive>]
borg-up diff                # Press Enter on first prompt to use current state
borg-up size
borg-up check
borg-up log
borg-up list
```

### Rsnap

```bash
rsnap init /path/to/your/project
rsnap snapshot [--dry-run] [--force-full]
rsnap prune --older 30      # (or --last, --first, --newer, --all; interactive mode if no option)
rsnap restore [<snapshot>]
rsnap log
rsnap list
rsnap diff                # First prompt: press Enter for live state; second: choose a snapshot
rsnap size
```

## Packaging Other Tools

Yes—you can use similar techniques to package and distribute other user‑level tools and services (such as syncing utilities or custom user services). Many users organize their personal scripts, dotfiles, and systemd user services (or similar) in a Git repository and use tools like **GNU Stow**, **Makefiles**, or dedicated installer scripts to install files in the correct locations. You can also create Debian or RPM packages if you wish to integrate your tools with your system’s package manager.

By wrapping your scripts, completion files, and configuration files in one repository and providing an installer, you create a portable “module” that can be installed on any machine.

## Contributing

Contributions, suggestions, and bug reports are welcome! Please submit issues and pull requests via GitHub.

## License

This project is licensed under the [MIT License](LICENSE).
