#!/usr/bin/env bash
# Pre-commit: scan staged changes for secrets with gitleaks.
# Disable with: git config hooks.gitleaks false
#
# Runs in every repo by default: a leaked credential is a risk anywhere, and a
# staged-only scan is fast and only looks at lines being committed. gitleaks
# picks up the repo's own .gitleaks.toml and .gitleaksignore automatically.
#
# There is no Makefile deduplication: a `make check` gitleaks target scans
# committed history and cannot see what is staged.
#
# Skips if gitleaks is not installed.

set -euo pipefail

enabled=$(git config --type=bool hooks.gitleaks 2>/dev/null || echo "true")
if [ "$enabled" != "true" ]; then
  exit 0
fi

if ! command -v gitleaks &>/dev/null; then
  echo "Warning: gitleaks not found, skipping secret scan" >&2
  echo "Install with: brew install gitleaks" >&2
  exit 0
fi

if ! gitleaks git --pre-commit --staged --redact --no-banner --verbose .; then
  echo >&2 "gitleaks found secrets in staged changes. Commit aborted."
  echo >&2 "Remove the secret (and rotate it if it was real). For a false"
  echo >&2 "positive, add its fingerprint to .gitleaksignore."
  exit 1
fi
