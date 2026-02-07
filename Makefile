PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/dedupctl
LIBEXECDIR ?= $(PREFIX)/libexec/dedupctl
BASH_COMPLETIONS_DIR ?= $(PREFIX)/share/bash-completion/completions
FISH_COMPLETIONS_DIR ?= $(HOME)/.config/fish/completions

install: dedupctl
	@echo "Installing dedupctl..."
	install -d $(BINDIR)
	install -m 755 dedupctl $(BINDIR)
	@echo "Installing libraries..."
	install -d $(LIBDIR)
	install -m 644 lib/*.sh $(LIBDIR)
	@echo "Installing command modules..."
	install -d $(LIBEXECDIR)
	install -m 644 libexec/dedupctl/*.sh $(LIBEXECDIR)
	@echo "Installing Bash completions..."
	install -d $(BASH_COMPLETIONS_DIR)
	install -m 644 completions/bash/dedupctl.bash $(BASH_COMPLETIONS_DIR)/dedupctl
	@echo "Installing Fish completions..."
	install -d $(FISH_COMPLETIONS_DIR)
	install -m 644 completions/fish/dedupctl.fish $(FISH_COMPLETIONS_DIR)/dedupctl.fish
	@echo "Installation complete."

uninstall:
	@echo "Uninstalling dedupctl..."
	rm -f $(BINDIR)/dedupctl
	rm -rf $(LIBDIR)
	rm -rf $(LIBEXECDIR)
	rm -f $(BASH_COMPLETIONS_DIR)/dedupctl
	rm -f $(FISH_COMPLETIONS_DIR)/dedupctl.fish
	@echo "Uninstallation complete."

.PHONY: install uninstall
