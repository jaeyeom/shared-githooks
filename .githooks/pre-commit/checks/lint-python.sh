#!/usr/bin/env bash
# Pre-commit: run ruff lint and format check on Python projects.
# Skips if no ruff config found (ruff.toml, .ruff.toml, or [tool.ruff] in pyproject.toml).
# Skips if the Makefile check target already runs ruff.
# Skips if a Bazel project manages ruff via @multitool//tools/ruff.

set -euo pipefail

if [ ! -f ruff.toml ] && [ ! -f .ruff.toml ]; then
  if [ ! -f pyproject.toml ] \
    || ! grep -q '\[tool\.ruff\]' pyproject.toml 2>/dev/null; then
    exit 0
  fi
fi

if [ -f Makefile ] \
  && grep -q '^check:' Makefile 2>/dev/null \
  && grep -q 'ruff' Makefile 2>/dev/null; then
  echo "Skipping standalone Python lint: Makefile has check target and mentions ruff"
  exit 0
fi

if { [ -f BUILD ] || [ -f BUILD.bazel ]; } \
  && grep -rq '@multitool//tools/ruff' \
    --include='BUILD' --include='BUILD.bazel' \
    --include='*.bzl' --include='MODULE.bazel' \
    --include='WORKSPACE' --include='WORKSPACE.bazel' \
    . 2>/dev/null; then
  echo "Skipping standalone Python lint: Bazel project manages ruff via @multitool"
  exit 0
fi

if ! command -v ruff &>/dev/null; then
  echo "Warning: ruff not found, skipping Python lint" >&2
  exit 0
fi

echo "Running Python lint..."
if ! ruff check .; then
  echo >&2 "Python lint failed. Commit aborted."
  exit 1
fi

echo "Running Python format check..."
if ! ruff format --check .; then
  echo >&2 "Python format check failed. Commit aborted."
  exit 1
fi
