# Getting Started

This guide explains how to integrate shared-githooks into your project.

## Prerequisites

- Git 2.x or later
- [Githooks](https://github.com/gabyx/Githooks) installed

### Installing Githooks

```bash
# macOS
brew install gabyx/githooks/githooks

# Or via the official install script
curl -sL https://raw.githubusercontent.com/gabyx/Githooks/main/scripts/install.sh | bash
```

After installation, initialize:

```bash
git hooks install
```

## Setup Methods

### Method 1: Per-project Setup (Recommended)

Add to your project's `.githooks/.shared.yaml`:

```yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

Githooks will automatically clone this repository and apply the hooks.

### Method 2: Global Setup

To apply to all Git repositories:

```bash
git config --global githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

### Method 3: Local Repository Setup

To apply to a specific repository only:

```bash
git config githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

## Version Pinning

Use `@` followed by a branch, tag, or commit SHA to pin a version:

```yaml
urls:
  # Pin to branch
  - "https://github.com/jaeyeom/shared-githooks.git@main"
  # Pin to tag
  - "https://github.com/jaeyeom/shared-githooks.git@v1.0.0"
  # Pin to commit SHA
  - "https://github.com/jaeyeom/shared-githooks.git@abc1234"
```

For production environments, pinning to a tag or commit SHA is recommended.

## Verifying Setup

Confirm that shared hooks are correctly configured:

```bash
# List installed shared hooks
git hooks shared list

# Manually update shared hooks
git hooks shared update
```

## Disabling Hooks

To disable specific hooks, add patterns to your project's
`.githooks/.ignore.yaml`:

```yaml
patterns:
  # Disable a specific hook
  - "pre-commit/checks/test-bazel.sh"
  # Disable the entire namespace
  - "ns:jaeyeom-shared-githooks/**"
```

## Next Steps

- [Hooks Reference](hooks-reference.md) — Detailed description of all hooks
- [Configuration Guide](configuration.md) — Advanced configuration options
- [Development Guide](development.md) — How to add/modify hooks
