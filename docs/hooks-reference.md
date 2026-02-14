# Hooks Reference

This document provides detailed descriptions of every hook's behavior,
conditions, and configuration options in shared-githooks.

## Overview

| Hook Type | Scripts | Execution |
|-----------|---------|-----------|
| pre-commit | 10 | Parallel (`checks/` directory) |
| commit-msg | 3 | Parallel (`checks/` directory) |

All hook scripts start with `set -euo pipefail` and silently skip when
dependencies are missing.

---

## Pre-commit Hooks

Hooks that verify code quality before a commit. Located in
`.githooks/pre-commit/checks/` and executed **in parallel**.

### check.sh — Makefile-based Checks

Runs `make -j check` if the project's Makefile has a `check` target.

**Activation conditions:**
- `Makefile` exists in the project root
- `check:` target is defined in the Makefile

**Skip conditions:**
- No `Makefile` present
- No `check:` target defined

**Command:** `make -j check` (parallel build)

---

### check-large-files.sh — Large File Detection

Checks whether staged files exceed a size threshold.

**Default limit:** 1 MB (1048576 bytes)

**Configuration:**

```bash
git config hooks.maxfilesize <bytes>
```

**Behavior:**
- Checks the size of all staged files (Added/Changed/Modified)
- Displays filename and size when threshold is exceeded, and aborts the commit
- Always runs (no skip conditions)

---

### check-whitespace.sh — Whitespace Error Detection

Detects trailing whitespace, space-before-tab, and other whitespace errors.

**Behavior:**
- Uses `git diff-index --check --cached` to inspect staged changes
- Excludes files handled by language-specific formatters

**Excluded file extensions:**
- `.go` — handled by gofmt
- `.py` — handled by black/autopep8, etc.
- `.proto` — handled by clang-format
- `.bzl`, `BUILD`, `BUILD.bazel`, `WORKSPACE` — handled by buildifier

---

### check-non-ascii.sh — Non-ASCII Filename Detection

Checks whether newly added files contain non-ASCII characters in their names.
This is a cross-platform compatibility check.

**To disable:**

```bash
git config hooks.allownonascii true
```

---

### lint-go.sh — Go Lint

Runs `golangci-lint` on Go projects.

**Activation conditions:**
- `.golangci.yml` exists in the project root
- `golangci-lint` is installed

**Skip conditions:**
- No `.golangci.yml` present
- `golangci-lint` is not installed (prints warning)
- Makefile `check` target already runs `golangci-lint` (deduplication)

**Note:** Unsets the `GOPACKAGESDRIVER` environment variable to ensure a clean
execution environment.

---

### lint-python.sh — Python Lint

Runs `ruff check` and `ruff format --check` on Python projects.

**Activation conditions:**
- `ruff.toml`, `.ruff.toml`, or a `[tool.ruff]` section in `pyproject.toml` exists
- `ruff` is installed

**Skip conditions:**
- No ruff configuration file present
- `ruff` is not installed (prints warning)
- Makefile `check` target already runs `ruff` (deduplication)
- Bazel project manages ruff via `@multitool//tools/ruff`

---

### lint-shell.sh — Shell Script Lint

Runs `shellcheck` on staged `.sh` files.

**Activation conditions:**
- `shellcheck` is installed
- Staged `.sh` files exist (Added/Changed/Modified)

**Skip conditions:**
- `shellcheck` is not installed (prints warning)
- No staged `.sh` files
- Makefile `check` target already runs `shellcheck` (deduplication)

---

### lint-org.sh — Org-mode Lint

Runs `org-lint` on staged `.org` files.

**Activation conditions:**
- `org-lint` is installed
- Staged `.org` files exist (Added/Changed/Modified)

**Skip conditions:**
- `org-lint` is not installed (silently skipped)
- No staged `.org` files

---

### lint-semgrep.sh — Semgrep Static Analysis

Runs `semgrep scan` on projects with Semgrep configuration.

**Activation conditions:**
- `.semgrep.yml`, `.semgrep.yaml`, or `.semgrep/` directory exists
- `semgrep` is installed

**Skip conditions:**
- No Semgrep configuration file/directory present
- `semgrep` is not installed (prints warning)
- Makefile `check` target already runs `semgrep` (deduplication)

---

### test-bazel.sh — Bazel Tests

Runs tests affected by changes in Bazel projects.

**Activation conditions:**
- `BUILD` or `BUILD.bazel` exists in the project root
- `bazel` is installed

**Skip conditions:**
- No `BUILD`/`BUILD.bazel` present
- `bazel` is not installed (prints warning)
- Makefile `check` target already runs `bazel test` (deduplication)

**Smart test selection:**
- If `bazel-affected-tests` binary is available, only affected tests are run
- Otherwise, falls back to `bazel test //...:all`

**Format test special handling:**
- When `//tools/format:` tests fail, automatically runs
  `bazel run //:format` to reformat code, then aborts the commit
- Developers can review the reformatted code and commit again

**Platform limitation:**
- On macOS (Darwin), non-format tests are skipped

---

## Commit-msg Hooks

Hooks that validate commit message quality and policies. Located in
`.githooks/commit-msg/checks/` and executed **in parallel**.

### check-subject-length.sh — Subject Line Length Limit

Enforces that the first line (subject) of the commit message does not exceed
72 characters.

**Rule:** Subject line <= 72 characters

---

### check-co-authored-by.sh — Co-Authored-By Rejection

Rejects commits containing a `Co-Authored-By:` line in the message.

**Pattern:** `^Co-Authored-By:`

---

### check-generated-comment.sh — AI-generated Marker Rejection

Rejects commits containing the `Generated with ` string in the message.
This encourages removal of markers auto-added by AI tools.

**Pattern:** `Generated with `
