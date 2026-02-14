# shared-githooks

One set of Git hooks for all your repos.

## Why

When you work with [Claude Code](https://docs.anthropic.com/en/docs/claude-code), you're committing and pushing changes constantly. Without guardrails, a bad commit slips through — broken formatting, failing tests, lint violations — and you don't notice until CI fails or a reviewer catches it.

These hooks are your safety net. Set them up once, globally, and every commit in every repo gets checked automatically. Claude Code runs `git commit`, the hooks catch problems before they land, and you move on with confidence. No per-repo setup, no remembering to run checks manually.

## Overview

A globally-installable Git hooks collection managed by [Githooks](https://github.com/gabyx/Githooks). Install once, apply everywhere. The hooks auto-detect project types, defer to Makefile conventions when available, and skip gracefully when tools aren't present. No per-repo configuration required.

The hooks follow a **Makefile-first philosophy**: if your project has a `Makefile` with a `check` target, the hooks run `make -j check` and let your existing build system handle the details. This aligns with the [makefile-workflow](https://github.com/jaeyeom/claude-toolbox) conventions where projects have standardized `check`, `check-format`, `lint`, and `test` targets.

The collection grows over time to understand more languages and toolchains, but always remains global-friendly — sensible defaults that work without configuration.

## Quick Setup

Install globally for all repos:

```bash
# Install Githooks if needed
git hooks install

# Add shared hooks globally
git config --global githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"

# Update shared hooks
git hooks shared update
```

Alternatively, use per-repo configuration via `.githooks/.shared.yaml`:

```yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

## How It Works

When you commit, hooks run in parallel following this logic:

```
commit → pre-commit hooks (parallel) →
  ├── Makefile with check: target? → make -j check (covers everything)
  ├── Go project without Makefile check? → golangci-lint
  ├── Python project without Makefile check? → ruff check + format
  ├── Shell scripts staged? → shellcheck
  ├── Bazel project without Makefile check? → affected tests
  ├── .org files staged? → org-lint
  ├── Semgrep config present? → semgrep scan
  ├── Large files staged? → reject (configurable limit)
  ├── Whitespace errors? → git diff --check
  └── Non-ASCII filenames? → reject (configurable)

commit-msg hooks (parallel) →
  ├── Subject line >72 chars? → reject
  ├── Co-Authored-By: line? → reject
  └── AI-generated marker? → reject
```

The **deference pattern** is key: if your Makefile has a `check` target that runs linters, the tool-specific hooks (like `lint-go.sh`) skip automatically to avoid duplicate work. If your Makefile mentions `golangci-lint`, the Go hook defers. If it mentions `bazel test`, the Bazel hook defers.

When no Makefile exists, the hooks fall back to running tools directly. When tools aren't installed, they skip silently.

## Making Your Repo Compatible

For the best experience, add a `Makefile` with a `check` target:

```makefile
.PHONY: all check format check-format lint test

all: format lint test
check: check-format lint test   # CI-safe, read-only

check-format:
	# verify formatting without mutating files

lint:
	# run linters (e.g., golangci-lint, shellcheck, eslint)

test:
	# run tests
```

The `check` target should be **read-only** (no file mutations) and safe for `make -j` (parallel execution). When hooks detect `make check`, they defer tool-specific checks to your Makefile.

See the [makefile-workflow](https://github.com/jaeyeom/claude-toolbox) conventions for detailed patterns per language (Go, Node.js, Bazel, mixed stacks).

## Included Hooks

### Pre-commit Hooks (all run in parallel)

| Hook | What It Does | Skip Conditions |
|------|--------------|-----------------|
| `check.sh` | Runs `make -j check` if available | No Makefile with `check:` target |
| `check-large-files.sh` | Rejects staged files exceeding a size threshold (default 1 MB) | Never (always runs); configure limit with `git config hooks.maxfilesize <bytes>` |
| `check-whitespace.sh` | Detects trailing whitespace and mixed line endings via `git diff-index --check` | Files handled by language formatters (*.go, *.py, *.proto, *.bzl, BUILD*) |
| `check-non-ascii.sh` | Rejects non-ASCII filenames for portability | `git config hooks.allownonascii true` |
| `lint-go.sh` | Runs `golangci-lint run ./...` | No `.golangci.yml`, tool not installed, or Makefile `check:` target mentions `golangci-lint` |
| `lint-python.sh` | Runs `ruff check` and `ruff format --check` on Python projects | No ruff config, tool not installed, Bazel manages ruff via `@multitool`, or Makefile `check:` target mentions `ruff` |
| `lint-shell.sh` | Runs `shellcheck` on staged `.sh` files | No staged `.sh` files, tool not installed, or Makefile `check:` target mentions `shellcheck` |
| `lint-org.sh` | Runs `org-lint` on staged `.org` files | No staged `.org` files, tool not installed |
| `lint-semgrep.sh` | Runs `semgrep scan` for static analysis | No `.semgrep.yml`, `.semgrep.yaml`, or `.semgrep/` directory; tool not installed; or Makefile `check:` target mentions `semgrep` |
| `test-bazel.sh` | Runs affected Bazel tests via `bazel-affected-tests`, auto-fixes format tests | No `BUILD`/`BUILD.bazel` file, `bazel` not installed, or Makefile `check:` target mentions `bazel test` |

### Commit-msg Hooks (all run in parallel)

| Hook | What It Does | Skip Conditions |
|------|--------------|-----------------|
| `check-subject-length.sh` | Enforces ≤72 character subject line | Never (always runs) |
| `check-co-authored-by.sh` | Rejects `Co-Authored-By:` lines | Never (always runs) |
| `check-generated-comment.sh` | Rejects `Generated with ` markers (AI tool artifacts) | Never (always runs) |

## Configuration

| Setting | Effect |
|---------|--------|
| `git config hooks.allownonascii true` | Allow non-ASCII filenames |
| `git config hooks.maxfilesize <bytes>` | Set large file threshold (default: 1048576 = 1 MB) |
| Makefile `check:` target | Overrides tool-specific hooks when present |
| `.NOTPARALLEL` in Makefile | Disables parallel `make -j` execution |

## Disabling Hooks

Disable specific hooks via Githooks ignore patterns:

```bash
# Disable a specific hook
git hooks ignore add --pattern "ns:jaeyeom-shared-githooks/pre-commit/checks/test-bazel.sh"

# Disable all Bazel tests
git hooks ignore add --pattern "**/test-bazel.sh"
```

Or add patterns to `.githooks/.ignore.yaml`:

```yaml
patterns:
  - "pre-commit/checks/test-bazel.sh"
```

## Development

Install development tools:

```bash
brew install shfmt shellcheck yamllint biome
```

Run formatting and checks:

```bash
make          # format + lint
make check    # CI-friendly checks (no mutation)
make help     # show all targets
```

See [CLAUDE.md](CLAUDE.md) for full technical documentation on directory structure, YAML hook configs, parallel execution, containerization, and more.
