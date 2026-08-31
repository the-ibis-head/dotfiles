DOTFILES := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ESC		 		:= $(shell printf '\033')
RESET	   		:= $(ESC)[0m
GREEN	   		:= $(ESC)[32m
MAGENTA	 		:= $(ESC)[35m
BLUE 			:= $(ESC)[34m
RED		 		:= $(ESC)[31m
BOLD			:= $(ESC)[1m
UNDERLINE		:= $(ESC)[4m
PREFIX			:= ==>

display_info	= printf "$(BLUE)${PREFIX}$(RESET) $(1)\n"
display_success = printf "$(GREEN)${PREFIX}$(RESET) $(1)\n"
display_error   = printf "$(RED)${PREFIX}$(RESET) $(1)\n"

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help screen
	@clear 2>/dev/null || true
	@printf "\n"
	@command -v figlet >/dev/null 2>&1 && figlet -f slant thothprocess || true
	@printf "\n$(BOLD)$(MAGENTA)  dotfiles$(RESET) — macOS Setup\n\n"
	@printf "  Usage: make $(GREEN)<target>$(RESET)\n\n"
	@printf "  $(UNDERLINE)$(BOLD)Targets$(RESET)\n\n"
	@awk 'BEGIN {FS = ":.*##"} \
		/^[a-zA-Z_\-]+:.*##/ { \
			printf "    $(GREEN)%-10s$(RESET) %s\n", $$1, $$2 \
		} \
		/^##@/ { \
			printf "\n$(BOLD)  %s$(RESET)\n", substr($$0, 5) \
		}' $(MAKEFILE_LIST)
	@printf "\n"

.PHONY: all
all: homebrew defaults ohmyzsh starship zsh duti git vscode ## Run recommended setup

.PHONY: homebrew
homebrew: ## Install homebrew and run bewfile
	@$(call display_info,Checking for Homebrew…)
	@if ! command -v brew &>/dev/null; then \
		$(call display_info,Installing Homebrew…); \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
		eval "$$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true; \
	else \
		$(call display_success,Homebrew already installed); \
	fi
	@$(call display_info,Running brew bundle…)
	@[ -f "$(DOTFILES)/homebrew/Brewfile" ] || { $(call display_error,Brewfile not found at $(DOTFILES)/homebrew/Brewfile); exit 1; }
	@brew bundle --file="$(DOTFILES)/homebrew/Brewfile"
	@$(call display_success,Homebrew bundle complete)

.PHONY: defaults
defaults: ## Apply macos defaults
	@$(call display_info,Applying macOS defaults...)
	@if [ ! -f "$(DOTFILES)/macos/defaults.txt" ]; then \
		$(call display_error,Missing $(DOTFILES)/macos/defaults.txt); \
		exit 1; \
	fi
	@grep -vE '^[[:space:]]*#|^[[:space:]]*$$' "$(DOTFILES)/macos/defaults.txt" | \
	while IFS= read -r cmd; do \
		$(call display_info,$$cmd); \
		eval "$$cmd"; \
	done
	@$(call display_success,macOS defaults applied)
	@$(call display_info,Restarting affected services...)
	@killall Finder 2>/dev/null || true
	@killall Dock 2>/dev/null || true
	@killall SystemUIServer 2>/dev/null || true
	@$(call display_success,macOS services restarted)

.PHONY: ohmyzsh
ohmyzsh: ## Install ohmyzsh
	@if [ ! -d "$$HOME/.oh-my-zsh" ]; then \
		$(call display_info,"Installing Oh My Zsh...") \
		sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
	else \
		$(call display_info,"Oh My Zsh is already installed."); \
	fi

.PHONY: starship
starship: ## Configure starship prompt
	@mkdir -p "$$(dirname "$(STARSHIP_DEST)")"
	@if [ ! -f "$(STARSHIP_DEST)" ]; then \
		$(call display_info,"Linking starship configuration..."); \
		ln -s "$(STARSHIP_SRC)" "$(STARSHIP_DEST)"; \
	else \
		$(call display_info,"Starship configuration already exists. Skipping."); \
	fi

.PHONY: zsh
zsh: ## Configure zsh
	@if [ ! -f "$(ZSHRC_DEST)" ]; then \
		$(call display_info,"Linking zsh configuration..."); \
		ln -s "$(ZSHRC_SRC)" "$(ZSHRC_DEST)"; \
	else \
		$(call display_info," Zsh configuration already exists. Skipping."); \
	fi

.PHONY: duti
duti: ## Apply duti file associations
	@$(call display_info,Applying file associations...)
	@if ! command -v duti >/dev/null 2>&1; then \
		$(call display_error,duti is not installed. Run 'make homebrew' first); \
		exit 1; \
	fi
	@if [ ! -f "$(DOTFILES)/duti/formats.txt" ]; then \
		$(call display_error,Missing $(DOTFILES)/duti/formats.txt); \
		exit 1; \
	fi
	@grep -vE '^\s*#|^\s*$$' "$(DOTFILES)/duti/formats.txt" | \
	while read -r bundle_id extension role; do \
		$(call display_info,Setting $$extension → $$bundle_id ($$role)); \
		duti -s "$$bundle_id" "$$extension" "$$role"; \
	done
	@$(call display_success,File associations applied)

.PHONY: git
git: ## Configure git
	@$(call display_info,Linking git config…)
	@[ -f "$(DOTFILES)/git/config" ] || { \
		$(call display_error,Missing $(DOTFILES)/git/config); \
		exit 1; \
	}
	@[ -f "$(DOTFILES)/git/ignore" ] || { \
		$(call display_error,Missing $(DOTFILES)/git/ignore); \
		exit 1; \
	}
	@ln -sf "$(DOTFILES)/git/config" "$(HOME)/.gitconfig"
	@ln -sf "$(DOTFILES)/git/ignore" "$(HOME)/.gitignore_global"
	@git config --global core.excludesfile "$(HOME)/.gitignore_global"
	@$(call display_success,git config + ignore linked)

.PHONY: vscode
vscode: ## Configure vscode
	@$(call display_info,Configuring Visual Studio Code...)
	@if [ ! -d "/Applications/Visual Studio Code.app" ] && \
	   [ ! -d "$$HOME/Applications/Visual Studio Code.app" ]; then \
		$(call display_error,Visual Studio Code is not installed); \
		exit 1; \
	fi
	@if ! command -v code >/dev/null 2>&1; then \
		$(call display_error,VS Code CLI not found); \
		echo ""; \
		echo "Open VS Code and run:"; \
		echo "  Shell Command: Install 'code' command in PATH"; \
		exit 1; \
	fi
	@if [ ! -f "$(DOTFILES)/vscode/settings.json" ]; then \
		$(call display_error,Missing $(DOTFILES)/vscode/settings.json); \
		exit 1; \
	fi
	@if [ ! -f "$(DOTFILES)/vscode/keybindings.json" ]; then \
		$(call display_error,Missing $(DOTFILES)/vscode/keybindings.json); \
		exit 1; \
	fi
	@if [ ! -f "$(DOTFILES)/vscode/extensions.txt" ]; then \
		$(call display_error,Missing $(DOTFILES)/vscode/extensions.txt); \
		exit 1; \
	fi
	@echo ""
	@echo "The following files will be installed:"
	@echo "  settings.json"
	@echo "  keybindings.json"
	@echo "  extensions.txt"
	@echo ""
	@read -p "Continue? [y/N] " confirm; \
	case "$$confirm" in \
		y|Y|yes|YES) ;; \
		*) echo "Cancelled."; exit 0 ;; \
	esac
	@mkdir -p "$$HOME/Library/Application Support/Code/User"
	@if [ -f "$$HOME/Library/Application Support/Code/User/settings.json" ]; then \
		cp "$$HOME/Library/Application Support/Code/User/settings.json" \
		   "$$HOME/Library/Application Support/Code/User/settings.json.bak"; \
	fi
	@if [ -f "$$HOME/Library/Application Support/Code/User/keybindings.json" ]; then \
		cp "$$HOME/Library/Application Support/Code/User/keybindings.json" \
		   "$$HOME/Library/Application Support/Code/User/keybindings.json.bak"; \
	fi
	@cp "$(DOTFILES)/vscode/settings.json" \
		"$$HOME/Library/Application Support/Code/User/settings.json"
	@cp "$(DOTFILES)/vscode/keybindings.json" \
		"$$HOME/Library/Application Support/Code/User/keybindings.json"
	@$(call display_success,VS Code settings copied)
	@$(call display_info,Installing extensions...)
	@grep -vE '^[[:space:]]*#|^[[:space:]]*$$' \
		"$(DOTFILES)/vscode/extensions.txt" | \
	while IFS= read -r extension; do \
		echo "Installing $$extension"; \
		code --install-extension "$$extension" --force; \
	done
	@$(call display_success,VS Code extensions installed)
