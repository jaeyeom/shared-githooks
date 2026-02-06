#!/usr/bin/env bash
# Pre-commit: run org-lint on staged .org files.
# Skips if org-lint is not installed.

set -euo pipefail

if ! command -v org-lint &>/dev/null; then
  exit 0
fi

ORG_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.org$' || true)

if [ -z "$ORG_FILES" ]; then
  exit 0
fi

echo "Running org-mode checks on .org files..."
if ! echo "$ORG_FILES" | xargs org-lint; then
  echo >&2 "Org-mode checks failed. Commit aborted."
  exit 1
fi
