#!/usr/bin/env bash
# Commit-msg: reject AI-generated commit message markers.

set -euo pipefail

INPUT_FILE="$1"

if grep -q "Generated with " "$INPUT_FILE"; then
  echo >&2 "Commit failed: Please remove the generation comment from commit message."
  exit 1
fi
