#!/usr/bin/env bash
# Pre-commit: run shellcheck on staged shell scripts.
# Skips if shellcheck is not installed.
# Skips if the Makefile check target already runs shellcheck.

set -euo pipefail

if [ -f Makefile ] \
  && grep -q '^check:' Makefile 2>/dev/null \
  && grep -q 'shellcheck' Makefile 2>/dev/null; then
  echo "Skipping standalone shell lint: Makefile has check target and mentions shellcheck"
  exit 0
fi

if ! command -v shellcheck &>/dev/null; then
  echo "Warning: shellcheck not found, skipping shell lint" >&2
  exit 0
fi

SH_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$' || true)

if [ -z "$SH_FILES" ]; then
  exit 0
fi

echo "Running shell lint..."
if ! echo "$SH_FILES" | xargs shellcheck; then
  echo >&2 "Shell lint failed. Commit aborted."
  exit 1
fi
