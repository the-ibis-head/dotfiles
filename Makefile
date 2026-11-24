DOTFILES := $(CURDIR)

SHELL := /bin/bash

ESC			:= $(shell printf '\033')
MAGENTA   	:= $(ESC)[35m
GREEN     	:= $(ESC)[32m
YELLOW		:= $(ESC)[33m
CYAN    	:= $(ESC)[36m
RED      	:= $(ESC)[31m
UNDERLINE 	:= $(ESC)[4m
BOLD      	:= $(ESC)[1m
RESET		:= $(ESC)[0m
PREFIX		:= ==>

display_warn    = printf "$(YELLOW)${PREFIX}$(RESET) $(1)\n"
display_info    = printf "$(CYAN)  →$(RESET) $(1)\n"
display_success = printf "$(GREEN)  ✓$(RESET) $(1)\n"
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
			printf "    $(GREEN)%-18s$(RESET) %s\n", $$1, $$2 \
		} \
		/^##@/ { \
			printf "\n$(BOLD)  %s$(RESET)\n", substr($$0, 5) \
		}' $(MAKEFILE_LIST)
	@printf "\n"

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

.PHONY: homebrew
homebrew: ## Install homebrew and run bewfile
	@$(call display_info,Checking for Homebrew…)
	@if ! command -v brew &>/dev/null; then \
	    $(call display_info,Installing Homebrew…); \
	    /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
	    $(call display_success,Homebrew already installed); \
	fi
	@$(call display_info,Running brew bundle…)
	@brew bundle --file="$(DOTFILES)/homebrew/Brewfile"
	@$(call display_success,Homebrew bundle complete)

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
