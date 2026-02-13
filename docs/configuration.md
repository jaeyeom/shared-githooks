# Configuration Guide

This document explains the advanced configuration options for
shared-githooks.

## Namespace

The `.githooks/.namespace` file defines this shared repository's namespace
identifier. The current value is `jaeyeom-shared-githooks`.

Consuming repositories can use the namespace to selectively disable or
execute hooks:

```bash
# Execute a specific hook by namespace
git hooks exec ns:jaeyeom-shared-githooks/pre-commit/checks/check.sh

# Disable the entire namespace
# .githooks/.ignore.yaml
patterns:
  - "ns:jaeyeom-shared-githooks/**"
```

## Disabling Hooks (.ignore.yaml)

To disable specific hooks, add patterns to the consuming repository's
`.githooks/.ignore.yaml`:

```yaml
patterns:
  # Disable a specific hook
  - "pre-commit/checks/test-bazel.sh"

  # Disable by directory
  - "pre-commit/checks/**"

  # Disable by namespace
  - "ns:jaeyeom-shared-githooks/**"

  # Wildcard patterns
  - "**/experimental/**"
```

## Environment Variables (.envs.yaml)

Use `.githooks/.envs.yaml` to set environment variables during hook execution.

## Git Config Controls

Some hooks can be controlled via Git config values:

| Config | Default | Description |
|--------|---------|-------------|
| `hooks.allownonascii` | `false` | Set to `true` to allow non-ASCII filenames |

```bash
# Allow non-ASCII filenames
git config hooks.allownonascii true
```

## Environment Variables Available to Hooks

Environment variables automatically set by Githooks during hook execution:

| Variable | Description |
|----------|-------------|
| `STAGED_FILES` | Newline-separated list of staged files (pre-commit only) |
| `STAGED_FILES_FILE` | Path to a file containing null-separated staged paths |
| `GITHOOKS_OS` | Operating system (`linux`, `darwin`, `windows`) |
| `GITHOOKS_ARCH` | Architecture (`amd64`, `arm64`) |
| `GITHOOKS_CONTAINER_RUN` | Set when running inside a container |

## Containerized Hook Execution

Hooks can run inside Docker/Podman containers.

### Defining Images (.images.yaml)

```yaml
# .githooks/.images.yaml
images:
  my-image:1.0:
    pull:
      reference: "registry/my-image:1.0"
  custom-tool:latest:
    build:
      dockerfile: ./docker/Dockerfile
      stage: final
      context: ./docker
```

### Referencing Images in Hooks

```yaml
# .githooks/pre-commit/containerized-check.yaml
version: 3
cmd: ./check.sh
image:
  reference: "my-image:1.0"
```

## YAML Hook Configuration

Hooks can be defined via YAML instead of shell scripts:

```yaml
# .githooks/pre-commit/my-hook.yaml
version: 1
cmd: "path/to/executable"
args:
  - "--flag"
  - "${env:MY_VAR}"
  - "${git:some.config}"
```

### Variable Substitution Patterns

| Pattern | Source |
|---------|--------|
| `${env:VAR}` | Environment variable |
| `${git:VAR}` | Git config (auto-scoped) |
| `${git-l:VAR}` | Local Git config |
| `${git-g:VAR}` | Global Git config |
| `${git-s:VAR}` | System Git config |
| `${!env:VAR}` | Required environment variable (fails if missing) |

## Parallel Execution Settings

Control how hooks execute:

- **Sequential:** Place scripts directly in the hook type directory
- **Parallel:** Group scripts in a subdirectory
- **All parallel:** Create an `.all-parallel` marker file in the directory

```
.githooks/pre-commit/
├── sequential-a.sh          # Sequential execution (lexical order)
├── sequential-b.sh          # Sequential execution (lexical order)
└── parallel-batch/          # Scripts inside run in parallel
    ├── check-a.sh
    └── check-b.sh
```
