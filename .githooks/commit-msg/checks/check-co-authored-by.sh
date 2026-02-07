#!/usr/bin/env bash
# Commit-msg: reject Co-Authored-By lines.

set -euo pipefail

INPUT_FILE="$1"

if grep -q "^Co-Authored-By:" "$INPUT_FILE"; then
  echo >&2 "Commit failed: Please remove Co-Authored-By line from commit message."
  exit 1
fi
