PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
BASH_COMPLETIONS_DIR ?= $(PREFIX)/share/bash-completion/completions
FISH_COMPLETIONS_DIR ?= $(HOME)/.config/fish/completions

install: borg-up rsnap
	@echo "Installing scripts..."
	install -d $(BINDIR)
	install -m 755 borg-up rsnap $(BINDIR)
	@echo "Installing Bash completions..."
	install -d $(BASH_COMPLETIONS_DIR)
	install -m 644 completions/bash/borg-up.bash $(BASH_COMPLETIONS_DIR)/borg-up
	install -m 644 completions/bash/rsnap.bash $(BASH_COMPLETIONS_DIR)/rsnap
	@echo "Installing Fish completions..."
	install -d $(FISH_COMPLETIONS_DIR)
	install -m 644 completions/fish/borg-up.fish $(FISH_COMPLETIONS_DIR)/borg-up.fish
	install -m 644 completions/fish/rsnap.fish $(FISH_COMPLETIONS_DIR)/rsnap.fish
	@echo "Installation complete."

uninstall:
	@echo "Uninstalling scripts..."
	rm -f $(BINDIR)/borg-up $(BINDIR)/rsnap
	rm -f $(BASH_COMPLETIONS_DIR)/borg-up $(BASH_COMPLETIONS_DIR)/rsnap
	rm -f $(FISH_COMPLETIONS_DIR)/borg-up.fish $(FISH_COMPLETIONS_DIR)/rsnap.fish
	@echo "Uninstallation complete."
