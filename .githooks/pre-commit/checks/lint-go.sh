#!/usr/bin/env bash
# Pre-commit: run golangci-lint on Go projects.
# Skips if no .golangci.yml or golangci-lint is not installed.

set -euo pipefail

if [ ! -f .golangci.yml ]; then
  exit 0
fi

if ! command -v golangci-lint &>/dev/null; then
  echo "Warning: golangci-lint not found, skipping Go lint" >&2
  exit 0
fi

echo "Running Go lint..."
unset GOPACKAGESDRIVER
if ! golangci-lint run ./...; then
  echo >&2 "Go lint failed. Commit aborted."
  exit 1
fi
