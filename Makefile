PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/borgctl
LIBEXECDIR ?= $(PREFIX)/libexec/borgctl
BASH_COMPLETIONS_DIR ?= $(PREFIX)/share/bash-completion/completions
FISH_COMPLETIONS_DIR ?= $(HOME)/.config/fish/completions

install: borgctl
	@echo "Installing borgctl..."
	install -d $(BINDIR)
	install -m 755 borgctl $(BINDIR)
	@echo "Installing libraries..."
	install -d $(LIBDIR)
	install -m 644 lib/*.sh $(LIBDIR)
	@echo "Installing command modules..."
	install -d $(LIBEXECDIR)
	install -m 644 libexec/borgctl/*.sh $(LIBEXECDIR)
	@echo "Installing Bash completions..."
	install -d $(BASH_COMPLETIONS_DIR)
	install -m 644 completions/bash/borgctl.bash $(BASH_COMPLETIONS_DIR)/borgctl
	@echo "Installing Fish completions..."
	install -d $(FISH_COMPLETIONS_DIR)
	install -m 644 completions/fish/borgctl.fish $(FISH_COMPLETIONS_DIR)/borgctl.fish
	@echo "Installation complete."

uninstall:
	@echo "Uninstalling borgctl..."
	rm -f $(BINDIR)/borgctl
	rm -rf $(LIBDIR)
	rm -rf $(LIBEXECDIR)
	rm -f $(BASH_COMPLETIONS_DIR)/borgctl
	rm -f $(FISH_COMPLETIONS_DIR)/borgctl.fish
	@echo "Uninstallation complete."

.PHONY: install uninstall
