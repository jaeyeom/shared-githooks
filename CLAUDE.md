# shared-githooks

Shared Git hooks repo consumed by other projects via
[Githooks](https://github.com/gabyx/Githooks). Not a standalone project —
consuming repos reference this repo's URL in their `.githooks/.shared.yaml`
or Git config, and Githooks clones/updates it automatically.

## Build / Test / Run

- `make check` — CI-friendly (no file mutation): format check + lint + test
- `make format` — auto-fix formatting
- Tools required: `shfmt`, `shellcheck`, `yamllint`, `biome`
  (`brew install shfmt shellcheck yamllint biome`)

## Architecture

- Place hooks in `.githooks/<hook-type>/` (primary search path). Githooks
  also searches `githooks/` and repo root, but `.githooks/` is the
  convention here.
- Scripts at the top level of a hook-type directory run **sequentially** in
  lexical order. Scripts inside a **subdirectory** run in **parallel** as a
  batch. Both `pre-commit/checks/` and `commit-msg/checks/` use this
  pattern — all checks within each run concurrently.
- To make all hooks in a folder parallel without a subdirectory, create a
  `.all-parallel` marker file.
- Files starting with `.` are **invisible** to Githooks hook discovery.
  That's why config files (`.shared.yaml`, `.ignore.yaml`, `.envs.yaml`)
  live safely alongside hook scripts.

## Githooks Reference

Githooks is a niche tool with limited online documentation. Key details
for writing hooks in this repo:

### YAML Run Configuration

Define a hook via YAML instead of a shell script:

```yaml
version: 1
cmd: "path/to/executable"
args:
  - "--flag"
  - "${env:MY_VAR}"
  - "${git:some.config}"
```

| Pattern | Source |
|---------|--------|
| `${env:VAR}` | Environment variable |
| `${git:VAR}` | Git config (auto-scoped) |
| `${git-l:VAR}` | Local Git config |
| `${git-g:VAR}` | Global Git config |
| `${git-s:VAR}` | System Git config |
| `${!env:VAR}` | Mandatory (fails if missing) |

### Environment Variables Available to Hooks

| Variable | Description |
|----------|-------------|
| `STAGED_FILES` | Newline-separated list of staged files (pre-commit only) |
| `STAGED_FILES_FILE` | Path to file with null-separated staged paths |
| `GITHOOKS_OS` | Operating system (`linux`, `darwin`, `windows`) |
| `GITHOOKS_ARCH` | Architecture (`amd64`, `arm64`) |
| `GITHOOKS_CONTAINER_RUN` | Set when running inside a container |

### Namespace

The `.namespace` file at repo root declares a namespace identifier. Consumers
can ignore hooks with patterns like `ns:<namespace>/**` in `.ignore.yaml`.

## Gotchas

- **i18n sync is opt-in.** The `check-i18n-sync.sh` hook is a no-op unless
  the consumer runs `git config hooks.i18nsync true`. When enabled, it
  requires all language variants of a doc file to be staged together
  (e.g., `README.md` + `README.ko.md` + `README.ja.md`). Languages are
  auto-discovered from tracked `README.<lang>.md` files.
- **README hook tables are tested.** `tests/test-readme-hooks.sh` validates
  that README documentation matches actual hook scripts. If you add, remove,
  or rename a hook, update the README or the test will fail.
- **Scripts must be executable** (`chmod +x`) or Githooks will skip them
  silently.
- **Hooks must be cross-platform.** Use `#!/usr/bin/env bash` and avoid
  platform-specific tools. Many consumers run on Linux CI and macOS local.
