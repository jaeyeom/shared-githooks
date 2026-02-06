#!/usr/bin/env bash
# Pre-commit: check for whitespace errors.
# Excludes files handled by language-specific formatters.

set -euo pipefail

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  against=HEAD
else
  against=$(git hash-object -t tree /dev/null)
fi

if ! git diff-index --check --cached "$against" -- \
  ':(exclude)*.go' \
  ':(exclude)*.py' \
  ':(exclude)*.proto' \
  ':(exclude)*.bzl' \
  ':(exclude)BUILD' \
  ':(exclude)BUILD.bazel' \
  ':(exclude)WORKSPACE'; then
  echo >&2 "Whitespace errors detected. Commit aborted."
  exit 1
fi
