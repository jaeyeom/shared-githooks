# Development Guide

This document explains how to add new hooks or modify existing hooks in
shared-githooks.

## Development Environment Setup

### Installing Required Tools

```bash
brew install shfmt shellcheck yamllint biome
```

| Tool | Purpose |
|------|---------|
| shfmt | Shell script formatting |
| shellcheck | Shell script static analysis |
| yamllint | YAML file linting |
| biome | Markdown and JSON formatting |

### Makefile Targets

```bash
make            # format + lint (local development)
make check      # CI-friendly checks (no file mutations)
make format     # Format all files
make lint       # Run all linters
make list       # List discovered hook scripts
make help       # Show available targets
```

## Adding a Hook

### 1. Create the Directory

Create a directory under `.githooks/` named after a supported Git hook event:

```bash
mkdir -p .githooks/pre-commit/checks
```

### 2. Write the Script

```bash
#!/usr/bin/env bash
# Pre-commit: [description of what the hook does].
# [description of skip conditions].

set -euo pipefail

# Check for dependencies — silently skip if missing
if ! command -v my-tool &>/dev/null; then
  exit 0
fi

# Main logic
echo "Running my check..."
if ! my-tool check; then
  echo >&2 "Check failed. Fix the reported issues, then commit again."
  exit 1
fi
```

### 3. Make It Executable

```bash
chmod +x .githooks/pre-commit/checks/my-check.sh
```

### 4. Test

```bash
# Run directly
.githooks/pre-commit/checks/my-check.sh

# Run via Githooks
git hooks exec ns:jaeyeom-shared-githooks/pre-commit/checks/my-check.sh
```

## Hook Writing Conventions

### Requirements

- Use `#!/usr/bin/env bash` shebang (cross-platform compatibility)
- Use `set -euo pipefail` — strict error handling
- Document the purpose and skip conditions in comments at the top
- Grant execute permission (`chmod +x`)

### Graceful Degradation

All hooks must **skip without failing** when dependencies are missing:

```bash
# Silently skip if tool is not available
if ! command -v my-tool &>/dev/null; then
  exit 0
fi
```

To print a warning message:

```bash
if ! command -v my-tool &>/dev/null; then
  echo "Warning: my-tool not found, skipping check" >&2
  exit 0
fi
```

### Deduplication

When the Makefile `check` target already runs the same tool, prevent the hook
from running it again:

```bash
if [ -f Makefile ] \
  && grep -q '^check:' Makefile 2>/dev/null \
  && grep -q 'my-tool' Makefile 2>/dev/null; then
  echo "Skipping standalone check: Makefile has check target and mentions my-tool"
  exit 0
fi
```

### Error Messages

On failure, print clear error messages to stderr:

```bash
echo >&2 "Check failed. Fix the reported issues, then commit again."
exit 1
```

## Directory Structure Rules

```
.githooks/<hook-type>/
├── script.sh              # Sequential execution
└── checks/                # Subdirectory = parallel execution
    ├── check-a.sh
    └── check-b.sh
```

- Scripts placed directly in a hook type directory run **sequentially in
  lexical order**
- Scripts inside subdirectories (e.g., `checks/`) run **in parallel**
- Files starting with a dot (`.`) are excluded from hook discovery

## Supported Hook Types

| Hook | Trigger |
|------|---------|
| `pre-commit` | Before commit |
| `commit-msg` | After commit message is written |
| `post-commit` | After commit |
| `pre-push` | Before push |
| `post-checkout` | After checkout |
| `post-merge` | After merge |
| `pre-rebase` | Before rebase |
| `pre-merge-commit` | Before merge commit |
| `post-rewrite` | After history rewrite |

## Code Quality

Always run format and lint checks before committing:

```bash
make check
```

### shfmt Settings

Shell script formatting rules:

- Indentation: 2 spaces (`-i 2`)
- Case indentation: enabled (`-ci`)
- Binary operators: placed before line breaks (`-bn`)

### shellcheck

Runs shellcheck on all `.sh` files to detect potential bugs, portability
issues, and style problems.
