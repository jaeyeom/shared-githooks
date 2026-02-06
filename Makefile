# Shared Githooks — developer workflow
# Tools: shfmt, shellcheck, yamllint, biome
# Install: brew install shfmt shellcheck yamllint biome

SHELL := /bin/bash
.DELETE_ON_ERROR:

SHELL_FILES := $(shell find .githooks -type f -name '*.sh' 2>/dev/null)
YAML_FILES  := $(shell find .githooks -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null)
BIOME_FILES := $(shell find . -maxdepth 3 \( -name '*.md' -o -name '*.json' \) -not -path './.omc/*' -not -path './.git/*' -not -path './.claude/*' 2>/dev/null)

##@ Main targets

.PHONY: all
all: format lint ## Full local workflow

.PHONY: check
check: check-format lint ## CI-friendly checks (no mutation)

##@ Format

.PHONY: format
format: format-shell format-biome ## Format all files

.PHONY: format-shell
format-shell: ## Format shell scripts with shfmt
	@if [ -n "$(SHELL_FILES)" ]; then \
		shfmt -w -i 2 -ci -bn $(SHELL_FILES); \
	else \
		echo "No shell files found"; \
	fi

.PHONY: format-biome
format-biome: ## Format Markdown and JSON with Biome
	@if [ -n "$(BIOME_FILES)" ]; then \
		biome format --write $(BIOME_FILES); \
	else \
		echo "No Markdown/JSON files found"; \
	fi

.PHONY: check-format
check-format: check-format-shell check-format-biome ## Check all formatting (fails on diff)

.PHONY: check-format-shell
check-format-shell: ## Check shell formatting
	@if [ -n "$(SHELL_FILES)" ]; then \
		shfmt -d -i 2 -ci -bn $(SHELL_FILES); \
	else \
		echo "No shell files found"; \
	fi

.PHONY: check-format-biome
check-format-biome: ## Check Markdown and JSON formatting
	@if [ -n "$(BIOME_FILES)" ]; then \
		biome format $(BIOME_FILES); \
	else \
		echo "No Markdown/JSON files found"; \
	fi

##@ Lint

.PHONY: lint
lint: lint-shell lint-yaml ## Run all linters

.PHONY: lint-shell
lint-shell: ## Lint shell scripts with shellcheck
	@if [ -n "$(SHELL_FILES)" ]; then \
		shellcheck $(SHELL_FILES); \
	else \
		echo "No shell files found"; \
	fi

.PHONY: lint-yaml
lint-yaml: ## Lint YAML configs with yamllint
	@if [ -n "$(YAML_FILES)" ]; then \
		yamllint -d relaxed $(YAML_FILES); \
	else \
		echo "No YAML files found"; \
	fi

##@ Helpers

.PHONY: list
list: ## List discovered hook scripts and configs
	@echo "Shell scripts:"; \
	if [ -n "$(SHELL_FILES)" ]; then echo "$(SHELL_FILES)" | tr ' ' '\n'; else echo "  (none)"; fi; \
	echo ""; \
	echo "YAML configs:"; \
	if [ -n "$(YAML_FILES)" ]; then echo "$(YAML_FILES)" | tr ' ' '\n'; else echo "  (none)"; fi

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
