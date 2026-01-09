PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/borg-rsnap
LIBEXECDIR ?= $(PREFIX)/libexec/borg-rsnap
BASH_COMPLETIONS_DIR ?= $(PREFIX)/share/bash-completion/completions
FISH_COMPLETIONS_DIR ?= $(HOME)/.config/fish/completions

install: borg-up rsnap
	@echo "Installing scripts..."
	install -d $(BINDIR)
	install -m 755 borg-up rsnap $(BINDIR)
	@echo "Installing libraries..."
	install -d $(LIBDIR)
	install -m 644 lib/*.sh $(LIBDIR)
	@echo "Installing command modules..."
	install -d $(LIBEXECDIR)/borg-up
	install -d $(LIBEXECDIR)/rsnap
	install -m 644 libexec/borg-up/*.sh $(LIBEXECDIR)/borg-up
	install -m 644 libexec/rsnap/*.sh $(LIBEXECDIR)/rsnap
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
	rm -rf $(LIBDIR)
	rm -rf $(LIBEXECDIR)
	rm -f $(BASH_COMPLETIONS_DIR)/borg-up $(BASH_COMPLETIONS_DIR)/rsnap
	rm -f $(FISH_COMPLETIONS_DIR)/borg-up.fish $(FISH_COMPLETIONS_DIR)/rsnap.fish
	@echo "Uninstallation complete."

.PHONY: install uninstall
