#!/usr/bin/env bash
# Commit-msg: enforce subject line ≤ 72 characters.

set -euo pipefail

INPUT_FILE="$1"

FIRST_LINE_LENGTH=$(head -n1 "$INPUT_FILE" | wc -c)
if [ "$FIRST_LINE_LENGTH" -gt 73 ]; then
  echo >&2 "Commit failed: The first line of the commit message must be ≤ 72 characters."
  exit 1
fi
