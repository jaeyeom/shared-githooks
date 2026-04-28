#!/usr/bin/env bash
# Pre-commit: check for whitespace errors.
# Excludes files handled by language-specific formatters and files marked
# in .gitattributes as `binary`, `-text`, or `eol=crlf`. Those files
# legitimately need their existing line endings or whitespace preserved
# (HTTP fixtures, golden test data, Windows scripts, etc.).

set -euo pipefail

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  against=HEAD
else
  against=$(git hash-object -t tree /dev/null)
fi

excludes=(
  ':(exclude)*.go'
  ':(exclude)*.py'
  ':(exclude)*.proto'
  ':(exclude)*.bzl'
  ':(exclude)BUILD'
  ':(exclude)BUILD.bazel'
  ':(exclude)WORKSPACE'
)

while IFS= read -r path; do
  [ -z "$path" ] && continue
  attrs=$(git check-attr binary text eol -- "$path" 2>/dev/null || true)
  if printf '%s\n' "$attrs" | grep -Eq ': binary: set$|: text: unset$|: eol: crlf$'; then
    excludes+=(":(exclude,literal)$path")
  fi
done < <(git diff --cached --name-only --diff-filter=ACMR)

if ! git diff-index --check --cached "$against" -- "${excludes[@]}"; then
  echo >&2 "Whitespace errors detected. Commit aborted."
  exit 1
fi
