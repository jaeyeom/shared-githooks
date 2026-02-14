# shared-githooks

A shared Git hooks repository managed by [Githooks](https://github.com/gabyx/Githooks).

## What This Repo Is

This is a **shared hook repository** — a centralized collection of Git hooks
that can be referenced by multiple repositories via Githooks. Consuming repos
add this repo's URL to their `.githooks/.shared.yaml` or global Git config, and
Githooks automatically clones/updates and runs hooks from here.

## Directory Structure

```
shared-githooks/
├── .githooks/               # Hook scripts (primary search path)
│   ├── pre-commit/          # Hooks that run before each commit
│   │   ├── script.sh        # Single script (runs sequentially)
│   │   └── batch-name/      # Subdirectory = parallel batch
│   │       ├── check-a.sh
│   │       └── check-b.sh
│   ├── commit-msg/          # Hooks that validate commit messages
│   ├── pre-push/            # Hooks that run before push
│   ├── post-checkout/       # Hooks that run after checkout
│   ├── post-merge/          # Hooks that run after merge
│   ├── <hook-name>/         # Any standard Git hook type
│   │   └── ...
│   ├── .shared.yaml         # (Optional) nested shared repo references
│   ├── .ignore.yaml         # Patterns to exclude hooks
│   ├── .envs.yaml           # Environment variables for hooks
│   ├── .images.yaml         # Container image config (Docker/Podman)
│   └── .lfs-required        # Marker: require Git LFS in consumers
├── docs/                    # Project documentation (English)
│   ├── getting-started.md   # Installation and setup guide
│   ├── hooks-reference.md   # Detailed hook reference
│   ├── configuration.md     # Advanced configuration options
│   ├── development.md       # Contributing and development guide
│   ├── ko/                  # Korean translations
│   └── ja/                  # Japanese translations
├── .namespace               # Namespace identifier for this shared repo
├── CLAUDE.md                # This file
├── README.md                # User-facing documentation (English)
├── README.ko.md             # Korean README
└── README.ja.md             # Japanese README
```

### Search Priority

When Githooks resolves hooks from a shared repo, it searches directories in
this order:

1. `<repo>/githooks/` (for development-only hooks)
2. `<repo>/.githooks/`
3. `<repo>/` (root)

Use `.githooks/` as the primary location for hooks.

## Adding a New Hook

1. Create a directory named after the Git hook event under `.githooks/`:

   ```
   .githooks/pre-commit/
   ```

2. Add an executable script inside that directory:

   ```bash
   #!/usr/bin/env bash
   # .githooks/pre-commit/check-formatting.sh
   echo "Checking formatting..."
   # your logic here
   ```

3. Make the script executable:

   ```
   chmod +x .githooks/pre-commit/check-formatting.sh
   ```

4. Alternatively, use a YAML run configuration instead of a script:

   ```yaml
   # .githooks/pre-commit/run-linter.yaml
   version: 1
   cmd: golangci-lint
   args:
     - "run"
     - "--fix"
   ```

### Supported Hook Types

All standard Git hooks are supported:

- `pre-commit`, `commit-msg`, `post-commit`
- `pre-push`, `pre-receive`, `post-receive`
- `post-checkout`, `post-merge`, `pre-merge-commit`
- `pre-rebase`, `post-rewrite`
- `applypatch-msg`, `pre-applypatch`, `post-applypatch`
- `update`, `post-update`, `reference-transaction`
- `push-to-checkout`, `pre-auto-gc`, `sendemail-validate`, `post-index-change`

## Parallel Execution

Place scripts inside a **subdirectory** within a hook type folder to run them
in parallel:

```
.githooks/pre-commit/
├── sequential-script.sh       # Runs sequentially (in lexical order)
└── parallel-checks/           # Everything inside runs in parallel
    ├── lint.sh
    ├── format.sh
    └── typecheck.sh
```

To make **all** hooks in a folder run in parallel, create a `.all-parallel`
marker file in that folder.

## Hook Run Configuration (YAML)

Instead of writing a shell script, you can define a hook via YAML:

```yaml
# .githooks/pre-commit/my-hook.yaml
version: 1
cmd: "path/to/executable"
args:
  - "--flag"
  - "${env:MY_VAR}"        # Environment variable substitution
  - "${git:some.config}"   # Git config value substitution
```

Variable substitution patterns:

| Pattern | Source |
|---------|--------|
| `${env:VAR}` | Environment variable |
| `${git:VAR}` | Git config (auto-scoped) |
| `${git-l:VAR}` | Local Git config |
| `${git-g:VAR}` | Global Git config |
| `${git-s:VAR}` | System Git config |
| `${!env:VAR}` | Mandatory (fails if missing) |

## Namespace

The `.namespace` file at the repo root declares this shared repo's namespace
identifier. Consumers can use the namespace to selectively disable hooks:

```
# .namespace
my-shared-hooks
```

This allows consumers to ignore hooks with patterns like
`ns:my-shared-hooks/**` in their `.ignore.yaml`.

## Environment Variables Available to Hooks

| Variable | Description |
|----------|-------------|
| `STAGED_FILES` | Newline-separated list of staged files (pre-commit only) |
| `STAGED_FILES_FILE` | Path to file with null-separated staged paths |
| `GITHOOKS_OS` | Operating system (e.g., `linux`, `darwin`, `windows`) |
| `GITHOOKS_ARCH` | Architecture (e.g., `amd64`, `arm64`) |
| `GITHOOKS_CONTAINER_RUN` | Set when running inside a container |

## Containerized Hooks

Hooks can run inside Docker/Podman containers. Define images in `.images.yaml`:

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

Reference images in hook YAML configs:

```yaml
# .githooks/pre-commit/containerized-check.yaml
version: 3
cmd: ./check.sh
image:
  reference: "my-image:1.0"
```

## How Consumers Use This Repo

### Via `.githooks/.shared.yaml` (per-repo)

In the consuming repository:

```yaml
# .githooks/.shared.yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

### Via Global Git Config

```bash
git config --global githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

### Via Local Git Config

```bash
git config githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

The `@main` suffix pins to the `main` branch. You can also use tags or commit
SHAs (e.g., `@v1.0.0`, `@abc1234`).

## Ignore Patterns

Use `.ignore.yaml` to exclude hooks:

```yaml
# .githooks/.ignore.yaml
patterns:
  - "pre-commit/slow-check.sh"    # Ignore a specific hook
  - "**/experimental/**"           # Ignore all hooks in experimental dirs
```

## Development Workflow

1. **Add/edit hooks** in the `.githooks/<hook-type>/` directory.
2. **Test locally** by running the script directly or using
   `git hooks exec ns:my-shared-hooks/<hook-type>/script.sh`.
3. **Commit and push** to this repo.
4. Consuming repos pick up changes on next `git hooks update` or automatically
   on the next hook trigger (Githooks auto-updates shared repos).

## Conventions

- Scripts must be **executable** (`chmod +x`).
- Files starting with a dot (`.`) are excluded from hook discovery.
- Hooks execute in **lexical order** within a directory.
- Keep hooks **fast** — slow hooks degrade developer experience.
- Use YAML configs for hooks that invoke external tools rather than writing
  wrapper scripts.
- Pin shared repo references to a branch or tag to avoid breaking consumers
  with untested changes.
- Write hooks to be **cross-platform** when possible (use `#!/usr/bin/env bash`
  or YAML configs with platform-independent tools).
