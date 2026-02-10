#!/usr/bin/env bash
# Pre-commit: run checks via Makefile.
# Fails if `make check` reports issues.
#
# Skips if no Makefile or no check target.
# Uses -j for parallel execution; Makefiles with .NOTPARALLEL are handled by Make.

set -euo pipefail

if [ ! -f Makefile ]; then
  exit 0
fi

if ! grep -q '^check:' Makefile 2>/dev/null; then
  exit 0
fi

echo "Running make -j check..."
if ! make -j check; then
  echo >&2 "Check failed. Fix the reported issues, then commit again."
  exit 1
fi
