#!/usr/bin/env bash
# Pre-commit: flag outdated GitHub Actions in staged workflow files.
# Disable with: git config hooks.checkactions false
#
# Checks two things:
#   1. uses: owner/repo@vN  -> N must be >= a hardcoded floor for known actions
#   2. golangci/golangci-lint-action steps must not pin a v1.x linter binary
#      via the `version:` input (golangci-lint v2 introduced breaking changes;
#      v1 keeps slipping into freshly generated workflows).
#
# SHA-pinned and branch-pinned `uses:` references are intentionally ignored
# (they're a deliberate choice; we can't verify them by major number alone).

set -euo pipefail

enabled=$(git config --type=bool hooks.checkactions 2>/dev/null || echo "true")
if [ "$enabled" != "true" ]; then
  exit 0
fi

STAGED=$(git diff --cached --name-only --diff-filter=ACMR \
  | grep -E '^\.github/workflows/.*\.ya?ml$' || true)

if [ -z "$STAGED" ]; then
  exit 0
fi

declare -A MIN_MAJOR=(
  ["actions/checkout"]=4
  ["actions/setup-go"]=5
  ["actions/setup-node"]=4
  ["actions/setup-python"]=5
  ["actions/setup-java"]=4
  ["actions/setup-dotnet"]=4
  ["actions/cache"]=4
  ["actions/upload-artifact"]=4
  ["actions/download-artifact"]=4
  ["actions/configure-pages"]=5
  ["actions/deploy-pages"]=4
  ["actions/upload-pages-artifact"]=3
  ["golangci/golangci-lint-action"]=6
  ["docker/build-push-action"]=6
  ["docker/login-action"]=3
  ["docker/setup-buildx-action"]=3
  ["docker/setup-qemu-action"]=3
  ["docker/metadata-action"]=5
  ["codecov/codecov-action"]=4
  ["softprops/action-gh-release"]=2
  ["github/codeql-action"]=3
)

GOLANGCI_LINT_MIN_MAJOR=2

uses_re='uses:[[:space:]]*["'\'']?([a-zA-Z0-9_./-]+)@v([0-9]+)'
version_re='^[[:space:]]*version:[[:space:]]*["'\'']?v([0-9]+)'
step_boundary_re='^[[:space:]]*-([[:space:]]|$)'
golangci_re='uses:[[:space:]]*["'\'']?golangci/golangci-lint-action@'

FAILED=0

fail() {
  echo >&2 "  $1"
  FAILED=1
}

while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || continue

  in_golangci=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ $step_boundary_re ]]; then
      in_golangci=0
    fi

    if [[ "$line" =~ $uses_re ]]; then
      action="${BASH_REMATCH[1]}"
      major="${BASH_REMATCH[2]}"
      min="${MIN_MAJOR[$action]:-}"
      if [ -n "$min" ] && [ "$major" -lt "$min" ]; then
        fail "$file: $action@v$major is below minimum v$min"
      fi
    fi

    if [[ "$line" =~ $golangci_re ]]; then
      in_golangci=1
    fi

    if [ "$in_golangci" = "1" ] && [[ "$line" =~ $version_re ]]; then
      ver="${BASH_REMATCH[1]}"
      if [ "$ver" -lt "$GOLANGCI_LINT_MIN_MAJOR" ]; then
        fail "$file: golangci-lint v$ver is below minimum v$GOLANGCI_LINT_MIN_MAJOR (set via golangci-lint-action 'version:' input)"
      fi
    fi
  done <"$file"
done <<<"$STAGED"

if [ "$FAILED" -ne 0 ]; then
  cat >&2 <<'EOF'

Outdated GitHub Actions detected. Commit aborted.

Bump each flagged action to at least the minimum major version listed above.
SHA-pinned and branch-pinned `uses:` references are not checked.

To disable this check, run:

  git config hooks.checkactions false
EOF
  exit 1
fi
