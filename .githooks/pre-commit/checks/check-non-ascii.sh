#!/usr/bin/env bash
# Pre-commit: reject non-ASCII filenames.
# Disable with: git config hooks.allownonascii true

set -euo pipefail

allownonascii=$(git config --type=bool hooks.allownonascii 2>/dev/null || echo "false")

if [ "$allownonascii" = "true" ]; then
  exit 0
fi

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  against=HEAD
else
  against=$(git hash-object -t tree /dev/null)
fi

count=$(git diff --cached --name-only --diff-filter=A -z "$against" |
  LC_ALL=C tr -d '[ -~]\0' | wc -c)

if [ "$count" -gt 0 ]; then
  cat >&2 <<'EOF'
Error: Attempt to add a non-ASCII file name.

This can cause problems if you want to work with people on other platforms.

To be portable it is advisable to rename the file.

If you know what you are doing you can disable this check using:

  git config hooks.allownonascii true
EOF
  exit 1
fi
