#!/usr/bin/env bash
# Test: verify README.md documents every hook and vice versa.
# Catches documentation drift when hooks are added or removed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="$REPO_ROOT/README.md"
HOOKS_DIR="$REPO_ROOT/.githooks"

FAILED=0

fail() {
  echo "FAIL: $1" >&2
  FAILED=1
}

# Collect actual hook scripts from disk.
actual_pre_commit=()
for f in "$HOOKS_DIR"/pre-commit/checks/*.sh; do
  [ -f "$f" ] && actual_pre_commit+=("$(basename "$f")")
done

actual_commit_msg=()
for f in "$HOOKS_DIR"/commit-msg/checks/*.sh; do
  [ -f "$f" ] && actual_commit_msg+=("$(basename "$f")")
done

# Collect hooks documented in README tables.
# The tables use the format: | `hook-name.sh` | ...
readme_pre_commit=()
readme_commit_msg=()

in_section=""
while IFS= read -r line; do
  if [[ "$line" =~ ^###\ Pre-commit ]]; then
    in_section="pre-commit"
  elif [[ "$line" =~ ^###\ Commit-msg ]]; then
    in_section="commit-msg"
  elif [[ "$line" =~ ^## ]] && [[ ! "$line" =~ ^### ]]; then
    in_section=""
  fi

  if [[ "$in_section" == "pre-commit" ]] && [[ "$line" =~ ^\|\ \`([a-z0-9_-]+\.sh)\` ]]; then
    readme_pre_commit+=("${BASH_REMATCH[1]}")
  elif [[ "$in_section" == "commit-msg" ]] && [[ "$line" =~ ^\|\ \`([a-z0-9_-]+\.sh)\` ]]; then
    readme_commit_msg+=("${BASH_REMATCH[1]}")
  fi
done <"$README"

# Check: every actual pre-commit hook is documented.
for hook in "${actual_pre_commit[@]}"; do
  found=0
  for doc in "${readme_pre_commit[@]}"; do
    if [ "$hook" = "$doc" ]; then
      found=1
      break
    fi
  done
  if [ "$found" -eq 0 ]; then
    fail "pre-commit hook '$hook' exists on disk but is not documented in README.md"
  fi
done

# Check: every documented pre-commit hook exists on disk.
for doc in "${readme_pre_commit[@]}"; do
  if [ ! -f "$HOOKS_DIR/pre-commit/checks/$doc" ]; then
    fail "pre-commit hook '$doc' is documented in README.md but does not exist on disk"
  fi
done

# Check: every actual commit-msg hook is documented.
for hook in "${actual_commit_msg[@]}"; do
  found=0
  for doc in "${readme_commit_msg[@]}"; do
    if [ "$hook" = "$doc" ]; then
      found=1
      break
    fi
  done
  if [ "$found" -eq 0 ]; then
    fail "commit-msg hook '$hook' exists on disk but is not documented in README.md"
  fi
done

# Check: every documented commit-msg hook exists on disk.
for doc in "${readme_commit_msg[@]}"; do
  if [ ! -f "$HOOKS_DIR/commit-msg/checks/$doc" ]; then
    fail "commit-msg hook '$doc' is documented in README.md but does not exist on disk"
  fi
done

# Check: all hook scripts are executable.
for f in "$HOOKS_DIR"/pre-commit/checks/*.sh "$HOOKS_DIR"/commit-msg/checks/*.sh; do
  [ -f "$f" ] || continue
  if [ ! -x "$f" ]; then
    fail "$(basename "$f") is not executable"
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo >&2 "README hook documentation test failed."
  exit 1
fi

echo "OK: README documents all hooks and all documented hooks exist."
