#!/usr/bin/env bash
# Pre-commit: reject staged files that exceed a size threshold.
# Default limit is 1 MB; override with: git config hooks.maxfilesize <bytes>

set -euo pipefail

DEFAULT_MAX_SIZE=1048576 # 1 MB

MAX_SIZE=$(git config --int hooks.maxfilesize 2>/dev/null || echo "$DEFAULT_MAX_SIZE")

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

human_size() {
  local bytes=$1
  if [ "$bytes" -ge 1073741824 ]; then
    echo "$((bytes / 1073741824)) GB"
  elif [ "$bytes" -ge 1048576 ]; then
    echo "$((bytes / 1048576)) MB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$((bytes / 1024)) KB"
  else
    echo "${bytes} bytes"
  fi
}

FAILED=0

while IFS= read -r file; do
  [ -z "$file" ] && continue
  if ! size=$(git cat-file -s ":${file}" 2>/dev/null); then
    continue
  fi
  if [ "$size" -gt "$MAX_SIZE" ]; then
    echo >&2 "  ${file} ($(human_size "$size") exceeds $(human_size "$MAX_SIZE") limit)"
    FAILED=1
  fi
done <<<"$STAGED_FILES"

if [ "$FAILED" -ne 0 ]; then
  cat >&2 <<'EOF'

Large file check failed. Commit aborted.

To increase the limit, run:

  git config hooks.maxfilesize <bytes>
EOF
  exit 1
fi
