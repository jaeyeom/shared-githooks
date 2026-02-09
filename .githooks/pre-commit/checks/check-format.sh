#!/usr/bin/env bash
# Pre-commit: check formatting via Makefile.
# Fails if `make check-format` reports issues. Run `make format` to fix.
#
# Skips if no Makefile or no check-format target.

set -euo pipefail

if [ ! -f Makefile ]; then
  exit 0
fi

if ! grep -q '^check-format:' Makefile 2>/dev/null; then
  exit 0
fi

echo "Running make check-format..."
if ! make check-format; then
  echo >&2 "Formatting check failed. Run 'make format' to fix, then commit again."
  exit 1
fi
