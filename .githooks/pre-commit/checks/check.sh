#!/usr/bin/env bash
# Pre-commit: run checks via Makefile.
# Fails if `make check` reports issues.
#
# Skips if no Makefile or no check target.
# Uses parallel execution (-j) unless the Makefile declares .NOTPARALLEL.

set -euo pipefail

if [ ! -f Makefile ]; then
  exit 0
fi

if ! grep -q '^check:' Makefile 2>/dev/null; then
  exit 0
fi

make_args=()
if ! grep -q '^\.NOTPARALLEL' Makefile 2>/dev/null; then
  make_args+=("-j")
fi

echo "Running make ${make_args[*]} check..."
if ! make "${make_args[@]}" check; then
  echo >&2 "Check failed. Fix the reported issues, then commit again."
  exit 1
fi
