#!/usr/bin/env bash
# Pre-commit: run semgrep scan on projects with semgrep configuration.
# Skips if no semgrep config found (.semgrep.yml, .semgrep.yaml, or .semgrep/ directory).
# Skips if the Makefile check target already runs semgrep.
# Skips if semgrep is not installed.

set -euo pipefail

if [ ! -f .semgrep.yml ] \
  && [ ! -f .semgrep.yaml ] \
  && [ ! -d .semgrep ]; then
  exit 0
fi

if [ -f Makefile ] \
  && grep -q '^check:' Makefile 2>/dev/null \
  && grep -q 'semgrep' Makefile 2>/dev/null; then
  echo "Skipping standalone semgrep scan: Makefile has check target and mentions semgrep"
  exit 0
fi

if ! command -v semgrep &>/dev/null; then
  echo "Warning: semgrep not found, skipping semgrep scan" >&2
  exit 0
fi

echo "Running semgrep scan..."
if ! semgrep scan --error --quiet .; then
  echo >&2 "Semgrep scan found issues. Commit aborted."
  exit 1
fi
